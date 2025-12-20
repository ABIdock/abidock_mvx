import 'package:meta/meta.dart';

import '../../codecs/codec_base.dart';
import '../../core/type_system.dart';

/// Algebraic optional type for function arguments that can be omitted.
///
/// Represents arguments that may or may not be provided to smart
/// contract functions. Uses algebraic data type pattern with "provided" and
/// "missing" variants. Commonly used for optional parameters in contract calls.
@immutable
final class OptionalType extends AbiType {
  OptionalType._(this.innerType)
    : super(
        name: 'Optional',
        typeParameters: <AbiType>[innerType],
        cardinality: TypeCardinalityExtension.variable(1),
      );

  /// Creates Optional type for the inner type.
  ///
  /// #### Example
  /// ```dart
  /// final optAddress = OptionalType.of(AddressType.type);
  /// final optAmount = OptionalType.of(BigUIntType.type);
  /// ```
  factory OptionalType.of(AbiType innerType) => OptionalType._(innerType);

  /// Creates OptionalValue with provided value.
  ///
  /// #### Example
  /// ```dart
  /// final value = OptionalType.create(AddressType.type, "erd1...");
  /// ```
  static OptionalValue create(AbiType innerType, dynamic nativeValue) {
    final type = OptionalType.of(innerType);
    return type.createValue(nativeValue) as OptionalValue;
  }

  /// Type of value this Optional can contain.
  final AbiType innerType;

  @override
  String get className => 'OptionalType';

  static const List<String> _classHierarchy = ['OptionalType', 'AbiType'];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  String get fullyQualifiedName => 'Optional<${innerType.fullyQualifiedName}>';

  /// Creates OptionalValue from native value or null.
  ///
  /// #### Parameters
  /// - `nativeValue` - Value to wrap (null for missing variant)
  ///
  /// #### Returns
  /// `OptionalValue` - provided (if non-null) or missing (if null)
  ///
  /// #### Example
  /// ```dart
  /// final optType = OptionalType(U32Type.type);
  ///
  /// final val1 = optType.createValue(42); // provided
  /// final val2 = optType.createValue(null); // missing
  /// ```
  @override
  TypedValue createValue(dynamic nativeValue) {
    if (nativeValue == null) {
      return OptionalValue.missing(this);
    }
    final TypedValue innerValue = innerType.createValue(nativeValue);
    return OptionalValue.provided(this, innerValue);
  }
}

/// Algebraic optional value representing provided or missing argument.
///
/// Holds either a provided value (Some) or missing value (None).
/// Provides methods to check presence, unwrap safely, map over values, etc.
/// Follows Rust/Scala Option pattern.
///
/// #### Example
/// ```dart
/// final optType = OptionalType(U32Type.type);
///
/// // Provided variant
/// final provided = OptionalValue.provided(optType, U32Value(100));
/// print(provided.isProvided); // true
/// print(provided.nativeValue); // 100
/// print(provided.unwrap()); // U32Value(100)
///
/// // Missing variant
/// final missing = OptionalValue.missing(optType);
/// print(missing.isMissing); // true
/// print(missing.nativeValue); // null
/// // missing.unwrap(); // Throws StateError
///
/// // Safe unwrap with default
/// final value = missing.unwrapOr(U32Value(0));
/// ```
@immutable
final class OptionalValue extends TypedValue {
  const OptionalValue._(OptionalType super.type, this.value);

  /// Creates a provided variant containing a value.
  ///
  /// #### Parameters
  /// - `type` - OptionalType instance
  /// - `value` - TypedValue to wrap (must match innerType)
  ///
  /// #### Example
  /// ```dart
  /// final optType = OptionalType(BooleanType.type);
  /// final provided = OptionalValue.provided(optType, BooleanValue(true));
  /// ```
  factory OptionalValue.provided(OptionalType type, TypedValue value) {
    return OptionalValue._(type, value);
  }

