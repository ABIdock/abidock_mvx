import 'dart:convert';

import 'package:meta/meta.dart';

import '../../core/type_system.dart';

/// Variant definition for explicit enum types with arbitrary discriminants.
///
/// Defines a variant in an explicit enum where discriminant values
/// are explicitly specified (not auto-generated). Used when discriminants must
/// match specific numeric values (e.g., matching a protocol or API contract).
@immutable
final class ExplicitEnumVariantDefinition {
  /// Creates an explicit enum variant definition.
  ///
  /// #### Parameters
  /// - `name` - Variant name (must be unique within enum)
  /// - `discriminant` - Explicit numeric identifier (can be any integer, must be unique)
  ///
  /// #### Example
  /// ```dart
  /// final variant = ExplicitEnumVariantDefinition(
  ///   name: 'Success',
  ///   discriminant: 1000,
  /// );
  /// print(variant.discriminant); // 1000
  /// ```
  const ExplicitEnumVariantDefinition({
    required this.name,
    required this.discriminant,
  });

  /// Name of this variant.
  final String name;

  /// Explicit discriminant value (can be any integer).
  final int discriminant;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExplicitEnumVariantDefinition &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          discriminant == other.discriminant;

  @override
  int get hashCode => Object.hash(name, discriminant);

  @override
  String toString() => '$name = $discriminant';
}

/// Explicit enum type with arbitrary discriminant values.
///
/// Represents enum types where discriminants are explicitly defined
/// (unlike regular EnumType which uses sequential discriminants). Useful when
/// discriminants must match external contracts or protocols.
///
/// #### Example
/// ```dart
/// // HTTP status enum with explicit codes
/// final statusEnum = ExplicitEnumType(
///   name: 'HttpStatus',
///   variants: [
///     ExplicitEnumVariantDefinition(name: 'Ok', discriminant: 200),
///     ExplicitEnumVariantDefinition(name: 'NotFound', discriminant: 404),
///     ExplicitEnumVariantDefinition(name: 'ServerError', discriminant: 500),
///   ],
/// );
///
/// // Create by name
/// final ok = statusEnum.createValue('Ok');
///
/// // Create by discriminant
/// final notFound = statusEnum.createValue(404);
/// ```
@immutable
final class ExplicitEnumType extends CustomType {
  /// Creates an ExplicitEnum type with variants.
  ///
  /// #### Parameters
  /// - `name` - Enum type name
  /// - `variants` - List of variant definitions (must be non-empty)
  /// - `metadata` - Optional metadata
  ///
  /// #### Throws
  /// - `ArgumentError` - If variants is empty
  /// - `ArgumentError` - If variant names are not unique
  /// - `ArgumentError` - If discriminants are not unique
  ///
  /// #### Example
  /// ```dart
  /// final errorEnum = ExplicitEnumType(
  ///   name: 'ErrorCode',
  ///   variants: [
  ///     ExplicitEnumVariantDefinition(name: 'None', discriminant: 0),
  ///     ExplicitEnumVariantDefinition(name: 'Auth', discriminant: 1001),
  ///     ExplicitEnumVariantDefinition(name: 'Network', discriminant: 2001),
  ///   ],
  /// );
  /// ```
  /// Looks up `name` in the supplied registry and returns it as an
  /// `ExplicitEnumType`, so an explicit-enum type can be built from a bare
  /// type name plus a registry.
  ///
  /// #### Parameters
  /// - `name` - The explicit-enum type name registered in `registry`
  /// - `registry` - Type registry (e.g. an `AbiTypeFactory`) implementing
  ///   `lookupType(String)`
  ///
  /// #### Returns
  /// `ExplicitEnumType` - The resolved type
  ///
  /// #### Throws
  /// - `ArgumentError` - If `name` is not registered or is not an ExplicitEnum
  static ExplicitEnumType fromRegistry(
    String name,
    ExplicitEnumTypeRegistry registry,
  ) {
    final dynamic resolved = registry.lookupType(name);
    if (resolved is ExplicitEnumType) {
      return resolved;
    }
    throw ArgumentError.value(
      name,
      'name',
      'No ExplicitEnumType registered for "$name" '
          '(got ${resolved?.runtimeType})',
    );
  }

