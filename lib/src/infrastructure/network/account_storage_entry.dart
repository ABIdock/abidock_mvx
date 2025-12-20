import '../../utils/helpers.dart';

/// Smart contract storage key-value pair entry.
/// Both key and value are hex-encoded strings.
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
