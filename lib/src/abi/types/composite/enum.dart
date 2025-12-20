import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../utils/helpers.dart';
import '../../core/type_system.dart';

/// Variant definition for enum types with name, discriminant, and optional fields.
///
/// Defines a single variant in an enum type, similar to Rust enum
/// variants or TypeScript discriminated unions.
@immutable
final class EnumVariantDefinition {
  /// Creates an enum variant definition.
  ///
  /// #### Parameters
  /// - `name` - Variant name (must be unique within enum)
  /// - `discriminant` - Numeric identifier (must be unique within enum)
  /// - `fields` - Optional list of field types for this variant
  ///
  /// #### Example
  /// ```dart
  /// final variant = EnumVariantDefinition(
  ///   name: 'Transfer',
  ///   discriminant: 2,
  ///   fields: [AddressType.type, U64Type.type],
  /// );
  /// print(variant.hasFields); // true
  /// print(variant.fieldCount); // 2
  /// ```
  const EnumVariantDefinition({
    required this.name,
    required this.discriminant,
    this.fields,
  });

  /// Name of this variant.
  final String name;

  /// Discriminant (numeric value) for this variant.
  final int discriminant;

  /// Optional fields for this variant.
  final List<AbiType>? fields;

  /// Whether this variant has associated fields.
  bool get hasFields => fields != null && fields!.isNotEmpty;

  /// Number of fields in this variant.
  int get fieldCount => fields?.length ?? 0;

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> result = <String, dynamic>{
      'name': name,
      'discriminant': discriminant,
    };
    if (hasFields) {
      result['fields'] = fields!.map((AbiType f) => f.toMap()).toList();
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnumVariantDefinition &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          discriminant == other.discriminant;

  @override
  int get hashCode => Object.hash(name, discriminant);

  @override
  String toString() {
    if (hasFields) {
      final String fieldTypes = fields!
          .map((AbiType f) => f.fullyQualifiedName)
          .join(', ');
      return '$name($fieldTypes) = $discriminant';
    }
    return '$name = $discriminant';
  }
}

/// Enum type with named variants and discriminants.
///
/// Represents smart contract enum types with multiple variants, each
/// with a unique discriminant. Variants can have optional associated data fields.
///
/// #### Example
/// ```dart
/// // Result enum: Ok | Error(code)
/// final resultType = EnumType(
///   name: 'Result',
///   variants: [
///     EnumVariantDefinition(name: 'Ok', discriminant: 0),
///     EnumVariantDefinition(
///       name: 'Error',
///       discriminant: 1,
///       fields: [U32Type.type],
///     ),
///   ],
/// );
///
/// // Create Ok variant
/// final ok = resultType.createValue('Ok');
///
/// // Create Error variant with code
/// final error = resultType.createValue({
///   'variant': 'Error',
///   'fields': [404],
/// });
/// ```
@immutable
final class EnumType extends CustomType {
  /// Creates an Enum type with variants.
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
  /// final statusEnum = EnumType(
  ///   name: 'Status',
  ///   variants: [
  ///     EnumVariantDefinition(name: 'Pending', discriminant: 0),
  ///     EnumVariantDefinition(name: 'Active', discriminant: 1),
  ///     EnumVariantDefinition(name: 'Completed', discriminant: 2),
  ///   ],
  /// );
  /// ```
  EnumType({required super.name, required this.variants, super.metadata})
    : super(cardinality: TypeCardinalityExtension.singular()) {
    if (variants.isEmpty) {
      throw ArgumentError('Enum must have at least one variant');
    }

    final Set<String> names = variants
        .map((EnumVariantDefinition v) => v.name)
        .toSet();
    if (names.length != variants.length) {
      throw ArgumentError('Enum variant names must be unique');
    }

    final Set<int> discriminants = variants
        .map((EnumVariantDefinition v) => v.discriminant)
        .toSet();
    if (discriminants.length != variants.length) {
      throw ArgumentError('Enum discriminants must be unique');
    }
  }

  /// Variant definitions for this enum.
  final List<EnumVariantDefinition> variants;

  @override
  String get className => 'EnumType';

  static const List<String> _classHierarchy = [
    'EnumType',
    'CustomType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  String get fullyQualifiedName {
    final String variantNames = variants
        .map((EnumVariantDefinition v) => v.name)
        .join(' | ');
    return '$name { $variantNames }';
  }

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'type': 'enum',
    'variants': variants.map((EnumVariantDefinition v) => v.toMap()).toList(),
  };

