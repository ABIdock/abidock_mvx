/// Validator keys for MultiversX validators using BLS12-381 signatures.
/// Provides BLS public and secret key management with automatic memory zeroing.
import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart' as convert;

import '../utils/sdk_exceptions.dart';

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

  /// Parses a `ValidatorSecretKey` from a validator PEM file.
  ///
  /// In the validator PEM format the body is the base64 of the hex-encoded
  /// 32-byte BLS secret key — base64 over ASCII hex, not over raw bytes.
  ///
  /// #### Parameters
  /// - `pemText` - Full validator PEM file text (may contain multiple
  ///   entries)
  /// - `index` - Entry index (default 0)
  ///
  /// #### Returns
  /// `ValidatorSecretKey` - The decoded BLS secret key
  ///
  /// #### Throws
  /// - `PemException` - When the PEM is empty, malformed, or the
  ///   requested index is out of range
  ///
  /// #### Example
  /// ```dart
  /// final key = ValidatorSecretKey.fromPem(pemFile);
  /// ```
  static ValidatorSecretKey fromPem(String pemText, {int index = 0}) {
    final List<ValidatorSecretKey> keys = parseValidatorKeys(pemText);
    if (index < 0 || index >= keys.length) {
      throw PemException(
        'Validator PEM index out of range: $index (entries: ${keys.length})',
      );
    }
    return keys[index];
  }

  /// Serializes this key to a validator PEM block.
  ///
  /// The body is the base64 of the hex-encoded secret key bytes, wrapped at
  /// 64 characters per line. The header uses the BLS public key hex as the
  /// label.
  ///
  /// #### Parameters
  /// - `publicKey` - BLS public key paired with this secret; used as the
  ///   PEM header/footer label
  ///
  /// #### Returns
  /// `String` - PEM-encoded validator key (no trailing newline)
  ///
  /// #### Example
  /// ```dart
  /// final pem = secret.toPem(public);
  /// ```
  String toPem(ValidatorPublicKey publicKey) {
    final String label = publicKey.hex;
    final String hexEncodedSecret = convert.hex.encode(_buffer);
    final String body = base64.encode(utf8.encode(hexEncodedSecret));
    final StringBuffer wrapped = StringBuffer();
    for (int i = 0; i < body.length; i += 64) {
      final int end = (i + 64 < body.length) ? i + 64 : body.length;
      if (i > 0) {
        wrapped.write('\n');
      }
      wrapped.write(body.substring(i, end));
    }
    return '-----BEGIN PRIVATE KEY for $label-----\n'
        '$wrapped\n'
        '-----END PRIVATE KEY for $label-----';
  }

  /// Signs `data` with this BLS12-381 secret key.
  ///
  /// #### Parameters
  /// - `data` - Message bytes to sign
  ///
  /// #### Returns
  /// `Uint8List` - 96-byte BLS signature
  ///
  /// #### Throws
  /// - `UnimplementedError` - Always, until a native BLS backend is
  ///   wired in. Pure-Dart BLS12-381 is not yet available in this SDK;
  ///   provide a custom signer or wait for native BLS integration.
  Uint8List sign(Uint8List data) {
    throw UnimplementedError(
      'BLS signing not yet supported in pure-Dart; provide a custom '
      'signer or wait for native BLS integration',
    );
  }
}

/// Parses every `ValidatorSecretKey` from a validator PEM file.
///
/// Iterates over each `-----BEGIN PRIVATE KEY for <label>-----` /
/// `-----END PRIVATE KEY for <label>-----` block, base64-decodes the
/// body to recover the hex-encoded secret key bytes, then hex-decodes
/// those bytes into a 32-byte BLS secret key.
///
/// #### Parameters
/// - `pemText` - Validator PEM file contents (one or many entries)
///
/// #### Returns
/// `List<ValidatorSecretKey>` - All validator keys, in file order
///
/// #### Throws
/// - `PemException` - When `pemText` is empty, contains no valid
///   validator entries, or has malformed base64/hex content
List<ValidatorSecretKey> parseValidatorKeys(String pemText) {
  if (pemText.trim().isEmpty) {
    throw const PemException('Empty validator PEM input');
  }

  /// Capture the BLS public-key label on both BEGIN and END markers so we
  /// can assert they match (M2-17).
  final RegExp blockPattern = RegExp(
    r'-----BEGIN PRIVATE KEY for ([^-]+)-----\s*([A-Za-z0-9+/=\s]+?)\s*-----END PRIVATE KEY for ([^-]+)-----',
    multiLine: true,
  );

  final Iterable<RegExpMatch> matches = blockPattern.allMatches(pemText);
  if (matches.isEmpty) {
    throw const PemException(
      'No validator PEM entries found; expected BEGIN/END PRIVATE KEY headers',
    );
  }

  /// 192 lowercase-hex chars = 96 bytes (BLS public key length).
  final RegExp validatorPubKeyLabel = RegExp(r'^[0-9a-f]{192}$');

  final List<ValidatorSecretKey> result = <ValidatorSecretKey>[];
  for (final RegExpMatch match in matches) {
    final String beginLabel = match.group(1)!.trim();
    final String body = match.group(2)!.replaceAll(RegExp(r'\s+'), '');
    final String endLabel = match.group(3)!.trim();

    if (beginLabel != endLabel) {
      throw PemException(
        'Validator PEM BEGIN/END labels do not match: '
        '"$beginLabel" vs "$endLabel"',
      );
    }
    if (!validatorPubKeyLabel.hasMatch(beginLabel)) {
      throw PemException(
        'Validator PEM label must be exactly 192 lowercase hex chars '
        '(BLS public key, 96 bytes); got "${beginLabel.length}" chars',
      );
    }

    final Uint8List hexBytes;
    try {
      hexBytes = base64.decode(body);
    } on FormatException catch (error, stackTrace) {
      throw PemException(
        'Invalid base64 in validator PEM body',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    final String hexString = utf8.decode(hexBytes);
    final Uint8List secretBytes;
    try {
      secretBytes = Uint8List.fromList(convert.hex.decode(hexString));
    } on FormatException catch (error, stackTrace) {
      throw PemException(
        'Invalid hex in validator PEM body',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (secretBytes.length != validatorSecretKeyLength) {
      throw PemException(
        'Invalid validator secret length: expected $validatorSecretKeyLength, got ${secretBytes.length}',
      );
    }
    result.add(ValidatorSecretKey(secretBytes));
  }
  return result;
}
