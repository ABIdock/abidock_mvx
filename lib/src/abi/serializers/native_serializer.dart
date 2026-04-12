/// Native serializer for smart contract arguments.
import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../utils/helpers.dart';
import '../../utils/hex_utils.dart';
import '../../utils/sdk_exceptions.dart';
import '../../wallet/crypto/bech32_encoder.dart';
import '../core/type_formula.dart';
import '../core/type_formula_parser.dart';
import '../core/types.dart';

/// Defines a smart contract endpoint parameter with name, description, and type.
@immutable
class EndpointParameterDefinition {
  /// Creates parameter definition with name, description, and type.
  ///
  /// #### Parameters
  /// - `name` - Parameter name
  /// - `description` - Optional parameter description
  /// - `type` - Parameter ABI type
  const EndpointParameterDefinition(this.name, this.description, this.type);

  /// Parameter name.
  final String name;

  /// Parameter description.
  final String? description;

  /// Parameter type.
  final AbiType type;
}

/// Defines a smart contract endpoint with input and output parameters.
@immutable
class EndpointDefinition {
  /// Creates endpoint definition with name, input, and output parameters.
  ///
  /// #### Parameters
  /// - `name` - Endpoint function name
  /// - `input` - Input parameters
  /// - `output` - Output parameters
  const EndpointDefinition({
    required this.name,
    required this.input,
    required this.output,
  });

  /// Endpoint name.
  final String name;

  /// Input parameters.
  final List<EndpointParameterDefinition> input;

  /// Output parameters.
  final List<EndpointParameterDefinition> output;
}

/// Describes the argument count constraints for an endpoint.
@immutable
class ArgumentsCardinality {
  /// Creates cardinality with min, max, and variadic flag.
  ///
  /// #### Parameters
  /// - `min` - Minimum argument count
  /// - `max` - Maximum argument count (-1 for unlimited)
  /// - `variadic` - Whether last parameter is variadic
  const ArgumentsCardinality({
    required this.min,
    required this.max,
    required this.variadic,
  });

  /// Minimum arguments.
  final int min;

  /// Maximum arguments.
  final int max;

  /// Whether variadic.
  final bool variadic;
}

/// Serializer that converts native Dart values to ABI typed values.
///
/// Use static methods to convert between native and typed representations
/// for smart contract function calls.
class NativeSerializer {
  /// Converts native Dart values to typed values based on endpoint signature.
  ///
  /// Automatically maps native values to endpoint parameter types with
  /// validation of argument count and type compatibility.
  ///
  /// #### Parameters
  /// - `args` - Native values to convert (null treated as empty)
  /// - `endpoint` - Endpoint with parameter type information
  ///
  /// #### Throws
  /// - `AbiNativeSerializationException` - If argument count mismatches or conversion fails
  static List<TypedValue> nativeToTypedValues(
    List<dynamic>? args,
    EndpointDefinition endpoint,
  ) {
    try {
      args ??= <dynamic>[];
      _checkArgumentsCardinality(args, endpoint);

      final List<EndpointParameterDefinition> parameters = endpoint.input;
      final List<TypedValue> values = <TypedValue>[];

      for (int i = 0; i < parameters.length; i++) {
        final EndpointParameterDefinition parameter = parameters[i];
        if (i == parameters.length - 1 && parameter.type is VariadicType) {
          final VariadicType varType = parameter.type as VariadicType;
          final List<TypedValue> variadicItems = <TypedValue>[];
          for (int j = i; j < args.length; j++) {
            variadicItems.add(_convertToTypedValue(
              args[j],
              varType.itemType,
              'Variadic parameter ${parameter.name} at index $j',
            ));
          }
          values.add(VariadicValue(variadicItems, itemType: varType.itemType));
        } else {
          final TypedValue value = _convertToTypedValue(
            args[i],
            parameter.type,
            'Parameter ${parameter.name} at index $i',
          );
          values.add(value);
        }
      }

      return values;
    } catch (e) {
      throw AbiNativeSerializationException(
        'Failed to convert native values for endpoint ${endpoint.name}',
        cause: e,
      );
    }
  }

