import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('Mnemonic Generation & Validation', () {
    test('generates valid 24-word mnemonic', () {
      final mnemonic = Mnemonic.generate();
      final words = mnemonic.getWords();
      expect(words, hasLength(24));
      expect(words.every((word) => word.isNotEmpty), isTrue);
      expect(Mnemonic.isValid(words.join(' ')), isTrue);
    });

    test('validates correct mnemonic phrases', () {
      const validPhrase24 =
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon art';
      const validPhrase12 =
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';

      expect(Mnemonic.isValid(validPhrase24), isTrue);
      expect(Mnemonic.isValid(validPhrase12), isTrue);
      expect(Mnemonic.isValid('invalid phrase'), isFalse);
    });

    test('creates mnemonic from valid phrase', () {
      const validPhrase =
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';
      final mnemonic = Mnemonic.fromString(validPhrase);
      final words = mnemonic.getWords();
      expect(words, hasLength(12));
      expect(words.first, equals('abandon'));
      expect(words.last, equals('about'));
    });
  });

  group('Key Derivation', () {
    test('derives deterministic keys for multiple accounts', () async {
      const phrase =
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';
      final mnemonic = Mnemonic.fromString(phrase);

      final key0 = await mnemonic.deriveKey(addressIndex: 0);
      final key1 = await mnemonic.deriveKey(addressIndex: 1);

      expect(key0.hex, isNot(equals(key1.hex)));
      expect(key0.bytes.length, equals(32));
      expect(key1.bytes.length, equals(32));

      final sameKey0 = await mnemonic.deriveKey(addressIndex: 0);
      expect(key0.hex, equals(sameKey0.hex));
    });

    test('supports BIP39 passwords', () async {
      final mnemonic = Mnemonic.generate();
      final keyNoPass = await mnemonic.deriveKey(addressIndex: 0);
      final keyWithPass = await mnemonic.deriveKey(
        addressIndex: 0,
        password: 'secret-passphrase',
      );
      expect(keyNoPass.hex, isNot(equals(keyWithPass.hex)));
    });
  });

  group('Security & Integration', () {
    test('provides proper memory management', () {
      final mnemonic = Mnemonic.generate();
      final words1 = mnemonic.getWords();
      final words2 = mnemonic.getWords();
      expect(words1, equals(words2));
      expect(identical(words1, words2), isFalse);
      expect(() => mnemonic.dispose(), returnsNormally);
    });

    test('works end-to-end for transaction signing', () async {
      final mnemonic = Mnemonic.generate();
      final key = await mnemonic.deriveKey(addressIndex: 0);
      final publicKey = await key.generatePublicKey();
      final address = publicKey.toAddress();

      expect(address.bech32.startsWith('erd1'), isTrue);
      expect(address.bech32.length, equals(62));

      final message = Uint8List.fromList('Hello MultiversX'.codeUnits);
      final signature = await key.sign(message);
      final isValid = await publicKey.verify(message, signature);
      expect(isValid, isTrue);
    });
  });
}
