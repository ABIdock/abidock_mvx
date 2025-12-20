import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('I64Type', () {
    test('singleton instance', () {
      final type1 = I64Type.type;
      final type2 = I64Type.type;
      expect(identical(type1, type2), isTrue);
    });
    test('type name', () {
      expect(I64Type.type.name, 'i64');
    });
  });
  group('I64Value', () {
    test('creates from valid values', () {
      expect(I64Type.create(0).nativeValue, BigInt.zero);
      expect(I64Type.create(1000000000).nativeValue, BigInt.from(1000000000));
      expect(I64Type.create(-1000000000).nativeValue, BigInt.from(-1000000000));
    });
    test('min and max values', () {
      expect(
        I64Type.type
            .createValue(BigInt.parse('-9223372036854775808'))
            .nativeValue,
        BigInt.parse('-9223372036854775808'),
      );
      expect(
        I64Type.type
            .createValue(BigInt.parse('9223372036854775807'))
            .nativeValue,
        BigInt.parse('9223372036854775807'),
      );
    });
    test('throws on out of range positive values', () {
      expect(
        () => I64Type.create(BigInt.parse('9223372036854775808')),
        throwsArgumentError,
      );
    });
    test('throws on out of range negative values', () {
      expect(
        () => I64Type.create(BigInt.parse('-9223372036854775809')),
        throwsArgumentError,
      );
    });
    test('value equality', () {
      final value1 = I64Type.create(-1000000000);
      final value2 = I64Type.create(-1000000000);
      final value3 = I64Type.create(1000000000);
      expect(value1.nativeValue, value2.nativeValue);
      expect(value1.nativeValue, isNot(value3.nativeValue));
    });
    test('toBytes encoding', () {
      final value = I64Type.create(-1000000000);
      final bytes = value.toBytes();
      expect(bytes, isA<List<int>>());
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}
