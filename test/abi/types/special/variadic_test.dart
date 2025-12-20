import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('VariadicType', () {
    test('type_creation_uncounted', () {
      final type = VariadicType.of(U32Type.type);
      expect(type.name, contains('variadic'));
      expect(type.itemType, U32Type.type);
      expect(type.isCounted, isFalse);
    });

    test('type_creation_counted', () {
      final type = VariadicType.counted(U32Type.type);
      expect(type.isCounted, isTrue);
    });

    test('createValue_from_list', () {
      final type = VariadicType.of(U32Type.type);
      final value = type.createValue([10, 20, 30]);
      expect(value, isA<VariadicValue>());
    });

    test('createValue_validation_error', () {
      final type = VariadicType.of(U32Type.type);
      expect(() => type.createValue(42), throwsArgumentError);
    });
  });

  group('VariadicValue', () {
    test('empty_list_handling', () {
      final type = VariadicType.of(U32Type.type);
      final value = type.createValue([]);
      final varValue = value as VariadicValue;
      expect(varValue.length, 0);
      expect(varValue.isEmpty, isTrue);
    });

    test('multiple_items_handling', () {
      final type = VariadicType.of(U32Type.type);
      final value = type.createValue([10, 20, 30]);
      final varValue = value as VariadicValue;
      expect(varValue.length, 3);
      expect((varValue[0] as U32Value).nativeValue, 10);
      expect((varValue[1] as U32Value).nativeValue, 20);
    });

    test('typed_value_conversion', () {
      final type = VariadicType.of(U32Type.type);
      final value = type.createValue([10, 20]);
      final varValue = value as VariadicValue;
      expect(varValue.items[0], isA<U32Value>());
      expect(varValue.items[1], isA<U32Value>());
    });
  });
}
