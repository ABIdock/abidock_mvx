import 'package:meta/meta.dart';

import '../../codecs/codec_base.dart';
import '../../core/type_system.dart';

/// Nothing type for void/empty values.
///
/// Represents absence of value or void returns in ABI specifications.
/// Zero-size type encoding no data.
///
/// #### Example
/// ```dart
/// final type = NothingType.type;
/// final value = type.createValue(null);
///
/// // Always empty bytes
/// print(value.toBytes().length); // 0
/// print(value.nativeValue); // null
/// print(value.toString()); // "Nothing"
///
/// // Common in function signatures with no return value
/// const endpoint = AbiEndpoint(name: 'transfer');
/// ```
@immutable
final class NothingType extends PrimitiveType {
  NothingType._() : super(name: 'Nothing');
  static final NothingType _instance = NothingType._();

  @override
  int get sizeInBytes => 0;

  @override
  String get className => 'NothingType';

  static const List<String> _classHierarchy = [
    'NothingType',
    'PrimitiveType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  /// Creates NothingValue (ignores input parameter).
  static NothingValue create([dynamic nativeValue]) {
    return NothingValue();
  }

  /// Gets the singleton type instance for use in type definitions.
  static NothingType get type => _instance;

  /// Creates NothingValue (ignores input parameter).
  ///
  /// #### Parameters
  /// - `nativeValue` - Ignored (accepts any value including null)
  ///
  /// #### Returns
  /// `NothingValue` - Empty value instance
  ///
  /// #### Example
  /// ```dart
  /// final value1 = NothingType.create(null);
  /// final value2 = NothingType.create("ignored");
  ///
  /// // All produce same result
  /// print(value1.toBytes().length); // 0
  /// print(value2.toBytes().length); // 0
  /// ```
  @override
  NothingValue createValue(dynamic nativeValue) => create(nativeValue);
}

/// Nothing value for void/empty.
///
/// Holds no data and encodes to zero bytes. Always returns null
/// as native value.
///
/// #### Example
/// ```dart
/// final value1 = NothingValue();
/// final value2 = NothingType.create();
///
/// print(value1.nativeValue); // null
/// print(value1.toBytes()); // []
/// print(value1.toString()); // "Nothing"
///
/// // Used in endpoints with no return value
/// final result = await contract.call('transfer', args);
/// // result might be List<NothingValue> for void functions
/// ```
@immutable
final class NothingValue extends TypedValue {
  /// Creates Nothing value.
  ///
  /// #### Parameters
  /// - Creates empty value with null native representation
  NothingValue() : super(NothingType._instance);

  @override
  String get className => 'NothingValue';

  @override
  List<String> get classHierarchy => <String>[className, 'TypedValue'];

  @override
  Null get nativeValue => null;

  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() => BinaryCodecUtils.emptyBuffer;

  @override
  String toString() => 'Nothing';
}
