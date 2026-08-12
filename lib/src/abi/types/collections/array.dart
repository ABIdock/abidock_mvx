import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../core/type_system.dart';

/// Fixed-length array type with N elements of type T.
///
/// Represents smart contract array types whose size is fixed by the type
/// itself and never appears on the wire (e.g., `array3<u32>`).
@immutable
final class ArrayType extends AbiType {
  /// Creates an Array type with element type and length.
  ///
  /// #### Parameters
  /// - `elementType` - The ABI type for each array element
  /// - `length` - Fixed number of elements (must be >= 0)
  ///
  /// #### Throws
  /// - `ArgumentError` - If length is negative
  ///
  /// #### Example
  /// ```dart
  /// // Array of 5 addresses
  /// final addressArray = ArrayType(AddressType.type, 5);
  /// final arrayValue = addressArray.createValue([
  ///   AddressValue.fromHex('0x1...'),
  ///   // ... more addresses ...
  /// ]);
  /// ```
  ArrayType(this.elementType, this.length)
    : super(
        name: 'Array',
        typeParameters: <AbiType>[elementType],
        cardinality: TypeCardinalityExtension.fixed(length),
      ) {
    if (length < 0) {
      throw ArgumentError.value(length, 'length', 'Must be non-negative');
    }
  }

  /// Element type in this array.
  final AbiType elementType;

  /// Fixed length of this array.
  final int length;

  @override
  int? get sizeInBytes {
    final int? elemSize = elementType.sizeInBytes;
    if (elemSize == null) return null;
    return elemSize * length;
  }

  @override
  String get className => 'ArrayType';

  static const List<String> _classHierarchy = ['ArrayType', 'AbiType'];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  String get fullyQualifiedName =>
      '$name<${elementType.fullyQualifiedName}, $length>';

  /// Creates an ArrayValue from a native Dart list.
  ///
  /// #### Parameters
  /// - `nativeValue` - Dart List with exactly `length` elements
  ///
  /// #### Returns
  /// `TypedValue` - ArrayValue instance with typed elements
  ///
  /// #### Throws
  /// - `ArgumentError` - If nativeValue is not a List
  /// - `ArgumentError` - If list length doesn't match array length
  ///
  /// #### Example
  /// ```dart
  /// final arrayType = ArrayType(U32Type.type, 3);
  /// final arrayValue = arrayType.createValue([10, 20, 30]) as ArrayValue;
  /// print(arrayValue.length); // 3
  /// print(arrayValue[1].nativeValue); // 20
  /// ```
  @override
  TypedValue createValue(dynamic nativeValue) {
    if (nativeValue is! List) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'Array requires List value',
      );
    }

    if (nativeValue.length != length) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'Array length must be exactly $length, got ${nativeValue.length}',
      );
    }

    final List<TypedValue> elements = nativeValue
        .map((dynamic item) => elementType.createValue(item))
        .toList();

    return ArrayValue(this, elements);
  }
}

/// Fixed-length array value with typed elements.
///
/// Contains a fixed number of elements, each validated against the
/// element type. Used for smart contract arrays with compile-time known size.
///
/// #### Example
/// ```dart
/// final arrayType = ArrayType(U32Type.type, 3);
/// final arrayValue = ArrayValue(arrayType, [
///   U32Value(100),
///   U32Value(200),
///   U32Value(300),
/// ]);
///
/// print(arrayValue.length); // 3
/// print(arrayValue[1].nativeValue); // 200
/// print(arrayValue.nativeValue); // [100, 200, 300]
/// ```
@immutable
final class ArrayValue extends TypedValue {
  /// Creates an Array value.
  ///
  /// #### Parameters
  /// - `type` - ArrayType defining element type and length
  /// - `elements` - List of TypedValue instances matching element type
  ///
  /// #### Throws
  /// - `ArgumentError` - If elements length doesn't match type length
  /// - `ArgumentError` - If any element type is incompatible
  ///
  /// #### Example
  /// ```dart
  /// final type = ArrayType(BooleanType.type, 2);
  /// final value = ArrayValue(type, [
  ///   BooleanValue(true),
  ///   BooleanValue(false),
  /// ]);
  /// ```
  ArrayValue(ArrayType type, List<TypedValue> elements)
    : elements = List<TypedValue>.unmodifiable(elements),
      super(type) {
    if (elements.length != type.length) {
      throw ArgumentError(
        'Array length must be exactly ${type.length}, got ${elements.length}',
      );
    }
    for (int i = 0; i < elements.length; i++) {
      if (!type.elementType.isAssignableFrom(elements[i].type)) {
        throw ArgumentError(
          'Element at index $i has type ${elements[i].type.fullyQualifiedName}, '
          'but expected ${type.elementType.fullyQualifiedName}',
        );
      }
    }
  }

  /// Array elements.
  final List<TypedValue> elements;

  @override
  ArrayType get type => super.type as ArrayType;

  @override
  String get className => 'ArrayValue';

  static const List<String> _classHierarchy = ['ArrayValue', 'TypedValue'];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  List<dynamic> get nativeValue =>
      elements.map((TypedValue e) => e.nativeValue).toList();

  /// Number of elements in this array.
  int get length => elements.length;

  /// Returns element at the given index.
  TypedValue operator [](int index) => elements[index];

  /// Encodes array to bytes by concatenating all elements.
  ///
  /// #### Returns
  /// Byte array with all elements encoded sequentially (no length prefix)
  ///
  /// #### Example
  /// ```dart
  /// final arrayType = ArrayType(U8Type.type, 3);
  /// final arrayValue = arrayType.createValue([10, 20, 30]);
  /// final bytes = arrayValue.toBytes();
  /// print(bytes); // [10, 20, 30]
  /// ```
  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() {
    final BytesBuilder builder = BytesBuilder(copy: false);
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
  /// `ArrayValue` - New instance with transformed elements
  ///
  /// #### Example
  /// ```dart
  /// final arrayType = ArrayType(U32Type.type, 3);
  /// final original = arrayType.createValue([1, 2, 3]) as ArrayValue;
  ///
  /// final doubled = original.map((e) {
  ///   final u32 = e as U32Value;
  ///   return U32Value(u32.nativeValue * 2);
  /// });
  /// print(doubled.nativeValue); // [2, 4, 6]
  /// ```
  ArrayValue map(TypedValue Function(TypedValue) f) {
    final List<TypedValue> mappedElements = elements.map(f).toList();
    return ArrayValue(type, mappedElements);
  }

  @override
  String toString() => 'Array(${elements.join(', ')})';
}