  ExplicitEnumType({
    required super.name,
    required this.variants,
    super.metadata,
  }) : super(cardinality: TypeCardinalityExtension.singular()) {
    if (variants.isEmpty) {
      throw ArgumentError('ExplicitEnum must have at least one variant');
    }
    _validateUniqueness();
  }

  /// Creates an empty placeholder explicit-enum used during two-phase ABI
  /// dependency resolution. Real variants are populated in the second pass
  /// before any encode/decode operation runs.
  ///
  /// #### Parameters
  /// - `name` - Custom type name registered in Phase 1.
  ExplicitEnumType.placeholder(String name)
    : variants = const <ExplicitEnumVariantDefinition>[],
      super(name: name, cardinality: TypeCardinalityExtension.singular());

  void _validateUniqueness() {
    final Set<String> names = variants
        .map((ExplicitEnumVariantDefinition v) => v.name)
        .toSet();
    if (names.length != variants.length) {
      throw ArgumentError('ExplicitEnum variant names must be unique');
    }
    final Set<int> discriminants = variants
        .map((ExplicitEnumVariantDefinition v) => v.discriminant)
        .toSet();
    if (discriminants.length != variants.length) {
      throw ArgumentError('ExplicitEnum discriminants must be unique');
    }
  }

  /// Variant definitions for this explicit enum.
  final List<ExplicitEnumVariantDefinition> variants;

  @override
  String get className => 'ExplicitEnumType';

  static const List<String> _classHierarchy = [
    'ExplicitEnumType',
    'CustomType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  String get fullyQualifiedName {
    final String variantDefs = variants
        .map(
          (ExplicitEnumVariantDefinition v) => '${v.name} = ${v.discriminant}',
        )
        .join(', ');
    return '$name { $variantDefs }';
  }

  /// Returns the variant definition with the given name.
  ///
  /// #### Parameters
  /// - `name` - Variant name to search for
  ///
  /// #### Returns
  /// `ExplicitEnumVariantDefinition` - Instance matching the name
  ///
  /// #### Throws
  /// - `ArgumentError` - If variant not found
  ///
  /// #### Example
  /// ```dart
  /// final variant = statusEnum.getVariant('Ok');
  /// print(variant.discriminant); // 200
  /// ```
  ExplicitEnumVariantDefinition getVariant(String name) {
    try {
      return variants.firstWhere(
        (ExplicitEnumVariantDefinition v) => v.name == name,
      );
    } catch (e) {
      throw ArgumentError('Variant not found: $name');
    }
  }

  /// Returns the variant definition with the given discriminant.
  ExplicitEnumVariantDefinition getVariantByDiscriminant(int discriminant) {
    try {
      return variants.firstWhere(
        (ExplicitEnumVariantDefinition v) => v.discriminant == discriminant,
      );
    } catch (e) {
      throw ArgumentError('Variant with discriminant $discriminant not found');
    }
  }

  /// Tries to get the variant definition with the given name.
  ExplicitEnumVariantDefinition? tryGetVariant(String name) {
    try {
      return variants.firstWhere(
        (ExplicitEnumVariantDefinition v) => v.name == name,
      );
    } catch (e) {
      return null;
    }
  }

  /// Number of variants in this enum.
  int get variantCount => variants.length;

  /// Creates an ExplicitEnumValue from native Dart value.
  ///
  /// #### Parameters
  /// - `nativeValue` - String (variant name) or int (discriminant value)
  ///
  /// #### Returns
  /// `TypedValue` - ExplicitEnumValue instance with selected variant
  ///
  /// #### Throws
  /// - `ArgumentError` - If nativeValue is not String or int
  /// - `ArgumentError` - If variant not found
  ///
  /// #### Example
  /// ```dart
  /// // Create by name
  /// final ok = statusEnum.createValue('Ok');
  /// print(ok.discriminant); // 200
  ///
  /// // Create by discriminant
  /// final notFound = statusEnum.createValue(404);
  /// print(notFound.variantName); // NotFound
  /// ```
  @override
  TypedValue createValue(dynamic nativeValue) {
    if (nativeValue is String) {
      final ExplicitEnumVariantDefinition variant = getVariant(nativeValue);
      return ExplicitEnumValue(this, variant);
    }

    if (nativeValue is int) {
      final ExplicitEnumVariantDefinition variant = getVariantByDiscriminant(
        nativeValue,
      );
      return ExplicitEnumValue(this, variant);
    }

    throw ArgumentError.value(
      nativeValue,
      'nativeValue',
      'ExplicitEnum requires String (variant name) or int (discriminant)',
    );
  }
}

