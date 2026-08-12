import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../utils/hex_utils.dart';
import '../../core/type_system.dart';

/// ManagedByteArray type for arbitrary fixed-length byte arrays.
///
/// Holds exactly `length` raw bytes and serializes without a length prefix in
/// both nested and top-level positions: the length is fixed by the type, so it
/// is never written to or read from the wire.
///
/// #### Example
/// ```dart
/// final type = ManagedByteArrayType(48);
/// final value = type.createValue(Uint8List(48));
/// print(value.toBytes().length); // 48
/// ```
@immutable
final class ManagedByteArrayType extends PrimitiveType {
  /// Creates a ManagedByteArray type with the given fixed `length`.
  ///
  /// #### Parameters
  /// - `length` - Number of bytes (must be positive)
  ManagedByteArrayType(this.length)
    : assert(length > 0, 'ManagedByteArray length must be > 0'),
      super(name: 'ManagedByteArray');

  /// Fixed byte length of this array type.
  final int length;

  @override
  int get sizeInBytes => length;

  @override
  String get className => 'ManagedByteArrayType';

  static const List<String> _classHierarchy = <String>[
    'ManagedByteArrayType',
    'PrimitiveType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  String get fullyQualifiedName => 'multiversx:types:ManagedByteArray*$length*';

  /// Creates a `ManagedByteArrayValue` from raw bytes or a hex string.
  ///
  /// #### Parameters
  /// - `nativeValue` - `List<int>` of `length` bytes, or hex string of `2 * length` chars
  ///
  /// #### Returns
  /// `ManagedByteArrayValue` - Instance wrapping a `Uint8List`
  ///
  /// #### Throws
  /// - `ArgumentError` - Wrong number of bytes / hex chars / unsupported type
  @override
  ManagedByteArrayValue createValue(dynamic nativeValue) {
    if (nativeValue is List<int>) {
      return ManagedByteArrayValue(this, nativeValue);
    }
    if (nativeValue is String) {
      final String cleanHex = nativeValue.startsWith('0x')
          ? nativeValue.substring(2)
          : nativeValue;
      if (cleanHex.length != length * 2) {
        throw ArgumentError.value(
          nativeValue,
          'nativeValue',
          'ManagedByteArray<$length> hex must be ${length * 2} chars',
        );
      }
      return ManagedByteArrayValue(this, HexUtils.hexToBytes(cleanHex));
    }
    throw ArgumentError.value(
      nativeValue,
      'nativeValue',
      'ManagedByteArray requires List<int> or hex String',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManagedByteArrayType && other.length == length;

  @override
  int get hashCode => Object.hash('ManagedByteArray', length);

  @override
  String toString() => 'ManagedByteArray<$length>()';
}

/// ManagedByteArray value wrapping a `Uint8List` of the type's exact length.
@immutable
final class ManagedByteArrayValue extends TypedValue {
  /// Creates a ManagedByteArray value bound to `type`.
  ///
  /// #### Parameters
  /// - `type` - The owning `ManagedByteArrayType` (sets the fixed length)
  /// - `bytes` - Raw bytes, must satisfy `bytes.length == type.length`
  ///
  /// #### Throws
  /// - `ArgumentError` - If `bytes.length` does not match `type.length`
  ManagedByteArrayValue(ManagedByteArrayType super.type, List<int> bytes)
    : value = _validate(type, bytes);

  /// Raw bytes (length == `type.length`).
  final Uint8List value;

  static Uint8List _validate(ManagedByteArrayType type, List<int> bytes) {
    if (bytes.length != type.length) {
      throw ArgumentError.value(
        bytes,
        'bytes',
        'ManagedByteArray<${type.length}> requires exactly ${type.length} '
            'bytes, got ${bytes.length}',
      );
    }
    return Uint8List.fromList(bytes);
  }

  @override
  ManagedByteArrayType get type => super.type as ManagedByteArrayType;

  @override
  String get className => 'ManagedByteArrayValue';

  @override
  List<String> get classHierarchy => <String>[className, 'TypedValue'];

  @override
  Uint8List get nativeValue => value;

  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() => value;

  /// Hex string (no `0x` prefix).
  @override
  String toHex() => HexUtils.bytesToHex(value);

  @override
  String toString() => '0x${toHex()}';
}
