/// Resilience patterns for robust blockchain network operations.
///
/// Provides circuit breakers, retry mechanisms, and failure handling
/// for reliable communication with blockchain networks.
/// );
///
/// try {
///   final result = await circuitBreaker.execute(() => apiClient.getData());
///   print('Data: $result');
/// } on CircuitBreakerException {
///   print('Service unavailable - circuit is open');
/// }
///
/// // Retry with exponential backoff
/// final retryHelper = RetryHelper(
///   RetryConfig(
///     maxAttempts: 3,
///     initialDelay: Duration(milliseconds: 100),
///     maxDelay: Duration(seconds: 5),
///   ),
/// );
///
/// final data = await retryHelper.execute(() => fetchData());
/// ```
export 'circuit_breaker.dart';
export 'circuit_breaker_exception.dart';
export 'circuit_state.dart';
export 'retry_helper.dart'; // includes RetryConfig
