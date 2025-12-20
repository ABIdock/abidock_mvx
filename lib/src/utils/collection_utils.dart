/// Collection utility functions for equality comparisons and hashing.
///
/// Provides reusable functions for comparing lists, maps, and byte arrays
/// used throughout the SDK for implementing equals and hashCode.
import 'dart:typed_data';

/// Static utility class for collection operations.
///
/// Provides methods for comparing lists, maps, and byte arrays.
class CollectionUtils {
  /// Private constructor to prevent instantiation.
  CollectionUtils._();

  /// Checks deep equality of two lists.
  ///
  /// Returns true if both lists are null, identical, or contain equal elements
  /// in the same order. Uses element-wise `==` comparison.
  ///
  /// #### Parameters
  /// - `a` - First list (nullable)
  /// - `b` - Second list (nullable)
  ///
  /// #### Returns
  /// `bool` - True if lists are equal
  ///
  /// #### Example
  /// ```dart
  /// CollectionUtils.listEquals([1, 2, 3], [1, 2, 3]); // true
  /// CollectionUtils.listEquals([1, 2], [1, 2, 3]); // false
  /// CollectionUtils.listEquals(null, null); // true
  /// CollectionUtils.listEquals([1], null); // false
  /// ```
  static bool listEquals<T>(List<T>? a, List<T>? b) {
    if (identical(a, b)) return true;
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Checks byte-wise equality of two Uint8Lists.
  ///
  /// Optimized for comparing binary data like signatures, hashes, and encoded values.
  ///
  /// #### Parameters
  /// - `a` - First byte array
  /// - `b` - Second byte array
  ///
  /// #### Returns
  /// `bool` - True if byte arrays are identical
  ///
  /// #### Example
  /// ```dart
  /// CollectionUtils.bytesEquals(Uint8List.fromList([1, 2]), Uint8List.fromList([1, 2])); // true
  /// CollectionUtils.bytesEquals(Uint8List.fromList([1]), Uint8List.fromList([2])); // false
  /// ```
  static bool bytesEquals(Uint8List a, Uint8List b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Checks equality of two lists of Uint8Lists.
  ///
  /// Uses byte-wise comparison for each element.
  ///
  /// #### Parameters
  /// - `a` - First list of byte arrays
  /// - `b` - Second list of byte arrays
  ///
  /// #### Returns
  /// `bool` - True if all byte arrays match
  ///
  /// #### Example
  /// ```dart
  /// final list1 = [Uint8List.fromList([1]), Uint8List.fromList([2])];
  /// final list2 = [Uint8List.fromList([1]), Uint8List.fromList([2])];
  /// CollectionUtils.bytesListEquals(list1, list2); // true
  /// ```
  static bool bytesListEquals(List<Uint8List> a, List<Uint8List> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!bytesEquals(a[i], b[i])) return false;
    }
    return true;
  }

  /// Computes hash code for a list.
  ///
  /// Returns 0 for null lists, otherwise combines all element hash codes.
  ///
  /// #### Parameters
  /// - `list` - List to hash (nullable)
  ///
  /// #### Returns
  /// `int` - Combined hash code
  ///
  /// #### Example
  /// ```dart
  /// CollectionUtils.listHashCode([1, 2, 3]); // consistent hash
  /// CollectionUtils.listHashCode(null); // 0
  /// ```
  static int listHashCode<T>(List<T>? list) {
    if (list == null || list.isEmpty) return 0;
    return Object.hashAll(list);
  }

  /// Computes hash code for a list of Uint8Lists.
  ///
  /// Uses Object.hashAll for each byte array, then combines them with Object.hash.
  ///
  /// #### Parameters
  /// - `list` - List of byte arrays
  ///
  /// #### Returns
  /// `int` - Combined hash code
  static int bytesListHashCode(List<Uint8List> list) {
    if (list.isEmpty) return 0;
    final hashes = list
        .map((Uint8List bytes) => Object.hashAll(bytes))
        .toList();
    return Object.hashAll(hashes);
  }

  /// Checks shallow equality of two maps.
  ///
  /// Returns true if both maps have the same keys with equal values.
  /// Uses `==` for value comparison (not deep equality).
  ///
  /// #### Parameters
  /// - `a` - First map (nullable)
  /// - `b` - Second map (nullable)
  ///
  /// #### Returns
  /// `bool` - True if maps are equal
  ///
  /// #### Example
  /// ```dart
  /// CollectionUtils.mapEquals({'a': 1}, {'a': 1}); // true
  /// CollectionUtils.mapEquals({'a': 1}, {'a': 2}); // false
  /// CollectionUtils.mapEquals(null, null); // true
  /// ```
  static bool mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
    if (identical(a, b)) return true;
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (final K key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
