import '../../core/type_system.dart';
import 'enum.dart';

/// Builder for creating EnumType instances with discriminated variants.
/// Provides a chainable API for building enum types with variants
/// that can have fields.
///
/// #### Example
/// ```dart
/// final statusEnum = EnumBuilder('Status')
///   .variant('Active', 0)
///   .variant('Inactive', 1)
///   .variantWithFields('Error', 2, [U32Type.type, StringType.type])
///   .build();
///
/// // Create values
/// final active = statusEnum.createValue('Active');
/// final error = statusEnum.createValue({
///   'variant': 'Error',
///   'fields': [404, 'Not Found'],
/// });
/// ```
class EnumBuilder {
  /// Creates an enum builder with the given name.
  ///
  /// #### Parameters
  /// - `name` - Name of the enum type
  /// - `metadata` - Optional metadata dictionary
  EnumBuilder(this._name, {Map<String, dynamic>? metadata})
    : _metadata = metadata,
      _variants = [],
      _variantNames = {},
      _discriminants = {};

  final String _name;
  final Map<String, dynamic>? _metadata;
  final List<EnumVariantDefinition> _variants;
  final Set<String> _variantNames;
  final Set<int> _discriminants;

  /// Adds a simple variant without fields.
  ///
  /// #### Parameters
  /// - `name` - Variant name (must be unique within enum)
  /// - `discriminant` - Variant discriminant value (must be unique)
  ///
  /// #### Returns
  /// `EnumBuilder` - This builder for method chaining
  ///
  /// #### Throws
  /// - `ArgumentError` if variant name is empty
  /// - `ArgumentError` if variant name is duplicate
  /// - `ArgumentError` if discriminant is duplicate
  ///
  /// #### Example
  /// ```dart
  /// builder
  ///   .variant('Active', 0)
  ///   .variant('Inactive', 1)
  ///   .variant('Pending', 2);
  /// ```
  EnumBuilder variant(String name, int discriminant) {
    _validateVariant(name, discriminant);

    _variantNames.add(name);
    _discriminants.add(discriminant);
    _variants.add(
      EnumVariantDefinition(name: name, discriminant: discriminant),
    );

    return this;
  }

  /// Adds a variant with associated data fields.
  ///
  /// #### Parameters
  /// - `name` - Variant name (must be unique within enum)
  /// - `discriminant` - Variant discriminant value (must be unique)
  /// - `fields` - List of ABI types for this variant's fields
  ///
  /// #### Returns
  /// `EnumBuilder` - This builder for method chaining
  ///
  /// #### Throws
  /// - `ArgumentError` if variant name is empty
  /// - `ArgumentError` if variant name duplicate
  /// - `ArgumentError` if discriminant is duplicate
  /// - `ArgumentError` if fields list is empty
  ///
  /// #### Example
  /// ```dart
  /// builder.variantWithFields('Error', 1, [
  ///   U32Type.type,
  ///   StringType.type,
  /// ]);
  /// ```
  EnumBuilder variantWithFields(
    String name,
    int discriminant,
    List<AbiType> fields,
  ) {
    _validateVariant(name, discriminant);

    if (fields.isEmpty) {
      throw ArgumentError(
        'Variant with fields "$name" must have at least one field. '
        'Use .variant() for variants without fields.',
      );
    }

    _variantNames.add(name);
    _discriminants.add(discriminant);
    _variants.add(
      EnumVariantDefinition(
        name: name,
        discriminant: discriminant,
        fields: fields,
      ),
    );

    return this;
  }

  /// Validates variant name and discriminant.
  void _validateVariant(String name, int discriminant) {
    if (name.isEmpty) {
      throw ArgumentError('Variant name cannot be empty');
    }

    if (_variantNames.contains(name)) {
      throw ArgumentError(
        'Duplicate variant name "$name" in enum "$_name". '
        'Variant names must be unique.',
      );
    }

    if (_discriminants.contains(discriminant)) {
      throw ArgumentError(
        'Duplicate discriminant $discriminant in enum "$_name". '
        'Each variant must have a unique discriminant.',
      );
    }
  }

  /// Builds the immutable EnumType.
  ///
  /// #### Returns
  /// EnumType with all added variants
  ///
  /// #### Throws
  /// - `ArgumentError` if no variants have been added
  ///
  /// #### Example
  /// ```dart
  /// final enumType = builder.build();
  /// print(enumType.name);  // 'Status'
  /// print(enumType.variants.length);  // 3
  /// ```
  EnumType build() {
    if (_variants.isEmpty) {
      throw ArgumentError(
        'Cannot build empty enum "$_name". '
        'Add at least one variant using .variant()',
      );
    }

    return EnumType(
      name: _name,
      variants: List.unmodifiable(_variants),
      metadata: _metadata,
    );
  }

  /// Returns the current number of variants.
  int get variantCount => _variants.length;

  /// Returns whether any variants have been added.
  bool get isEmpty => _variants.isEmpty;

  /// Returns whether variants have been added.
  bool get isNotEmpty => _variants.isNotEmpty;

  @override
  String toString() => 'EnumBuilder($_name, ${_variants.length} variants)';
}

/// Extension methods for common enum patterns.
extension EnumBuilderExtensions on EnumBuilder {
  /// Adds multiple simple variants at once.
  ///
  /// #### Parameters
  /// - `variants` - Map of variant name � discriminant
  ///
  /// #### Returns
  /// `EnumBuilder` - This builder for method chaining
  ///
  /// #### Example
  /// ```dart
  /// builder.variants({
  ///   'Red': 0,
  ///   'Green': 1,
  ///   'Blue': 2,
  /// });
  /// ```
  EnumBuilder variants(Map<String, int> variants) {
    for (final entry in variants.entries) {
      variant(entry.key, entry.value);
    }
    return this;
  }

  /// Creates a Result enum with Ok and Error variants.
  ///
  /// #### Parameters
  /// - `okFields` - Optional types for Ok variant fields
  /// - `errorFields` - Optional types for Error variant fields
  ///
  /// #### Returns
  /// `EnumType` - Built EnumType
  ///
  /// #### Example
  /// ```dart
  /// // Simple Result<T, E>
  /// final result = EnumBuilder('Result').resultEnum(
  ///   okFields: [U32Type.type],
  ///   errorFields: [StringType.type],
  /// );
  /// ```
  EnumType resultEnum({List<AbiType>? okFields, List<AbiType>? errorFields}) {
    if (okFields != null && okFields.isNotEmpty) {
      variantWithFields('Ok', 0, okFields);
    } else {
      variant('Ok', 0);
    }

    if (errorFields != null && errorFields.isNotEmpty) {
      variantWithFields('Error', 1, errorFields);
    } else {
      variant('Error', 1);
    }

    return build();
  }

  /// Creates an Option enum with None and Some variants.
  ///
  /// #### Parameters
  /// - `someFields` - Types for Some variant fields (must have at least one)
  ///
  /// #### Returns
  /// `EnumType` - Built EnumType
  ///
  /// #### Example
  /// ```dart
  /// // Option<T>
  /// final option = EnumBuilder('Option').optionEnum(
  ///   someFields: [U32Type.type],
  /// );
  /// ```
  EnumType optionEnum({required List<AbiType> someFields}) {
    if (someFields.isEmpty) {
      throw ArgumentError('Option Some variant must have at least one field');
    }

    variant('None', 0);
    variantWithFields('Some', 1, someFields);

    return build();
  }
}
