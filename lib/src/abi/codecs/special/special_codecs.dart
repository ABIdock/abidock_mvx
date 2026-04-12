/// Binary codecs for special types.

import 'dart:typed_data';

import '../../../utils/sdk_exceptions.dart';
import '../../core/type_system.dart';
import '../../core/validation_mixin.dart';
import '../../types/special/managed_decimal.dart';
import '../../types/special/optional.dart';
import '../../types/special/variadic.dart';
import '../../utils/binary_builder.dart';
import '../codec_base.dart';

/// Codec for Optional values (function arguments that can be omitted).
///
/// Empty buffer = missing argument, non-empty = provided argument.
class OptionalBinaryCodec with ValidationMixin {
  const OptionalBinaryCodec(this.binaryCodec);
  final IBinaryCodec binaryCodec;

  /// Decodes Optional from top-level buffer.
  ///
  /// #### Parameters
  /// - `buffer` - Empty = missing, non-empty = provided value
  /// - `type` - OptionalType with inner type spec
  ///
  /// #### Returns
  /// `OptionalValue` - Missing or provided
  OptionalValue decodeTopLevel(Uint8List buffer, OptionalType type) {
    if (buffer.isEmpty) {
      return OptionalValue.missing(type);
    }

    final TypedValue innerValue = binaryCodec.decodeTopLevel(
      buffer,
      type.innerType,
    );
    return OptionalValue.provided(type, innerValue);
  }

  /// Decodes Optional from nested position.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer to decode from
  /// - `type` - OptionalType
  /// - `offset` - Starting position
  ///
  /// #### Returns
  /// `(OptionalValue, int)` - Tuple of (value, bytes consumed)
  (OptionalValue, int) decodeNested(
    Uint8List buffer,
    OptionalType type,
    int offset,
  ) {
    if (offset >= buffer.length) {
      return (OptionalValue.missing(type), 0);
    }

    final (TypedValue innerValue, int innerBytes) = binaryCodec.decodeNested(
      buffer,
      type.innerType,
      offset,
    );

    return (OptionalValue.provided(type, innerValue), innerBytes);
  }

  /// Encodes Optional for top-level.
  ///
  /// #### Parameters
  /// - `value` - Missing = empty buffer, Provided = encoded value
  ///
  /// #### Returns
  /// `Uint8List` - Empty for missing, encoded value for provided
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - if validation fails
  Uint8List encodeTopLevel(OptionalValue value) {
    _validateOptionalValue(value);

    if (value.isMissing) {
      return BinaryCodecUtils.emptyBuffer;
    }

    return binaryCodec.encodeTopLevel(value.value!);
  }

  /// Encodes Optional for nested.
  ///
  /// #### Parameters
  /// - `value` - Optional value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Empty for missing, nested-encoded value for provided
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - if validation fails
  Uint8List encodeNested(OptionalValue value) {
    _validateOptionalValue(value);

    if (value.isMissing) {
      return BinaryCodecUtils.emptyBuffer;
    }

    return binaryCodec.encodeNested(value.value!);
  }

  /// Validates Optional value structure.
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - if invalid structure
  @pragma('vm:prefer-inline')
  void _validateOptionalValue(OptionalValue value) {
    if (value.isMissing && value.value != null) {
      throw const AbiBinaryCodecException(
        'Optional marked as missing but contains a value',
      );
    }
    if (!value.isMissing && value.value == null) {
      throw const AbiBinaryCodecException(
        'Optional marked as provided but value is null',
      );
    }
  }
}

/// Codec for ManagedDecimal values.
///
/// Fixed-point decimals with configurable scale (decimal places).
class ManagedDecimalBinaryCodec with ValidationMixin {
  const ManagedDecimalBinaryCodec(this.binaryCodec);
  final IBinaryCodec binaryCodec;

