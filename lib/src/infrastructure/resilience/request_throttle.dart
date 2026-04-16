import 'dart:async';

/// Token-bucket throttle for outbound HTTP traffic.
///
/// Limits the rate at which wrapped calls may reach a shared downstream
/// (e.g. `api.multiversx.com`'s ~30 rps per-IP ceiling). Use it to smooth
/// bursts that would otherwise trigger 429s.
///
/// #### Example
/// ```dart
/// final throttle = RequestThrottle(capacity: 30, refillPerSecond: 25);
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
