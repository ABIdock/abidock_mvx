/// Pinning test for the canonical MultiversX message-signing prefix.
///
/// This test exists because the `messagePrefix` / `canonicalMessagePrefix`
/// constants were once silently regressed from `'\x17Elrond Signed Message:\n'`
/// (with spaces, 23 chars matching the 0x17 length byte) to the wrong
/// `'\x17ElrondSignedMessage:\n'` (no spaces, 21 chars). That regression
/// invalidated every off-chain message signed here, because verification on
/// xPortal, Ledger, the Web Wallet and the chain itself would fail.
///
/// If you have a "good reason" to change these constants — stop. The reason
/// is almost certainly wrong. The value is fixed by the on-chain signature
/// verifier: the prefix bytes are part of what gets hashed.
import 'dart:convert';

import 'package:abidock_mvx/src/core/message/base.dart';
import 'package:abidock_mvx/src/core/message/message_computer.dart';
import 'package:test/test.dart';

void main() {
  group('MessagePrefix canonical value (pinning)', () {
    test('messagePrefix is exactly the spaced Elrond Signed Message form', () {
      expect(messagePrefix, equals('\x17Elrond Signed Message:\n'));
    });

    test('canonicalMessagePrefix matches messagePrefix', () {
      expect(canonicalMessagePrefix, equals(messagePrefix));
    });

    test('leading byte is 0x17 and equals the suffix length', () {
      final List<int> bytes = utf8.encode(messagePrefix);
      expect(bytes.first, equals(0x17));
      expect(bytes.length - 1, equals(0x17));
      expect(bytes.length, equals(24));
    });

    test('suffix ASCII is "Elrond Signed Message:\\n"', () {
      expect(messagePrefix.substring(1), equals('Elrond Signed Message:\n'));
    });
  });
}
