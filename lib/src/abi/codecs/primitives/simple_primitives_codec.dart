/// Binary codecs for simple primitive types.
import 'dart:convert';
import 'dart:typed_data';

import '../../../utils/sdk_exceptions.dart';
import '../../core/validation_mixin.dart';
import '../../types/primitives/address.dart';
import '../../types/primitives/boolean.dart';
import '../../types/primitives/bytes.dart';
import '../../types/primitives/string.dart';
import '../../types/special/code_metadata.dart';
import '../../types/special/h256.dart';
import '../../types/special/nothing.dart';
import '../../types/special/token_identifier.dart';
import '../../utils/binary_builder.dart';
import '../codec_base.dart';

/// Codec for Boolean values.
class BooleanBinaryCodec with ValidationMixin {
  const BooleanBinaryCodec();

  static Uint8List get _true => Uint8List.fromList(<int>[1]);
  static Uint8List get _false => Uint8List.fromList(<int>[0]);

  /// Decodes Boolean from top-level buffer (empty=false, non-empty=true).
  ///
  /// #### Parameters
  /// - `buffer` - Binary data (empty = false, any non-empty = true)
  ///
  /// #### Returns
  /// `BooleanValue` - The decoded boolean
  BooleanValue decodeTopLevel(Uint8List buffer) {
    if (buffer.isEmpty) {
      return BooleanValue(false);
    }
    return BooleanValue(buffer[0] != 0);
  }

  /// Decodes Boolean from nested position. Returns (value, bytesConsumed).
  ///
  /// #### Parameters
  /// - `buffer` - Buffer containing boolean byte
  /// - `offset` - Position of boolean byte
  ///
  /// #### Returns
  /// `(BooleanValue, int)` - Tuple of (value, always 1 byte consumed)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer too short
  (BooleanValue, int) decodeNested(Uint8List buffer, int offset) {
    requireOffsetWithBytes(buffer, offset, 1);
    return (BooleanValue(buffer[offset] != 0), 1);
  }

  /// Encodes Boolean for top-level (true=0x01, false=empty buffer).
  ///
  /// #### Parameters
  /// - `value` - Boolean value to encode
  ///
  /// #### Returns
  /// `Uint8List` - 0x01 for true, empty for false
  Uint8List encodeTopLevel(BooleanValue value) {
    return value.nativeValue ? _true : BinaryCodecUtils.emptyBuffer;
  }

  /// Encodes Boolean for nested (true=0x01, false=0x00, always 1 byte).
  ///
  /// #### Parameters
  /// - `value` - Boolean value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Single byte 0x01 or 0x00
  Uint8List encodeNested(BooleanValue value) {
    return value.nativeValue ? _true : _false;
  }
}

/// Codec for Address values (32 bytes).
class AddressBinaryCodec with ValidationMixin {
  const AddressBinaryCodec();

  /// Decodes Address from top-level buffer.
  ///
  /// #### Parameters
  /// - `buffer` - Must be exactly 32 bytes
  ///
  /// #### Returns
  /// `AddressValue` - 32-byte address
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer is not exactly 32 bytes
  AddressValue decodeTopLevel(Uint8List buffer) {
    requireExactLength(buffer, 32, 'Address');
    return AddressValue(buffer);
  }

  /// Decodes Address from nested position. Returns (value, bytesConsumed).
  ///
  /// #### Parameters
  /// - `buffer` - Buffer containing 32-byte address
  /// - `offset` - Starting position
  ///
  /// #### Returns
  /// `(AddressValue, int)` - Tuple of (address, always 32 bytes consumed)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If insufficient bytes remain
  (AddressValue, int) decodeNested(Uint8List buffer, int offset) {
    requireBufferLength(buffer, offset, 32, 'Address');
    final Uint8List addressBytes = buffer.sublist(offset, offset + 32);
    return (AddressValue(addressBytes), 32);
  }

