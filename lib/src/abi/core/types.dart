/// Type factories and utilities for creating ABI types from strings and formulas.
import '../../utils/helpers.dart';
import '../../utils/sdk_exceptions.dart';
import '../../utils/string_utils.dart';
import '../types/collections/array.dart';
import '../types/collections/list.dart';
import '../types/collections/option.dart';
import '../types/composite/enum.dart';
import '../types/composite/explicit_enum.dart';
import '../types/composite/fields.dart';
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
import '../types/special/managed_byte_array.dart';
import '../types/special/managed_decimal.dart';
import '../types/special/multi_value.dart';
import '../types/special/nothing.dart';
import '../types/special/optional.dart';
import '../types/special/token_identifier.dart';
import '../types/special/variadic.dart';
import 'type_formula.dart';
import 'type_formula_parser.dart';
import 'type_system.dart';

export '../types/collections/array.dart';
export '../types/collections/list.dart';
export '../types/collections/option.dart';
export '../types/composite/enum.dart';
export '../types/composite/explicit_enum.dart';
export '../types/composite/fields.dart';
export '../types/composite/struct.dart';
export '../types/composite/tuple.dart';
export '../types/primitives/address.dart';
export '../types/primitives/boolean.dart';
export '../types/primitives/bytes.dart';
export '../types/primitives/numerical.dart';
export '../types/primitives/string.dart';
export '../types/special/code_metadata.dart';
export '../types/special/composite.dart';
export '../types/special/h256.dart';
export '../types/special/managed_byte_array.dart';
export '../types/special/managed_decimal.dart';
export '../types/special/multi_value.dart';
export '../types/special/nothing.dart';
export '../types/special/optional.dart';
export '../types/special/token_identifier.dart';
export '../types/special/variadic.dart';
export 'type_system.dart' show AbiType, TypedValue, PrimitiveType, CustomType;

/// Helper class for storing type suggestions with their similarity distance.
///
/// Used internally by [AbiTypeFactory] for "Did you mean?" error suggestions.
class _TypeSuggestion {
  /// Creates a type suggestion with a similarity distance.
  ///
  /// #### Parameters
  /// - `typeName` - The suggested type name
  /// - `distance` - Levenshtein distance from the input (0 = exact match)
  const _TypeSuggestion(this.typeName, this.distance);

  /// The suggested type name.
  final String typeName;

  /// Levenshtein distance from the requested type name.
  /// Lower values indicate closer similarity (0 = exact match).
  final int distance;
}

/// Factory for creating AbiType instances from type strings and formulas.
class AbiTypeFactory implements ExplicitEnumTypeRegistry {
  final Map<String, AbiType> _customTypes = <String, AbiType>{};
  final Map<String, bool> _registeredNames = <String, bool>{};
  final Set<String> _inResolution = <String>{};

  /// Creates a new AbiTypeFactory instance.
  ///
  /// #### Parameters
  /// - `initialTypes` - Optional map of custom types to register at creation
  AbiTypeFactory({Map<String, AbiType>? initialTypes}) {
    if (initialTypes != null) {
      _customTypes.addAll(initialTypes);
    }
  }

  void registerTypeName(String name) {
    _registeredNames[name] = false;
  }

  bool hasTypeName(String name) {
    return _registeredNames.containsKey(name);
  }

  AbiType resolveType(String name, Map<String, dynamic> definition) {
    if (!_registeredNames.containsKey(name)) {
      throw ArgumentError('Type $name not registered');
    }

    if (_registeredNames[name]!) {
      return _customTypes[name]!;
    }

    _inResolution.add(name);

    try {
      final type = _parseTypeDefinition(name, definition);
      _customTypes[name] = type;
      _registeredNames[name] = true;
      return type;
    } finally {
      _inResolution.remove(name);
    }
  }

