/// Validator keys for MultiversX validators using BLS12-381 signatures.
/// Provides BLS public and secret key management with automatic memory zeroing.
import 'dart:typed_data';
import 'package:convert/convert.dart' as convert;

const int validatorSecretKeyLength = 32;
const int validatorPublicKeyLength = 96;

/// Securely zeros validator secret key bytes when garbage collected.
/// Prevents BLS key recovery from memory dumps.
final _validatorSecretKeyFinalizer = Finalizer<Uint8List>((buffer) {
  buffer.fillRange(0, buffer.length, 0);
});

/// BLS public key used by validators for signature verification.
/// Used in consensus and block signing operations.
///
/// #### Example
/// ```dart
/// // From hex string
/// final pubkey = ValidatorPublicKey.fromHex(
///   '0123456789abcdef...', // 96 bytes = 192 hex chars
/// );
///
/// // Get hex representation
/// final hexStr = pubkey.hex;
/// print('Validator: $hexStr');
///
/// // Get raw bytes
/// final bytes = pubkey.bytes;
/// ```
class ValidatorPublicKey {
  /// Creates validator public key from bytes.
  ///
  /// #### Parameters
  /// - `buffer` - 96-byte BLS public key
  ///
  /// #### Throws
  /// - `ArgumentError` - If buffer length is not 96 bytes
  ///
  /// #### Example
  /// ```dart
  /// final pubkeyBytes = Uint8List(96);
  /// // ... fill with BLS public key
  /// final pubkey = ValidatorPublicKey(pubkeyBytes);
  /// ```
  ValidatorPublicKey(Uint8List buffer) : _buffer = Uint8List.fromList(buffer) {
    if (buffer.length != validatorPublicKeyLength) {
      throw ArgumentError(
        'Invalid validator public key length: expected $validatorPublicKeyLength, got ${buffer.length}',
      );
    }
  }

  /// Creates validator public key from hex string.
  ///
  /// #### Parameters
  /// - `hex` - Hex string (192 characters for 96 bytes)
  ///
  /// #### Returns
  /// `ValidatorPublicKey` - Parsed BLS public key instance
  ///
  /// #### Throws
  /// - `ArgumentError` - If hex string length is invalid
  ///
  /// #### Example
  /// ```dart
  /// final hexStr = '0123456789abcdef...'; // 192 hex chars
  /// final pubkey = ValidatorPublicKey.fromHex(hexStr);
  /// ```
  factory ValidatorPublicKey.fromHex(String hex) {
    final buffer = Uint8List.fromList(convert.hex.decode(hex));
    return ValidatorPublicKey(buffer);
  }
  final Uint8List _buffer;

  /// Gets hex string representation of public key.
  String get hex => convert.hex.encode(_buffer);

  /// Gets raw bytes of public key (defensive copy).
  Uint8List get bytes => Uint8List.fromList(_buffer);

  @override
  String toString() => hex;
}

/// BLS secret key used by validators with automatic memory zeroing.
/// Never exposed in logs, zeros memory when garbage collected or explicitly disposed.
///
/// #### Example
/// ```dart
/// // From hex string
/// final secretKey = ValidatorSecretKey.fromHex(hexString);
///
/// // From bytes
/// final secretKey = ValidatorSecretKey(keyBytes);
///
/// // Secure disposal
/// secretKey.dispose(); // Zeros memory immediately
///
/// // Access bytes (use with caution)
/// final bytes = secretKey.bytes;
/// final hexStr = secretKey.hex;
/// ```
class ValidatorSecretKey {
  /// Creates validator secret key from bytes.
  ///
  /// #### Parameters
  /// - `buffer` - 32-byte BLS secret key
  ///
  /// #### Throws
  /// - `ArgumentError` - If buffer length is not 32 bytes
  ///
  /// #### Example
  /// ```dart
  /// final keyBytes = Uint8List(32);
  /// // ... fill with BLS secret key
  /// final secretKey = ValidatorSecretKey(keyBytes);
  /// ```
  ValidatorSecretKey(Uint8List buffer) : _buffer = Uint8List.fromList(buffer) {
    if (buffer.length != validatorSecretKeyLength) {
      throw ArgumentError(
        'Invalid validator secret key length: expected $validatorSecretKeyLength, got ${buffer.length}',
      );
    }
    _validatorSecretKeyFinalizer.attach(this, _buffer, detach: this);
  }

  /// Creates validator secret key from hex string.
  ///
  /// #### Parameters
  /// - `hex` - Hex string (64 characters for 32 bytes)
  ///
  /// #### Returns
  /// `ValidatorSecretKey` - Parsed BLS secret key instance
  ///
  /// #### Throws
  /// - `ArgumentError` - If hex string length is invalid
  ///
  /// #### Example
  /// ```dart
  /// final hexKey = 'a1b2c3d4...'; // 64 hex chars
  /// final secretKey = ValidatorSecretKey.fromHex(hexKey);
  /// ```
  factory ValidatorSecretKey.fromHex(String hex) {
    final buffer = Uint8List.fromList(convert.hex.decode(hex));
    return ValidatorSecretKey(buffer);
  }
  final Uint8List _buffer;

  /// Gets hex string representation of secret key.
  String get hex => convert.hex.encode(_buffer);

  /// Gets raw bytes of secret key (defensive copy).
  Uint8List get bytes => Uint8List.fromList(_buffer);

  @override
  String toString() {
    return 'ValidatorSecretKey(<redacted ${_buffer.length} bytes>)';
  }

  /// Securely zeros validator secret key from memory immediately.
  void dispose() {
    _validatorSecretKeyFinalizer.detach(this);
    _buffer.fillRange(0, _buffer.length, 0);
  }
}
