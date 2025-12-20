import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'numerical.dart';

/// 16-bit unsigned integer type (0 to 65,535).
///
/// Represents unsigned 16-bit integers for smart contracts.
/// Range: 0 to 65,535, encoded as 2 bytes with big-endian format.
///
/// #### Example
/// ```dart
/// final small = U16Type.create(1000);
/// final large = U16Type.create(50000);
/// final max = U16Type.create(65535); // Max value
/// final zero = U16Type.create(0);
///
/// print(small.nativeValue); // 1000
/// print(large.toBytes()); // [195, 80] (big-endian)
/// print(max.toBytes()); // [255, 255]
///
/// // Use in struct definitions
/// final structType = StructType(fields: [
///   StructField('port', U16Type.type),
/// ]);
/// ```
@immutable
final class U16Type extends NumericalType {
  U16Type._() : super(name: 'u16', sizeInBytes: 2, isSigned: false);

  static final U16Type _instance = U16Type._();

  @override
  String get className => 'U16Type';

  static const List<String> _classHierarchy = [
    'U16Type',
    'NumericalType',
    'PrimitiveType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  /// Creates a U16Value from native Dart int.
  ///
  /// #### Parameters
  /// - `nativeValue` - Integer value between 0 and 65,535
  ///
  /// #### Returns
  /// `U16Value` - Instance with the unsigned 16-bit integer
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is not int or outside range
  ///
  /// #### Example
  /// ```dart
  /// final value1 = U16Type.create(1000);
  /// final value2 = U16Type.create(65535); // Max
  ///
  /// // These throw: outside valid range
  /// // final invalid1 = U16Type.create(65536);
  /// // final invalid2 = U16Type.create(-1);
  /// ```
  static U16Value create(dynamic nativeValue) {
    if (nativeValue is! int) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'U16Type requires int value',
      );
    }
    if (nativeValue < 0 || nativeValue > u16Max) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'U16Type value must be in range 0-65535',
      );
    }
    return U16Value(nativeValue);
  }

  /// Gets the singleton type instance for use in type definitions.
  static U16Type get type => _instance;

  @override
  U16Value createValue(dynamic nativeValue) => create(nativeValue);
}

/// 16-bit unsigned integer value.
///
/// Holds an unsigned 16-bit integer with arithmetic and bitwise operations.
/// Uses optimized encoding for small values with precomputed byte arrays.
///
/// #### Example
/// ```dart
/// final value1 = U16Value(1000);
/// final value2 = U16Value(50000);
/// final zero = U16Value(0);
///
/// // Arithmetic operations (with overflow checking)
/// final sum = value1 + U16Value(500); // U16Value(1500)
/// final diff = value2 - U16Value(10000); // U16Value(40000)
/// final bitwise = value1 & U16Value(255); // U16Value(232) (1000 & 255)
///
/// // Comparisons
/// print(value1 > zero); // true
/// print(value2.nativeValue); // 50000
///
/// // Binary encoding (big-endian 2 bytes)
/// print(value1.toBytes()); // [3, 232] (1000 as 16-bit)
/// print(zero.toBytes()); // [0, 0]
/// ```
@immutable
final class U16Value extends IntNumericalValue {
  /// Creates a U16 value.
  ///
  /// #### Parameters
  /// - `value` - Integer between 0 and 65,535
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is outside valid range
  U16Value(this.value) : super(U16Type._instance) {
    if (value < 0 || value > u16Max) {
      throw ArgumentError.value(value, 'value', 'Must be in range 0-65535');
    }
  }

  @override
  final int value;

  @override
  int get minValue => 0;

  @override
  int get maxValue => u16Max;

  @override
  int get bitMask => 0xFFFF;

  @override
  String get typeName => 'U16';

  @override
  U16Value createInstance(int value) => U16Value(value);

  @override
  String get className => 'U16Value';

  static const List<String> _classHierarchy = [
    'U16Value',
    'IntNumericalValue',
    'NumericalValue',
    'TypedValue',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  static final List<Uint8List> _precomputed = List.generate(
    256,
    (i) => Uint8List(2)
      ..[0] = (i >> 8) & 0xFF
      ..[1] = i & 0xFF,
    growable: false,
  );

  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() {
    if (value <= 255) return _precomputed[value];

    return Uint8List(2)
      ..[0] = (value >> 8) & 0xFF
      ..[1] = value & 0xFF;
  }

  U16Value operator +(U16Value other) => addChecked(other) as U16Value;
  U16Value operator -(U16Value other) => subtractChecked(other) as U16Value;
  U16Value operator *(U16Value other) => multiplyChecked(other) as U16Value;
  U16Value operator ~/(U16Value other) => divideInt(other) as U16Value;
  U16Value operator %(U16Value other) => modulo(other) as U16Value;

  bool operator <(U16Value other) => lessThan(other);
  bool operator <=(U16Value other) => lessThanOrEqual(other);
  bool operator >(U16Value other) => greaterThan(other);
  bool operator >=(U16Value other) => greaterThanOrEqual(other);

  U16Value operator &(U16Value other) => bitwiseAnd(other) as U16Value;
  U16Value operator |(U16Value other) => bitwiseOr(other) as U16Value;
  U16Value operator ^(U16Value other) => bitwiseXor(other) as U16Value;
  U16Value operator ~() => bitwiseNot() as U16Value;
  U16Value operator <<(int shift) => shiftLeft(shift) as U16Value;
  U16Value operator >>(int shift) => shiftRight(shift) as U16Value;
}
