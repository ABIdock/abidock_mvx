/// Binary codecs for composite types (Struct, Tuple, Enum, ExplicitEnum).

import 'dart:typed_data';

import '../../../utils/sdk_exceptions.dart';
import '../../core/type_system.dart';
import '../../core/validation_mixin.dart';
import '../../types/composite/enum.dart';
import '../../types/composite/explicit_enum.dart';
import '../../types/composite/fields.dart';
import '../../types/composite/struct.dart';
import '../../types/composite/tuple.dart';
import '../../utils/binary_builder.dart';
import '../codec_base.dart';

/// Binary codec for Struct type (concatenated field encodings).
///
/// Encodes/decodes struct values by concatenating encoded fields
/// in definition order without field separators or length prefixes.
class StructBinaryCodec with ValidationMixin {
  /// Creates a Struct codec.
  ///
  /// #### Parameters
  /// - `binaryCodec` - Parent codec for encoding/decoding field values
  const StructBinaryCodec(this.binaryCodec);
  final IBinaryCodec binaryCodec;

  /// Decodes Struct from top-level buffer.
  ///
  /// #### Parameters
  /// - `buffer` - Binary data containing concatenated field values
  /// - `type` - Struct type with field definitions
  ///
  /// #### Returns
  /// `StructValue` - Decoded value with all fields
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer too short or field decode fails
  StructValue decodeTopLevel(Uint8List buffer, StructType type) {
    final (StructValue value, _) = decodeNested(buffer, type, 0);
    return value;
  }

  /// Decodes Struct from nested position, returns (value, bytesConsumed).
  ///
  /// #### Parameters
  /// - `buffer` - Buffer containing nested Struct
  /// - `type` - Struct type with field definitions
  /// - `offset` - Starting position in buffer
  ///
  /// #### Returns
  /// `(StructValue, int)` - Tuple of (decoded value, bytes consumed)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer too short or field decode fails
  (StructValue, int) decodeNested(
    Uint8List buffer,
    StructType type,
    int offset,
  ) {
    final List<Field> fieldValues = <Field>[];
    int currentOffset = offset;

    for (final FieldDefinition fieldDef in type.fieldDefinitions) {
      final (TypedValue value, int valueBytes) = binaryCodec.decodeNested(
        buffer,
        fieldDef.type,
        currentOffset,
      );

      fieldValues.add(Field(name: fieldDef.name, value: value));
      currentOffset += valueBytes;
    }

    return (StructValue(type, Fields(fieldValues)), currentOffset - offset);
  }

  /// Encodes Struct for top-level.
  ///
  /// #### Parameters
  /// - `value` - Struct value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Concatenated field encodings
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If field count mismatch
  Uint8List encodeTopLevel(StructValue value) {
    return encodeNested(value);
  }

  /// Encodes Struct for nested (concatenates all fields).
  ///
  /// #### Parameters
  /// - `value` - Struct value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Concatenated field encodings without separators
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If field count mismatch
  Uint8List encodeNested(StructValue value) {
    _validateStructValue(value);

    final builder = BinaryBuilder();
    for (final Field field in value.fields) {
      builder.addBytes(binaryCodec.encodeNested(field.value));
    }
    return builder.toBytes();
  }

  /// Validates Struct value structure.
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If count mismatch
  @pragma('vm:prefer-inline')
  void _validateStructValue(StructValue value) {
    final int declaredFieldCount = value.type.fieldDefinitions.length;
    final int actualFieldCount = value.fields.length;

    if (actualFieldCount != declaredFieldCount) {
      throw AbiBinaryCodecException(
        'Struct field count mismatch: expected $declaredFieldCount fields but got $actualFieldCount',
      );
    }
  }
}

/// Binary codec for Tuple type (delegates to StructBinaryCodec).
///
/// Tuples are encoded identically to structs (concatenated fields).
class TupleBinaryCodec with ValidationMixin {
  /// Creates a Tuple codec.
  ///
  /// #### Parameters
  /// - `structBinaryCodec` - Struct codec used for tuple encoding
  const TupleBinaryCodec(this.structBinaryCodec);
  final StructBinaryCodec structBinaryCodec;

  /// Decodes Tuple from top-level buffer.
  ///
  /// #### Parameters
  /// - `buffer` - Binary data containing concatenated element values
  /// - `type` - Tuple type with element definitions
  ///
  /// #### Returns
  /// `TupleValue` - Decoded value with all elements
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer too short or element decode fails
  TupleValue decodeTopLevel(Uint8List buffer, TupleType type) {
    final (TupleValue value, _) = decodeNested(buffer, type, 0);
    return value;
  }

