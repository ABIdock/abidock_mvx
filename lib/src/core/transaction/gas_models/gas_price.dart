/// Gas price for transaction fee calculation.
/// Represents price per gas unit in smallest denomination (10^-18 EGLD).

/// Gas price specification with validation.
final class GasPrice {
  /// Creates gas price with validation.
  ///
  /// #### Parameters
  /// - `value` - Gas price in smallest denomination
  ///
  /// #### Throws
  /// - `AssertionError` - If value is negative
  const GasPrice(this.value) : assert(value >= 0, 'value cannot be negative');

  /// Gas price value in smallest denomination (10^-18 EGLD per gas).
  final int value;

  /// Adds two gas prices together.
  GasPrice operator +(GasPrice other) => GasPrice(value + other.value);

  /// Subtracts another gas price.
  ///
  /// #### Throws
  /// - `AssertionError` - If result would be negative
  GasPrice operator -(GasPrice other) => GasPrice(value - other.value);

  /// Multiplies gas price by integer factor.
  GasPrice operator *(int multiplicator) => GasPrice(value * multiplicator);

  /// Divides gas price by integer divisor (integer division).
  GasPrice operator ~/(int divisor) => GasPrice(value ~/ divisor);

  /// Returns gas price value as BigInt.
  ///
  /// Useful for gas cost calculations with Balance.
  ///
  /// #### Returns
  /// `BigInt` - Gas price as BigInt
  ///
  /// #### Example
  /// ```dart
  /// final gasLimit = GasLimit(500000);
  /// final gasPrice = GasPrice(1000000000);
  /// final gasCost = gasLimit.toBigInt * gasPrice.toBigInt;
  /// ```
  BigInt get toBigInt => BigInt.from(value);

  /// Compares this gas price with another.
  int compareTo(GasPrice other) => value.compareTo(other.value);

  /// Whether this gas price is greater than other.
  bool operator >(GasPrice other) => value > other.value;

  /// Whether this gas price is greater than or equal to other.
  bool operator >=(GasPrice other) => value >= other.value;

  /// Whether this gas price is less than other.
  bool operator <(GasPrice other) => value < other.value;

  /// Whether this gas price is less than or equal to other.
  bool operator <=(GasPrice other) => value <= other.value;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GasPrice && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'GasPrice{ $value }';
}
