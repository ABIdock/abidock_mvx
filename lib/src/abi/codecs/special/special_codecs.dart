/// Binary codecs for special types.

import 'dart:typed_data';

import '../../../utils/sdk_exceptions.dart';
import '../../core/type_system.dart';
import '../../core/validation_mixin.dart';
import '../../types/special/managed_byte_array.dart';
import '../../types/special/managed_decimal.dart';
import '../../types/special/multi_value.dart';
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

  /// Always throws; `Optional<T>` has no nested wire form.
  ///
  /// Per the MultiversX ABI spec `Optional<T>` is variadic-position only and
  /// only meaningful as the last argument of an endpoint. Nested encodings
  /// (inside structs, tuples, lists, etc.) are ambiguous, so this method
  /// surfaces the ABI authoring error loudly instead of silently encoding the
  /// inner type.
  ///
  /// #### Parameters
  /// - `buffer` - Ignored
  /// - `type` - Ignored
  /// - `offset` - Ignored
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - Always
  (OptionalValue, int) decodeNested(
    Uint8List buffer,
    OptionalType type,
    int offset,
  ) {
    throw const AbiBinaryCodecException(
      'Optional<T> has no nested wire form; use it only at the end of an argument list',
    );
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

  /// Always throws; `Optional<T>` has no nested wire form.
  ///
  /// Per the MultiversX ABI spec `Optional<T>` is variadic-position only and
  /// only meaningful as the last argument of an endpoint. Nested encodings
  /// (inside structs, tuples, lists, etc.) are ambiguous, so this method
  /// surfaces the ABI authoring error loudly instead of silently encoding the
  /// inner type.
  ///
  /// #### Parameters
  /// - `value` - Ignored
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - Always
  Uint8List encodeNested(OptionalValue value) {
    throw const AbiBinaryCodecException(
      'Optional<T> has no nested wire form; use it only at the end of an argument list',
    );
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
    if (buffer.length < offset + 4) {
      throw AbiBinaryCodecException(
        'Buffer too short for ManagedDecimal length prefix: expected at '
        'least ${offset + 4} bytes, got ${buffer.length}',
      );
    }

    final int bigUintLength =
        (buffer[offset] << 24) |
        (buffer[offset + 1] << 16) |
        (buffer[offset + 2] << 8) |
        buffer[offset + 3];

    final int totalLength = type.isVariable
        ? 4 + bigUintLength + 4
        : 4 + bigUintLength;

    if (buffer.length < offset + totalLength) {
      throw AbiBinaryCodecException(
        'Buffer too short for '
        '${type.isVariable ? 'variable' : 'fixed'} ManagedDecimal: '
        'expected ${offset + totalLength} bytes, got ${buffer.length}',
      );
    }

    final Uint8List magnitudeBytes = buffer.sublist(
      offset + 4,
      offset + 4 + bigUintLength,
    );

    final BigInt value = type.isSigned
        ? _decodeBigInt(magnitudeBytes)
        : BinaryCodecUtils.bufferToBigInt(magnitudeBytes);

    final int scale = type.isVariable
        ? (buffer[offset + 4 + bigUintLength] << 24) |
              (buffer[offset + 4 + bigUintLength + 1] << 16) |
              (buffer[offset + 4 + bigUintLength + 2] << 8) |
              buffer[offset + 4 + bigUintLength + 3]
        : type.scale;

    final ManagedDecimalValue result = ManagedDecimalValue(
      value,
      scale: scale,
      isSigned: type.isSigned,
      isVariable: type.isVariable,
    );
    return (result, totalLength);
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
  /// Nested encoding is length-prefixed:
  /// - Variable scale (`ManagedDecimal<usize>`):
  ///   `[u32 dataLen][magnitude bytes][u32 scale]` — the magnitude is written
  ///   as a nested BigUint (4-byte big-endian length, then the bytes), and the
  ///   decimal count follows as a 4-byte big-endian unsigned integer.
  /// - Fixed scale (`ManagedDecimal<N>`):
  ///   `[u32 dataLen][magnitude bytes]` — only the magnitude reaches the wire;
  ///   `N` is carried by the type, never by the bytes.
  ///
  /// The fixed-scale length prefix is **required** so sibling fields in a
  /// struct/array/tuple decode at the correct offset. Without it,
  /// `decodeNested` cannot tell where the magnitude stops and greedily
  /// consumes the rest of the buffer.
  ///
  /// #### Parameters
  /// - `value` - Decimal value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Per the byte layout above.
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If scale is negative.
  Uint8List encodeNested(ManagedDecimalValue value) {
    if (value.scale < 0) {
      throw AbiBinaryCodecException(
        'ManagedDecimal scale ${value.scale} must be non-negative',
      );
    }

    final Uint8List valueBytes = value.isSigned
        ? _encodeBigInt(value.value)
        : BinaryCodecUtils.bigIntToBuffer(value.value);

    final BinaryBuilder builder = BinaryBuilder()
      ..addU32(valueBytes.length)
      ..addBytes(valueBytes);

    if (value.isVariable) {
      builder.addU32(value.scale);
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
    if (value == BigInt.zero) {
      return Uint8List(0);
    }
    if (value.isNegative) {
      final BigInt valuePlusOne = value + BigInt.one;
      Uint8List buffer = BinaryCodecUtils.bigIntToBuffer(valuePlusOne.abs());

      if (buffer.isEmpty) {
        buffer = Uint8List(1);
      }

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
///
/// `counted-variadic<T>` has **no** single-buffer form. It exists only as a
/// multi-argument shape: the count is top-encoded as its own argument
/// (`2` → `0x02`, `0` → empty) and every item follows as a further separate
/// argument. Encoding a count prefix into one buffer produces bytes no
/// contract can parse, so every counted path here throws and callers must go
/// through `ArgSerializer` / `ArgumentEncoder`.
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
  /// - `AbiBinaryCodecException` - If the type is counted, decoding fails, or
  ///   the buffer has leftover bytes
  VariadicValue decodeTopLevel(Uint8List buffer, VariadicType type) {
    _requireSingleBufferForm(isCounted: type.isCounted);

    final List<TypedValue> items = <TypedValue>[];
    int currentOffset = 0;
    int lastOffset = -1;

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

    if (currentOffset != buffer.length) {
      throw AbiBinaryCodecException(
        'Variadic decoding did not consume entire buffer: '
        'consumed $currentOffset bytes, buffer has ${buffer.length} bytes '
        '(${buffer.length - currentOffset} bytes remain)',
      );
    }

    return VariadicValue(items, itemType: type.itemType);
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
  /// - `AbiBinaryCodecException` - If the type is counted or an item consumes
  ///   zero bytes
  (VariadicValue, int) decodeNested(
    Uint8List buffer,
    VariadicType type,
    int offset,
  ) {
    _requireSingleBufferForm(isCounted: type.isCounted);

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
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If the value is counted
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
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If the value is counted
  Uint8List encodeNested(VariadicValue value) {
    _requireSingleBufferForm(isCounted: value.isCounted);

    final builder = BinaryBuilder();

    for (final TypedValue item in value.items) {
      builder.addBytes(binaryCodec.encodeNested(item));
    }

    return builder.toBytes();
  }

  /// Rejects `counted-variadic<T>`, which spans several top-level arguments.
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If `isCounted` is true
  @pragma('vm:prefer-inline')
  static void _requireSingleBufferForm({required bool isCounted}) {
    if (isCounted) {
      throw const AbiBinaryCodecException(
        'counted-variadic has no single-buffer form; the count and each item '
        'are separate top-level arguments - encode or decode via '
        'ArgSerializer/ArgumentEncoder',
      );
    }
  }
}

/// Codec for `ManagedByteArray<N>` values.
///
/// Always reads/writes exactly `type.length` bytes with no length prefix in
/// either nested or top-level positions (the length is part of the type).
class ManagedByteArrayBinaryCodec with ValidationMixin {
  const ManagedByteArrayBinaryCodec();

  /// Decodes `ManagedByteArray<N>` from a top-level buffer of exactly N bytes.
  ///
  /// #### Parameters
  /// - `buffer` - Bytes of length `type.length`
  /// - `type` - Owning type providing the fixed length
  ///
  /// #### Returns
  /// `ManagedByteArrayValue` - With the buffer copied into a `Uint8List`
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer length != `type.length`
  ManagedByteArrayValue decodeTopLevel(
    Uint8List buffer,
    ManagedByteArrayType type,
  ) {
    if (buffer.length != type.length) {
      throw AbiBinaryCodecException(
        'ManagedByteArray<${type.length}> requires exactly ${type.length} '
        'bytes, got ${buffer.length}',
      );
    }
    return ManagedByteArrayValue(type, buffer);
  }

  /// Decodes `ManagedByteArray<N>` from a nested position. Always consumes N.
  ///
  /// #### Parameters
  /// - `buffer` - Source bytes
  /// - `type` - Owning type providing the fixed length
  /// - `offset` - Position of the first byte
  ///
  /// #### Returns
  /// `(ManagedByteArrayValue, int)` - Tuple of (value, `type.length`)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If insufficient bytes remain
  (ManagedByteArrayValue, int) decodeNested(
    Uint8List buffer,
    ManagedByteArrayType type,
    int offset,
  ) {
    requireOffsetWithBytes(buffer, offset, type.length);
    final Uint8List slice = Uint8List.sublistView(
      buffer,
      offset,
      offset + type.length,
    );
    return (ManagedByteArrayValue(type, slice), type.length);
  }

  /// Encodes `ManagedByteArray<N>` for top-level (raw N bytes).
  Uint8List encodeTopLevel(ManagedByteArrayValue value) => value.value;

  /// Encodes `ManagedByteArray<N>` for nested (raw N bytes, no length prefix).
  Uint8List encodeNested(ManagedByteArrayValue value) => value.value;
}

/// Codec for `MultiValue<...>` typed values.
///
/// `MultiValue<...>` groups several independent top-level arguments. The wire
/// form is the concatenation of each inner value's top-level encoding when
/// flattened into a single buffer stream; for argument decoding the
/// `ArgSerializer.buffersToValues` flow consumes one buffer per inner type.
/// There is no nested or single-buffer wire form, so both `encodeNested`,
/// `decodeNested`, and the single-buffer `decodeTopLevel` throw.
class MultiValueBinaryCodec with ValidationMixin {
  /// Creates a [MultiValueBinaryCodec] delegating to an underlying codec.
  ///
  /// #### Parameters
  /// - `binaryCodec` - Codec used to encode each inner value top-level.
  const MultiValueBinaryCodec(this.binaryCodec);

  /// Underlying binary codec used for inner top-level encodings.
  final IBinaryCodec binaryCodec;

  /// Encodes a [MultiValueValue] by concatenating top-level encodings.
  ///
  /// #### Parameters
  /// - `value` - The multi-value whose inner values are encoded one-by-one.
  ///
  /// #### Returns
  /// `Uint8List` - Concatenation of each inner top-level encoding.
  Uint8List encodeTopLevel(MultiValueValue value) {
    final BinaryBuilder builder = BinaryBuilder();
    for (final TypedValue inner in value.values) {
      builder.addBytes(binaryCodec.encodeTopLevel(inner));
    }
    return builder.toBytes();
  }

  /// Always throws; `MultiValue<...>` has no single-buffer top-level form.
  ///
  /// `MultiValue<...>` spans multiple top-level argument buffers; decoding
  /// from a single buffer is undefined. Use `ArgSerializer.buffersToValues`
  /// instead, which feeds one buffer per inner type.
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - Always.
  MultiValueValue decodeTopLevel(Uint8List buffer, MultiValueType type) {
    throw const AbiBinaryCodecException(
      'MultiValue has no top-level wire form from a single buffer; '
      'use ArgSerializer.buffersToValues',
    );
  }

  /// Always throws; `MultiValue<...>` has no nested wire form.
  ///
  /// `MultiValue<...>` is only meaningful at the top-level argument boundary.
  /// Use `Tuple<...>` for nested grouping of fixed-arity composite values.
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - Always.
  Uint8List encodeNested(MultiValueValue value) {
    throw const AbiBinaryCodecException(
      'MultiValue has no nested wire form; use Tuple for nested',
    );
  }

  /// Always throws; `MultiValue<...>` has no nested wire form.
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - Always.
  (MultiValueValue, int) decodeNested(
    Uint8List buffer,
    MultiValueType type,
    int offset,
  ) {
    throw const AbiBinaryCodecException(
      'MultiValue has no nested wire form; use Tuple for nested',
    );
  }
}
