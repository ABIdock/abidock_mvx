import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('AccountStorageEntry', () {
    test('hex value is preserved untouched', () {
      const AccountStorageEntry entry = AccountStorageEntry(
        key: '6b657931',
        value: '68656c6c6f',
      );
      expect(entry.key, equals('6b657931'));
      expect(entry.value, equals('68656c6c6f'));
    });

    test('decodedValue returns the UTF-8 interpretation of hex value', () {
      const AccountStorageEntry entry = AccountStorageEntry(
        key: 'key',
        value: '68656c6c6f',
      );
      expect(entry.decodedValue, equals('hello'));
    });

    test('decodedValue handles empty value', () {
      const AccountStorageEntry entry = AccountStorageEntry(
        key: 'key',
        value: '',
      );
      expect(entry.decodedValue, equals(''));
    });

    test('decodedValue is lenient on malformed hex bytes', () {
      const AccountStorageEntry entry = AccountStorageEntry(
        key: 'key',
        value: 'ff',
      );
      expect(entry.decodedValue, isA<String>());
    });

    test('fromHttpResponse reads value from JSON payload', () {
      final AccountStorageEntry entry = AccountStorageEntry.fromHttpResponse(
        <String, dynamic>{'value': '776f726c64'},
        'mykey',
      );
      expect(entry.key, equals('mykey'));
      expect(entry.value, equals('776f726c64'));
      expect(entry.decodedValue, equals('world'));
    });
  });
}