  AbiType _parseTypeDefinition(String name, Map<String, dynamic> definition) {
    final typeKind = requireAs<String>(definition['type'], 'type');

    if (typeKind == 'struct') {
      return _parseStruct(name, definition);
    } else if (typeKind == 'enum') {
      return _parseEnum(name, definition);
    } else if (typeKind == 'explicit-enum') {
      return _parseExplicitEnum(name, definition);
    }

    throw ArgumentError('Unknown type kind: $typeKind');
  }

  /// Parses a struct definition with forward-reference support.
  ///
  /// Self-referential structs (`Node { children: List<Node> }`) are valid
  /// because `List<Node>` is runtime-bounded — the cycle is bounded by the
  /// data, not the type. To allow this we pre-register an empty struct in
  /// `_customTypes` BEFORE descending into fields, so any recursive lookup
  /// resolves to the same placeholder instance. The placeholder's
  /// `fieldDefinitions` list is then populated in place as we parse — the
  /// returned StructType is the same instance every reference points at.
  AbiType _parseStruct(String name, Map<String, dynamic> definition) {
    final fields = <FieldDefinition>[];
    final StructType placeholder = StructType(
      name: name,
      fieldDefinitions: fields,
    );
    _customTypes[name] = placeholder;

    final fieldsList =
        optionalAs<List<dynamic>>(definition['fields'], 'fields') ??
        const <dynamic>[];

    for (final fieldDef in fieldsList) {
      final fieldName = requireAs<String>(fieldDef['name'], 'name');
      final fieldTypeStr = requireAs<String>(fieldDef['type'], 'type');
      final fieldType = fromString(fieldTypeStr);
      fields.add(FieldDefinition(name: fieldName, type: fieldType));
    }

    return placeholder;
  }

  /// Parses an enum definition, including data-carrying variant payloads.
  ///
  /// A variant's optional `fields` array is the wire payload that follows the
  /// discriminant byte: `[u8 discriminant][dep-encoded field 0][field 1]…`.
  /// Declaration order **is** wire order, so the parsed list preserves it.
  /// Field types are resolved through [fromString] so nested custom types
  /// referenced by a variant resolve against the already-registered
  /// dependencies.
  AbiType _parseEnum(String name, Map<String, dynamic> definition) {
    final variants = <EnumVariantDefinition>[];
    final variantsList = requireAs<List<dynamic>>(
      definition['variants'],
      'variants',
    );

    for (final variantDef in variantsList) {
      final List<dynamic>? fieldsList = optionalAs<List<dynamic>>(
        variantDef['fields'],
        'fields',
      );
      final List<AbiType>? fieldTypes = fieldsList == null
          ? null
          : <AbiType>[
              for (final dynamic fieldDef in fieldsList)
                fromString(requireAs<String>(fieldDef['type'], 'type')),
            ];
      variants.add(
        EnumVariantDefinition(
          name: requireAs<String>(variantDef['name'], 'name'),
          discriminant: requireAs<int>(
            variantDef['discriminant'],
            'discriminant',
          ),
          fields: fieldTypes,
        ),
      );
    }

    return EnumType(name: name, variants: variants);
  }

  /// Parses an explicit-enum type definition from ABI JSON.
  ///
  /// Explicit enums are serialized by variant name (string) instead of
  /// discriminant (integer). Used for human-readable serialization.
  ///
  /// #### Parameters
  /// - `name` - Type name
  /// - `definition` - Map with 'variants' array
  ///
  /// #### Returns
  /// `ExplicitEnumType` - Parsed explicit enum type
  AbiType _parseExplicitEnum(String name, Map<String, dynamic> definition) {
    final List<ExplicitEnumVariantDefinition> variants =
        <ExplicitEnumVariantDefinition>[];
    final List<dynamic> variantsList = requireAs<List<dynamic>>(
      definition['variants'],
      'variants',
    );

    for (int i = 0; i < variantsList.length; i++) {
      final Map<String, dynamic> variantDef = requireAs<Map<String, dynamic>>(
        variantsList[i],
        'variants[$i]',
      );
      variants.add(
        ExplicitEnumVariantDefinition(
          name: requireAs<String>(variantDef['name'], 'name'),
          discriminant:
              optionalAs<int>(variantDef['discriminant'], 'discriminant') ?? i,
        ),
      );
    }

    return ExplicitEnumType(name: name, variants: variants);
  }

