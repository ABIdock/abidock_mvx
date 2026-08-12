/// Cryptographically secure random values for wallet encryption operations.
/// Generates salt, initialization vectors, and unique keystore identifiers.
import 'dart:math';
import 'dart:typed_data';

/// Cryptographically secure random values for encryption operations.
/// Provides salt, IV, and unique identifiers using `Random.secure()`.
class Randomness {
  /// Creates randomness with optional custom values for testing.
  ///
  /// #### Parameters
  /// - `salt` - 32-byte salt for KDF (generates random if null)
  /// - `iv` - 16-byte initialization vector (generates random if null)
  /// - `id` - Unique identifier (generates a UUIDv4 string if null)
  Randomness({Uint8List? salt, Uint8List? iv, String? id})
    : salt = salt ?? _generateRandomBytes(32),
      iv = iv ?? _generateRandomBytes(16),
      id = id ?? _generateUuidV4();

  /// 32-byte salt for Scrypt KDF (256-bit entropy).
  final Uint8List salt;

  /// 16-byte initialization vector for AES-128-CTR (128-bit entropy).
  final Uint8List iv;

  /// Unique keystore identifier formatted as a UUIDv4 string
  /// (`xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx` where `y` is one of `8`, `9`,
  /// `a`, or `b`), as required by the keystore file's `id` field.
  final String id;

  /// Generates cryptographically secure random bytes.
  ///
  /// #### Parameters
  /// - `length` - Number of bytes to generate
  ///
  /// #### Returns
  /// `Uint8List` - Random bytes using `Random.secure()`.
  static Uint8List _generateRandomBytes(int length) {
    final Random random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// Generates a UUIDv4 string from 16 cryptographically secure random bytes.
  ///
  /// #### Returns
  /// `String` - 36-character UUIDv4 (RFC 4122 §4.4) string. The 7th byte is
  /// forced to encode version `4`, and the 9th byte's two highest bits are
  /// forced to the RFC variant (`10xxxxxx`).
  static String _generateUuidV4() {
    final Uint8List bytes = _generateRandomBytes(16);
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
