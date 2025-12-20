import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('U32Type', () {
    test('singleton instance', () {
      expect(U32Type.type, same(U32Type.type));
    });
    test('type name', () {
      expect(U32Type.type.name, 'u32');
    });
  });
  group('U32Value', () {
    test('creates value from int', () {
      final value = U32Type.create(42);
      expect(value.value, 42);
    });
    test('creates zero value', () {
      final value = U32Type.create(0);
      expect(value.value, 0);
    });
    test('creates max value', () {
      const max = 0xFFFFFFFF;
      final value = U32Type.create(max);
      expect(value.value, max);
    });
    test('validates range', () {
      expect(() => U32Type.create(-1), throwsA(isA<ArgumentError>()));
      expect(() => U32Type.create(0x100000000), throwsA(isA<ArgumentError>()));
    });
    test('equality', () {
      final a = U32Type.create(42);
      final b = U32Type.create(42);
      final c = U32Type.create(100);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
    test('toString', () {
      final value = U32Type.create(42);
      expect(value.toString(), contains('42'));
    });
  });
}