  /// Creates a missing variant (argument not provided).
  ///
  /// #### Parameters
  /// - `type` - OptionalType instance
  ///
  /// #### Example
  /// ```dart
  /// final optType = OptionalType(AddressType.type);
  /// final missing = OptionalValue.missing(optType);
  /// print(missing.isMissing); // true
  /// ```
  factory OptionalValue.missing(OptionalType type) {
    return OptionalValue._(type, null);
  }

  /// Wrapped value (null if missing).
  final TypedValue? value;

  /// Whether this Optional has a provided value.
  bool get isProvided => value != null;

  /// Whether this Optional is missing (not provided).
  bool get isMissing => value == null;

  @override
  OptionalType get type => super.type as OptionalType;

  @override
  String get className => 'OptionalValue';

  static const List<String> _classHierarchy = ['OptionalValue', 'TypedValue'];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  dynamic get nativeValue => value?.nativeValue;

  /// Encodes to bytes or returns empty for missing.
  ///
  /// #### Returns
  /// `List<int>` - Byte encoding of wrapped value (empty if missing)
  ///
  /// #### Example
  /// ```dart
  /// final provided = OptionalValue.provided(
  ///   OptionalType(U32Type.type),
  ///   U32Value(100),
  /// );
  /// print(provided.toBytes()); // [0, 0, 0, 100]
  ///
  /// final missing = OptionalValue.missing(OptionalType(U32Type.type));
  /// print(missing.toBytes()); // []
  /// ```
  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() {
    if (isMissing) {
      return BinaryCodecUtils.emptyBuffer;
    }
    return value!.toBytes();
  }

  /// Returns the wrapped value or throws if missing.
  ///
  /// #### Returns
  /// `TypedValue` - The wrapped TypedValue
  ///
  /// #### Throws
  /// - `StateError` - If called on missing variant
  ///
  /// #### Example
  /// ```dart
  /// final provided = OptionalValue.provided(
  ///   OptionalType(U32Type.type),
  ///   U32Value(42),
  /// );
  /// print(provided.unwrap()); // U32Value(42)
  ///
  /// final missing = OptionalValue.missing(OptionalType(U32Type.type));
  /// // missing.unwrap(); // Throws StateError
  /// ```
  TypedValue unwrap() {
    if (isMissing) {
      throw StateError('Called unwrap() on missing optional argument');
    }
    return value!;
  }

  /// Returns the wrapped value or the default if missing.
  ///
  /// #### Parameters
  /// - `defaultValue` - Value to return if missing
  ///
  /// #### Returns
  /// `TypedValue` - Wrapped value or default
  ///
  /// #### Example
  /// ```dart
  /// final missing = OptionalValue.missing(OptionalType(U32Type.type));
  /// final value = missing.unwrapOr(U32Value(0));
  /// print(value.nativeValue); // 0
  /// ```
  TypedValue unwrapOr(TypedValue defaultValue) {
    return value ?? defaultValue;
  }

  /// Maps the wrapped value using the provided function.
  ///
  /// #### Parameters
  /// - `f` - Transformation function
  ///
  /// #### Returns
  /// `OptionalValue` - New instance with transformed value (or missing)
  ///
  /// #### Example
  /// ```dart
  /// final opt = OptionalValue.provided(
  ///   OptionalType(U32Type.type),
  ///   U32Value(10),
  /// );
  ///
  /// final doubled = opt.map((v) => U32Value((v as U32Value).value * 2));
  /// print(doubled.nativeValue); // 20
  ///
  /// final missing = OptionalValue.missing(OptionalType(U32Type.type));
  /// final result = missing.map((v) => U32Value(999));
  /// print(result.isMissing); // true (map does nothing on missing)
  /// ```
  OptionalValue map(TypedValue Function(TypedValue) f) {
    if (isMissing) {
      return this;
    }
    return OptionalValue.provided(type, f(value!));
  }

  @override
  String toString() {
    if (isMissing) {
      return 'Missing';
    }
    return 'Provided($value)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OptionalValue) return false;

    if (isMissing && other.isMissing) return true;
    if (isMissing != other.isMissing) return false;

    return value == other.value && type == other.type;
  }

  @override
  int get hashCode => Object.hash(type, value);
}
