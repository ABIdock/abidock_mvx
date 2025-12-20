import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('ListType', () {
    test('element_type_handling', () {
      final listType = ListType(U32Type.type);
      expect(listType.name, contains('List'));
      expect(listType.elementType, equals(U32Type.type));
    });

    test('createValue_operations', () {
      final listType = ListType(U32Type.type);
      final value = listType.createValue([10, 20, 30]);
      expect(value.nativeValue.length, 3);

      final empty = listType.createValue([]);
      expect(empty.nativeValue, isEmpty);
    });
  });
}
