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

  /// Returns all entries whose hex key starts with the hex-encoding of
  /// [prefix]. Useful for scanning ESDT / role-flag namespaces.
  List<AccountStorageEntry> entriesWithPrefix(String prefix) {
    final String hex = _utf8ToHex(prefix);
    return entries
        .where((AccountStorageEntry e) => e.key.startsWith(hex))
        .toList();
  }

  /// Looks up the ESDT balance entry for [tokenIdentifier] (and optional
  /// [nonce] for NFTs / SFTs / MetaESDT). Returns `null` when the account
  /// has no balance for that token.
  AccountStorageEntry? esdtEntry(String tokenIdentifier, {int? nonce}) {
    final StringBuffer key = StringBuffer(_utf8ToHex('ELRONDesdt'))
      ..write(_utf8ToHex(tokenIdentifier));
    if (nonce != null && nonce > 0) {
      key.write(_nonceHex(nonce));
    }
    return getEntry(key.toString());
  }

  /// Looks up the role-flag entry for [tokenIdentifier].
  AccountStorageEntry? esdtRolesEntry(String tokenIdentifier) {
    final String key =
        _utf8ToHex('ELRONDroleesdt') + _utf8ToHex(tokenIdentifier);
    return getEntry(key);
  }

  /// Looks up the last-created-nonce tracker for [tokenIdentifier].
  AccountStorageEntry? esdtLastNonceEntry(String tokenIdentifier) {
    final String key = _utf8ToHex('ELRONDnonce') + _utf8ToHex(tokenIdentifier);
    return getEntry(key);
  }

  static String _utf8ToHex(String s) =>
      s.codeUnits.map((int c) => c.toRadixString(16).padLeft(2, '0')).join();

  static String _nonceHex(int nonce) {
    String hex = nonce.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';
    return hex;
  }

  @override
  String toString() => 'AccountStorage(entries: ${entries.length})';
}
