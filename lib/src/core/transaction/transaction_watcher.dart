import 'dart:async';
import '../../infrastructure/network/network_provider.dart';
import '../../utils/sdk_exceptions.dart';
import 'transaction_on_network.dart';
import 'transaction_status.dart';

/// Configuration for transaction polling behavior.
/// Defines timeout, polling interval, and patience period for transaction watching.
///
/// #### Example
/// ```dart
/// // Default options (60s timeout, 2s polling)
/// const defaultOptions = TransactionAwaitingOptions();
///
/// // Custom options
/// const customOptions = TransactionAwaitingOptions(
///   timeout: Duration(minutes: 5),
///   pollingInterval: Duration(seconds: 3),
///   patience: Duration(seconds: 10),
/// );
///
/// // Quick poll for testnet
/// const quickOptions = TransactionAwaitingOptions(
///   timeout: Duration(seconds: 30),
///   pollingInterval: Duration(seconds: 1),
/// );
/// ```
class TransactionAwaitingOptions {
  /// Creates awaiting options with custom timeouts.
  ///
  /// #### Parameters
  /// - `timeout` - Maximum wait time before throwing timeout exception (default: 60s)
  /// - `pollingInterval` - Delay between status checks (default: 400ms)
  /// - `patience` - Extra wait after block detection for finalization (default: 800ms)
  /// - `maxConsecutiveErrors` - Abort after this many consecutive fetch failures (default: 5)
  ///
  /// #### Example
  /// ```dart
  /// const options = TransactionAwaitingOptions(
  ///   timeout: Duration(seconds: 120),
  ///   pollingInterval: Duration(seconds: 3),
  ///   patience: Duration(seconds: 10),
  /// );
  /// ```
  const TransactionAwaitingOptions({
    this.timeout = const Duration(seconds: 60),
    this.pollingInterval = const Duration(milliseconds: 400),
    this.patience = const Duration(milliseconds: 800),
    this.maxConsecutiveErrors = 5,
    this.awaitCrossShardCompletion = false,
    this.numShards,
    this.roundDuration,
  });

  /// Maximum wait time before timeout.
  final Duration timeout;

  /// Interval between status checks.
  final Duration pollingInterval;

  /// Extra wait time after block detection for finalization.
  final Duration patience;

  /// Max consecutive fetch errors before giving up with the original cause.
  final int maxConsecutiveErrors;

  /// When `true`, [TransactionWatcher.awaitCompleted] additionally waits for
  /// the chain's `completedTxEvent` log before returning. That event fires
  /// once all cross-shard SCResults have been produced. Cross-shard SC calls
  /// commonly look "success" at source-shard inclusion but their destination
  /// SCResult is still in-flight; without this flag the watcher can return a
  /// premature snapshot.
  final bool awaitCrossShardCompletion;

  /// Number of shards on the target network. When set alongside
  /// [roundDuration], [TransactionWatcher] adapts its polling timeout to
  /// `max(timeout, roundDuration * (numShards + 1) * 3)` for cross-shard
  /// safety. Pull from `NetworkConfig` / `NetworkStatus` when available.
  final int? numShards;

  /// Round duration on the target network (typically 6 s on mainnet).
  final Duration? roundDuration;
}

/// Polls blockchain to monitor transaction status until completion.
/// Queries blockchain API at regular intervals until condition is met or timeout occurs.
///
/// #### Example
/// ```dart
/// // Create watcher
/// final watcher = TransactionWatcher(networkProvider: networkProvider);
///
/// // Wait for completion
/// final txOnNetwork = await watcher.awaitCompleted(txHash);
/// if (txOnNetwork.isSuccessful) {
///   print('Transaction succeeded!');
/// }
///
/// // Custom timeout and polling
/// const options = TransactionAwaitingOptions(
///   timeout: Duration(minutes: 2),
///   pollingInterval: Duration(seconds: 3),
/// );
/// final tx = await watcher.awaitCompleted(txHash, options: options);
///
/// // Custom condition
/// final txInBlock = await watcher.awaitOnCondition(
///   txHash,
///   (status) => status.isExecuted,
///   options: options,
/// );
///
/// // Cleanup
/// watcher.close();
/// ```
class TransactionWatcher {
  /// Creates watcher from network provider.
  ///
  /// #### Parameters
  /// - `networkProvider` - Network provider with base URL
  ///
  /// #### Example
  /// ```dart
  /// final networkProvider = NetworkProvider.fromChain(Chain.devnet);
  /// final watcher = TransactionWatcher(networkProvider: networkProvider);
  ///
  /// try {
  ///   final tx = await watcher.awaitCompleted(txHash);
  ///   print('Status: ${tx.status.status}');
  /// } finally {
  ///   watcher.close();
  /// }
  /// ```
  TransactionWatcher({required NetworkProvider networkProvider})
    : _networkProvider = networkProvider;

  final NetworkProvider _networkProvider;

