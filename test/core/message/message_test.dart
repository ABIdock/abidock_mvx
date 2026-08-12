import 'dart:convert';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('Message', () {
    test(
      'should create message from bytes and handle different data types',
      () {
        final bytes = utf8.encode('Hello');
        final message = Message(bytes);
        expect(message.bytes, equals(bytes));
        expect(message.bytes.length, equals(5));

        final emptyMessage = Message(const <int>[]);
        expect(emptyMessage.bytes, isEmpty);

        const unicode = '🔒 Login with €100 💰';
        final unicodeBytes = utf8.encode(unicode);
        final unicodeMessage = Message(unicodeBytes);
        final decoded = utf8.decode(unicodeMessage.bytes);
        expect(decoded, equals(unicode));
      },
    );
  });
}
