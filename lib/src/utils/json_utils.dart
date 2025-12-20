import 'dart:convert';
import 'dart:typed_data';

/// Utilities for JSON parsing.
/// Static utility class for parsing loose JSON types from wallet providers.
class JsonUtils {
  JsonUtils._();

  /// Parses an integer from a dynamic value (int or String).
  ///
  /// Handles cases where wallets return numbers as strings to avoid precision loss
  /// or due to loose typing.
  ///
  /// #### Parameters
  /// - `value` - The value to parse (int, String, or null)
  /// - `defaultValue` - Value to return if parsing fails (default: 0)
  ///
  /// #### Returns
  /// `int` - The parsed integer or default value
  static int parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Parses a byte array from a dynamic value (Base64 or plain String).
  ///
  /// Attempts to decode as Base64 first (standard for binary data in JSON).
  /// Falls back to UTF-8 encoding if Base64 decoding fails
  ///
  /// #### Parameters
  /// - `value` - The value to parse (String or null)
  ///
  /// #### Returns
  /// `Uint8List` - Decoded bytes or empty list if null/invalid
  static Uint8List parseBytes(dynamic value) {
    if (value == null) return Uint8List(0);
    if (value is! String) return Uint8List(0);
    if (value.isEmpty) return Uint8List(0);

    try {
      return base64.decode(value);
    } catch (_) {
      return Uint8List.fromList(utf8.encode(value));
    }
  }

  /// Parses a double from a dynamic value (double, int, or String).
  ///
  /// Handles cases where wallets return numbers as strings to avoid precision loss
  /// or due to loose typing.
  ///
  /// #### Parameters
  /// - `value` - The value to parse (double, int, String, or null)
  /// - `defaultValue` - Value to return if parsing fails (default: 0.0)
  ///
  /// #### Returns
  /// `double` - The parsed double or default value
  static double parseDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Ensures a value is a String.
  ///
  /// Safely converts any value to String, handling nulls.
  ///
  /// #### Parameters
  /// - `value` - The value to convert
  /// - `defaultValue` - Value to return if input is null (default: '')
  ///
  /// #### Returns
  /// `String` - The string representation or default value
  static String parseString(dynamic value, [String defaultValue = '']) {
    return value?.toString() ?? defaultValue;
  }
}
