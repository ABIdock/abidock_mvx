/// Type formula representation for smart contract ABI types.
import 'package:meta/meta.dart';

import '../../utils/collection_utils.dart';
import '../../utils/helpers.dart';

/// Type formula for smart contract ABI types.
@immutable
class TypeFormula {
  /// Creates type formula.
  ///
  /// #### Parameters
  /// - `name` - Type name (e.g., 'List', 'Option', 'u32')
  /// - `typeParameters` - Generic type parameters (default: empty)
  const TypeFormula({
    required this.name,
    this.typeParameters = const <TypeFormula>[],
  });

  /// Creates primitive type formula without type parameters.
  ///
  /// #### Parameters
  /// - `name` - Primitive type name (e.g., 'u32', 'Address')
  const TypeFormula.primitive(this.name)
    : typeParameters = const <TypeFormula>[];

  /// Creates generic type formula with single type parameter.
  ///
  /// #### Parameters
  /// - `name` - Generic type name (e.g., 'Option', 'List')
  /// - `parameter` - Type parameter formula
  TypeFormula.withSingleParameter(this.name, TypeFormula parameter)
    : typeParameters = <TypeFormula>[parameter];

  /// Creates generic type formula with multiple type parameters.
  ///
  /// #### Parameters
  /// - `name` - Generic type name (e.g., 'Tuple')
  /// - `typeParameters` - List of type parameter formulas
  const TypeFormula.withParameters(this.name, this.typeParameters);

  /// Creates from JSON map.
  ///
  /// #### Parameters
  /// - `json` - Map with 'name' and optional 'typeParameters'
  ///
  /// #### Returns
  /// `TypeFormula` - Type formula instance
  ///
  /// #### Throws
  /// - `TypeError` - Invalid JSON structure
  factory TypeFormula.fromJson(Map<String, dynamic> json) {
    return TypeFormula(
      name: requireAs<String>(json['name'], 'name'),
      typeParameters:
          optionalAs<List<dynamic>>(json['typeParameters'], 'typeParameters')
              ?.map(
                (dynamic p) => TypeFormula.fromJson(
                  requireAs<Map<String, dynamic>>(p, 'typeParameter'),
                ),
              )
              .toList() ??
          const <TypeFormula>[],
    );
  }

  /// Type name (e.g., "List", "Option", "u32").
  final String name;

  /// Type parameters for generic types.
  final List<TypeFormula> typeParameters;

  /// Whether primitive type (no type parameters).
  bool get isPrimitive => typeParameters.isEmpty;

  /// Whether generic type (has type parameters).
  bool get isGeneric => typeParameters.isNotEmpty;

  /// Gets first type parameter, or null if none exist.
  TypeFormula? get firstTypeParameter =>
      typeParameters.isNotEmpty ? typeParameters.first : null;

  /// Gets type parameter at index.
  TypeFormula getTypeParameter(int index) => typeParameters[index];

  /// Number of type parameters.
  int get typeParameterCount => typeParameters.length;

  /// Checks if type formula has specified name.
  ///
  /// #### Parameters
  /// - `typeName` - Name to check
  ///
  /// #### Returns
  /// `bool` - true if names match
  bool hasName(String typeName) => name == typeName;

  /// Checks if Option type.
  bool get isOption => name == 'Option';

  /// Checks if List type.
  bool get isList => name == 'List';

  /// Checks if Array type.
  bool get isArray => name == 'Array';

  /// Checks if Tuple type.
  bool get isTuple => name == 'Tuple';

  /// Checks if Struct type.
  bool get isStruct => name == 'Struct';

  /// Checks if numerical type.
  bool get isNumerical {
    return const <String>{
      'u8',
      'u16',
      'u32',
      'u64',
      'i8',
      'i16',
      'i32',
      'i64',
      'BigUInt',
      'BigInt',
    }.contains(name);
  }

  /// Checks if Address type.
  bool get isAddress => name == 'Address';

  /// Checks if Boolean type.
  bool get isBoolean => name == 'bool';

  /// Checks if String type.
  bool get isString => name == 'String';

  /// Checks if Bytes type.
  bool get isBytes => name == 'bytes';

  /// Returns string representation.
  ///
  /// #### Returns
  /// `String` - Type string (e.g., `Option<Address>`, `List<u32>`)

  @override
  String toString() {
    if (isPrimitive) {
      return name;
    }

    final String parametersString = typeParameters
        .map((TypeFormula p) => p.toString())
        .join(', ');
    return '$name<$parametersString>';
  }

  /// Creates copy with optional modifications.
  ///
  /// #### Parameters
  /// - `name` - New name (optional)
  /// - `typeParameters` - New type parameters (optional)
  ///
  /// #### Returns
  /// `TypeFormula` - New type formula instance
  TypeFormula copyWith({String? name, List<TypeFormula>? typeParameters}) {
    return TypeFormula(
      name: name ?? this.name,
      typeParameters: typeParameters ?? this.typeParameters,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypeFormula &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          CollectionUtils.listEquals(typeParameters, other.typeParameters);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(typeParameters));

  /// Converts to JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'typeParameters': typeParameters
        .map((TypeFormula p) => p.toJson())
        .toList(),
  };

  /// Validates that type formula is well-formed.
  bool validate() {
    if (name.isEmpty) return false;

    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_-]*$').hasMatch(name)) return false;

    return typeParameters.every((TypeFormula param) => param.validate());
  }

  /// Gets depth of nesting in type formula.
  int get depth {
    if (isPrimitive) return 1;

    final int maxParameterDepth = typeParameters
        .map((TypeFormula p) => p.depth)
        .fold(0, (int a, int b) => a > b ? a : b);
    return 1 + maxParameterDepth;
  }

  /// Flattens type formula into list of all type names.
  List<String> flatten() {
    final List<String> result = <String>[name];
    for (final TypeFormula param in typeParameters) {
      result.addAll(param.flatten());
    }
    return result;
  }
}
