/// Main binary codec for encoding/decoding all ABI types.
import 'dart:typed_data';
import '../../utils/sdk_exceptions.dart';
import '../core/type_system.dart';
import '../core/validation_mixin.dart';
import '../types/collections/array.dart';
import '../types/collections/list.dart';
import '../types/collections/option.dart';
import '../types/composite/enum.dart';
import '../types/composite/explicit_enum.dart';
import '../types/composite/struct.dart';
import '../types/composite/tuple.dart';
import '../types/primitives/address.dart';
import '../types/primitives/boolean.dart';
import '../types/primitives/bytes.dart';
import '../types/primitives/numerical.dart';
import '../types/primitives/string.dart';
import '../types/special/code_metadata.dart';
import '../types/special/composite.dart';
import '../types/special/h256.dart';
import '../types/special/managed_decimal.dart';
import '../types/special/nothing.dart';
import '../types/special/optional.dart';
import '../types/special/token_identifier.dart';
import '../types/special/variadic.dart';
import 'codec_base.dart';
import 'collections/collection_codecs.dart';
import 'composite/composite_codecs.dart';
import 'primitives/primitive_orchestrator.dart';
import 'special/special_codecs.dart';

/// Interface for binary codec operations.
///
/// Primary interface for encoding and decoding ABI-typed values
abstract interface class ICodec {
  /// Decodes buffer into typed value of specified type.
  ///
  /// #### Parameters
  /// - `buffer` - Raw bytes to decode
  /// - `type` - Target ABI type specification
  ///
  /// #### Returns
  /// `TypedValue` - Decoded value matching the specified type
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer is invalid or type unsupported
  TypedValue decodeTopLevel(Uint8List buffer, AbiType type);

  /// Encodes typed value into bytes.
  ///
  /// #### Parameters
  /// - `value` - Typed value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Binary representation
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If value type unsupported or encoding fails
  Uint8List encodeTopLevel(TypedValue value);
}

/// Main binary codec orchestrator delegating to specialized codecs by type.
///
/// Central codec handling all ABI types (primitives, collections,
/// composites, special types) with proper delegation and validation.
class BinaryCodec with ValidationMixin implements IBinaryCodec, ICodec {
  /// Creates binary codec with specified codec instances.
  ///
  /// #### Parameters
  /// - `primitiveCodec` - Handles numbers, booleans, addresses, strings, bytes
  /// - `optionCodec` - Handles `Option<T>` types
  /// - `optionalCodec` - Handles `Optional<T>` types
  /// - `listCodec` - Handles variable-length `List<T>`
  /// - `arrayCodec` - Handles fixed-length `Array<T,N>`
  /// - `structCodec` - Handles struct types
  /// - `tupleCodec` - Handles tuple types
  /// - `enumCodec` - Handles enum types
  /// - `explicitEnumCodec` - Handles explicit enum types
  /// - `managedDecimalCodec` - Handles ManagedDecimal types
  /// - `variadicCodec` - Handles variadic types
  BinaryCodec({
    required this.primitiveCodec,
    required this.optionCodec,
    required this.optionalCodec,
    required this.listCodec,
    required this.arrayCodec,
    required this.structCodec,
    required this.tupleCodec,
    required this.enumCodec,
    required this.explicitEnumCodec,
    required this.managedDecimalCodec,
    required this.variadicCodec,
  });

  factory BinaryCodec.withDefaults() {
    return _cachedInstance ??= _createInstance();
  }

  static BinaryCodec? _cachedInstance;