  /// Checks arguments cardinality.
  static void _checkArgumentsCardinality(
    List<dynamic> args,
    EndpointDefinition endpoint,
  ) {
    final ArgumentsCardinality cardinality = getArgumentsCardinality(
      endpoint.input,
    );

    if (!(cardinality.min <= args.length && (cardinality.max == -1 || args.length <= cardinality.max))) {
      throw AbiNativeSerializationException(
        'Wrong number of arguments for endpoint ${endpoint.name}: '
        'expected between ${cardinality.min} and ${cardinality.max} arguments, '
        'have ${args.length}',
      );
    }
  }

  /// Calculates argument count constraints from endpoint parameters.
  ///
  /// #### Parameters
  /// - `parameters` - Endpoint parameters
  static ArgumentsCardinality getArgumentsCardinality(
    List<EndpointParameterDefinition> parameters,
  ) {
    final bool hasVariadic =
        parameters.isNotEmpty && parameters.last.type is VariadicType;

    if (hasVariadic) {
      final int min = parameters.length - 1;
      const int max = -1;
      return ArgumentsCardinality(min: min, max: max, variadic: true);
    } else {
      final int count = parameters.length;
      return ArgumentsCardinality(min: count, max: count, variadic: false);
    }
  }

  /// Converts native value to typed value.
  static TypedValue _convertToTypedValue(
    dynamic value,
    AbiType type,
    String context,
  ) {
    try {
      if (value is TypedValue) {
        return value;
      }
      if (type is OptionType) {
        return _toOptionValue(value, type, context);
      }
      if (type is OptionalType) {
        return _toOptionalValue(value, type, context);
      }
      if (type is VariadicType) {
        return _toVariadicValue(value, type, context);
      }
      if (type is CompositeType) {
        return _toCompositeValue(value, type, context);
      }
      if (type is TupleType) {
        return _toTupleValue(value, type, context);
      }
      if (type is StructType) {
        return _toStructValue(value, type, context);
      }
      if (type is ListType) {
        return _toListValue(value, type, context);
      }
      if (type is ArrayType) {
        return _toArrayValue(value, type, context);
      }
      if (type is EnumType) {
        return _toEnumValue(value, type, context);
      }
      if (type is ExplicitEnumType) {
        return _toExplicitEnumValue(value, type, context);
      }
      if (type is ManagedDecimalType) {
        return _toManagedDecimal(value, type, context);
      }
      if (type is PrimitiveType) {
        return _toPrimitiveValue(value, type, context);
      }

      throw AbiNativeSerializationException(
        'Unsupported type: ${type.runtimeType}',
      );
    } catch (e) {
      throw AbiNativeSerializationException(
        'Failed to convert value for $context',
        cause: e,
      );
    }
  }

  /// Converts to Option value
  static TypedValue _toOptionValue(
    dynamic native,
    OptionType type,
    String context,
  ) {
    if (native == null) {
      return OptionValue.none(type);
    }

    final TypedValue converted = _convertToTypedValue(
      native,
      type.innerType,
      context,
    );
    return OptionValue.some(type, converted);
  }

  /// Converts to List value
  static TypedValue _toListValue(
    dynamic native,
    ListType type,
    String context,
  ) {
    if (native is! List) {
      throw AbiNativeSerializationException(
        'Expected List for $context, got ${native.runtimeType}',
      );
    }

    final List<TypedValue> converted = native
        .asMap()
        .entries
        .map(
          (MapEntry<int, dynamic> entry) => _convertToTypedValue(
            entry.value,
            type.elementType,
            '$context[${entry.key}]',
          ),
        )
        .toList();

    return ListValue(type, converted);
  }

  /// Converts to Array value (fixed-length)
  static TypedValue _toArrayValue(
    dynamic native,
    ArrayType type,
    String context,
  ) {
    if (native is! List) {
      throw AbiNativeSerializationException(
        'Expected List for Array $context, got ${native.runtimeType}',
      );
    }

    if (native.length != type.length) {
      throw AbiNativeSerializationException(
        'Array $context expects exactly ${type.length} elements, got ${native.length}',
      );
    }

    final List<TypedValue> converted = native
        .asMap()
        .entries
        .map(
          (MapEntry<int, dynamic> entry) => _convertToTypedValue(
            entry.value,
            type.elementType,
            '$context[${entry.key}]',
          ),
        )
        .toList();

    return ArrayValue(type, converted);
  }

  /// Converts to Optional value
  static TypedValue _toOptionalValue(
    dynamic native,
    OptionalType type,
    String context,
  ) {
    if (native == null) {
      return OptionalValue.missing(type);
    }

    final TypedValue converted = _convertToTypedValue(
      native,
      type.innerType,
      context,
    );
    return OptionalValue.provided(type, converted);
  }

