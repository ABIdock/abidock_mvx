import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('I32Type', () {
    test('singleton instance', () {
      final type1 = I32Type.type;
      final type2 = I32Type.type;
      expect(identical(type1, type2), isTrue);
    });
    test('type name', () {
      expect(I32Type.type.name, 'i32');
    });
  });
  group('I32Value', () {
    test('creates from valid values', () {
      expect(I32Type.create(0).nativeValue, 0);
      expect(I32Type.create(1000000).nativeValue, 1000000);
      expect(I32Type.create(-1000000).nativeValue, -1000000);
    });
    test('min and max values', () {
      expect(I32Type.create(-2147483648).nativeValue, -2147483648);
      expect(I32Type.create(2147483647).nativeValue, 2147483647);
    });
    test('throws on out of range positive values', () {
      expect(() => I32Type.create(2147483648), throwsArgumentError);
      expect(() => I32Type.create(3000000000), throwsArgumentError);
    });
    test('throws on out of range negative values', () {
      expect(() => I32Type.create(-2147483649), throwsArgumentError);
      expect(() => I32Type.create(-3000000000), throwsArgumentError);
    });
    test('value equality', () {
      final value1 = I32Type.create(-1000000);
      final value2 = I32Type.create(-1000000);
      final value3 = I32Type.create(1000000);
      expect(value1.nativeValue, value2.nativeValue);
      expect(value1.nativeValue, isNot(value3.nativeValue));
    });
    test('toBytes encoding', () {
      final value = I32Type.create(-1000000);
      final bytes = value.toBytes();
      expect(bytes, isA<List<int>>());
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}