  /// Returns the variant definition with the given name.
  ///
  /// #### Parameters
  /// - `name` - Variant name to search for
  ///
  /// #### Returns
  /// `EnumVariantDefinition` - Instance matching the name
  ///
  /// #### Throws
  /// - `ArgumentError` - If variant not found
  ///
  /// #### Example
  /// ```dart
  /// final statusEnum = EnumType(name: 'Status', variants: [
  ///   EnumVariantDefinition(name: 'Active', discriminant: 0),
  /// ]);
  /// final variant = statusEnum.getVariant('Active');
  /// print(variant.discriminant); // 0
  /// ```
  EnumVariantDefinition getVariant(String name) {
    try {
      return variants.firstWhere((EnumVariantDefinition v) => v.name == name);
    } catch (e) {
      throw ArgumentError('Variant not found: $name');
    }
  }

  /// Returns the variant definition with the given discriminant.
  EnumVariantDefinition getVariantByDiscriminant(int discriminant) {
    try {
      return variants.firstWhere(
        (EnumVariantDefinition v) => v.discriminant == discriminant,
      );
    } catch (e) {
      throw ArgumentError('Variant with discriminant $discriminant not found');
    }
  }

  /// Tries to get the variant definition with the given discriminant.
  ///
  /// Returns null if no variant with the given discriminant exists.
  EnumVariantDefinition? tryGetVariantByDiscriminant(int discriminant) {
    for (final variant in variants) {
      if (variant.discriminant == discriminant) {
        return variant;
      }
    }
    return null;
  }

