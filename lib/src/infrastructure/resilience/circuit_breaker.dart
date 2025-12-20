import 'dart:async';

import 'circuit_breaker_exception.dart';
import 'circuit_state.dart';

/// Circuit breaker pattern for protecting external service calls from cascading failures.
/// Prevents repeated calls to failing services using closed, open, and half-open states.
class CircuitBreaker {
  /// Creates circuit breaker with failure tracking and recovery configuration.
  ///
  /// #### Parameters
  /// - `failureThreshold` - Consecutive failures before opening circuit (default 5)
  /// - `timeout` - Operation timeout duration (default 30s)
  /// - `retryDelay` - Wait time before attempting recovery (default 60s)
  /// - `onOpen` - Callback when circuit opens (optional)
  /// - `onClose` - Callback when circuit closes (optional)
  /// - `onHalfOpen` - Callback when circuit half-opens (optional)
  CircuitBreaker({
    this.failureThreshold = 3,
    this.timeout = const Duration(seconds: 10),
    this.retryDelay = const Duration(seconds: 15),
    this.onOpen,
    this.onClose,
    this.onHalfOpen,
  });

  /// Current circuit state.
  CircuitState _state = CircuitState.closed;

  /// Consecutive failure count.
  int _failureCount = 0;

  /// Last failure time.
  DateTime? _lastFailureTime;

  /// Last success time.
  DateTime? _lastSuccessTime;

  /// Failures before opening circuit.
  final int failureThreshold;

  /// Operation timeout.
  final Duration timeout;

  /// Wait time before attempting recovery.
  final Duration retryDelay;

  /// Callback when circuit opens.
  final void Function()? onOpen;

  /// Callback when circuit closes.
  final void Function()? onClose;

  /// Callback when circuit half-opens.
  final void Function()? onHalfOpen;

  /// Executes operation with circuit breaker protection.
  ///
  /// #### Parameters
  /// - `operation` - Async operation to execute
  ///
  /// #### Returns
  /// `T` - Result of the operation
  ///
  /// #### Throws
  /// - `CircuitBreakerOpenException` - Circuit is open, operation rejected
  /// - Original exception if operation fails
  Future<T> execute<T>(Future<T> Function() operation) async {
    if (_state == CircuitState.open) {
      if (_shouldAttemptReset()) {
        _transitionToHalfOpen();
      } else {
        throw CircuitBreakerOpenException(
          'Circuit breaker is open',
          _lastFailureTime!,
          retryDelay,
        );
      }
    }

    try {
      final T result = await operation().timeout(timeout);
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }

  /// Check if should attempt reset.
  bool _shouldAttemptReset() {
    if (_lastFailureTime == null) return false;
    return DateTime.now().difference(_lastFailureTime!) > retryDelay;
  }

  /// Transition to half-open state.
  void _transitionToHalfOpen() {
    _state = CircuitState.halfOpen;
    onHalfOpen?.call();
  }

  /// Handle successful operation.
  void _onSuccess() {
    _lastSuccessTime = DateTime.now();

    if (_state == CircuitState.halfOpen) {
      _failureCount = 0;
      _state = CircuitState.closed;
      onClose?.call();
    }
  }

  /// Handles failed operation.
  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_state == CircuitState.halfOpen) {
      _state = CircuitState.open;
      onOpen?.call();
    } else if (_failureCount >= failureThreshold) {
      _state = CircuitState.open;
      onOpen?.call();
    }
  }

  /// Gets current circuit state.
  CircuitState get state => _state;

  /// Gets consecutive failure count.
  int get failureCount => _failureCount;

  /// Checks if circuit is open.
  bool get isOpen => _state == CircuitState.open;

  /// Checks if circuit is closed.
  bool get isClosed => _state == CircuitState.closed;

  /// Checks if circuit is half-open.
  bool get isHalfOpen => _state == CircuitState.halfOpen;

  /// Manually resets circuit to closed state.
  void reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _lastFailureTime = null;
  }

  /// Gets current statistics about circuit breaker state.
  ///
  /// #### Returns
  /// `Map<String, dynamic>` - Circuit breaker statistics
  Map<String, dynamic> getStats() => <String, dynamic>{
    'state': _state.name,
    'failureCount': _failureCount,
    'lastFailureTime': _lastFailureTime?.toIso8601String(),
    'lastSuccessTime': _lastSuccessTime?.toIso8601String(),
  };
}
