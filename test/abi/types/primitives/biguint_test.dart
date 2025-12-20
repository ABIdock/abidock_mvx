import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('BigUIntType', () {
    test('singleton instance', () {
      final type1 = BigUIntType.type;
      final type2 = BigUIntType.type;
      expect(identical(type1, type2), isTrue);
    });
    test('type name', () {
      expect(BigUIntType.type.name, 'BigUint');
    });
  });
  group('BigUIntValue', () {
    test('creates from valid values', () {
      expect(BigUIntType.create(0).nativeValue, BigInt.zero);
      expect(BigUIntType.create(42).nativeValue, BigInt.from(42));
    });
    test('handles large positive values', () {
      final largeValue = BigInt.parse('123456789012345678901234567890');
      expect(BigUIntType.create(largeValue).nativeValue, largeValue);
    });
    test('throws on negative values', () {
      expect(() => BigUIntType.create(-1), throwsArgumentError);
      expect(() => BigUIntType.create(BigInt.from(-100)), throwsArgumentError);
    });
    test('value equality', () {
      final value1 = BigUIntType.create(BigInt.from(1000000));
      final value2 = BigUIntType.create(BigInt.from(1000000));
      final value3 = BigUIntType.create(BigInt.from(2000000));
      expect(value1.nativeValue, value2.nativeValue);
      expect(value1.nativeValue, isNot(value3.nativeValue));
    });
    test('toBytes encoding', () {
      final value = BigUIntType.create(BigInt.from(1000000));
      final bytes = value.toBytes();
      expect(bytes, isA<List<int>>());
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}
