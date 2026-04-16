import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('RequestThrottle', () {
    test('allows bursts up to capacity without delay', () async {
      final throttle = RequestThrottle(capacity: 5, refillPerSecond: 10);
      final start = DateTime.now();
      for (int i = 0; i < 5; i++) {
        await throttle.acquire();
      }
      final elapsed = DateTime.now().difference(start);
      expect(elapsed.inMilliseconds, lessThan(100));
    });

    test('throttles beyond capacity until refill', () async {
      final throttle = RequestThrottle(capacity: 1, refillPerSecond: 20);
      await throttle.acquire();
      final start = DateTime.now();
      await throttle.acquire();
      final elapsed = DateTime.now().difference(start);
      expect(elapsed.inMilliseconds, greaterThanOrEqualTo(40));
    });

    test('rejects invalid parameters', () {
      expect(
        () => RequestThrottle(capacity: 0, refillPerSecond: 10),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => RequestThrottle(capacity: 1, refillPerSecond: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
