/// Cryptographically secure random values for wallet encryption operations.
/// Generates salt, initialization vectors, and unique keystore identifiers.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Cryptographically secure random values for encryption operations.
/// Provides salt, IV, and unique identifiers using Random.secure().
class Randomness {
  /// Creates randomness with optional custom values for testing.
  ///
  /// #### Parameters
  /// - `salt` - 32-byte salt for KDF (generates random if null)
  /// - `iv` - 16-byte initialization vector (generates random if null)
  /// - `id` - Unique identifier (generates random if null)
  Randomness({Uint8List? salt, Uint8List? iv, String? id})
    : salt = salt ?? _generateRandomBytes(32),
      iv = iv ?? _generateRandomBytes(16),
      id = id ?? _generateCryptoId();

  /// 32-byte salt for Scrypt KDF (256-bit entropy).
  final Uint8List salt;

  /// 16-byte initialization vector for AES-128-CTR (128-bit entropy).
  final Uint8List iv;

  /// Unique keystore identifier (256-bit entropy, base64url encoded).
  final String id;

  /// Generates cryptographically secure random bytes.
  ///
  /// #### Parameters
  /// - `length` - Number of bytes to generate
  ///
  /// #### Returns
  /// `Uint8List` - Random bytes using Random.secure()
  static Uint8List _generateRandomBytes(int length) {
    final Random random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// Generates cryptographically secure ID with 256-bit entropy.
  ///
  /// #### Returns
  /// `String` - Base64url-encoded ID from 32 random bytes
  static String _generateCryptoId() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