  /// Registers a custom type for type resolution.
  ///
  /// #### Parameters
  /// - `name` - Type name (e.g., 'MyStruct')
  /// - `type` - AbiType instance to register
  void registerCustomType(String name, AbiType type) {
    _customTypes[name] = type;
  }

  /// Clears all registered custom types.
  void clearCustomTypes() {
    _customTypes.clear();
  }

  /// Gets a registered custom type by name.
  ///
  /// #### Parameters
  /// - `name` - Type name
  ///
  /// #### Returns
  /// `AbiType?` - Type or null if not found
  AbiType? getCustomType(String name) {
    return _customTypes[name];
  }

  @override
  Object? lookupType(String name) => _customTypes[name];

  /// Creates an AbiType from a string representation.
  ///
  /// #### Parameters
  /// - `typeString` - Type string (e.g., `u32`, `List<u32>`, `Option<Address>`)
  ///
  /// #### Returns
  /// `AbiType` - Type instance
  ///
  /// #### Throws
  /// - `ArgumentError` - Unknown or invalid type string
  AbiType fromString(String typeString) {
    final AbiType? customType = _customTypes[typeString];
    if (customType != null) {
      return customType;
    }
    final TypeFormula? formula = _tryParseTypeFormula(typeString);
    if (formula != null) {
      return fromTypeFormula(formula);
    }

    final RegExpMatch? arrayMatch = RegExp(
      r'^(.+)\[(\d+)\]$',
    ).firstMatch(typeString);
    if (arrayMatch != null) {
      final AbiType elementType = fromString(arrayMatch.group(1)!);
      final int size = int.parse(arrayMatch.group(2)!);
      return ArrayType(elementType, size);
    }
    return _fromSimpleTypeName(typeString);
  }

  TypeFormula? _tryParseTypeFormula(String typeString) {
    try {
      return TypeFormulaParser.parseString(typeString);
    } on AbiTypeFormulaParseException {
      return null;
    }
  }

