import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('I16Type', () {
    test('singleton instance', () {
      final type1 = I16Type.type;
      final type2 = I16Type.type;
      expect(identical(type1, type2), isTrue);
    });
    test('type name', () {
      expect(I16Type.type.name, 'i16');
    });
  });
  group('I16Value', () {
    test('creates from valid values', () {
      expect(I16Type.create(0).nativeValue, 0);
      expect(I16Type.create(1000).nativeValue, 1000);
      expect(I16Type.create(-1000).nativeValue, -1000);
    });
    test('min and max values', () {
      expect(I16Type.create(-32768).nativeValue, -32768);
      expect(I16Type.create(32767).nativeValue, 32767);
    });
    test('throws on out of range positive values', () {
      expect(() => I16Type.create(32768), throwsArgumentError);
      expect(() => I16Type.create(50000), throwsArgumentError);
    });
    test('throws on out of range negative values', () {
      expect(() => I16Type.create(-32769), throwsArgumentError);
      expect(() => I16Type.create(-50000), throwsArgumentError);
    });
    test('value equality', () {
      final value1 = I16Type.create(-1000);
      final value2 = I16Type.create(-1000);
      final value3 = I16Type.create(1000);
      expect(value1.nativeValue, value2.nativeValue);
      expect(value1.nativeValue, isNot(value3.nativeValue));
    });
    test('toBytes encoding', () {
      final value = I16Type.create(-1000);
      final bytes = value.toBytes();
      expect(bytes, isA<List<int>>());
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}