/// ExplicitEnum value representing a selected variant.
///
/// Holds the selected variant for an explicit enum. Unlike regular
/// EnumValue, this type has no associated fields - only the discriminant.
///
/// #### Example
/// ```dart
/// final statusEnum = ExplicitEnumType(
///   name: 'Status',
///   variants: [
///     ExplicitEnumVariantDefinition(name: 'Active', discriminant: 100),
///     ExplicitEnumVariantDefinition(name: 'Inactive', discriminant: 200),
///   ],
/// );
///
/// final active = statusEnum.createValue('Active') as ExplicitEnumValue;
/// print(active.variantName); // Active
/// print(active.discriminant); // 100
/// print(active.isVariant('Active')); // true
/// ```
@immutable
final class ExplicitEnumValue extends TypedValue {
  /// Creates an ExplicitEnum value.
  ///
  /// #### Parameters
  /// - `type` - ExplicitEnumType defining available variants
  /// - `variant` - Selected variant definition
  ///
  /// #### Throws
  /// - `ArgumentError` - If variant doesn't belong to enum type
  ///
  /// #### Example
  /// ```dart
  /// final variant = statusEnum.getVariant('Active');
  /// final value = ExplicitEnumValue(statusEnum, variant);
  /// ```
  ExplicitEnumValue(ExplicitEnumType type, this.variant) : super(type) {
    if (!type.variants.contains(variant)) {
      throw ArgumentError('Variant does not belong to enum type $type');
    }
  }

  /// Selected variant.
  final ExplicitEnumVariantDefinition variant;

  @override
  ExplicitEnumType get type => super.type as ExplicitEnumType;

  @override
  String get className => 'ExplicitEnumValue';

  static const List<String> _classHierarchy = [
    'ExplicitEnumValue',
    'TypedValue',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  String get nativeValue => variant.name;

  /// Name of the selected variant.
  String get variantName => variant.name;

  /// Discriminant of the selected variant.
  int get discriminant => variant.discriminant;

  /// Encodes the variant NAME as UTF-8 — the explicit-enum top-level wire form.
  ///
  /// An `explicit-enum` puts the raw UTF-8 bytes of the variant name on the
  /// wire — never a discriminant. `OperationCompletionStatus`
  /// (`completed` / `interrupted`) is the only such type in practice. ABI JSON
  /// for `explicit-enum` carries no `discriminant` key at all; [discriminant]
  /// here is synthesised from the variant's array index and has no meaning on
  /// the wire.
  ///
  /// #### Returns
  /// `List<int>` - UTF-8 bytes of [variantName]
  ///
  /// #### Example
  /// ```dart
  /// final status = statusEnum.createValue('interrupted');
  /// final bytes = status.toBytes();
  /// print(bytes); // [105, 110, 116, 101, 114, 114, 117, 112, 116, 101, 100]
  /// ```
  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() {
    return utf8.encode(variantName);
  }

  /// Checks if this enum value is the specified variant.
  ///
  /// #### Parameters
  /// - `variantName` - Name of variant to check against
  ///
  /// #### Returns
  /// `bool` - true if current variant matches, false otherwise
  ///
  /// #### Example
  /// ```dart
  /// final value = statusEnum.createValue('Ok');
  /// print(value.isVariant('Ok')); // true
  /// print(value.isVariant('NotFound')); // false
  ///
  /// // Use for type-safe variant checking
  /// if (value.isVariant('ServerError')) {
  ///   print('Server error occurred');
  /// }
  /// ```
  bool isVariant(String variantName) => variant.name == variantName;

  @override
  String toString() => '${type.name}::${variant.name}';
}

/// Minimal registry interface for [ExplicitEnumType.fromRegistry].
///
/// Implemented by anything that exposes registered ABI types by name
/// (e.g. `AbiTypeFactory.getCustomType` via a thin adapter).
abstract class ExplicitEnumTypeRegistry {
  /// Returns the registered type with `name`, or `null` if absent.
  Object? lookupType(String name);
}
