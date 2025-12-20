/// Gas limit specification for transaction execution.
/// Represents maximum gas units a transaction can consume. Unused gas is refunded.
import 'dart:typed_data';

import '../../network_configuration.dart';

/// Gas limit for transaction execution with validation.
final class GasLimit {
  /// Creates gas limit with validation.
  ///
  /// #### Parameters
  /// - `value` - Gas limit in gas units
  ///
  /// #### Throws
  /// - `AssertionError` - If value is negative
  const GasLimit(this.value) : assert(value >= 0, 'value cannot be negative');

  /// Creates gas limit with minimum value for simple transactions.
  ///
  /// #### Parameters
  /// - `minGasLimit` - Minimum gas (default: 50,000)
  ///
  /// #### Returns
  /// `GasLimit` - Minimum value gas limit
  const GasLimit.min({int minGasLimit = defaultMinGasLimit})
    : value = minGasLimit;

  /// Creates gas limit based on transaction payload size.
  /// Calculates gas as minGasLimit + (dataLength * gasPerDataByte).
  ///
  /// #### Parameters
  /// - `data` - Transaction data payload
  /// - `minGasLimit` - Base minimum gas (default: 50,000)
  /// - `gasPerDataByte` - Gas cost per data byte (default: 1,500)
  ///
  /// #### Returns
  /// `GasLimit` - Calculated gas limit for payload
  factory GasLimit.forPayload({
    Uint8List? data,
    int minGasLimit = defaultMinGasLimit,
    int gasPerDataByte = defaultGasPerDataByte,
  }) {
    int value = minGasLimit;
    if (data != null) {
      value += gasPerDataByte * data.lengthInBytes;
    }
    return GasLimit(value);
  }

  /// Gas limit value in gas units.
  final int value;

  /// Adds two gas limits together.
  ///
  /// #### Parameters
  /// - `gasLimit` - Gas limit to add
  ///
  /// #### Returns
  /// `GasLimit` - Combined value gas limit
  GasLimit operator +(GasLimit gasLimit) => GasLimit(value + gasLimit.value);

  /// Subtracts another gas limit.
  ///
  /// #### Parameters
  /// - `gasLimit` - Gas limit to subtract
  ///
  /// #### Returns
  /// `GasLimit` - Difference gas limit
  ///
  /// #### Throws
  /// - `AssertionError` - If result would be negative
  GasLimit operator -(GasLimit gasLimit) => GasLimit(value - gasLimit.value);

  /// Multiplies gas limit by integer factor.
  ///
  /// #### Parameters
  /// - `multiplicator` - Factor to multiply by
  ///
  /// #### Returns
  /// `GasLimit` - Multiplied value gas limit
  GasLimit operator *(int multiplicator) => GasLimit(value * multiplicator);

  /// Divides gas limit by integer divisor (integer division).
  ///
  /// #### Parameters
  /// - `divisor` - Integer to divide by
  ///
  /// #### Returns
  /// `GasLimit` - Divided gas limit (rounded down)
  GasLimit operator ~/(int divisor) => GasLimit(value ~/ divisor);

  /// Returns gas limit value as BigInt.
  ///
  /// Useful for gas cost calculations with Balance.
  ///
  /// #### Returns
  /// `BigInt` - Gas limit as BigInt
  ///
  /// #### Example
  /// ```dart
  /// final gasLimit = GasLimit(500000);
  /// final gasPrice = GasPrice(1000000000);
  /// final gasCost = gasLimit.toBigInt * gasPrice.toBigInt;
  /// ```
  BigInt get toBigInt => BigInt.from(value);

  /// Compares this gas limit with another.
  int compareTo(GasLimit other) => value.compareTo(other.value);

  /// Whether this gas limit is greater than other.
  bool operator >(GasLimit other) => value > other.value;

  /// Whether this gas limit is greater than or equal to other.
  bool operator >=(GasLimit other) => value >= other.value;

  /// Whether this gas limit is less than other.
  bool operator <(GasLimit other) => value < other.value;

  /// Whether this gas limit is less than or equal to other.
  bool operator <=(GasLimit other) => value <= other.value;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GasLimit && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'GasLimit{ $value }';
}
