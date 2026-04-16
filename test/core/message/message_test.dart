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

  group('SignableMessage', () {
    test('should create signable message with auto and custom parameters', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final signable = SignableMessage.fromMessage('Hello');
      final after = DateTime.now().millisecondsSinceEpoch;

      expect(signable.timestamp, greaterThanOrEqualTo(before));
      expect(signable.timestamp, lessThanOrEqualTo(after));
      expect(signable.nonce, isNotNull);
      expect(signable.bytes.length, equals(32));

      const customTimestamp = 1640995200000;
      const customNonce = 'test-nonce-123';
      final customSignable = SignableMessage.fromMessage(
        'Hello',
        timestamp: customTimestamp,
        nonce: customNonce,
        chainId: 'T',
        recipient:
            'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
      );
      expect(customSignable.timestamp, equals(customTimestamp));
      expect(customSignable.nonce, equals(customNonce));
      expect(customSignable.chainId, equals('T'));
    });

    test('should provide replay protection with different parameters', () {
      final signable1 = SignableMessage.fromMessage(
        'Hello',
        timestamp: 1000000,
        nonce: 'nonce1',
      );
      final signable2 = SignableMessage.fromMessage(
        'Hello',
        timestamp: 2000000,
        nonce: 'nonce1',
      );
      final signable3 = SignableMessage.fromMessage(
        'Hello',
        timestamp: 1000000,
        nonce: 'nonce2',
      );

      expect(signable1.bytes, isNot(equals(signable2.bytes)));
      expect(signable1.bytes, isNot(equals(signable3.bytes)));

      final identical1 = SignableMessage.fromMessage(
        'Hello',
        timestamp: 1000000,
        nonce: 'same',
      );
      final identical2 = SignableMessage.fromMessage(
        'Hello',
        timestamp: 1000000,
        nonce: 'same',
      );
      expect(identical1.bytes, equals(identical2.bytes));

      final auto1 = SignableMessage.fromMessage('Hello');
      final auto2 = SignableMessage.fromMessage('Hello');
      expect(auto1.nonce, isNot(equals(auto2.nonce)));
    });

    test(
      'should produce consistent 32-byte Keccak256 digest and handle edge cases',
      () {
        final signable = SignableMessage.fromMessage('Hello');
        expect(signable.bytes.length, equals(32));

        final empty = SignableMessage.fromMessage('');
        expect(empty.bytes.length, equals(32));

        final large = SignableMessage.fromMessage('A' * 10000);
        expect(large.bytes.length, equals(32));

        const timestamp = 1640995200000;
        const nonce = 'integration-test-nonce';
        final recreated1 = SignableMessage.fromMessage(
          'Test',
          timestamp: timestamp,
          nonce: nonce,
        );
        final recreated2 = SignableMessage.fromMessage(
          'Test',
          timestamp: timestamp,
          nonce: nonce,
        );
        expect(recreated1.bytes, equals(recreated2.bytes));
      },
    );
  });
}
