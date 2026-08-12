import 'package:meta/meta.dart';

import '../../core/type_system.dart';

/// Definition of a field in a struct or tuple with name and type.
///
/// Specifies the schema for a field, including its name, type, and
/// optional documentation. Used to define struct/tuple structure before creating values.
@immutable
final class FieldDefinition {
  /// Creates a field definition.
  ///
  /// #### Parameters
  /// - `name` - Field name (must be unique within struct/tuple)
  /// - `type` - ABI type for this field
  /// - `description` - Optional documentation string
  ///
  /// #### Example
  /// ```dart
  /// final field = FieldDefinition(
  ///   name: 'balance',
  ///   type: U64Type.type,
  ///   description: 'Account balance in tokens',
  /// );
  /// ```
  const FieldDefinition({
    required this.name,
    required this.type,
    this.description,
  });

  /// Name of this field.
  final String name;

  /// Type of this field.
  final AbiType type;

  /// Optional description for this field.
  final String? description;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'name': name,
    'type': type.name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldDefinition &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          type.equals(other.type);

  @override
  int get hashCode => Object.hash(name, type.fullyQualifiedName);

  @override
  String toString() {
    if (description != null) {
      return '$name: ${type.fullyQualifiedName} // $description';
    }
    return '$name: ${type.fullyQualifiedName}';
  }
}

/// Field with name and typed value.
///
/// Represents an actual field instance with both its name and value.
/// Used to store field data in structs and tuples.
///
/// #### Example
/// ```dart
/// final nameField = Field(
///   name: 'name',
///   value: BytesValue(utf8.encode('Alice')),
/// );
/// final ageField = Field(
///   name: 'age',
///   value: U32Value(30),
/// );
/// ```
@immutable
final class Field {
  /// Creates a field with a value.
  ///
  /// #### Parameters
  /// - `name` - Field name
  /// - `value` - TypedValue for this field
  ///
  /// #### Example
  /// ```dart
  /// final field = Field(
  ///   name: 'active',
  ///   value: BooleanValue(true),
  /// );
  /// ```
  const Field({required this.name, required this.value});

  /// Name of this field.
  final String name;

  /// Value of this field.
  final TypedValue value;

  /// Type of this field's value.
  AbiType get type => value.type;