  /// Decodes Tuple from nested position, returns (value, bytesConsumed).
  ///
  /// #### Parameters
  /// - `buffer` - Buffer containing nested Tuple
  /// - `type` - Tuple type with element definitions
  /// - `offset` - Starting position in buffer
  ///
  /// #### Returns
  /// `(TupleValue, int)` - Tuple of (decoded value, bytes consumed)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer too short or element decode fails
  (TupleValue, int) decodeNested(Uint8List buffer, TupleType type, int offset) {
    final List<Field> fieldValues = <Field>[];
    int currentOffset = offset;

    for (final FieldDefinition fieldDef in type.fieldDefinitions) {
      final (TypedValue value, int valueBytes) = structBinaryCodec.binaryCodec
          .decodeNested(buffer, fieldDef.type, currentOffset);

      fieldValues.add(Field(name: fieldDef.name, value: value));
      currentOffset += valueBytes;
    }

    return (TupleValue(type, Fields(fieldValues)), currentOffset - offset);
  }

  /// Encodes Tuple for top-level.
  ///
  /// #### Parameters
  /// - `value` - Tuple value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Concatenated element encodings
  Uint8List encodeTopLevel(TupleValue value) {
    return encodeNested(value);
  }

  /// Encodes Tuple for nested (concatenates all fields).
  ///
  /// #### Parameters
  /// - `value` - Tuple value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Concatenated element encodings without separators
  Uint8List encodeNested(TupleValue value) {
    final builder = BinaryBuilder();
    for (final Field field in value.fields) {
      builder.addBytes(structBinaryCodec.binaryCodec.encodeNested(field.value));
    }
    return builder.toBytes();
  }
}

/// Binary codec for Enum type (1-byte discriminant + optional fields).
///
/// Encodes enums as discriminant byte followed by variant fields.
/// Special case: unit variant with discriminant=0 encodes as empty for top-level.
class EnumBinaryCodec with ValidationMixin {
  /// Creates an Enum codec.
  ///
  /// #### Parameters
  /// - `binaryCodec` - Parent codec for encoding/decoding enum field values
  const EnumBinaryCodec(this.binaryCodec);
  final IBinaryCodec binaryCodec;

  /// Decodes Enum from top-level buffer.
  ///
  /// #### Parameters
  /// - `buffer` - Binary data (empty for unit variant 0, else discriminant+fields)
  /// - `type` - Enum type with variant definitions
  ///
  /// #### Returns
  /// `EnumValue` - Decoded value with variant and fields
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If empty enum has no variants, buffer invalid, or decode fails
  EnumValue decodeTopLevel(Uint8List buffer, EnumType type) {
    if (buffer.isEmpty) {
      if (type.variants.isEmpty) {
        throw const AbiBinaryCodecException(
          'Cannot decode empty enum with no variants',
        );
      }
      final EnumVariantDefinition? variant = type.tryGetVariantByDiscriminant(
        0,
      );
      if (variant == null) {
        throw AbiBinaryCodecException(
          'Empty buffer implies discriminant 0, but no variant with '
          'discriminant 0 exists in enum ${type.name}',
        );
      }
      if (variant.fields != null && variant.fields!.isNotEmpty) {
        throw AbiBinaryCodecException(
          'Empty buffer cannot decode enum variant with fields: ${variant.name}',
        );
      }
      return EnumValue(type, variant, const <TypedValue>[]);
    }

    final (EnumValue value, _) = decodeNested(buffer, type, 0);
    return value;
  }

  /// Decodes Enum from nested position, returns (value, bytesConsumed).
  ///
  /// #### Parameters
  /// - `buffer` - Buffer containing nested Enum
  /// - `type` - Enum type with variant definitions
  /// - `offset` - Starting position in buffer
  ///
  /// #### Returns
  /// `(EnumValue, int)` - Tuple of (decoded value, bytes consumed)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer too short, invalid discriminant, or decode fails
  (EnumValue, int) decodeNested(Uint8List buffer, EnumType type, int offset) {
    requireOffsetWithBytes(buffer, offset, 1);

    final int discriminant = buffer[offset];

    final EnumVariantDefinition? variant = type.tryGetVariantByDiscriminant(
      discriminant,
    );
    if (variant == null) {
      throw AbiBinaryCodecException(
        'Invalid discriminant $discriminant for enum ${type.name} '
        '(no variant with this discriminant exists)',
      );
    }

    int currentOffset = offset + 1;

    if (variant.fields == null || variant.fields!.isEmpty) {
      return (EnumValue(type, variant, const <TypedValue>[]), 1);
    }

    final List<TypedValue> fieldValues = <TypedValue>[];
    for (final AbiType fieldType in variant.fields!) {
      final (TypedValue value, int valueBytes) = binaryCodec.decodeNested(
        buffer,
        fieldType,
        currentOffset,
      );
      fieldValues.add(value);
      currentOffset += valueBytes;
    }

    return (EnumValue(type, variant, fieldValues), currentOffset - offset);
  }

