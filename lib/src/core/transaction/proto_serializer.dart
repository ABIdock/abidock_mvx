/// Protocol Buffer serializer for MultiversX transactions.
/// Serializes transactions to Protocol Buffer format compatible with mx-chain-go.
import 'dart:convert';
import 'dart:typed_data';

import '../../utils/hex_utils.dart';
import '../nonce.dart';
import 'transaction.dart';

/// Protocol Buffer wire types used in encoding.
/// Uses varint for integers, length-delimited for bytes/strings/messages.
class _WireType {
  /// Varint wire type (0) for integers.
  static const int varint = 0;

  /// Length-delimited wire type (2) for bytes/strings.
  static const int lengthDelimited = 2;
}

/// Protocol Buffer serializer for transactions.
/// Encodes transactions to protobuf format for MultiversX blockchain nodes.
class ProtoSerializer {
  /// Creates protocol buffer serializer instance.
  const ProtoSerializer();

  /// Serializes transaction to Protocol Buffer binary format.
  ///
  /// #### Parameters
  /// - `transaction` - Transaction to serialize
  ///
  /// #### Returns
  /// `Uint8List` - Protobuf-encoded transaction bytes
  ///
  /// #### Example
  /// ```dart
  /// final serializer = ProtoSerializer();
  /// final protoBytes = serializer.serializeTransaction(transaction);
  /// print('Protobuf size: ${protoBytes.length} bytes');
  /// ```
  Uint8List serializeTransaction(Transaction transaction) {
    final BytesBuilder buffer = BytesBuilder();

    if (transaction.nonce != const Nonce.zero()) {
      _writeVarintField(buffer, 1, transaction.nonce.value);
    }

    final Uint8List valueBytes = _serializeValue(transaction.value.value);
    _writeBytesField(buffer, 2, valueBytes);

    _writeBytesField(buffer, 3, Uint8List.fromList(transaction.receiver.bytes));

    if (transaction.receiverUsername.isNotEmpty) {
      final Uint8List usernameBytes = Uint8List.fromList(
        utf8.encode(transaction.receiverUsername),
      );
      _writeBytesField(buffer, 4, usernameBytes);
    }

    _writeBytesField(buffer, 5, Uint8List.fromList(transaction.sender.bytes));

    if (transaction.senderUsername.isNotEmpty) {
      final Uint8List usernameBytes = Uint8List.fromList(
        utf8.encode(transaction.senderUsername),
      );
      _writeBytesField(buffer, 6, usernameBytes);
    }

    _writeVarintField(buffer, 7, transaction.gasPrice.value);

    _writeVarintField(buffer, 8, transaction.gasLimit.value);

    if (transaction.data.isNotEmpty) {
      _writeBytesField(buffer, 9, transaction.data);
    }

    final Uint8List chainIdBytes = Uint8List.fromList(
      utf8.encode(transaction.chainId.value),
    );
    _writeBytesField(buffer, 10, chainIdBytes);

    _writeVarintField(buffer, 11, transaction.version.value);

    if (transaction.signature.isNotEmpty) {
      _writeBytesField(buffer, 12, transaction.signature.toUint8List());
    }

    if (transaction.options != 0) {
      _writeVarintField(buffer, 13, transaction.options);
    }

    if (transaction.guardian != null && !transaction.guardian!.isEmpty) {
      _writeBytesField(
        buffer,
        14,
        Uint8List.fromList(transaction.guardian!.bytes),
      );
    }

    if (transaction.guardianSignature.isNotEmpty) {
      _writeBytesField(buffer, 15, transaction.guardianSignature.toUint8List());
    }

    if (transaction.relayer != null && !transaction.relayer!.isEmpty) {
      _writeBytesField(
        buffer,
        16,
        Uint8List.fromList(transaction.relayer!.bytes),
      );
    }
    if (transaction.relayerSignature.isNotEmpty) {
      _writeBytesField(buffer, 17, transaction.relayerSignature.toUint8List());
    }

    return buffer.toBytes();
  }

  /// Serializes transaction value using sign & magnitude format.
  ///
  /// Uses custom sign & magnitude format (sign byte + big-endian magnitude).
  ///
  /// #### Parameters
  /// - `value` - BigInt value to serialize
  ///
  /// #### Returns
  /// `Uint8List` - Serialized value in sign & magnitude format
  ///
  /// #### Example
  /// ```dart
  /// // Zero: [0x00, 0x00]
  /// final zero = _serializeValue(BigInt.zero);
  ///
  /// // 255: [0x00, 0xff]
  /// final small = _serializeValue(BigInt.from(255));
  ///
  /// // 65535: [0x00, 0xff, 0xff]
  /// final large = _serializeValue(BigInt.from(65535));
  /// ```
  Uint8List _serializeValue(BigInt value) {
    if (value == BigInt.zero) {
      return Uint8List.fromList([0x00, 0x00]);
    }

    final String hexString = value.toRadixString(16);
    final String paddedHex = hexString.length.isOdd ? '0$hexString' : hexString;
    final Uint8List magnitudeBytes = HexUtils.hexToBytes(paddedHex);

    return Uint8List.fromList([0x00, ...magnitudeBytes]);
  }

  /// Writes varint field.
  void _writeVarintField(BytesBuilder buffer, int fieldNumber, int value) {
    final int key = (fieldNumber << 3) | _WireType.varint;
    _writeVarint(buffer, key);

    _writeVarint(buffer, value);
  }

  /// Writes length-delimited field.
  void _writeBytesField(BytesBuilder buffer, int fieldNumber, Uint8List data) {
    final int key = (fieldNumber << 3) | _WireType.lengthDelimited;
    _writeVarint(buffer, key);

    _writeVarint(buffer, data.length);

    buffer.add(data);
  }

  void _writeVarint(BytesBuilder buffer, int value) {
    if (value < 0) {
      throw ArgumentError.value(
        value,
        'value',
        'Varint encoding requires non-negative value',
      );
    }
    while (value >= 0x80) {
      buffer.addByte((value & 0x7F) | 0x80);
      value >>= 7;
    }
    buffer.addByte(value & 0x7F);
  }
}
