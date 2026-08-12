import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'numerical.dart';

/// 16-bit signed integer type (-32,768 to 32,767).
///
/// Represents signed 16-bit integers for smart contracts.
/// Range: -32,768 to 32,767, encoded as 2 bytes with two's complement.
///
/// #### Example
/// ```dart
/// final positive = I16Type.create(1000);
/// final negative = I16Type.create(-2500);
/// final zero = I16Type.create(0);
/// final max = I16Type.create(32767);
///
/// print(positive.nativeValue); // 1000
/// print(negative.toBytes()); // [246, 60] (two's complement)
/// print(max.toBytes()); // [127, 255]
///
/// // Use in struct definitions
/// final structType = StructType(
///   name: 'SensorReading',
///   fieldDefinitions: [
///     FieldDefinition(name: 'temperature', type: I16Type.type),
///   ],
/// );
/// ```
@immutable
final class I16Type extends NumericalType {
  I16Type._() : super(name: 'i16', sizeInBytes: 2, isSigned: true);

  static final I16Type _instance = I16Type._();

  @override
  String get className => 'I16Type';

  static const List<String> _classHierarchy = [
    'I16Type',
    'NumericalType',
    'PrimitiveType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  /// Creates an I16Value from native Dart int.
  ///
  /// #### Parameters
  /// - `nativeValue` - Integer value between -32,768 and 32,767
  ///
  /// #### Returns
  /// `I16Value` - Instance with the signed 16-bit integer
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is not int or outside range
  ///
  /// #### Example
  /// ```dart
  /// final value1 = I16Type.create(1000);
  /// final value2 = I16Type.create(-15000);
  ///
  /// // These throw: outside valid range
  /// // final invalid1 = I16Type.create(32768);
  /// // final invalid2 = I16Type.create(-32769);
  /// ```
  static I16Value create(dynamic nativeValue) {
    if (nativeValue is! int) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'I16Type requires int value',
      );
    }
    if (nativeValue < i16Min || nativeValue > i16Max) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'I16Type value must be in range -32768 to 32767',
      );
    }
    return I16Value(nativeValue);
  }

  /// Gets the singleton type instance for use in type definitions.
  static I16Type get type => _instance;

  @override
  I16Value createValue(dynamic nativeValue) => create(nativeValue);
}

/// 16-bit signed integer value.
///
/// Holds a signed 16-bit integer with full arithmetic and bitwise operations.
/// Uses optimized encoding for common values with precomputed byte arrays.
///
/// #### Example
/// ```dart
/// final value1 = I16Value(1000);
/// final value2 = I16Value(-2500);
/// final zero = I16Value(0);
///
/// // Arithmetic operations
/// final sum = value1 + I16Value(500); // 1500
/// final diff = value1 - I16Value(200); // 800
/// final neg = -value1; // -1000
///
/// // Comparisons
/// print(value1 > zero); // true
/// print(value2.nativeValue.isNegative); // true
///
/// // Binary encoding (big-endian two's complement)
/// print(value1.toBytes()); // [3, 232] (1000 as 16-bit)
/// print(zero.toBytes()); // [0, 0]
/// ```
@immutable
final class I16Value extends IntNumericalValue {
  /// Creates an I16 value.
  ///
  /// #### Parameters
  /// - `value` - Integer between -32,768 and 32,767
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is outside valid range
  I16Value(this.value) : super(I16Type._instance) {
    if (value < i16Min || value > i16Max) {
      throw ArgumentError.value(
        value,
        'value',
        'Must be in range -32768 to 32767',
      );
    }
  }

  @override
  final int value;

  @override
  int get minValue => i16Min;

  @override
  int get maxValue => i16Max;

  @override
  int get bitMask => 0xFFFF;

  @override
  String get typeName => 'I16';

  @override
  I16Value createInstance(int value) => I16Value(value);

  @override
  String get className => 'I16Value';

  static const List<String> _classHierarchy = [
    'I16Value',
    'IntNumericalValue',
    'NumericalValue',
    'TypedValue',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() {
    final int unsigned = value & 0xFFFF;
    return Uint8List(2)
      ..[0] = (unsigned >> 8) & 0xFF
      ..[1] = unsigned & 0xFF;
  }

  I16Value operator +(I16Value other) => addChecked(other) as I16Value;
  I16Value operator -(I16Value other) => subtractChecked(other) as I16Value;
  I16Value operator *(I16Value other) => multiplyChecked(other) as I16Value;
  I16Value operator ~/(I16Value other) => divideInt(other) as I16Value;
  I16Value operator %(I16Value other) => modulo(other) as I16Value;
  I16Value operator -() => negateChecked() as I16Value;

  bool operator <(I16Value other) => lessThan(other);
  bool operator <=(I16Value other) => lessThanOrEqual(other);
  bool operator >(I16Value other) => greaterThan(other);
  bool operator >=(I16Value other) => greaterThanOrEqual(other);

  I16Value operator &(I16Value other) => createInstance(value & other.value);
  I16Value operator |(I16Value other) => createInstance(value | other.value);
  I16Value operator ^(I16Value other) => createInstance(value ^ other.value);
  I16Value operator ~() => createInstance(~value);
  I16Value operator <<(int shift) => createInstance(value << shift);
  I16Value operator >>(int shift) => createInstance(value >> shift);
}
