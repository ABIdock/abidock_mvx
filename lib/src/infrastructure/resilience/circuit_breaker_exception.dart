/// Exception thrown when circuit breaker is in open state and rejects requests.
/// Indicates the protected service is temporarily unavailable.
class CircuitBreakerOpenException implements Exception {
  /// Creates circuit breaker open exception.
  ///
  /// #### Parameters
  /// - `message` - Error message
  /// - `lastFailureTime` - Timestamp of last failure
  /// - `retryDelay` - Duration until recovery attempt
  CircuitBreakerOpenException(
    this.message,
    this.lastFailureTime,
    this.retryDelay,
  );

  /// Error message.
  final String message;

  /// Last failure time.
  final DateTime lastFailureTime;

  /// Wait time before attempting recovery.
  final Duration retryDelay;

  @override
  String toString() {
    final int timeSinceFailure = DateTime.now()
        .difference(lastFailureTime)
        .inSeconds;
    final int retryIn = retryDelay.inSeconds - timeSinceFailure;
    return 'CircuitBreakerOpenException: $message '
        '(retry in ${retryIn > 0 ? retryIn : 0}s)';
  }
}
