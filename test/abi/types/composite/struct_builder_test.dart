import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('StructBuilder', () {
    test('field_addition_and_build', () {
      final structType = StructBuilder('Person')
          .field('name', StringType.type)
          .field('age', U32Type.type)
          .field('balance', BigUIntType.type)
          .build();

      expect(structType.name, 'Person');
      expect(structType.fieldDefinitions.length, 3);
      expect(structType.fieldDefinitions[1].type, U32Type.type);
    });

    test('nested_types_support', () {
      final addressType = StructBuilder(
        'Address',
      ).field('street', StringType.type).field('city', StringType.type).build();

      final personType = StructBuilder('PersonWithAddress')
          .field('name', StringType.type)
          .field('address', addressType)
          .field('numbers', ListType(U32Type.type))
          .build();

      expect(personType.fieldDefinitions[1].type, addressType);
      expect(personType.fieldDefinitions[2].type.name, 'List');
    });

    test('validation_and_value_creation', () {
      final structType = StructBuilder(
        'User',
      ).field('id', U64Type.type).field('active', BooleanType.type).build();

      expect(
        () => StructBuilder(
          'Duplicate',
        ).field('name', StringType.type).field('name', U32Type.type).build(),
        throwsA(isA<ArgumentError>()),
      );

      final value = structType.createValue({
        'id': BigInt.from(123),
        'active': true,
      });
      final map = value.nativeValue as Map;
      expect(map['id'], BigInt.from(123));
    });
  });
}
