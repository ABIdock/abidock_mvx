import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('NothingType', () {
    test('has correct name', () {
      final type = NothingType.type;
      expect(type.name, 'Nothing');
    });
    test('has zero size', () {
      final type = NothingType.type;
      expect(type.sizeInBytes, 0);
    });
    test('singleton returns same instance', () {
      final type1 = NothingType.type;
      final type2 = NothingType.type;
      expect(identical(type1, type2), isTrue);
    });
    test('creates value from null', () {
      final type = NothingType.type;
      final value = type.createValue(null);
      expect(value, isA<NothingValue>());
    });
    test('accepts any value', () {
      final type = NothingType.type;
      expect(() => type.createValue(42), returnsNormally);
      expect(() => type.createValue('test'), returnsNormally);
      expect(() => type.createValue([1, 2, 3]), returnsNormally);
    });
  });
  group('NothingValue', () {
    test('has null native value', () {
      final value = NothingValue();
      expect(value.nativeValue, isNull);
    });
    test('encodes to empty bytes', () {
      final value = NothingValue();
      final encoded = value.toBytes();
      expect(encoded, isEmpty);
    });
    test('has correct type', () {
      final value = NothingValue();
      expect(value.type, NothingType.type);
    });
    test('multiple instances are independent', () {
      final value1 = NothingValue();
      final value2 = NothingValue();
      expect(identical(value1, value2), isFalse);
    });
  });
}
