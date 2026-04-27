import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:convert/convert.dart' as convert;
import 'package:test/test.dart';

Uint8List _bytes(String s) => Uint8List.fromList(convert.hex.decode(s));

Future<UserSecretKey> _keyFrom(String hex) async {
  return UserSecretKey(_bytes(hex));
}

void main() {
  group('PubkeyEncryptor end-to-end', () {
    test('Alice encrypts a message that Bob can decrypt', () async {
      final UserSecretKey aliceSk = await _keyFrom(
        '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
      );
      final UserSecretKey bobSk = await _keyFrom(
        '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb',
      );
      final UserPublicKey bobPk = await bobSk.generatePublicKey();

      final Uint8List plaintext = Uint8List.fromList(
        utf8.encode('Secret MultiversX message'),
      );

      final X25519EncryptedData encrypted = await PubkeyEncryptor.encrypt(
        plaintext,
        bobPk,
        aliceSk,
      );

      expect(encrypted.version, 1);
      expect(encrypted.cipher, 'x25519-xsalsa20-poly1305');

      final Uint8List decrypted = await PubkeyDecryptor.decrypt(
        encrypted,
        bobSk,
      );
      expect(utf8.decode(decrypted), 'Secret MultiversX message');
    });

    test('decryption fails with the wrong recipient key', () async {
      final UserSecretKey alice = await _keyFrom(
        'c5aa8df43f9f837bedb7442f31dcb7b166d38535076f094b85ce3a2e0b4458f7',
      );
      final UserSecretKey bob = await _keyFrom(
        '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
      );
      final UserSecretKey eve = await _keyFrom(
        '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb',
      );
      final UserPublicKey bobPk = await bob.generatePublicKey();

      final X25519EncryptedData encrypted = await PubkeyEncryptor.encrypt(
        Uint8List.fromList(utf8.encode('for bob only')),
        bobPk,
        alice,
      );

      await expectLater(
        PubkeyDecryptor.decrypt(encrypted, eve),
        throwsA(isA<DecryptorException>()),
      );
    });

    test('decryption fails when the signature is tampered', () async {
      final UserSecretKey alice = await _keyFrom(
        '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
      );
      final UserSecretKey bob = await _keyFrom(
        '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb',
      );
      final UserPublicKey bobPk = await bob.generatePublicKey();

      final X25519EncryptedData encrypted = await PubkeyEncryptor.encrypt(
        Uint8List.fromList(utf8.encode('hello')),
        bobPk,
        alice,
      );
      final Uint8List macBytes = _bytes(encrypted.mac);
      macBytes[0] ^= 0xFF;
      final X25519EncryptedData tampered = X25519EncryptedData(
        version: encrypted.version,
        nonce: encrypted.nonce,
        cipher: encrypted.cipher,
        ciphertext: encrypted.ciphertext,
        mac: convert.hex.encode(macBytes),
        identities: encrypted.identities,
      );

      await expectLater(
        PubkeyDecryptor.decrypt(tampered, bob),
        throwsA(isA<DecryptorException>()),
      );
    });

    test('decryption fails when the ciphertext is tampered', () async {
      final UserSecretKey alice = await _keyFrom(
        '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
      );
      final UserSecretKey bob = await _keyFrom(
        '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb',
      );
      final UserPublicKey bobPk = await bob.generatePublicKey();

      final X25519EncryptedData encrypted = await PubkeyEncryptor.encrypt(
        Uint8List.fromList(utf8.encode('cleartext is secret')),
        bobPk,
        alice,
      );
      final Uint8List ctBytes = _bytes(encrypted.ciphertext);
      ctBytes[0] ^= 0x01;
      final X25519EncryptedData tampered = X25519EncryptedData(
        version: encrypted.version,
        nonce: encrypted.nonce,
        cipher: encrypted.cipher,
        ciphertext: convert.hex.encode(ctBytes),
        mac: encrypted.mac,
        identities: encrypted.identities,
      );

      await expectLater(
        PubkeyDecryptor.decrypt(tampered, bob),
        throwsA(isA<DecryptorException>()),
      );
    });

    test('empty payload roundtrips', () async {
      final UserSecretKey alice = await _keyFrom(
        '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
      );
      final UserSecretKey bob = await _keyFrom(
        '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb',
      );
      final UserPublicKey bobPk = await bob.generatePublicKey();

      final X25519EncryptedData encrypted = await PubkeyEncryptor.encrypt(
        Uint8List(0),
        bobPk,
        alice,
      );
      final Uint8List decrypted = await PubkeyDecryptor.decrypt(encrypted, bob);
      expect(decrypted, isEmpty);
    });

    test('long payload roundtrips', () async {
      final UserSecretKey alice = await _keyFrom(
        '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
      );
      final UserSecretKey bob = await _keyFrom(
        '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb',
      );
      final UserPublicKey bobPk = await bob.generatePublicKey();

      final Uint8List payload = Uint8List(4096);
      for (int i = 0; i < payload.length; i++) {
        payload[i] = (i * 13 + 7) & 0xFF;
      }

      final X25519EncryptedData encrypted = await PubkeyEncryptor.encrypt(
        payload,
        bobPk,
        alice,
      );
      final Uint8List decrypted = await PubkeyDecryptor.decrypt(encrypted, bob);
      expect(decrypted, orderedEquals(payload));
    });

    test('JSON serialization roundtrip', () async {
      final UserSecretKey alice = await _keyFrom(
        '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
      );
      final UserSecretKey bob = await _keyFrom(
        '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb',
      );
      final UserPublicKey bobPk = await bob.generatePublicKey();

      final X25519EncryptedData encrypted = await PubkeyEncryptor.encrypt(
        Uint8List.fromList(utf8.encode('serialization test')),
        bobPk,
        alice,
      );
      final String jsonStr = encrypted.toJsonString();
      final X25519EncryptedData reloaded = X25519EncryptedData.fromJsonString(
        jsonStr,
      );
      final Uint8List decrypted = await PubkeyDecryptor.decrypt(reloaded, bob);
      expect(utf8.decode(decrypted), 'serialization test');
    });
  });
}
