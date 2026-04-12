/// Wallet encryption using AES-128-CTR cipher with Scrypt KDF and HMAC-SHA256 MAC.
/// Provides password-based encryption with automatic memory zeroing for security.
import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:pointycastle/export.dart';

import 'constants.dart';
import 'crypto_utils.dart';
import 'derivation_params.dart';
import 'encrypted_data.dart';
import 'randomness.dart';

/// Keystore encryption version.
enum EncryptorVersion {
  /// Version 4 keystore format (current standard).
  v4(4);

  final int value;
  const EncryptorVersion(this.value);
}

/// Encrypts wallet data using password-based encryption with Scrypt and AES-128-CTR.
/// Provides methods for key derivation, encryption, and MAC computation.
class Encryptor {
  /// Encrypts data with password using AES-128-CTR and Scrypt.
  ///
  /// #### Parameters
  /// - `data` - Data to encrypt
  /// - `password` - Encryption password
  /// - `randomness` - Optional custom randomness source
  ///
  /// #### Returns
  /// `EncryptedData` - Encrypted data with ciphertext, IV, salt, and MAC
  static EncryptedData encrypt(
    Uint8List data,
    String password, {
    Randomness? randomness,
  }) {
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    try {
      return encryptWithBytes(data, passwordBytes, randomness: randomness);
    } finally {
      passwordBytes.fillRange(0, passwordBytes.length, 0);
    }
  }

  /// Encrypts data with password bytes for secure memory handling.
  ///
  /// #### Parameters
  /// - `data` - Data to encrypt
  /// - `passwordBytes` - Password as UTF-8 bytes
  /// - `randomness` - Optional custom randomness source
  ///
  /// #### Returns
  /// `EncryptedData` - Encrypted data with ciphertext, IV, salt, and MAC
  static EncryptedData encryptWithBytes(
    Uint8List data,
    Uint8List passwordBytes, {
    Randomness? randomness,
  }) {
    randomness ??= Randomness();

    Uint8List? derivedKey;
    Uint8List? derivedKeyFirstHalf;
    Uint8List? derivedKeySecondHalf;

    try {
      final ScryptKeyDerivationParams kdParams = ScryptKeyDerivationParams();
      derivedKey = kdParams.generateDerivedKey(passwordBytes, randomness.salt);

      derivedKeyFirstHalf = derivedKey.sublist(0, 16);
      derivedKeySecondHalf = derivedKey.sublist(16, 32);

      final StreamCipher cipher = _createCipher(
        derivedKeyFirstHalf,
        randomness.iv,
      );
      final Uint8List ciphertext = cipher.process(data);
      final Uint8List mac = CryptoUtils.computeHmacSha256(
        derivedKeySecondHalf,
        ciphertext,
      );

      return EncryptedData(
        version: EncryptorVersion.v4.value,
        id: randomness.id,
        ciphertext: hex.encode(ciphertext),
        iv: hex.encode(randomness.iv),
        cipher: cipherAlgorithm,
        kdf: keyDerivationFunction,
        kdfparams: kdParams,
        mac: hex.encode(mac),
        salt: hex.encode(randomness.salt),
      );
    } finally {
      derivedKey?.fillRange(0, derivedKey.length, 0);
      derivedKeyFirstHalf?.fillRange(0, derivedKeyFirstHalf.length, 0);
      derivedKeySecondHalf?.fillRange(0, derivedKeySecondHalf.length, 0);
    }
  }

  static StreamCipher _createCipher(Uint8List key, Uint8List iv) {
    final StreamCipher cipher = StreamCipher('AES/CTR');
    final ParametersWithIV<KeyParameter> params =
        ParametersWithIV<KeyParameter>(KeyParameter(key), iv);
    cipher.init(true, params);
    return cipher;
  }
}
