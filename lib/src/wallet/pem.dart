/// PEM file parsing for user and validator keys with comprehensive validation.
/// Parses base64-encoded keys wrapped in BEGIN/END markers and validates
/// that the bech32 label in the header matches the derived address.

import 'dart:convert';
import 'dart:typed_data';

import '../core/address.dart';
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
/// - `PemException` - If PEM is invalid, index out of bounds, label is not a
///   valid bech32 address, or label does not match derived address.
///
/// #### Example
/// ```dart
/// final pemContent = await File('wallet.pem').readAsString();
/// final secretKey = parseUserKey(pemContent);
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
/// Each block's header label is validated as a bech32 address, and the
/// embedded public key bytes are checked to match that label.
///
/// #### Parameters
/// - `text` - PEM file content (may contain multiple keys)
///
/// #### Returns
/// `List<UserSecretKey>` - All secret keys found in PEM
///
/// #### Throws
/// - `PemException` - If PEM is invalid, label is not bech32, or label and
///   derived public key disagree.
List<UserSecretKey> parseUserKeys(String text) {
  final List<_PemBlock> blocks = _parse(
    text,
    userSeedLength + userPubkeyLength,
  );
  final List<UserSecretKey> result = <UserSecretKey>[];
  for (final _PemBlock block in blocks) {
    final Uint8List buffer = block.bytes;
    final Uint8List publicBytes = buffer.sublist(
      userSeedLength,
      userSeedLength + userPubkeyLength,
    );

    final Address labelAddress;
    try {
      labelAddress = Address.fromBech32(block.label);
    } catch (error, stackTrace) {
      throw PemException(
        'PEM label is not a valid bech32 address: "${block.label}"',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    final Address derived = Address(publicBytes, hrp: labelAddress.hrp);
    if (derived.bech32 != labelAddress.bech32) {
      throw PemException(
        'PEM label does not match derived address: '
        '${labelAddress.bech32} vs ${derived.bech32}',
      );
    }

    result.add(UserSecretKey(buffer.sublist(0, userSeedLength)));
  }
  return result;
}

/// Internal representation of one parsed PEM block.
class _PemBlock {
  const _PemBlock({required this.label, required this.bytes});

  /// Label parsed from the `-----BEGIN ... for <label>-----` header.
  final String label;

  /// Decoded key bytes (hex-decoded from the base64 body).
  final Uint8List bytes;
}

/// Parses PEM text and extracts the label and binary data of each block.
List<_PemBlock> _parse(String text, int expectedLength) {
  if (text.isEmpty) {
    throw const PemException('PEM text is empty');
  }
  const int maxPemSize = 1024 * 1024;
  if (text.length > maxPemSize) {
    throw const PemException('PEM file too large (max 1024KB)');
  }
  String cleanText = text;
  if (text.startsWith('﻿')) {
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

  final List<_PemBlock> blocks = <_PemBlock>[];
  List<String> linesAccumulator = <String>[];
  String? currentLabel;
  bool inBlock = false;

  for (final String line in lines) {
    if (line.startsWith('-----BEGIN')) {
      if (inBlock) {
        throw const PemException('Nested BEGIN markers not allowed');
      }
      currentLabel = _extractLabel(line, 'BEGIN');
      linesAccumulator = <String>[];
      inBlock = true;
    } else if (line.startsWith('-----END')) {
      if (!inBlock) {
        throw const PemException('END marker without matching BEGIN');
      }
      final String endLabel = _extractLabel(line, 'END');
      if (endLabel != currentLabel) {
        throw PemException(
          'PEM BEGIN/END labels disagree: "$currentLabel" vs "$endLabel"',
        );
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
        final bool isAllZeros = asBytes.every((int b) => b == 0);
        final bool isAllOnes = asBytes.every((int b) => b == 0xFF);
        if (isAllZeros || isAllOnes) {
          throw const PemException(
            'Invalid key format (all zeros or all ones)',
          );
        }

        blocks.add(_PemBlock(label: currentLabel ?? '', bytes: asBytes));
      } catch (e) {
        if (e is PemException) {
          rethrow;
        }
        throw PemException('Failed to parse PEM block: $e');
      }

      linesAccumulator = <String>[];
      currentLabel = null;
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
  if (blocks.isEmpty) {
    throw const PemException('No valid keys found in PEM');
  }

  return blocks;
}

/// Extracts the label (e.g. `erd1...`) from a PEM `BEGIN`/`END` marker line.
String _extractLabel(String line, String kind) {
  final RegExp pattern = RegExp(
    '-----$kind (?:PRIVATE KEY|EC PRIVATE KEY|RSA PRIVATE KEY|KEY) for ([^-]+?)-----',
  );
  final RegExpMatch? match = pattern.firstMatch(line);
  if (match == null) {
    throw PemException(
      'Malformed PEM $kind line (expected "-----$kind ... for <label>-----"): "$line"',
    );
  }
  return match.group(1)!.trim();
}
