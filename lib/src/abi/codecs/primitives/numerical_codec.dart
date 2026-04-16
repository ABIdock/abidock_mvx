/// Binary codec for numerical types (U8-U64, I8-I64, BigUint, BigInt).
import 'dart:typed_data';

import '../../../utils/sdk_exceptions.dart';
import '../../core/validation_mixin.dart';
import '../../types/primitives/numerical.dart';
import '../../utils/binary_builder.dart';
import '../codec_base.dart';

/// Binary codec for numerical types.
class NumericalBinaryCodec with ValidationMixin {
  const NumericalBinaryCodec();

  /// Decodes numerical value from nested position.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer containing numerical value
  /// - `type` - Specific numerical type (U8, I32, BigUInt, etc.)
  /// - `offset` - Starting position in buffer
  ///
  /// #### Returns
  /// `(NumericalValue, int)` - Tuple of (decoded value, bytes consumed)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer too short or type unsupported
  (NumericalValue, int) decodeNested(
    Uint8List buffer,
    NumericalType type,
    int offset,
  ) {
    if (type is U8Type) return _decodeU8(buffer, offset);
    if (type is U16Type) return _decodeU16(buffer, offset);
    if (type is U32Type) return _decodeU32(buffer, offset);
    if (type is U64Type) return _decodeU64(buffer, offset);
    if (type is I8Type) return _decodeI8(buffer, offset);
    if (type is I16Type) return _decodeI16(buffer, offset);
    if (type is I32Type) return _decodeI32(buffer, offset);
    if (type is I64Type) return _decodeI64(buffer, offset);
    if (type is BigUIntType) {
      final (int length, int lengthBytes) = BinaryCodecUtils.readLength(
        buffer,
        offset,
      );
      final (BigUIntValue value, int valueBytes) = _decodeBigUInt(
        buffer,
        offset + lengthBytes,
        length,
      );
      return (value, lengthBytes + valueBytes);
    }
    if (type is BigIntType) {
      final (int length, int lengthBytes) = BinaryCodecUtils.readLength(
        buffer,
        offset,
      );
      final (BigIntValue value, int valueBytes) = _decodeBigInt(
        buffer,
        offset + lengthBytes,
        length,
      );
      return (value, lengthBytes + valueBytes);
    }

    throw AbiBinaryCodecException(
      'Unsupported numerical type: ${type.fullyQualifiedName}',
    );
  }

  /// Decodes numerical value from entire buffer (top-level).
  ///
  /// #### Parameters
  /// - `buffer` - Complete buffer (empty = 0, else all bytes used)
  /// - `type` - Specific numerical type
  ///
  /// #### Returns
  /// `NumericalValue` - Decoded value
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If type unsupported
  NumericalValue decodeTopLevel(Uint8List buffer, NumericalType type) {
    if (buffer.isEmpty) {
      return switch (type) {
        U8Type() => U8Value(0),
        U16Type() => U16Value(0),
        U32Type() => U32Value(0),
        U64Type() => U64Value(BigInt.zero),
        I8Type() => I8Value(0),
        I16Type() => I16Value(0),
        I32Type() => I32Value(0),
        I64Type() => I64Value(BigInt.zero),
        BigUIntType() => BigUIntValue(BigInt.zero),
        BigIntType() => BigIntValue(BigInt.zero),
        _ => throw AbiBinaryCodecException(
          'Unsupported numerical type: ${type.fullyQualifiedName}',
        ),
      };
    }

    if (type is U8Type ||
        type is U16Type ||
        type is U32Type ||
        type is U64Type ||
        type is BigUIntType) {
      BigInt value = BigInt.zero;
      for (int i = 0; i < buffer.length; i++) {
        value = (value << 8) | BigInt.from(buffer[i]);
      }

      return switch (type) {
        U8Type() => U8Value(value.toInt()),
        U16Type() => U16Value(value.toInt()),
        U32Type() => U32Value(value.toInt()),
        U64Type() => U64Value(value),
        BigUIntType() => BigUIntValue(value),
        _ => throw const AbiBinaryCodecException('Unreachable'),
      };
    }

    final bool isNegative = (buffer[0] & 0x80) != 0;

    if (!isNegative) {
      BigInt value = BigInt.zero;
      for (int i = 0; i < buffer.length; i++) {
        value = (value << 8) | BigInt.from(buffer[i]);
      }

      return switch (type) {
        I8Type() => I8Value(value.toInt()),
        I16Type() => I16Value(value.toInt()),
        I32Type() => I32Value(value.toInt()),
        I64Type() => I64Value(value),
        BigIntType() => BigIntValue(value),
        _ => throw const AbiBinaryCodecException('Unreachable'),
      };
    } else {
      BigInt value = BigInt.zero;
      for (int i = 0; i < buffer.length; i++) {
        value = (value << 8) | BigInt.from(buffer[i]);
      }

      final int bitSize = buffer.length * 8;
      final BigInt modulus = BigInt.one << bitSize;
      assert(
        modulus == BigInt.one << bitSize,
        'Modulus mismatch: expected ${BigInt.one << bitSize}, got $modulus',
      );
      value = value - modulus;

      return switch (type) {
        I8Type() => I8Value(value.toInt()),
        I16Type() => I16Value(value.toInt()),
        I32Type() => I32Value(value.toInt()),
        I64Type() => I64Value(value),
        BigIntType() => BigIntValue(value),
        _ => throw const AbiBinaryCodecException('Unreachable'),
      };
    }
  }

