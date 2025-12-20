import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../utils/helpers.dart';
import 'numerical.dart';

/// 64-bit unsigned integer type (0 to 18,446,744,073,709,551,615).
///
/// Represents unsigned 64-bit integers for large values like token amounts,
/// timestamps, and blockchain identifiers. Uses BigInt for values exceeding
/// platform int range.
///
/// #### Example
/// ```dart
/// final value1 = U64Type.create(BigInt.parse('1000000000000'));
/// final value2 = U64Type.create(9223372036854775807); // Max int
/// final maxValue = U64Type.create(BigInt.parse('18446744073709551615'));
///
/// // Arithmetic operations
/// final sum = value1 + U64Value(BigInt.from(500));
/// final product = value1 * U64Value(BigInt.from(2));
///
/// // Binary encoding (8 bytes, big-endian)
/// final bytes = value1.toBytes(); // [0, 0, 0, 232, 212, 165, 16, 0]
/// print('Value: ${value1.value}, Bytes: ${bytes.length}');
/// ```

@immutable
final class U64Type extends NumericalType {
  U64Type._() : super(name: 'u64', sizeInBytes: 8, isSigned: false);

  static final U64Type _instance = U64Type._();

  @override
  String get className => 'U64Type';

  static const List<String> _classHierarchy = [
    'U64Type',
    'NumericalType',
    'PrimitiveType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  /// Creates a U64Value from native Dart int or BigInt.
  ///
  /// #### Parameters
  /// - `nativeValue` - Integer or BigInt value between 0 and 18,446,744,073,709,551,615
  ///
  /// #### Returns
  /// `U64Value` - Instance with the unsigned 64-bit integer
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is negative or exceeds maximum
  ///
  /// #### Example
  /// ```dart
  /// final value1 = U64Type.create(1000);
  /// final value2 = U64Type.create(BigInt.parse('123456789012345'));
  /// final maxVal = U64Type.create(BigInt.parse('18446744073709551615'));
  ///
  /// // These throw: outside valid range
  /// // final invalid = U64Type.create(BigInt.parse('-1'));
  /// // final overflow = U64Type.create(BigInt.parse('18446744073709551616'));
  /// ```
  static U64Value create(dynamic nativeValue) {
    final BigInt bigInt = nativeValue is BigInt
        ? nativeValue
        : BigInt.from(requireAs<int>(nativeValue, 'nativeValue'));

    if (bigInt.isNegative || bigInt > u64Max) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'U64Type value out of range',
      );
    }
    return U64Value(bigInt);
  }

  /// Gets the singleton type instance for use in type definitions.
  static U64Type get type => _instance;

  @override
  U64Value createValue(dynamic nativeValue) => create(nativeValue);
}

/// 64-bit unsigned integer value.
@immutable
final class U64Value extends BigIntNumericalValue {
  /// Creates a U64 value from BigInt.
  ///
  /// #### Parameters
  /// - `value` - BigInt between 0 and 18,446,744,073,709,551,615
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is negative or exceeds maximum
  U64Value(this.value) : super(U64Type._instance) {
    if (value.isNegative || value > u64Max) {
      throw ArgumentError.value(value, 'value', 'U64Type value out of range');
    }
  }

  @override
  final BigInt value;

  @override
  BigInt get minValue => BigInt.zero;

  @override
  BigInt get maxValue => u64Max;

  @override
  BigInt get bitMask => u64Max;

  @override
  String get typeName => 'U64';

  @override
  U64Value createInstance(BigInt value) => U64Value(value);

  @override
  String get className => 'U64Value';

  static const List<String> _classHierarchy = [
    'U64Value',
    'BigIntNumericalValue',
    'NumericalValue',
    'TypedValue',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  static final List<Uint8List> _precomputed = List.generate(
    256,
    (i) => Uint8List(8)
      ..[0] = (i >> 56) & 0xFF
      ..[1] = (i >> 48) & 0xFF
      ..[2] = (i >> 40) & 0xFF
      ..[3] = (i >> 32) & 0xFF
      ..[4] = (i >> 24) & 0xFF
      ..[5] = (i >> 16) & 0xFF
      ..[6] = (i >> 8) & 0xFF
      ..[7] = i & 0xFF,
    growable: false,
  );

  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() {
    if (value <= BigInt.from(255)) return _precomputed[value.toInt()];

    return Uint8List(8)
      ..[0] = ((value >> 56) & BigInt.from(0xFF)).toInt()
      ..[1] = ((value >> 48) & BigInt.from(0xFF)).toInt()
      ..[2] = ((value >> 40) & BigInt.from(0xFF)).toInt()
      ..[3] = ((value >> 32) & BigInt.from(0xFF)).toInt()
      ..[4] = ((value >> 24) & BigInt.from(0xFF)).toInt()
      ..[5] = ((value >> 16) & BigInt.from(0xFF)).toInt()
      ..[6] = ((value >> 8) & BigInt.from(0xFF)).toInt()
      ..[7] = (value & BigInt.from(0xFF)).toInt();
  }

  U64Value operator +(U64Value other) => addChecked(other) as U64Value;
  U64Value operator -(U64Value other) => subtractChecked(other) as U64Value;
  U64Value operator *(U64Value other) => multiplyChecked(other) as U64Value;
  U64Value operator ~/(U64Value other) => divideInt(other) as U64Value;
  U64Value operator %(U64Value other) => modulo(other) as U64Value;

  bool operator <(U64Value other) => lessThan(other);
  bool operator <=(U64Value other) => lessThanOrEqual(other);
  bool operator >(U64Value other) => greaterThan(other);
  bool operator >=(U64Value other) => greaterThanOrEqual(other);

  U64Value operator &(U64Value other) => bitwiseAnd(other) as U64Value;
  U64Value operator |(U64Value other) => bitwiseOr(other) as U64Value;
  U64Value operator ^(U64Value other) => bitwiseXor(other) as U64Value;
  U64Value operator ~() => bitwiseNot() as U64Value;
  U64Value operator <<(int shift) => shiftLeft(shift) as U64Value;
  U64Value operator >>(int shift) => shiftRight(shift) as U64Value;
}
