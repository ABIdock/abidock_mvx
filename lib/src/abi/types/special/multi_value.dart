/// MultiValue type for top-level multi-argument grouping.
import 'package:meta/meta.dart';

import '../../../utils/collection_utils.dart';
import '../../core/type_system.dart';

/// Multi-value grouping of independent top-level arguments.
///
/// A [MultiValueType] is the authoring shape for endpoints/return-data that
/// carry several independent top-level values. Unlike [`TupleType`], a `MultiValue` is **not** a single
/// nested struct on the wire — each inner type occupies its own
/// argument/return-data buffer. The wire form for a single buffer is
/// undefined, so nested encodings throw at the codec layer.
///
/// #### Example
/// ```dart
/// final type = MultiValueType(2, [U8Type.type, U32Type.type]);
/// // type.name == 'multi<u8,u32>'
/// ```
@immutable
final class MultiValueType extends CustomType {
  /// Creates a [MultiValueType] with explicit arity and component types.
  ///
  /// #### Parameters
  /// - `arity` - Number of independent top-level slots.
  /// - `types` - Inner types, one per slot (length must equal `arity`).
  ///
  /// #### Throws
  /// - `ArgumentError` - If `arity` is negative or does not match `types.length`.
  MultiValueType(this.arity, this.types, {super.metadata})
    : super(
        name: 'multi<${types.map((AbiType t) => t.name).join(',')}>',
        typeParameters: types,
        cardinality: TypeCardinalityExtension.fixed(arity),
      ) {
    if (arity < 0) {
      throw ArgumentError.value(arity, 'arity', 'must be non-negative');
    }
    if (types.length != arity) {
      throw ArgumentError(
        'MultiValueType expected $arity types, got ${types.length}',
      );
    }
  }

  /// Inner types in declaration order.
  final List<AbiType> types;

  /// Number of independent top-level slots.
  final int arity;

  @override
  String get className => 'MultiValueType';

  static const List<String> _classHierarchy = <String>[
    'MultiValueType',
    'CustomType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  String get fullyQualifiedName =>
      'multi<${types.map((AbiType t) => t.fullyQualifiedName).join(',')}>';

  @override
  TypedValue createValue(dynamic nativeValue) {
    if (nativeValue is List) {
      if (nativeValue.length != arity) {
        throw ArgumentError.value(
          nativeValue,
          'nativeValue',
          'MultiValueType expected $arity values, got ${nativeValue.length}',
        );
      }
      final List<TypedValue> values = <TypedValue>[
        for (int i = 0; i < arity; i++) types[i].createValue(nativeValue[i]),
      ];
      return MultiValueValue(this, values);
    }
    throw ArgumentError.value(
      nativeValue,
      'nativeValue',
      'MultiValueType requires a List of length $arity',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultiValueType &&
          runtimeType == other.runtimeType &&
          arity == other.arity &&
          CollectionUtils.listEquals(types, other.types);

  @override
  int get hashCode => Object.hash(arity, Object.hashAll(types));
}

/// Value matching a [MultiValueType] — N independent typed values.
///
/// Validates that `values.length == type.arity` at construction time.
@immutable
final class MultiValueValue extends TypedValue {
  /// Creates a [MultiValueValue] from inner typed values.
  ///
  /// #### Parameters
  /// - `type` - Parent [MultiValueType].
  /// - `values` - Inner values (length must equal `type.arity`).
  ///
  /// #### Throws
  /// - `ArgumentError` - If `values.length != type.arity`.
  MultiValueValue(MultiValueType type, this.values) : super(type) {
    if (values.length != type.arity) {
      throw ArgumentError(
        'MultiValueValue expected ${type.arity} values, got ${values.length}',
      );
    }
  }

  /// Inner typed values, one per slot.
  final List<TypedValue> values;

  @override
  MultiValueType get type => super.type as MultiValueType;

  @override
  String get className => 'MultiValueValue';

  static const List<String> _classHierarchy = <String>[
    'MultiValueValue',
    'TypedValue',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  List<dynamic> get nativeValue =>
      values.map((TypedValue v) => v.nativeValue).toList();

  /// Number of inner values.
  int get arity => values.length;

  /// Returns the inner value at `index`.
  TypedValue operator [](int index) => values[index];

  @override
  List<int> toBytes() {
    throw UnsupportedError(
      'MultiValueValue has no single-buffer wire form; '
      'each inner value occupies its own top-level buffer.',
    );
  }

  @override
  String toString() =>
      'MultiValue[${values.map((TypedValue v) => v.toString()).join(', ')}]';
}