  /// Tries to get the variant definition with the given name.
  EnumVariantDefinition? tryGetVariant(String name) {
    try {
      return variants.firstWhere((EnumVariantDefinition v) => v.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Number of variants in this enum.
  int get variantCount => variants.length;

  /// Creates an EnumValue from native Dart value.
  ///
  /// #### Parameters
  /// - `nativeValue` - String (variant name) or Map with 'variant' and optional 'fields'
  ///
  /// #### Returns
  /// `TypedValue` - EnumValue instance with selected variant
  ///
  /// #### Throws
  /// - `ArgumentError` - If nativeValue format is invalid
  /// - `ArgumentError` - If variant not found
  /// - `ArgumentError` - If field count mismatch
  ///
  /// #### Example
  /// ```dart
  /// // Simple variant
  /// final ok = enumType.createValue('Ok');
  ///
  /// // Variant with fields
  /// final error = enumType.createValue({
  ///   'variant': 'Error',
  ///   'fields': [404, 'Not Found'],
  /// });
  /// ```
  @override
  TypedValue createValue(dynamic nativeValue) {
    if (nativeValue is String) {
      final EnumVariantDefinition variant = getVariant(nativeValue);
      if (variant.hasFields) {
        throw ArgumentError('Variant "$nativeValue" requires field values');
      }
      return EnumValue(this, variant, const <TypedValue>[]);
    }

    if (nativeValue is Map<String, dynamic>) {
      final String? variantName = optionalAs<String>(
        nativeValue['variant'],
        'variant',
      );
      if (variantName == null) {
        throw ArgumentError('Map must contain "variant" key');
      }

      final EnumVariantDefinition variant = getVariant(variantName);
      final List<dynamic> fieldValues =
          (optionalAs<List<dynamic>>(nativeValue['fields'], 'fields') ??
          const <dynamic>[]);

      if (variant.hasFields) {
        if (fieldValues.length != variant.fieldCount) {
          throw ArgumentError(
            'Variant "$variantName" expects ${variant.fieldCount} fields, '
            'got ${fieldValues.length}',
          );
        }

        final List<TypedValue> typedFields = <TypedValue>[];
        for (int i = 0; i < fieldValues.length; i++) {
          final dynamic fieldValue = fieldValues[i];
          if (fieldValue is TypedValue) {
            typedFields.add(fieldValue);
          } else {
            typedFields.add(variant.fields![i].createValue(fieldValue));
          }
        }
        return EnumValue(this, variant, typedFields);
      }

      return EnumValue(this, variant, const <TypedValue>[]);
    }

    throw ArgumentError.value(
      nativeValue,
      'nativeValue',
      'Enum requires String (variant name) or Map with "variant" and optional "fields"',
    );
  }
}

/// Enum value representing a selected variant with optional fields.
///
/// Holds the selected variant and its associated field values. Provides
/// type-safe access to variant properties and fields.
///
/// #### Example
/// ```dart
/// final enumType = EnumType(
///   name: 'Action',
///   variants: [
///     EnumVariantDefinition(name: 'None', discriminant: 0),
///     EnumVariantDefinition(
///       name: 'Transfer',
///       discriminant: 1,
///       fields: [AddressType.type, U64Type.type],
///     ),
///   ],
/// );
///
/// // Create Transfer variant
/// final transfer = enumType.createValue({
///   'variant': 'Transfer',
///   'fields': ['erd1...', 1000],
/// }) as EnumValue;
///
/// print(transfer.variantName); // Transfer
/// print(transfer.discriminant); // 1
/// print(transfer.hasFields); // true
/// print(transfer.getField(1).nativeValue); // 1000
/// ```
@immutable
final class EnumValue extends TypedValue {
  /// Creates an Enum value.
  ///
  /// #### Parameters
  /// - `type` - EnumType defining available variants
  /// - `variant` - Selected variant definition
  /// - `fields` - List of field values for this variant
  ///
  /// #### Throws
  /// - `ArgumentError` - If variant doesn't belong to enum type
  /// - `ArgumentError` - If field count mismatch
  /// - `ArgumentError` - If field types incompatible
  ///
  /// #### Example
  /// ```dart
  /// final variant = enumType.getVariant('Error');
  /// final value = EnumValue(
  ///   enumType,
  ///   variant,
  ///   [U32Value(500)],
  /// );
  /// ```
  EnumValue(EnumType type, this.variant, List<TypedValue> fields)
    : fields = List<TypedValue>.unmodifiable(fields),
      super(type) {
    if (!type.variants.contains(variant)) {
      throw ArgumentError('Variant does not belong to enum type $type');
    }
    if (variant.hasFields && fields.length != variant.fieldCount) {
      throw ArgumentError(
        'Variant "${variant.name}" expects ${variant.fieldCount} fields, '
        'got ${fields.length}',
      );
    }
    if (variant.hasFields) {
      for (int i = 0; i < fields.length; i++) {
        if (!variant.fields![i].isAssignableFrom(fields[i].type)) {
          throw ArgumentError(
            'Field $i has type ${fields[i].type.fullyQualifiedName}, '
            'but expected ${variant.fields![i].fullyQualifiedName}',
          );
        }
      }
    }
  }

  /// Selected variant.
  final EnumVariantDefinition variant;

  /// Field values for this variant (if any).
  final List<TypedValue> fields;

  @override
  EnumType get type => super.type as EnumType;

  @override
  String get className => 'EnumValue';

  static const List<String> _classHierarchy = ['EnumValue', 'TypedValue'];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  dynamic get nativeValue {
    if (!variant.hasFields) {
      return variant.name;
    }
    return <String, Object>{
      'variant': variant.name,
      'fields': fields.map((TypedValue f) => f.nativeValue).toList(),
    };
  }

  /// Name of the selected variant.
  String get variantName => variant.name;

  /// Discriminant of the selected variant.
  int get discriminant => variant.discriminant;

  /// Whether this variant has fields.
  bool get hasFields => variant.hasFields;

  /// Number of fields in this variant.
  int get fieldCount => fields.length;

  /// Returns the field at the given index.
  TypedValue getField(int index) {
    if (index < 0 || index >= fields.length) {
      throw RangeError.index(index, fields, 'index', null, fields.length);
    }
    return fields[index];
  }

  /// Encodes enum to bytes: [discriminant (1 byte), ...field bytes].
  ///
  /// #### Returns
  /// Byte array with discriminant followed by encoded fields
  ///
  /// #### Example
  /// ```dart
  /// final ok = enumType.createValue('Ok'); // discriminant 0
  /// print(ok.toBytes()); // [0]
  ///
  /// final error = enumType.createValue({
  ///   'variant': 'Error',
  ///   'fields': [404],
  /// }); // discriminant 1
  /// print(error.toBytes()); // [1, 0, 0, 1, 148] (1 byte + u32)
  /// ```
  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() {
    final BytesBuilder builder = BytesBuilder(copy: false);

    builder.addByte(discriminant);

    for (final TypedValue field in fields) {
      builder.add(field.toBytes());
    }

    return builder.takeBytes();
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
  /// final value = enumType.createValue('Active');
  /// print(value.isVariant('Active')); // true
  /// print(value.isVariant('Pending')); // false
  ///
  /// // Use for type-safe variant checking
  /// if (value.isVariant('Error')) {
  ///   final errorCode = value.getField(0).nativeValue;
  /// }
  /// ```
  bool isVariant(String variantName) => variant.name == variantName;

  @override
  String toString() {
    if (!hasFields) {
      return '${type.name}::${variant.name}';
    }
    final String fieldsStr = fields.join(', ');
    return '${type.name}::${variant.name}($fieldsStr)';
  }
}