  /// Encodes Address for top-level.
  ///
  /// #### Parameters
  /// - `value` - Address value (must have 32 bytes)
  ///
  /// #### Returns
  /// `Uint8List` - 32-byte buffer
  Uint8List encodeTopLevel(AddressValue value) {
    return Uint8List.fromList(value.toBytes());
  }

  /// Encodes Address for nested.
  ///
  /// #### Parameters
  /// - `value` - Address value (must have 32 bytes)
  ///
  /// #### Returns
  /// `Uint8List` - 32-byte buffer
  Uint8List encodeNested(AddressValue value) {
    return encodeTopLevel(value);
  }
}

/// Codec for String values.
class StringBinaryCodec with ValidationMixin {
  const StringBinaryCodec();

  /// Decodes String from top-level buffer (no length prefix).
  ///
  /// #### Parameters
  /// - `buffer` - UTF-8 encoded string bytes
  ///
  /// #### Returns
  /// `StringValue` - Decoded string
  StringValue decodeTopLevel(Uint8List buffer) {
    final String str = utf8.decode(buffer);
    return StringValue(str);
  }

  /// Decodes String from nested position (4-byte length prefix).
  ///
  /// #### Parameters
  /// - `buffer` - Buffer with length prefix + UTF-8 bytes
  /// - `offset` - Starting position
  ///
  /// #### Returns
  /// `(StringValue, int)` - Tuple of (string, bytes consumed)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer too short
  (StringValue, int) decodeNested(Uint8List buffer, int offset) {
    final (int length, int lengthBytes) = BinaryCodecUtils.readLength(
      buffer,
      offset,
    );
    final int endOffset = offset + lengthBytes + length;

    requireEndOffset(buffer, offset, lengthBytes + length, 'String');

    final Uint8List stringBytes = buffer.sublist(
      offset + lengthBytes,
      endOffset,
    );
    final String str = utf8.decode(stringBytes, allowMalformed: true);
    return (StringValue(str), lengthBytes + length);
  }

  /// Encodes String for top-level (no length prefix).
  ///
  /// #### Parameters
  /// - `value` - String value to encode
  ///
  /// #### Returns
  /// `Uint8List` - UTF-8 encoded bytes
  Uint8List encodeTopLevel(StringValue value) {
    return Uint8List.fromList(utf8.encode(value.nativeValue));
  }

  /// Encodes String for nested (4-byte length prefix).
  ///
  /// #### Parameters
  /// - `value` - String value to encode
  ///
  /// #### Returns
  /// `Uint8List` - 4-byte big-endian length + UTF-8 bytes
  Uint8List encodeNested(StringValue value) {
    final Uint8List stringBytes = Uint8List.fromList(
      utf8.encode(value.nativeValue),
    );
    return (BinaryBuilder()
          ..addU32(stringBytes.length)
          ..addBytes(stringBytes))
        .toBytes();
  }
}

/// Codec for Bytes values.
class BytesBinaryCodec with ValidationMixin {
  const BytesBinaryCodec();

  /// Decodes Bytes from top-level buffer (no length prefix).
  ///
  /// #### Parameters
  /// - `buffer` - Raw bytes
  ///
  /// #### Returns
  /// `BytesValue` - Wrapping the buffer
  BytesValue decodeTopLevel(Uint8List buffer) {
    return BytesValue(buffer);
  }

  /// Decodes Bytes from nested position (4-byte length prefix).
  ///
  /// #### Parameters
  /// - `buffer` - Buffer with length + bytes
  /// - `offset` - Starting position
  ///
  /// #### Returns
  /// `(BytesValue, int)` - Tuple of (bytes, bytes consumed)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer too short
  (BytesValue, int) decodeNested(Uint8List buffer, int offset) {
    final (int length, int lengthBytes) = BinaryCodecUtils.readLength(
      buffer,
      offset,
    );
    final int endOffset = offset + lengthBytes + length;

    requireEndOffset(buffer, offset, lengthBytes + length, 'Bytes');

    final Uint8List bytes = buffer.sublist(offset + lengthBytes, endOffset);
    return (BytesValue(bytes), lengthBytes + length);
  }

