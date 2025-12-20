import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('StructType', () {
    test('field_definitions_handling', () {
      final userType = StructType(
        name: 'User',
        fieldDefinitions: [
          FieldDefinition(name: 'id', type: U32Type.type),
          FieldDefinition(name: 'name', type: StringType.type),
        ],
      );
      expect(userType.name, 'User');
      expect(userType.fieldDefinitions.length, 2);
    });

    test('createValue_operations', () {
      final userType = StructType(
        name: 'User',
        fieldDefinitions: [
          FieldDefinition(name: 'id', type: U32Type.type),
          FieldDefinition(name: 'name', type: StringType.type),
        ],
      );
      final userValue = userType.createValue({'id': 1, 'name': 'Alice'});
      expect(userValue.nativeValue, isA<Map>());
    });
  });
}
