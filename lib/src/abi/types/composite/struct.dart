import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../core/type_system.dart';
import 'fields.dart';

/// Struct type with named fields and specific types.
///
/// Represents smart contract struct types with named fields
///  Each field has a name and type.
@immutable
final class StructType extends CustomType {
  /// Creates a Struct type with name and field definitions.
  ///
  /// #### Parameters
  /// - `name` - Struct type name
  /// - `fieldDefinitions` - List of field definitions (must be non-empty)
  /// - `metadata` - Optional metadata
  ///
  /// #### Throws
  /// - `ArgumentError` - If fieldDefinitions is empty
  /// - `ArgumentError` - If field names are not unique
  ///
  /// #### Example
  /// ```dart
  /// final pointType = StructType(
  ///   name: 'Point',
  ///   fieldDefinitions: [
  ///     FieldDefinition(name: 'x', type: U32Type.type),
  ///     FieldDefinition(name: 'y', type: U32Type.type),
  ///   ],
  /// );
  /// ```
  StructType({
    required super.name,
    required this.fieldDefinitions,
    super.metadata,
  }) : super(cardinality: TypeCardinalityExtension.singular()) {
    final Set<String> names = fieldDefinitions
        .map((FieldDefinition f) => f.name)
        .toSet();
    if (names.length != fieldDefinitions.length) {
      throw ArgumentError('Struct field names must be unique');
    }
  }

  /// Field definitions for this struct.
  final List<FieldDefinition> fieldDefinitions;

  @override
  String get className => 'StructType';

  static const List<String> _classHierarchy = [
    'StructType',
    'CustomType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  String get fullyQualifiedName {
    final String fields = fieldDefinitions
        .map((FieldDefinition f) => '${f.name}: ${f.type.fullyQualifiedName}')
        .join(', ');
    return '$name { $fields }';
  }

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'type': 'struct',
    'fields': fieldDefinitions.map((FieldDefinition f) => f.toMap()).toList(),
  };

  /// Returns the field definition with the given name.
  ///
  /// #### Parameters
  /// - `name` - Field name to search for
  ///
  /// #### Returns
  /// `FieldDefinition` - Instance matching the name
  ///
  /// #### Throws
  /// - `ArgumentError` - If field not found
  ///
  /// #### Example
  /// ```dart
  /// final pointType = StructType(name: 'Point', fieldDefinitions: [
  ///   FieldDefinition(name: 'x', type: U32Type.type),
  /// ]);
  /// final field = pointType.getFieldDefinition('x');
  /// print(field.type.name); // U32
  /// ```
  FieldDefinition getFieldDefinition(String name) {
    try {
      return fieldDefinitions.firstWhere((FieldDefinition f) => f.name == name);
    } on StateError {
      throw ArgumentError('Field not found: $name');
    }
  }

  /// Tries to get the field definition with the given name.
  FieldDefinition? tryGetFieldDefinition(String name) {
    try {
      return fieldDefinitions.firstWhere((FieldDefinition f) => f.name == name);
    } on StateError {
      return null;
    }
  }

  /// Creates a StructValue from native Dart value.
  ///
  /// #### Parameters
  /// - `nativeValue` - `Map<String, dynamic>` with field names/values or List with values in field order
  ///
  /// #### Returns
  /// `StructValue` - Instance with typed fields
  ///
  /// #### Throws
  /// - `ArgumentError` - If nativeValue is not Map or List
  ///
  /// #### Example
  /// ```dart
  /// // From map (preferred)
  /// final user = userType.createValue({
  ///   'name': 'Bob',
  ///   'age': 25,
  /// });
  ///
  /// // From list (field order must match)
  /// final user2 = userType.createValue(['Charlie', 35]);
  /// ```
  @override
  TypedValue createValue(dynamic nativeValue) {
    if (nativeValue is Map<String, dynamic>) {
      final Fields fields = Fields.fromMap(nativeValue, fieldDefinitions);
      return StructValue(this, fields);
    }

    if (nativeValue is List) {
      final Fields fields = Fields.fromList(nativeValue, fieldDefinitions);
      return StructValue(this, fields);
    }

    throw ArgumentError.value(
      nativeValue,
      'nativeValue',
      'Struct requires Map<String, dynamic> or List value',
    );
  }
}

