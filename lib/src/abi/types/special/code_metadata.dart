/// Code metadata type for smart contract deployment flags.
///
/// This module provides types for representing smart contract metadata flags
/// used during deployment and upgrade operations.
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../core/type_system.dart';

/// CodeMetadata type for smart contract metadata flags.
///
/// Represents 16-bit smart contract deployment metadata including upgradeable,
/// readable, payable, and payable-by-sc flags. Essential for contract deployment
/// and upgrade operations on MultiversX blockchain.
///
/// #### Example
/// ```dart
/// final type = CodeMetadataType.type;
///
/// // Create from integer flags (big-endian 2-byte format)
/// final metadata1 = type.createValue(0x0506); // All flags set
/// final metadata2 = type.createValue(0x0102); // Upgradeable + payable
///
/// // Create from byte array
/// final metadata3 = type.createValue([0x05, 0x06]);
///
/// // Check individual flags
/// final value = CodeMetadataType.create(0x0502);
/// print('Upgradeable: ${value.isUpgradeable}'); // true
/// print('Payable: ${value.isPayable}'); // true
/// print('Readable: ${value.isReadable}'); // true
///
/// // Binary encoding (2 bytes, big-endian)
/// final bytes = value.toBytes(); // [5, 2]
/// ```

@immutable
final class CodeMetadataType extends PrimitiveType {
  CodeMetadataType._() : super(name: 'CodeMetadata');
  static final CodeMetadataType _instance = CodeMetadataType._();

  @override
  int get sizeInBytes => 2;

  @override
  String get className => 'CodeMetadataType';

  @override
  List<String> get classHierarchy => <String>[
    className,
    'PrimitiveType',
    'AbiType',
  ];

  /// Creates CodeMetadataValue from integer or byte array.
  static CodeMetadataValue create(dynamic nativeValue) {
    if (nativeValue is int) {
      return CodeMetadataValue(nativeValue);
    }

    if (nativeValue is List<int>) {
      if (nativeValue.length != 2) {
        throw ArgumentError.value(
          nativeValue,
          'nativeValue',
          'CodeMetadataType requires exactly 2 bytes',
        );
      }
      final int value = (nativeValue[0] << 8) | nativeValue[1];
      return CodeMetadataValue(value);
    }

    throw ArgumentError.value(
      nativeValue,
      'nativeValue',
      'CodeMetadataType requires int or List<int> (2 bytes)',
    );
  }

  /// Gets the singleton type instance for use in type definitions.
  static CodeMetadataType get type => _instance;

  /// Creates CodeMetadataValue from integer or byte array.
  ///
  /// #### Parameters
  /// - `nativeValue` - Integer (0-65535) or 2-byte array
  ///
  /// #### Returns
  /// `CodeMetadataValue` - Instance with the metadata flags
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is invalid type or out of range
  ///
  /// #### Example
  /// ```dart
  /// final type = CodeMetadataType.type;
  ///
  /// // From integer flags (big-endian 2-byte format)
  /// final metadata1 = type.createValue(0x0102); // Upgradeable + payable
  /// final metadata2 = type.createValue(0x0502); // Upgradeable + readable + payable
  ///
  /// // From byte array (big-endian)
  /// final metadata3 = type.createValue([0x01, 0x02]);
  /// final metadata4 = type.createValue([0x05, 0x06]); // All flags
  ///
  /// // These throw: invalid input
  /// // final invalid1 = type.createValue([1, 2, 3]); // Wrong length
  /// // final invalid2 = type.createValue(65536); // Out of range
  /// ```
  @override
  CodeMetadataValue createValue(dynamic nativeValue) => create(nativeValue);
}

/// CodeMetadata value.
@immutable
final class CodeMetadataValue extends TypedValue {
  /// Creates CodeMetadata value with specific flags.
  ///
  /// #### Parameters
  /// - `flags` - Integer with combined metadata flags (0-65535)
  ///
  /// #### Throws
  /// - `ArgumentError` - If flags value is out of 16-bit range
  ///
  /// #### Example
  /// ```dart
  /// // Individual flag constants
  /// final upgradeable = CodeMetadataValue(CodeMetadataValue.upgradeableFlag);
  /// final payable = CodeMetadataValue(CodeMetadataValue.payableFlag);
  ///
  /// // Combined flags (big-endian 2-byte format)
  /// final combined = CodeMetadataValue(0x0502); // Upgradeable + payable + readable
  /// final allFlags = CodeMetadataValue(0x0506); // All flags enabled
  ///
  /// // Check individual properties
  /// print('Can upgrade: ${combined.isUpgradeable}'); // true
  /// print('Is payable: ${combined.isPayable}'); // true
  /// print('Bytes: ${combined.toBytes()}'); // [5, 2]
  /// ```
  CodeMetadataValue(this.flags) : super(CodeMetadataType._instance) {
    if (flags < 0 || flags > 0xFFFF) {
      throw ArgumentError.value(
        flags,
        'flags',
        'CodeMetadata must be 16-bit value (0-65535)',
      );
    }
  }

  /// Metadata flags as 16-bit value.
  final int flags;

  /// Upgradeable flag (byte 0, bit 0).
  static const int upgradeableFlag = 0x0100;

  /// Readable flag (byte 0, bit 2).
  static const int readableFlag = 0x0400;

  /// Payable flag (byte 1, bit 1).
  static const int payableFlag = 0x0002;

  /// Payable by smart contract flag (byte 1, bit 2).
  static const int payableBySCFlag = 0x0004;

  /// Whether contract is upgradeable.
  bool get isUpgradeable => (flags & upgradeableFlag) != 0;

  /// Whether contract is readable.
  bool get isReadable => (flags & readableFlag) != 0;

  /// Whether contract is payable.
  bool get isPayable => (flags & payableFlag) != 0;

  /// Whether contract is payable by smart contracts.
  bool get isPayableBySC => (flags & payableBySCFlag) != 0;

  @override
  String get className => 'CodeMetadataValue';

  @override
  List<String> get classHierarchy => <String>[className, 'TypedValue'];

  @override
  int get nativeValue => flags;

  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() =>
      (ByteData(2)..setUint16(0, flags, Endian.big)).buffer.asUint8List();

  @override
  String toString() {
    final List<String> props = <String>[];
    if (isUpgradeable) props.add('upgradeable');
    if (isReadable) props.add('readable');
    if (isPayable) props.add('payable');
    if (isPayableBySC) props.add('payable-by-sc');
    return 'CodeMetadata(${props.join(', ')})';
  }
}
