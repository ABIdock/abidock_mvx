import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('OptionType', () {
    test('type_creation_with_inner_type', () {
      final optionType = OptionType(U32Type.type);
      expect(optionType.name, contains('Option'));
      expect(optionType.innerType, equals(U32Type.type));
    });

    test('createValue_some_and_none', () {
      final optionType = OptionType(U32Type.type);
      final someValue = optionType.createValue(42);
      final noneValue = optionType.createValue(null);
      expect(someValue.nativeValue, isNotNull);
      expect(noneValue.nativeValue, isNull);
    });
  });
}