  /// Encodes Bytes for top-level (no length prefix).
  ///
  /// #### Parameters
  /// - `value` - Bytes value
  ///
  /// #### Returns
  /// `Uint8List` - Raw bytes
  Uint8List encodeTopLevel(BytesValue value) {
    return Uint8List.fromList(value.nativeValue);
  }

  /// Encodes Bytes for nested (4-byte length prefix).
  ///
  /// #### Parameters
  /// - `value` - Bytes value
  ///
  /// #### Returns
  /// `Uint8List` - 4-byte length + raw bytes
  Uint8List encodeNested(BytesValue value) {
    final Uint8List bytes = Uint8List.fromList(value.nativeValue);
    return (BinaryBuilder()
          ..addU32(bytes.length)
          ..addBytes(bytes))
        .toBytes();
  }
}

/// Codec for Nothing values (empty/void type).
class NothingBinaryCodec with ValidationMixin {
  const NothingBinaryCodec();

  /// Decodes Nothing from top-level buffer (always empty).
  ///
  /// #### Returns
  /// `NothingValue`
  NothingValue decodeTopLevel(Uint8List buffer) {
    return NothingValue();
  }

  /// Decodes Nothing from nested position. Returns (value, bytesConsumed).
  ///
  /// #### Parameters
  /// - `buffer` - Buffer (unused for Nothing type)
  /// - `offset` - Offset position (unused for Nothing type)
  ///
  /// #### Returns
  /// `(NothingValue, int)` - Tuple of (NothingValue, 0 bytes consumed)
  (NothingValue, int) decodeNested(Uint8List buffer, int offset) {
    return (NothingValue(), 0);
  }

  /// Encodes Nothing for top-level (empty buffer).
  ///
  /// #### Parameters
  /// - `value` - Nothing value (ignored)
  ///
  /// #### Returns
  /// `Uint8List` - Empty buffer
  Uint8List encodeTopLevel(NothingValue value) {
    return BinaryCodecUtils.emptyBuffer;
  }

  /// Encodes Nothing for nested (empty buffer).
  ///
  /// #### Parameters
  /// - `value` - Nothing value (ignored)
  ///
  /// #### Returns
  /// `Uint8List` - Empty buffer
  Uint8List encodeNested(NothingValue value) {
    return BinaryCodecUtils.emptyBuffer;
  }
}

/// Codec for TokenIdentifier values.
class TokenIdentifierBinaryCodec with ValidationMixin {
  const TokenIdentifierBinaryCodec();

  /// Decodes TokenIdentifier from top-level buffer (no length prefix).
  ///
  /// #### Parameters
  /// - `buffer` - ASCII/UTF-8 encoded identifier
  ///
  /// #### Returns
  /// `TokenIdentifierValue` - Decoded identifier
  TokenIdentifierValue decodeTopLevel(Uint8List buffer) {
    final String identifier = utf8.decode(buffer);
    return TokenIdentifierValue(identifier);
  }

  /// Decodes EgldOrEsdtTokenIdentifier from top-level buffer.
  ///
  /// #### Parameters
  /// - `buffer` - ASCII/UTF-8 encoded identifier
  ///
  /// #### Returns
  /// `EgldOrEsdtTokenIdentifierValue` - Decoded identifier
  EgldOrEsdtTokenIdentifierValue decodeTopLevelAsEgldOrEsdt(Uint8List buffer) {
    final String identifier = utf8.decode(buffer);
    return EgldOrEsdtTokenIdentifierValue(identifier);
  }

  /// Decodes TokenIdentifier from nested position (4-byte length prefix).
  ///
  /// #### Parameters
  /// - `buffer` - Buffer with length + identifier bytes
  /// - `offset` - Starting position
  ///
  /// #### Returns
  /// `(TokenIdentifierValue, int)` - Tuple of (identifier, bytes consumed)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer too short
  (TokenIdentifierValue, int) decodeNested(Uint8List buffer, int offset) {
    final (int length, int lengthBytes) = BinaryCodecUtils.readLength(
      buffer,
      offset,
    );
    final int endOffset = offset + lengthBytes + length;

    requireEndOffset(buffer, offset, lengthBytes + length, 'TokenIdentifier');

    final Uint8List identifierBytes = buffer.sublist(
      offset + lengthBytes,
      endOffset,
    );
    final String identifier = utf8.decode(identifierBytes);
    return (TokenIdentifierValue(identifier), lengthBytes + length);
  }

