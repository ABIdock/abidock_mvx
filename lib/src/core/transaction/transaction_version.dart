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
  /// Creates transaction version with compile-time validation.
  ///
  /// Use this constructor with literal values (the `assert` fires in debug).
  /// For runtime values from untrusted sources, use [TransactionVersion.validated].
  ///
  /// #### Parameters
  /// - `value` - Version number (must be > 0)
  ///
  /// #### Throws
  /// - `AssertionError` - If value <= 0 (debug only)
  ///
  /// #### Example
  /// ```dart
  /// const v1 = TransactionVersion(1); // OK
  /// const v2 = TransactionVersion(2); // OK
  /// ```
  const TransactionVersion(this.value)
    : assert(value > 0, 'value must be superior to 0');

  /// Creates transaction version with runtime validation.
  ///
  /// Use when [value] comes from network input or user input.
  ///
  /// #### Throws
  /// - `ArgumentError` - If value <= 0
  factory TransactionVersion.validated(int value) {
    if (value <= 0) {
      throw ArgumentError.value(value, 'value', 'must be > 0');
    }
    return TransactionVersion(value);
  }

  /// Transaction version value (positive integer).
  final int value;
}