  static BinaryCodec _createInstance() {
    final PrimitiveBinaryCodec primitiveCodec =
        PrimitiveBinaryCodec.withDefaults();

    final _BinaryCodecStub stub = _BinaryCodecStub();

    final OptionBinaryCodec optionCodec = OptionBinaryCodec(stub);
    final OptionalBinaryCodec optionalCodec = OptionalBinaryCodec(stub);
    final ListBinaryCodec listCodec = ListBinaryCodec(stub);
    final ArrayBinaryCodec arrayCodec = ArrayBinaryCodec(stub);

    final StructBinaryCodec structCodec = StructBinaryCodec(stub);
    final TupleBinaryCodec tupleCodec = TupleBinaryCodec(structCodec);
    final EnumBinaryCodec enumCodec = EnumBinaryCodec(stub);
    const ExplicitEnumBinaryCodec explicitEnumCodec = ExplicitEnumBinaryCodec();

    final ManagedDecimalBinaryCodec managedDecimalCodec =
        ManagedDecimalBinaryCodec(stub);
    final VariadicBinaryCodec variadicCodec = VariadicBinaryCodec(stub);

    final BinaryCodec codec = BinaryCodec(
      primitiveCodec: primitiveCodec,
      optionCodec: optionCodec,
      optionalCodec: optionalCodec,
      listCodec: listCodec,
      arrayCodec: arrayCodec,
      structCodec: structCodec,
      tupleCodec: tupleCodec,
      enumCodec: enumCodec,
      explicitEnumCodec: explicitEnumCodec,
      managedDecimalCodec: managedDecimalCodec,
      variadicCodec: variadicCodec,
    );

    stub._codec = codec;

    return codec;
  }

  /// Codec for primitive types (numbers, booleans, addresses).
  final PrimitiveBinaryCodec primitiveCodec;

  /// Codec for `Option<T>` types (Some/None).
  final OptionBinaryCodec optionCodec;

  /// Codec for `Optional<T>` types (present/missing).
  final OptionalBinaryCodec optionalCodec;

  /// Codec for `List<T>` types (variable-length).
  final ListBinaryCodec listCodec;

  /// Codec for `Array<T, N>` types (fixed-length).
  final ArrayBinaryCodec arrayCodec;

  /// Codec for struct types.
  final StructBinaryCodec structCodec;

  /// Codec for tuple types.
  final TupleBinaryCodec tupleCodec;

  /// Codec for enum types.
  final EnumBinaryCodec enumCodec;

  /// Codec for explicit enum types.
  final ExplicitEnumBinaryCodec explicitEnumCodec;

  /// Codec for ManagedDecimal types.
  final ManagedDecimalBinaryCodec managedDecimalCodec;

  /// Codec for variadic types.
  final VariadicBinaryCodec variadicCodec;

  /// Decodes top-level value from buffer.
  ///
  /// #### Parameters
  /// - `buffer` - Binary data to decode (max 256KB)
  /// - `type` - Target ABI type
  ///
  /// #### Returns
  /// `TypedValue` - Decoded instance
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer exceeds max length or type unsupported
  @override
  TypedValue decodeTopLevel(Uint8List buffer, AbiType type) {
    requireMaxLength(buffer, BinaryCodecConstraints.maxBufferLength);

    if (type is NumericalType) {
      return primitiveCodec.decodeTopLevel(buffer, type);
    } else if (type is BooleanType) {
      return primitiveCodec.decodeTopLevel(buffer, type);
    } else if (type is AddressType) {
      return primitiveCodec.decodeTopLevel(buffer, type);
    } else if (type is StringType) {
      return primitiveCodec.decodeTopLevel(buffer, type);
    } else if (type is BytesType) {
      return primitiveCodec.decodeTopLevel(buffer, type);
    } else if (type is NothingType) {
      return primitiveCodec.decodeTopLevel(buffer, type);
    } else if (type is TokenIdentifierType) {
      return primitiveCodec.decodeTopLevel(buffer, type);
    } else if (type is EgldOrEsdtTokenIdentifierType) {
      return primitiveCodec.decodeTopLevel(buffer, type);
    } else if (type is H256Type) {
      return primitiveCodec.decodeTopLevel(buffer, type);
    } else if (type is CodeMetadataType) {
      return primitiveCodec.decodeTopLevel(buffer, type);
    } else if (type is OptionType) {
      return optionCodec.decodeTopLevel(buffer, type);
    } else if (type is OptionalType) {
      return optionalCodec.decodeTopLevel(buffer, type);
    } else if (type is ListType) {
      return listCodec.decodeTopLevel(buffer, type);
    } else if (type is ArrayType) {
      return arrayCodec.decodeTopLevel(buffer, type);
    } else if (type is StructType) {
      return structCodec.decodeTopLevel(buffer, type);
    } else if (type is TupleType) {
      return tupleCodec.decodeTopLevel(buffer, type);
    } else if (type is EnumType) {
      return enumCodec.decodeTopLevel(buffer, type);
    } else if (type is ExplicitEnumType) {
      return explicitEnumCodec.decodeTopLevel(buffer, type);
    } else if (type is ManagedDecimalType) {
      return managedDecimalCodec.decodeTopLevel(buffer, type);
    } else if (type is VariadicType) {
      return variadicCodec.decodeTopLevel(buffer, type);
    } else if (type is CompositeType) {
      return _decodeCompositeTopLevel(buffer, type);
    } else {
      throw AbiBinaryCodecException(
        'Unsupported type for decoding: ${type.fullyQualifiedName}',
      );
    }
  }