  /// Creates an AbiType from a TypeFormula.
  ///
  /// A handful of built-in framework types are never emitted into the ABI's
  /// `types` map, so they must be recognised intrinsically: `TokenId` shares
  /// `TokenIdentifier`'s length-prefixed UTF-8 wire form, `NonZeroBigUint`
  /// encodes and decodes byte for byte like `BigUint`, and `Payment` /
  /// `FungiblePayment` are plain structs whose fields encode in declaration
  /// order.
  ///
  /// #### Parameters
  /// - `formula` - TypeFormula instance
  ///
  /// #### Returns
  /// `AbiType` - Type instance
  ///
  /// #### Throws
  /// - `ArgumentError` - Unknown type or missing required parameters
  AbiType fromTypeFormula(TypeFormula formula) {
    final String typeName = formula.name;
    if (formula.typeParameters.isEmpty) {
      final AbiType? customType = _customTypes[typeName];
      if (customType != null) {
        return customType;
      }
    }
    if (typeName.startsWith('array') && typeName.length > 5) {
      final sizeStr = typeName.substring(5);
      final size = int.tryParse(sizeStr);
      if (size != null && formula.typeParameters.isNotEmpty) {
        final AbiType elementType = fromTypeFormula(formula.typeParameters[0]);
        if (elementType is U8Type) {
          return ManagedByteArrayType(size);
        }
        return ArrayType(elementType, size);
      }
    }

    if (typeName == 'ManagedByteArray') {
      final String? meta = formula.metadata;
      final int? metaSize = meta == null ? null : int.tryParse(meta);
      if (metaSize != null) {
        return ManagedByteArrayType(metaSize);
      }
      if (formula.typeParameters.isNotEmpty) {
        final int? paramSize = int.tryParse(formula.typeParameters.first.name);
        if (paramSize != null) {
          return ManagedByteArrayType(paramSize);
        }
      }
      throw ArgumentError(
        'ManagedByteArray requires a numeric length, e.g. '
        'ManagedByteArray*48* or ManagedByteArray<48>',
      );
    }

    switch (typeName) {
      case 'u8':
        return U8Type.type;
      case 'u16':
        return U16Type.type;
      case 'u32':
        return U32Type.type;
      case 'u64':
      case 'U64':
        return U64Type.type;
      case 'u128':
      case 'U128':
        return BigUIntType.type;
      case 'BigUint':
      case 'NonZeroBigUint':
        return BigUIntType.type;

      case 'i8':
        return I8Type.type;
      case 'i16':
        return I16Type.type;
      case 'i32':
        return I32Type.type;
      case 'i64':
        return I64Type.type;
      case 'i128':
      case 'I128':
        return BigIntType.type;
      case 'BigInt':
      case 'Bigint':
        return BigIntType.type;

      case 'BigFloat':
        return BigFloatType.type;

      case 'Address':
        return AddressType.type;
      case 'bool':
        return BooleanType.type;
      case 'bytes':
        return BytesType.type;
      case 'string':
      case 'utf-8 string':
        return StringType.type;

      case 'List':
        if (formula.typeParameters.isEmpty) {
          throw ArgumentError('List type requires type parameter');
        }
        return ListType(fromTypeFormula(formula.typeParameters.first));

      case 'Array':
        if (formula.typeParameters.length < 2) {
          throw ArgumentError(
            'Array type requires element type and size parameters',
          );
        }
        final AbiType elementType = fromTypeFormula(formula.typeParameters[0]);
        final int size = int.parse(formula.typeParameters[1].name);
        return ArrayType(elementType, size);

      case 'array2':
        return ArrayType(fromTypeFormula(formula.typeParameters[0]), 2);
      case 'array6':
        return ArrayType(fromTypeFormula(formula.typeParameters[0]), 6);
      case 'array8':
        return ArrayType(fromTypeFormula(formula.typeParameters[0]), 8);
      case 'array16':
        return ArrayType(fromTypeFormula(formula.typeParameters[0]), 16);
      case 'array20':
        return ArrayType(fromTypeFormula(formula.typeParameters[0]), 20);
      case 'array32':
        return ArrayType(fromTypeFormula(formula.typeParameters[0]), 32);
      case 'array46':
        return ArrayType(fromTypeFormula(formula.typeParameters[0]), 46);
      case 'array48':
        return ArrayType(fromTypeFormula(formula.typeParameters[0]), 48);
      case 'array64':
        return ArrayType(fromTypeFormula(formula.typeParameters[0]), 64);
      case 'array128':
        return ArrayType(fromTypeFormula(formula.typeParameters[0]), 128);
      case 'array256':
        return ArrayType(fromTypeFormula(formula.typeParameters[0]), 256);

      case 'Option':
        if (formula.typeParameters.isEmpty) {
          throw ArgumentError('Option type requires type parameter');
        }
        return OptionType(fromTypeFormula(formula.typeParameters.first));

      case 'optional':
      case 'OptionalArg':
      case 'OptionalResult':
        if (formula.typeParameters.isEmpty) {
          throw ArgumentError('Optional type requires type parameter');
        }
        return OptionalType.of(fromTypeFormula(formula.typeParameters.first));

      case 'tuple':
      case 'Tuple':
      case 'tuple2':
      case 'tuple3':
      case 'tuple4':
      case 'tuple5':
      case 'tuple6':
      case 'tuple7':
      case 'tuple8':
        if (formula.typeParameters.isEmpty) {
          throw ArgumentError(
            'Tuple type requires at least one type parameter',
          );
        }
        final List<AbiType> tupleElementTypes = formula.typeParameters
            .map((TypeFormula param) => fromTypeFormula(param))
            .toList();
        return TupleType(tupleElementTypes);

      case 'MultiValue':
      case 'MultiValue2':
      case 'MultiValue3':
      case 'MultiValue4':
      case 'MultiValue5':
      case 'MultiValue6':
      case 'MultiValue7':
      case 'MultiValue8':
        if (formula.typeParameters.isEmpty) {
          throw ArgumentError(
            'MultiValue type requires at least one type parameter',
          );
        }
        final List<AbiType> multiValueTypes = formula.typeParameters
            .map((TypeFormula param) => fromTypeFormula(param))
            .toList();
        return MultiValueType(multiValueTypes.length, multiValueTypes);

      case 'variadic':
      case 'Variadic':
      case 'VarArgs':
      case 'MultiResultVec':
        if (formula.typeParameters.isEmpty) {
          throw ArgumentError('Variadic type requires type parameter');
        }
        return VariadicType.of(fromTypeFormula(formula.typeParameters.first));

      case 'ManagedDecimal':
        if (formula.typeParameters.isEmpty) {
          throw ArgumentError('ManagedDecimal type requires scale parameter');
        }
        final String scaleParam = formula.typeParameters.first.name;
        if (scaleParam == 'usize') {
          final int variableScale = int.tryParse(formula.metadata ?? '') ?? 0;
          return ManagedDecimalType.variable(variableScale);
        }
        final int scale = int.parse(scaleParam);
        return ManagedDecimalType.of(scale);

      case 'ManagedDecimalSigned':
        if (formula.typeParameters.isEmpty) {
          throw ArgumentError(
            'ManagedDecimalSigned type requires scale parameter',
          );
        }
        final String signedScaleParam = formula.typeParameters.first.name;
        if (signedScaleParam == 'usize') {
          final int variableScale = int.tryParse(formula.metadata ?? '') ?? 0;
          return ManagedDecimalType.variable(variableScale, isSigned: true);
        }
        final int signedScale = int.parse(signedScaleParam);
        return ManagedDecimalType.signed(signedScale);

      case 'counted-variadic':
        if (formula.typeParameters.isEmpty) {
          throw ArgumentError('Counted variadic type requires type parameter');
        }
        return VariadicType.counted(
          fromTypeFormula(formula.typeParameters.first),
        );

      case 'multi':
      case 'Multi':
      case 'multivalue':
        if (formula.typeParameters.isEmpty) {
          throw ArgumentError(
            'MultiValue type requires at least one type parameter',
          );
        }
        final List<AbiType> multiTypes = formula.typeParameters
            .map((TypeFormula param) => fromTypeFormula(param))
            .toList();
        return MultiValueType(multiTypes.length, multiTypes);

      case 'MultiArg':
      case 'MultiResult':
        if (formula.typeParameters.isEmpty) {
          throw ArgumentError(
            'Composite type requires at least one type parameter',
          );
        }
        final List<AbiType> fieldTypes = formula.typeParameters
            .map((TypeFormula param) => fromTypeFormula(param))
            .toList();
        return CompositeType.of(fieldTypes);

      case 'TokenIdentifier':
        return TokenIdentifierType.type;

      case 'EsdtTokenIdentifier':
        return TokenIdentifierType.type;

      case 'TokenId':
        return TokenIdentifierType.type;

      case 'EgldOrEsdtTokenIdentifier':
        return EgldOrEsdtTokenIdentifierType.type;

      case 'EsdtTokenPayment':
        return _builtInEsdtTokenPayment();
      case 'EgldOrEsdtTokenPayment':
        return _builtInEgldOrEsdtTokenPayment();
      case 'EgldOrMultiEsdtPayment':
        return _builtInEgldOrMultiEsdtPayment();
      case 'Payment':
        return _builtInPayment();
      case 'FungiblePayment':
        return _builtInFungiblePayment();

      case 'Nothing':
      case 'nothing':
      case 'AsyncCall':
        return NothingType.type;

      case 'struct':
      case 'Struct':
        throw ArgumentError(
          'Struct type requires field definitions. '
          'Cannot create from type string alone. '
          'Use StructType constructor directly with FieldDefinition list.',
        );

      case 'enum':
      case 'Enum':
        throw ArgumentError(
          'Enum type requires variant definitions. '
          'Cannot create from type string alone. '
          'Use EnumType constructor directly with EnumVariantDefinition list.',
        );

      case 'ExplicitEnum':
        throw ArgumentError(
          'ExplicitEnum type requires variant definitions. '
          'Cannot create from type string alone. '
          'Use ExplicitEnumType constructor directly with ExplicitEnumVariantDefinition list.',
        );

      case 'H256':
        return H256Type.type;

      case 'CodeMetadata':
        return CodeMetadataType.type;

      default:
        throw ArgumentError(_buildUnknownTypeError(typeName));
    }
  }

