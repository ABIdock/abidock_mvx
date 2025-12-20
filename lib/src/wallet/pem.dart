/// PEM file parsing for user and validator keys with comprehensive validation.
/// Parses base64-encoded keys wrapped in BEGIN/END markers with security checks.

import 'dart:convert';
import 'dart:typed_data';

import '../utils/sdk_exceptions.dart';
import 'user_keys.dart';

/// Parses single user key from PEM text at index.
///
/// #### Parameters
/// - `text` - PEM file content
/// - `index` - Key index if multiple keys present (default: 0)
///
/// #### Returns
/// `UserSecretKey` - Secret key at specified index
///
/// #### Throws
/// - `PemException` - If PEM is invalid, index out of bounds, or security checks fail
///
/// #### Example
/// ```dart
/// // Load from file
/// final pemContent = await File('wallet.pem').readAsString();
/// final secretKey = parseUserKey(pemContent);
///
/// // Multiple keys
/// final key0 = parseUserKey(pemContent, index: 0);
/// final key1 = parseUserKey(pemContent, index: 1);
///
/// // Use in signer
/// final signer = UserSigner(secretKey);
/// final address = await signer.getAddress();
/// ```
UserSecretKey parseUserKey(String text, {int index = 0}) {
  final List<UserSecretKey> keys = parseUserKeys(text);
  if (index >= keys.length) {
    throw PemException(
      'Index $index out of bounds, only ${keys.length} keys found',
    );
  }
  return keys[index];
}

/// Parses all user keys from PEM text.
///
/// #### Parameters
/// - `text` - PEM file content (may contain multiple keys)
///
/// #### Returns
/// `List<UserSecretKey>` - All secret keys found in PEM
///
/// #### Throws
/// - `PemException` - If PEM is invalid or security checks fail
///
/// #### Example
/// ```dart
/// // Parse all keys
/// final keys = parseUserKeys(pemContent);
/// print('Found ${keys.length} keys');
///
/// // Create signers for all keys
/// final signers = keys.map((key) => UserSigner(key)).toList();
///
/// // Get all addresses
/// for (int i = 0; i < keys.length; i++) {
///   final publicKey = await keys[i].generatePublicKey();
///   final address = publicKey.toAddress();
///   print('Key $i: ${address.bech32}');
/// }
/// ```
List<UserSecretKey> parseUserKeys(String text) {
  final List<Uint8List> buffers = _parse(
    text,
    userSeedLength + userPubkeyLength,
  );
  return buffers.map((Uint8List buffer) {
    return UserSecretKey(buffer.sublist(0, userSeedLength));
  }).toList();
}

/// Parses PEM text and extracts binary data.
List<Uint8List> _parse(String text, int expectedLength) {
  if (text.isEmpty) {
    throw const PemException('PEM text is empty');
  }
  const maxPemSize = 1024 * 1024; // 1MB
  if (text.length > maxPemSize) {
    throw const PemException('PEM file too large (max 1024KB)');
  }
  String cleanText = text;
  if (text.startsWith('\uFEFF')) {
    cleanText = text.substring(1);
  }
  final List<String> lines = cleanText
      .split(RegExp(r'\r?\n'))
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty)
      .toList();

  if (lines.isEmpty) {
    throw const PemException('PEM contains no valid content');
  }

  final List<Uint8List> buffers = <Uint8List>[];
  List<String> linesAccumulator = <String>[];
  bool inBlock = false;

  for (final String line in lines) {
    if (line.startsWith('-----BEGIN')) {
      if (inBlock) {
        throw const PemException('Nested BEGIN markers not allowed');
      }
      linesAccumulator = <String>[];
      inBlock = true;
    } else if (line.startsWith('-----END')) {
      if (!inBlock) {
        throw const PemException('END marker without matching BEGIN');
      }

      try {
        final String asBase64 = linesAccumulator.join('');
        if (asBase64.isEmpty) {
          throw const PemException('Empty PEM block');
        }
        final Uint8List decoded;
        try {
          decoded = Uint8List.fromList(base64.decode(asBase64));
        } on FormatException catch (e) {
          throw PemException('Invalid base64 encoding: ${e.message}');
        }
        final String asHex;
        try {
          asHex = utf8.decode(decoded);
        } catch (e) {
          throw PemException('Invalid UTF-8 in PEM data: $e');
        }
        if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(asHex)) {
          throw const PemException(
            'PEM data contains non-hexadecimal characters',
          );
        }

        if (asHex.length % 2 != 0) {
          throw const PemException('PEM hex data has odd length');
        }
        final Uint8List asBytes = Uint8List.fromList(
          List<int>.generate(
            asHex.length ~/ 2,
            (int i) => int.parse(asHex.substring(i * 2, i * 2 + 2), radix: 16),
          ),
        );
        if (asBytes.length != expectedLength) {
          throw PemException(
            'incorrect key length: expected $expectedLength, found ${asBytes.length}',
          );
        }
        final isAllZeros = asBytes.every((b) => b == 0);
        final isAllOnes = asBytes.every((b) => b == 0xFF);
        if (isAllZeros || isAllOnes) {
          throw const PemException(
            'Invalid key format (all zeros or all ones)',
          );
        }

        buffers.add(asBytes);
      } catch (e) {
        if (e is PemException) {
          rethrow;
        }
        throw PemException('Failed to parse PEM block: $e');
      }

      linesAccumulator = <String>[];
      inBlock = false;
    } else {
      if (inBlock) {
        linesAccumulator.add(line);
      }
    }
  }
  if (inBlock) {
    throw const PemException('Unclosed PEM block (missing END marker)');
  }
  if (buffers.isEmpty) {
    throw const PemException('No valid keys found in PEM');
  }

  return buffers;
}