  /// Decodes nested value from buffer at offset, returns (value, bytesRead).
  ///
  /// #### Parameters
  /// - `buffer` - Binary data containing nested value
  /// - `type` - Target ABI type
  /// - `offset` - Starting position in buffer
  /// - `depth` - Current recursion depth (max 32)
  ///
  /// #### Returns
  /// `(TypedValue, int)` - Tuple of (decoded value, bytes consumed)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If offset invalid, type unsupported, or max depth exceeded
  @override
  (TypedValue, int) decodeNested(
    Uint8List buffer,
    AbiType type,
    int offset, {
    int depth = 0,
  }) {
    BinaryCodecConstraints.checkRecursionDepth(depth);
    requireValidOffset(buffer, offset);

    final (TypedValue value, int bytesRead) = switch (type) {
      NumericalType() => primitiveCodec.decodeNested(buffer, type, offset),
      BooleanType() => primitiveCodec.decodeNested(buffer, type, offset),
      AddressType() => primitiveCodec.decodeNested(buffer, type, offset),
      StringType() => primitiveCodec.decodeNested(buffer, type, offset),
      BytesType() => primitiveCodec.decodeNested(buffer, type, offset),
      NothingType() => primitiveCodec.decodeNested(buffer, type, offset),
      TokenIdentifierType() => primitiveCodec.decodeNested(
        buffer,
        type,
        offset,
      ),
      EgldOrEsdtTokenIdentifierType() => primitiveCodec.decodeNested(
        buffer,
        type,
        offset,
      ),
      H256Type() => primitiveCodec.decodeNested(buffer, type, offset),
      CodeMetadataType() => primitiveCodec.decodeNested(buffer, type, offset),
      OptionType() => optionCodec.decodeNested(buffer, type, offset),
      OptionalType() => optionalCodec.decodeNested(buffer, type, offset),
      ListType() => listCodec.decodeNested(buffer, type, offset),
      ArrayType() => arrayCodec.decodeNested(buffer, type, offset),
      StructType() => structCodec.decodeNested(buffer, type, offset),
      TupleType() => tupleCodec.decodeNested(buffer, type, offset),
      EnumType() => enumCodec.decodeNested(buffer, type, offset),
      ExplicitEnumType() => explicitEnumCodec.decodeNested(
        buffer,
        type,
        offset,
      ),
      ManagedDecimalType() => managedDecimalCodec.decodeNested(
        buffer,
        type,
        offset,
      ),
      VariadicType() => variadicCodec.decodeNested(buffer, type, offset),
      CompositeType() => _decodeCompositeNested(buffer, type, offset),
      _ => throw AbiBinaryCodecException(
        'Unsupported type for decoding: ${type.fullyQualifiedName}',
      ),
    };

    if (bytesRead < 0) {
      throw AbiBinaryCodecException(
        'Invalid bytesRead ($bytesRead) from decoding ${type.fullyQualifiedName}',
      );
    }
    requireBytesRead(buffer, offset, bytesRead);

    return (value, bytesRead);
  }

