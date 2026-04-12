import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'numerical.dart';

/// 32-bit signed integer type (-2,147,483,648 to 2,147,483,647).
///
/// Represents signed 32-bit integers for smart contracts.
/// Range: -2,147,483,648 to 2,147,483,647, encoded as 4 bytes with two's complement.
///
/// #### Example
/// ```dart
/// final positive = I32Type.create(1000000);
/// final negative = I32Type.create(-500000);
/// final zero = I32Type.create(0);
/// final max = I32Type.create(2147483647);
///
/// print(positive.nativeValue); // 1000000
/// print(negative.toBytes()); // [255, 248, 113, 192] (two's complement)
/// print(max.toBytes()); // [127, 255, 255, 255]
///
/// // Use in struct definitions
/// final structType = StructType(fields: [
///   StructField('balance', I32Type.type),
/// ]);
/// ```
@immutable
final class I32Type extends NumericalType {
  I32Type._() : super(name: 'i32', sizeInBytes: 4, isSigned: true);

  static final I32Type _instance = I32Type._();

  @override
  String get className => 'I32Type';

  static const List<String> _classHierarchy = [
    'I32Type',
    'NumericalType',
    'PrimitiveType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  /// Creates an I32Value from native Dart int.
  ///
  /// #### Parameters
  /// - `nativeValue` - Integer value between -2,147,483,648 and 2,147,483,647
  ///
  /// #### Returns
  /// `I32Value` - Instance with the signed 32-bit integer
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is not int or outside range
  ///
  /// #### Example
  /// ```dart
  /// final value1 = I32Type.create(1000000);
  /// final value2 = I32Type.create(-2000000);
  ///
  /// // These throw: outside valid range (on 32-bit systems)
  /// // final invalid1 = I32Type.create(2147483648);
  /// // final invalid2 = I32Type.create(-2147483649);
  /// ```
  static I32Value create(dynamic nativeValue) {
    if (nativeValue is! int) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'I32Type requires int value',
      );
    }
    if (nativeValue < i32Min || nativeValue > i32Max) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'I32Type value out of range',
      );
    }
    return I32Value(nativeValue);
  }

  /// Gets the singleton type instance for use in type definitions.
  static I32Type get type => _instance;

  @override
  I32Value createValue(dynamic nativeValue) => create(nativeValue);
}

/// 32-bit signed integer value.
///
/// Holds a signed 32-bit integer with full arithmetic and bitwise operations.
/// Uses optimized encoding for small values with precomputed byte arrays.
///
/// #### Example
/// ```dart
/// final value1 = I32Value(1000000);
/// final value2 = I32Value(-500000);
/// final zero = I32Value(0);
///
/// // Arithmetic operations
/// final sum = value1 + I32Value(500000); // 1500000
/// final diff = value1 - I32Value(200000); // 800000
/// final neg = -value1; // -1000000
///
/// // Comparisons
/// print(value1 > zero); // true
/// print(value2.nativeValue.isNegative); // true
///
/// // Binary encoding (big-endian two's complement)
/// print(value1.toBytes()); // [0, 15, 66, 64] (1000000 as 32-bit)
/// print(zero.toBytes()); // [0, 0, 0, 0]
/// ```
@immutable
final class I32Value extends IntNumericalValue {
  /// Creates an I32 value.
  ///
  /// #### Parameters
  /// - `value` - Integer between -2,147,483,648 and 2,147,483,647
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is outside valid range
  I32Value(this.value) : super(I32Type._instance) {
    if (value < i32Min || value > i32Max) {
      throw ArgumentError.value(value, 'value', 'I32Type value out of range');
    }
  }

  @override
  final int value;

  @override
  int get minValue => i32Min;

  @override
  int get maxValue => i32Max;

  @override
  int get bitMask => 0xFFFFFFFF;

  @override
  String get typeName => 'I32';

  @override
  I32Value createInstance(int value) => I32Value(value);

  @override
  String get className => 'I32Value';

  static const List<String> _classHierarchy = [
    'I32Value',
    'IntNumericalValue',
    'NumericalValue',
    'TypedValue',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  static final List<Uint8List> _precomputed = List.generate(256, (i) {
    final int val = i - 128;
    final int unsigned = val & 0xFFFFFFFF;
    return Uint8List(4)
      ..[0] = (unsigned >> 24) & 0xFF
      ..[1] = (unsigned >> 16) & 0xFF
      ..[2] = (unsigned >> 8) & 0xFF
      ..[3] = unsigned & 0xFF;
  }, growable: false);

  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() {
    if (value >= -128 && value <= 127) return _precomputed[value + 128];

    final int unsigned = value & 0xFFFFFFFF;
    return Uint8List(4)
      ..[0] = (unsigned >> 24) & 0xFF
      ..[1] = (unsigned >> 16) & 0xFF
      ..[2] = (unsigned >> 8) & 0xFF
      ..[3] = unsigned & 0xFF;
  }

  I32Value operator +(I32Value other) => addChecked(other) as I32Value;
  I32Value operator -(I32Value other) => subtractChecked(other) as I32Value;
  I32Value operator *(I32Value other) => multiplyChecked(other) as I32Value;
  I32Value operator ~/(I32Value other) => divideInt(other) as I32Value;
  I32Value operator %(I32Value other) => modulo(other) as I32Value;
  I32Value operator -() => negateChecked() as I32Value;

  bool operator <(I32Value other) => lessThan(other);
  bool operator <=(I32Value other) => lessThanOrEqual(other);
  bool operator >(I32Value other) => greaterThan(other);
  bool operator >=(I32Value other) => greaterThanOrEqual(other);

  I32Value operator &(I32Value other) => createInstance(value & other.value);
  I32Value operator |(I32Value other) => createInstance(value | other.value);
  I32Value operator ^(I32Value other) => createInstance(value ^ other.value);
  I32Value operator ~() => createInstance(~value);
  I32Value operator <<(int shift) => createInstance(value << shift);
  I32Value operator >>(int shift) => createInstance(value >> shift);
}
