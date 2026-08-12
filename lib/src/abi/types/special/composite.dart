import 'package:meta/meta.dart';

import '../../../utils/collection_utils.dart';
import '../../core/type_system.dart';

/// Composite type for legacy multi-value encoding `(multi<T1, T2, ...>)`.
///
/// Represents multiple values encoded as separate arguments rather
/// than as a single nested structure. Used for legacy compatibility with older
/// smart contract patterns. Each field becomes a separate argument in calls.
@immutable
final class CompositeType extends CustomType {
  CompositeType._(this.fieldTypes)
    : super(
        name:
            'Composite<${fieldTypes.map((AbiType t) => t.fullyQualifiedName).join(', ')}>',
        typeParameters: fieldTypes,
      ) {
    if (fieldTypes.isEmpty) {
      throw ArgumentError('CompositeType must have at least one field type');
    }
  }

  /// Creates Composite type with field types.
  ///
  /// #### Example
  /// ```dart
  /// final type = CompositeType.of([U32Type.type, BooleanType.type]);
  /// ```
  factory CompositeType.of(List<AbiType> fieldTypes) =>
      CompositeType._(fieldTypes);

  /// Creates CompositeValue from field values.
  ///
  /// #### Example
  /// ```dart
  /// final value = CompositeType.create([U32Type.type, BooleanType.type], [42, true]);
  /// ```
  static CompositeValue create(
    List<AbiType> fieldTypes,
    List<dynamic> fieldValues,
  ) {
    final type = CompositeType.of(fieldTypes);
    return type.createValue(fieldValues) as CompositeValue;
  }

  /// Types of the composite fields.
  final List<AbiType> fieldTypes;

  @override
  String get className => 'CompositeType';

  static const List<String> _classHierarchy = [
    'CompositeType',
    'CustomType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  TypeCardinality get cardinality =>
      TypeCardinalityExtension.variable(fieldTypes.length);

  /// Creates a CompositeValue from native list.
  ///
  /// #### Parameters
  /// - `nativeValue` - List with values matching field types
  ///
  /// #### Returns
  /// `CompositeValue` - Instance with typed fields
  ///
  /// #### Throws
  /// - `ArgumentError` - If nativeValue is not List
  /// - `ArgumentError` - If list length doesn't match fieldTypes length
  ///
  /// #### Example
  /// ```dart
  /// final type = CompositeType.of([U32Type.type, BooleanType.type]);
  /// final value = type.createValue([100, true]) as CompositeValue;
  /// print(value.length); // 2
  /// ```
  @override
  TypedValue createValue(dynamic nativeValue) {
    if (nativeValue is List) {
      if (nativeValue.length != fieldTypes.length) {
        throw ArgumentError.value(
          nativeValue,
          'nativeValue',
          'Composite requires ${fieldTypes.length} values, got ${nativeValue.length}',
        );
      }

      final List<TypedValue> fieldValues = <TypedValue>[];
      for (int i = 0; i < fieldTypes.length; i++) {
        fieldValues.add(fieldTypes[i].createValue(nativeValue[i]));
      }

      return CompositeValue(this, fieldValues);
    }

    throw ArgumentError.value(
      nativeValue,
      'nativeValue',
      'Composite requires List',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompositeType &&
          runtimeType == other.runtimeType &&
          CollectionUtils.listEquals(fieldTypes, other.fieldTypes);

  @override
  int get hashCode => Object.hashAll(fieldTypes);
}

/// Composite value with multiple fields encoded as separate arguments.
///
/// Holds multiple typed values that must be encoded as separate
/// arguments (not nested). Cannot be encoded to bytes directly - use ArgSerializer.
///
/// #### Example
/// ```dart
/// final type = CompositeType.of([U32Type.type, BytesType.type]);
/// final value = type.createValue([42, [1, 2, 3]]) as CompositeValue;
///
/// print(value.length); // 2
/// print(value[0].nativeValue); // 42
/// print(value[1].nativeValue); // [1, 2, 3]
///
/// // Cannot use toBytes() - will throw UnsupportedError
/// // Use ArgSerializer to encode as separate arguments
/// ```
@immutable
final class CompositeValue extends TypedValue {
  /// Creates a Composite value.
  ///
  /// #### Parameters
  /// - `type` - CompositeType defining field types
  /// - `fields` - List of TypedValue instances matching field types
  ///
  /// #### Returns
  /// `CompositeValue` - Instance with the data
  ///
  /// #### Throws
  /// - `ArgumentError` - If fields length doesn't match type
  /// - `ArgumentError` - If any field type is incompatible
  ///
  /// #### Example
  /// ```dart
  /// final type = CompositeType.of([U32Type.type, BooleanType.type]);
  /// final value = CompositeValue(type, [
  ///   U32Value(100),
  ///   BooleanValue(true),
  /// ]);
  /// ```
  CompositeValue(CompositeType type, this.fields) : super(type) {
    if (fields.length != type.fieldTypes.length) {
      throw ArgumentError(
        'CompositeValue requires ${type.fieldTypes.length} fields, got ${fields.length}',
      );
    }

    for (int i = 0; i < fields.length; i++) {
      if (!type.fieldTypes[i].equals(fields[i].type)) {
        throw ArgumentError(
          'Field $i type mismatch: expected ${type.fieldTypes[i].fullyQualifiedName}, '
          'got ${fields[i].type.fullyQualifiedName}',
        );
      }
    }
  }

  /// Creates a Composite value from individual field values.
  ///
  /// #### Parameters
  /// - `fields` - List of TypedValue instances
  ///
  /// #### Returns
  /// `CompositeValue` - Instance with auto-generated type
  ///
  /// #### Example
  /// ```dart
  /// final value = CompositeValue.fromFields([
  ///   U32Value(100),
  ///   BooleanValue(true),
  ///   BytesValue([1, 2, 3]),
  /// ]);
  /// print(value.length); // 3
  /// ```
  factory CompositeValue.fromFields(List<TypedValue> fields) {
    final List<AbiType> fieldTypes = fields
        .map((TypedValue f) => f.type)
        .toList();
    return CompositeValue(CompositeType._(fieldTypes), fields);
  }

  /// Field values.
  final List<TypedValue> fields;

  /// Gets the composite type.
  CompositeType get compositeType => type as CompositeType;

  /// Gets the number of fields.
  int get length => fields.length;

  /// Gets a field at the specified index.
  TypedValue operator [](int index) => fields[index];

  @override
  String get className => 'CompositeValue';

  static const List<String> _classHierarchy = ['CompositeValue', 'TypedValue'];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  List<dynamic> get nativeValue =>
      fields.map((TypedValue f) => f.nativeValue).toList();

  /// Throws UnsupportedError - composite cannot be encoded to bytes.
  ///
  /// #### Throws
  /// - `UnsupportedError` - Always thrown (use ArgSerializer instead)
  ///
  /// #### Example
  /// ```dart
  /// final value = CompositeValue.fromFields([U32Value(100)]);
  /// // value.toBytes(); // Throws UnsupportedError
  ///
  /// // Instead, use ArgSerializer to encode as separate arguments:
  /// // final serializer = ArgSerializer();
  /// // final args = serializer.valuesToStrings(value.fields);
  /// ```
  @override
  List<int> toBytes() {
    throw UnsupportedError(
      'CompositeValue cannot be encoded to bytes. '
      'Use ArgSerializer to encode composite values as separate arguments.',
    );
  }

  @override
  String toString() {
    final String fieldsStr = fields
        .map((TypedValue f) => f.toString())
        .join(', ');
    return 'Composite[$fieldsStr]';
  }
}
