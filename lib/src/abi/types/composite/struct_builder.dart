import '../../core/type_system.dart';
import '../collections/array.dart';
import '../collections/list.dart';
import '../composite/enum.dart';
import '../composite/tuple.dart';
import '../primitives/address.dart';
import '../primitives/biguint.dart';
import '../primitives/boolean.dart';
import '../primitives/bytes.dart';
import '../primitives/i16.dart';
import '../primitives/i32.dart';
import '../primitives/i64.dart';
import '../primitives/i8.dart';
import '../primitives/string.dart';
import '../primitives/u16.dart';
import '../primitives/u32.dart';
import '../primitives/u64.dart';
import '../primitives/u8.dart';
import '../special/optional.dart';
import 'fields.dart';
import 'struct.dart';

/// Builder for creating StructType instances.
///
/// Provides a chainable API for building struct types with named fields.
/// Automatically validates field name uniqueness.
class StructBuilder {
  /// Creates a struct builder with the given name.
  ///
  /// #### Parameters
  /// - `name` - Name of the struct type (must be non-empty)
  /// - `metadata` - Optional metadata dictionary
  ///
  /// #### Example
  /// ```dart
  /// final builder = StructBuilder('Token');
  /// ```
  StructBuilder(this._name, {Map<String, dynamic>? metadata})
    : _metadata = metadata,
      _fields = [],
      _fieldNames = {};

  final String _name;
  final Map<String, dynamic>? _metadata;
  final List<FieldDefinition> _fields;
  final Set<String> _fieldNames;

  /// Adds a field to the struct.
  ///
  /// #### Parameters
  /// - `name` - Field name (must be unique within struct)
  /// - `type` - Field type (any ABI type)
  ///
  /// #### Returns
  /// `StructBuilder` - This builder for method chaining
  ///
  /// #### Throws
  /// - `ArgumentError` if field name is empty
  /// - `ArgumentError` if field name is duplicate
  ///
  /// #### Example
  /// ```dart
  /// builder
  ///   .field('id', U32Type.type)
  ///   .field('name', StringType.type);
  /// ```
  StructBuilder field(String name, AbiType type) {
    if (name.isEmpty) {
      throw ArgumentError('Field name cannot be empty');
    }

    if (_fieldNames.contains(name)) {
      throw ArgumentError(
        'Duplicate field name "$name" in struct "$_name". '
        'Field names must be unique.',
      );
    }

    _fieldNames.add(name);
    _fields.add(FieldDefinition(name: name, type: type));

    return this;
  }

  /// Adds multiple fields at once from a map.
  ///
  /// #### Parameters
  /// - `fields` - Map of field name → type
  ///
  /// #### Returns
  /// `StructBuilder` - This builder for method chaining
  ///
  /// #### Example
  /// ```dart
  /// builder.fields({
  ///   'x': U32Type.type,
  ///   'y': U32Type.type,
  ///   'z': U32Type.type,
  /// });
  /// ```
  StructBuilder fields(Map<String, AbiType> fields) {
    for (final entry in fields.entries) {
      field(entry.key, entry.value);
    }
    return this;
  }

  /// Builds the immutable StructType.
  ///
  /// #### Returns
  /// StructType with all added fields
  ///
  /// #### Throws
  /// - `ArgumentError` if no fields have been added
  ///
  /// #### Example
  /// ```dart
  /// final structType = builder.build();
  /// print(structType.name);  // 'Token'
  /// print(structType.fieldDefinitions.length);  // 3
  /// ```
  StructType build() {
    if (_fields.isEmpty) {
      throw ArgumentError(
        'Cannot build empty struct "$_name". '
        'Add at least one field using .field()',
      );
    }

    return StructType(
      name: _name,
      fieldDefinitions: List.unmodifiable(_fields),
      metadata: _metadata,
    );
  }

  /// Returns the current number of fields.
  int get fieldCount => _fields.length;

  /// Returns whether any fields have been added.
  bool get isEmpty => _fields.isEmpty;

  /// Returns whether fields have been added.
  bool get isNotEmpty => _fields.isNotEmpty;

  @override
  String toString() => 'StructBuilder($_name, ${_fields.length} fields)';
}

/// Extension methods for common struct patterns.
extension StructBuilderExtensions on StructBuilder {
  /// Adds a U8 field (byte type).
  ///
  /// #### Example
  /// ```dart
  /// builder.u8Field('flags');
  /// ```
  StructBuilder u8Field(String name) {
    return field(name, U8Type.type);
  }

  /// Adds a U16 field (short integer type).
  ///
  /// #### Example
  /// ```dart
  /// builder.u16Field('port');
  /// ```
  StructBuilder u16Field(String name) {
    return field(name, U16Type.type);
  }

  /// Adds a U32 field (common integer type).
  ///
  /// #### Example
  /// ```dart
  /// builder.u32Field('count');
  /// ```
  StructBuilder u32Field(String name) {
    return field(name, U32Type.type);
  }

  /// Adds a U64 field (common large integer type).
  ///
  /// #### Example
  /// ```dart
  /// builder.u64Field('id');
  /// ```
  StructBuilder u64Field(String name) {
    return field(name, U64Type.type);
  }

  /// Adds an I8 field (signed byte type).
  ///
  /// #### Example
  /// ```dart
  /// builder.i8Field('temperature');
  /// ```
  StructBuilder i8Field(String name) {
    return field(name, I8Type.type);
  }

