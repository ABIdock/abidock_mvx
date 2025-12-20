import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('I8Type', () {
    test('singleton instance', () {
      final type1 = I8Type.type;
      final type2 = I8Type.type;
      expect(identical(type1, type2), isTrue);
    });
    test('type name', () {
      expect(I8Type.type.name, 'i8');
    });
  });
  group('I8Value', () {
    test('creates from valid values', () {
      expect(I8Type.create(0).nativeValue, 0);
      expect(I8Type.create(42).nativeValue, 42);
      expect(I8Type.create(-42).nativeValue, -42);
    });
    test('min and max values', () {
      expect(I8Type.create(-128).nativeValue, -128);
      expect(I8Type.create(127).nativeValue, 127);
    });
    test('throws on out of range positive values', () {
      expect(() => I8Type.create(128), throwsArgumentError);
      expect(() => I8Type.create(200), throwsArgumentError);
    });
    test('throws on out of range negative values', () {
      expect(() => I8Type.create(-129), throwsArgumentError);
      expect(() => I8Type.create(-200), throwsArgumentError);
    });
    test('value equality', () {
      final value1 = I8Type.create(-42);
      final value2 = I8Type.create(-42);
      final value3 = I8Type.create(42);
      expect(value1.nativeValue, value2.nativeValue);
      expect(value1.nativeValue, isNot(value3.nativeValue));
    });
    test('toBytes encoding', () {
      final value = I8Type.create(-42);
      final bytes = value.toBytes();
      expect(bytes, isA<List<int>>());
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}