  /// Decodes ManagedDecimal from top-level buffer.
  ///
  /// #### Parameters
  /// - `buffer` - For variable: [length, value, scale(4 bytes)], for fixed: [value only]
  /// - `type` - ManagedDecimalType with scale/signedness
  ///
  /// #### Returns
  /// `ManagedDecimalValue` - With scale and value
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer too short
  ManagedDecimalValue decodeTopLevel(
    Uint8List buffer,
    ManagedDecimalType type,
  ) {
    if (buffer.isEmpty) {
      return ManagedDecimalValue(
        BigInt.zero,
        scale: type.isVariable ? 0 : type.scale,
        isSigned: type.isSigned,
        isVariable: type.isVariable,
      );
    }

    if (type.isVariable) {
      if (buffer.length < 4) {
        throw AbiBinaryCodecException(
          'Buffer too short for variable ManagedDecimal: expected at least 4 bytes for length, got ${buffer.length}',
        );
      }
      final int bigUintSizeBytes =
          (buffer[0] << 24) | (buffer[1] << 16) | (buffer[2] << 8) | buffer[3];

      final int bigUintLength = bigUintSizeBytes;
      final int requiredLength = 4 + bigUintLength + 4;
      if (buffer.length < requiredLength) {
        throw AbiBinaryCodecException(
          'Buffer too short for variable ManagedDecimal: expected $requiredLength bytes, got ${buffer.length}',
        );
      }
      final Uint8List valueBuffer = buffer.sublist(0, 4 + bigUintLength);

      final BigInt value = type.isSigned
          ? _decodeBigInt(valueBuffer.sublist(4, 4 + bigUintLength))
          : BinaryCodecUtils.bufferToBigInt(
              valueBuffer.sublist(4, 4 + bigUintLength),
            );

      final int scale =
          (buffer[4 + bigUintLength] << 24) |
          (buffer[4 + bigUintLength + 1] << 16) |
          (buffer[4 + bigUintLength + 2] << 8) |
          buffer[4 + bigUintLength + 3];

      return ManagedDecimalValue(
        value,
        scale: scale,
        isSigned: type.isSigned,
        isVariable: true,
      );
    } else {
      final BigInt value = type.isSigned
          ? _decodeBigInt(buffer)
          : BinaryCodecUtils.bufferToBigInt(buffer);

      return ManagedDecimalValue(
        value,
        scale: type.scale,
        isSigned: type.isSigned,
      );
    }
  }

  /// Decodes ManagedDecimal from nested position.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer to decode from
  /// - `type` - ManagedDecimalType
  /// - `offset` - Starting position
  ///
  /// #### Returns
  /// `(ManagedDecimalValue, int)` - Tuple of (value, bytes consumed)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If insufficient data
  (ManagedDecimalValue, int) decodeNested(
    Uint8List buffer,
    ManagedDecimalType type,
    int offset,
  ) {
    int length;
    Uint8List payload;

    if (buffer.length < offset + 4) {
      throw AbiBinaryCodecException(
        'Buffer too short for ManagedDecimal length prefix: expected at least ${offset + 4} bytes, got ${buffer.length}',
      );
    }

    if (type.isVariable) {
      final int bigUintLength =
          (buffer[offset] << 24) |
          (buffer[offset + 1] << 16) |
          (buffer[offset + 2] << 8) |
          buffer[offset + 3];

      length = 4 + bigUintLength + 4;
      if (buffer.length < offset + length) {
        throw AbiBinaryCodecException(
          'Buffer too short for variable ManagedDecimal: expected ${offset + length} bytes, got ${buffer.length}',
        );
      }
      payload = buffer.sublist(offset, offset + length);
    } else {
      length =
          (buffer[offset] << 24) |
          (buffer[offset + 1] << 16) |
          (buffer[offset + 2] << 8) |
          buffer[offset + 3];
      if (buffer.length < offset + 4 + length) {
        throw AbiBinaryCodecException(
          'Buffer too short for fixed ManagedDecimal: expected ${offset + 4 + length} bytes, got ${buffer.length}',
        );
      }
      payload = buffer.sublist(offset + 4, offset + 4 + length);
    }

    final ManagedDecimalValue result = decodeTopLevel(payload, type);
    return (result, type.isVariable ? length : 4 + length);
  }

