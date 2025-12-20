import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../core/type_system.dart';

/// Optional type that can contain a value or be empty.
///
/// Represents smart contract Option types for nullable values
/// (e.g., `Option<T>` in Rust). Encoded as Some(value) or None.
@immutable
final class OptionType extends AbiType {
  /// Creates an Option type for the inner type.
  ///
  /// #### Parameters
  /// - `innerType` - The ABI type this Option can contain
  ///
  /// #### Example
  /// ```dart
  /// // Option of address
  /// final optionalAddress = OptionType(AddressType.type);
  ///
  /// // Option of string
  /// final optionalString = OptionType(BytesType.type);
  /// ```
  OptionType(this.innerType)
    : super(
        name: 'Option',
        typeParameters: <AbiType>[innerType],
        cardinality: TypeCardinalityExtension.singular(),
      );

  /// Type of value this Option can contain.
  final AbiType innerType;

  @override
  String get className => 'OptionType';

  static const List<String> _classHierarchy = ['OptionType', 'AbiType'];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  String get fullyQualifiedName => 'Option<${innerType.fullyQualifiedName}>';

  /// Creates an OptionValue from a native Dart value or null.
  ///
  /// #### Parameters
  /// - `nativeValue` - Value matching innerType, or null for None
  ///
  /// #### Returns
  /// `TypedValue` - OptionValue instance as Some(value) or None
  ///
  /// #### Example
  /// ```dart
  /// final optionType = OptionType(U32Type.type);
  ///
  /// // Create Some variant
  /// final some = optionType.createValue(100);
  /// print(some.isSome); // true
  ///
  /// // Create None variant
  /// final none = optionType.createValue(null);
  /// print(none.isNone); // true
  /// ```
  @override
  TypedValue createValue(dynamic nativeValue) {
    if (nativeValue == null) {
      return OptionValue.none(this);
    }
    final TypedValue innerValue = innerType.createValue(nativeValue);
    return OptionValue.some(this, innerValue);
  }
}

/// Optional value representing Some(value) or None.
///
/// Encodes nullable values for smart contracts. Provides safe access
/// with unwrap operations and functional mapping.
///
/// #### Example
/// ```dart
/// final optionType = OptionType(U32Type.type);
///
/// // Some variant
/// final some = OptionValue.some(optionType, U32Value(42));
/// print(some.isSome); // true
/// print(some.unwrap().nativeValue); // 42
///
/// // None variant
/// final none = OptionValue.none(optionType);
/// print(none.isNone); // true
/// // none.unwrap() would throw StateError
/// ```
@immutable
final class OptionValue extends TypedValue {
  const OptionValue._(OptionType super.type, this.value);

  /// Creates a Some variant containing a value.
  ///
  /// #### Parameters
  /// - `type` - OptionType defining the inner type
  /// - `value` - TypedValue to wrap
  ///
  /// #### Example
  /// ```dart
  /// final optionType = OptionType(U32Type.type);
  /// final some = OptionValue.some(optionType, U32Value(100));
  /// print(some.nativeValue); // 100
  /// ```
  factory OptionValue.some(OptionType type, TypedValue value) {
    return OptionValue._(type, value);
  }

  /// Creates a None variant (empty option).
  ///
  /// #### Parameters
  /// - `type` - OptionType defining the inner type
  ///
  /// #### Example
  /// ```dart
  /// final optionType = OptionType(U32Type.type);
  /// final none = OptionValue.none(optionType);
  /// print(none.nativeValue); // null
  /// ```
  factory OptionValue.none(OptionType type) {
    return OptionValue._(type, null);
  }

  /// Wrapped value (null if None).
  final TypedValue? value;

  /// Whether this Option contains a value.
  bool get isSome => value != null;

  /// Whether this Option is empty.
  bool get isNone => value == null;

  @override
  OptionType get type => super.type as OptionType;

  @override
  String get className => 'OptionValue';

  static const List<String> _classHierarchy = ['OptionValue', 'TypedValue'];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  dynamic get nativeValue => value?.nativeValue;

  /// Encodes option to bytes: [0x00] for None, [0x01, ...value] for Some.
  ///
  /// #### Returns
  /// Byte array with discriminator (0x00=None, 0x01=Some) and optional value
  ///
  /// #### Example
  /// ```dart
  /// final optionType = OptionType(U8Type.type);
  ///
  /// final none = OptionValue.none(optionType);
  /// print(none.toBytes()); // [0]
  ///
  /// final some = optionType.createValue(42);
  /// print(some.toBytes()); // [1, 42]
  /// ```
  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() {
    if (isNone) {
      return Uint8List(1)..[0] = 0;
    }
    final BytesBuilder builder = BytesBuilder(copy: false);
    builder.addByte(1);
    builder.add(value!.toBytes());
    return builder.takeBytes();
  }

  /// Returns the wrapped value or throws if None.
  ///
  /// #### Returns
  /// Wrapped TypedValue
  ///
  /// #### Throws
  /// - `StateError` - If called on None
  ///
  /// #### Example
  /// ```dart
  /// final some = optionType.createValue(42);
  /// print(some.unwrap().nativeValue); // 42
  ///
  /// final none = optionType.createValue(null);
  /// // none.unwrap(); // Throws StateError
  /// ```
  TypedValue unwrap() {
    if (isNone) {
      throw StateError('Called unwrap() on None');
    }
    return value!;
  }

  /// Returns the wrapped value or the default if None.
  ///
  /// #### Parameters
  /// - `defaultValue` - TypedValue to return if None
  ///
  /// #### Returns
  /// `TypedValue` - Wrapped value or defaultValue
  ///
  /// #### Example
  /// ```dart
  /// final fallback = U32Value(0);
  /// final some = optionType.createValue(42);
  /// print(some.unwrapOr(fallback).nativeValue); // 42
  ///
  /// final none = optionType.createValue(null);
  /// print(none.unwrapOr(fallback).nativeValue); // 0
  /// ```
  TypedValue unwrapOr(TypedValue defaultValue) {
    return value ?? defaultValue;
  }

  /// Maps the wrapped value using the provided function.
  ///
  /// #### Parameters
  /// - `f` - Function to apply to wrapped value
  ///
  /// #### Returns
  /// `OptionValue` - New instance with transformed value, or None if None
  ///
  /// #### Example
  /// ```dart
  /// final some = optionType.createValue(5);
  /// final doubled = some.map((e) {
  ///   final u32 = e as U32Value;
  ///   return U32Value(u32.nativeValue * 2);
  /// });
  /// print(doubled.nativeValue); // 10
  ///
  /// final none = optionType.createValue(null);
  /// final result = none.map((e) => e); // Still None
  /// ```
  OptionValue map(TypedValue Function(TypedValue) f) {
    if (isNone) {
      return this;
    }
    return OptionValue.some(type, f(value!));
  }

  @override
  String toString() {
    if (isNone) {
      return 'None';
    }
    return 'Some($value)';
  }
}
