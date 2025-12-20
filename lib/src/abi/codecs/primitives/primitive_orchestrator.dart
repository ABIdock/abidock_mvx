/// Orchestrator codec for all primitive types.
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../utils/sdk_exceptions.dart';
import '../../core/type_system.dart';
import '../../types/primitives/address.dart';
import '../../types/primitives/boolean.dart';
import '../../types/primitives/bytes.dart';
import '../../types/primitives/numerical.dart';
import '../../types/primitives/string.dart';
import '../../types/special/code_metadata.dart';
import '../../types/special/h256.dart';
import '../../types/special/nothing.dart';
import '../../types/special/token_identifier.dart';
import 'numerical_codec.dart';
import 'simple_primitives_codec.dart';

/// Orchestrator codec for all primitive types.
///
/// Central dispatcher routing encode/decode operations to specialized
/// codecs based on type (numerical, boolean, address, string, bytes, etc.).
@immutable
class PrimitiveBinaryCodec {
  /// Creates a primitive codec with specialized codec instances.
  ///
  /// #### Parameters
  /// - `numericalCodec` - Handles U8-U64, I8-I64, BigUInt, BigInt
  /// - `booleanCodec` - Handles true/false values
  /// - `addressCodec` - Handles 32-byte addresses
  /// - `stringCodec` - Handles UTF-8 strings
  /// - `bytesCodec` - Handles raw byte buffers
  /// - `nothingCodec` - Handles unit/void type
  /// - `tokenIdentifierCodec` - Handles token identifiers
  /// - `h256Codec` - Handles 32-byte hashes
  /// - `codeMetadataCodec` - Handles contract metadata flags
  const PrimitiveBinaryCodec({
    required this.numericalCodec,
    required this.booleanCodec,
    required this.addressCodec,
    required this.stringCodec,
    required this.bytesCodec,
    required this.nothingCodec,
    required this.tokenIdentifierCodec,
    required this.h256Codec,
    required this.codeMetadataCodec,
  });

  /// Creates a primitive codec with default instances.
  ///
  /// #### Returns
  /// `PrimitiveBinaryCodec` - With all default codecs configured
  factory PrimitiveBinaryCodec.withDefaults() {
    return const PrimitiveBinaryCodec(
      numericalCodec: NumericalBinaryCodec(),
      booleanCodec: BooleanBinaryCodec(),
      addressCodec: AddressBinaryCodec(),
      stringCodec: StringBinaryCodec(),
      bytesCodec: BytesBinaryCodec(),
      nothingCodec: NothingBinaryCodec(),
      tokenIdentifierCodec: TokenIdentifierBinaryCodec(),
      h256Codec: H256BinaryCodec(),
      codeMetadataCodec: CodeMetadataBinaryCodec(),
    );
  }

  /// Codec for numerical types.
  final NumericalBinaryCodec numericalCodec;

  /// Codec for boolean values.
  final BooleanBinaryCodec booleanCodec;

  /// Codec for address values.
  final AddressBinaryCodec addressCodec;

  /// Codec for string values.
  final StringBinaryCodec stringCodec;

  /// Codec for bytes values.
  final BytesBinaryCodec bytesCodec;

  /// Codec for nothing values.
  final NothingBinaryCodec nothingCodec;

  /// Codec for token identifier values.
  final TokenIdentifierBinaryCodec tokenIdentifierCodec;

  /// Codec for H256 (32-byte hash) values.
  final H256BinaryCodec h256Codec;

  /// Codec for CodeMetadata values.
  final CodeMetadataBinaryCodec codeMetadataCodec;

  /// Decodes top-level primitive value.
  ///
  /// #### Parameters
  /// - `buffer` - Binary data to decode
  /// - `type` - Specific primitive type
  ///
  /// #### Returns
  /// `TypedValue` - Decoded value of appropriate subclass
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If type unsupported or decode fails
  TypedValue decodeTopLevel(Uint8List buffer, AbiType type) {
    return switch (type) {
      NumericalType() => numericalCodec.decodeTopLevel(buffer, type),
      BooleanType() => booleanCodec.decodeTopLevel(buffer),
      AddressType() => addressCodec.decodeTopLevel(buffer),
      StringType() => stringCodec.decodeTopLevel(buffer),
      BytesType() => bytesCodec.decodeTopLevel(buffer),
      NothingType() => nothingCodec.decodeTopLevel(buffer),
      TokenIdentifierType() => tokenIdentifierCodec.decodeTopLevel(buffer),
      EgldOrEsdtTokenIdentifierType() =>
        tokenIdentifierCodec.decodeTopLevelAsEgldOrEsdt(buffer),
      H256Type() => h256Codec.decodeTopLevel(buffer),
      CodeMetadataType() => codeMetadataCodec.decodeTopLevel(buffer),
      _ => throw AbiBinaryCodecException(
        'Unsupported primitive type: ${type.runtimeType}',
      ),
    };
  }