  /// Encodes top-level value to buffer.
  ///
  /// #### Parameters
  /// - `value` - Typed value to encode
  ///
  /// #### Returns
  /// `Uint8List` - Binary representation (max 256KB)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If value type unsupported or result exceeds max length
  @override
  Uint8List encodeTopLevel(TypedValue value) {
    final Uint8List result = _encodeTopLevelInternal(value);

    if (result.length > BinaryCodecConstraints.maxBufferLength) {
      throw AbiBinaryCodecException(
        'Encoded buffer length ${result.length} exceeds maximum ${BinaryCodecConstraints.maxBufferLength}',
      );
    }

    return result;
  }

  Uint8List _encodeTopLevelInternal(TypedValue value) {
    if (value is NumericalValue) {
      return primitiveCodec.encodeTopLevel(value);
    } else if (value is BooleanValue) {
      return primitiveCodec.encodeTopLevel(value);
    } else if (value is AddressValue) {
      return primitiveCodec.encodeTopLevel(value);
    } else if (value is StringValue) {
      return primitiveCodec.encodeTopLevel(value);
    } else if (value is BytesValue) {
      return primitiveCodec.encodeTopLevel(value);
    } else if (value is NothingValue) {
      return primitiveCodec.encodeTopLevel(value);
    } else if (value is TokenIdentifierValue) {
      return primitiveCodec.encodeTopLevel(value);
    } else if (value is EgldOrEsdtTokenIdentifierValue) {
      return primitiveCodec.encodeTopLevel(value);
    } else if (value is H256Value) {
      return primitiveCodec.encodeTopLevel(value);
    } else if (value is CodeMetadataValue) {
      return primitiveCodec.encodeTopLevel(value);
    } else if (value is OptionalValue) {
      return optionalCodec.encodeTopLevel(value);
    } else if (value is OptionValue) {
      return optionCodec.encodeTopLevel(value);
    } else if (value is ListValue) {
      return listCodec.encodeTopLevel(value);
    } else if (value is ArrayValue) {
      return arrayCodec.encodeTopLevel(value);
    } else if (value is StructValue) {
      return structCodec.encodeTopLevel(value);
    } else if (value is TupleValue) {
      return tupleCodec.encodeTopLevel(value);
    } else if (value is EnumValue) {
      return enumCodec.encodeTopLevel(value);
    } else if (value is ExplicitEnumValue) {
      return explicitEnumCodec.encodeTopLevel(value);
    } else if (value is ManagedDecimalValue) {
      return managedDecimalCodec.encodeTopLevel(value);
    } else if (value is VariadicValue) {
      return variadicCodec.encodeTopLevel(value);
    } else if (value is CompositeValue) {
      return _encodeCompositeTopLevel(value);
    } else {
      throw AbiBinaryCodecException(
        'Unsupported value type for encoding: ${value.runtimeType}',
      );
    }
  }

