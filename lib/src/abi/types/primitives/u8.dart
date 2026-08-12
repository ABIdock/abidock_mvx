import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'numerical.dart';

/// 8-bit unsigned integer type (0 to 255).
///
/// Represents unsigned 8-bit integers for smart contracts.
/// Range: 0 to 255, encoded as single byte with no sign bit.
///
/// #### Example
/// ```dart
/// final byte1 = U8Type.create(100);
/// final byte2 = U8Type.create(255); // Max value
/// final zero = U8Type.create(0);
///
/// print(byte1.nativeValue); // 100
/// print(byte2.toBytes()); // [255]
/// print(zero.toBytes()); // [0]
///
/// // Use in struct definitions
/// final structType = StructType(
///   name: 'Counter',
///   fieldDefinitions: [
///     FieldDefinition(name: 'count', type: U8Type.type),
///   ],
/// );
/// ```
@immutable
final class U8Type extends NumericalType {
  U8Type._() : super(name: 'u8', sizeInBytes: 1, isSigned: false);

  static final U8Type _instance = U8Type._();

  @override
  String get className => 'U8Type';

  static const List<String> _classHierarchy = [
    'U8Type',
    'NumericalType',
    'PrimitiveType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  /// Creates a U8Value from native Dart int.
  ///
  /// #### Parameters
  /// - `nativeValue` - Integer value between 0 and 255
  ///
  /// #### Returns
  /// `U8Value` - Instance with the unsigned 8-bit integer
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is not int or outside range
  ///
  /// #### Example
  /// ```dart
  /// final value1 = U8Type.create(42);
  /// final value2 = U8Type.create(255); // Max
  ///
  /// // These throw: outside valid range
  /// // final invalid1 = U8Type.create(256);
  /// // final invalid2 = U8Type.create(-1);
  /// ```
  static U8Value create(dynamic nativeValue) {
    if (nativeValue is! int) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'U8Type requires int value',
      );
    }
    if (nativeValue < 0 || nativeValue > u8Max) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'U8Type value must be in range 0-255',
      );
    }
    return U8Value(nativeValue);
  }

  /// Gets the singleton type instance for use in type definitions.
  static U8Type get type => _instance;

  @override
  U8Value createValue(dynamic nativeValue) => create(nativeValue);
}

/// 8-bit unsigned integer value.
///
/// Holds an unsigned 8-bit integer with arithmetic and bitwise operations.
/// Uses precomputed byte arrays for optimal encoding performance.
///
/// #### Example
/// ```dart
/// final value1 = U8Value(100);
/// final value2 = U8Value(200);
/// final zero = U8Value(0);
///
/// // Arithmetic operations (with overflow checking)
/// final sum = value1 + U8Value(50); // U8Value(150)
/// final diff = value1 - U8Value(50); // U8Value(50)
/// final bitwise = value1 & U8Value(15); // U8Value(4) (100 & 15)
///
/// // Comparisons
/// print(value1 > zero); // true
/// print(value2.nativeValue); // 200
///
/// // Binary encoding (single byte)
/// print(value1.toBytes()); // [100]
/// print(value2.toBytes()); // [200]
/// ```
@immutable
final class U8Value extends IntNumericalValue {
  /// Creates a U8 value.
  ///
  /// #### Parameters
  /// - `value` - Integer between 0 and 255
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is outside valid range
  U8Value(this.value) : super(U8Type._instance) {
    if (value < 0 || value > u8Max) {
      throw ArgumentError.value(value, 'value', 'Must be in range 0-255');
    }
  }

  @override
  final int value;

  @override
  int get minValue => 0;

  @override
  int get maxValue => u8Max;

  @override
  int get bitMask => 0xFF;

  @override
  String get typeName => 'U8';

  @override
  U8Value createInstance(int value) => U8Value(value);

  @override
  String get className => 'U8Value';

  static const List<String> _classHierarchy = [
    'U8Value',
    'IntNumericalValue',
    'NumericalValue',
    'TypedValue',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() => Uint8List(1)..[0] = value;

  U8Value operator +(U8Value other) => addChecked(other) as U8Value;
  U8Value operator -(U8Value other) => subtractChecked(other) as U8Value;
  U8Value operator *(U8Value other) => multiplyChecked(other) as U8Value;
  U8Value operator ~/(U8Value other) => divideInt(other) as U8Value;
  U8Value operator %(U8Value other) => modulo(other) as U8Value;

  bool operator <(U8Value other) => lessThan(other);
  bool operator <=(U8Value other) => lessThanOrEqual(other);
  bool operator >(U8Value other) => greaterThan(other);
  bool operator >=(U8Value other) => greaterThanOrEqual(other);

  U8Value operator &(U8Value other) => bitwiseAnd(other) as U8Value;
  U8Value operator |(U8Value other) => bitwiseOr(other) as U8Value;
  U8Value operator ^(U8Value other) => bitwiseXor(other) as U8Value;
  U8Value operator ~() => bitwiseNot() as U8Value;
  U8Value operator <<(int shift) => shiftLeft(shift) as U8Value;
  U8Value operator >>(int shift) => shiftRight(shift) as U8Value;
}
