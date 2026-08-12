import 'dart:convert';

import 'package:convert/convert.dart';

import '../../utils/helpers.dart';

/// Smart contract storage key-value pair entry.
/// Both [key] and [value] are stored as hex strings exactly as returned by the
/// network; use [decodedValue] to get the UTF-8 interpretation of the raw
/// storage bytes.
class AccountStorageEntry {
  /// Creates storage entry with key and value.
  ///
  /// #### Parameters
  /// - `key` - Storage key (hex encoded)
  /// - `value` - Storage value (hex encoded)
  const AccountStorageEntry({required this.key, required this.value});

  /// Creates storage entry from network API response.
  ///
  /// #### Parameters
  /// - `data` - JSON object with 'value' field
  /// - `key` - Storage key identifier
  ///
  /// #### Returns
  /// `AccountStorageEntry` - Entry with parsed value
  factory AccountStorageEntry.fromHttpResponse(
    Map<String, dynamic> data,
    String key,
  ) {
    return AccountStorageEntry(
      key: key,
      value: optionalAs<String>(data['value'], 'value') ?? '',
    );
  }

  /// Storage key (hex encoded).
  final String key;

  /// Storage value (hex encoded).
  final String value;

  /// Hex-decoded UTF-8 representation of [value].
  ///
  /// Contract storage holds arbitrary bytes, so invalid UTF-8 is decoded
  /// leniently rather than thrown on. Returns an empty string if [value] is
  /// empty or not valid hex.
  ///
  /// #### Returns
  /// `String` - UTF-8 string decoded from the hex `value`
  String get decodedValue {
    if (value.isEmpty) return '';
    try {
      final List<int> bytes = hex.decode(value);
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  @override
  String toString() => 'AccountStorageEntry(key: $key, value: $value)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccountStorageEntry &&
        other.key == key &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(key, value);
}
