import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../utils/helpers.dart';
import '../../codecs/codec_base.dart';
import 'numerical.dart';

/// Arbitrary precision unsigned integer type.
///
/// Represents unsigned integers of any size with no maximum limit.
/// Uses minimal encoding with no leading zeros, empty buffer for zero.
///
/// #### Example
/// ```dart
/// // From Dart int
/// final small = BigUIntType.create(42);
///
/// // From BigInt (large numbers)
/// final large = BigUIntType.create(BigInt.parse('999999999999999999999999'));
///
/// // Zero value
/// final zero = BigUIntType.create(0);
///
/// print(small.nativeValue); // 42
/// print(zero.toBytes().isEmpty); // true (empty buffer for zero)
///
/// // Use in struct definitions
/// final structType = StructType(fields: [
///   StructField('largeNumber', BigUIntType.type),
/// ]);
/// ```
@immutable
final class BigUIntType extends NumericalType {
  BigUIntType._() : super(name: 'BigUint', sizeInBytes: null, isSigned: false);

  static final BigUIntType _instance = BigUIntType._();

  @override
  String get className => 'BigUIntType';

  static const List<String> _classHierarchy = [
    'BigUIntType',
    'NumericalType',
    'PrimitiveType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  /// Creates a BigUIntValue from native Dart value.
  ///
  /// #### Parameters
  /// - `nativeValue` - `BigInt` or non-negative `int` value
  ///
  /// #### Returns
  /// `BigUIntValue` - Instance with the unsigned integer value
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is negative
  ///
  /// #### Example
  /// ```dart
  /// // From int
  /// final value1 = BigUIntType.create(42);
  ///
  /// // From BigInt (large numbers)
  /// final value2 = BigUIntType.create(BigInt.parse('123456789012345678901234567890'));
  ///
  /// // Zero value
  /// final zero = BigUIntType.create(0);
  ///
  /// // This throws: negative values not allowed
  /// // final invalid = BigUIntType.create(-1);
  /// ```
  static BigUIntValue create(dynamic nativeValue) {
    final BigInt bigInt = nativeValue is BigInt
        ? nativeValue
        : BigInt.from(requireAs<int>(nativeValue, 'nativeValue'));

    if (bigInt.isNegative) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'BigUIntType cannot be negative',
      );
    }
    return BigUIntValue(bigInt);
  }

  /// Creates a zero BigUint value.
  static BigUIntValue createZero() => BigUIntValue(BigInt.zero);

  /// Creates a BigUint from string representation.
  static BigUIntValue createFromString(String value) =>
      BigUIntValue(BigInt.parse(value));

  /// Gets the singleton type instance for use in type definitions.
  static BigUIntType get type => _instance;

  @override
  BigUIntValue createValue(dynamic nativeValue) => create(nativeValue);
}

/// Arbitrary precision unsigned integer value.
///
/// Holds a non-negative integer of any size with arithmetic and bitwise operations.
/// Provides minimal encoding with no leading zeros.
///
/// #### Example
/// ```dart
/// final value1 = BigUIntValue(BigInt.from(42));
/// final value2 = BigUIntValue(BigInt.parse('999999999999999999999999'));
/// final zero = BigUIntValue(BigInt.zero);
///
/// // Arithmetic operations
/// final sum = value1 + BigUIntValue(BigInt.from(8)); // 50
/// final product = value1 * BigUIntValue(BigInt.from(2)); // 84
///
/// // Comparisons
/// print(value1 > zero); // true
/// print(value2 >= value1); // true
///
/// // Binary encoding (minimal, no leading zeros)
/// print(zero.toBytes().isEmpty); // true
/// print(value1.toBytes()); // [42]
/// ```
@immutable
final class BigUIntValue extends NumericalValue {
  /// Creates a BigUInt value.
  ///
  /// #### Parameters
  /// - `value` - Non-negative BigInt instance to wrap
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is negative
  BigUIntValue(this.value) : super(BigUIntType._instance) {
    if (value.isNegative) {
      throw ArgumentError.value(value, 'value', 'Cannot be negative');
    }
  }

  /// The BigInt value.
  final BigInt value;

  @override
  String get className => 'BigUIntValue';

