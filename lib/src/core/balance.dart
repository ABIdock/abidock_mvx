/// Decimal places for EGLD denomination.
const int denomination = 18;

/// One EGLD in smallest unit (attoEGLD).
final BigInt oneEGLD = BigInt.parse('1000000000000000000');

/// EGLD balance.
/// Provides conversion between attoEGLD (atomic units) and EGLD (human-readable).
/// Supports arithmetic operations with overflow protection.
///
/// #### Example
/// ```dart
/// // From attoEGLD
/// final bal1 = Balance(BigInt.parse('1000000000000000000')); // 1 EGLD
///
/// // From EGLD (human-readable)
/// final bal2 = Balance.fromEgld(2.5); // 2.5 EGLD
///
/// // Formatting
/// print(bal1.toDenominated); // 1.000000000000000000
/// print(bal1.toDenominatedTrimmed); // 1
/// print(bal2.toDenominatedTrimmed); // 2.5
///
/// // Arithmetic
/// final total = bal1 + bal2;
/// print(total.toDenominatedTrimmed); // 3.5
/// ```
final class Balance {
  /// Creates Balance with value in attoEGLD.
  ///
  /// #### Parameters
  /// - `value` - Balance in attoEGLD (smallest unit, BigInt)
  ///
  /// #### Throws
  /// - `AssertionError` - If value is negative
  Balance(this.value)
    : assert(value >= BigInt.zero, 'balance cannot be negative');

  /// Creates Balance with zero value.
  Balance.zero() : value = BigInt.zero;

  /// Creates Balance from string (attoEGLD).
  ///
  /// #### Parameters
  /// - `value` - String representation of attoEGLD amount
  ///
  /// #### Returns
  /// Balance instance
  ///
  /// #### Throws
  /// - `FormatException` - If string is not valid BigInt
  ///
  /// #### Example
  /// ```dart
  /// final bal = Balance.fromString('1000000000000000000');
  /// print(bal.toDenominatedTrimmed); // 1
  /// ```
  factory Balance.fromString(String value) {
    return Balance(BigInt.parse(value));
  }

  /// Creates Balance from numeric value (attoEGLD).
  ///
  /// #### Parameters
  /// - `value` - Numeric value in attoEGLD (int or double)
  ///
  /// #### Returns
  /// Balance instance
  ///
  /// #### Example
  /// ```dart
  /// final bal = Balance.fromNum(1000000);
  /// print(bal.value); // BigInt(1000000)
  /// ```
  factory Balance.fromNum(num value) {
    return Balance(BigInt.from(value));
  }

  /// Creates Balance from EGLD string value.
  ///
  /// #### Parameters
  /// - `value` - EGLD amount as string (e.g., '1.5' for 1.5 EGLD)
  ///
  /// #### Returns
  /// Balance instance in EGLD
  ///
  /// #### Throws
  /// - `FormatException` - If string format is invalid
  ///
  /// #### Example
  /// ```dart
  /// // Avoid: Balance.fromEgld(0.1 + 0.2) - floating point issues
  /// // Use: Balance.fromEgldString('0.3') - string precision
  /// final bal = Balance.fromEgldString('2.5');
  /// print(bal.toDenominatedTrimmed); // 2.5
  /// ```
  factory Balance.fromEgldString(String value) {
    if (value.isEmpty) {
      throw const FormatException('Empty string is not a valid EGLD value');
    }

    final trimmed = value.trim();
    if (trimmed == '0' || trimmed == '0.0') {
      return Balance.zero();
    }

    final List<String> parts = trimmed.split('.');
    if (parts.length > 2) {
      throw FormatException('Invalid EGLD value format: $value');
    }

    final String integerPart = parts[0].isEmpty ? '0' : parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '';

    if (decimalPart.length > denomination) {
      decimalPart = decimalPart.substring(0, denomination);
    } else {
      decimalPart = decimalPart.padRight(denomination, '0');
    }

    final String combinedStr = integerPart + decimalPart;
    final BigInt result = BigInt.parse(combinedStr);

    return Balance(result);
  }

  /// Creates Balance from EGLD value (human-readable).
  ///
  /// A decimal written in source converts to the attoEGLD integer it denotes:
  /// `Balance.fromEgld(0.1).value` is exactly `100000000000000000`. Integers
  /// are scaled with exact integer arithmetic; a double is converted from its
  /// shortest decimal representation, which is the literal that produced it.
  ///
  /// **Note:** a double only holds about 17 significant decimal digits, so an
  /// arithmetic expression may not evaluate to the number it appears to be —
  /// `0.1 + 0.2` is the double `0.30000000000000004`, and converts to that.
  /// Use [fromEgldString] to state an amount exactly.
  ///
  /// #### Parameters
  /// - `value` - EGLD amount as num (e.g., 1.5 for 1.5 EGLD)
  ///
  /// #### Returns
  /// Balance instance in attoEGLD
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is not finite, or needs more than
  ///   [denomination] decimal places; attoEGLD is the smallest representable
  ///   unit, so such a value is rejected rather than silently truncated
  ///
  /// #### Example
  /// ```dart
  /// final bal1 = Balance.fromEgld(1.0); // 1 EGLD
  /// final bal2 = Balance.fromEgld(2.5); // 2.5 EGLD
  /// final bal3 = Balance.fromEgld(0.000000000000000001); // 1 attoEGLD
  ///
  /// print(bal1.value); // BigInt(1000000000000000000)
  /// print(bal2.toDenominatedTrimmed); // 2.5
  /// ```
  factory Balance.fromEgld(num value) {
    if (value is int) {
      return Balance(BigInt.from(value) * oneEGLD);
    }

    final double amount = value.toDouble();
    if (!amount.isFinite) {
      throw ArgumentError.value(value, 'value', 'must be a finite EGLD amount');
    }
    if (amount == 0) {
      return Balance.zero();
    }

    return Balance(_attoFromDouble(amount));
  }

