/// Protocol Buffer serializer for MultiversX transactions.
/// Produces the exact Protocol Buffer encoding the chain hashes to derive a
/// transaction hash.
import 'dart:convert';
import 'dart:typed_data';

import '../../utils/hex_utils.dart';
import '../nonce.dart';
import 'transaction.dart';
import 'transaction_constants.dart';

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
  /// The transaction message on the wire defines fields **1-17 only**, the
  /// last two being the relayer address and the relayer signature. No tag
  /// beyond 17 may ever be written: the chain's schema does not declare one,
  /// so an unknown tag would produce a Blake2b hash that disagrees with the
  /// network and the transaction would be rejected.
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
      _writeBytesField(
        buffer,
        4,
        _encodeUsername(transaction.receiverUsername),
      );
    }

    _writeBytesField(buffer, 5, Uint8List.fromList(transaction.sender.bytes));

    if (transaction.senderUsername.isNotEmpty) {
      _writeBytesField(buffer, 6, _encodeUsername(transaction.senderUsername));
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

    if (_isGuardedTransaction(transaction)) {
      _writeBytesField(
        buffer,
        14,
        Uint8List.fromList(transaction.guardian!.bytes),
      );
      _writeBytesField(buffer, 15, transaction.guardianSignature.toUint8List());
    }

    if (transaction.relayer != null && !transaction.relayer!.isEmpty) {
      _writeBytesField(
        buffer,
        16,
        Uint8List.fromList(transaction.relayer!.bytes),
      );
      if (transaction.relayerSignature.isNotEmpty) {
        _writeBytesField(
          buffer,
          17,
          transaction.relayerSignature.toUint8List(),
        );
      }
    }

    return buffer.toBytes();
  }

  static bool _isGuardedTransaction(Transaction tx) {
    final bool hasFlag =
        (tx.options & transactionOptionsTxGuarded) ==
        transactionOptionsTxGuarded;
    final bool hasGuardian = tx.guardian != null && !tx.guardian!.isEmpty;
    final bool hasSignature = tx.guardianSignature.isNotEmpty;
    return hasFlag && hasGuardian && hasSignature;
  }

  /// Encodes a herotag username as base64 string bytes.
  ///
  /// The username field on the wire holds the ASCII of the base64 encoding of
  /// the herotag, not the raw UTF-8 username. Encoding it any other way makes
  /// hash-signed transactions with herotags fail verification on-chain.
  ///
  /// #### Parameters
  /// - `username` - Non-empty herotag value
  ///
  /// #### Returns
  /// `Uint8List` - UTF-8 bytes of the base64 representation of the username
  Uint8List _encodeUsername(String username) {
    final String base64Username = base64.encode(utf8.encode(username));
    return Uint8List.fromList(utf8.encode(base64Username));
  }

  /// Serializes the transaction value in the chain's sign & magnitude form:
  /// a leading sign byte (`0x00` for non-negative) followed by the big-endian
  /// magnitude, with zero encoded as `[0x00, 0x00]`.
  ///
  /// #### Parameters
  /// - `value` - Non-negative amount in atomic units
  ///
  /// #### Returns
  /// `Uint8List` - Sign byte followed by the big-endian magnitude
  ///
  /// #### Throws
  /// - `ArgumentError` - When `value` is negative
  Uint8List _serializeValue(BigInt value) {
    if (value.isNegative) {
      throw ArgumentError('Transaction value cannot be negative: $value');
    }
    if (value == BigInt.zero) {
      return Uint8List.fromList([0x00, 0x00]);
    }

    final String hexString = value.toRadixString(16);
    final String paddedHex = hexString.length.isOdd ? '0$hexString' : hexString;
    final Uint8List magnitudeBytes = HexUtils.hexToBytes(paddedHex);

    return Uint8List.fromList([0x00, ...magnitudeBytes]);
  }

  void _writeVarintField(BytesBuilder buffer, int fieldNumber, int value) {
    final int key = (fieldNumber << 3) | _WireType.varint;
    _writeVarint(buffer, BigInt.from(key));
    _writeVarint(buffer, BigInt.from(value));
  }

  void _writeBytesField(BytesBuilder buffer, int fieldNumber, Uint8List data) {
    final int key = (fieldNumber << 3) | _WireType.lengthDelimited;
    _writeVarint(buffer, BigInt.from(key));
    _writeVarint(buffer, BigInt.from(data.length));
    buffer.add(data);
  }

  void _writeVarint(BytesBuilder buffer, BigInt value) {
    if (value.isNegative) {
      throw ArgumentError.value(
        value,
        'value',
        'Varint encoding requires non-negative value',
      );
    }
    final BigInt continuation = BigInt.from(0x80);
    final BigInt low7 = BigInt.from(0x7F);
    BigInt v = value;
    while (v >= continuation) {
      buffer.addByte(((v & low7) | continuation).toInt());
      v = v >> 7;
    }
    buffer.addByte((v & low7).toInt());
  }
}
