import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'numerical.dart';

/// 8-bit signed integer type (-128 to 127).
///
/// Represents signed 8-bit integers for smart contracts.
/// Range: -128 to 127, encoded as single byte with two's complement.
///
/// #### Example
/// ```dart
/// final positive = I8Type.create(100);
/// final negative = I8Type.create(-50);
/// final zero = I8Type.create(0);
///
/// print(positive.nativeValue); // 100
/// print(negative.toBytes()); // [206] (two's complement)
/// print(zero.toBytes()); // [0]
///
/// // Use in struct definitions
/// final structType = StructType(fields: [
///   StructField('offset', I8Type.type),
/// ]);
/// ```
@immutable
final class I8Type extends NumericalType {
  I8Type._() : super(name: 'i8', sizeInBytes: 1, isSigned: true);

  static final I8Type _instance = I8Type._();

  @override
  String get className => 'I8Type';

  static const List<String> _classHierarchy = [
    'I8Type',
    'NumericalType',
    'PrimitiveType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  /// Creates an I8Value from native Dart int.
  ///
  /// #### Parameters
  /// - `nativeValue` - Integer value between -128 and 127
  ///
  /// #### Returns
  /// `I8Value` - Instance with the signed 8-bit integer
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is not int or outside range
  ///
  /// #### Example
  /// ```dart
  /// final value1 = I8Type.create(42);
  /// final value2 = I8Type.create(-100);
  ///
  /// // These throw: outside valid range
  /// // final invalid1 = I8Type.create(128);
  /// // final invalid2 = I8Type.create(-129);
  /// ```
  static I8Value create(dynamic nativeValue) {
    if (nativeValue is! int) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'I8Type requires int value',
      );
    }
    if (nativeValue < i8Min || nativeValue > i8Max) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'I8Type value must be in range -128 to 127',
      );
    }
    return I8Value(nativeValue);
  }

  /// Gets the singleton type instance for use in type definitions.
  static I8Type get type => _instance;

  @override
  I8Value createValue(dynamic nativeValue) => create(nativeValue);
}

/// 8-bit signed integer value.
///
/// Holds a signed 8-bit integer with full arithmetic and bitwise operations.
/// Provides efficient encoding using precomputed byte arrays.
///
/// #### Example
/// ```dart
/// final value1 = I8Value(42);
/// final value2 = I8Value(-100);
/// final zero = I8Value(0);
///
/// // Arithmetic operations
/// final sum = value1 + I8Value(8); // 50
/// final diff = value1 - I8Value(10); // 32
/// final neg = -value1; // -42
///
/// // Comparisons
/// print(value1 > zero); // true
/// print(value2.nativeValue.isNegative); // true
///
/// // Binary encoding (two's complement)
/// print(value1.toBytes()); // [42]
/// print(value2.toBytes()); // [156] (two's complement of -100)
/// ```
@immutable
final class I8Value extends IntNumericalValue {
  /// Creates an I8 value.
  ///
  /// #### Parameters
  /// - `value` - Integer between -128 and 127
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is outside valid range
  I8Value(this.value) : super(I8Type._instance) {
    if (value < i8Min || value > i8Max) {
      throw ArgumentError.value(value, 'value', 'Must be in range -128 to 127');
    }
  }

  @override
  final int value;

  @override
  int get minValue => i8Min;

  @override
  int get maxValue => i8Max;

  @override
  int get bitMask => 0xFF;

  @override
  String get typeName => 'I8';

  @override
  I8Value createInstance(int value) => I8Value(value);

  @override
  String get className => 'I8Value';

  static const List<String> _classHierarchy = [
    'I8Value',
    'IntNumericalValue',
    'NumericalValue',
    'TypedValue',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() => Uint8List(1)..[0] = value & 0xFF;

  I8Value operator +(I8Value other) => addChecked(other) as I8Value;
  I8Value operator -(I8Value other) => subtractChecked(other) as I8Value;
  I8Value operator *(I8Value other) => multiplyChecked(other) as I8Value;
  I8Value operator ~/(I8Value other) => divideInt(other) as I8Value;
  I8Value operator %(I8Value other) => modulo(other) as I8Value;
  I8Value operator -() => negateChecked() as I8Value;

  bool operator <(I8Value other) => lessThan(other);
  bool operator <=(I8Value other) => lessThanOrEqual(other);
  bool operator >(I8Value other) => greaterThan(other);
  bool operator >=(I8Value other) => greaterThanOrEqual(other);

  I8Value operator &(I8Value other) => createInstance(value & other.value);
  I8Value operator |(I8Value other) => createInstance(value | other.value);
  I8Value operator ^(I8Value other) => createInstance(value ^ other.value);
  I8Value operator ~() => createInstance(~value);
  I8Value operator <<(int shift) => createInstance(value << shift);
  I8Value operator >>(int shift) => createInstance(value >> shift);
}
