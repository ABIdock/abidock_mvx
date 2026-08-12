import 'dart:async';

/// Token-bucket throttle for outbound HTTP traffic.
///
/// Limits the rate at which wrapped calls may reach a shared downstream. The
/// public MultiversX hosts enforce per-IP ceilings at the edge — 50 requests
/// per second on the Gateway hosts, 2 per second on the mainnet API host and 5
/// on the devnet API host — and answer 429 above them. Sizing the bucket to
/// the ceiling smooths bursts that would otherwise be rejected.
///
/// A provider wires one of these automatically when
/// `NetworkProviderConfig.throttlePolicy` is enabled; construct it directly
/// only to throttle calls this SDK does not make.
///
/// #### Example
/// ```dart
/// final throttle = RequestThrottle(capacity: 50, refillPerSecond: 50);
/// await throttle.acquire();
/// final response = await dio.get(url);
/// ```
class RequestThrottle {
  RequestThrottle({required this.capacity, required this.refillPerSecond})
    : assert(capacity > 0),
      assert(refillPerSecond > 0),
      _tokens = capacity,
      _lastRefill = DateTime.now();

  /// Maximum burst allowed before throttling kicks in.
  final int capacity;

  /// Tokens replenished per second.
  final double refillPerSecond;

  int _tokens;
  DateTime _lastRefill;

  /// Acquires one token, waiting if the bucket is empty.
  Future<void> acquire() async {
    while (true) {
      _refill();
      if (_tokens > 0) {
        _tokens--;
        return;
      }
      final int ms = (1000 / refillPerSecond).ceil();
      await Future<void>.delayed(Duration(milliseconds: ms));
    }
  }

  void _refill() {
    final DateTime now = DateTime.now();
    final double elapsed = now.difference(_lastRefill).inMilliseconds / 1000.0;
    final int earned = (elapsed * refillPerSecond).floor();
    if (earned > 0) {
      _tokens = (_tokens + earned).clamp(0, capacity);
      _lastRefill = now;
    }
  }
}
