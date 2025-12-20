import 'dart:typed_data';

import 'package:abidock_mvx/src/wallet/crypto/decryptor.dart';
import 'package:abidock_mvx/src/wallet/crypto/encrypted_data.dart';
import 'package:abidock_mvx/src/wallet/crypto/encryptor.dart';
import 'package:test/test.dart';

void main() {
  group('Encryptor', () {
    group('encrypt', () {
      test('produces valid encrypted data', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        final encrypted = Encryptor.encrypt(data, 'password');

        expect(encrypted.version, equals(4));
        expect(encrypted.ciphertext, isNotEmpty);
        expect(encrypted.iv, isNotEmpty);
        expect(encrypted.mac, isNotEmpty);
        expect(encrypted.salt, isNotEmpty);
        expect(encrypted.cipher, equals('aes-128-ctr'));
        expect(encrypted.kdf, equals('scrypt'));
      });

      test('produces unique output for same input', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        final encrypted1 = Encryptor.encrypt(data, 'password');
        final encrypted2 = Encryptor.encrypt(data, 'password');

        expect(encrypted1.salt, isNot(equals(encrypted2.salt)));
        expect(encrypted1.iv, isNot(equals(encrypted2.iv)));
        expect(encrypted1.ciphertext, isNot(equals(encrypted2.ciphertext)));
      });

      test('handles empty data', () {
        final data = Uint8List(0);
        final encrypted = Encryptor.encrypt(data, 'password');
        expect(encrypted.ciphertext, isEmpty);
      });

      test('handles empty password', () {
        final data = Uint8List.fromList([1, 2, 3]);
        final encrypted = Encryptor.encrypt(data, '');
        expect(encrypted.ciphertext, isNotEmpty);
      });

      test('handles large data', () {
        final data = Uint8List.fromList(List.filled(10000, 42));
        final encrypted = Encryptor.encrypt(data, 'password');
        expect(encrypted.ciphertext, isNotEmpty);
      });

      test('handles unicode password', () {
        final data = Uint8List.fromList([1, 2, 3]);
        final encrypted = Encryptor.encrypt(data, 'пароль密码🔐');
        expect(encrypted.ciphertext, isNotEmpty);
      });
    });

    group('encryptWithBytes', () {
      test('produces same result structure as encrypt', () {
        final data = Uint8List.fromList([1, 2, 3]);
        final password = Uint8List.fromList('password'.codeUnits);
        final encrypted = Encryptor.encryptWithBytes(data, password);

        expect(encrypted.version, equals(4));
        expect(encrypted.ciphertext, isNotEmpty);
      });
    });
  });

  group('Decryptor', () {
    group('decrypt', () {
      test('decrypts encrypted data correctly', () {
        final original = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
        final encrypted = Encryptor.encrypt(original, 'test_password');
        final decrypted = Decryptor.decrypt(encrypted, 'test_password');
        expect(decrypted, equals(original));
      });

      test('round-trip preserves data', () {
        final testData = [
          Uint8List.fromList([]),
          Uint8List.fromList([0]),
          Uint8List.fromList([255]),
          Uint8List.fromList(List.generate(32, (i) => i)),
          Uint8List.fromList(List.filled(100, 42)),
        ];

        for (final original in testData) {
          final encrypted = Encryptor.encrypt(original, 'password');
          final decrypted = Decryptor.decrypt(encrypted, 'password');
          expect(decrypted, equals(original));
        }
      });

      test('throws on wrong password', () {
        final data = Uint8List.fromList([1, 2, 3]);
        final encrypted = Encryptor.encrypt(data, 'correct');
        expect(() => Decryptor.decrypt(encrypted, 'wrong'), throwsA(anything));
      });

      test('throws on tampered ciphertext', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        final encrypted = Encryptor.encrypt(data, 'password');
        final tampered = EncryptedData(
          version: encrypted.version,
          id: encrypted.id,
          ciphertext: 'deadbeef${encrypted.ciphertext}',
          iv: encrypted.iv,
          cipher: encrypted.cipher,
          kdf: encrypted.kdf,
          kdfparams: encrypted.kdfparams,
          mac: encrypted.mac,
          salt: encrypted.salt,
        );
        expect(
          () => Decryptor.decrypt(tampered, 'password'),
          throwsA(anything),
        );
      });

      test('throws on tampered mac', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        final encrypted = Encryptor.encrypt(data, 'password');
        final tampered = EncryptedData(
          version: encrypted.version,
          id: encrypted.id,
          ciphertext: encrypted.ciphertext,
          iv: encrypted.iv,
          cipher: encrypted.cipher,
          kdf: encrypted.kdf,
          kdfparams: encrypted.kdfparams,
          mac: 'deadbeef' * 8,
          salt: encrypted.salt,
        );
        expect(
          () => Decryptor.decrypt(tampered, 'password'),
          throwsA(anything),
        );
      });
    });

    group('decryptWithBytes', () {
      test('decrypts using byte password', () {
        final original = Uint8List.fromList([10, 20, 30]);
        final password = Uint8List.fromList('password'.codeUnits);
        final encrypted = Encryptor.encryptWithBytes(original, password);
        final decrypted = Decryptor.decryptWithBytes(encrypted, password);
        expect(decrypted, equals(original));
      });
    });
  });

  group('Encryption Integration', () {
    test('32-byte key encryption for wallet', () {
      final secretKey = Uint8List.fromList(List.generate(32, (i) => i));
      final encrypted = Encryptor.encrypt(secretKey, 'wallet_password');
      final decrypted = Decryptor.decrypt(encrypted, 'wallet_password');
      expect(decrypted, equals(secretKey));
    });

    test('64-byte seed phrase encryption', () {
      final seed = Uint8List.fromList(List.generate(64, (i) => i * 2 % 256));
      final encrypted = Encryptor.encrypt(seed, 'secure123');
      final decrypted = Decryptor.decrypt(encrypted, 'secure123');
      expect(decrypted, equals(seed));
    });

    test('handles high entropy passwords', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final password = String.fromCharCodes(List.generate(64, (i) => 33 + i));
      final encrypted = Encryptor.encrypt(data, password);
      final decrypted = Decryptor.decrypt(encrypted, password);
      expect(decrypted, equals(data));
    });
  });
}
