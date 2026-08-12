import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../core/type_system.dart';

/// Boolean type encoded as a single byte (0x00 or 0x01).
///
/// Represents true/false values in smart contract types.
/// Encoded as 0x01 for true and 0x00 for false.
///
/// #### Example
/// ```dart
/// final trueValue = BooleanType.create(true);
/// final falseValue = BooleanType.create(false);
///
/// print(trueValue.toBytes()); // [1]
/// print(falseValue.toBytes()); // [0]
/// print(trueValue.nativeValue); // true
///
/// // Use in struct definitions
/// final structType = StructType(
///   name: 'Flags',
///   fieldDefinitions: [
///     FieldDefinition(name: 'isActive', type: BooleanType.type),
///   ],
/// );
/// ```
@immutable
final class BooleanType extends PrimitiveType {
  BooleanType._() : super(name: 'bool');

  static final BooleanType _instance = BooleanType._();

  @override
  int get sizeInBytes => 1;

  @override
  String get className => 'BooleanType';

  static const List<String> _classHierarchy = [
    'BooleanType',
    'PrimitiveType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  /// Creates a BooleanValue from a native bool.
  ///
  /// #### Parameters
  /// - `nativeValue` - Dart bool (true or false)
  ///
  /// #### Throws
  /// - `ArgumentError` - If nativeValue is not bool
  ///
  /// #### Example
  /// ```dart
  /// final trueValue = BooleanType.create(true);
  /// final falseValue = BooleanType.create(false);
  ///
  /// print(trueValue.isTrue); // true
  /// print(falseValue.isFalse); // true
  /// ```
  static BooleanValue create(dynamic nativeValue) {
    if (nativeValue is bool) {
      return BooleanValue(nativeValue);
    }
    if (nativeValue is int) {
      return BooleanValue(nativeValue != 0);
    }
    throw ArgumentError.value(
      nativeValue,
      'nativeValue',
      'BooleanType requires bool value',
    );
  }

  /// Gets the singleton type instance for use in type definitions.
  static BooleanType get type => _instance;

  @override
  TypedValue createValue(dynamic nativeValue) => create(nativeValue);
}

/// Boolean value (true or false).
///
/// Holds a boolean value with encoding to/from byte representation.
/// Provides utility methods for boolean checks and operations.
///
/// #### Example
/// ```dart
/// final trueVal = BooleanValue(true);
/// final falseVal = BooleanValue(false);
///
/// // Value access
/// print(trueVal.nativeValue); // true
/// print(falseVal.nativeValue); // false
///
/// // Utility methods
/// print(trueVal.isTrue); // true
/// print(trueVal.isFalse); // false
///
/// // Binary encoding
/// print(trueVal.toBytes()); // [1]
/// print(falseVal.toBytes()); // [0]
/// ```
@immutable
final class BooleanValue extends TypedValue {
  /// Creates a Boolean value.
  ///
  /// #### Parameters
  /// - `value` - Boolean value (true or false)
  BooleanValue(this.value) : super(BooleanType._instance);

  /// Boolean value.
  final bool value;

  @override
  String get className => 'BooleanValue';

  static const List<String> _classHierarchy = ['BooleanValue', 'TypedValue'];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  bool get nativeValue => value;

  /// Encodes to single byte: 0x01 for true, 0x00 for false.
  ///
  /// #### Returns
  /// `List<int>` - Single-element byte list
  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() => Uint8List(1)..[0] = value ? 1 : 0;

  /// Returns whether this value is true.
  ///
  /// #### Returns
  /// `bool` - true if value is true, false otherwise
  bool get isTrue => value == true;

  /// Returns whether this value is false.
  ///
  /// #### Returns
  /// `bool` - true if value is false, false otherwise
  bool get isFalse => !isTrue;
}