/// Struct value with named fields and actual values.
///
/// Holds field values for a struct instance. Provides access by field
/// name and supports immutable updates via `copyWith()`.
///
/// #### Example
/// ```dart
/// final userType = StructType(
///   name: 'User',
///   fieldDefinitions: [
///     FieldDefinition(name: 'name', type: BytesType.type),
///     FieldDefinition(name: 'age', type: U32Type.type),
///     FieldDefinition(name: 'active', type: BooleanType.type),
///   ],
/// );
///
/// final user = userType.createValue({
///   'name': 'Alice',
///   'age': 30,
///   'active': true,
/// }) as StructValue;
///
/// print(user.getFieldValue('name').nativeValue); // Alice
/// print(user.fieldNames); // [name, age, active]
///
/// // Create modified copy
/// final updated = user.copyWith({'age': 31});
/// ```
@immutable
final class StructValue extends TypedValue {
  /// Creates a Struct value.
  ///
  /// #### Parameters
  /// - `type` - StructType defining field names and types
  /// - `fields` - Fields instance with typed field values
  ///
  /// #### Throws
  /// - Validation errors from Fields.validateAgainst()
  ///
  /// #### Example
  /// ```dart
  /// final fields = Fields.fromMap(
  ///   {'x': 10, 'y': 20},
  ///   pointType.fieldDefinitions,
  /// );
  /// final point = StructValue(pointType, fields);
  /// ```
  StructValue(StructType type, this.fields) : super(type) {
    fields.validateAgainst(type.fieldDefinitions);
  }

  /// Fields of this struct.
  final Fields fields;

  @override
  StructType get type => super.type as StructType;

  @override
  String get className => 'StructValue';

  static const List<String> _classHierarchy = ['StructValue', 'TypedValue'];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  Map<String, dynamic> get nativeValue => fields.toMap();

  /// Returns the field with the given name.
  Field getField(String name) => fields.getByName(name);

  /// Returns the value of the field with the given name.
  TypedValue getFieldValue(String name) => fields.getValue(name);

  /// Tries to get the field value with the given name.
  TypedValue? tryGetFieldValue(String name) {
    final Field? field = fields.tryGetByName(name);
    return field?.value;
  }

  /// Returns all field names.
  List<String> get fieldNames => fields.names;

  /// Returns all field values.
  List<TypedValue> get fieldValues => fields.values;

  /// Encodes struct to bytes by encoding all fields in definition order.
  ///
  /// #### Returns
  /// Byte array with all field values concatenated (no field names)
  ///
  /// #### Example
  /// ```dart
  /// final point = pointType.createValue({'x': 10, 'y': 20});
  /// final bytes = point.toBytes();
  /// // [0, 0, 0, 10, 0, 0, 0, 20] (two u32 values)
  /// ```
  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() {
    final BytesBuilder builder = BytesBuilder(copy: false);

    for (final Field field in fields) {
      builder.add(field.value.toBytes());
    }

    return builder.takeBytes();
  }

  /// Creates a new struct with updated field values.
  ///
  /// #### Parameters
  /// - `updates` - Map of field names to new values
  ///
  /// #### Returns
  /// `StructValue` - New instance with updated fields
  ///
  /// #### Example
  /// ```dart
  /// final user = userType.createValue({
  ///   'name': 'Alice',
  ///   'age': 30,
  /// }) as StructValue;
  ///
  /// final updated = user.copyWith({'age': 31});
  /// print(updated.getFieldValue('age').nativeValue); // 31
  /// print(updated.getFieldValue('name').nativeValue); // Alice (unchanged)
  /// ```
  StructValue copyWith(Map<String, dynamic> updates) {
    final Map<String, dynamic> newMap = Map<String, dynamic>.from(nativeValue);
    newMap.addAll(updates);
    return type.createValue(newMap) as StructValue;
  }

  @override
  String toString() {
    final String fieldsStr = fields
        .map((Field f) => '${f.name}: ${f.value}')
        .join(', ');
    return '${type.name} { $fieldsStr }';
  }
}