  /// Builds a helpful error message for unknown types with suggestions.
  ///
  /// #### Parameters
  /// - `typeName` - The unknown type name that was requested
  ///
  /// #### Returns
  /// `String` - Detailed error message with suggestions
  String _buildUnknownTypeError(String typeName) {
    final List<String> knownTypes = <String>[
      'u8',
      'u16',
      'u32',
      'u64',
      'U64',
      'BigUint',
      'i8',
      'i16',
      'i32',
      'i64',
      'BigInt',
      'Bigint',
      'Address',
      'bool',
      'bytes',
      'string',
      'utf-8 string',
      'List',
      'Array',
      'Option',
      'array2',
      'array6',
      'array8',
      'array16',
      'array20',
      'array32',
      'array46',
      'array48',
      'array64',
      'array128',
      'array256',
      'optional',
      'OptionalArg',
      'OptionalResult',
      'tuple',
      'Tuple',
      'tuple2',
      'tuple3',
      'tuple4',
      'tuple5',
      'tuple6',
      'tuple7',
      'tuple8',
      'variadic',
      'Variadic',
      'VarArgs',
      'MultiResultVec',
      'counted-variadic',
      'multi',
      'Multi',
      'MultiArg',
      'MultiResult',
      'TokenIdentifier',
      'EsdtTokenIdentifier',
      'EgldOrEsdtTokenIdentifier',
      'TokenId',
      'NonZeroBigUint',
      'Payment',
      'FungiblePayment',
      'Nothing',
      'nothing',
      'AsyncCall',
      'H256',
      'CodeMetadata',
      'struct',
      'Struct',
      'enum',
      'Enum',
      'ExplicitEnum',
      'ManagedDecimal',
      'ManagedDecimalSigned',
    ];

    final List<String> allKnownTypes = <String>[
      ...knownTypes,
      ..._customTypes.keys,
    ];
    final List<_TypeSuggestion> suggestions = <_TypeSuggestion>[];
    for (final String knownType in allKnownTypes) {
      final int distance = StringUtils.levenshteinDistance(
        typeName.toLowerCase(),
        knownType.toLowerCase(),
      );
      if (distance <= 3) {
        suggestions.add(_TypeSuggestion(knownType, distance));
      }
    }
    suggestions.sort((a, b) => a.distance.compareTo(b.distance));
    final StringBuffer message = StringBuffer();
    message.write('Unknown type: $typeName');
    if (suggestions.isNotEmpty) {
      message.write('\n\nDid you mean');
      if (suggestions.length == 1) {
        message.write(' "${suggestions.first.typeName}"?');
      } else {
        message.write(' one of these?');
        for (int i = 0; i < suggestions.length && i < 5; i++) {
          message.write('\n  - ${suggestions[i].typeName}');
        }
      }
    }
    if (_customTypes.isNotEmpty) {
      message.write('\n\nRegistered custom types (${_customTypes.length}):');
      final List<String> customTypeNames = _customTypes.keys.toList()..sort();
      for (final String customType in customTypeNames.take(10)) {
        message.write('\n  - $customType');
      }
      if (customTypeNames.length > 10) {
        message.write('\n  ... and ${customTypeNames.length - 10} more');
      }
    }

    message.write('\n\nAvailable primitive types:');
    message.write('\n  Unsigned: u8, u16, u32, u64, BigUint');
    message.write('\n  Signed: i8, i16, i32, i64, BigInt');
    message.write('\n  Other: Address, bool, bytes, string');
    message.write('\n  Collections: List<T>, Array<T, N>, Option<T>');
    message.write('\n  Special: TokenIdentifier, Nothing, H256, CodeMetadata');
    message.write(
      '\n\nNote: Struct, Enum, and ManagedDecimal types must be '
      'created from full ABI definitions with metadata.',
    );

    return message.toString();
  }