  /// Encodes numerical value to bytes.
  ///
  /// #### Parameters
  /// - `value` - Numerical value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Fixed-size encoding (U8=1, U16=2, U32=4, U64/BigInt=8+length prefix)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If value out of range for its type
  Uint8List encodeNested(NumericalValue value) {
    _validateNumericalValue(value);

    if (value is BigUIntValue || value is BigIntValue) {
      final Uint8List valueBytes = encodeTopLevel(value);
      return (BinaryBuilder()
            ..addU32(valueBytes.length)
            ..addBytes(valueBytes))
          .toBytes();
    }

    return Uint8List.fromList(value.toBytes());
  }

  /// Encodes numerical value to bytes (top-level).
  ///
  /// #### Parameters
  /// - `value` - Numerical value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Minimal bytes (zero = empty, no leading zeros for positive)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If value out of range for its type
  Uint8List encodeTopLevel(NumericalValue value) {
    _validateNumericalValue(value);

    final BigInt bigIntValue = value.asBigInt;

    if (bigIntValue == BigInt.zero) {
      return BinaryCodecUtils.emptyBuffer;
    }

    if (value is U8Value ||
        value is U16Value ||
        value is U32Value ||
        value is U64Value ||
        value is BigUIntValue) {
      return BinaryCodecUtils.bigIntToBuffer(bigIntValue);
    }

    return _encodeSignedTopLevel(bigIntValue);
  }

  Uint8List _encodeSignedTopLevel(BigInt value) {
    if (value > BigInt.zero) {
      final Uint8List buffer = BinaryCodecUtils.bigIntToBuffer(value);

      if (buffer.isNotEmpty && (buffer[0] & 0x80) != 0) {
        final Uint8List result = Uint8List(buffer.length + 1);
        result.setRange(1, result.length, buffer);
        return result;
      }

      return buffer;
    }

    final BigInt valuePlusOne = value + BigInt.one;
    Uint8List buffer = BinaryCodecUtils.bigIntToBuffer(valuePlusOne.abs());

    if (buffer.isEmpty) {
      buffer = Uint8List(1);
    }

    for (int i = 0; i < buffer.length; i++) {
      buffer[i] = ~buffer[i] & 0xff;
    }

    if (buffer.isNotEmpty && (buffer[0] & 0x80) == 0) {
      final Uint8List result = Uint8List(buffer.length + 1);
      result[0] = 0xff;
      result.setRange(1, result.length, buffer);
      return result;
    }

    return buffer;
  }

  (U8Value, int) _decodeU8(Uint8List buffer, int offset) {
    requireOffsetWithBytes(buffer, offset, 1);
    return (U8Value(buffer[offset]), 1);
  }

  (U16Value, int) _decodeU16(Uint8List buffer, int offset) {
    requireOffsetWithBytes(buffer, offset, 2);
    final int value = ByteData.sublistView(
      buffer,
      offset,
      offset + 2,
    ).getUint16(0, Endian.big);
    return (U16Value(value), 2);
  }

  (U32Value, int) _decodeU32(Uint8List buffer, int offset) {
    requireOffsetWithBytes(buffer, offset, 4);
    final int value = ByteData.sublistView(
      buffer,
      offset,
      offset + 4,
    ).getUint32(0, Endian.big);
    return (U32Value(value), 4);
  }

  (U64Value, int) _decodeU64(Uint8List buffer, int offset) {
    requireOffsetWithBytes(buffer, offset, 8);
    BigInt value = BigInt.zero;
    for (int i = 0; i < 8; i++) {
      value = (value << 8) | BigInt.from(buffer[offset + i]);
    }
    return (U64Value(value), 8);
  }

  (I8Value, int) _decodeI8(Uint8List buffer, int offset) {
    requireOffsetWithBytes(buffer, offset, 1);
    final int value = ByteData.sublistView(
      buffer,
      offset,
      offset + 1,
    ).getInt8(0);
    return (I8Value(value), 1);
  }

  (I16Value, int) _decodeI16(Uint8List buffer, int offset) {
    requireOffsetWithBytes(buffer, offset, 2);
    final int value = ByteData.sublistView(
      buffer,
      offset,
      offset + 2,
    ).getInt16(0, Endian.big);
    return (I16Value(value), 2);
  }