  /// Decodes nested primitive value, returns (value, bytesConsumed).
  ///
  /// #### Parameters
  /// - `buffer` - Buffer containing nested value
  /// - `type` - Specific primitive type
  /// - `offset` - Starting position in buffer
  ///
  /// #### Returns
  /// `(TypedValue, int)` - Tuple of (decoded value, bytes consumed)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If type unsupported or decode fails
  (TypedValue, int) decodeNested(Uint8List buffer, AbiType type, int offset) {
    return switch (type) {
      NumericalType() => numericalCodec.decodeNested(buffer, type, offset),
      BooleanType() => booleanCodec.decodeNested(buffer, offset),
      AddressType() => addressCodec.decodeNested(buffer, offset),
      StringType() => stringCodec.decodeNested(buffer, offset),
      BytesType() => bytesCodec.decodeNested(buffer, offset),
      NothingType() => nothingCodec.decodeNested(buffer, offset),
      TokenIdentifierType() => tokenIdentifierCodec.decodeNested(
        buffer,
        offset,
      ),
      EgldOrEsdtTokenIdentifierType() =>
        tokenIdentifierCodec.decodeNestedAsEgldOrEsdt(buffer, offset),
      H256Type() => h256Codec.decodeNested(buffer, offset),
      CodeMetadataType() => codeMetadataCodec.decodeNested(buffer, offset),
      _ => throw AbiBinaryCodecException(
        'Unsupported primitive type: ${type.runtimeType}',
      ),
    };
  }

  /// Encodes top-level primitive value.
  ///
  /// #### Parameters
  /// - `value` - Primitive value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Binary representation
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If value type unsupported
  Uint8List encodeTopLevel(TypedValue value) {
    return switch (value) {
      NumericalValue() => numericalCodec.encodeTopLevel(value),
      BooleanValue() => booleanCodec.encodeTopLevel(value),
      AddressValue() => addressCodec.encodeTopLevel(value),
      StringValue() => stringCodec.encodeTopLevel(value),
      BytesValue() => bytesCodec.encodeTopLevel(value),
      NothingValue() => nothingCodec.encodeTopLevel(value),
      TokenIdentifierValue() => tokenIdentifierCodec.encodeTopLevel(value),
      EgldOrEsdtTokenIdentifierValue() =>
        tokenIdentifierCodec.encodeTopLevelEgldOrEsdt(value),
      H256Value() => h256Codec.encodeTopLevel(value),
      CodeMetadataValue() => codeMetadataCodec.encodeTopLevel(value),
      _ => throw AbiBinaryCodecException(
        'Unsupported primitive value: ${value.runtimeType}',
      ),
    };
  }

  /// Encodes nested primitive value.
  ///
  /// #### Parameters
  /// - `value` - Primitive value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Binary representation
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If value type unsupported
  Uint8List encodeNested(TypedValue value) {
    return switch (value) {
      NumericalValue() => numericalCodec.encodeNested(value),
      BooleanValue() => booleanCodec.encodeNested(value),
      AddressValue() => addressCodec.encodeNested(value),
      StringValue() => stringCodec.encodeNested(value),
      BytesValue() => bytesCodec.encodeNested(value),
      NothingValue() => nothingCodec.encodeNested(value),
      TokenIdentifierValue() => tokenIdentifierCodec.encodeNested(value),
      EgldOrEsdtTokenIdentifierValue() =>
        tokenIdentifierCodec.encodeNestedEgldOrEsdt(value),
      H256Value() => h256Codec.encodeNested(value),
      CodeMetadataValue() => codeMetadataCodec.encodeNested(value),
      _ => throw AbiBinaryCodecException(
        'Unsupported primitive value: ${value.runtimeType}',
      ),
    };
  }

  /// Checks if the given type is a numerical type.
  ///
  /// #### Parameters
  /// - `type` - ABI type to check
  ///
  /// #### Returns
  /// `bool` - `true` if type is U8-U64, I8-I64, BigUInt, or BigInt
  bool isNumerical(AbiType type) {
    return type is U8Type ||
        type is U16Type ||
        type is U32Type ||
        type is U64Type ||
        type is I8Type ||
        type is I16Type ||
        type is I32Type ||
        type is I64Type ||
        type is BigUIntType ||
        type is BigIntType;
  }

  /// Checks if the given type is a primitive type.
  ///
  /// #### Parameters
  /// - `type` - ABI type to check
  ///
  /// #### Returns
  /// `bool` - `true` if type is numerical, boolean, address, string, bytes,
  /// nothing, token identifier, H256, or CodeMetadata
  static bool isPrimitive(AbiType type) {
    return type is NumericalType ||
        type is BooleanType ||
        type is AddressType ||
        type is StringType ||
        type is BytesType ||
        type is NothingType ||
        type is TokenIdentifierType ||
        type is EgldOrEsdtTokenIdentifierType ||
        type is H256Type ||
        type is CodeMetadataType;
  }
}