  /// Creates types from simple type names without parameters.
  ///
  /// #### Parameters
  /// - `typeName` - Simple type name (e.g., 'u32', 'Address')
  ///
  /// #### Returns
  /// `AbiType` - Type instance
  ///
  /// #### Throws
  /// - `ArgumentError` - Unknown type name
  AbiType _fromSimpleTypeName(String typeName) {
    switch (typeName) {
      case 'u8':
        return U8Type.type;
      case 'u16':
        return U16Type.type;
      case 'u32':
        return U32Type.type;
      case 'u64':
        return U64Type.type;
      case 'u128':
        return BigUIntType.type;
      case 'BigUint':
      case 'NonZeroBigUint':
        return BigUIntType.type;

      case 'i8':
        return I8Type.type;
      case 'i16':
        return I16Type.type;
      case 'i32':
        return I32Type.type;
      case 'i64':
        return I64Type.type;
      case 'i128':
        return BigIntType.type;
      case 'BigInt':
        return BigIntType.type;
      case 'BigFloat':
        return BigFloatType.type;

      case 'Address':
        return AddressType.type;
      case 'bool':
        return BooleanType.type;
      case 'bytes':
        return BytesType.type;
      case 'string':
      case 'utf-8 string':
        return StringType.type;
      case 'TokenIdentifier':
        return TokenIdentifierType.type;
      case 'EsdtTokenIdentifier':
        return TokenIdentifierType.type;
      case 'TokenId':
        return TokenIdentifierType.type;
      case 'EgldOrEsdtTokenIdentifier':
        return EgldOrEsdtTokenIdentifierType.type;
      case 'EsdtTokenPayment':
        return _builtInEsdtTokenPayment();
      case 'EgldOrEsdtTokenPayment':
        return _builtInEgldOrEsdtTokenPayment();
      case 'EgldOrMultiEsdtPayment':
        return _builtInEgldOrMultiEsdtPayment();
      case 'Payment':
        return _builtInPayment();
      case 'FungiblePayment':
        return _builtInFungiblePayment();
      case 'Nothing':
        return NothingType.type;
      case 'H256':
        return H256Type.type;
      case 'CodeMetadata':
        return CodeMetadataType.type;

      default:
        throw ArgumentError(_buildUnknownTypeError(typeName));
    }
  }

