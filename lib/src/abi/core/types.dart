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
import '../types/special/managed_decimal.dart';
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
export '../types/special/managed_decimal.dart';
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
class AbiTypeFactory {
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

  AbiType _parseStruct(String name, Map<String, dynamic> definition) {
    final fields = <FieldDefinition>[];
    final fieldsList = requireAs<List<dynamic>>(definition['fields'], 'fields');

    for (final fieldDef in fieldsList) {
      final fieldName = requireAs<String>(fieldDef['name'], 'name');
      final fieldTypeStr = requireAs<String>(fieldDef['type'], 'type');
      final fieldType = fromString(fieldTypeStr);
      fields.add(FieldDefinition(name: fieldName, type: fieldType));
    }

    return StructType(name: name, fieldDefinitions: fields);
  }

  AbiType _parseEnum(String name, Map<String, dynamic> definition) {
    final variants = <EnumVariantDefinition>[];
    final variantsList = requireAs<List<dynamic>>(
      definition['variants'],
      'variants',
    );

    for (final variantDef in variantsList) {
      variants.add(
        EnumVariantDefinition(
          name: requireAs<String>(variantDef['name'], 'name'),
          discriminant: requireAs<int>(
            variantDef['discriminant'],
            'discriminant',
          ),
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
        return ArrayType(fromTypeFormula(formula.typeParameters[0]), size);
      }
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
      case 'MultiValue2':
      case 'MultiValue3':
      case 'MultiValue4':
      case 'MultiValue5':
      case 'MultiValue6':
      case 'MultiValue7':
      case 'MultiValue8':
        if (formula.typeParameters.isEmpty) {
          throw ArgumentError(
            'Tuple type requires at least one type parameter',
          );
        }
        final List<AbiType> elementTypes = formula.typeParameters
            .map((TypeFormula param) => fromTypeFormula(param))
            .toList();
        return TupleType(elementTypes);

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
          return ManagedDecimalType.variable(0);
        }
        final int scale = int.parse(scaleParam);
        return ManagedDecimalType.of(scale);

      case 'ManagedDecimalSigned':
        if (formula.typeParameters.isEmpty) {
          throw ArgumentError(
            'ManagedDecimalSigned type requires scale parameter',
          );
        }
        final String scaleParam = formula.typeParameters.first.name;
        if (scaleParam == 'usize') {
          return ManagedDecimalType.variable(0, isSigned: true);
        }
        final int scale = int.parse(scaleParam);
        return ManagedDecimalType.signed(scale);

      case 'counted-variadic':
        if (formula.typeParameters.isEmpty) {
          throw ArgumentError('Counted variadic type requires type parameter');
        }
        return VariadicType.counted(
          fromTypeFormula(formula.typeParameters.first),
        );

      case 'multi':
      case 'Multi':
      case 'MultiArg':
      case 'MultiResult':
        if (formula.typeParameters.isEmpty) {
          throw ArgumentError(
            'Composite (multi) type requires at least one type parameter',
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

      case 'EgldOrEsdtTokenIdentifier':
        return EgldOrEsdtTokenIdentifierType.type;

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
      case 'EgldOrEsdtTokenIdentifier':
        return EgldOrEsdtTokenIdentifierType.type;
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
