import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../core/type_system.dart';

/// Variable-length list type for elements of type T.
///
/// Represents smart contract `List<T>` types whose size is determined at
/// runtime rather than fixed by the type.
@immutable
final class ListType extends AbiType {
  /// Creates a List type for the element type.
  ///
  /// #### Parameters
  /// - `elementType` - The ABI type for each list element
  ///
  /// #### Example
  /// ```dart
  /// // List of addresses
  /// final addressList = ListType(AddressType.type);
  ///
  /// // List of strings
  /// final stringList = ListType(BytesType.type);
  /// ```
  ListType(this.elementType)
    : super(
        name: 'List',
        typeParameters: <AbiType>[elementType],
        cardinality: TypeCardinalityExtension.variable(),
      );

  /// Element type in this list.
  final AbiType elementType;

  @override
  String get className => 'ListType';

  static const List<String> _classHierarchy = ['ListType', 'AbiType'];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  String get fullyQualifiedName => 'List<${elementType.fullyQualifiedName}>';

  /// Creates a ListValue from a native Dart list.
  ///
  /// #### Parameters
  /// - `nativeValue` - Dart List with any number of elements
  ///
  /// #### Returns
  /// `TypedValue` - ListValue instance with typed elements
  ///
  /// #### Throws
  /// - `ArgumentError` - If nativeValue is not a List
  ///
  /// #### Example
  /// ```dart
  /// final listType = ListType(U32Type.type);
  /// final listValue = listType.createValue([10, 20, 30]) as ListValue;
  /// print(listValue.length); // 3
  /// print(listValue[0].nativeValue); // 10
  /// ```
  @override
  TypedValue createValue(dynamic nativeValue) {
    if (nativeValue is! List) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'List requires List value',
      );
    }

    final List<TypedValue> elements = nativeValue
        .map((dynamic item) => elementType.createValue(item))
        .toList();

    return ListValue(this, elements);
  }
}

/// Variable-length list value with typed elements.
///
/// Contains a dynamic number of elements, each validated against the
/// element type. Used for smart contract lists with runtime-determined size.
///
/// #### Example
/// ```dart
/// final listType = ListType(U32Type.type);
/// final listValue = ListValue(listType, [
///   U32Value(100),
///   U32Value(200),
///   U32Value(300),
/// ]);
///
/// print(listValue.length); // 3
/// print(listValue.isEmpty); // false
/// print(listValue[1].nativeValue); // 200
/// print(listValue.nativeValue); // [100, 200, 300]
/// ```
@immutable
final class ListValue extends TypedValue {
  /// Creates a List value.
  ///
  /// #### Parameters
  /// - `type` - ListType defining element type
  /// - `elements` - List of TypedValue instances matching element type
  ///
  /// #### Throws
  /// - `ArgumentError` - If any element type is incompatible
  ///
  /// #### Example
  /// ```dart
  /// final type = ListType(BooleanType.type);
  /// final value = ListValue(type, [
  ///   BooleanValue(true),
  ///   BooleanValue(false),
  ///   BooleanValue(true),
  /// ]);
  /// ```
  ListValue(ListType type, List<TypedValue> elements)
    : elements = List<TypedValue>.unmodifiable(elements),
      super(type) {
    for (int i = 0; i < elements.length; i++) {
      if (!type.elementType.isAssignableFrom(elements[i].type)) {
        throw ArgumentError(
          'Element at index $i has type ${elements[i].type.fullyQualifiedName}, '
          'but expected ${type.elementType.fullyQualifiedName}',
        );
      }
    }
  }

  /// List elements.
  final List<TypedValue> elements;

  @override
  ListType get type => super.type as ListType;

  @override
  String get className => 'ListValue';

  static const List<String> _classHierarchy = ['ListValue', 'TypedValue'];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  List<dynamic> get nativeValue =>
      elements.map((TypedValue e) => e.nativeValue).toList();

  /// Number of elements in this list.
  int get length => elements.length;

  /// Whether this list is empty.
  bool get isEmpty => elements.isEmpty;

  /// Whether this list is not empty.
  bool get isNotEmpty => elements.isNotEmpty;

  /// Returns element at the given index.
  TypedValue operator [](int index) => elements[index];

  /// Encodes list to bytes with 4-byte length prefix followed by elements.
  ///
  /// #### Returns
  /// Byte array with [length (4 bytes big-endian), ...elements]
  ///
  /// #### Example
  /// ```dart
  /// final listType = ListType(U8Type.type);
  /// final listValue = listType.createValue([10, 20]);
  /// final bytes = listValue.toBytes();
  /// // [0, 0, 0, 2, 10, 20] - length prefix (2) + elements
  /// print(bytes);
  /// ```
  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() {
    final BytesBuilder builder = BytesBuilder(copy: false);

    final int len = elements.length;
    builder.add(
      (ByteData(4)..setUint32(0, len, Endian.big)).buffer.asUint8List(),
    );

    for (final TypedValue element in elements) {
      builder.add(element.toBytes());
    }

    return builder.takeBytes();
  }

  /// Maps each element using the provided function.
  ///
  /// #### Parameters
  /// - `f` - Function to apply to each element
  ///
  /// #### Returns
  /// `ListValue` - New instance with transformed elements
  ///
  /// #### Example
  /// ```dart
  /// final listType = ListType(U32Type.type);
  /// final original = listType.createValue([1, 2, 3]) as ListValue;
  ///
  /// final doubled = original.map((e) {
  ///   final u32 = e as U32Value;
  ///   return U32Value(u32.nativeValue * 2);
  /// });
  /// print(doubled.nativeValue); // [2, 4, 6]
  /// ```
  ListValue map(TypedValue Function(TypedValue) f) {
    final List<TypedValue> mappedElements = elements.map(f).toList();
    return ListValue(type, mappedElements);
  }

  @override
  String toString() => 'List(${elements.join(', ')})';
}