  /// Converts to Variadic value
  static TypedValue _toVariadicValue(
    dynamic native,
    VariadicType type,
    String context,
  ) {
    if (type.isCounted) {
      throw const AbiNativeSerializationException(
        'Counted variadic arguments must be explicitly typed. '
        'Use VariadicValue.counted() constructor or VariadicValue with explicit items.',
      );
    }

    final List nativeList = native ?? [];

    final List<TypedValue> converted = nativeList
        .asMap()
        .entries
        .map(
          (MapEntry<int, dynamic> entry) => _convertToTypedValue(
            entry.value,
            type.itemType,
            '$context[${entry.key}]',
          ),
        )
        .toList();

    return VariadicValue(converted, itemType: type.itemType, isCounted: false);
  }

  /// Converts to Composite value
  static TypedValue _toCompositeValue(
    dynamic native,
    CompositeType type,
    String context,
  ) {
    if (native is! List) {
      throw AbiNativeSerializationException(
        'Expected List for Composite type in $context, got ${native.runtimeType}',
      );
    }

    final List<AbiType> typeParameters = type.typeParameters;
    if (native.length != typeParameters.length) {
      throw AbiNativeSerializationException(
        'Composite type expects ${typeParameters.length} values but got ${native.length}',
      );
    }

    final List<TypedValue> typedValues = <TypedValue>[];
    for (int i = 0; i < typeParameters.length; i++) {
      typedValues.add(
        _convertToTypedValue(native[i], typeParameters[i], '$context[$i]'),
      );
    }

    return CompositeValue(type, typedValues);
  }

  /// Converts to Tuple value
  static TypedValue _toTupleValue(
    dynamic native,
    TupleType type,
    String context,
  ) {
    if (native is! List) {
      throw AbiNativeSerializationException(
        'Expected List for Tuple type in $context, got ${native.runtimeType}',
      );
    }

    final List<AbiType> elementTypes = type.elementTypes;
    if (native.length != elementTypes.length) {
      throw AbiNativeSerializationException(
        'Tuple expects ${elementTypes.length} elements but got ${native.length}',
      );
    }

    final List<Field> fields = <Field>[];
    for (int i = 0; i < elementTypes.length; i++) {
      final TypedValue typedValue = _convertToTypedValue(
        native[i],
        elementTypes[i],
        '$context[$i]',
      );
      fields.add(Field(name: 'field$i', value: typedValue));
    }

    return TupleValue(type, Fields(fields));
  }

  /// Converts to Struct value
  static TypedValue _toStructValue(
    dynamic native,
    StructType type,
    String context,
  ) {
    if (native is! Map) {
      throw AbiNativeSerializationException(
        'Expected Map for Struct type in $context, got ${native.runtimeType}',
      );
    }

    final List<Field> structFields = <Field>[];
    final List<FieldDefinition> fieldDefs = type.fieldDefinitions;

    for (int i = 0; i < fieldDefs.length; i++) {
      final FieldDefinition fieldDef = fieldDefs[i];
      final String fieldName = fieldDef.name;

      if (!native.containsKey(fieldName)) {
        throw AbiNativeSerializationException(
          'Missing field "$fieldName" in Struct for $context',
        );
      }

      final dynamic fieldNativeValue = native[fieldName];
      final TypedValue fieldTypedValue = _convertToTypedValue(
        fieldNativeValue,
        fieldDef.type,
        '$context.$fieldName',
      );

      structFields.add(Field(name: fieldName, value: fieldTypedValue));
    }

    return StructValue(type, Fields(structFields));
  }

