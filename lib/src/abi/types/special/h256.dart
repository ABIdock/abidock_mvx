import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../utils/hex_utils.dart';

import '../../core/type_system.dart';

/// H256 type for 256-bit hashes (32 bytes).
///
/// Represents 256-bit cryptographic hashes like transaction hashes,
/// block hashes, or state hashes. Fixed size of 32 bytes.
///
/// #### Example
/// ```dart
/// // Factory method usage
/// final hash1 = H256Type.create([0, 1, 2, /* ...32 bytes... */]);
/// final hash2 = H256Type.create('0x0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20');
///
/// // Singleton type access
/// final structType = StructType(
///   name: 'TxRecord',
///   fieldDefinitions: [
///     FieldDefinition(name: 'txHash', type: H256Type.type),
///   ],
/// );
///
/// // Value operations
/// print(hash1.nativeValue); // hex representation
/// print(hash1.toBytes().length); // 32
/// ```
@immutable
final class H256Type extends PrimitiveType {
  H256Type._() : super(name: 'H256');
  static final H256Type _instance = H256Type._();

  /// Size in bytes (32).
  static const int hashLength = 32;

  @override
  int get sizeInBytes => hashLength;

  @override
  String get className => 'H256Type';

  static const List<String> _classHierarchy = [
    'H256Type',
    'PrimitiveType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  /// Creates H256Value from bytes or hex string.
  static H256Value create(dynamic nativeValue) {
    if (nativeValue is List<int>) {
      return H256Value(nativeValue);
    }

    if (nativeValue is String) {
      return H256Value.fromHex(nativeValue);
    }

    throw ArgumentError.value(
      nativeValue,
      'nativeValue',
      'H256Type requires List<int> (32 bytes) or hex string',
    );
  }

  /// Gets the singleton type instance for use in type definitions.
  static H256Type get type => _instance;

  /// Creates H256Value from bytes or hex string.
  ///
  /// #### Parameters
  /// - `nativeValue` - `List<int>` (32 bytes) or String (64-char hex)
  ///
  /// #### Returns
  /// `H256Value` - Instance with the data
  ///
  /// #### Throws
  /// - `ArgumentError` - If not `List<int>` or String
  /// - `ArgumentError` - If bytes length != 32 or hex length != 64
  ///
  /// #### Example
  /// ```dart
  /// // From bytes
  /// final hash1 = H256Type.create(List<int>.filled(32, 0));
  ///
  /// // From hex
  /// final hash2 = H256Type.create(
  ///   '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'
  /// );
  /// ```
  @override
  H256Value createValue(dynamic nativeValue) => create(nativeValue);
}

/// H256 value for 256-bit hash.
///
/// Holds a 32-byte cryptographic hash. Provides hex conversion and
/// validation. Commonly used for transaction/block identifiers.
///
/// #### Example
/// ```dart
/// // From bytes
/// final hash1 = H256Value(List<int>.filled(32, 0));
///
/// // From hex (with or without 0x prefix)
/// final hash2 = H256Value.fromHex(
///   '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'
/// );
///
/// print(hash2.toHex()); // Without 0x prefix
/// print(hash2.toHexWithPrefix()); // With 0x prefix
/// ```
@immutable
final class H256Value extends TypedValue {
  /// Creates H256 value.
  H256Value(List<int> value)
    : value = _validateAndConvert(value),
      super(H256Type._instance);

  /// Creates H256 value from hex string.
  factory H256Value.fromHex(String hex) {
    final String cleanHex = hex.startsWith('0x') ? hex.substring(2) : hex;
    if (cleanHex.length != 64) {
      throw ArgumentError.value(
        hex,
        'hex',
        'H256 hex string must be 64 characters (32 bytes)',
      );
    }

    return H256Value(HexUtils.hexToBytes(cleanHex));
  }

  /// Hash bytes (32 bytes).
  final Uint8List value;

  static Uint8List _validateAndConvert(List<int> value) {
    if (value.length != H256Type.hashLength) {
      throw ArgumentError.value(
        value,
        'value',
        'H256 must be exactly ${H256Type.hashLength} bytes',
      );
    }
    return Uint8List.fromList(value);
  }

  @override
  String get className => 'H256Value';

  @override
  List<String> get classHierarchy => <String>[className, 'TypedValue'];

  @override
  Uint8List get nativeValue => value;

  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() => value;

  /// Hex representation of hash.
  @override
  String toHex() => HexUtils.bytesToHex(value);

  /// Hex representation with 0x prefix.
  String toHexWithPrefix() => '0x${toHex()}';

  @override
  String toString() => toHexWithPrefix();
}
