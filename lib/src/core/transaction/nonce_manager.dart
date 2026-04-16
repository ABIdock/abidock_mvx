import 'dart:async';

import '../../infrastructure/network/network_provider.dart';
import '../account/account_on_network.dart';
import '../address.dart';
import '../nonce.dart';

/// Stateful nonce allocator for a single address.
///
/// Keeps a local in-memory counter that stays ahead of the network so
/// back-to-back sends never reuse a nonce. The counter is seeded from
/// `networkProvider.getAccount(...)` on first use and periodically refreshed.
///
/// Use this when you're sending more than one transaction in a tight loop
/// (airdrop, bulk mint, multi-step flow): each call to [next] hands out a
/// fresh [Nonce] and immediately increments the local counter. No round-trip
/// to the network is needed between sends, and concurrent callers are
/// serialized so two green threads can't grab the same nonce.
///
/// #### Semantics
/// - `next()` — reserves and returns the next nonce. If the manager has never
///   been synced, it fetches the account first. All calls are serialized.
/// - `release(nonce)` — returns a reserved nonce to the pool when the sender
///   decided not to broadcast it after all. Only effective if the released
///   nonce is the highest reserved one; otherwise the nonce is dropped (the
///   caller should just burn it with a no-op transaction or re-sync).
/// - `resync()` — forces a fresh `getAccount` call and advances the counter
///   *forward only*. It never goes backwards: if locally we already reserved
///   nonce 42 but the network still reports 40, the counter stays at 42.
/// - `applyNonce(nonce)` — records that a nonce was successfully broadcast,
///   so later `resync()` calls know the floor.
///
/// #### Example
/// ```dart
/// final nonces = NonceManager(
///   address: sender.address,
///   networkProvider: provider,
/// );
///
/// Future<String> sendOne(Transaction draft, Signer signer) async {
///   final nonce = await nonces.next();
///   try {
///     final signed = await signer.sign(draft.copyWith(newNonce: nonce));
///     final hash = await provider.sendTransaction(signed);
///     nonces.applyNonce(nonce);
///     return hash;
///   } catch (_) {
///     nonces.release(nonce);
///     rethrow;
///   }
/// }
/// ```
class NonceManager {
  /// Creates a nonce manager for [address].
  ///
  /// #### Parameters
  /// - `address` - Account address whose nonce is being tracked
  /// - `networkProvider` - Provider used to bootstrap and re-sync the counter
  /// - `resyncInterval` - How often to force a fresh `getAccount` call, even
  ///   if `next()` calls keep succeeding. Defaults to 5 minutes; set to
  ///   [Duration.zero] to disable the timer-based refresh.
  NonceManager({
    required this.address,
    required this.networkProvider,
    this.resyncInterval = const Duration(minutes: 5),
  });

  /// Address this manager tracks.
  final Address address;

  /// Network provider used to read the account state.
  final NetworkProvider networkProvider;

  /// How often to force-resync the counter even if `next()` succeeds.
  final Duration resyncInterval;

  int? _nextValue;
  int _highestApplied = -1;
  DateTime? _lastResync;
  final List<int> _releasedButNotReused = <int>[];

  /// Reserves and returns the next nonce.
  Future<Nonce> next() async {
    await _serialize(_ensureFresh);
    if (_releasedButNotReused.isNotEmpty) {
      _releasedButNotReused.sort();
      final int reuse = _releasedButNotReused.removeAt(0);
      return Nonce(reuse);
    }
    final int current = _nextValue!;
    _nextValue = current + 1;
    return Nonce(current);
  }

  /// Records that [nonce] was successfully broadcast.
  ///
  /// The highest applied nonce acts as a floor during [resync]: the counter
  /// will never be pulled below `applied + 1`.
  void applyNonce(Nonce nonce) {
    if (nonce.value > _highestApplied) {
      _highestApplied = nonce.value;
    }
  }

  /// Returns a reserved [nonce] to the pool.
  ///
  /// If this was the last-reserved nonce, the counter is rewound so the next
  /// `next()` call hands it out again. Otherwise it's queued for reuse on the
  /// next `next()` call, maintaining strict ordering.
  void release(Nonce nonce) {
    if (_nextValue == null) return;
    if (nonce.value <= _highestApplied) {
      return;
    }
    if (nonce.value == _nextValue! - 1) {
      _nextValue = nonce.value;
    } else if (nonce.value < _nextValue!) {
      if (!_releasedButNotReused.contains(nonce.value)) {
        _releasedButNotReused.add(nonce.value);
      }
    }
  }

  /// Forces a re-sync from the network.
  ///
  /// Advances the counter forward if the network reports a higher nonce,
  /// but never moves it backwards past what's been reserved locally.
  Future<void> resync() async {
    await _serialize(() => _syncFromNetwork(force: true));
  }

  /// Current locally-reserved counter, or `null` if never synced.
  int? get peek => _nextValue;

  Future<void> _ensureFresh() async {
    if (_nextValue == null) {
      await _syncFromNetwork(force: true);
      return;
    }
    if (resyncInterval == Duration.zero || _lastResync == null) return;
    if (DateTime.now().difference(_lastResync!) > resyncInterval) {
      await _syncFromNetwork(force: false);
    }
  }

  Future<void> _syncFromNetwork({required bool force}) async {
    try {
      final AccountOnNetwork account = await networkProvider.getAccount(
        address,
      );
      final int networkNonce = account.nonce.value;
      final int floor = _highestApplied + 1;
      final int desired = networkNonce > floor ? networkNonce : floor;
      if (_nextValue == null || desired > _nextValue!) {
        _nextValue = desired;
      }
      _releasedButNotReused.removeWhere(
        (int n) => n <= _highestApplied || n < networkNonce,
      );
      _lastResync = DateTime.now();
    } catch (_) {
      if (force && _nextValue == null) rethrow;
    }
  }

  final List<Completer<void>> _queue = <Completer<void>>[];

  Future<void> _serialize(Future<void> Function() action) async {
    final Completer<void> me = Completer<void>();
    _queue.add(me);
    if (_queue.length > 1) {
      await _queue[_queue.length - 2].future;
    }
    try {
      await action();
    } finally {
      _queue.remove(me);
      me.complete();
    }
  }
}