  /// Decodes EgldOrEsdtTokenIdentifier from nested position.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer with length + identifier bytes
  /// - `offset` - Starting position
  ///
  /// #### Returns
  /// `(EgldOrEsdtTokenIdentifierValue, int)` - Tuple of (identifier, bytes consumed)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer too short
  (EgldOrEsdtTokenIdentifierValue, int) decodeNestedAsEgldOrEsdt(
    Uint8List buffer,
    int offset,
  ) {
    final (int length, int lengthBytes) = BinaryCodecUtils.readLength(
      buffer,
      offset,
    );
    final int endOffset = offset + lengthBytes + length;

    requireEndOffset(
      buffer,
      offset,
      lengthBytes + length,
      'EgldOrEsdtTokenIdentifier',
    );

    final Uint8List identifierBytes = buffer.sublist(
      offset + lengthBytes,
      endOffset,
    );
    final String identifier = utf8.decode(identifierBytes);
    return (EgldOrEsdtTokenIdentifierValue(identifier), lengthBytes + length);
  }

  /// Encodes TokenIdentifier for top-level (no length prefix).
  ///
  /// #### Parameters
  /// - `value` - Token identifier value
  ///
  /// #### Returns
  /// `Uint8List` - ASCII/UTF-8 bytes of identifier
  Uint8List encodeTopLevel(TokenIdentifierValue value) {
    return Uint8List.fromList(utf8.encode(value.identifier));
  }

  /// Encodes EgldOrEsdtTokenIdentifier for top-level (no length prefix).
  ///
  /// #### Parameters
  /// - `value` - EGLD or ESDT token identifier
  ///
  /// #### Returns
  /// `Uint8List` - ASCII/UTF-8 bytes
  Uint8List encodeTopLevelEgldOrEsdt(EgldOrEsdtTokenIdentifierValue value) {
    return Uint8List.fromList(utf8.encode(value.identifier));
  }

  /// Encodes TokenIdentifier for nested (4-byte length prefix).
  ///
  /// #### Parameters
  /// - `value` - Token identifier value
  ///
  /// #### Returns
  /// `Uint8List` - 4-byte length + ASCII/UTF-8 bytes
  Uint8List encodeNested(TokenIdentifierValue value) {
    final Uint8List identifierBytes = Uint8List.fromList(
      utf8.encode(value.identifier),
    );
    return (BinaryBuilder()
          ..addU32(identifierBytes.length)
          ..addBytes(identifierBytes))
        .toBytes();
  }

  /// Encodes EgldOrEsdtTokenIdentifier for nested (4-byte length prefix).
  ///
  /// #### Parameters
  /// - `value` - EGLD or ESDT token identifier
  ///
  /// #### Returns
  /// `Uint8List` - 4-byte length + ASCII/UTF-8 bytes
  Uint8List encodeNestedEgldOrEsdt(EgldOrEsdtTokenIdentifierValue value) {
    final Uint8List identifierBytes = Uint8List.fromList(
      utf8.encode(value.identifier),
    );
    return (BinaryBuilder()
          ..addU32(identifierBytes.length)
          ..addBytes(identifierBytes))
        .toBytes();
  }
}

/// Codec for H256 (32-byte hash) values.
///
/// H256 is a fixed 32-byte type used for transaction hashes, block hashes,
/// and other cryptographic identifiers on MultiversX.
class H256BinaryCodec with ValidationMixin {
  const H256BinaryCodec();

  /// Size of H256 in bytes.
  static const int hashLength = 32;

