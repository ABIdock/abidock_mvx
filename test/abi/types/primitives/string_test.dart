import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('StringType', () {
    test('works as singleton with correct name', () {
      expect(StringType.type, same(StringType.type));
      expect(StringType.type.name, 'string');
    });
  });

  group('StringValue', () {
    test('creates and handles strings correctly', () {
      final value = StringType.create('Hello');
      expect(value.value, 'Hello');
      expect(value.nativeValue, 'Hello');

      final empty = StringType.create('');
      expect(empty.value, '');

      final unicode = StringType.create('Hello ??');
      expect(unicode.value, 'Hello ??');
    });

    test('encodes to bytes correctly', () {
      final value = StringValue('Hello');
      final bytes = value.toBytes();
      expect(bytes, [72, 101, 108, 108, 111]);
    });

    test('equality works correctly', () {
      final a = StringValue('test');
      final b = StringValue('test');
      final c = StringValue('other');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
