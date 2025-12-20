/// Public key encryption using X25519-XSalsa20-Poly1305 authenticated encryption.
/// Provides ECDH key exchange with ephemeral keys and Ed25519 sender authentication.
import 'dart:math' show Random;
import 'dart:typed_data';
import 'package:convert/convert.dart' as convert;
import 'package:cryptography/cryptography.dart';
import 'package:pinenacl/x25519.dart' as x25519;

import '../user_keys.dart';
import 'constants.dart';
import 'x25519_encrypted_data.dart';

/// Public key encryptor using X25519-XSalsa20-Poly1305 authenticated encryption.
/// Combines ECDH key exchange with XSalsa20 cipher and Poly1305 MAC.
class PubkeyEncryptor {
  PubkeyEncryptor._();

  /// Encrypts data for recipient using X25519-XSalsa20-Poly1305.
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
    final ed25519Alg = Ed25519();
    final edhKeyPair = await ed25519Alg.newKeyPair();
    final edhPublicKey = await edhKeyPair.extractPublicKey();
    final edhSecretBytes = await edhKeyPair.extractPrivateKeyBytes();
    final edhX25519PrivateKey = x25519.PrivateKey(
      Uint8List.fromList(edhSecretBytes),
    );
    final recipientX25519PubKey = x25519.PublicKey(recipientPubKey.bytes);
    final sha256 = Sha256();
    final dataHash = await sha256.hash(data);
    final nonceDeterministic = Uint8List.fromList(
      dataHash.bytes.sublist(0, pubKeyEncNonceLength ~/ 2),
    );
    final nonceRandom = Uint8List(pubKeyEncNonceLength ~/ 2);
    final secureRandom = Random.secure();
    for (int i = 0; i < nonceRandom.length; i++) {
      nonceRandom[i] = secureRandom.nextInt(256);
    }
    final nonce = Uint8List(pubKeyEncNonceLength)
      ..setRange(0, nonceDeterministic.length, nonceDeterministic)
      ..setRange(nonceDeterministic.length, pubKeyEncNonceLength, nonceRandom);
    final box = x25519.Box(
      myPrivateKey: edhX25519PrivateKey,
      theirPublicKey: recipientX25519PubKey,
    );
    final encryptedBox = box.encrypt(data, nonce: nonce);
    final ciphertext = encryptedBox.cipherText;
    final edhPubKeyBytes = Uint8List.fromList(edhPublicKey.bytes);
    final authMessage = Uint8List.fromList([...ciphertext, ...edhPubKeyBytes]);
    final authMessageHash = await sha256.hash(authMessage);
    final signature = await authSecretKey.sign(
      Uint8List.fromList(authMessageHash.bytes),
    );
    final originatorPubKey = await authSecretKey.generatePublicKey();

    return X25519EncryptedData(
      version: pubKeyEncVersion,
      nonce: convert.hex.encode(nonce),
      cipher: pubKeyEncCipher,
      ciphertext: convert.hex.encode(ciphertext),
      mac: convert.hex.encode(signature),
      identities: X25519Identities(
        recipient: recipientPubKey.hex,
        ephemeralPubKey: convert.hex.encode(edhPubKeyBytes),
        originatorPubKey: originatorPubKey.hex,
      ),
    );
  }
}
