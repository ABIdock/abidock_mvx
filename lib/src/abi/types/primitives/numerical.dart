/// Numerical ABI types and base classes for smart contracts.
///
/// Provides base types and shared arithmetic for all numerical ABI types:
/// unsigned (U8, U16, U32, U64, BigUint) and signed (I8, I16, I32, I64, BigInt).
import 'package:meta/meta.dart';

import '../../core/type_system.dart';

export 'bigint.dart';
export 'biguint.dart';
export 'i16.dart';
export 'i32.dart';
export 'i64.dart';
export 'i8.dart';
export 'u16.dart';
export 'u32.dart';
export 'u64.dart';
export 'u8.dart';

/// U8 maximum value (255).
const int u8Max = 255;

/// U16 maximum value (65,535).
const int u16Max = 65535;

/// U32 maximum value (4,294,967,295).
const int u32Max = 4294967295;

/// U64 maximum value (18,446,744,073,709,551,615).
final BigInt u64Max = BigInt.parse('18446744073709551615');

/// I8 minimum value (-128).
const int i8Min = -128;

/// I8 maximum value (127).
const int i8Max = 127;

/// I16 minimum value (-32,768).
const int i16Min = -32768;

/// I16 maximum value (32,767).
const int i16Max = 32767;

/// I32 minimum value (-2,147,483,648).
const int i32Min = -2147483648;

/// I32 maximum value (2,147,483,647).
const int i32Max = 2147483647;

/// I64 minimum value (-9,223,372,036,854,775,808).
final BigInt i64Min = BigInt.parse('-9223372036854775808');

/// I64 maximum value (9,223,372,036,854,775,807).
final BigInt i64Max = BigInt.parse('9223372036854775807');

/// Base type for all numerical ABI types.
///
/// Abstract base for U8, U16, U32, U64, I8, I16, I32, I64, BigUint, BigInt types.
/// Provides common properties like byte size and signedness.
///
/// #### Example
/// ```dart
/// final u32Type = U32Type.type; // sizeInBytes=4, isSigned=false
/// final i64Type = I64Type.type; // sizeInBytes=8, isSigned=true
/// ```
@immutable
abstract class NumericalType extends PrimitiveType {
  /// Creates a numerical type.
  ///
  /// #### Parameters
  /// - `name` - Type name (u8, u16, u32, u64, i8, i16, i32, i64, BigUint, Bigint)
  /// - `sizeInBytes` - Fixed size in bytes (null for BigUint/BigInt)
  /// - `isSigned` - Whether this represents signed integers
  NumericalType({
    required super.name,
    required this.sizeInBytes,
    required this.isSigned,
  });

  @override
  final int? sizeInBytes;

  /// Whether this type represents signed integers.
  final bool isSigned;

  @override
  String get className => 'NumericalType';

  static const List<String> _classHierarchy = [
    'NumericalType',
    'PrimitiveType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;
}

/// Base value for all numerical ABI values.
///
/// Provides conversion to BigInt/int and top-encoding for variable-length encoding.
///
/// #### Example
/// ```dart
/// final u32Val = U32Value(1000);
/// print(u32Val.asBigInt); // BigInt(1000)
/// print(u32Val.asInt); // 1000
/// ```
@immutable
abstract class NumericalValue extends TypedValue {
  /// Creates a numerical value with the given type.
  const NumericalValue(super.type);

  @override
  String get className => 'NumericalValue';

  static const List<String> _classHierarchy = ['NumericalValue', 'TypedValue'];

  @override
  List<String> get classHierarchy => _classHierarchy;

  /// Returns this value as a BigInt.
  BigInt get asBigInt;

  /// Returns this value as an int (may lose precision for large values).
  int get asInt => asBigInt.toInt();