  /// Validates this field against a field definition.
  ///
  /// #### Parameters
  /// - `definition` - FieldDefinition to validate against
  ///
  /// #### Throws
  /// - `ArgumentError` - If name doesn't match
  /// - `ArgumentError` - If type is incompatible
  ///
  /// #### Example
  /// ```dart
  /// final definition = FieldDefinition(name: 'age', type: U32Type.type);
  /// final field = Field(name: 'age', value: U32Value(25));
  /// field.validateAgainst(definition); // OK
  ///
  /// final wrongField = Field(name: 'name', value: U32Value(25));
  /// // wrongField.validateAgainst(definition); // Throws: name mismatch
  /// ```
  void validateAgainst(FieldDefinition definition) {
    if (name != definition.name) {
      throw ArgumentError(
        'Field name mismatch: expected "${definition.name}", got "$name"',
      );
    }

    if (!definition.type.isAssignableFrom(value.type)) {
      throw ArgumentError(
        'Field "$name" type mismatch: expected ${definition.type.fullyQualifiedName}, '
        'got ${value.type.fullyQualifiedName}',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Field &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          value.valueEquals(other.value);

  @override
  int get hashCode => Object.hash(name, value);

  @override
  String toString() => '$name: $value';
}

/// Collection of fields for structs and tuples.
///
/// Manages a collection of Field instances, providing access by name
/// or index. Handles validation, conversion to/from maps and lists.
///
/// #### Example
/// ```dart
/// final fields = Fields([
///   Field(name: 'x', value: U32Value(10)),
///   Field(name: 'y', value: U32Value(20)),
/// ]);
///
/// print(fields.length); // 2
/// print(fields.getValue('x').nativeValue); // 10
/// print(fields.toMap()); // {x: 10, y: 20}
/// ```
@immutable
final class Fields extends Iterable<Field> {
  /// Creates a collection of fields.
  ///
  /// #### Parameters
  /// - `fields` - List of Field instances
  ///
  /// #### Example
  /// ```dart
  /// final fields = Fields([
  ///   Field(name: 'id', value: U32Value(1)),
  ///   Field(name: 'name', value: BytesValue(utf8.encode('Test'))),
  /// ]);
  /// ```
  Fields(List<Field> fields) : _items = List<Field>.unmodifiable(fields);

  @override
  Iterator<Field> get iterator => _items.iterator;

  /// Creates fields from a map of name->value pairs and field definitions.
  ///
  /// #### Parameters
  /// - `map` - Map of field names to native values
  /// - `definitions` - List of field definitions
  ///
  /// #### Throws
  /// - `ArgumentError` - If required field is missing
  ///
  /// #### Example
  /// ```dart
  /// final definitions = [
  ///   FieldDefinition(name: 'x', type: U32Type.type),
  ///   FieldDefinition(name: 'y', type: U32Type.type),
  /// ];
  /// final fields = Fields.fromMap({'x': 10, 'y': 20}, definitions);
  /// ```
  factory Fields.fromMap(
    Map<String, dynamic> map,
    List<FieldDefinition> definitions,
  ) {
    final List<Field> fields = <Field>[];

    for (final FieldDefinition definition in definitions) {
      if (!map.containsKey(definition.name)) {
        throw ArgumentError('Missing field: ${definition.name}');
      }

      final dynamic nativeValue = map[definition.name];
      final TypedValue typedValue = definition.type.createValue(nativeValue);

      fields.add(Field(name: definition.name, value: typedValue));
    }

    return Fields(fields);
  }

  /// Creates fields from a list of values and field definitions.
  ///
  /// #### Parameters
  /// - `values` - List of native values (must match definitions order)
  /// - `definitions` - List of field definitions
  ///
  /// #### Throws
  /// - `ArgumentError` - If values length doesn't match definitions length
  ///
  /// #### Example
  /// ```dart
  /// final definitions = [
  ///   FieldDefinition(name: 'field0', type: U32Type.type),
  ///   FieldDefinition(name: 'field1', type: BooleanType.type),
  /// ];
  /// final fields = Fields.fromList([42, true], definitions);
  /// ```
  factory Fields.fromList(
    List<dynamic> values,
    List<FieldDefinition> definitions,
  ) {
    if (values.length != definitions.length) {
      throw ArgumentError(
        'Values length (${values.length}) must match definitions length (${definitions.length})',
      );
    }

    final List<Field> fields = <Field>[];

    for (int i = 0; i < definitions.length; i++) {
      final FieldDefinition definition = definitions[i];
      final TypedValue typedValue = definition.type.createValue(values[i]);
      fields.add(Field(name: definition.name, value: typedValue));
    }

    return Fields(fields);
  }

  /// Internal list of fields.
  final List<Field> _items;

  /// Returns field at the given index.
  Field operator [](int index) => _items[index];

  /// Returns the field with the given name.
  ///
  /// #### Parameters
  /// - `name` - Field name to search for
  ///
  /// #### Returns
  /// `Field` - Instance with matching name
  ///
  /// #### Throws
  /// - `ArgumentError` - If field not found
  ///
  /// #### Example
  /// ```dart
  /// final field = fields.getByName('x');
  /// print(field.value.nativeValue); // 10
  /// ```
  Field getByName(String name) {
    try {
      return _items.firstWhere((Field f) => f.name == name);
    } catch (e) {
      throw ArgumentError('Field not found: $name');
    }
  }

  /// Returns the value of the field with the given name.
  TypedValue getValue(String name) => getByName(name).value;

  /// Tries to get the field with the given name.
  Field? tryGetByName(String name) {
    try {
      return _items.firstWhere((Field f) => f.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Returns all field names.
  List<String> get names => _items.map((Field f) => f.name).toList();

  /// Returns all field values.
  List<TypedValue> get values => _items.map((Field f) => f.value).toList();

  /// Validates all fields against their definitions.
  ///
  /// #### Parameters
  /// - `definitions` - List of field definitions to validate against
  ///
  /// #### Throws
  /// - `ArgumentError` - If field count mismatch
  /// - `ArgumentError` - If any field validation fails
  ///
  /// #### Example
  /// ```dart
  /// final definitions = [
  ///   FieldDefinition(name: 'x', type: U32Type.type),
  ///   FieldDefinition(name: 'y', type: U32Type.type),
  /// ];
  /// fields.validateAgainst(definitions); // Validates all fields
  /// ```
  void validateAgainst(List<FieldDefinition> definitions) {
    if (_items.length != definitions.length) {
      throw ArgumentError(
        'Field count mismatch: expected ${definitions.length}, got ${_items.length}',
      );
    }

    for (int i = 0; i < _items.length; i++) {
      _items[i].validateAgainst(definitions[i]);
    }
  }

  /// Converts fields to a map of name->native value.
  Map<String, dynamic> toMap() {
    return Map<String, dynamic>.fromEntries(
      _items.map(
        (Field f) => MapEntry<String, dynamic>(f.name, f.value.nativeValue),
      ),
    );
  }

  /// Converts fields to a list of native values.
  List<dynamic> toNativeList() {
    return _items.map((Field f) => f.value.nativeValue).toList();
  }

  @override
  String toString() => '{${_items.join(', ')}}';
}
