import 'dart:async';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('RetryHelper.execute', () {
    test('returns result on first success without retrying', () async {
      final helper = RetryHelper(
        config: const RetryConfig(
          maxRetries: 3,
          initialDelay: Duration(milliseconds: 1),
        ),
      );

      int calls = 0;
      final result = await helper.execute<int>(
        operation: () async {
          calls++;
          return 42;
        },
        isRetryable: RetryHelper.isTransientError,
        operationName: 'ok',
      );

      expect(result, 42);
      expect(calls, 1);
    });

    test('retries transient failures until success', () async {
      final helper = RetryHelper(
        config: const RetryConfig(
          maxRetries: 3,
          initialDelay: Duration(milliseconds: 1),
          maxDelay: Duration(milliseconds: 5),
        ),
      );

      int attempts = 0;
      final result = await helper.execute<int>(
        operation: () async {
          attempts++;
          if (attempts < 3) {
            throw const NetworkException(
              'transient',
              statusCode: 503,
              endpoint: '',
            );
          }
          return 7;
        },
        isRetryable: RetryHelper.isTransientError,
        operationName: 'flaky',
      );

      expect(result, 7);
      expect(attempts, 3);
    });

    test('gives up after maxRetries', () async {
      final helper = RetryHelper(
        config: const RetryConfig(
          maxRetries: 2,
          initialDelay: Duration(milliseconds: 1),
        ),
      );

      int attempts = 0;
      await expectLater(
        helper.execute<int>(
          operation: () async {
            attempts++;
            throw const NetworkException(
              'transient',
              statusCode: 503,
              endpoint: '',
            );
          },
          isRetryable: RetryHelper.isTransientError,
          operationName: 'doomed',
        ),
        throwsA(isA<NetworkException>()),
      );

      expect(attempts, 2);
    });

    test('does not retry non-retryable errors', () async {
      final helper = RetryHelper(
        config: const RetryConfig(
          maxRetries: 5,
          initialDelay: Duration(milliseconds: 1),
        ),
      );

      int attempts = 0;
      await expectLater(
        helper.execute<int>(
          operation: () async {
            attempts++;
            throw ArgumentError('bad input');
          },
          isRetryable: RetryHelper.isTransientError,
          operationName: 'bad',
        ),
        throwsArgumentError,
      );

      expect(attempts, 1);
    });
  });

  group('RetryHelper.execute / rate limiting', () {
    test('stops a permanently rate-limited call after maxRetries '
        'attempts', () async {
      final helper = RetryHelper(
        config: const RetryConfig(
          maxRetries: 4,
          initialDelay: Duration(milliseconds: 1),
          maxDelay: Duration(milliseconds: 5),
        ),
      );

      int attempts = 0;
      Object? thrown;
      final stopwatch = Stopwatch()..start();

      try {
        await helper.execute<int>(
          operation: () async {
            attempts++;
            throw const NetworkException(
              'Too Many Requests',
              statusCode: 429,
              endpoint: '/accounts',
            );
          },
          isRetryable: RetryHelper.isTransientError,
          operationName: 'rateLimited',
        );
      } catch (e) {
        thrown = e;
      }
      stopwatch.stop();

      expect(attempts, 4);
      expect(thrown, isA<NetworkException>());
      expect((thrown! as NetworkException).statusCode, 429);
      expect(
        thrown.toString(),
        'NetworkException: Too Many Requests (HTTP 429) at /accounts',
      );
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('makes a single attempt when maxRetries is 1', () async {
      final helper = RetryHelper(
        config: const RetryConfig(
          maxRetries: 1,
          initialDelay: Duration(milliseconds: 1),
        ),
      );

      int attempts = 0;
      await expectLater(
        helper.execute<int>(
          operation: () async {
            attempts++;
            throw const NetworkException(
              'Too Many Requests',
              statusCode: 429,
              endpoint: '/accounts',
            );
          },
          isRetryable: RetryHelper.isTransientError,
          operationName: 'rateLimitedOnce',
        ),
        throwsA(isA<NetworkException>()),
      );

      expect(attempts, 1);
    });

    test('backs off between rate-limited attempts', () async {
      final helper = RetryHelper(
        config: const RetryConfig(
          maxRetries: 3,
          initialDelay: Duration(milliseconds: 40),
          maxDelay: Duration(milliseconds: 200),
        ),
      );

      int attempts = 0;
      final stopwatch = Stopwatch()..start();

      await expectLater(
        helper.execute<int>(
          operation: () async {
            attempts++;
            throw const NetworkException(
              'Too Many Requests',
              statusCode: 429,
              endpoint: '/accounts',
            );
          },
          isRetryable: RetryHelper.isTransientError,
          operationName: 'backoff',
        ),
        throwsA(isA<NetworkException>()),
      );
      stopwatch.stop();

      expect(attempts, 3);
      expect(
        stopwatch.elapsedMilliseconds,
        greaterThanOrEqualTo(120),
        reason: 'waits 40ms then 80ms between the three attempts',
      );
    });
  });

  group('RetryHelper.isTransientError', () {
    test('flags 408/429/5xx status codes', () {
      for (final int code in <int>[408, 429, 500, 502, 503, 504]) {
        expect(
          RetryHelper.isTransientError(
            NetworkException('x', statusCode: code, endpoint: ''),
          ),
          isTrue,
        );
      }
    });

    test('rejects 400/404 client errors', () {
      expect(
        RetryHelper.isTransientError(
          const NetworkException('x', statusCode: 400, endpoint: ''),
        ),
        isFalse,
      );
      expect(
        RetryHelper.isTransientError(
          const NetworkException('x', statusCode: 404, endpoint: ''),
        ),
        isFalse,
      );
    });

    test('matches socket/connection/timeout strings', () {
      expect(
        RetryHelper.isTransientError(
          Exception('SocketException: Failed host lookup'),
        ),
        isTrue,
      );
      expect(RetryHelper.isTransientError(TimeoutException('x')), isTrue);
    });
  });
}
