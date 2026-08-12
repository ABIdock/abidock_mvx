/// Pinning tests for [TransactionAwaitingOptions] defaults.
///
/// The defaults are tuned to the chain's inclusion latency:
///   * pollingInterval = 600 ms
///   * timeout         = 9 s   (= 15 polling intervals)
///   * patience        = 0 s
///
/// This package originally diverged with 400 ms / 60 s / 800 ms — leading to
/// either (a) premature timeouts in load tests, or (b) silent races where the
/// watcher returns before the SCR is committed. The pinning test exists
/// because this regression has happened once already.
///
/// DO NOT change these constants without bumping this package's major version:
/// callers time their flows around them.
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionAwaitingOptions canonical defaults (pinning)', () {
    const TransactionAwaitingOptions defaults = TransactionAwaitingOptions();

    test('pollingInterval defaults to 600ms', () {
      expect(
        defaults.pollingInterval,
        equals(const Duration(milliseconds: 600)),
      );
    });

    test('timeout defaults to 9s', () {
      expect(defaults.timeout, equals(const Duration(seconds: 9)));
    });

    test('patience defaults to zero', () {
      expect(defaults.patience, equals(Duration.zero));
    });

    test('timeout is exactly 15 polling intervals', () {
      expect(
        defaults.timeout.inMilliseconds,
        equals(defaults.pollingInterval.inMilliseconds * 15),
        reason:
            'The timeout is derived as `pollingInterval * 15`. Keep the same '
            'invariant if you ever change pollingInterval.',
      );
    });
  });
}
