/// Core ABI type system foundations and base classes.
import 'package:meta/meta.dart';

import '../../utils/hex_utils.dart';

/// Type cardinality (multiplicity) as a lightweight record.
///
/// Defines how many values a type can hold (1, fixed, or variable).
typedef TypeCardinality = ({int lowerBound, int? upperBound});

/// Extension methods for TypeCardinality record.
extension TypeCardinalityExtension on TypeCardinality {
  /// Maximum allowed cardinality value for bounded types.
  static const int maxCardinality = 65536;

  /// Creates singular cardinality (exactly one element).
  static TypeCardinality singular() => (lowerBound: 1, upperBound: 1);

  /// Creates fixed cardinality (exactly `value` elements).
  ///
  /// #### Parameters
  /// - `value` - Exact number of elements
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is negative
  static TypeCardinality fixed(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'Cannot be negative');
    }
    return (lowerBound: value, upperBound: value);
  }

  /// Creates variable cardinality (0 to `value` elements, null = unlimited).
  ///
  /// #### Parameters
  /// - `value` - Maximum elements (null = unbounded)
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is negative
  static TypeCardinality variable([int? value]) {
    if (value != null && value < 0) {
      throw ArgumentError.value(value, 'value', 'Cannot be negative');
    }
    return (lowerBound: 0, upperBound: value);
  }

  /// Checks if represents exactly one value.
  bool get isSingular => lowerBound == 1 && upperBound == 1;

  /// Checks if represents zero or one value.
  bool get isSingularOrNone => lowerBound == 0 && upperBound == 1;

  /// Checks if represents multiple values.
  bool get isComposite => upperBound != 1;

  /// Checks if has fixed bounds.
  bool get isFixed => lowerBound == upperBound;

  /// Gets effective upper bound (uses maxCardinality if unbounded).
  int get effectiveUpperBound => upperBound ?? maxCardinality;

  /// String representation.
  String toStringValue() {
    if (isSingular) return 'TypeCardinality.singular';
    if (isFixed) return 'TypeCardinality.fixed($lowerBound)';
    return 'TypeCardinality($lowerBound..$upperBound)';
  }
}

/// Base class for all ABI types.
@immutable
abstract class AbiType {
  /// Creates ABI type.
  ///
  /// #### Parameters
  /// - `name` - Type name (e.g., 'u32', 'Address', 'List')
  /// - `typeParameters` - Generic type parameters (default: empty)
  /// - `cardinality` - Type cardinality (default: singular)
  /// - `metadata` - Optional metadata
  AbiType({
    required this.name,
    this.typeParameters = const <AbiType>[],
    TypeCardinality? cardinality,
    this.metadata,
  }) : cardinality = cardinality ?? TypeCardinalityExtension.singular();

  /// Type name (e.g., 'u32', 'Address', 'List').
  final String name;

  /// Type parameters for generic types.
  final List<AbiType> typeParameters;

  /// Type cardinality.
  final TypeCardinality cardinality;

  /// Optional metadata.
  final dynamic metadata;

  /// Returns class name for runtime type identification.
  ///
  /// #### Returns
  /// `String` - Class name (e.g., 'U32Type', 'AddressType')
  String get className => 'AbiType';

  /// Returns full class hierarchy from most specific to most general.
  ///
  /// #### Returns
  /// List of class names
  List<String> get classHierarchy => <String>[className];

  /// Returns byte size if fixed, null if dynamic.
  ///
  /// #### Returns
  /// `int?` - Size in bytes or null if variable
  int? get sizeInBytes => null;

  /// Whether type has dynamic (variable) length.
  bool get isDynamic => sizeInBytes == null;

  /// Whether type is generic (has type parameters).
  bool get isGeneric => typeParameters.isNotEmpty;

  /// Whether type has metadata attached.
  bool get hasMetadata => metadata != null;

  /// Gets first type parameter.
  ///
  /// #### Returns
  /// `AbiType` - First type parameter
  ///
  /// #### Throws
  /// - `StateError` - If type has no parameters
  AbiType get firstTypeParameter {
    if (typeParameters.isEmpty) {
      throw StateError('Type $name has no type parameters');
    }
    return typeParameters.first;
  }

  /// Returns fully qualified name including type parameters.
  ///
  /// #### Returns
  /// `String` - Qualified name (e.g., `multiversx:types:List<u32>`)
  String get fullyQualifiedName {
    if (!isGeneric && !hasMetadata) {
      return 'multiversx:types:$name';
    }

    final StringBuffer buffer = StringBuffer('multiversx:types:$name');

    if (typeParameters.isNotEmpty) {
      final String params = typeParameters
          .map((AbiType t) => t.fullyQualifiedName)
          .join(', ');
      buffer.write('<$params>');
    }

    if (hasMetadata) {
      buffer.write('*$metadata*');
    }

    return buffer.toString();
  }

  /// Checks if instance is exactly the specified class.
  ///
  /// #### Parameters
  /// - `name` - Class name to check
  ///
  /// #### Returns
  /// `bool` - true if exact match
  bool hasExactClass(String name) => className == name;

  /// Checks if instance is or extends the specified class.
  ///
  /// #### Parameters
  /// - `name` - Class name to check
  ///
  /// #### Returns
  /// `bool` - true if in hierarchy
  bool hasClassOrSuperclass(String name) => classHierarchy.contains(name);

  /// Checks type equality based on fully qualified names.
  ///
  /// #### Parameters
  /// - `other` - Type to compare
  ///
  /// #### Returns
  /// `bool` - true if types are equal
  bool equals(AbiType other) => fullyQualifiedName == other.fullyQualifiedName;