  /// Adds an I16 field (signed short integer type).
  ///
  /// #### Example
  /// ```dart
  /// builder.i16Field('coordinate');
  /// ```
  StructBuilder i16Field(String name) {
    return field(name, I16Type.type);
  }

  /// Adds an I32 field (signed integer type).
  ///
  /// #### Example
  /// ```dart
  /// builder.i32Field('balance');
  /// ```
  StructBuilder i32Field(String name) {
    return field(name, I32Type.type);
  }

  /// Adds an I64 field (signed large integer type).
  ///
  /// #### Example
  /// ```dart
  /// builder.i64Field('timestamp');
  /// ```
  StructBuilder i64Field(String name) {
    return field(name, I64Type.type);
  }

  /// Adds a string field.
  ///
  /// #### Example
  /// ```dart
  /// builder.stringField('name');
  /// ```
  StructBuilder stringField(String name) {
    return field(name, StringType.type);
  }

  /// Adds a boolean field.
  ///
  /// #### Example
  /// ```dart
  /// builder.boolField('isActive');
  /// ```
  StructBuilder boolField(String name) {
    return field(name, BooleanType.type);
  }

  /// Adds an address field.
  ///
  /// #### Example
  /// ```dart
  /// builder.addressField('owner');
  /// ```
  StructBuilder addressField(String name) {
    return field(name, AddressType.type);
  }

  /// Adds a BigUInt field (arbitrary precision).
  ///
  /// #### Example
  /// ```dart
  /// builder.bigUIntField('balance');
  /// ```
  StructBuilder bigUIntField(String name) {
    return field(name, BigUIntType.type);
  }

  /// Adds a bytes field.
  ///
  /// #### Example
  /// ```dart
  /// builder.bytesField('data');
  /// ```
  StructBuilder bytesField(String name) {
    return field(name, BytesType.type);
  }

  /// Adds an optional field of the given inner type.
  ///
  /// #### Example
  /// ```dart
  /// builder.optionalField('description', StringType.type);
  /// builder.optionalField('metadata', addressType);
  /// ```
  StructBuilder optionalField(String name, AbiType innerType) {
    return field(name, OptionalType.of(innerType));
  }

  /// Adds an array field with fixed length.
  ///
  /// #### Example
  /// ```dart
  /// builder.arrayField('coordinates', U32Type.type, 3);  // [u32; 3]
  /// builder.arrayField('hashes', BytesType.type, 5);     // [bytes; 5]
  /// ```
  StructBuilder arrayField(String name, AbiType elementType, int length) {
    return field(name, ArrayType(elementType, length));
  }

  /// Adds a variable-length list field.
  ///
  /// #### Example
  /// ```dart
  /// builder.listField('tags', StringType.type);
  /// builder.listField('amounts', BigUIntType.type);
  /// ```
  StructBuilder listField(String name, AbiType elementType) {
    return field(name, ListType(elementType));
  }

  /// Adds a nested struct field.
  ///
  /// #### Example
  /// ```dart
  /// final addressStruct = StructBuilder('Address')
  ///   .stringField('street')
  ///   .stringField('city')
  ///   .build();
  ///
  /// builder.structField('homeAddress', addressStruct);
  /// ```
  StructBuilder structField(String name, StructType structType) {
    return field(name, structType);
  }

  /// Adds an enum field.
  ///
  /// #### Example
  /// ```dart
  /// builder.enumField('status', statusEnumType);
  /// ```
  StructBuilder enumField(String name, EnumType enumType) {
    return field(name, enumType);
  }

  /// Adds a tuple field.
  ///
  /// #### Example
  /// ```dart
  /// builder.tupleField('point', TupleType([U32Type.type, U32Type.type]));
  /// ```
  StructBuilder tupleField(String name, TupleType tupleType) {
    return field(name, tupleType);
  }

  /// Adds an optional string field.
  ///
  /// #### Example
  /// ```dart
  /// builder.optionalStringField('nickname');
  /// ```
  StructBuilder optionalStringField(String name) {
    return optionalField(name, StringType.type);
  }

  /// Adds an optional address field.
  ///
  /// #### Example
  /// ```dart
  /// builder.optionalAddressField('delegate');
  /// ```
  StructBuilder optionalAddressField(String name) {
    return optionalField(name, AddressType.type);
  }

  /// Adds an optional BigUInt field.
  ///
  /// #### Example
  /// ```dart
  /// builder.optionalBigUIntField('maxAmount');
  /// ```
  StructBuilder optionalBigUIntField(String name) {
    return optionalField(name, BigUIntType.type);
  }

  /// Adds a string array field.
  ///
  /// #### Example
  /// ```dart
  /// builder.stringArrayField('tags', 5);  // Fixed 5 strings
  /// ```
  StructBuilder stringArrayField(String name, int length) {
    return arrayField(name, StringType.type, length);
  }

  /// Adds a string list field.
  ///
  /// #### Example
  /// ```dart
  /// builder.stringListField('categories');  // Variable length
  /// ```
  StructBuilder stringListField(String name) {
    return listField(name, StringType.type);
  }

  /// Adds an address list field.
  ///
  /// #### Example
  /// ```dart
  /// builder.addressListField('participants');
  /// ```
  StructBuilder addressListField(String name) {
    return listField(name, AddressType.type);
  }

  /// Adds a BigUInt list field.
  ///
  /// #### Example
  /// ```dart
  /// builder.amountListField('rewards');
  /// ```
  StructBuilder amountListField(String name) {
    return listField(name, BigUIntType.type);
  }
}
