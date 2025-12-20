import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('UserVerifier', () {
    test('should create verifier from public key and address', () async {
      final secretKey = UserSecretKey.generate();
      final publicKey = await secretKey.generatePublicKey();
      final verifier = UserVerifier(publicKey);
      expect(verifier.publicKey, equals(publicKey));

      final address = publicKey.toAddress();
      final addressVerifier = UserVerifier.fromAddress(address);
      expect(addressVerifier.publicKey.bytes, equals(address.bytes));

      const bech32 =
          'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th';
      final bech32Address = Address.fromBech32(bech32);
      final bech32Verifier = UserVerifier.fromAddress(bech32Address);
      expect(bech32Verifier.publicKey.bytes.length, equals(32));
    });

    test('should verify valid signatures and reject invalid ones', () async {
      final secretKey = UserSecretKey.generate();
      final publicKey = await secretKey.generatePublicKey();
      final verifier = UserVerifier(publicKey);
      final data = Uint8List.fromList(utf8.encode('Test data'));

      final signature = await secretKey.sign(data);
      final isValid = await verifier.verify(data, signature);
      expect(isValid, isTrue);

      final invalidSignature = Uint8List(64);
      final isInvalid = await verifier.verify(data, invalidSignature);
      expect(isInvalid, isFalse);

      final differentKey = UserSecretKey.generate();
      final wrongSignature = await differentKey.sign(data);
      final isWrong = await verifier.verify(data, wrongSignature);
      expect(isWrong, isFalse);

      final differentData = Uint8List.fromList(utf8.encode('Different data'));
      final isDataWrong = await verifier.verify(differentData, signature);
      expect(isDataWrong, isFalse);
    });

    test('should handle edge cases with empty and large data', () async {
      final secretKey = UserSecretKey.generate();
      final publicKey = await secretKey.generatePublicKey();
      final verifier = UserVerifier(publicKey);

      final emptyData = Uint8List(0);
      final emptySignature = await secretKey.sign(emptyData);
      final emptyValid = await verifier.verify(emptyData, emptySignature);
      expect(emptyValid, isTrue);

      final largeData = Uint8List(1024);
      for (int i = 0; i < largeData.length; i++) {
        largeData[i] = i % 256;
      }
      final largeSignature = await secretKey.sign(largeData);
      final largeValid = await verifier.verify(largeData, largeSignature);
      expect(largeValid, isTrue);
    });

    test('should verify message signatures with replay protection', () async {
      final mnemonic = Mnemonic.generate();
      final secretKey = await mnemonic.deriveKey(addressIndex: 0);
      final publicKey = await secretKey.generatePublicKey();
      final verifier = UserVerifier(publicKey);

      final message = SignableMessage.fromMessage('Login to dApp');
      final signature = await secretKey.sign(Uint8List.fromList(message.bytes));
      final isValid = await verifier.verify(
        Uint8List.fromList(message.bytes),
        signature,
      );
      expect(isValid, isTrue);

      final message1 = SignableMessage.fromMessage(
        'Same message',
        nonce: 'nonce1',
      );
      final message2 = SignableMessage.fromMessage(
        'Same message',
        nonce: 'nonce2',
      );
      final sig1 = await secretKey.sign(Uint8List.fromList(message1.bytes));
      final sig2 = await secretKey.sign(Uint8List.fromList(message2.bytes));

      expect(
        await verifier.verify(Uint8List.fromList(message1.bytes), sig1),
        isTrue,
      );
      expect(
        await verifier.verify(Uint8List.fromList(message2.bytes), sig2),
        isTrue,
      );
      expect(
        await verifier.verify(Uint8List.fromList(message1.bytes), sig2),
        isFalse,
      );
    });

    test(
      'should work in authentication workflow and multi-account scenarios',
      () async {
        final account1 = UserSecretKey.generate();
        final account2 = UserSecretKey.generate();
        final publicKey1 = await account1.generatePublicKey();
        final publicKey2 = await account2.generatePublicKey();

        final verifier1 = UserVerifier(publicKey1);
        final verifier2 = UserVerifier(publicKey2);

        final authMessage = SignableMessage.fromMessage('Authenticate user');
        final signature1 = await account1.sign(
          Uint8List.fromList(authMessage.bytes),
        );
        final signature2 = await account2.sign(
          Uint8List.fromList(authMessage.bytes),
        );

        expect(
          await verifier1.verify(
            Uint8List.fromList(authMessage.bytes),
            signature1,
          ),
          isTrue,
        );
        expect(
          await verifier2.verify(
            Uint8List.fromList(authMessage.bytes),
            signature2,
          ),
          isTrue,
        );
        expect(
          await verifier1.verify(
            Uint8List.fromList(authMessage.bytes),
            signature2,
          ),
          isFalse,
        );
        expect(
          await verifier2.verify(
            Uint8List.fromList(authMessage.bytes),
            signature1,
          ),
          isFalse,
        );

        final wrongLength = Uint8List(64);
        expect(
          await verifier1.verify(
            Uint8List.fromList(authMessage.bytes),
            wrongLength,
          ),
          isFalse,
        );
      },
    );
  });
}
