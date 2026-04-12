/// User secret and public key classes for ed25519.
/// Uses libsodium FFI for memory control and security.
///
///  UserPublicKey derives blockchain addresses and verifies signatures.
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:convert/convert.dart' as convert;

import '../core/address.dart';
import 'assertions.dart';
import 'crypto/ed25519_crypto.dart';
import 'pem.dart';

const int userSeedLength = 32;
const int userPubkeyLength = 32;

/// Securely zeros secret key bytes when garbage collected.
/// Prevents key recovery from memory dumps.
final _secretKeyFinalizer = Finalizer<Uint8List>((buffer) {
  buffer.fillRange(0, buffer.length, 0);
});

/// Ed25519 secret key for signing transactions and messages with automatic memory zeroing.
/// Never exposed in logs or toString(), zeros memory when garbage collected or explicitly disposed.
///
/// #### Example
/// ```dart
/// // Generate random key
/// final secretKey = UserSecretKey.generate();
///
/// // From hex string (64 characters)
/// final secretKey = UserSecretKey.fromString(
///   'a1b2c3d4e5f6...',
/// );
///
/// // From PEM file
/// final secretKey = UserSecretKey.fromPem(pemContent, index: 0);
///
/// // Generate public key
/// final publicKey = await secretKey.generatePublicKey();
///
/// // Sign transaction
/// final signature = await secretKey.sign(txBytes);
///
/// // Secure disposal (zeros memory)
/// secretKey.dispose();
///
/// // Access raw bytes (use with caution)
/// final bytes = secretKey.bytes;
/// final hexStr = secretKey.hex;
/// ```
class UserSecretKey {
  /// Creates secret key from bytes.
  ///
  /// #### Parameters
  /// - `buffer` - 32-byte Ed25519 seed
  ///
  /// #### Throws
  /// - `ArgumentError` - If buffer length is not 32 bytes
  ///
  /// #### Example
  /// ```dart
  /// final seed = Uint8List(32);
  /// // ... fill with random bytes
  /// final secretKey = UserSecretKey(seed);
  /// ```
  UserSecretKey(Uint8List buffer) : _buffer = Uint8List.fromList(buffer) {
    guardLength(buffer, userSeedLength);
    _secretKeyFinalizer.attach(this, _buffer, detach: this);
  }

  /// Creates secret key from hex string.
  ///
  /// #### Parameters
  /// - `value` - Hex string (64 characters for 32 bytes)
  ///
  /// #### Returns
  /// `UserSecretKey` - Parsed secret key instance
  ///
  /// #### Throws
  /// - `ArgumentError` - If string length is not 64 characters
  ///
  /// #### Example
  /// ```dart
  /// final hexKey = 'a1b2c3d4e5f6...'; // 64 chars
  /// final secretKey = UserSecretKey.fromString(hexKey);
  /// ```
  factory UserSecretKey.fromString(String value) {
    guardLength(value, userSeedLength * 2);
    final buffer = Uint8List.fromList(convert.hex.decode(value));
    return UserSecretKey(buffer);
  }

  factory UserSecretKey.fromPem(String text, {int index = 0}) {
    return parseUserKey(text, index: index);
  }
  final Uint8List _buffer;

  /// Generates public key from this secret key.
  ///
  /// #### Returns Public key derived via Ed25519.
  ///
  /// #### Example
  /// ```dart
  /// final secretKey = UserSecretKey.generate();
  /// final publicKey = await secretKey.generatePublicKey();
  /// final address = publicKey.toAddress();
  /// print('Address: ${address.bech32}');
  /// ```
  Future<UserPublicKey> generatePublicKey() async {
    final publicKeyBytes = await Ed25519Crypto.generatePublicKey(_buffer);
    return UserPublicKey(publicKeyBytes);
  }

  /// Generates random secret key.
  ///
  /// #### Returns New random 32-byte secret key.
  ///
  /// #### Example
  /// ```dart
  /// final secretKey = UserSecretKey.generate();
  /// final publicKey = await secretKey.generatePublicKey();
  ///
  /// // Save to encrypted keystore
  /// final wallet = await UserWallet.fromSecretKey(
  ///   secretKey: secretKey,
  ///   password: 'strong-password',
  /// );
  /// wallet.save('wallet.json');
  /// ```
  static UserSecretKey generate() {
    final random = Random.secure();
    final seed = Uint8List(userSeedLength);
    for (int i = 0; i < seed.length; i++) {
      seed[i] = random.nextInt(256);
    }
    return UserSecretKey(seed);
  }

