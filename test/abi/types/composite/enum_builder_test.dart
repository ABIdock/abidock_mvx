import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('EnumBuilder', () {
    test('variant_simple_creation', () {
      final enumType = EnumBuilder(
        'Status',
      ).variant('Pending', 0).variant('Active', 1).build();
      expect(enumType.variants.length, 2);
      expect(enumType.variants[0].name, 'Pending');
      expect(enumType.variants[1].discriminant, 1);
    });

    test('variantWithFields_creation', () {
      final enumType = EnumBuilder('Result').variant('Ok', 0).variantWithFields(
        'Error',
        1,
        [U32Type.type, StringType.type],
      ).build();
      expect(enumType.variants[1].fieldCount, 2);
    });

    test('build_validation_duplicate_names', () {
      expect(
        () => EnumBuilder(
          'Duplicate',
        ).variant('Same', 0).variant('Same', 1).build(),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('build_validation_duplicate_discriminants', () {
      expect(
        () => EnumBuilder(
          'Duplicate',
        ).variant('First', 0).variant('Second', 0).build(),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('createValue_from_built_enum', () {
      final enumType = EnumBuilder(
        'Status',
      ).variant('Pending', 0).variant('Active', 1).build();
      final pending = enumType.createValue('Pending');
      final active = enumType.createValue('Active');
      expect(pending.nativeValue, 'Pending');
      expect(active.nativeValue, 'Active');
    });

    test('integration_with_struct_builder', () {
      final statusType = EnumBuilder(
        'Status',
      ).variant('Active', 0).variant('Inactive', 1).build();
      final accountType = StructBuilder('Account')
          .field('id', U64Type.type)
          .field('status', statusType)
          .field('balance', BigUIntType.type)
          .build();
      expect(accountType.fieldDefinitions[1].type, statusType);
    });
  });
}
