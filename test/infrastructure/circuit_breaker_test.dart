import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('CircuitBreaker', () {
    test('executes successful operations', () async {
      final breaker = CircuitBreaker(failureThreshold: 2);
      final result = await breaker.execute<int>(() async => 42);
      expect(result, 42);
      expect(breaker.isClosed, isTrue);
    });

    test('opens after consecutive failures', () async {
      final breaker = CircuitBreaker(failureThreshold: 2);

      await expectLater(
        breaker.execute<int>(() async => throw Exception('boom')),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        breaker.execute<int>(() async => throw Exception('boom')),
        throwsA(isA<Exception>()),
      );

      expect(breaker.isOpen, isTrue);
      await expectLater(
        breaker.execute<int>(() async => 1),
        throwsA(isA<CircuitBreakerOpenException>()),
      );
    });

    test('resets failure count on success', () async {
      final breaker = CircuitBreaker(failureThreshold: 3);

      await expectLater(
        breaker.execute<int>(() async => throw Exception('x')),
        throwsA(isA<Exception>()),
      );

      await breaker.execute<int>(() async => 1);
      expect(breaker.isClosed, isTrue);
    });

    test('half-open single-probe rejects concurrent calls', () async {
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        retryDelay: const Duration(milliseconds: 10),
      );

      await expectLater(
        breaker.execute<int>(() async => throw Exception('x')),
        throwsA(isA<Exception>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final probe = breaker.execute<int>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return 1;
      });
      await Future<void>.delayed(const Duration(milliseconds: 5));

      await expectLater(
        breaker.execute<int>(() async => 2),
        throwsA(isA<CircuitBreakerOpenException>()),
      );

      expect(await probe, 1);
    });
  });
}
