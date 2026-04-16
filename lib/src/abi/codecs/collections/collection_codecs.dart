/// Binary codecs for collection types.

import 'dart:typed_data';

import '../../../utils/sdk_exceptions.dart';
import '../../core/type_system.dart';
import '../../core/validation_mixin.dart';
import '../../types/collections/array.dart';
import '../../types/collections/list.dart';
import '../../types/collections/option.dart';
import '../../utils/binary_builder.dart';
import '../codec_base.dart';

/// Binary codec for Option type (0x00 for None, 0x01+value for Some).
///
/// Encodes/decodes `Option<T>` values following ABI specification
/// where None = empty/0x00 and Some = 0x01 + encoded inner value.
class OptionBinaryCodec with ValidationMixin {
  /// Creates an Option codec.
  ///
  /// #### Parameters
  /// - `binaryCodec` - Parent codec for encoding/decoding inner values
  const OptionBinaryCodec(this.binaryCodec);
  final IBinaryCodec binaryCodec;

  static Uint8List get _marker00 => Uint8List.fromList(<int>[0x00]);
  static Uint8List get _marker01 => Uint8List.fromList(<int>[0x01]);

  /// Decodes Option from top-level buffer.
  ///
  /// Empty buffer = None; non-empty must start with `0x01` followed by the
  /// nested encoding of the inner value.
  OptionValue decodeTopLevel(Uint8List buffer, OptionType type) {
    if (buffer.isEmpty) {
      return OptionValue.none(type);
    }

    if (buffer[0] != 0x01) {
      throw AbiBinaryCodecException(
        'Invalid top-level Option marker: 0x${buffer[0].toRadixString(16)} '
        '(expected 0x01 or empty)',
      );
    }

    final (TypedValue innerValue, _) = binaryCodec.decodeNested(
      buffer,
      type.innerType,
      1,
    );
    return OptionValue.some(type, innerValue);
  }

  /// Decodes Option from nested position, returns (value, bytesConsumed).
  ///
  /// #### Parameters
  /// - `buffer` - Buffer containing nested Option
  /// - `type` - Option type specification
  /// - `offset` - Starting position in buffer
  ///
  /// #### Returns
  /// `(OptionValue, int)` - Tuple of (decoded value, bytes consumed)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer too short, invalid marker, or decode fails
  (OptionValue, int) decodeNested(
    Uint8List buffer,
    OptionType type,
    int offset,
  ) {
    requireOffsetWithBytes(buffer, offset, 1);

    if (buffer[offset] == 0x00) {
      return (OptionValue.none(type), 1);
    }

    if (buffer[offset] != 0x01) {
      throw AbiBinaryCodecException(
        'Invalid marker for Option at offset $offset (expected 0x00 or 0x01)',
      );
    }

    final (TypedValue innerValue, int innerBytes) = binaryCodec.decodeNested(
      buffer,
      type.innerType,
      offset + 1,
    );

    return (OptionValue.some(type, innerValue), 1 + innerBytes);
  }

  /// Encodes Option for top-level.
  ///
  /// None = empty buffer; Some = `[0x01]` followed by nested encoding of the
  /// inner value.
  Uint8List encodeTopLevel(OptionValue value) {
    _validateOptionValue(value);

    if (value.isNone) {
      return BinaryCodecUtils.emptyBuffer;
    }

    final Uint8List innerBytes = binaryCodec.encodeNested(value.value!);
    return (BinaryBuilder()
          ..addBytes(_marker01)
          ..addBytes(innerBytes))
        .toBytes();
  }

  /// Encodes Option for nested.
  ///
  /// #### Parameters
  /// - `value` - Option value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Single byte 0x00 for None, or 0x01+encoded value for Some
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If validation fails
  Uint8List encodeNested(OptionValue value) {
    _validateOptionValue(value);

    if (value.isNone) {
      return _marker00;
    }

    final Uint8List innerBytes = binaryCodec.encodeNested(value.value!);
    return (BinaryBuilder()
          ..addBytes(_marker01)
          ..addBytes(innerBytes))
        .toBytes();
  }

  /// Validates Option value structure.
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If invalid structure
  @pragma('vm:prefer-inline')
  void _validateOptionValue(OptionValue value) {
    if (value.isNone && value.value != null) {
      throw const AbiBinaryCodecException(
        'Option marked as None but contains a value',
      );
    }
    if (!value.isNone && value.value == null) {
      throw const AbiBinaryCodecException(
        'Option marked as Some but value is null',
      );
    }
  }
}

/// Binary codec for List type (4-byte length prefix + items).
///
/// Encodes/decodes `List<T>` values where nested encoding includes
/// 4-byte big-endian length prefix, top-level has no prefix.
class ListBinaryCodec with ValidationMixin {
  /// Creates a List codec.
  ///
  /// #### Parameters
  /// - `binaryCodec` - Parent codec for encoding/decoding list elements
  const ListBinaryCodec(this.binaryCodec);
  final IBinaryCodec binaryCodec;

  /// Decodes List from top-level buffer.
  ///
  /// #### Parameters
  /// - `buffer` - Binary data containing list elements
  /// - `type` - List type specification
  ///
  /// #### Returns
  /// `ListValue` - Decoded list value
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If element decoding fails
  ListValue decodeTopLevel(Uint8List buffer, ListType type) {
    final List<TypedValue> elements = <TypedValue>[];
    int currentOffset = 0;

    while (currentOffset < buffer.length) {
      final (TypedValue item, int itemBytes) = binaryCodec.decodeNested(
        buffer,
        type.elementType,
        currentOffset,
      );
      if (itemBytes <= 0) {
        throw AbiBinaryCodecException(
          'List element consumed zero bytes at offset $currentOffset',
        );
      }
      elements.add(item);
      currentOffset += itemBytes;
    }

    return ListValue(type, elements);
  }