  @override
  List<int> toTopBytes() {
    final BigInt value = asBigInt;
    if (value == BigInt.zero) return <int>[];

    final List<int> bytes = <int>[];
    BigInt remaining = value.abs();

    while (remaining > BigInt.zero) {
      bytes.insert(0, (remaining & BigInt.from(0xff)).toInt());
      remaining = remaining >> 8;
    }

    if (value < BigInt.zero) {
      for (int i = 0; i < bytes.length; i++) {
        bytes[i] = ~bytes[i] & 0xff;
      }
      if (bytes.isNotEmpty && (bytes[0] & 0x80) == 0) {
        bytes.insert(0, 0xff);
      }
    } else if (type is NumericalType && (type as NumericalType).isSigned) {
      if (bytes.isNotEmpty && (bytes[0] & 0x80) != 0) {
        bytes.insert(0, 0x00);
      }
    }

    return bytes;
  }
}

/// Base for int-storage numerical values (U8, U16, U32, I8, I16, I32).
///
/// Provides shared arithmetic with bounds checking. Subclasses define
/// [value], [minValue], [maxValue], [bitMask], and [createInstance].
///
/// #### Example
/// ```dart
/// final a = U8Value(100);
/// final b = U8Value(50);
/// final sum = a + b; // U8Value(150)
/// ```
@immutable
abstract class IntNumericalValue extends NumericalValue {
  /// Creates an int-based numerical value.
  const IntNumericalValue(super.type);

  /// The integer value.
  int get value;

  /// Minimum allowed value for this type.
  int get minValue;

  /// Maximum allowed value for this type.
  int get maxValue;

  /// Bit mask for this type (e.g., 0xFF for 8-bit).
  int get bitMask;

  /// Type name for error messages (e.g., 'U8', 'I32').
  String get typeName;

  /// Creates a new instance of the same type with the given value.
  IntNumericalValue createInstance(int value);

  @pragma('vm:prefer-inline')
  @override
  BigInt get asBigInt => BigInt.from(value);

  @override
  int get nativeValue => value;

  @protected
  IntNumericalValue addChecked(IntNumericalValue other) {
    final int result = value + other.value;
    if (result > maxValue || result < minValue) {
      throw ArgumentError(
        '$typeName overflow: $value + ${other.value} = $result',
      );
    }
    return createInstance(result);
  }

  @protected
  IntNumericalValue subtractChecked(IntNumericalValue other) {
    final int result = value - other.value;
    if (result > maxValue || result < minValue) {
      throw ArgumentError(
        '$typeName underflow: $value - ${other.value} = $result',
      );
    }
    return createInstance(result);
  }

  @protected
  IntNumericalValue multiplyChecked(IntNumericalValue other) {
    final int result = value * other.value;
    if (result > maxValue || result < minValue) {
      throw ArgumentError(
        '$typeName overflow: $value * ${other.value} = $result',
      );
    }
    return createInstance(result);
  }

  @protected
  IntNumericalValue divideInt(IntNumericalValue other) =>
      createInstance(value ~/ other.value);

  @protected
  IntNumericalValue modulo(IntNumericalValue other) =>
      createInstance(value % other.value);

  @protected
  IntNumericalValue negateChecked() {
    final int result = -value;
    if (result > maxValue || result < minValue) {
      throw ArgumentError('$typeName overflow: -$value = $result');
    }
    return createInstance(result);
  }

  @protected
  bool lessThan(IntNumericalValue other) => value < other.value;

  @protected
  bool lessThanOrEqual(IntNumericalValue other) => value <= other.value;

  @protected
  bool greaterThan(IntNumericalValue other) => value > other.value;

  @protected
  bool greaterThanOrEqual(IntNumericalValue other) => value >= other.value;

  @protected
  IntNumericalValue bitwiseAnd(IntNumericalValue other) =>
      createInstance(value & other.value);

  @protected
  IntNumericalValue bitwiseOr(IntNumericalValue other) =>
      createInstance(value | other.value);

  @protected
  IntNumericalValue bitwiseXor(IntNumericalValue other) =>
      createInstance(value ^ other.value);

  @protected
  IntNumericalValue bitwiseNot() => createInstance(~value & bitMask);

