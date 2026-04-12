import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../utils/helpers.dart';
import '../../codecs/codec_base.dart';
import 'numerical.dart';

/// Arbitrary precision signed integer type.
///
/// Represents signed integers of any size with no minimum/maximum limit.
/// Uses minimal two's complement encoding for efficient storage.
///
/// #### Example
/// ```dart
/// // From Dart int
/// final small = BigIntType.create(42);
///
/// // From BigInt (large numbers)
/// final large = BigIntType.create(BigInt.parse('123456789012345678901234567890'));
///
/// print(small.nativeValue); // 42
/// print(large.toHex()); // Hex representation
///
/// // Use in struct definitions
/// final structType = StructType(fields: [
///   StructField('signedLarge', BigIntType.type),
/// ]);
/// ```
@immutable
final class BigIntType extends NumericalType {
  BigIntType._() : super(name: 'BigInt', sizeInBytes: null, isSigned: true);

  static final BigIntType _instance = BigIntType._();

  @override
  String get className => 'BigIntType';

  static const List<String> _classHierarchy = [
    'BigIntType',
    'NumericalType',
    'PrimitiveType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  /// Creates a BigIntValue from native Dart value.
  ///
  /// #### Parameters
  /// - `nativeValue` - `BigInt` or `int` value
  ///
  /// #### Returns
  /// `BigIntValue` - Instance with the signed integer value
  ///
  /// #### Example
  /// ```dart
  /// // From int
  /// final value1 = BigIntType.create(42);
  ///
  /// // From BigInt (large numbers)
  /// final value2 = BigIntType.create(BigInt.parse('999999999999999999999'));
  ///
  /// // Negative values
  /// final value3 = BigIntType.create(-123);
  /// ```
  static BigIntValue create(dynamic nativeValue) {
    final BigInt bigInt = nativeValue is BigInt
        ? nativeValue
        : BigInt.from(requireAs<int>(nativeValue, 'nativeValue'));

    return BigIntValue(bigInt);
  }

  /// Creates a zero BigInt value.
  static BigIntValue createZero() => BigIntValue(BigInt.zero);

  /// Creates a BigInt from string representation.
  static BigIntValue createFromString(String value) =>
      BigIntValue(BigInt.parse(value));

  /// Gets the singleton type instance for use in type definitions.
  static BigIntType get type => _instance;

  @override
  BigIntValue createValue(dynamic nativeValue) => create(nativeValue);
}

/// Arbitrary precision signed integer value.
///
/// Holds a signed integer of any size with full arithmetic and bitwise operations.
/// Supports conversion to bytes using two's complement encoding.
///
/// #### Example
/// ```dart
/// final value1 = BigIntValue(BigInt.from(42));
/// final value2 = BigIntValue(BigInt.parse('123456789012345678901234567890'));
/// final value3 = BigIntValue(BigInt.from(-999));
///
/// // Arithmetic operations
/// final sum = value1 + BigIntValue(BigInt.from(8)); // 50
/// final diff = value1 - BigIntValue(BigInt.from(10)); // 32
///
/// // Comparisons
/// print(value1 > BigIntValue(BigInt.from(0))); // true
/// print(value3.nativeValue.isNegative); // true
///
/// // Binary encoding
/// final bytes = value1.toBytes(); // Two's complement bytes
/// ```
@immutable
final class BigIntValue extends NumericalValue {
  /// Creates a BigInt value.
  ///
  /// #### Parameters
  /// - `value` - BigInt instance to wrap
  BigIntValue(this.value) : super(BigIntType._instance);

  /// The BigInt value.
  final BigInt value;

  @override
  String get className => 'BigIntValue';

