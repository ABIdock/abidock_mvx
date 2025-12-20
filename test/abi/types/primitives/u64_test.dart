import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('U64Type', () {
    test('singleton instance', () {
      final type1 = U64Type.type;
      final type2 = U64Type.type;
      expect(identical(type1, type2), isTrue);
    });
    test('type name', () {
      expect(U64Type.type.name, 'u64');
    });
  });
  group('U64Value', () {
    test('creates from valid values', () {
      expect(U64Type.create(0).nativeValue, BigInt.zero);
      expect(U64Type.create(1000000).nativeValue, BigInt.from(1000000));
      expect(
        U64Type.type
            .createValue(BigInt.parse('18446744073709551615'))
            .nativeValue,
        BigInt.parse('18446744073709551615'),
      );
    });
    test('min and max values', () {
      expect(U64Type.create(0).nativeValue, BigInt.zero);
      expect(
        U64Type.type
            .createValue(BigInt.parse('18446744073709551615'))
            .nativeValue,
        BigInt.parse('18446744073709551615'),
      );
    });
    test('throws on negative values', () {
      expect(() => U64Type.create(-1), throwsArgumentError);
      expect(() => U64Type.create(BigInt.from(-100)), throwsArgumentError);
    });
    test('throws on out of range values', () {
      expect(
        () => U64Type.create(BigInt.parse('18446744073709551616')),
        throwsArgumentError,
      );
    });
    test('value equality', () {
      final value1 = U64Type.create(1000000);
      final value2 = U64Type.create(1000000);
      final value3 = U64Type.create(2000000);
      expect(value1.nativeValue, value2.nativeValue);
      expect(value1.nativeValue, isNot(value3.nativeValue));
    });
    test('toBytes encoding', () {
      final value = U64Type.create(BigInt.parse('18446744073709551615'));
      final bytes = value.toBytes();
      expect(bytes, isA<List<int>>());
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}