  /// Converts to Enum value
  static TypedValue _toEnumValue(
    dynamic native,
    EnumType type,
    String context,
  ) {
    if (native is int) {
      final EnumVariantDefinition variant = type.getVariantByDiscriminant(
        native,
      );
      return EnumValue(type, variant, const <TypedValue>[]);
    }
    if (native is String) {
      final EnumVariantDefinition variant = type.getVariant(native);
      if (variant.hasFields) {
        throw AbiNativeSerializationException(
          'Enum variant "$native" has fields but no values provided in $context',
        );
      }
      return EnumValue(type, variant, const <TypedValue>[]);
    }
    if (native is Map) {
      final String? variantName = optionalAs<String>(
        native['variant'],
        'variant',
      );
      if (variantName == null) {
        throw AbiNativeSerializationException(
          'Enum object must have "variant" field in $context',
        );
      }

      final EnumVariantDefinition variant = type.getVariant(variantName);

      if (!variant.hasFields) {
        return EnumValue(type, variant, const <TypedValue>[]);
      }
      final dynamic fieldsData = native['fields'];
      if (fieldsData == null) {
        throw AbiNativeSerializationException(
          'Enum variant "$variantName" has fields but no values provided in $context',
        );
      }
      final List<TypedValue> fieldValues = <TypedValue>[];

      if (fieldsData is List) {
        if (fieldsData.length != variant.fieldCount) {
          throw AbiNativeSerializationException(
            'Enum variant "$variantName" expects ${variant.fieldCount} fields but got ${fieldsData.length} in $context',
          );
        }

        for (int i = 0; i < fieldsData.length; i++) {
          final TypedValue typedValue = _convertToTypedValue(
            fieldsData[i],
            variant.fields![i],
            '$context.$variantName.field$i',
          );
          fieldValues.add(typedValue);
        }
      } else if (fieldsData is Map) {
        for (int i = 0; i < variant.fieldCount; i++) {
          final String fieldKey = 'field$i';
          if (!fieldsData.containsKey(fieldKey)) {
            throw AbiNativeSerializationException(
              'Missing field "$fieldKey" in Enum variant "$variantName" for $context',
            );
          }

          final TypedValue typedValue = _convertToTypedValue(
            fieldsData[fieldKey],
            variant.fields![i],
            '$context.$variantName.$fieldKey',
          );
          fieldValues.add(typedValue);
        }
      } else {
        throw AbiNativeSerializationException(
          'Enum fields must be List or Map in $context, got ${fieldsData.runtimeType}',
        );
      }

      return EnumValue(type, variant, fieldValues);
    }

    throw AbiNativeSerializationException(
      'Unsupported native type for Enum: ${native.runtimeType} in $context',
    );
  }

  /// Converts to ExplicitEnum value
  static TypedValue _toExplicitEnumValue(
    dynamic native,
    ExplicitEnumType type,
    String context,
  ) {
    if (native is String) {
      final ExplicitEnumVariantDefinition variant = type.getVariant(native);
      return ExplicitEnumValue(type, variant);
    }
    if (native is int) {
      final ExplicitEnumVariantDefinition variant = type
          .getVariantByDiscriminant(native);
      return ExplicitEnumValue(type, variant);
    }
    if (native is Map) {
      final String? variantName = optionalAs<String>(native['name'], 'name');
      if (variantName != null) {
        final ExplicitEnumVariantDefinition variant = type.getVariant(
          variantName,
        );
        return ExplicitEnumValue(type, variant);
      }

      final int? discriminant = optionalAs<int>(
        native['discriminant'],
        'discriminant',
      );
      if (discriminant != null) {
        final ExplicitEnumVariantDefinition variant = type
            .getVariantByDiscriminant(discriminant);
        return ExplicitEnumValue(type, variant);
      }

      throw AbiNativeSerializationException(
        'ExplicitEnum object must have "name" or "discriminant" field in $context',
      );
    }

    throw AbiNativeSerializationException(
      'Unsupported native type for ExplicitEnum: ${native.runtimeType} in $context',
    );
  }

  /// Converts to ManagedDecimal value
  static TypedValue _toManagedDecimal(
    dynamic native,
    ManagedDecimalType type,
    String context,
  ) {
    if (native is List && native.length == 2) {
      final BigInt mantissa = _toBigInt(native[0], '$context.mantissa');
      final int scale = _toInt(native[1], '$context.scale');
      return ManagedDecimalValue(
        mantissa,
        scale: scale,
        isSigned: type.isSigned,
        isVariable: type.isVariable,
      );
    }

    throw AbiNativeSerializationException(
      'ManagedDecimal expects [mantissa, scale] List in $context, got ${native.runtimeType}',
    );
  }

