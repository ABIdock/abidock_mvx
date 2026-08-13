import 'dart:async';
import 'dart:math';

import '../../utils/sdk_exceptions.dart';
import '../logging/logger.dart';

const Set<int> _retriableStatusCodes = <int>{408, 429, 500, 502, 503, 504};

/// Configuration for retry logic with exponential backoff.
class RetryConfig {
  /// Creates retry configuration with exponential backoff parameters.
  ///
  /// #### Parameters
  /// - `maxRetries` - Maximum retry attempts (default 3)
  /// - `initialDelay` - Delay before first retry (default 1s)
  /// - `maxDelay` - Maximum delay between retries (default 30s)
  /// - `backoffMultiplier` - Exponential backoff multiplier (default 2.0)
  /// - `timeout` - Timeout for each attempt (default 30s)
  /// - `jitterFactor` - Random jitter factor 0.0-1.0 to prevent thundering herd (default 0.1)
  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.timeout = const Duration(seconds: 30),
    this.jitterFactor = 0.1,
  });

  /// Maximum retry attempts.
  final int maxRetries;

  /// Initial delay before first retry.
  final Duration initialDelay;

  /// Maximum delay between retries.
  final Duration maxDelay;

  /// Multiplier for exponential backoff.
  final double backoffMultiplier;

  /// Timeout for each request attempt.
  final Duration timeout;

  /// Random jitter factor (0.0-1.0) to add variability to delays.
  /// Helps prevent thundering herd when multiple clients retry simultaneously.
  final double jitterFactor;
}

/// Helper for executing operations with automatic retry and exponential backoff.
/// Retries failed operations with configurable backoff strategy and timeout per attempt.
class RetryHelper {
  RetryHelper({required this.config, this._logger});
  final Logger? _logger;
  final RetryConfig config;

  /// Executes operation with retry logic and exponential backoff.
  ///
  /// #### Parameters
  /// - `operation` - Async operation to execute
  /// - `isRetryable` - Predicate to determine if error is retryable
  /// - `operationName` - Name for logging (e.g., 'fetchAccount')
  /// - `context` - Additional context for logging (optional)
  ///
  /// #### Returns
  /// `T` - Result of the operation
  ///
  /// #### Throws
  /// - Last error if all retries exhausted or error is non-retryable
  Future<T> execute<T>({
    required Future<T> Function() operation,
    required bool Function(Object error) isRetryable,
    required String operationName,
    Map<String, dynamic>? context,
  }) async {
    int attempt = 0;
    Duration delay = config.initialDelay;

    while (true) {
      attempt++;

      try {
        _logger?.debug(
          'Attempting $operationName',
          context: <String, dynamic>{
            'attempt': attempt,
            'maxRetries': config.maxRetries,
            ...?context,
          },
        );

        final T result = await operation().timeout(config.timeout);

        if (attempt > 1) {
          _logger?.info(
            '$operationName succeeded after retry',
            context: <String, dynamic>{'attempts': attempt, ...?context},
          );
        }

        return result;
      } on TimeoutException {
        _logger?.warning(
          '$operationName timed out',
          context: <String, dynamic>{
            'attempt': attempt,
            'timeout': '${config.timeout.inSeconds}s',
            ...?context,
          },
        );

        if (attempt >= config.maxRetries) {
          _logger?.error(
            '$operationName failed after all retries',
            context: <String, dynamic>{
              'totalAttempts': attempt,
              'reason': 'timeout',
              ...?context,
            },
          );
          rethrow;
        }
        await _delayBeforeRetry(delay, attempt, operationName, context);
        delay = _calculateNextDelay(delay);
      } catch (e) {
        if (!isRetryable(e) || attempt >= config.maxRetries) {
          _logger?.error(
            '$operationName failed',
            context: <String, dynamic>{
              'attempt': attempt,
              'retryable': isRetryable(e),
              'error': e.toString(),
              ...?context,
            },
          );
          rethrow;
        }

        _logger?.warning(
          '$operationName failed, will retry',
          context: <String, dynamic>{
            'attempt': attempt,
            'maxRetries': config.maxRetries,
            'nextRetryIn': '${delay.inSeconds}s',
            'error': e.toString(),
            ...?context,
          },
        );

        await _delayBeforeRetry(delay, attempt, operationName, context);
        delay = _calculateNextDelay(delay);
      }
    }
  }

  /// Delays execution before retry with exponential backoff.
  Future<void> _delayBeforeRetry(
    Duration delay,
    int attempt,
    String operationName,
    Map<String, dynamic>? context,
  ) async {
    _logger?.debug(
      'Waiting before retry',
      context: <String, dynamic>{
        'delay': '${delay.inSeconds}s',
        'attempt': attempt,
        'operation': operationName,
        ...?context,
      },
    );

    await Future<void>.delayed(delay);
  }

  /// Calculates next delay using exponential backoff with jitter.
  ///
  /// Clamps the base delay to maxDelay before adding jitter so the
  /// final delay never exceeds maxDelay plus the jitter allowance.
  Duration _calculateNextDelay(Duration currentDelay) {
    final int baseDelayMs =
        (currentDelay.inMilliseconds * config.backoffMultiplier).round();

    final int clampedBaseMs = baseDelayMs > config.maxDelay.inMilliseconds
        ? config.maxDelay.inMilliseconds
        : baseDelayMs;

    final int jitterMs =
        (clampedBaseMs * config.jitterFactor * _random.nextDouble()).round();
    final int delayWithJitterMs = clampedBaseMs + jitterMs;

    final Duration nextDelay = Duration(milliseconds: delayWithJitterMs);

    return nextDelay > config.maxDelay ? config.maxDelay : nextDelay;
  }

  static final Random _random = Random();

  /// Default retry predicate for common transient network and server errors.
  ///
  /// #### Parameters
  /// - `error` - Error object to check
  ///
  /// #### Returns
  /// `bool` - True if error appears to be transient
  static bool isTransientError(Object error) {
    if (error is NetworkException) {
      final int? code = error.statusCode;
      if (code != null) {
        return _retriableStatusCodes.contains(code);
      }
    }

    final String errorString = error.toString().toLowerCase();
    if (errorString.contains('socketexception') ||
        errorString.contains('connection') ||
        errorString.contains('network') ||
        errorString.contains('timeout')) {
      return true;
    }

    if (errorString.contains('apiexception')) {
      final RegExpMatch? statusCodeMatch = RegExp(r'apiexception\((\d+)\)')
          .firstMatch(errorString);
      if (statusCodeMatch != null) {
        final int? statusCode = int.tryParse(statusCodeMatch.group(1) ?? '');
        if (statusCode != null && _retriableStatusCodes.contains(statusCode)) {
          return true;
        }
      }
    }

    return false;
  }
}