  /// Encodes ManagedDecimal for top-level.
  ///
  /// #### Parameters
  /// - `value` - Decimal value to encode
  ///
  /// #### Returns
  /// `Uint8List` - For variable: [length(4 bytes), value, scale(4 bytes)], for fixed: [value only]
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If scale mismatch in fixed mode
  Uint8List encodeTopLevel(ManagedDecimalValue value) {
    final builder = BinaryBuilder();
    if (value.isVariable) {
      final Uint8List valueBytes = value.isSigned
          ? _encodeBigInt(value.value)
          : BinaryCodecUtils.bigIntToBuffer(value.value);
      builder.addU32(valueBytes.length);
      builder.addBytes(valueBytes);
      builder.addU32(value.scale);
    } else {
      final Uint8List valueBytes = value.isSigned
          ? _encodeBigInt(value.value)
          : BinaryCodecUtils.bigIntToBuffer(value.value);
      builder.addBytes(valueBytes);
    }
    return builder.toBytes();
  }

  /// Encodes ManagedDecimal for nested.
  ///
  /// #### Parameters
  /// - `value` - Decimal value to encode
  ///
  /// #### Returns
  /// `Uint8List` - For variable: [4-byte length, scale, value], for fixed: [4-byte length, value]
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If scale mismatch
  Uint8List encodeNested(ManagedDecimalValue value) {
    const int maxScale = 77;
    if (value.scale < 0 || value.scale > maxScale) {
      throw AbiBinaryCodecException(
        'ManagedDecimal scale ${value.scale} out of valid range (0-$maxScale)',
      );
    }

    final builder = BinaryBuilder();

    if (value.isVariable) {
      final Uint8List valueBytes = value.isSigned
          ? _encodeBigInt(value.value)
          : BinaryCodecUtils.bigIntToBuffer(value.value);

      builder.addU32(valueBytes.length);
      builder.addBytes(valueBytes);
      builder.addU32(value.scale);
    } else {
      final Uint8List valueBytes = value.isSigned
          ? _encodeBigInt(value.value)
          : BinaryCodecUtils.bigIntToBuffer(value.value);

      builder.addU32(valueBytes.length);
      builder.addBytes(valueBytes);
    }

    return builder.toBytes();
  }

  BigInt _decodeBigInt(Uint8List bytes) {
    if (bytes.isEmpty) return BigInt.zero;

    final bool isNegative = (bytes[0] & 0x80) != 0;

    if (!isNegative) {
      return BinaryCodecUtils.bufferToBigInt(bytes);
    }

    final Uint8List inverted = Uint8List(bytes.length);
    for (int i = 0; i < bytes.length; i++) {
      inverted[i] = (~bytes[i]) & 0xFF;
    }

    int carry = 1;
    for (int i = inverted.length - 1; i >= 0 && carry > 0; i--) {
      final int sum = inverted[i] + carry;
      inverted[i] = sum & 0xFF;
      carry = sum >> 8;
    }

    final BigInt magnitude = BinaryCodecUtils.bufferToBigInt(inverted);
    return -magnitude;
  }

  Uint8List _encodeBigInt(BigInt value) {
    if (value.isNegative) {
      final BigInt valuePlusOne = value + BigInt.one;
      final Uint8List buffer = BinaryCodecUtils.bigIntToBuffer(
        valuePlusOne.abs(),
      );

      for (int i = 0; i < buffer.length; i++) {
        buffer[i] = (~buffer[i]) & 0xFF;
      }

      if ((buffer[0] & 0x80) == 0) {
        final Uint8List extended = Uint8List(buffer.length + 1);
        extended[0] = 0xFF;
        extended.setRange(1, extended.length, buffer);
        return extended;
      }

      return buffer;
    } else {
      final Uint8List buffer = BinaryCodecUtils.bigIntToBuffer(value);

      if (buffer.isNotEmpty && (buffer[0] & 0x80) != 0) {
        final Uint8List extended = Uint8List(buffer.length + 1);
        extended[0] = 0x00;
        extended.setRange(1, extended.length, buffer);
        return extended;
      }

      return buffer;
    }
  }
}