  static const List<String> _classHierarchy = [
    'BigIntValue',
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

    final bool isNegative = value.isNegative;
    final BigInt absValue = value.abs();

    int byteCount = 0;
    BigInt tempCopy = absValue;
    while (tempCopy > BigInt.zero) {
      byteCount++;
      tempCopy = tempCopy >> 8;
    }

    final Uint8List bytes = Uint8List(byteCount);
    BigInt temp = absValue;
    for (int i = byteCount - 1; i >= 0; i--) {
      bytes[i] = (temp & BigInt.from(0xFF)).toInt();
      temp = temp >> 8;
    }

    if (isNegative) {
      for (int i = bytes.length - 1; i >= 0; i--) {
        bytes[i] = (~bytes[i]) & 0xFF;
      }
      int carry = 1;
      for (int i = bytes.length - 1; i >= 0 && carry > 0; i--) {
        final int sum = bytes[i] + carry;
        bytes[i] = sum & 0xFF;
        carry = sum >> 8;
      }
    }

    if (!isNegative && bytes.isNotEmpty && (bytes[0] & 0x80) != 0) {
      final Uint8List extended = Uint8List(bytes.length + 1);
      extended.setRange(1, extended.length, bytes);
      return extended;
    }

    return bytes;
  }

  /// Adds two BigIntValues.
  ///
  /// #### Parameters
  /// - `other` - BigIntValue to add
  ///
  /// #### Returns
  /// `BigIntValue` - Sum of the two values
  ///
  /// #### Example
  /// ```dart
  /// final a = BigIntValue(BigInt.from(100));
  /// final b = BigIntValue(BigInt.from(50));
  /// final sum = a + b; // BigIntValue(150)
  /// ```
  BigIntValue operator +(BigIntValue other) => BigIntValue(value + other.value);

  /// Subtracts two BigIntValues.
  ///
  /// #### Parameters
  /// - `other` - BigIntValue to subtract
  ///
  /// #### Returns
  /// `BigIntValue` - Difference of the two values
  ///
  /// #### Example
  /// ```dart
  /// final a = BigIntValue(BigInt.from(100));
  /// final b = BigIntValue(BigInt.from(30));
  /// final diff = a - b; // BigIntValue(70)
  /// ```
  BigIntValue operator -(BigIntValue other) => BigIntValue(value - other.value);

  /// Multiplies two BigIntValues.
  ///
  /// #### Parameters
  /// - `other` - BigIntValue to multiply
  ///
  /// #### Returns
  /// `BigIntValue` - Product of the two values
  ///
  /// #### Example
  /// ```dart
  /// final a = BigIntValue(BigInt.from(10));
  /// final b = BigIntValue(BigInt.from(5));
  /// final product = a * b; // BigIntValue(50)
  /// ```
  BigIntValue operator *(BigIntValue other) => BigIntValue(value * other.value);

  /// Integer divides two BigIntValues.
  ///
  /// #### Parameters
  /// - `other` - BigIntValue divisor
  ///
  /// #### Returns
  /// `BigIntValue` - Integer quotient
  ///
  /// #### Example
  /// ```dart
  /// final a = BigIntValue(BigInt.from(10));
  /// final b = BigIntValue(BigInt.from(3));
  /// final quotient = a ~/ b; // BigIntValue(3)
  /// ```
  BigIntValue operator ~/(BigIntValue other) =>
      BigIntValue(value ~/ other.value);

  /// Modulus of two BigIntValues.
  ///
  /// #### Parameters
  /// - `other` - BigIntValue divisor
  ///
  /// #### Returns
  /// `BigIntValue` - Remainder
  ///
  /// #### Example
  /// ```dart
  /// final a = BigIntValue(BigInt.from(10));
  /// final b = BigIntValue(BigInt.from(3));
  /// final remainder = a % b; // BigIntValue(1)
  /// ```
  BigIntValue operator %(BigIntValue other) => BigIntValue(value % other.value);

  /// Negates the BigIntValue.
  ///
  /// #### Returns
  /// `BigIntValue` - Negated value
  ///
  /// #### Example
  /// ```dart
  /// final a = BigIntValue(BigInt.from(42));
  /// final negated = -a; // BigIntValue(-42)
  /// ```
  BigIntValue operator -() => BigIntValue(-value);

  /// Tests if this value is less than another.
  ///
  /// #### Parameters
  /// - `other` - BigIntValue to compare
  ///
  /// #### Returns
  /// `bool` - True if this < other
  ///
  /// #### Example
  /// ```dart
  /// final a = BigIntValue(BigInt.from(10));
  /// final b = BigIntValue(BigInt.from(20));
  /// print(a < b); // true
  /// ```
  bool operator <(BigIntValue other) => value < other.value;

