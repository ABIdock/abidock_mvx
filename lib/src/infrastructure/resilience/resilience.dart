/// Resilience patterns for robust blockchain network operations.
///
/// Provides circuit breakers, retry mechanisms, and failure handling
/// for reliable communication with blockchain networks.
///
/// #### Example
/// ```dart
/// final CircuitBreaker circuitBreaker = CircuitBreaker(
///   failureThreshold: 3,
///   timeout: const Duration(seconds: 10),
/// );
///
/// try {
///   final dynamic result = await circuitBreaker.execute(
///     () => provider.doGetGeneric('network/config'),
///   );
///   print('Data: $result');
/// } on CircuitBreakerOpenException {
///   print('Service unavailable - circuit is open');
/// }
///
/// final RetryHelper retryHelper = RetryHelper(
///   config: const RetryConfig(
///     maxRetries: 3,
///     initialDelay: Duration(milliseconds: 100),
///     maxDelay: Duration(seconds: 5),
///   ),
/// );
///
/// final dynamic data = await retryHelper.execute(
///   operation: () => provider.doGetGeneric('network/config'),
///   isRetryable: RetryHelper.isTransientError,
///   operationName: 'getNetworkConfig',
/// );
/// ```
library;

export 'circuit_breaker.dart';
export 'circuit_breaker_exception.dart';
export 'circuit_state.dart';
export 'request_throttle.dart';
export 'retry_helper.dart';
