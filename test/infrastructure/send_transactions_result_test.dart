import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('SendTransactionsResult', () {
    test('successfulHashes filters out nulls', () {
      const result = SendTransactionsResult(
        numSent: 2,
        txHashes: <String?>['a', null, 'b'],
      );
      expect(result.successfulHashes, <String>['a', 'b']);
    });

    test('numFailed derives from total - sent', () {
      const result = SendTransactionsResult(
        numSent: 1,
        txHashes: <String?>['a', null, null],
      );
      expect(result.numFailed, 2);
    });

    test('failures surfaces only SendTxFailure entries', () {
      const result = SendTransactionsResult(
        numSent: 1,
        txHashes: <String?>['h1', null],
        outcomes: <SendTxOutcome>[
          SendTxSuccess(0, 'h1'),
          SendTxFailure(1, reason: 'nonce mismatch'),
        ],
      );

      expect(result.failures.length, 1);
      expect(result.failures.first.index, 1);
      expect(result.failures.first.reason, 'nonce mismatch');
    });

    test('failures returns empty when no outcomes provided', () {
      const result = SendTransactionsResult(
        numSent: 1,
        txHashes: <String?>['a'],
      );
      expect(result.failures, isEmpty);
    });
  });
}
