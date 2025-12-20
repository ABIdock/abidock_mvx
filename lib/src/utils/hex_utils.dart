/// Utility functions for hex encoding and decoding between strings and bytes.
/// Provides conversion between hexadecimal strings, byte arrays, and UTF-8 strings.
import 'dart:convert';
import 'dart:typed_data';

/// Utility functions for hex encoding and decoding.
/// Static utility class for converting between hex strings, byte arrays, and UTF-8 strings.
class HexUtils {
  /// Private constructor to prevent instantiation.
  HexUtils._();

  /// Converts UTF-8 string to hex representation.
  ///
  /// #### Parameters
  /// - `input` - UTF-8 string to encode
  ///
  /// #### Returns
  /// `String` - Lowercase hex string without 0x prefix
  static String stringToHex(String input) {
    final List<int> bytes = utf8.encode(input);
    return bytesToHex(bytes);
  }

  /// Converts bytes to hexadecimal string.
  ///
  /// #### Parameters
  /// - `bytes` - Byte array to encode
  ///
  /// #### Returns
  /// `String` - Lowercase hex string
  static String bytesToHex(List<int> bytes) {
    return bytes
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Converts hexadecimal string to bytes.
  ///
  /// #### Parameters
  /// - `hex` - Hex string with or without 0x prefix (spaces are stripped)
  ///
  /// #### Returns
  /// `Uint8List` - Decoded bytes
  ///
  /// #### Throws
  /// - `FormatException` - If hex has odd length or invalid characters
  static Uint8List hexToBytes(String hex) {
    String cleanHex = hex.replaceAll(' ', '');
    if (cleanHex.startsWith('0x') || cleanHex.startsWith('0X')) {
      cleanHex = cleanHex.substring(2);
    }
    if (cleanHex.length % 2 != 0) {
      throw FormatException(
        'Hex string must have an even number of characters',
        hex,
      );
    }

    final List<int> bytes = <int>[];
    for (int i = 0; i < cleanHex.length; i += 2) {
      final String hexPair = cleanHex.substring(i, i + 2);
      final int? byte = int.tryParse(hexPair, radix: 16);

      if (byte == null) {
        throw FormatException('Invalid hex characters at position $i', hex, i);
      }

      bytes.add(byte);
    }

    return Uint8List.fromList(bytes);
  }

  /// Converts hexadecimal string to bytes, left-padding odd-length hex strings.
  ///
  /// Unlike [hexToBytes], this method handles odd-length hex strings by
  /// prepending a '0' to make the length even, interpreting `'fff'` as `'0fff'`.
  ///
  /// #### Parameters
  /// - `hex` - Hex string with or without 0x prefix (spaces are stripped)
  ///
  /// #### Returns
  /// `Uint8List` - Decoded bytes
  ///
  /// #### Throws
  /// - `FormatException` - If hex contains invalid characters
  static Uint8List hexToBytesLenient(String hex) {
    if (hex.isEmpty) return Uint8List(0);

    String cleanHex = hex.replaceAll(RegExp(r'\s'), '');
    if (cleanHex.startsWith('0x') || cleanHex.startsWith('0X')) {
      cleanHex = cleanHex.substring(2);
    }

    if (cleanHex.length % 2 != 0) {
      cleanHex = '0$cleanHex';
    }

    final int length = cleanHex.length ~/ 2;
    final Uint8List bytes = Uint8List(length);

    for (int i = 0, j = 0; i < cleanHex.length; i += 2, j++) {
      final int high = _hexCharToInt(cleanHex.codeUnitAt(i));
      final int low = _hexCharToInt(cleanHex.codeUnitAt(i + 1));
      bytes[j] = (high << 4) | low;
    }

    return bytes;
  }

  /// Converts hex char to int (0-15).
  @pragma('vm:prefer-inline')
  static int _hexCharToInt(int charCode) {
    if (charCode >= 48 && charCode <= 57) return charCode - 48;
    if (charCode >= 65 && charCode <= 70) return charCode - 55;
    if (charCode >= 97 && charCode <= 102) return charCode - 87;
    throw FormatException(
      'Invalid hex character: ${String.fromCharCode(charCode)}',
    );
  }

  /// Converts hexadecimal string to UTF-8 string.
  ///
  /// #### Parameters
  /// - `hex` - Hex string with or without 0x prefix
  ///
  /// #### Returns
  /// `String` - Decoded UTF-8 string
  ///
  /// #### Throws
  /// - `FormatException` - If hex is malformed or bytes are invalid UTF-8
  static String hexToString(String hex) {
    final Uint8List bytes = hexToBytes(hex);
    return utf8.decode(bytes);
  }

  /// Converts UTF-8 string to hex.
  ///
  /// #### Parameters
  /// - `str` - UTF-8 string to encode
  ///
  /// #### Returns
  /// `String` - Lowercase hex string
  static String utf8ToHex(String str) {
    return utf8
        .encode(str)
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
