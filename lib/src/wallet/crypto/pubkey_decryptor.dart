/// Public key decryption using X25519-XSalsa20-Poly1305 authenticated decryption.
/// Verifies Ed25519 signature and performs ECDH key exchange to decrypt.
import 'dart:typed_data';
import 'package:convert/convert.dart' as convert;
import 'package:cryptography/cryptography.dart';
import 'package:pinenacl/x25519.dart' as x25519;

import '../../utils/sdk_exceptions.dart';
import '../user_keys.dart';
import 'curve25519_conversion.dart';
import 'x25519_encrypted_data.dart';

/// Public key decryptor using X25519-XSalsa20-Poly1305 authenticated decryption.
/// Verifies sender signature before decrypting with ECDH shared secret.
class PubkeyDecryptor {
  PubkeyDecryptor._();

  /// Decrypts X25519-encrypted data using recipient's secret key.
  ///
  /// Key conversion: both the ephemeral Ed25519 public key stored in the
  /// payload and the recipient's Ed25519 seed are converted to their X25519
  /// counterparts before ECDH, matching the encryptor's behaviour.
  ///
  /// #### Parameters
  /// - `data` - X25519EncryptedData to decrypt
  /// - `decryptorSecretKey` - Recipient's Ed25519 secret key
  ///
  /// #### Returns
  /// `Uint8List` - Decrypted plaintext data
  ///
  /// #### Throws
  /// - `DecryptorException` - If signature verification fails
  /// - `DecryptorException` - If decryption fails or data is tampered
  static Future<Uint8List> decrypt(
    X25519EncryptedData data,
    UserSecretKey decryptorSecretKey,
  ) async {
    final Uint8List ciphertext = Uint8List.fromList(
      convert.hex.decode(data.ciphertext),
    );
    final Uint8List edhEdPubKeyBytes = Uint8List.fromList(
      convert.hex.decode(data.identities.ephemeralPubKey),
    );
    final Uint8List originatorPubKeyBytes = Uint8List.fromList(
      convert.hex.decode(data.identities.originatorPubKey),
    );
    final UserPublicKey originatorPubKey = UserPublicKey(originatorPubKeyBytes);
    final Uint8List signature = Uint8List.fromList(
      convert.hex.decode(data.mac),
    );
    final Uint8List nonce = Uint8List.fromList(convert.hex.decode(data.nonce));

    final Sha256 sha256 = Sha256();
    final Uint8List authMessage = Uint8List.fromList(<int>[
      ...ciphertext,
      ...edhEdPubKeyBytes,
    ]);
    final Hash authMessageHash = await sha256.hash(authMessage);

    final bool signatureValid = await originatorPubKey.verify(
      Uint8List.fromList(authMessageHash.bytes),
      signature,
    );

    if (!signatureValid) {
      throw const DecryptorException(
        'Invalid authentication for encrypted message originator. '
        'Signature verification failed.',
      );
    }

    final Uint8List decryptorSeed = decryptorSecretKey.bytes;
    final Uint8List decryptorX25519Scalar = await ed25519SeedToX25519SecretKey(
      decryptorSeed,
    );
    final Uint8List edhX25519PubKeyBytes = ed25519PublicKeyToX25519(
      edhEdPubKeyBytes,
    );

    try {
      final x25519.PrivateKey x25519Secret = x25519.PrivateKey(
        decryptorX25519Scalar,
      );
      final x25519.PublicKey x25519EdhPubKey = x25519.PublicKey(
        edhX25519PubKeyBytes,
      );
      final x25519.Box box = x25519.Box(
        myPrivateKey: x25519Secret,
        theirPublicKey: x25519EdhPubKey,
      );

      try {
        final List<int> decryptedMessage = box.decrypt(
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
      decryptorSeed.fillRange(0, decryptorSeed.length, 0);
      decryptorX25519Scalar.fillRange(0, decryptorX25519Scalar.length, 0);
    }
  }
}
