/// Binary codec base types and utilities.
import 'dart:typed_data';

import '../../utils/hex_utils.dart';
import '../../utils/sdk_exceptions.dart';
import '../core/type_system.dart';

/// Constraints for binary codec operations to prevent resource exhaustion.
class BinaryCodecConstraints {
  BinaryCodecConstraints._();

  /// Maximum buffer length (256KB).
  static const int maxBufferLength = 256000;

  /// Maximum list length (128K items).
  static const int maxListLength = 128000;

  /// Maximum recursion depth.
  static const int maxRecursionDepth = 32;

  /// Checks if buffer length is within limits.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer to validate
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer exceeds 256KB
  static void checkBufferLength(Uint8List buffer) {
    if (buffer.length > maxBufferLength) {
      throw AbiBinaryCodecException(
        'Buffer too large: ${buffer.length} exceeds maximum $maxBufferLength',
      );
    }
  }

  /// Checks if list length is within limits.
  ///
  /// #### Parameters
  /// - `length` - List length to validate
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If length exceeds 128K items
  static void checkListLength(int length) {
    if (length > maxListLength) {
      throw AbiBinaryCodecException(
        'List too large: $length exceeds maximum $maxListLength',
      );
    }
  }

  /// Checks if recursion depth is within limits.
  ///
  /// #### Parameters
  /// - `depth` - Current recursion depth
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If depth exceeds 32 levels
  static void checkRecursionDepth(int depth) {
    if (depth > maxRecursionDepth) {
      throw AbiBinaryCodecException(
        'Recursion depth $depth exceeds maximum $maxRecursionDepth',
      );
    }
  }
}

/// Utility functions for binary codec operations.
class BinaryCodecUtils {
  BinaryCodecUtils._();
  static final Uint8List emptyBuffer = Uint8List(0);

  /// Reads 4-byte big-endian length from buffer at offset.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer containing length field
  /// - `offset` - Starting position
  ///
  /// #### Returns
  /// `(int, int)` - Decoded length and bytes consumed
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer too short
  static (int, int) readLength(Uint8List buffer, int offset) {
    if (buffer.length - offset < 4) {
      throw AbiBinaryCodecException(
        'Buffer too short for length field at offset $offset',
      );
    }

    final int length = ByteData.sublistView(
      buffer,
      offset,
      offset + 4,
    ).getUint32(0, Endian.big);

    if (length > BinaryCodecConstraints.maxBufferLength) {
      throw AbiBinaryCodecException(
        'Length $length exceeds maximum allowed ${BinaryCodecConstraints.maxBufferLength}',
      );
    }

    return (length, 4);
  }

  /// Writes 4-byte big-endian length.
  ///
  /// #### Parameters
  /// - `length` - Length value to encode
  ///
  /// #### Returns
  /// `Uint8List` - 4-byte encoded length
  static Uint8List writeLength(int length) {
    final Uint8List bytes = Uint8List(4);
    ByteData.sublistView(bytes).setUint32(0, length, Endian.big);
    return bytes;
  }

  /// Concatenates multiple buffers into one.
  ///
  /// #### Parameters
  /// - `buffers` - List of buffers to concatenate
  ///
  /// #### Returns
  /// `Uint8List` - Single buffer containing all buffers
  static Uint8List concat(List<Uint8List> buffers) {
    final int totalLength = buffers.fold<int>(
      0,
      (int sum, Uint8List buffer) => sum + buffer.length,
    );

    final Uint8List result = Uint8List(totalLength);
    int offset = 0;

    for (final Uint8List buffer in buffers) {
      result.setRange(offset, offset + buffer.length, buffer);
      offset += buffer.length;
    }

    return result;
  }