  static const List<String> _classHierarchy = [
    'BigUIntValue',
    'NumericalValue',
    'TypedValue',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  BigInt get nativeValue => value;

  @pragma('vm:prefer-inline')
  @override
  BigInt get asBigInt => value;

  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() {
    if (value == BigInt.zero) return BinaryCodecUtils.emptyBuffer;

    BigInt temp = value;
    int byteCount = 0;
    BigInt tempCopy = temp;
    while (tempCopy > BigInt.zero) {
      byteCount++;
      tempCopy = tempCopy >> 8;
    }

    final Uint8List bytes = Uint8List(byteCount);
    for (int i = byteCount - 1; i >= 0; i--) {
      bytes[i] = (temp & BigInt.from(0xFF)).toInt();
      temp = temp >> 8;
    }

    return bytes;
  }

  /// Adds two BigUIntValues.
  ///
  /// #### Parameters
  /// - `other` - BigUIntValue to add
  ///
  /// #### Returns
  /// `BigUIntValue` - Sum of the two values
  ///
  /// #### Example
  /// ```dart
  /// final a = BigUIntValue(BigInt.from(100));
  /// final b = BigUIntValue(BigInt.from(50));
  /// final sum = a + b; // BigUIntValue(150)
  /// ```
  BigUIntValue operator +(BigUIntValue other) =>
      BigUIntValue(value + other.value);

  /// Subtracts two BigUIntValues.
  ///
  /// #### Parameters
  /// - `other` - BigUIntValue to subtract
  ///
  /// #### Returns
  /// `BigUIntValue` - Difference of the two values
  ///
  /// #### Throws
  /// - `ArgumentError` - If result would be negative
  ///
  /// #### Example
  /// ```dart
  /// final a = BigUIntValue(BigInt.from(100));
  /// final b = BigUIntValue(BigInt.from(30));
  /// final diff = a - b; // BigUIntValue(70)
  /// // This throws: a - BigUIntValue(BigInt.from(200))
  /// ```
  BigUIntValue operator -(BigUIntValue other) {
    final BigInt result = value - other.value;
    if (result < BigInt.zero) {
      throw ArgumentError('Result cannot be negative for unsigned integer');
    }
    return BigUIntValue(result);
  }

  /// Multiplies two BigUIntValues.
  ///
  /// #### Parameters
  /// - `other` - BigUIntValue to multiply
  ///
  /// #### Returns
  /// `BigUIntValue` - Product of the two values
  ///
  /// #### Example
  /// ```dart
  /// final a = BigUIntValue(BigInt.from(10));
  /// final b = BigUIntValue(BigInt.from(5));
  /// final product = a * b; // BigUIntValue(50)
  /// ```
  BigUIntValue operator *(BigUIntValue other) =>
      BigUIntValue(value * other.value);

  /// Integer divides two BigUIntValues.
  ///
  /// #### Parameters
  /// - `other` - BigUIntValue divisor
  ///
  /// #### Returns
  /// `BigUIntValue` - Integer quotient
  ///
  /// #### Example
  /// ```dart
  /// final a = BigUIntValue(BigInt.from(10));
  /// final b = BigUIntValue(BigInt.from(3));
  /// final quotient = a ~/ b; // BigUIntValue(3)
  /// ```
  BigUIntValue operator ~/(BigUIntValue other) =>
      BigUIntValue(value ~/ other.value);

  /// Modulus of two BigUIntValues.
  ///
  /// #### Parameters
  /// - `other` - BigUIntValue divisor
  ///
  /// #### Returns
  /// `BigUIntValue` - Remainder
  ///
  /// #### Example
  /// ```dart
  /// final a = BigUIntValue(BigInt.from(10));
  /// final b = BigUIntValue(BigInt.from(3));
  /// final remainder = a % b; // BigUIntValue(1)
  /// ```
  BigUIntValue operator %(BigUIntValue other) =>
      BigUIntValue(value % other.value);

  /// Tests if this value is less than another.
  ///
  /// #### Parameters
  /// - `other` - BigUIntValue to compare
  ///
  /// #### Returns
  /// `bool` - True if this < other
  ///
  /// #### Example
  /// ```dart
  /// final a = BigUIntValue(BigInt.from(10));
  /// final b = BigUIntValue(BigInt.from(20));
  /// print(a < b); // true
  /// ```
  bool operator <(BigUIntValue other) => value < other.value;

  /// Tests if this value is less than or equal to another.
  ///
  /// #### Parameters
  /// - `other` - BigUIntValue to compare
  ///
  /// #### Returns
  /// `bool` - True if this <= other
  bool operator <=(BigUIntValue other) => value <= other.value;

  /// Tests if this value is greater than another.
  ///
  /// #### Parameters
  /// - `other` - BigUIntValue to compare
  ///
  /// #### Returns
  /// `bool` - True if this > other
  bool operator >(BigUIntValue other) => value > other.value;

  /// Tests if this value is greater than or equal to another.
  ///
  /// #### Parameters
  /// - `other` - BigUIntValue to compare
  ///
  /// #### Returns
  /// `bool` - True if this >= other
  bool operator >=(BigUIntValue other) => value >= other.value;

  /// Bitwise AND of two BigUIntValues.
  ///
  /// #### Parameters
  /// - `other` - BigUIntValue for AND operation
  ///
  /// #### Returns
  /// `BigUIntValue` - Result of bitwise AND
  ///
  /// #### Example
  /// ```dart
  /// final a = BigUIntValue(BigInt.from(12)); // 1100
  /// final b = BigUIntValue(BigInt.from(10)); // 1010
  /// final result = a & b; // BigUIntValue(8) = 1000
  /// ```
  BigUIntValue operator &(BigUIntValue other) =>
      BigUIntValue(value & other.value);

  /// Bitwise OR of two BigUIntValues.
  ///
  /// #### Parameters
  /// - `other` - BigUIntValue for OR operation
  ///
  /// #### Returns
  /// `BigUIntValue` - Result of bitwise OR
  ///
  /// #### Example
  /// ```dart
  /// final a = BigUIntValue(BigInt.from(12)); // 1100
  /// final b = BigUIntValue(BigInt.from(10)); // 1010
  /// final result = a | b; // BigUIntValue(14) = 1110
  /// ```
  BigUIntValue operator |(BigUIntValue other) =>
      BigUIntValue(value | other.value);

  /// Bitwise XOR of two BigUIntValues.
  ///
  /// #### Parameters
  /// - `other` - BigUIntValue for XOR operation
  ///
  /// #### Returns
  /// `BigUIntValue` - Result of bitwise XOR
  ///
  /// #### Example
  /// ```dart
  /// final a = BigUIntValue(BigInt.from(12)); // 1100
  /// final b = BigUIntValue(BigInt.from(10)); // 1010
  /// final result = a ^ b; // BigUIntValue(6) = 0110
  /// ```
  BigUIntValue operator ^(BigUIntValue other) =>
      BigUIntValue(value ^ other.value);

  /// Bitwise NOT operation (not supported for arbitrary precision unsigned).
  ///
  /// #### Throws
  /// - `UnsupportedError` - Bitwise NOT undefined for arbitrary precision unsigned integers
  BigUIntValue operator ~() => throw UnsupportedError(
    'Bitwise NOT not supported for arbitrary precision unsigned integers',
  );

  /// Left shift operation.
  ///
  /// #### Parameters
  /// - `shift` - Number of bits to shift left
  ///
  /// #### Returns
  /// `BigUIntValue` - Result of left shift
  ///
  /// #### Example
  /// ```dart
  /// final a = BigUIntValue(BigInt.from(5)); // 0101
  /// final result = a << 2; // BigUIntValue(20) = 10100
  /// ```
  BigUIntValue operator <<(int shift) => BigUIntValue(value << shift);

  /// Right shift operation.
  ///
  /// #### Parameters
  /// - `shift` - Number of bits to shift right
  ///
  /// #### Returns
  /// `BigUIntValue` - Result of right shift
  ///
  /// #### Example
  /// ```dart
  /// final a = BigUIntValue(BigInt.from(20)); // 10100
  /// final result = a >> 2; // BigUIntValue(5) = 0101
  /// ```
  BigUIntValue operator >>(int shift) => BigUIntValue(value >> shift);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BigUIntValue && value == other.value;

  @override
  int get hashCode => value.hashCode;
}