  /// Checks if type can be assigned from `other` type.
  ///
  /// #### Parameters
  /// - `other` - Type to check assignability
  ///
  /// #### Returns
  /// `bool` - true if assignable
  bool isAssignableFrom(AbiType other) {
    if (typeParameters.length != other.typeParameters.length) {
      return false;
    }

    for (int i = 0; i < typeParameters.length; i++) {
      if (!typeParameters[i].equals(other.typeParameters[i])) {
        return false;
      }
    }

    return className == other.className;
  }

  /// Creates typed value from native Dart value.
  ///
  /// #### Parameters
  /// - `nativeValue` - Dart value to convert
  ///
  /// #### Returns
  /// `TypedValue` - Typed value instance
  ///
  /// #### Throws
  /// - `ArgumentError` - If value incompatible with type
  TypedValue createValue(dynamic nativeValue);

  /// Checks if type can accept the given native value.
  ///
  /// #### Parameters
  /// - `nativeValue` - Dart value to check
  ///
  /// #### Returns
  /// `bool` - true if value is valid for this type
  bool canAcceptValue(dynamic nativeValue) {
    try {
      createValue(nativeValue);
      return true;
    } catch (e) {
      return false;
    }
  }

  Map<String, dynamic> toMap() => <String, dynamic>{'type': name};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AbiType && runtimeType == other.runtimeType && equals(other);

  @override
  int get hashCode => fullyQualifiedName.hashCode;

  @override
  String toString() {
    if (typeParameters.isEmpty) {
      return '$name()';
    }
    final String params = typeParameters
        .map((AbiType t) => t.toString())
        .join(', ');
    return '$name<$params>()';
  }
}

/// Base class for all primitive types.
///
/// Foundation for u32, Address, bool, bytes, etc.
@immutable
abstract class PrimitiveType extends AbiType {
  /// Creates primitive type.
  PrimitiveType({
    required super.name,
    super.typeParameters,
    super.cardinality,
    super.metadata,
  });

  @override
  String get className => 'PrimitiveType';

  @override
  List<String> get classHierarchy => <String>[className, 'AbiType'];
}

/// Base class for custom/user-defined types.
///
/// Foundation for Struct, Enum types defined in smart contracts.
@immutable
abstract class CustomType extends AbiType {
  /// Creates custom type.
  CustomType({
    required super.name,
    super.typeParameters,
    super.cardinality,
    super.metadata,
  });

  @override
  String get className => 'CustomType';

  @override
  List<String> get classHierarchy => <String>[className, 'AbiType'];

  /// Returns type dependency names for this custom type.
  ///
  /// #### Returns
  /// `List<String>` - List of type names this custom type depends on
  List<String> get dependencyNames => const <String>[];
}

/// Base class for all typed values (instances of types).
@immutable
abstract class TypedValue {
  /// Creates typed value.
  ///
  /// #### Parameters
  /// - `type` - ABI type of this value
  const TypedValue(this.type);

  /// Value type.
  final AbiType type;

  /// Returns class name for runtime type identification.
  ///
  /// #### Returns
  /// `String` - Class name (e.g., 'U32Value', 'AddressValue')
  String get className => 'TypedValue';

  /// Returns full class hierarchy from most specific to most general.
  ///
  /// #### Returns
  /// List of class names
  List<String> get classHierarchy => <String>[className];

  /// Checks if instance is exactly the specified class.
  ///
  /// #### Parameters
  /// - `name` - Class name to check
  ///
  /// #### Returns
  /// `bool` - true if exact match
  bool hasExactClass(String name) => className == name;

  /// Checks if instance is or extends the specified class.
  ///
  /// #### Parameters
  /// - `name` - Class name to check
  ///
  /// #### Returns
  /// `bool` - true if in hierarchy
  bool hasClassOrSuperclass(String name) => classHierarchy.contains(name);

  /// Returns native Dart representation of this value.
  ///
  /// #### Returns
  /// `dynamic` - Native Dart value (int, String, List, etc.)
  dynamic get nativeValue;

  /// Returns native value (alias for nativeValue).
  ///
  /// #### Returns
  /// `dynamic` - Native Dart value
  dynamic valueOf() => nativeValue;

  /// Converts to byte representation.
  ///
  /// #### Returns
  /// `List<int>` - Byte array representation
  List<int> toBytes();

  /// Converts to bytes using top-level encoding (variable-width).
  ///
  /// #### Returns
  /// `List<int>` - Byte array representation
  List<int> toTopBytes() => toBytes();

  /// Converts to hex string using nested encoding (fixed-width).
  ///
  /// #### Returns
  /// `String` - Hex string (e.g., '0000002a')
  String toHex() => HexUtils.bytesToHex(toBytes());

  /// Converts to hex string using top-level encoding (variable-width).
  ///
  /// #### Returns
  /// `String` - Hex string
  String toTopHex() => HexUtils.bytesToHex(toTopBytes());

  /// Checks value equality.
  ///
  /// #### Parameters
  /// - `other` - Value to compare
  ///
  /// #### Returns
  /// `bool` - true if values are equal
  bool valueEquals(TypedValue other) {
    if (!type.equals(other.type)) {
      return false;
    }
    return nativeValue == other.nativeValue;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypedValue &&
          runtimeType == other.runtimeType &&
          valueEquals(other);

  @override
  int get hashCode => Object.hash(type, nativeValue);

  @override
  String toString() => '$className{type: ${type.name}, value: $nativeValue}';
}
