import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('TupleType', () {
    test('field_types_handling', () {
      final tupleType = TupleType([U32Type.type, BooleanType.type]);
      expect(tupleType.name, contains('Tuple'));
      expect(tupleType.fieldDefinitions.length, 2);
    });

    test('createValue_operations', () {
      final tupleType = TupleType([U32Type.type, BooleanType.type]);
      final value = tupleType.createValue([42, true]);
      expect(value.nativeValue, isA<List>());
      expect(value.nativeValue.length, 2);
    });
  });
}