  @protected
  IntNumericalValue shiftLeft(int shift) =>
      createInstance((value << shift) & bitMask);

  @protected
  IntNumericalValue shiftRight(int shift) => createInstance(value >> shift);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntNumericalValue &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Base for BigInt-storage numerical values (U64, I64).
///
/// Provides shared arithmetic with bounds checking for 64-bit types.
/// Subclasses define [value], [minValue], [maxValue], [bitMask], and [createInstance].
///
/// #### Example
/// ```dart
/// final a = U64Value(BigInt.from(1000000000000));
/// final b = U64Value(BigInt.from(500000000000));
/// final sum = a + b; // U64Value(1500000000000)
/// ```
@immutable
abstract class BigIntNumericalValue extends NumericalValue {
  /// Creates a BigInt-based numerical value.
  const BigIntNumericalValue(super.type);

  /// The BigInt value.
  BigInt get value;

  /// Minimum allowed value for this type.
  BigInt get minValue;

  /// Maximum allowed value for this type.
  BigInt get maxValue;

  /// Bit mask for this type (64-bit).
  BigInt get bitMask;

  /// Type name for error messages (e.g., 'U64', 'I64').
  String get typeName;

  /// Creates a new instance of the same type with the given value.
  BigIntNumericalValue createInstance(BigInt value);

  @pragma('vm:prefer-inline')
  @override
  BigInt get asBigInt => value;

  @override
  BigInt get nativeValue => value;

  @protected
  BigIntNumericalValue addChecked(BigIntNumericalValue other) {
    final BigInt result = value + other.value;
    if (result > maxValue || result < minValue) {
      throw ArgumentError(
        '$typeName overflow: $value + ${other.value} = $result',
      );
    }
    return createInstance(result);
  }

  @protected
  BigIntNumericalValue subtractChecked(BigIntNumericalValue other) {
    final BigInt result = value - other.value;
    if (result > maxValue || result < minValue) {
      throw ArgumentError(
        '$typeName underflow: $value - ${other.value} = $result',
      );
    }
    return createInstance(result);
  }

  @protected
  BigIntNumericalValue multiplyChecked(BigIntNumericalValue other) {
    final BigInt result = value * other.value;
    if (result > maxValue || result < minValue) {
      throw ArgumentError(
        '$typeName overflow: $value * ${other.value} = $result',
      );
    }
    return createInstance(result);
  }

  @protected
  BigIntNumericalValue divideInt(BigIntNumericalValue other) =>
      createInstance(value ~/ other.value);

  @protected
  BigIntNumericalValue modulo(BigIntNumericalValue other) =>
      createInstance(value % other.value);

  @protected
  BigIntNumericalValue negateChecked() {
    final BigInt result = -value;
    if (result > maxValue || result < minValue) {
      throw ArgumentError('$typeName overflow: -$value = $result');
    }
    return createInstance(result);
  }

  @protected
  bool lessThan(BigIntNumericalValue other) => value < other.value;

  @protected
  bool lessThanOrEqual(BigIntNumericalValue other) => value <= other.value;

  @protected
  bool greaterThan(BigIntNumericalValue other) => value > other.value;

  @protected
  bool greaterThanOrEqual(BigIntNumericalValue other) => value >= other.value;

  @protected
  BigIntNumericalValue bitwiseAnd(BigIntNumericalValue other) =>
      createInstance(value & other.value);

  @protected
  BigIntNumericalValue bitwiseOr(BigIntNumericalValue other) =>
      createInstance(value | other.value);

  @protected
  BigIntNumericalValue bitwiseXor(BigIntNumericalValue other) =>
      createInstance(value ^ other.value);

  @protected
  BigIntNumericalValue bitwiseNot() => createInstance(~value & bitMask);

  @protected
  BigIntNumericalValue shiftLeft(int shift) =>
      createInstance((value << shift) & bitMask);

  @protected
  BigIntNumericalValue shiftRight(int shift) => createInstance(value >> shift);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BigIntNumericalValue &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}