  /// Tests if this value is less than or equal to another.
  ///
  /// #### Parameters
  /// - `other` - BigIntValue to compare
  ///
  /// #### Returns
  /// `bool` - True if this <= other
  bool operator <=(BigIntValue other) => value <= other.value;

  /// Tests if this value is greater than another.
  ///
  /// #### Parameters
  /// - `other` - BigIntValue to compare
  ///
  /// #### Returns
  /// `bool` - True if this > other
  bool operator >(BigIntValue other) => value > other.value;

  /// Tests if this value is greater than or equal to another.
  ///
  /// #### Parameters
  /// - `other` - BigIntValue to compare
  ///
  /// #### Returns
  /// `bool` - True if this >= other
  bool operator >=(BigIntValue other) => value >= other.value;

  /// Bitwise AND of two BigIntValues.
  ///
  /// #### Parameters
  /// - `other` - BigIntValue for AND operation
  ///
  /// #### Returns
  /// `BigIntValue` - Result of bitwise AND
  ///
  /// #### Example
  /// ```dart
  /// final a = BigIntValue(BigInt.from(12)); // 1100
  /// final b = BigIntValue(BigInt.from(10)); // 1010
  /// final result = a & b; // BigIntValue(8) = 1000
  /// ```
  BigIntValue operator &(BigIntValue other) => BigIntValue(value & other.value);

  /// Bitwise OR of two BigIntValues.
  ///
  /// #### Parameters
  /// - `other` - BigIntValue for OR operation
  ///
  /// #### Returns
  /// `BigIntValue` - Result of bitwise OR
  ///
  /// #### Example
  /// ```dart
  /// final a = BigIntValue(BigInt.from(12)); // 1100
  /// final b = BigIntValue(BigInt.from(10)); // 1010
  /// final result = a | b; // BigIntValue(14) = 1110
  /// ```
  BigIntValue operator |(BigIntValue other) => BigIntValue(value | other.value);

  /// Bitwise XOR of two BigIntValues.
  ///
  /// #### Parameters
  /// - `other` - BigIntValue for XOR operation
  ///
  /// #### Returns
  /// `BigIntValue` - Result of bitwise XOR
  ///
  /// #### Example
  /// ```dart
  /// final a = BigIntValue(BigInt.from(12)); // 1100
  /// final b = BigIntValue(BigInt.from(10)); // 1010
  /// final result = a ^ b; // BigIntValue(6) = 0110
  /// ```
  BigIntValue operator ^(BigIntValue other) => BigIntValue(value ^ other.value);

  /// Bitwise NOT (complement) of BigIntValue.
  ///
  /// #### Returns
  /// `BigIntValue` - Result of bitwise NOT
  ///
  /// #### Example
  /// ```dart
  /// final a = BigIntValue(BigInt.from(5)); // 0101
  /// final result = ~a; // BigIntValue(-6) (two's complement)
  /// ```
  BigIntValue operator ~() => BigIntValue(~value);

  /// Left shift operation.
  ///
  /// #### Parameters
  /// - `shift` - Number of bits to shift left
  ///
  /// #### Returns
  /// `BigIntValue` - Result of left shift
  ///
  /// #### Example
  /// ```dart
  /// final a = BigIntValue(BigInt.from(5)); // 0101
  /// final result = a << 2; // BigIntValue(20) = 10100
  /// ```
  BigIntValue operator <<(int shift) => BigIntValue(value << shift);

  /// Right shift operation.
  ///
  /// #### Parameters
  /// - `shift` - Number of bits to shift right
  ///
  /// #### Returns
  /// `BigIntValue` - Result of right shift
  ///
  /// #### Example
  /// ```dart
  /// final a = BigIntValue(BigInt.from(20)); // 10100
  /// final result = a >> 2; // BigIntValue(5) = 0101
  /// ```
  BigIntValue operator >>(int shift) => BigIntValue(value >> shift);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BigIntValue && value == other.value;

  @override
  int get hashCode => value.hashCode;
}
