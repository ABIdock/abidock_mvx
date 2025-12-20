import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('AddressType', () {
    test('works as singleton with correct name', () {
      expect(AddressType.type, same(AddressType.type));
      expect(AddressType.type.name, 'Address');
    });
  });

  group('AddressValue', () {
    test('creates from different formats', () {
      final bech32Value = AddressType.create(
        'erd1qqqqqqqqqqqqqpgqhe8t5jewej70zupmh44jurgn29psua5l2jps3ntjj3',
      );
      expect(bech32Value.value.length, 32);

      final hexValue = AddressType.create(
        '0000000000000000050000000000000000000001000000000000000000000064',
      );
      expect(hexValue.value.length, 32);

      final bytesValue = AddressType.create(List<int>.filled(32, 0));
      expect(bytesValue.value.length, 32);
    });

    test('handles zero address', () {
      expect(AddressValue.zero.value.length, 32);
      expect(AddressValue.zero.value.every((b) => b == 0), true);
    });

    test('validates address length', () {
      expect(
        () => AddressValue(List<int>.filled(31, 0)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('converts to different formats', () {
      final value = AddressValue(List<int>.filled(32, 0));

      final bech32 = value.toBech32();
      expect(bech32, startsWith('erd1'));

      final hex = value.toHex();
      expect(hex.length, 64);
    });

    test('roundtrip conversion works', () {
      const original =
          'erd1qqqqqqqqqqqqqpgqhe8t5jewej70zupmh44jurgn29psua5l2jps3ntjj3';
      final value = AddressValue.fromBech32(original);
      final roundtrip = value.toBech32();
      expect(roundtrip, original);
    });
  });
}