  /// Converts to primitive value
  static TypedValue _toPrimitiveValue(
    dynamic native,
    PrimitiveType type,
    String context,
  ) {
    switch (type.runtimeType) {
      case const (U8Type):
        return U8Value(_toInt(native, context));
      case const (U16Type):
        return U16Value(_toInt(native, context));
      case const (U32Type):
        return U32Value(_toInt(native, context));
      case const (U64Type):
        return U64Value(_toBigInt(native, context));
      case const (BigUIntType):
        return BigUIntValue(_toBigInt(native, context));
      case const (I8Type):
        return I8Value(_toInt(native, context));
      case const (I16Type):
        return I16Value(_toInt(native, context));
      case const (I32Type):
        return I32Value(_toInt(native, context));
      case const (I64Type):
        return I64Value(_toBigInt(native, context));
      case const (BigIntType):
        return BigIntValue(_toBigInt(native, context));
      case const (AddressType):
        return AddressValue(_convertNativeToAddress(native, context));
      case const (BooleanType):
        return BooleanValue(_toBool(native, context));
      case const (StringType):
        return StringValue(_toString(native, context));
      case const (BytesType):
        return BytesValue(_toBytes(native, context));
      case const (TokenIdentifierType):
        return TokenIdentifierValue(_toString(native, context));
      case const (EgldOrEsdtTokenIdentifierType):
        return EgldOrEsdtTokenIdentifierValue(_toString(native, context));
      case const (H256Type):
        return _toH256Value(native, context);
      case const (CodeMetadataType):
        return _toCodeMetadataValue(native, context);
      case const (NothingType):
        return NothingValue();
      default:
        throw AbiNativeSerializationException(
          'Unsupported primitive type: ${type.runtimeType}',
        );
    }
  }

  /// Converts to int
  static int _toInt(dynamic value, String context) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final int? parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    if (value is BigInt) return value.toInt();

