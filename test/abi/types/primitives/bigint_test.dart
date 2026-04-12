import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('BigIntType', () {
    test('singleton instance', () {
      final type1 = BigIntType.type;
      final type2 = BigIntType.type;
      expect(identical(type1, type2), isTrue);
    });
    test('type name', () {
      expect(BigIntType.type.name, 'BigInt');
    });
  });
  group('BigIntValue', () {
    test('creates from valid values', () {
      expect(BigIntType.create(0).nativeValue, BigInt.zero);
      expect(BigIntType.create(42).nativeValue, BigInt.from(42));
      expect(BigIntType.create(-42).nativeValue, BigInt.from(-42));
    });
    test('handles large positive values', () {
      final largeValue = BigInt.parse('123456789012345678901234567890');
      expect(BigIntType.create(largeValue).nativeValue, largeValue);
    });
    test('handles large negative values', () {
      final largeNegative = BigInt.parse('-123456789012345678901234567890');
      expect(BigIntType.create(largeNegative).nativeValue, largeNegative);
    });
    test('value equality', () {
      final value1 = BigIntType.create(BigInt.from(1000000));
      final value2 = BigIntType.create(BigInt.from(1000000));
      final value3 = BigIntType.create(BigInt.from(2000000));
      expect(value1.nativeValue, value2.nativeValue);
      expect(value1.nativeValue, isNot(value3.nativeValue));
    });
    test('toBytes encoding', () {
      final value = BigIntType.create(BigInt.from(1000000));
      final bytes = value.toBytes();
      expect(bytes, isA<List<int>>());
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}
