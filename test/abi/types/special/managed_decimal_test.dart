import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('ManagedDecimalType', () {
    test('type_creation', () {
      final unsignedType = ManagedDecimalType.of(2);
      expect(unsignedType.name, contains('ManagedDecimal'));
      expect(unsignedType.isSigned, isFalse);
      expect(unsignedType.isVariable, isFalse);

      final signedType = ManagedDecimalType.signed(4);
      expect(signedType.isSigned, isTrue);
    });

    test('validation_errors', () {
      expect(() => ManagedDecimalType.of(-1), throwsArgumentError);
      expect(() => ManagedDecimalType.of(256), throwsArgumentError);
    });
  });

  group('ManagedDecimalValue', () {
    test('fromDouble_creation', () {
      final value = ManagedDecimalValue.fromDouble(19.99, scale: 2);
      expect(value.nativeValue, BigInt.from(1999));
      expect(double.parse(value.toDecimalString()), closeTo(19.99, 0.01));
      expect(value.scale, 2);
    });

    test('fromString_creation', () {
      final value = ManagedDecimalValue.fromString('19.99', scale: 2);
      expect(double.parse(value.toDecimalString()), closeTo(19.99, 0.01));
    });

    test('toDecimalString_conversion', () {
      final value = ManagedDecimalValue.fromDouble(19.99, scale: 2);
      expect(value.toDecimalString(), '19.99');
    });

    test('signed_value_handling', () {
      final signedType = ManagedDecimalType.signed(2);
      final negativeValue =
          signedType.createValue(-19.99) as ManagedDecimalValue;
      expect(
        double.parse(negativeValue.toDecimalString()),
        closeTo(-19.99, 0.01),
      );

      final unsignedType = ManagedDecimalType.of(2);
      expect(() => unsignedType.createValue(-19.99), throwsArgumentError);
    });
  });
}
