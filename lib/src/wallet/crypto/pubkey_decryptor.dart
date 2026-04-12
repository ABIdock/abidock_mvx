/// Public key decryption using X25519-XSalsa20-Poly1305 authenticated decryption.
/// Verifies Ed25519 signature and performs ECDH key exchange to decrypt.
import 'dart:typed_data';
import 'package:convert/convert.dart' as convert;
import 'package:cryptography/cryptography.dart';
import 'package:pinenacl/x25519.dart' as x25519;

import '../../utils/sdk_exceptions.dart';
import '../user_keys.dart';
import 'x25519_encrypted_data.dart';

/// Public key decryptor using X25519-XSalsa20-Poly1305 authenticated decryption.
/// Verifies sender signature before decrypting with ECDH shared secret.
class PubkeyDecryptor {
  PubkeyDecryptor._();

  /// Decrypts X25519-encrypted data using recipient's secret key.
  ///
  /// #### Parameters
  /// - `data` - X25519EncryptedData to decrypt
  /// - `decryptorSecretKey` - Recipient's Ed25519 secret key
  ///
  /// #### Returns
  /// `Uint8List` - Decrypted plaintext data
  ///
  /// #### Throws
  /// - `Exception` - If signature verification fails
  /// - `Exception` - If decryption fails or data is tampered
  static Future<Uint8List> decrypt(
    X25519EncryptedData data,
    UserSecretKey decryptorSecretKey,
  ) async {
    final ciphertext = Uint8List.fromList(convert.hex.decode(data.ciphertext));
    final edhPubKeyBytes = Uint8List.fromList(
      convert.hex.decode(data.identities.ephemeralPubKey),
    );
    final originatorPubKeyBytes = Uint8List.fromList(
      convert.hex.decode(data.identities.originatorPubKey),
    );
    final originatorPubKey = UserPublicKey(originatorPubKeyBytes);
    final signature = Uint8List.fromList(convert.hex.decode(data.mac));
    final nonce = Uint8List.fromList(convert.hex.decode(data.nonce));

    final sha256 = Sha256();
    final authMessage = Uint8List.fromList([...ciphertext, ...edhPubKeyBytes]);
    final authMessageHash = await sha256.hash(authMessage);

    final signatureValid = await originatorPubKey.verify(
      Uint8List.fromList(authMessageHash.bytes),
      signature,
    );

    if (!signatureValid) {
      throw const DecryptorException(
        'Invalid authentication for encrypted message originator. '
        'Signature verification failed.',
      );
    }

    final decryptorSecretBytes = decryptorSecretKey.bytes;

    try {
      final x25519Secret = x25519.PrivateKey(decryptorSecretBytes);

      final x25519EdhPubKey = x25519.PublicKey(edhPubKeyBytes);
      final box = x25519.Box(
        myPrivateKey: x25519Secret,
        theirPublicKey: x25519EdhPubKey,
      );

      try {
        final decryptedMessage = box.decrypt(
          x25519.EncryptedMessage(cipherText: ciphertext, nonce: nonce),
        );
        return Uint8List.fromList(decryptedMessage);
      } catch (e) {
        throw DecryptorException(
          'Failed authentication for given ciphertext. '
          'Either wrong recipient, tampered message, or incorrect nonce.',
          cause: e,
        );
      }
    } finally {
      // Zero out secret bytes
      for (int i = 0; i < decryptorSecretBytes.length; i++) {
        decryptorSecretBytes[i] = 0;
      }
    }
  }
}
