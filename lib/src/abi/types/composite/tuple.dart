import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../core/type_system.dart';
import 'fields.dart';

/// Tuple type with ordered, unnamed fields accessed by index.
///
/// Represents smart contract tuple types with positional elements.
///  Elements are accessed by index.
@immutable
final class TupleType extends CustomType {
  /// Creates a Tuple type with element types.
  ///
  /// #### Parameters
  /// - `elementTypes` - List of types for each tuple element (must be non-empty)
  /// - `metadata` - Optional metadata
  ///
  /// #### Throws
  /// - `ArgumentError` - If elementTypes is empty
  ///
  /// #### Example
  /// ```dart
  /// // Tuple of (address, amount)
  /// final transferTuple = TupleType([
  ///   AddressType.type,
  ///   U64Type.type,
  /// ]);
  /// print(transferTuple.arity); // 2
  /// ```
  TupleType(List<AbiType> elementTypes, {super.metadata})
    : fieldDefinitions = _createFieldDefinitions(elementTypes),
      super(name: 'Tuple', cardinality: TypeCardinalityExtension.singular()) {
    if (elementTypes.isEmpty) {
      throw ArgumentError('Tuple must have at least one element');
    }
  }

  /// Field definitions for this tuple (auto-generated names like 'field0', 'field1').
  final List<FieldDefinition> fieldDefinitions;

  /// Types of elements in this tuple.
  List<AbiType> get elementTypes =>
      fieldDefinitions.map((FieldDefinition f) => f.type).toList();

  /// Creates field definitions from element types with auto-generated names.
  static List<FieldDefinition> _createFieldDefinitions(List<AbiType> types) {
    return List<FieldDefinition>.generate(
      types.length,
      (int i) => FieldDefinition(
        name: 'field$i',
        type: types[i],
        description: 'Tuple element at index $i',
      ),
    );
  }

  @override
  String get className => 'TupleType';

  static const List<String> _classHierarchy = [
    'TupleType',
    'CustomType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  String get fullyQualifiedName {
    final String types = elementTypes
        .map((AbiType t) => t.fullyQualifiedName)
        .join(', ');
    return '($types)';
  }

  /// Number of elements in this tuple.
  int get arity => elementTypes.length;

  /// Creates a TupleValue from native Dart list.
  ///
  /// #### Parameters
  /// - `nativeValue` - List with values matching element types
  ///
  /// #### Returns
  /// `TupleValue` - Instance with typed elements
  ///
  /// #### Throws
  /// - `ArgumentError` - If nativeValue is not a List
  /// - `ArgumentError` - If list length doesn't match arity
  ///
  /// #### Example
  /// ```dart
  /// final tupleType = TupleType([U32Type.type, BooleanType.type]);
  /// final tuple = tupleType.createValue([100, true]) as TupleValue;
  /// print(tuple[0].nativeValue); // 100
  /// print(tuple[1].nativeValue); // true
  /// ```
  @override
  TypedValue createValue(dynamic nativeValue) {
    if (nativeValue is! List) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'Tuple requires List value',
      );
    }

    if (nativeValue.length != arity) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'Tuple requires exactly $arity elements, got ${nativeValue.length}',
      );
    }

    final Fields fields = Fields.fromList(nativeValue, fieldDefinitions);
    return TupleValue(this, fields);
  }
}

/// Tuple value with ordered element values accessed by index.
///
/// Holds element values for a tuple instance. Provides index-based
/// access, destructuring, and immutable updates.
///
/// #### Example
/// ```dart
/// final tupleType = TupleType([
///   U32Type.type,
///   BytesType.type,
///   AddressType.type,
/// ]);
///
/// final tuple = tupleType.createValue([
///   100,
///   'data',
///   'erd1...',
/// ]) as TupleValue;
///
/// print(tuple[0].nativeValue); // 100
/// print(tuple[1].nativeValue); // data
/// print(tuple.arity); // 3
///
/// // Destructure to list
/// final [id, data, address] = tuple.destructure();
/// ```
@immutable
final class TupleValue extends TypedValue {
  /// Creates a Tuple value.
  ///
  /// #### Parameters
  /// - `type` - TupleType defining element types
  /// - `fields` - Fields instance with typed element values
  ///
  /// #### Throws
  /// - Validation errors from Fields.validateAgainst()
  ///
  /// #### Example
  /// ```dart
  /// final fields = Fields.fromList(
  ///   [42, true],
  ///   tupleType.fieldDefinitions,
  /// );
  /// final tuple = TupleValue(tupleType, fields);
  /// ```
  TupleValue(TupleType type, this.fields) : super(type) {
    fields.validateAgainst(type.fieldDefinitions);
  }

  /// Fields of this tuple (accessed by index).
  final Fields fields;

  @override
  TupleType get type => super.type as TupleType;

  @override
  String get className => 'TupleValue';

  static const List<String> _classHierarchy = ['TupleValue', 'TypedValue'];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  List<dynamic> get nativeValue => fields.toNativeList();

  /// Number of elements in this tuple.
  int get arity => fields.length;

  /// Returns the element at the given index.
  TypedValue operator [](int index) {
    if (index < 0 || index >= arity) {
      throw RangeError.index(index, this, 'index', null, arity);
    }
    return fields[index].value;
  }

  /// Returns the element at the given index (same as []).
  TypedValue getElementAt(int index) => this[index];

  /// Tries to get the element at the given index.
  TypedValue? tryGetElementAt(int index) {
    if (index < 0 || index >= arity) {
      return null;
    }
    return fields[index].value;
  }

  /// Returns all element values as a list.
  List<TypedValue> get elements => fields.values;

  /// Encodes tuple to bytes by encoding all elements in order.
  ///
  /// #### Returns
  /// Byte array with all element values concatenated
  ///
  /// #### Example
  /// ```dart
  /// final tuple = tupleType.createValue([10, true]);
  /// final bytes = tuple.toBytes();
  /// // [0, 0, 0, 10, 1] (u32 + bool)
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

  /// Creates a new tuple with updated element values.
  ///
  /// #### Parameters
  /// - `updates` - Map of indices to new values
  ///
  /// #### Returns
  /// `TupleValue` - New instance with updated elements
  ///
  /// #### Example
  /// ```dart
  /// final tuple = tupleType.createValue([10, 'old', true]) as TupleValue;
  /// final updated = tuple.copyWith({1: 'new'});
  /// print(updated[0].nativeValue); // 10 (unchanged)
  /// print(updated[1].nativeValue); // new
  /// print(updated[2].nativeValue); // true (unchanged)
  /// ```
  TupleValue copyWith(Map<int, dynamic> updates) {
    final List<dynamic> newList = List<dynamic>.from(nativeValue);
    updates.forEach((int index, dynamic value) {
      if (index >= 0 && index < arity) {
        newList[index] = value;
      }
    });
    return type.createValue(newList) as TupleValue;
  }

  /// Deconstructs this tuple into a list of values.
  ///
  /// #### Returns
  /// List of TypedValue elements
  ///
  /// #### Example
  /// ```dart
  /// final tuple = tupleType.createValue([42, 'data', true]) as TupleValue;
  /// final elements = tuple.destructure();
  /// print(elements[0].nativeValue); // 42
  /// print(elements[1].nativeValue); // data
  /// print(elements[2].nativeValue); // true
  ///
  /// // Pattern matching style
  /// final [id, data, flag] = tuple.destructure();
  /// ```
  List<TypedValue> destructure() => elements;

  @override
  String toString() {
    final String elementsStr = elements.join(', ');
    return '($elementsStr)';
  }
}
