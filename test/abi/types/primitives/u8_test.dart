import 'package:abidock_mvx/src/abi/types/primitives/numerical.dart';
import 'package:test/test.dart';

void main() {
  group('U8Type', () {
    test('singleton instance', () {
      final type1 = U8Type.type;
      final type2 = U8Type.type;
      expect(identical(type1, type2), isTrue);
    });
    test('type name', () {
      expect(U8Type.type.name, 'u8');
    });
  });
  group('U8Value', () {
    test('creates from valid values', () {
      expect(U8Type.create(0).nativeValue, 0);
      expect(U8Type.create(127).nativeValue, 127);
      expect(U8Type.create(255).nativeValue, 255);
    });
    test('min and max values', () {
      expect(U8Type.create(0).nativeValue, 0);
      expect(U8Type.create(255).nativeValue, 255);
    });
    test('throws on negative values', () {
      expect(() => U8Type.create(-1), throwsArgumentError);
    });
    test('throws on out of range values', () {
      expect(() => U8Type.create(256), throwsArgumentError);
      expect(() => U8Type.create(1000), throwsArgumentError);
    });
    test('value equality', () {
      final value1 = U8Type.create(42);
      final value2 = U8Type.create(42);
      final value3 = U8Type.create(43);
      expect(value1.nativeValue, value2.nativeValue);
      expect(value1.nativeValue, isNot(value3.nativeValue));
    });
    test('toBytes encoding', () {
      final value = U8Type.create(255);
      final bytes = value.toBytes();
      expect(bytes, isA<List<int>>());
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}
