import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../utils/helpers.dart';
import 'numerical.dart';

/// 64-bit signed integer type.
///
/// Represents signed 64-bit integers for smart contracts.
/// Range: -9,223,372,036,854,775,808 to 9,223,372,036,854,775,807, encoded as 8 bytes.
///
/// #### Example
/// ```dart
/// final positive = I64Type.create(1000000000000);
/// final negative = I64Type.create(BigInt.parse('-5000000000000'));
/// final fromInt = I64Type.create(42);
/// final max = I64Type.create(BigInt.parse('9223372036854775807'));
///
/// print(positive.nativeValue); // 1000000000000
/// print(fromInt.toBytes()); // [0, 0, 0, 0, 0, 0, 0, 42]
/// print(max.toBytes().length); // 8 bytes
///
/// // Use in struct definitions
/// final structType = StructType(fields: [
///   StructField('timestamp', I64Type.type),
/// ]);
/// ```
@immutable
final class I64Type extends NumericalType {
  I64Type._() : super(name: 'i64', sizeInBytes: 8, isSigned: true);

  static final I64Type _instance = I64Type._();

  @override
  String get className => 'I64Type';

  static const List<String> _classHierarchy = [
    'I64Type',
    'NumericalType',
    'PrimitiveType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  /// Creates an I64Value from native Dart int or BigInt.
  ///
  /// #### Parameters
  /// - `nativeValue` - `int` or `BigInt` value within 64-bit signed range
  ///
  /// #### Returns
  /// `I64Value` - Instance with the signed 64-bit integer
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is outside 64-bit signed range
  ///
  /// #### Example
  /// ```dart
  /// // From int (small values)
  /// final value1 = I64Type.create(1000000);
  ///
  /// // From BigInt (large values)
  /// final value2 = I64Type.create(BigInt.parse('9000000000000000000'));
  ///
  /// // Negative values
  /// final value3 = I64Type.create(BigInt.parse('-5000000000000'));
  /// ```
  static I64Value create(dynamic nativeValue) {
    final BigInt bigInt = nativeValue is BigInt
        ? nativeValue
        : BigInt.from(requireAs<int>(nativeValue, 'nativeValue'));

    if (bigInt < i64Min || bigInt > i64Max) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'I64Type value out of range',
      );
    }
    return I64Value(bigInt);
  }

  /// Gets the singleton type instance for use in type definitions.
  static I64Type get type => _instance;

  @override
  I64Value createValue(dynamic nativeValue) => create(nativeValue);
}

/// 64-bit signed integer value.
///
/// Holds a signed 64-bit integer as BigInt with full arithmetic and bitwise operations.
/// Uses optimized encoding for small values with precomputed byte arrays.
///
/// #### Example
/// ```dart
/// final value1 = I64Value(BigInt.from(1000000000000));
/// final value2 = I64Value(BigInt.parse('-5000000000000'));
/// final small = I64Value(BigInt.from(42));
///
/// // Arithmetic operations
/// final sum = value1 + I64Value(BigInt.from(1000000000000)); // 2000000000000
/// final diff = value1 - I64Value(BigInt.from(500000000000)); // 500000000000
/// final neg = -value1; // -1000000000000
///
/// // Comparisons
/// print(value1 > I64Value(BigInt.zero)); // true
/// print(value2.nativeValue.isNegative); // true
///
/// // Binary encoding (big-endian two's complement)
/// print(small.toBytes()); // [0, 0, 0, 0, 0, 0, 0, 42]
/// print(value1.toBytes().length); // 8 bytes
/// ```
@immutable
final class I64Value extends BigIntNumericalValue {
  /// Creates an I64 value.
  ///
  /// #### Parameters
  /// - `value` - BigInt within 64-bit signed range
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is outside valid range
  I64Value(this.value) : super(I64Type._instance) {
    if (value < i64Min || value > i64Max) {
      throw ArgumentError.value(value, 'value', 'I64Type value out of range');
    }
  }

  @override
  final BigInt value;

  @override
  BigInt get minValue => i64Min;

  @override
  BigInt get maxValue => i64Max;

  static final BigInt _bitMask = (BigInt.one << 64) - BigInt.one;

  @override
  BigInt get bitMask => _bitMask;

  @override
  String get typeName => 'I64';

  @override
  I64Value createInstance(BigInt value) => I64Value(value);

  @override
  String get className => 'I64Value';

  static const List<String> _classHierarchy = [
    'I64Value',
    'BigIntNumericalValue',
    'NumericalValue',
    'TypedValue',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() {
    final BigInt mask = (BigInt.one << 64) - BigInt.one;
    final BigInt unsigned = value & mask;
    return Uint8List(8)
      ..[0] = ((unsigned >> 56) & BigInt.from(0xFF)).toInt()
      ..[1] = ((unsigned >> 48) & BigInt.from(0xFF)).toInt()
      ..[2] = ((unsigned >> 40) & BigInt.from(0xFF)).toInt()
      ..[3] = ((unsigned >> 32) & BigInt.from(0xFF)).toInt()
      ..[4] = ((unsigned >> 24) & BigInt.from(0xFF)).toInt()
      ..[5] = ((unsigned >> 16) & BigInt.from(0xFF)).toInt()
      ..[6] = ((unsigned >> 8) & BigInt.from(0xFF)).toInt()
      ..[7] = (unsigned & BigInt.from(0xFF)).toInt();
  }

  I64Value operator +(I64Value other) => addChecked(other) as I64Value;
  I64Value operator -(I64Value other) => subtractChecked(other) as I64Value;
  I64Value operator *(I64Value other) => multiplyChecked(other) as I64Value;
  I64Value operator ~/(I64Value other) => divideInt(other) as I64Value;
  I64Value operator %(I64Value other) => modulo(other) as I64Value;
  I64Value operator -() => negateChecked() as I64Value;

  bool operator <(I64Value other) => lessThan(other);
  bool operator <=(I64Value other) => lessThanOrEqual(other);
  bool operator >(I64Value other) => greaterThan(other);
  bool operator >=(I64Value other) => greaterThanOrEqual(other);

  I64Value operator &(I64Value other) => I64Value(value & other.value);
  I64Value operator |(I64Value other) => I64Value(value | other.value);
  I64Value operator ^(I64Value other) => I64Value(value ^ other.value);
  I64Value operator ~() => I64Value(~value);
  I64Value operator <<(int shift) => I64Value(value << shift);
  I64Value operator >>(int shift) => I64Value(value >> shift);
}