  /// Encodes nested value to buffer.
  ///
  /// #### Parameters
  /// - `value` - Typed value to encode
  /// - `depth` - Current recursion depth (max 32)
  ///
  /// #### Returns
  /// `Uint8List` - Binary representation
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If value type unsupported or max depth exceeded
  @override
  Uint8List encodeNested(TypedValue value, {int depth = 0}) {
    BinaryCodecConstraints.checkRecursionDepth(depth);

    if (value is NumericalValue) {
      return primitiveCodec.encodeNested(value);
    } else if (value is BooleanValue) {
      return primitiveCodec.encodeNested(value);
    } else if (value is AddressValue) {
      return primitiveCodec.encodeNested(value);
    } else if (value is StringValue) {
      return primitiveCodec.encodeNested(value);
    } else if (value is BytesValue) {
      return primitiveCodec.encodeNested(value);
    } else if (value is NothingValue) {
      return primitiveCodec.encodeNested(value);
    } else if (value is TokenIdentifierValue) {
      return primitiveCodec.encodeNested(value);
    } else if (value is EgldOrEsdtTokenIdentifierValue) {
      return primitiveCodec.encodeNested(value);
    } else if (value is H256Value) {
      return primitiveCodec.encodeNested(value);
    } else if (value is CodeMetadataValue) {
      return primitiveCodec.encodeNested(value);
    } else if (value is OptionalValue) {
      return optionalCodec.encodeNested(value);
    } else if (value is OptionValue) {
      return optionCodec.encodeNested(value);
    } else if (value is ListValue) {
      return listCodec.encodeNested(value);
    } else if (value is ArrayValue) {
      return arrayCodec.encodeNested(value);
    } else if (value is StructValue) {
      return structCodec.encodeNested(value);
    } else if (value is TupleValue) {
      return tupleCodec.encodeNested(value);
    } else if (value is EnumValue) {
      return enumCodec.encodeNested(value);
    } else if (value is ExplicitEnumValue) {
      return explicitEnumCodec.encodeNested(value);
    } else if (value is ManagedDecimalValue) {
      return managedDecimalCodec.encodeNested(value);
    } else if (value is VariadicValue) {
      return variadicCodec.encodeNested(value);
    } else if (value is CompositeValue) {
      return _encodeCompositeNested(value, depth: depth);
    } else {
      throw AbiBinaryCodecException(
        'Unsupported value type for nested encoding: ${value.runtimeType}',
      );
    }
  }

  /// Decodes top-level CompositeValue from buffer.
  TypedValue _decodeCompositeTopLevel(Uint8List buffer, CompositeType type) {
    final List<TypedValue> fields = <TypedValue>[];
    int offset = 0;

    for (final AbiType fieldType in type.fieldTypes) {
      final (TypedValue field, int bytesRead) = decodeNested(
        buffer,
        fieldType,
        offset,
      );
      fields.add(field);
      offset += bytesRead;
    }

    return CompositeValue(type, fields);
  }

  /// Decodes nested CompositeValue from buffer at offset.
  (TypedValue, int) _decodeCompositeNested(
    Uint8List buffer,
    CompositeType type,
    int offset,
  ) {
    final List<TypedValue> fields = <TypedValue>[];
    int currentOffset = offset;

    for (final AbiType fieldType in type.fieldTypes) {
      final (TypedValue field, int bytesRead) = decodeNested(
        buffer,
        fieldType,
        currentOffset,
      );
      fields.add(field);
      currentOffset += bytesRead;
    }

    return (CompositeValue(type, fields), currentOffset - offset);
  }

  /// Encodes top-level CompositeValue (concatenates all field encodings).
  Uint8List _encodeCompositeTopLevel(CompositeValue value) {
    final List<int> bytes = <int>[];
    for (final TypedValue field in value.fields) {
      bytes.addAll(encodeNested(field));
    }
    return Uint8List.fromList(bytes);
  }

  /// Encodes nested CompositeValue (concatenates all field encodings).
  Uint8List _encodeCompositeNested(CompositeValue value, {int depth = 0}) {
    final List<int> bytes = <int>[];
    for (final TypedValue field in value.fields) {
      bytes.addAll(encodeNested(field, depth: depth + 1));
    }
    return Uint8List.fromList(bytes);
  }
}

class _BinaryCodecStub implements IBinaryCodec {
  late BinaryCodec _codec;

  @override
  (TypedValue, int) decodeNested(
    Uint8List buffer,
    AbiType type,
    int offset, {
    int depth = 0,
  }) {
    return _codec.decodeNested(buffer, type, offset, depth: depth + 1);
  }

  @override
  Uint8List encodeNested(TypedValue value, {int depth = 0}) {
    return _codec.encodeNested(value, depth: depth + 1);
  }

  @override
  Uint8List encodeTopLevel(TypedValue value) {
    return _codec.encodeTopLevel(value);
  }

  @override
  TypedValue decodeTopLevel(Uint8List buffer, AbiType type) {
    return _codec.decodeTopLevel(buffer, type);
  }
}