  /// Cache for built-in struct singletons. Returning the same instance for
  /// every lookup keeps `==`/`identical` behaviour consistent and lets
  /// downstream consumers (codegen, codecs) memoise on type identity.
  static final Map<String, StructType> _builtIns = <String, StructType>{};

  /// `EsdtTokenPayment { token_identifier: TokenIdentifier, token_nonce: u64, amount: BigUint }`
  /// — a built-in struct that never appears in the ABI's `types` map.
  static StructType _builtInEsdtTokenPayment() {
    return _builtIns.putIfAbsent(
      'EsdtTokenPayment',
      () => StructType(
        name: 'EsdtTokenPayment',
        fieldDefinitions: <FieldDefinition>[
          FieldDefinition(
            name: 'token_identifier',
            type: TokenIdentifierType.type,
          ),
          FieldDefinition(name: 'token_nonce', type: U64Type.type),
          FieldDefinition(name: 'amount', type: BigUIntType.type),
        ],
      ),
    );
  }

  /// `EgldOrEsdtTokenPayment { token_identifier: EgldOrEsdtTokenIdentifier, token_nonce: u64, amount: BigUint }`.
  static StructType _builtInEgldOrEsdtTokenPayment() {
    return _builtIns.putIfAbsent(
      'EgldOrEsdtTokenPayment',
      () => StructType(
        name: 'EgldOrEsdtTokenPayment',
        fieldDefinitions: <FieldDefinition>[
          FieldDefinition(
            name: 'token_identifier',
            type: EgldOrEsdtTokenIdentifierType.type,
          ),
          FieldDefinition(name: 'token_nonce', type: U64Type.type),
          FieldDefinition(name: 'amount', type: BigUIntType.type),
        ],
      ),
    );
  }