  /// Balance value in attoEGLD (smallest unit).
  final BigInt value;

  /// Balance as denominated string (18 decimal places).
  ///
  /// #### Returns
  /// String with full 18 decimal places
  String get toDenominated {
    final String padded = value.toString().padLeft(denomination, '0');
    final String decimals = padded.substring(padded.length - denomination);
    final String integer = padded
        .substring(0, padded.length - denomination)
        .padLeft(1, '0');
    return '$integer.$decimals';
  }

  /// Balance as denominated string with trailing zeros removed.
  String get toDenominatedTrimmed {
    return toDenominated.replaceAll(RegExp(r'\.?0+$'), '');
  }

  /// Whether balance is zero.
  bool get isZero => value == BigInt.zero;

  /// Whether balance is positive.
  bool get isPositive => value > BigInt.zero;

  /// Whether balance is negative.
  bool get isNegative => value < BigInt.zero;

  /// Adds another balance.
  Balance operator +(Balance other) {
    return Balance(value + other.value);
  }

  /// Subtracts another balance.
  ///
  /// #### Parameters
  /// - `other` - Balance to subtract
  ///
  /// #### Returns
  /// New Balance with difference
  ///
  /// #### Throws
  /// - `ArgumentError` - If result would be negative
  ///
  /// #### Example
  /// ```dart
  /// final bal1 = Balance.fromEgld(5.0);
  /// final bal2 = Balance.fromEgld(2.0);
  /// final remaining = bal1 - bal2;
  /// print(remaining.toDenominatedTrimmed); // 3
  /// ```
  Balance operator -(Balance other) {
    final BigInt result = value - other.value;
    if (result < BigInt.zero) {
      throw ArgumentError(
        'Cannot create negative balance: $toDenominated - ${other.toDenominated}',
      );
    }
    return Balance(result);
  }

  /// Multiplies this balance by a scalar (e.g. `gasLimit * gasPrice`).
  Balance operator *(BigInt scalar) {
    if (scalar.isNegative) {
      throw ArgumentError.value(scalar, 'scalar', 'must be non-negative');
    }
    return Balance(value * scalar);
  }

  /// Integer-divides this balance by a scalar.
  Balance operator ~/(BigInt divisor) {
    if (divisor <= BigInt.zero) {
      throw ArgumentError.value(divisor, 'divisor', 'must be positive');
    }
    return Balance(value ~/ divisor);
  }

  /// Integer-divides this balance by another balance and returns a scalar ratio.
  BigInt ratioTo(Balance other) {
    if (other.value == BigInt.zero) {
      throw ArgumentError('Cannot take ratio with zero balance');
    }
    return value ~/ other.value;
  }

  /// Modulo a scalar.
  Balance operator %(BigInt divisor) {
    if (divisor <= BigInt.zero) {
      throw ArgumentError.value(divisor, 'divisor', 'must be positive');
    }
    return Balance(value % divisor);
  }

  /// Compares this balance with another.
  int compareTo(Balance other) {
    return value.compareTo(other.value);
  }

  /// Whether this balance is greater than other.
  bool operator >(Balance other) => compareTo(other) > 0;

  /// Whether this balance is greater than or equal to other.
  bool operator >=(Balance other) => compareTo(other) >= 0;

  /// Whether this balance is less than other.
  bool operator <(Balance other) => compareTo(other) < 0;

  /// Whether this balance is less than or equal to other.
  bool operator <=(Balance other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Balance && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Balance{ $toDenominatedTrimmed }';

  /// Detailed string including full denominated value.
  String toDetailedString() {
    return 'Balance{ value: $value, formatted: $toDenominated }';
  }

  /// Converts a finite, non-zero double to attoEGLD without losing precision.
  ///
  /// The shortest decimal representation of a double is the only one that reads
  /// back as the same bits, so it is the decimal the caller wrote. Its digits
  /// are rescaled to attoEGLD with integer arithmetic, which never rounds.
  ///
  /// #### Parameters
  /// - `amount` - Finite, non-zero EGLD amount
  ///
  /// #### Returns
  /// The amount in attoEGLD
  ///
  /// #### Throws
  /// - `ArgumentError` - If the amount needs more than [denomination] decimals
  static BigInt _attoFromDouble(double amount) {
    String literal = amount.toString();
    final bool negative = literal.startsWith('-');
    if (negative) {
      literal = literal.substring(1);
    }

    int exponent = 0;
    final int exponentIndex = literal.indexOf('e');
    if (exponentIndex >= 0) {
      exponent = int.parse(literal.substring(exponentIndex + 1));
      literal = literal.substring(0, exponentIndex);
    }

    String digits = literal;
    int scale = -exponent;
    final int pointIndex = literal.indexOf('.');
    if (pointIndex >= 0) {
      digits =
          literal.substring(0, pointIndex) + literal.substring(pointIndex + 1);
      scale += literal.length - pointIndex - 1;
    }

    final BigInt mantissa = BigInt.parse(digits);
    final BigInt ten = BigInt.from(10);
    final int shift = denomination - scale;

    if (shift < 0) {
      final BigInt unit = ten.pow(-shift);
      if (mantissa % unit != BigInt.zero) {
        throw ArgumentError.value(
          amount,
          'value',
          'EGLD amount needs more than $denomination decimal places, '
              'but attoEGLD is the smallest unit',
        );
      }
      final BigInt reduced = mantissa ~/ unit;
      return negative ? -reduced : reduced;
    }

    final BigInt atto = mantissa * ten.pow(shift);
    return negative ? -atto : atto;
  }
}
