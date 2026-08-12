/// Shared private helpers for transaction-factory implementations.
///
/// A single home for the `@`-delimited data-field hex encoding, so every
/// factory emits identical bytes for the same numeric argument.
library;

/// Encodes [value] as lower-case hex with a leading zero pad to keep the
/// length even — required by the MultiversX `@`-delimited data wire format.
///
/// #### Parameters
/// - `value` - Non-negative integer to encode.
///
/// #### Returns
/// `String` - Even-length lower-case hex without a `0x` prefix.
///
/// #### Example
/// ```dart
/// evenHexInt(5);   // '05'
/// evenHexInt(255); // 'ff'
/// ```
String evenHexInt(int value) {
  final String hex = value.toRadixString(16);
  return hex.length.isOdd ? '0$hex' : hex;
}