  /// Signs data with this secret key.
  ///
  /// #### Parameters
  /// - `message` - Data to sign
  ///
  /// #### Returns
  /// `Future<Uint8List>` - 64-byte Ed25519 signature
  ///
  /// #### Example
  /// ```dart
  /// // Sign transaction
  /// final txBytes = tx.serializeForSigning();
  /// final signature = await secretKey.sign(txBytes);
  /// final signedTx = tx.copyWith(
  ///   newSignature: Signature.fromUint8List(signature),
  /// );
  ///
  /// // Sign message
  /// final message = Message(utf8.encode('Hello'));
  /// final signature = await secretKey.sign(message.bytes);
  /// ```
  Future<Uint8List> sign(Uint8List message) async {
    return Ed25519Crypto.sign(_buffer, message);
  }

  /// Gets hex string representation of secret key.
  String get hex => convert.hex.encode(_buffer);

  /// Gets raw bytes of secret key (defensive copy).
  Uint8List get bytes => Uint8List.fromList(_buffer);

  @override
  String toString() {
    return 'UserSecretKey(<redacted ${_buffer.length} bytes>)';
  }

  /// Securely zeros secret key from memory.
  void dispose() {
    _secretKeyFinalizer.detach(this);
    _buffer.fillRange(0, _buffer.length, 0);
  }
}

/// Ed25519 public key for address derivation and signature verification.
///
/// /// addresses and verify signatures. Safe to share publicly.
///
/// #### Example
/// ```dart
/// // From secret key
/// final publicKey = await secretKey.generatePublicKey();
///
/// // Derive address
/// final address = publicKey.toAddress();
/// print('Address: ${address.bech32}');
///
/// // Verify signature
/// final isValid = await publicKey.verify(data, signature);
/// if (isValid) {
///   print('Signature is valid');
/// }
///
/// // Get hex representation
/// final hexPubkey = publicKey.hex;
///
/// // Get raw bytes
/// final bytes = publicKey.bytes;
/// ```
class UserPublicKey {
  /// Creates public key from bytes.
  ///
  /// #### Parameters
  /// - `buffer` - 32-byte Ed25519 public key
  ///
  /// #### Throws
  /// - `ArgumentError` - If buffer length is not 32 bytes
  ///
  /// #### Example
  /// ```dart
  /// final pubkeyBytes = Uint8List(32);
  /// // ... fill with public key bytes
  /// final publicKey = UserPublicKey(pubkeyBytes);
  /// ```
  UserPublicKey(Uint8List buffer) : _buffer = Uint8List.fromList(buffer) {
    guardLength(buffer, userPubkeyLength);
  }
  final Uint8List _buffer;

  /// Verifies Ed25519 signature.
  ///
  /// #### Parameters
  /// - `data` - Original data that was signed
  /// - `signature` - 64-byte signature to verify
  ///
  /// #### Returns
  /// `Future<bool>` - True if signature is valid, false otherwise
  ///
  /// #### Example
  /// ```dart
  /// // Verify transaction signature
  /// final txBytes = tx.serializeForSigning();
  /// final isValid = await publicKey.verify(txBytes, signature);
  ///
  /// // Verify message signature
  /// final message = Message(utf8.encode('Hello'));
  /// final isValid = await publicKey.verify(
  ///   message.bytes,
  ///   signatureBytes,
  /// );
  ///
  /// if (isValid) {
  ///   print('Signature verified!');
  /// } else {
  ///   print('Invalid signature');
  /// }
  /// ```
  Future<bool> verify(Uint8List data, Uint8List signature) async {
    try {
      return Ed25519Crypto.verify(_buffer, data, signature);
    } catch (e) {
      return false;
    }
  }

  /// Gets hex string representation of public key.
  String get hex => convert.hex.encode(_buffer);

  Address toAddress({String? hrp}) {
    return Address(_buffer, hrp: hrp ?? 'erd');
  }

  /// Gets raw bytes of public key (defensive copy).
  Uint8List get bytes => Uint8List.fromList(_buffer);
}