  /// `Payment { token_identifier: TokenId, token_nonce: u64, amount: NonZeroBigUint }`
  /// — a built-in struct. `TokenId` and `NonZeroBigUint` share the wire form of
  /// `TokenIdentifier` and `BigUint` respectively, so the nested layout is
  /// `[u32 len][utf8 id][8-byte BE nonce][u32 len][magnitude]`.
  static StructType _builtInPayment() {
    return _builtIns.putIfAbsent(
      'Payment',
      () => StructType(
        name: 'Payment',
        fieldDefinitions: <FieldDefinition>[
          FieldDefinition(
            name: 'token_identifier',
            type: TokenIdentifierType.type,
          ),
          FieldDefinition(name: 'token_nonce', type: U64Type.type),
          FieldDefinition(name: 'amount', type: BigUIntType.type),
        ],
      ),
    );
  }

  /// `FungiblePayment { token_identifier: TokenId, amount: NonZeroBigUint }`
  /// — a built-in struct with no custom encoding, so top-level and nested share
  /// the layout `[u32 len][utf8 id][u32 len][magnitude]`.
  static StructType _builtInFungiblePayment() {
    return _builtIns.putIfAbsent(
      'FungiblePayment',
      () => StructType(
        name: 'FungiblePayment',
        fieldDefinitions: <FieldDefinition>[
          FieldDefinition(
            name: 'token_identifier',
            type: TokenIdentifierType.type,
          ),
          FieldDefinition(name: 'amount', type: BigUIntType.type),
        ],
      ),
    );
  }

  /// `EgldOrMultiEsdtPayment { egld_amount: BigUint, multi_esdt: List<EsdtTokenPayment> }`
  /// — a built-in struct. Both fields are always present on the wire; senders
  /// that mean "EGLD only" leave `multi_esdt` empty and vice versa.
  static StructType _builtInEgldOrMultiEsdtPayment() {
    return _builtIns.putIfAbsent(
      'EgldOrMultiEsdtPayment',
      () => StructType(
        name: 'EgldOrMultiEsdtPayment',
        fieldDefinitions: <FieldDefinition>[
          FieldDefinition(name: 'egld_amount', type: BigUIntType.type),
          FieldDefinition(
            name: 'multi_esdt',
            type: ListType(_builtInEsdtTokenPayment()),
          ),
        ],
      ),
    );
  }
}

/// Extension providing backward-compatible methods and factories.
///
/// Adds convenience methods to AbiType.
extension AbiTypeExtensions on AbiType {
  /// Checks if the value is valid for this type.
  ///
  /// #### Parameters
  /// - `value` - Value to validate
  ///
  /// #### Returns
  /// `bool` - true if valid
  bool isValidValue(dynamic value) => canAcceptValue(value);

  /// Returns whether the type has dynamic length.
  bool get isDynamic => sizeInBytes == null;
}