/// Codec for Variadic values (variable number of items).
///
/// Encodes multiple items by concatenation.
class VariadicBinaryCodec with ValidationMixin {
  const VariadicBinaryCodec(this.binaryCodec);
  final IBinaryCodec binaryCodec;

  /// Decodes Variadic from top-level buffer.
  ///
  /// #### Parameters
  /// - `buffer` - Concatenated encoded items
  /// - `type` - VariadicType with item type
  ///
  /// #### Returns
  /// `VariadicValue` - With list of decoded items
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If decoding fails or buffer has leftover bytes
  VariadicValue decodeTopLevel(Uint8List buffer, VariadicType type) {
    final List<TypedValue> items = <TypedValue>[];
    int currentOffset = 0;
    int lastOffset = -1;
    int? remaining;

    if (type.isCounted) {
      if (buffer.length < 4) {
        throw AbiBinaryCodecException(
          'Buffer too short for counted variadic count prefix: got ${buffer.length}',
        );
      }
      final (int count, int consumed) = BinaryCodecUtils.readLength(buffer, 0);
      currentOffset = consumed;
      remaining = count;
    }

    while (currentOffset < buffer.length &&
        (remaining == null || remaining > 0)) {
      if (currentOffset == lastOffset) {
        throw AbiBinaryCodecException(
          'Variadic item consumed zero bytes at offset $currentOffset',
        );
      }
      lastOffset = currentOffset;

      final (TypedValue item, int itemBytes) = binaryCodec.decodeNested(
        buffer,
        type.itemType,
        currentOffset,
      );
      items.add(item);
      currentOffset += itemBytes;
      if (remaining != null) remaining--;
    }

    if (currentOffset != buffer.length) {
      throw AbiBinaryCodecException(
        'Variadic decoding did not consume entire buffer: '
        'consumed $currentOffset bytes, buffer has ${buffer.length} bytes '
        '(${buffer.length - currentOffset} bytes remain)',
      );
    }

    return VariadicValue(
      items,
      itemType: type.itemType,
      isCounted: type.isCounted,
    );
  }

  /// Decodes Variadic from nested position.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer with concatenated items
  /// - `type` - VariadicType
  /// - `offset` - Starting position
  ///
  /// #### Returns
  /// `(VariadicValue, int)` - Tuple of (value, bytes consumed)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If item consumes zero bytes
  (VariadicValue, int) decodeNested(
    Uint8List buffer,
    VariadicType type,
    int offset,
  ) {
    final List<TypedValue> items = <TypedValue>[];
    int currentOffset = offset;
    int lastOffset = offset - 1;

    while (currentOffset < buffer.length) {
      if (currentOffset == lastOffset) {
        throw AbiBinaryCodecException(
          'Variadic item consumed zero bytes at offset $currentOffset',
        );
      }
      lastOffset = currentOffset;

      final (TypedValue item, int itemBytes) = binaryCodec.decodeNested(
        buffer,
        type.itemType,
        currentOffset,
      );
      items.add(item);
      currentOffset += itemBytes;
    }

    return (
      VariadicValue(items, itemType: type.itemType),
      currentOffset - offset,
    );
  }

  /// Encodes Variadic for top-level.
  ///
  /// #### Parameters
  /// - `value` - Variadic value with items
  ///
  /// #### Returns
  /// `Uint8List` - Concatenated top-level encodings of all items
  Uint8List encodeTopLevel(VariadicValue value) {
    return encodeNested(value);
  }

  /// Encodes Variadic for nested.
  ///
  /// #### Parameters
  /// - `value` - Variadic value with items
  ///
  /// #### Returns
  /// `Uint8List` - Concatenated nested encodings of all items
  Uint8List encodeNested(VariadicValue value) {
    final builder = BinaryBuilder();

    if (value.isCounted) {
      builder.addU32(value.length);
    }

    for (final TypedValue item in value.items) {
      builder.addBytes(binaryCodec.encodeNested(item));
    }

    return builder.toBytes();
  }
}
