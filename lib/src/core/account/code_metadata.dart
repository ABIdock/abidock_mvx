/// Lightweight `CodeMetadata` model used by the network-layer account parsers.
///
/// Code metadata travels on the wire as a 2-byte big-endian bitmap. The
/// ABI-side counterpart is `CodeMetadataValue` in
/// `lib/src/abi/types/special/code_metadata.dart`; this class is the network /
/// account-snapshot view (no `TypedValue` baggage).
///
/// Byte layout (big-endian, 2 bytes):
/// - Byte 0 high nibble: `Upgradeable = 0x01_00`, `Readable = 0x04_00`.
/// - Byte 1: `Payable = 0x00_02`, `PayableBySc = 0x00_04`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Smart-contract code metadata flags as returned by Gateway / API.
///
/// #### Example
/// ```dart
/// final raw = base64.decode('BQQ='); // 0x05 0x04
/// final meta = CodeMetadata.fromBytes(Uint8List.fromList(raw));
/// print(meta.isUpgradeable); // true
/// print(meta.isReadable);    // true
/// print(meta.isPayableBySmartContract); // true
/// ```
@immutable
class CodeMetadata {
  /// Creates a `CodeMetadata` from boolean flags.
  ///
  /// #### Parameters
  /// - `isUpgradeable` - Contract is upgradeable.
  /// - `isReadable` - Contract storage is externally readable.
  /// - `isPayable` - Contract accepts plain EGLD transfers.
  /// - `isPayableBySmartContract` - Contract accepts SC-initiated transfers.
  const CodeMetadata({
    this.isUpgradeable = false,
    this.isReadable = false,
    this.isPayable = false,
    this.isPayableBySmartContract = false,
  });

  /// Upgradeable bit (byte 0, mask `0x01`).
  static const int upgradeableMask = 0x0100;

  /// Readable bit (byte 0, mask `0x04`).
  static const int readableMask = 0x0400;

  /// Payable bit (byte 1, mask `0x02`).
  static const int payableMask = 0x0002;

  /// Payable-by-smart-contract bit (byte 1, mask `0x04`).
  static const int payableBySmartContractMask = 0x0004;

  /// Whether the contract is upgradeable.
  final bool isUpgradeable;

  /// Whether the contract storage is externally readable.
  final bool isReadable;

  /// Whether the contract is payable from user accounts.
  final bool isPayable;

  /// Whether the contract is payable from other smart contracts.
  final bool isPayableBySmartContract;

  /// Parses a `CodeMetadata` from a 2-byte big-endian buffer.
  ///
  /// Accepts buffers of length 0, 1, or 2. Buffers shorter than 2 bytes are
  /// right-padded with zero bytes, since omitted trailing bytes carry no flags.
  ///
  /// #### Parameters
  /// - `bytes` - 0..2 byte big-endian bitmap.
  ///
  /// #### Returns
  /// `CodeMetadata` - decoded flags.
  ///
  /// #### Throws
  /// - `ArgumentError` - If `bytes.length > 2`.
  factory CodeMetadata.fromBytes(Uint8List bytes) {
    if (bytes.length > 2) {
      throw ArgumentError.value(
        bytes,
        'bytes',
        'CodeMetadata must be at most 2 bytes (got ${bytes.length})',
      );
    }
    final int b0 = bytes.isNotEmpty ? bytes[0] : 0;
    final int b1 = bytes.length > 1 ? bytes[1] : 0;
    final int flags = (b0 << 8) | b1;
    return CodeMetadata(
      isUpgradeable: (flags & upgradeableMask) != 0,
      isReadable: (flags & readableMask) != 0,
      isPayable: (flags & payableMask) != 0,
      isPayableBySmartContract: (flags & payableBySmartContractMask) != 0,
    );
  }

  /// Parses a `CodeMetadata` from its base64 wire representation.
  ///
  /// Returns `null` when `encoded` is `null` or empty (so callers can pass
  /// the raw Gateway field unchanged).
  ///
  /// #### Parameters
  /// - `encoded` - Base64 string from `codeMetadata` JSON field.
  ///
  /// #### Returns
  /// `CodeMetadata?` - Parsed flags, or `null` for missing/empty input.
  static CodeMetadata? tryParseBase64(String? encoded) {
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      final Uint8List bytes = base64.decode(encoded);
      return CodeMetadata.fromBytes(bytes);
    } on FormatException {
      return null;
    }
  }

  /// Encodes the flags into a canonical 2-byte big-endian buffer.
  ///
  /// #### Returns
  /// `Uint8List` - 2-byte big-endian representation suitable for the wire.
  Uint8List toBytes() {
    int flags = 0;
    if (isUpgradeable) flags |= upgradeableMask;
    if (isReadable) flags |= readableMask;
    if (isPayable) flags |= payableMask;
    if (isPayableBySmartContract) flags |= payableBySmartContractMask;
    final ByteData buf = ByteData(2)..setUint16(0, flags, Endian.big);
    return buf.buffer.asUint8List();
  }

  /// Encodes the flags as a base64 string (canonical wire form).
  String toBase64() => base64.encode(toBytes());

  @override
  String toString() {
    final List<String> flags = <String>[];
    if (isUpgradeable) flags.add('upgradeable');
    if (isReadable) flags.add('readable');
    if (isPayable) flags.add('payable');
    if (isPayableBySmartContract) flags.add('payable-by-sc');
    return 'CodeMetadata(${flags.join(', ')})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CodeMetadata &&
        other.isUpgradeable == isUpgradeable &&
        other.isReadable == isReadable &&
        other.isPayable == isPayable &&
        other.isPayableBySmartContract == isPayableBySmartContract;
  }

  @override
  int get hashCode => Object.hash(
    isUpgradeable,
    isReadable,
    isPayable,
    isPayableBySmartContract,
  );
}
