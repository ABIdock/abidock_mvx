/// Public key encryption using X25519-XSalsa20-Poly1305 authenticated encryption.
/// Provides ECDH key exchange with ephemeral keys and Ed25519 sender authentication.
import 'dart:math' show Random;
import 'dart:typed_data';
import 'package:convert/convert.dart' as convert;
import 'package:cryptography/cryptography.dart';
import 'package:pinenacl/x25519.dart' as x25519;

import '../user_keys.dart';
import 'constants.dart';
import 'curve25519_conversion.dart';
import 'x25519_encrypted_data.dart';

/// Public key encryptor using X25519-XSalsa20-Poly1305 authenticated encryption.
/// Combines ECDH key exchange with XSalsa20 cipher and Poly1305 MAC.
class PubkeyEncryptor {
  PubkeyEncryptor._();

  /// Encrypts data for recipient using X25519-XSalsa20-Poly1305.
  ///
  /// Key conversion: the recipient's Ed25519 public key and the ephemeral
  /// Ed25519 seed are converted to their X25519 counterparts before ECDH, per
  /// RFC 7748 / libsodium's `crypto_sign_ed25519_*_to_curve25519`. The
  /// ephemeral Ed25519 public key is what gets stored in the output
  /// (matching mx-sdk-js-core); the decryptor converts it on the way in.
  ///
  /// #### Parameters
  /// - `data` - Plaintext data to encrypt
  /// - `recipientPubKey` - Recipient's Ed25519 public key
  /// - `authSecretKey` - Sender's Ed25519 secret key for authentication
  ///
  /// #### Returns
  /// `X25519EncryptedData` - Encrypted data with ciphertext, nonce, MAC, and identities
  static Future<X25519EncryptedData> encrypt(
    Uint8List data,
    UserPublicKey recipientPubKey,
    UserSecretKey authSecretKey,
  ) async {
    final Ed25519 ed25519Alg = Ed25519();
    final SimpleKeyPair edhKeyPair = await ed25519Alg.newKeyPair();
    final SimplePublicKey edhEdPublicKey = await edhKeyPair.extractPublicKey();
    final List<int> edhEdSeed = await edhKeyPair.extractPrivateKeyBytes();
    final Uint8List edhEdSeedBytes = Uint8List.fromList(edhEdSeed);

    final Uint8List edhX25519ScalarBytes = await ed25519SeedToX25519SecretKey(
      edhEdSeedBytes,
    );
    final Uint8List recipientX25519PubKeyBytes = ed25519PublicKeyToX25519(
      recipientPubKey.bytes,
    );

    try {
      final x25519.PrivateKey edhX25519PrivateKey = x25519.PrivateKey(
        edhX25519ScalarBytes,
      );
      final x25519.PublicKey recipientX25519PubKey = x25519.PublicKey(
        recipientX25519PubKeyBytes,
      );

      final Sha256 sha256 = Sha256();
      final Hash dataHash = await sha256.hash(data);
      final Uint8List nonceDeterministic = Uint8List.fromList(
        dataHash.bytes.sublist(0, pubKeyEncNonceLength ~/ 2),
      );
      final Uint8List nonceRandom = Uint8List(pubKeyEncNonceLength ~/ 2);
      final Random secureRandom = Random.secure();
      for (int i = 0; i < nonceRandom.length; i++) {
        nonceRandom[i] = secureRandom.nextInt(256);
      }
      final Uint8List nonce = Uint8List(pubKeyEncNonceLength)
        ..setRange(0, nonceDeterministic.length, nonceDeterministic)
        ..setRange(
          nonceDeterministic.length,
          pubKeyEncNonceLength,
          nonceRandom,
        );

      final x25519.Box box = x25519.Box(
        myPrivateKey: edhX25519PrivateKey,
        theirPublicKey: recipientX25519PubKey,
      );
      final x25519.EncryptedMessage encryptedBox = box.encrypt(
        data,
        nonce: nonce,
      );
      final List<int> ciphertext = encryptedBox.cipherText;

      final Uint8List edhEdPubKeyBytes = Uint8List.fromList(
        edhEdPublicKey.bytes,
      );
      final Uint8List authMessage = Uint8List.fromList(<int>[
        ...ciphertext,
        ...edhEdPubKeyBytes,
      ]);
      final Hash authMessageHash = await sha256.hash(authMessage);
      final Uint8List signature = await authSecretKey.sign(
        Uint8List.fromList(authMessageHash.bytes),
      );
      final UserPublicKey originatorPubKey = await authSecretKey
          .generatePublicKey();

      return X25519EncryptedData(
        version: pubKeyEncVersion,
        nonce: convert.hex.encode(nonce),
        cipher: pubKeyEncCipher,
        ciphertext: convert.hex.encode(ciphertext),
        mac: convert.hex.encode(signature),
        identities: X25519Identities(
          recipient: recipientPubKey.hex,
          ephemeralPubKey: convert.hex.encode(edhEdPubKeyBytes),
          originatorPubKey: originatorPubKey.hex,
        ),
      );
    } finally {
      edhEdSeedBytes.fillRange(0, edhEdSeedBytes.length, 0);
      edhX25519ScalarBytes.fillRange(0, edhX25519ScalarBytes.length, 0);
    }
  }
}