    throw AbiNativeSerializationException(
      'Cannot convert ${value.runtimeType} to int for $context',
    );
  }

  /// Converts to BigInt
  static BigInt _toBigInt(dynamic value, String context) {
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    if (value is double) return BigInt.from(value.toInt());
    if (value is String) {
      final BigInt? parsed = BigInt.tryParse(value);
      if (parsed != null) return parsed;
    }

    throw AbiNativeSerializationException(
      'Cannot convert ${value.runtimeType} to BigInt for $context',
    );
  }

  /// Converts to bool
  static bool _toBool(dynamic value, String context) {
    if (value is bool) return value;
    if (value is String) {
      final String str = value.toLowerCase();
      return str == 'true' || str == '1';
    }
    if (value is num) return value != 0;

    throw AbiNativeSerializationException(
      'Cannot convert ${value.runtimeType} to bool for $context',
    );
  }

  /// Converts to string
  static String _toString(dynamic value, String context) {
    if (value == null) {
      throw AbiNativeSerializationException(
        'Cannot convert null to String for $context',
      );
    }
    return value.toString();
  }

  /// Converts to bytes
  static Uint8List _toBytes(dynamic value, String context) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    if (value is String) {
      if (value.startsWith('0x') || value.startsWith('0X')) {
        return HexUtils.hexToBytes(value.substring(2));
      }
      return Uint8List.fromList(utf8.encode(value));
    }

    throw AbiNativeSerializationException(
      'Cannot convert ${value.runtimeType} to bytes for $context',
    );
  }

  /// Converts native to address.
  static Uint8List _convertNativeToAddress(dynamic native, String context) {
    if (native is String) {
      final int separatorIndex = native.lastIndexOf('1');
      if (separatorIndex > 0) {
        final String hrp = native.substring(0, separatorIndex);
        if (hrp.isNotEmpty && !native.startsWith('0x') && native.length > 10) {
          try {
            final Bech32Encoder bech32Encoder = Bech32Encoder(hrp: hrp);
            final Uint8List bytes = bech32Encoder.decode(native);

            if (bytes.length != 32) {
              throw AbiNativeSerializationException(
                'Invalid bech32 address: expected 32 bytes, got ${bytes.length} for $context',
              );
            }

            return Uint8List.fromList(bytes);
          } catch (e) {
            // Fall through to hex detection below if bech32 decode fails
            if (e is AbiNativeSerializationException) rethrow;
          }
        }
      }
      if (native.startsWith('0x')) {
        return HexUtils.hexToBytes(native.substring(2));
      }
      if (native.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(native)) {
        try {
          return HexUtils.hexToBytes(native);
        } catch (e) {
          throw AbiNativeSerializationException(
            'Invalid hex address format for $context: $e',
          );
        }
      }

      throw AbiNativeSerializationException(
        'Invalid address format for $context: must be bech32 (erd1...), hex (0x...), or 64-char hex',
      );
    }

    if (native is Uint8List) {
      if (native.length == 32) {
        return native;
      }
      throw AbiNativeSerializationException(
        'Address bytes must be 32 bytes long, got ${native.length} for $context',
      );
    }

    if (native is List<int>) {
      final Uint8List bytes = Uint8List.fromList(native);
      if (bytes.length == 32) {
        return bytes;
      }
      throw AbiNativeSerializationException(
        'Address bytes must be 32 bytes long, got ${bytes.length} for $context',
      );
    }

    throw AbiNativeSerializationException(
      'Cannot convert ${native.runtimeType} to Address for $context',
    );
  }

  /// Converts native to H256 value (32-byte hash).
  static H256Value _toH256Value(dynamic native, String context) {
    if (native is String) {
      return H256Value.fromHex(native);
    }
    if (native is List<int>) {
      return H256Value(native);
    }

    throw AbiNativeSerializationException(
      'Cannot convert ${native.runtimeType} to H256 for $context. '
      'Expected hex string or 32-byte List<int>.',
    );
  }

  /// Converts native to CodeMetadata value.
  static CodeMetadataValue _toCodeMetadataValue(
    dynamic native,
    String context,
  ) {
    if (native is int) {
      return CodeMetadataValue(native);
    }
    if (native is List<int> && native.length == 2) {
      final int value = (native[0] << 8) | native[1];
      return CodeMetadataValue(value);
    }

    throw AbiNativeSerializationException(
      'Cannot convert ${native.runtimeType} to CodeMetadata for $context. '
      'Expected int (0-65535) or 2-byte List<int>.',
    );
  }

  /// Creates typed values from native values using type formula strings.
  ///
  /// #### Parameters
  /// - `nativeValues` - Native Dart values
  /// - `typeFormulas` - Type formula strings matching values
  ///
  /// #### Throws
  /// - `AbiNativeSerializationException` - If counts mismatch or parsing fails
  static List<TypedValue> createTypedValues(
    List<dynamic> nativeValues,
    List<String> typeFormulas,
  ) {
    if (nativeValues.length != typeFormulas.length) {
      throw AbiNativeSerializationException(
        'Value count (${nativeValues.length}) does not match type formula count (${typeFormulas.length})',
      );
    }

    final List<TypedValue> values = <TypedValue>[];

    for (int i = 0; i < nativeValues.length; i++) {
      try {
        final TypeFormula typeFormula = TypeFormulaParser.parseString(
          typeFormulas[i],
        );
        final AbiType abiType = AbiTypeFactory().fromTypeFormula(typeFormula);
        final TypedValue typedValue = _convertToTypedValue(
          nativeValues[i],
          abiType,
          'Argument $i (${typeFormulas[i]})',
        );
        values.add(typedValue);
      } catch (e) {
        throw AbiNativeSerializationException(
          'Failed to create typed value for argument $i with type "${typeFormulas[i]}"',
          cause: e,
        );
      }
    }

    return values;
  }

  /// Validates that native values can be converted to specified type formulas.
  ///
  /// #### Parameters
  /// - `nativeValues` - Native Dart values
  /// - `typeFormulas` - Type formula strings
  static bool validateValues(
    List<dynamic> nativeValues,
    List<String> typeFormulas,
  ) {
    if (nativeValues.length != typeFormulas.length) return false;

    try {
      for (int i = 0; i < nativeValues.length; i++) {
        final TypeFormula typeFormula = TypeFormulaParser.parseString(
          typeFormulas[i],
        );
        final AbiType abiType = AbiTypeFactory().fromTypeFormula(typeFormula);
        if (!abiType.canAcceptValue(nativeValues[i])) {
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Converts typed values back to native Dart values.
  ///
  /// #### Parameters
  /// - `typedValues` - ABI typed values
  static List<dynamic> typedValuesToNative(List<TypedValue> typedValues) {
    return typedValues.map((TypedValue value) => value.valueOf()).toList();
  }

  /// Converts typed values to human-readable string representations.
  ///
  /// #### Parameters
  /// - `typedValues` - ABI typed values
  static List<String> typedValuesToReadable(List<TypedValue> typedValues) {
    return typedValues.map((TypedValue value) => value.toString()).toList();
  }
}