  /// Decodes List from nested position.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer containing nested List
  /// - `type` - List type specification
  /// - `offset` - Starting position in buffer
  ///
  /// #### Returns
  /// `(ListValue, int)` - Decoded value and bytes consumed
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If decode fails
  (ListValue, int) decodeNested(Uint8List buffer, ListType type, int offset) {
    final (int length, int lengthBytes) = BinaryCodecUtils.readLength(
      buffer,
      offset,
    );

    BinaryCodecConstraints.checkListLength(length);

    final List<TypedValue> elements = <TypedValue>[];
    int currentOffset = offset + lengthBytes;

    for (int i = 0; i < length; i++) {
      final (TypedValue item, int itemBytes) = binaryCodec.decodeNested(
        buffer,
        type.elementType,
        currentOffset,
      );
      elements.add(item);
      currentOffset += itemBytes;
    }

    return (ListValue(type, elements), currentOffset - offset);
  }

  /// Encodes List for top-level.
  ///
  /// #### Parameters
  /// - `value` - List value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Encoded elements without length prefix
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If validation fails
  Uint8List encodeTopLevel(ListValue value) {
    _validateListValue(value);

    final builder = BinaryBuilder();
    for (final TypedValue item in value.elements) {
      builder.addBytes(binaryCodec.encodeNested(item));
    }
    return builder.toBytes();
  }

  /// Encodes List for nested.
  ///
  /// #### Parameters
  /// - `value` - List value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Length prefix followed by encoded elements
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If validation fails
  Uint8List encodeNested(ListValue value) {
    _validateListValue(value);

    final builder = BinaryBuilder()..addU32(value.elements.length);

    for (final TypedValue item in value.elements) {
      builder.addBytes(binaryCodec.encodeNested(item));
    }

    return builder.toBytes();
  }

  /// Validates List value structure.
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If too many elements
  @pragma('vm:prefer-inline')
  void _validateListValue(ListValue value) {
    if (value.elements.length > BinaryCodecConstraints.maxListLength) {
      throw AbiBinaryCodecException(
        'List element count ${value.elements.length} exceeds maximum ${BinaryCodecConstraints.maxListLength}',
      );
    }
  }
}

/// Binary codec for Array type (fixed-length, no length prefix).
///
/// Encodes/decodes `Array<T,N>` values with fixed element count
/// known at compile time, so no length prefix needed.
class ArrayBinaryCodec with ValidationMixin {
  /// Creates an Array codec.
  ///
  /// #### Parameters
  /// - `binaryCodec` - Parent codec for encoding/decoding array elements
  const ArrayBinaryCodec(this.binaryCodec);
  final IBinaryCodec binaryCodec;

  /// Decodes Array from top-level buffer.
  ///
  /// #### Parameters
  /// - `buffer` - Binary data containing array elements
  /// - `type` - Array type specification
  ///
  /// #### Returns
  /// `ArrayValue` - Decoded array value
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If element decode fails
  ArrayValue decodeTopLevel(Uint8List buffer, ArrayType type) {
    final (ArrayValue value, _) = decodeNested(buffer, type, 0);
    return value;
  }

  /// Decodes Array from nested position.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer containing nested Array
  /// - `type` - Array type specification
  /// - `offset` - Starting position in buffer
  ///
  /// #### Returns
  /// `(ArrayValue, int)` - Decoded value and bytes consumed
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If element decode fails
  (ArrayValue, int) decodeNested(Uint8List buffer, ArrayType type, int offset) {
    if (type.elementType.sizeInBytes != null) {
      final int expectedSize = type.length * type.elementType.sizeInBytes!;
      if (buffer.length - offset < expectedSize) {
        throw AbiBinaryCodecException(
          'Array buffer too short: expected at least $expectedSize bytes, got ${buffer.length - offset}',
        );
      }
    }

    final List<TypedValue> elements = <TypedValue>[];
    int currentOffset = offset;

    for (int i = 0; i < type.length; i++) {
      final (TypedValue item, int itemBytes) = binaryCodec.decodeNested(
        buffer,
        type.elementType,
        currentOffset,
      );
      elements.add(item);
      currentOffset += itemBytes;
    }

    return (ArrayValue(type, elements), currentOffset - offset);
  }

  /// Encodes Array for top-level.
  ///
  /// #### Parameters
  /// - `value` - Array value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Encoded elements without length prefix
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If element count mismatch
  Uint8List encodeTopLevel(ArrayValue value) {
    return encodeNested(value);
  }

  /// Encodes Array for nested.
  ///
  /// #### Parameters
  /// - `value` - Array value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Encoded elements
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If element count mismatch
  Uint8List encodeNested(ArrayValue value) {
    _validateArrayValue(value);

    final builder = BinaryBuilder();
    for (final TypedValue item in value.elements) {
      builder.addBytes(binaryCodec.encodeNested(item));
    }
    return builder.toBytes();
  }

  /// Validates Array value structure.
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If count mismatch
  @pragma('vm:prefer-inline')
  void _validateArrayValue(ArrayValue value) {
    final int declaredLength = value.type.length;
    final int actualLength = value.elements.length;

    if (actualLength != declaredLength) {
      throw AbiBinaryCodecException(
        'Array element count mismatch: expected $declaredLength elements but got $actualLength',
      );
    }
  }
}