  (I32Value, int) _decodeI32(Uint8List buffer, int offset) {
    requireOffsetWithBytes(buffer, offset, 4);
    final int value = ByteData.sublistView(
      buffer,
      offset,
      offset + 4,
    ).getInt32(0, Endian.big);
    return (I32Value(value), 4);
  }

  (I64Value, int) _decodeI64(Uint8List buffer, int offset) {
    requireOffsetWithBytes(buffer, offset, 8);
    final int rawValue = ByteData.sublistView(
      buffer,
      offset,
      offset + 8,
    ).getInt64(0, Endian.big);
    return (I64Value(BigInt.from(rawValue)), 8);
  }

  (BigUIntValue, int) _decodeBigUInt(Uint8List buffer, int offset, int length) {
    requireOffsetWithBytes(buffer, offset, length);

    final Uint8List bytes = buffer.sublist(offset, offset + length);
    final BigInt bigInt = BinaryCodecUtils.bufferToBigInt(bytes);
    return (BigUIntValue(bigInt), length);
  }

  (BigIntValue, int) _decodeBigInt(Uint8List buffer, int offset, int length) {
    requireOffsetWithBytes(buffer, offset, length);

    final Uint8List bytes = buffer.sublist(offset, offset + length);
    final BigInt bigInt = _decodeTwosComplement(bytes);
    return (BigIntValue(bigInt), length);
  }

  BigInt _decodeTwosComplement(Uint8List bytes) {
    if (bytes.isEmpty) return BigInt.zero;

    final bool isNegative = (bytes[0] & 0x80) != 0;

    if (!isNegative) {
      return BinaryCodecUtils.bufferToBigInt(bytes);
    }

    final List<int> inverted = bytes.map((int b) => (~b) & 0xFF).toList();

    int carry = 1;
    for (int i = inverted.length - 1; i >= 0 && carry > 0; i--) {
      final int sum = inverted[i] + carry;
      inverted[i] = sum & 0xFF;
      carry = sum >> 8;
    }

    final BigInt magnitude = BinaryCodecUtils.bufferToBigInt(
      Uint8List.fromList(inverted),
    );
    return -magnitude;
  }

  /// Validates numerical value before encoding.
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If value out of range
  @pragma('vm:prefer-inline')
  void _validateNumericalValue(NumericalValue value) {
    final BigInt bigIntValue = value.asBigInt;

    switch (value) {
      case U8Value():
        if (bigIntValue < BigInt.zero || bigIntValue > BigInt.from(u8Max)) {
          throw AbiBinaryCodecException(
            'U8 value $bigIntValue out of range (must be 0-255)',
          );
        }
      case U16Value():
        if (bigIntValue < BigInt.zero || bigIntValue > BigInt.from(u16Max)) {
          throw AbiBinaryCodecException(
            'U16 value $bigIntValue out of range (must be 0-65535)',
          );
        }
      case U32Value():
        if (bigIntValue < BigInt.zero || bigIntValue > BigInt.from(u32Max)) {
          throw AbiBinaryCodecException(
            'U32 value $bigIntValue out of range (must be 0-4294967295)',
          );
        }
      case U64Value():
        if (bigIntValue < BigInt.zero || bigIntValue > u64Max) {
          throw AbiBinaryCodecException(
            'U64 value $bigIntValue out of range (must be 0-$u64Max)',
          );
        }
      case I8Value():
        if (bigIntValue < BigInt.from(i8Min) ||
            bigIntValue > BigInt.from(i8Max)) {
          throw AbiBinaryCodecException(
            'I8 value $bigIntValue out of range (must be -128 to 127)',
          );
        }
      case I16Value():
        if (bigIntValue < BigInt.from(i16Min) ||
            bigIntValue > BigInt.from(i16Max)) {
          throw AbiBinaryCodecException(
            'I16 value $bigIntValue out of range (must be -32768 to 32767)',
          );
        }
      case I32Value():
        if (bigIntValue < BigInt.from(i32Min) ||
            bigIntValue > BigInt.from(i32Max)) {
          throw AbiBinaryCodecException(
            'I32 value $bigIntValue out of range (must be -2147483648 to 2147483647)',
          );
        }
      case I64Value():
        if (bigIntValue < i64Min || bigIntValue > i64Max) {
          throw AbiBinaryCodecException(
            'I64 value $bigIntValue out of range (must be $i64Min to $i64Max)',
          );
        }
      case BigUIntValue():
        if (bigIntValue < BigInt.zero) {
          throw AbiBinaryCodecException(
            'BigUInt value $bigIntValue must be non-negative',
          );
        }
      case BigIntValue():
        break;
    }
  }
}
