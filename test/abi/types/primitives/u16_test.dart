import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('U16Type', () {
    test('singleton instance', () {
      final type1 = U16Type.type;
      final type2 = U16Type.type;
      expect(identical(type1, type2), isTrue);
    });
    test('type name', () {
      expect(U16Type.type.name, 'u16');
    });
  });
  group('U16Value', () {
    test('creates from valid values', () {
      expect(U16Type.create(0).nativeValue, 0);
      expect(U16Type.create(1000).nativeValue, 1000);
      expect(U16Type.create(65535).nativeValue, 65535);
    });
    test('min and max values', () {
      expect(U16Type.create(0).nativeValue, 0);
      expect(U16Type.create(65535).nativeValue, 65535);
    });
    test('throws on negative values', () {
      expect(() => U16Type.create(-1), throwsArgumentError);
    });
    test('throws on out of range values', () {
      expect(() => U16Type.create(65536), throwsArgumentError);
      expect(() => U16Type.create(100000), throwsArgumentError);
    });
    test('value equality', () {
      final value1 = U16Type.create(1000);
      final value2 = U16Type.create(1000);
      final value3 = U16Type.create(2000);
      expect(value1.nativeValue, value2.nativeValue);
      expect(value1.nativeValue, isNot(value3.nativeValue));
    });
    test('toBytes encoding', () {
      final value = U16Type.create(65535);
      final bytes = value.toBytes();
      expect(bytes, isA<List<int>>());
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}
