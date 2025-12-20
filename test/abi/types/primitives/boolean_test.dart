import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('BooleanType', () {
    test('works as singleton with correct name', () {
      expect(BooleanType.type, same(BooleanType.type));
      expect(BooleanType.type.name, 'bool');
    });
  });

  group('BooleanValue', () {
    test('creates and handles boolean values', () {
      final trueVal = BooleanType.create(true);
      expect(trueVal.value, true);
      expect(trueVal.nativeValue, true);

      final falseVal = BooleanType.create(false);
      expect(falseVal.value, false);
      expect(falseVal.nativeValue, false);
    });

    test('encodes to bytes correctly', () {
      final trueVal = BooleanValue(true);
      final falseVal = BooleanValue(false);
      expect(trueVal.toBytes(), [1]);
      expect(falseVal.toBytes(), [0]);
    });

    test('equality works correctly', () {
      final a = BooleanValue(true);
      final b = BooleanValue(true);
      final c = BooleanValue(false);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
