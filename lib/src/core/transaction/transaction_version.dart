/// Transaction version identifier for protocol versioning.

/// Transaction version identifier.
/// Represents transaction protocol version as a positive integer.
///
/// #### Example
/// ```dart
/// const version = TransactionVersion(1);
/// print(version.value); // 1
/// ```
class TransactionVersion {
  /// Creates transaction version with validation.
  ///
  /// #### Parameters
  /// - `value` - Version number (must be > 0)
  ///
  /// #### Throws
  /// - `AssertionError` - If value <= 0
  ///
  /// #### Example
  /// ```dart
  /// const v1 = TransactionVersion(1); // OK
  /// const v2 = TransactionVersion(2); // OK
  /// // const invalid = TransactionVersion(0); // Assertion error in debug
  /// ```
  const TransactionVersion(this.value)
    : assert(value > 0, 'value must be superior to 0');

  /// Transaction version value (positive integer).
  final int value;
}
