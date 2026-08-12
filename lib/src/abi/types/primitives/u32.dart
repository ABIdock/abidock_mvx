import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'numerical.dart';

/// 32-bit unsigned integer type (0 to 4,294,967,295).
///
/// Represents unsigned 32-bit integers for smart contracts.
/// Most commonly used integer type. Range: 0 to 4,294,967,295, encoded as 4 bytes.
///
/// #### Example
/// ```dart
/// final small = U32Type.create(1000);
/// final large = U32Type.create(1000000000);
/// final max = U32Type.create(4294967295); // Max value
/// final zero = U32Type.create(0);
///
/// print(small.nativeValue); // 1000
/// print(large.toBytes()); // [59, 154, 202, 0] (big-endian)
/// print(max.toBytes()); // [255, 255, 255, 255]
///
/// // Use in struct definitions
/// final structType = StructType(
///   name: 'Identifier',
///   fieldDefinitions: [
///     FieldDefinition(name: 'id', type: U32Type.type),
///   ],
/// );
/// ```
@immutable
final class U32Type extends NumericalType {
  U32Type._() : super(name: 'u32', sizeInBytes: 4, isSigned: false);

  static final U32Type _instance = U32Type._();

  @override
  String get className => 'U32Type';

  static const List<String> _classHierarchy = [
    'U32Type',
    'NumericalType',
    'PrimitiveType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  /// Creates a U32Value from native Dart int.
  ///
  /// #### Parameters
  /// - `nativeValue` - Integer value between 0 and 4,294,967,295
  ///
  /// #### Returns
  /// `U32Value` - Instance with the unsigned 32-bit integer
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is not int or outside range
  ///
  /// #### Example
  /// ```dart
  /// final value1 = U32Type.create(1000000);
  /// final value2 = U32Type.create(4294967295); // Max
  ///
  /// // These throw: outside valid range (on some platforms)
  /// // final invalid1 = U32Type.create(4294967296);
  /// // final invalid2 = U32Type.create(-1);
  /// ```
  static U32Value create(dynamic nativeValue) {
    if (nativeValue is! int) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'U32Type requires int value',
      );
    }
    if (nativeValue < 0 || nativeValue > u32Max) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'U32Type value must be in range 0-4294967295',
      );
    }
    return U32Value(nativeValue);
  }

  /// Gets the singleton type instance for use in type definitions.
  static U32Type get type => _instance;

  @override
  U32Value createValue(dynamic nativeValue) => create(nativeValue);
}

/// 32-bit unsigned integer value.
@immutable
final class U32Value extends IntNumericalValue {
  /// Creates a U32 value.
  U32Value(this.value) : super(U32Type._instance) {
    if (value < 0 || value > u32Max) {
      throw ArgumentError.value(
        value,
        'value',
        'Must be in range 0-4294967295',
      );
    }
  }

  @override
  final int value;

  @override
  int get minValue => 0;

  @override
  int get maxValue => u32Max;

  @override
  int get bitMask => 0xFFFFFFFF;

  @override
  String get typeName => 'U32';

  @override
  U32Value createInstance(int value) => U32Value(value);

  @override
  String get className => 'U32Value';

  static const List<String> _classHierarchy = [
    'U32Value',
    'IntNumericalValue',
    'NumericalValue',
    'TypedValue',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() {
    return Uint8List(4)
      ..[0] = (value >> 24) & 0xFF
      ..[1] = (value >> 16) & 0xFF
      ..[2] = (value >> 8) & 0xFF
      ..[3] = value & 0xFF;
  }

  U32Value operator +(U32Value other) => addChecked(other) as U32Value;
  U32Value operator -(U32Value other) => subtractChecked(other) as U32Value;
  U32Value operator *(U32Value other) => multiplyChecked(other) as U32Value;
  U32Value operator ~/(U32Value other) => divideInt(other) as U32Value;
  U32Value operator %(U32Value other) => modulo(other) as U32Value;

  bool operator <(U32Value other) => lessThan(other);
  bool operator <=(U32Value other) => lessThanOrEqual(other);
  bool operator >(U32Value other) => greaterThan(other);
  bool operator >=(U32Value other) => greaterThanOrEqual(other);

  U32Value operator &(U32Value other) => bitwiseAnd(other) as U32Value;
  U32Value operator |(U32Value other) => bitwiseOr(other) as U32Value;
  U32Value operator ^(U32Value other) => bitwiseXor(other) as U32Value;
  U32Value operator ~() => bitwiseNot() as U32Value;
  U32Value operator <<(int shift) => shiftLeft(shift) as U32Value;
  U32Value operator >>(int shift) => shiftRight(shift) as U32Value;
}
