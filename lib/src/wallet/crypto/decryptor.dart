/// Wallet decryption using AES-128-CTR cipher with Scrypt KDF and MAC verification.
/// Provides password-based decryption with automatic memory zeroing for security.
import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:pointycastle/export.dart';

import '../../utils/sdk_exceptions.dart';
import 'crypto_utils.dart';
import 'derivation_params.dart';
import 'encrypted_data.dart';

/// Decrypts wallet keystores using password-based decryption with Scrypt and AES-128-CTR.
/// Handles key derivation, MAC verification, and AES-CTR decryption.
class Decryptor {
  /// Decrypts encrypted data with password.
  ///
  /// #### Parameters
  /// - `data` - EncryptedData from keystore
  /// - `password` - Decryption password
  ///
  /// #### Returns
  /// `Uint8List` - Decrypted key bytes
  ///
  /// #### Throws
  /// - `DecryptorException` - If MAC verification fails
  static Uint8List decrypt(EncryptedData data, String password) {
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    try {
      return decryptWithBytes(data, passwordBytes);
    } finally {
      passwordBytes.fillRange(0, passwordBytes.length, 0);
    }
  }

  /// Decrypts encrypted data with password bytes for secure memory handling.
  ///
  /// #### Parameters
  /// - `data` - EncryptedData from keystore
  /// - `passwordBytes` - Password as UTF-8 bytes
  ///
  /// #### Returns
  /// `Uint8List` - Decrypted key bytes
  ///
  /// #### Throws
  /// - `DecryptorException` - If MAC verification fails
  static Uint8List decryptWithBytes(
    EncryptedData data,
    Uint8List passwordBytes,
  ) {
    final ScryptKeyDerivationParams kdfparams = data.kdfparams;
    final Uint8List salt = Uint8List.fromList(hex.decode(data.salt));
    final Uint8List iv = Uint8List.fromList(hex.decode(data.iv));
    final Uint8List ciphertext = Uint8List.fromList(
      hex.decode(data.ciphertext),
    );

    Uint8List? derivedKey;
    Uint8List? derivedKeyFirstHalf;
    Uint8List? derivedKeySecondHalf;

    try {
      derivedKey = kdfparams.generateDerivedKey(passwordBytes, salt);

      derivedKeyFirstHalf = derivedKey.sublist(0, 16);
      derivedKeySecondHalf = derivedKey.sublist(16, 32);
      final Uint8List computedMac = CryptoUtils.computeHmacSha256(
        derivedKeySecondHalf,
        ciphertext,
      );
      final Uint8List actualMacBytes = Uint8List.fromList(hex.decode(data.mac));

      if (!CryptoUtils.constantTimeCompare(computedMac, actualMacBytes)) {
        throw const DecryptorException('MAC mismatch, possibly wrong password');
      }
      final StreamCipher cipher = _createDecipher(derivedKeyFirstHalf, iv);
      return cipher.process(ciphertext);
    } finally {
      derivedKey?.fillRange(0, derivedKey.length, 0);
      derivedKeyFirstHalf?.fillRange(0, derivedKeyFirstHalf.length, 0);
      derivedKeySecondHalf?.fillRange(0, derivedKeySecondHalf.length, 0);
    }
  }

  static StreamCipher _createDecipher(Uint8List key, Uint8List iv) {
    final StreamCipher cipher = StreamCipher('AES/CTR');
    final ParametersWithIV<KeyParameter> params =
        ParametersWithIV<KeyParameter>(KeyParameter(key), iv);
    cipher.init(false, params);
    return cipher;
  }
}
