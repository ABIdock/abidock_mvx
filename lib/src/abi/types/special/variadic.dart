import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../core/type_system.dart';
import '../../extensions/type_extensions.dart';
import 'managed_decimal.dart';

/// Variadic type for multi-value arguments.
///
/// Represents a variable number of arguments of the same type.
/// Used for endpoints accepting arbitrary-length lists as separate arguments.
/// Can be counted (with length prefix) or uncounted (consumes all remaining bytes).
@immutable
final class VariadicType extends CustomType {
  VariadicType._(this.itemType, {this.isCounted = false})
    : super(
        name: 'variadic<${itemType.fullyQualifiedName}>',
        typeParameters: <AbiType>[itemType],
      );

  /// Creates Variadic type.
  ///
  /// #### Example
  /// ```dart
  /// final var1 = VariadicType.of(U32Type.type);
  /// final var2 = VariadicType.counted(BytesType.type);
  /// ```
  factory VariadicType.of(AbiType itemType) => VariadicType._(itemType);

  /// Creates counted Variadic type.
  factory VariadicType.counted(AbiType itemType) =>
      VariadicType._(itemType, isCounted: true);

  /// Creates VariadicValue from list.
  ///
  /// #### Example
  /// ```dart
  /// final values = VariadicType.create(U32Type.type, [10, 20, 30]);
  /// ```
  static VariadicValue create(AbiType itemType, List<dynamic> nativeValues) {
    final type = VariadicType.of(itemType);
    return type.createValue(nativeValues) as VariadicValue;
  }

  /// Item type.
  final AbiType itemType;

  /// Whether variadic is counted.
  final bool isCounted;

  @override
  String get className => 'VariadicType';

  static const List<String> _classHierarchy = [
    'VariadicType',
    'CustomType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  TypeCardinality get cardinality => TypeCardinalityExtension.variable();

  /// Creates VariadicValue from native list.
  ///
  /// #### Parameters
  /// - `nativeValue` - List of values matching itemType
  ///
  /// #### Returns
  /// `VariadicValue` - Instance with the data
  ///
  /// #### Throws
  /// - `ArgumentError` - If nativeValue is not List
  ///
  /// #### Example
  /// ```dart
  /// final varType = VariadicType(U32Type.type);
  /// final values = varType.createValue([10, 20, 30, 40]);
  /// print(values.length); // 4
  /// ```
  @override
  TypedValue createValue(dynamic nativeValue) {
    if (nativeValue is List) {
      return VariadicValue(
        nativeValue.map((dynamic item) => itemType.createValue(item)).toList(),
        itemType: itemType,
        isCounted: isCounted,
      );
    }

    throw ArgumentError.value(
      nativeValue,
      'nativeValue',
      'Variadic requires List',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VariadicType &&
          runtimeType == other.runtimeType &&
          itemType == other.itemType &&
          isCounted == other.isCounted;

  @override
  int get hashCode => Object.hash(runtimeType, itemType, isCounted);
}

/// Variadic value for multiple values of same type.
///
/// Holds a list of typed values that will be encoded as separate
/// arguments. All items must be exactly the same type. Special restriction:
/// `Variadic<ManagedDecimal>` can only hold 0-1 items due to encoding ambiguity.
///
/// #### Example
/// ```dart
/// // Multiple U32 values
/// final values = VariadicValue([
///   U32Value(10),
///   U32Value(20),
///   U32Value(30),
/// ], itemType: U32Type.type);
///
/// print(values.length); // 3
/// print(values[0].nativeValue); // 10
/// print(values.isEmpty); // false
///
/// // Counted variadic
/// final counted = VariadicValue.counted([
///   BytesValue([1, 2, 3]),
///   BytesValue([4, 5, 6]),
/// ], itemType: BytesType.type);
/// ```
@immutable
final class VariadicValue extends TypedValue {
  /// Creates Variadic value.
  ///
  /// #### Parameters
  /// - `items` - List of TypedValue instances (all same type)
  /// - `itemType` - ABI type of items
  /// - `isCounted` - Whether this is counted variadic (default: false)
  ///
  /// #### Throws
  /// - `ArgumentError` - If any item type doesn't match itemType
  /// - `ArgumentError` - If ManagedDecimal variadic has >1 item
  ///
  /// #### Example
  /// ```dart
  /// final values = VariadicValue([
  ///   U32Value(100),
  ///   U32Value(200),
  /// ], itemType: U32Type.type);
  /// ```
  VariadicValue(this.items, {required AbiType itemType, bool isCounted = false})
    : super(VariadicType._(itemType, isCounted: isCounted)) {
    for (int i = 0; i < items.length; i++) {
      if (!itemType.isAssignableFrom(items[i].type)) {
        throw ArgumentError.value(
          items[i],
          'items[$i]',
          'All items must be exactly of type ${itemType.fullyQualifiedName}, got ${items[i].type.fullyQualifiedName}',
        );
      }
    }
    if (itemType is ManagedDecimalType && items.length > 1) {
      throw ArgumentError(
        'Variadic<ManagedDecimal> with multiple items is not supported. '
        'ManagedDecimal encoding consumes all bytes except the last (scale), '
        'making it impossible to determine item boundaries when multiple items exist. '
        'Use List<ManagedDecimal> instead, or limit to a single ManagedDecimal value.',
      );
    }
  }

  /// Creates counted variadic value.
  ///
  /// #### Parameters
  /// - `items` - List of TypedValue instances
  /// - `itemType` - ABI type of items
  ///
  /// #### Example
  /// ```dart
  /// final counted = VariadicValue.counted([
  ///   U32Value(10),
  ///   U32Value(20),
  /// ], itemType: U32Type.type);
  /// print(counted.isCounted); // true
  /// ```
  factory VariadicValue.counted(
    List<TypedValue> items, {
    required AbiType itemType,
  }) {
    return VariadicValue(items, itemType: itemType, isCounted: true);
  }

  /// Items in variadic.
  final List<TypedValue> items;

  /// Item type.
  AbiType get itemType =>
      type.requireType<VariadicType>('Type must be VariadicType').itemType;

  /// Whether variadic is counted.
  bool get isCounted =>
      type.requireType<VariadicType>('Type must be VariadicType').isCounted;

  /// Number of items.
  int get length => items.length;

  /// Whether variadic is empty.
  bool get isEmpty => items.isEmpty;

  /// Whether variadic is not empty.
  bool get isNotEmpty => items.isNotEmpty;

  /// Gets item at specified index.
  TypedValue operator [](int index) => items[index];

  @override
  String get className => 'VariadicValue';

  static const List<String> _classHierarchy = ['VariadicValue', 'TypedValue'];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  List<TypedValue> get nativeValue => items;

  /// Encodes by concatenating all item encodings.
  ///
  /// #### Returns
  /// Concatenated bytes of all items
  ///
  /// #### Example
  /// ```dart
  /// final values = VariadicValue([
  ///   U32Value(10),
  ///   U32Value(20),
  /// ], itemType: U32Type.type);
  ///
  /// final bytes = values.toBytes();
  /// // [0,0,0,10, 0,0,0,20] - two 4-byte U32 values
  /// ```
  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() {
    final BytesBuilder builder = BytesBuilder(copy: false);
    for (final TypedValue item in items) {
      builder.add(item.toBytes());
    }
    return builder.takeBytes();
  }

  @override
  String toString() {
    final String itemsStr = items
        .map((TypedValue e) => e.toString())
        .join(', ');
    return 'Variadic<${itemType.fullyQualifiedName}>[$itemsStr]';
  }
}