  /// Decodes H256 from top-level buffer.
  ///
  /// #### Parameters
  /// - `buffer` - Binary data (must be exactly 32 bytes)
  ///
  /// #### Returns
  /// `H256Value` - The decoded hash
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer length is not 32
  H256Value decodeTopLevel(Uint8List buffer) {
    if (buffer.length != hashLength) {
      throw AbiBinaryCodecException(
        'H256 requires exactly $hashLength bytes, got ${buffer.length}',
      );
    }
    return H256Value(buffer);
  }

  /// Decodes H256 from nested position. Returns (value, bytesConsumed).
  ///
  /// #### Parameters
  /// - `buffer` - Buffer containing hash
  /// - `offset` - Starting position of hash
  ///
  /// #### Returns
  /// `(H256Value, int)` - Tuple of (value, 32 bytes consumed)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer too short
  (H256Value, int) decodeNested(Uint8List buffer, int offset) {
    requireOffsetWithBytes(buffer, offset, hashLength);
    final Uint8List hashBytes = Uint8List.sublistView(
      buffer,
      offset,
      offset + hashLength,
    );
    return (H256Value(hashBytes), hashLength);
  }

  /// Encodes H256 for top-level (raw 32 bytes).
  ///
  /// #### Parameters
  /// - `value` - H256 value
  ///
  /// #### Returns
  /// `Uint8List` - 32-byte hash
  Uint8List encodeTopLevel(H256Value value) {
    return value.value;
  }

  /// Encodes H256 for nested (raw 32 bytes, no length prefix needed).
  ///
  /// #### Parameters
  /// - `value` - H256 value
  ///
  /// #### Returns
  /// `Uint8List` - 32-byte hash
  Uint8List encodeNested(H256Value value) {
    return value.value;
  }
}

/// Codec for CodeMetadata (2-byte flags) values.
///
/// CodeMetadata represents smart contract deployment flags as a 16-bit value.
/// Used for specifying contract properties like upgradeable, payable, readable.
class CodeMetadataBinaryCodec with ValidationMixin {
  const CodeMetadataBinaryCodec();

  /// Size of CodeMetadata in bytes.
  static const int metadataLength = 2;

  /// Decodes CodeMetadata from top-level buffer.
  ///
  /// #### Parameters
  /// - `buffer` - Binary data (must be exactly 2 bytes)
  ///
  /// #### Returns
  /// `CodeMetadataValue` - The decoded metadata
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer length is not 2
  CodeMetadataValue decodeTopLevel(Uint8List buffer) {
    if (buffer.length != metadataLength) {
      throw AbiBinaryCodecException(
        'CodeMetadata requires exactly $metadataLength bytes, got ${buffer.length}',
      );
    }
    final int flags = (buffer[0] << 8) | buffer[1];
    return CodeMetadataValue(flags);
  }

  /// Decodes CodeMetadata from nested position. Returns (value, bytesConsumed).
  ///
  /// #### Parameters
  /// - `buffer` - Buffer containing metadata
  /// - `offset` - Starting position of metadata
  ///
  /// #### Returns
  /// `(CodeMetadataValue, int)` - Tuple of (value, 2 bytes consumed)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer too short
  (CodeMetadataValue, int) decodeNested(Uint8List buffer, int offset) {
    requireOffsetWithBytes(buffer, offset, metadataLength);
    final int flags = (buffer[offset] << 8) | buffer[offset + 1];
    return (CodeMetadataValue(flags), metadataLength);
  }

  /// Encodes CodeMetadata for top-level (2 bytes, big-endian).
  ///
  /// #### Parameters
  /// - `value` - CodeMetadata value
  ///
  /// #### Returns
  /// `Uint8List` - 2-byte flags
  Uint8List encodeTopLevel(CodeMetadataValue value) {
    return Uint8List.fromList(value.toBytes());
  }

  /// Encodes CodeMetadata for nested (2 bytes, big-endian).
  ///
  /// #### Parameters
  /// - `value` - CodeMetadata value
  ///
  /// #### Returns
  /// `Uint8List` - 2-byte flags
  Uint8List encodeNested(CodeMetadataValue value) {
    return Uint8List.fromList(value.toBytes());
  }
}
