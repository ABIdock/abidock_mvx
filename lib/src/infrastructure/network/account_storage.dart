import '../../utils/helpers.dart';
import 'account_storage_entry.dart';

/// Smart contract account storage with key-value pairs.
/// Each entry is a key-value pair stored in the contract's state.
class AccountStorage {
  /// Creates account storage with list of entries.
  ///
  /// #### Parameters
  /// - `entries` - List of key-value storage entries
  const AccountStorage({required this.entries});

  /// Creates account storage from network API response.
  ///
  /// #### Parameters
  /// - `data` - JSON response with 'pairs' field containing key-value map
  ///
  /// #### Returns
  /// `AccountStorage` - Instance with parsed entries
  factory AccountStorage.fromHttpResponse(Map<String, dynamic> data) {
    final Map<String, dynamic> pairs =
        optionalAs<Map<String, dynamic>>(data['pairs'], 'pairs') ??
        <String, dynamic>{};
    final List<AccountStorageEntry> entries = pairs.entries.map((
      MapEntry<String, dynamic> entry,
    ) {
      return AccountStorageEntry(
        key: entry.key,
        value: requireAs<String>(entry.value, 'value'),
      );
    }).toList();

    return AccountStorage(entries: entries);
  }

  /// Storage entries.
  final List<AccountStorageEntry> entries;

  /// Gets storage entry by key.
  ///
  /// #### Parameters
  /// - `key` - Storage key to search for
  ///
  /// #### Returns
  /// `AccountStorageEntry?` - Entry if found, null otherwise
  AccountStorageEntry? getEntry(String key) {
    try {
      return entries.firstWhere(
        (AccountStorageEntry entry) => entry.key == key,
      );
    } catch (e) {
      return null;
    }
  }

  /// Checks if storage key exists.
  ///
  /// #### Parameters
  /// - `key` - Storage key to check
  ///
  /// #### Returns
  /// `bool` - true if key exists, false otherwise
  bool hasKey(String key) {
    return entries.any((AccountStorageEntry entry) => entry.key == key);
  }

  @override
  String toString() => 'AccountStorage(entries: ${entries.length})';
}