  /// Converts buffer to unsigned BigInt.
  ///
  /// #### Parameters
  /// - `buffer` - Binary data
  ///
  /// #### Returns
  /// `BigInt` - Unsigned BigInt representation
  static BigInt bufferToBigInt(Uint8List buffer) {
    if (buffer.isEmpty) return BigInt.zero;

    BigInt result = BigInt.zero;
    int offset = 0;

    while (offset + 8 <= buffer.length) {
      final int chunk = ByteData.sublistView(
        buffer,
        offset,
        offset + 8,
      ).getUint64(0, Endian.big);
      final BigInt unsignedChunk = chunk < 0
          ? BigInt.from(chunk) + (BigInt.one << 64)
          : BigInt.from(chunk);
      result = (result << 64) | unsignedChunk;
      offset += 8;
    }

    while (offset < buffer.length) {
      result = (result << 8) | BigInt.from(buffer[offset]);
      offset++;
    }

    return result;
  }

  /// Converts unsigned BigInt to buffer.
  ///
  /// #### Parameters
  /// - `value` - Unsigned BigInt to encode
  ///
  /// #### Returns
  /// `Uint8List` - Binary representation
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If value is negative
  static Uint8List bigIntToBuffer(BigInt value) {
    if (value == BigInt.zero) return emptyBuffer;
    if (value.isNegative) {
      throw const AbiBinaryCodecException(
        'Cannot encode negative BigInt as unsigned',
      );
    }

    int byteCount = 0;
    BigInt tempCopy = value;
    while (tempCopy > BigInt.zero) {
      byteCount++;
      tempCopy = tempCopy >> 8;
    }

    final Uint8List bytes = Uint8List(byteCount);
    BigInt temp = value;
    for (int i = byteCount - 1; i >= 0; i--) {
      bytes[i] = (temp & BigInt.from(0xff)).toInt();
      temp = temp >> 8;
    }

    return bytes;
  }

  /// Converts hex string to bytes.
  ///
  /// #### Parameters
  /// - `hex` - Hex string with optional '0x' prefix
  ///
  /// #### Returns
  /// `Uint8List` - Binary data
  static Uint8List hexToBytes(String hex) => HexUtils.hexToBytesLenient(hex);

  /// Converts bytes to hex string.
  ///
  /// #### Parameters
  /// - `bytes` - Binary data to convert
  ///
  /// #### Returns
  /// `String` - Lowercase hex string
  static String bytesToHex(Uint8List bytes) => HexUtils.bytesToHex(bytes);
}

/// Base interface for type-specific binary codecs.
abstract interface class TypeBinaryCodec<T extends TypedValue> {
  /// Decodes value from buffer at top-level.
  ///
  /// #### Parameters
  /// - `buffer` - Complete buffer containing value
  ///
  /// #### Returns
  /// `T` - Decoded value
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If decoding fails
  T decodeTopLevel(Uint8List buffer);

  /// Decodes value from buffer at nested level.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer containing value
  /// - `offset` - Starting position
  ///
  /// #### Returns
  /// `(T, int)` - Decoded value and bytes consumed
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If decoding fails
  (T, int) decodeNested(Uint8List buffer, int offset);

  /// Encodes value to bytes at top-level.
  ///
  /// #### Parameters
  /// - `value` - Value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Binary representation
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If encoding fails
  Uint8List encodeTopLevel(T value);

  /// Encodes value to bytes at nested level.
  ///
  /// #### Parameters
  /// - `value` - Value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Binary representation
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If encoding fails
  Uint8List encodeNested(T value);
}

/// Forward declaration interface for BinaryCodec.
abstract interface class IBinaryCodec {
  /// Decodes nested value from buffer at offset.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer containing nested value
  /// - `type` - Target ABI type
  /// - `offset` - Starting position
  /// - `depth` - Recursion depth (default 0)
  ///
  /// #### Returns
  /// `(TypedValue, int)` - Decoded value and bytes consumed
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If decoding fails
  (TypedValue, int) decodeNested(
    Uint8List buffer,
    AbiType type,
    int offset, {
    int depth = 0,
  });

  /// Encodes nested value to buffer.
  ///
  /// #### Parameters
  /// - `value` - Value to encode
  /// - `depth` - Recursion depth (default 0)
  ///
  /// #### Returns
  /// `Uint8List` - Binary representation
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If encoding fails
  Uint8List encodeNested(TypedValue value, {int depth = 0});
}
