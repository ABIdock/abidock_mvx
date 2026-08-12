/// Tests for the shared hex helper used by the transaction factories.
///
/// `evenHexInt` must produce even-length lower-case hex without a `0x`
/// prefix, matching the MultiversX `@`-delimited data wire format.
import 'package:abidock_mvx/src/core/transaction/factories/_factory_helpers.dart';
import 'package:test/test.dart';

void main() {
  group('evenHexInt', () {
    test('zero pads to two chars', () {
      expect(evenHexInt(0), equals('00'));
    });

    test('single hex digit pads to two', () {
      expect(evenHexInt(5), equals('05'));
    });

    test('two hex digits unchanged', () {
      expect(evenHexInt(255), equals('ff'));
    });

    test('three hex digits pads to four', () {
      expect(evenHexInt(256), equals('0100'));
    });

    test('large value', () {
      expect(evenHexInt(0xDEADBEEF), equals('deadbeef'));
    });

    test('odd-length values are zero-padded on the left', () {
      expect(evenHexInt(0xABC), equals('0abc'));
    });

    test('output is always even-length', () {
      for (int i = 0; i < 1000; i++) {
        final String hex = evenHexInt(i);
        expect(hex.length.isEven, isTrue, reason: 'i=$i hex=$hex');
      }
    });
  });
}