  /// Awaits transaction until final state (executed, failed, or invalid).
  ///
  /// #### Parameters
  /// - `txHash` - Transaction hash to monitor
  /// - `options` - Polling configuration (optional)
  ///
  /// #### Returns
  /// `TransactionOnNetwork` - Transaction with final status
  ///
  /// #### Throws
  /// - `TransactionWatcherTimeoutException` - If timeout exceeded
  /// - `TransactionWatcherException` - If polling failed
  ///
  /// #### Example
  /// ```dart
  /// final watcher = TransactionWatcher(networkProvider: networkProvider);
  ///
  /// try {
  ///   // Wait with default options (60s timeout)
  ///   final tx = await watcher.awaitCompleted(txHash);
  ///
  ///   if (tx.isSuccessful) {
  ///     print('Success! Block: ${tx.blockNonce}');
  ///   } else if (tx.hasFailed) {
  ///     print('Failed: ${tx.status.status}');
  ///   }
  ///
  ///   // With custom options
  ///   const options = TransactionAwaitingOptions(
  ///     timeout: Duration(minutes: 5),
  ///     pollingInterval: Duration(seconds: 3),
  ///   );
  ///   final tx2 = await watcher.awaitCompleted(txHash2, options: options);
  /// } on TransactionWatcherTimeoutException catch (e) {
  ///   print('Timeout: ${e.message}');
  /// } finally {
  ///   watcher.close();
  /// }
  /// ```
  Future<TransactionOnNetwork> awaitCompleted(
    String txHash, {
    TransactionAwaitingOptions options = const TransactionAwaitingOptions(),
  }) async {
    return awaitOnCondition(
      txHash,
      (TransactionStatus status) => status.isFinal,
      options: options,
    );
  }

  /// Awaits transaction until predicate condition is met.
  ///
  /// #### Parameters
  /// - `txHash` - Transaction hash to monitor
  /// - `predicate` - Condition function returning true when satisfied
  /// - `options` - Polling configuration (optional)
  ///
  /// #### Returns
  /// `TransactionOnNetwork` - Transaction when condition met
  ///
  /// #### Throws
  /// - `TransactionWatcherTimeoutException` - If timeout exceeded
  /// - `TransactionWatcherException` - If polling failed
  ///
  /// #### Example
  /// ```dart
  /// final watcher = TransactionWatcher(networkProvider: networkProvider);
  ///
  /// // Wait until executed (not just pending)
  /// final tx = await watcher.awaitOnCondition(
  ///   txHash,
  ///   (status) => status.isExecuted,
  /// );
  ///
  /// // Wait until in specific block
  /// final txInBlock = await watcher.awaitOnCondition(
  ///   txHash,
  ///   (status) => status.isFinal,
  ///   options: TransactionAwaitingOptions(
  ///     timeout: Duration(seconds: 120),
  ///   ),
  /// );
  ///
  /// // Custom condition
  /// final txCustom = await watcher.awaitOnCondition(
  ///   txHash,
  ///   (status) => status.isSuccessful || status.isFailed,
  /// );
  /// ```
  Future<TransactionOnNetwork> awaitOnCondition(
    String txHash,
    bool Function(TransactionStatus status) predicate, {
    TransactionAwaitingOptions options = const TransactionAwaitingOptions(),
  }) async {
    final DateTime startTime = DateTime.now();
    TransactionOnNetwork? lastTx;
    int consecutiveErrors = 0;

    final Duration effectiveTimeout =
        options.numShards != null && options.roundDuration != null
        ? _maxDuration(
            options.timeout,
            options.roundDuration! * (options.numShards! + 1) * 3,
          )
        : options.timeout;

    while (true) {
      final Duration elapsed = DateTime.now().difference(startTime);
      if (elapsed >= effectiveTimeout) {
        throw TransactionWatcherTimeoutException(
          'Transaction did not complete within ${effectiveTimeout.inSeconds}s',
          transactionHash: txHash,
          timeout: effectiveTimeout,
        );
      }

      try {
        lastTx = await fetchTransaction(txHash);
        consecutiveErrors = 0;

        if (predicate(lastTx.status)) {
          if (lastTx.isInBlock && options.patience.inMilliseconds > 0) {
            await Future<void>.delayed(options.patience);
            lastTx = await fetchTransaction(txHash);
          }
          if (options.awaitCrossShardCompletion &&
              !_hasCompletedEvent(lastTx)) {
            await Future<void>.delayed(options.pollingInterval);
            continue;
          }
          return lastTx;
        }

        await Future<void>.delayed(options.pollingInterval);
      } catch (e) {
        consecutiveErrors++;
        if (consecutiveErrors >= options.maxConsecutiveErrors) {
          throw TransactionWatcherException(
            'Transaction polling failed $consecutiveErrors consecutive times',
            transactionHash: txHash,
            cause: e,
          );
        }
        final Duration backoff = Duration(
          milliseconds:
              options.pollingInterval.inMilliseconds *
              (1 << (consecutiveErrors - 1)),
        );
        await Future<void>.delayed(backoff);
        continue;
      }
    }
  }

  /// Fetches current transaction state from blockchain.
  Future<TransactionOnNetwork> fetchTransaction(String txHash) async {
    try {
      return await _networkProvider.getTransaction(txHash);
    } catch (e) {
      if (e is TransactionWatcherException) {
        rethrow;
      }
      throw TransactionWatcherException(
        'Failed to fetch transaction',
        transactionHash: txHash,
        cause: e,
      );
    }
  }

  /// Checks if transaction has completed execution.
  Future<bool> isCompleted(String txHash) async {
    try {
      final TransactionOnNetwork tx = await fetchTransaction(txHash);
      return tx.isCompleted;
    } catch (e) {
      return false;
    }
  }

  static Duration _maxDuration(Duration a, Duration b) => a > b ? a : b;

  static bool _hasCompletedEvent(TransactionOnNetwork tx) {
    final logs = tx.logs;
    if (logs == null) return false;
    for (final event in logs.events) {
      final String id = event.identifier;
      if (id == 'completedTxEvent' || id == 'SCDeploy' || id == 'signalError') {
        return true;
      }
    }
    return false;
  }

  /// Closes HTTP client and frees resources.
  void close() {
    _networkProvider.close();
  }
}