  /// Encodes Enum for top-level.
  ///
  /// #### Parameters
  /// - `value` - Enum value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Empty for unit variant 0, else discriminant+fields
  Uint8List encodeTopLevel(EnumValue value) {
    final bool hasFields = value.fields.isNotEmpty;

    final builder = BinaryBuilder();

    if (hasFields || value.discriminant != 0) {
      builder.addByte(value.discriminant);
    }

    for (final TypedValue fieldValue in value.fields) {
      builder.addBytes(binaryCodec.encodeNested(fieldValue));
    }

    return builder.toBytes();
  }

  /// Encodes Enum for nested (1-byte discriminant + fields).
  ///
  /// #### Parameters
  /// - `value` - Enum value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Discriminant byte followed by encoded fields
  Uint8List encodeNested(EnumValue value) {
    final builder = BinaryBuilder()..addByte(value.discriminant);

    for (final TypedValue fieldValue in value.fields) {
      builder.addBytes(binaryCodec.encodeNested(fieldValue));
    }

    return builder.toBytes();
  }
}

/// Binary codec for ExplicitEnum type (uses variant name strings).
///
/// Encodes enum variants as UTF-8 strings of variant names.
/// Nested encoding uses 4-byte length prefix, top-level has no prefix.
class ExplicitEnumBinaryCodec with ValidationMixin {
  const ExplicitEnumBinaryCodec();

  /// Decodes ExplicitEnum from top-level buffer (no length prefix).
  ///
  /// #### Parameters
  /// - `buffer` - UTF-8 encoded variant name
  /// - `type` - ExplicitEnum type with variant definitions
  ///
  /// #### Returns
  /// `ExplicitEnumValue` - Decoded value matching variant name
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If variant name unknown
  ExplicitEnumValue decodeTopLevel(Uint8List buffer, ExplicitEnumType type) {
    final String variantName = String.fromCharCodes(buffer);

    final ExplicitEnumVariantDefinition? variant = type.variants
        .cast<ExplicitEnumVariantDefinition?>()
        .firstWhere(
          (ExplicitEnumVariantDefinition? v) => v?.name == variantName,
          orElse: () => null,
        );

    if (variant == null) {
      throw AbiBinaryCodecException(
        'Unknown variant "$variantName" for ExplicitEnum ${type.name}',
      );
    }

    return ExplicitEnumValue(type, variant);
  }

  /// Decodes ExplicitEnum from nested position, returns (value, bytesConsumed).
  ///
  /// #### Parameters
  /// - `buffer` - Buffer containing length prefix + UTF-8 variant name
  /// - `type` - ExplicitEnum type with variant definitions
  /// - `offset` - Starting position in buffer
  ///
  /// #### Returns
  /// `(ExplicitEnumValue, int)` - Tuple of (decoded value, bytes consumed)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer too short or variant name unknown
  (ExplicitEnumValue, int) decodeNested(
    Uint8List buffer,
    ExplicitEnumType type,
    int offset,
  ) {
    requireOffsetWithBytes(buffer, offset, 4);

    final int length =
        (buffer[offset] << 24) |
        (buffer[offset + 1] << 16) |
        (buffer[offset + 2] << 8) |
        buffer[offset + 3];

    requireEndOffset(buffer, offset, 4 + length, 'ExplicitEnum');

    final Uint8List stringBytes = buffer.sublist(
      offset + 4,
      offset + 4 + length,
    );
    final String variantName = String.fromCharCodes(stringBytes);

    final ExplicitEnumVariantDefinition? variant = type.variants
        .cast<ExplicitEnumVariantDefinition?>()
        .firstWhere(
          (ExplicitEnumVariantDefinition? v) => v?.name == variantName,
          orElse: () => null,
        );

    if (variant == null) {
      throw AbiBinaryCodecException(
        'Unknown variant "$variantName" for ExplicitEnum ${type.name}',
      );
    }

    return (ExplicitEnumValue(type, variant), 4 + length);
  }

  /// Encodes ExplicitEnum for top-level (no length prefix).
  ///
  /// #### Parameters
  /// - `value` - ExplicitEnum value to encode
  ///
  /// #### Returns
  /// `Uint8List` - ASCII encoded variant name
  Uint8List encodeTopLevel(ExplicitEnumValue value) {
    return Uint8List.fromList(value.variantName.codeUnits);
  }

  /// Encodes ExplicitEnum for nested (4-byte length + string).
  ///
  /// #### Parameters
  /// - `value` - ExplicitEnum value to encode
  ///
  /// #### Returns
  /// `Uint8List` - 4-byte big-endian length followed by ASCII variant name
  Uint8List encodeNested(ExplicitEnumValue value) {
    final Uint8List stringBytes = Uint8List.fromList(
      value.variantName.codeUnits,
    );

    return (BinaryBuilder()
          ..addU32(stringBytes.length)
          ..addBytes(stringBytes))
        .toBytes();
  }
}
