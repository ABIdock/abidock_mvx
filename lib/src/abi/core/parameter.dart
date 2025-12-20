import 'package:meta/meta.dart';

import '../../utils/collection_utils.dart';
import '../../utils/helpers.dart';
import 'types.dart';

/// Smart contract function parameter definition.
@immutable
final class AbiParameter {
  /// Creates parameter.
  ///
  /// #### Parameters
  /// - `name` - Parameter name (required)
  /// - `type` - Parameter type (required)
  /// - `multiResult` - Whether this is a multi_result output (variable count)
  /// - `documentation` - Optional docs
  const AbiParameter({
    required this.name,
    required this.type,
    this.multiResult = false,
    this.documentation,
  });

  /// Creates parameter from type string.
  ///
  /// #### Parameters
  /// - `name` - Parameter name (required)
  /// - `typeString` - Type as string (e.g., 'BigUInt', 'List<Address>')
  /// - `documentation` - Optional docs
  /// - `typeFactory` - Optional AbiTypeFactory for custom type resolution
  ///
  /// #### Returns
  /// `AbiParameter` - Parameter instance
  factory AbiParameter.fromTypeString({
    required String name,
    required String typeString,
    bool multiResult = false,
    String? documentation,
    AbiTypeFactory? typeFactory,
  }) {
    final AbiTypeFactory factory = typeFactory ?? AbiTypeFactory();
    return AbiParameter(
      name: name,
      type: factory.fromString(typeString),
      multiResult: multiResult,
      documentation: documentation,
    );
  }

  /// Creates parameter from JSON map.
  ///
  /// #### Parameters
  /// - `data` - Map with 'name', 'type', optional 'docs'/'documentation'
  /// - `typeFactory` - Optional AbiTypeFactory for custom type resolution
  ///
  /// #### Returns
  /// `AbiParameter` - Parameter instance (defaults name to 'output' if empty)
  factory AbiParameter.fromMap(
    Map<String, dynamic> data, {
    AbiTypeFactory? typeFactory,
  }) {
    final String name = optionalAs<String>(data['name'], 'name') ?? '';
    final String typeString =
        optionalAs<String>(data['type'], 'type') ?? 'bytes';
    final bool multiResult =
        optionalAs<bool>(data['multi_result'], 'multi_result') ?? false;

    String? docs;
    if (data.containsKey('docs')) {
      final dynamic docsValue = data['docs'];
      if (docsValue is String) {
        docs = docsValue;
      } else if (docsValue is List) {
        docs = docsValue.join('\n');
      }
    } else if (data.containsKey('documentation')) {
      final dynamic docValue = data['documentation'];
      if (docValue is String) {
        docs = docValue;
      } else if (docValue is List) {
        docs = docValue.join('\n');
      }
    }

    final String paramName = name.isEmpty ? 'output' : name;
    final AbiTypeFactory factory = typeFactory ?? AbiTypeFactory();

    return AbiParameter(
      name: paramName,
      type: factory.fromString(typeString),
      multiResult: multiResult,
      documentation: docs,
    );
  }

  /// Parameter name.
  final String name;

  /// Parameter type.
  final AbiType type;

  /// Whether this is a multi_result output (variable count, can be 0).
  final bool multiResult;

  /// Optional documentation.
  final String? documentation;

  /// Validates if value is compatible with parameter type.
  ///
  /// #### Parameters
  /// - `value` - Value to validate
  ///
  /// #### Returns
  /// `bool` - true if value matches parameter type
  bool isValidValue(dynamic value) => type.isValidValue(value);

  /// Converts to map.
  ///
  /// #### Returns
  /// `Map<String, dynamic>` - JSON-like map representation
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> result = <String, dynamic>{
      'name': name,
      'type': type.name,
    };

    if (multiResult) {
      result['multi_result'] = true;
    }

    if (documentation != null) {
      result['documentation'] = documentation;
    }

    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AbiParameter &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          type.name == other.type.name &&
          multiResult == other.multiResult &&
          documentation == other.documentation;

  @override
  int get hashCode => Object.hash(name, type.name, multiResult, documentation);

  @override
  String toString() {
    if (documentation != null) {
      return 'AbiParameter{$name: ${type.name} ($documentation)}';
    }
    return 'AbiParameter{$name: ${type.name}}';
  }
}

/// Collection of input parameters for smart contract function.
@immutable
final class InputParameters extends Iterable<AbiParameter> {
  /// Creates input parameters.
  const InputParameters(this._items);

  @override
  Iterator<AbiParameter> get iterator => _items.iterator;

  /// Creates empty input parameters.
  const InputParameters.empty() : _items = const <AbiParameter>[];

  /// Creates from list of maps.
  ///
  /// #### Parameters
  /// - `parameterMaps` - List of JSON-like maps
  /// - `typeFactory` - Optional AbiTypeFactory for custom type resolution
  ///
  /// #### Returns
  /// `InputParameters` - Collection instance
  factory InputParameters.fromMaps(
    List<Map<String, dynamic>> parameterMaps, {
    AbiTypeFactory? typeFactory,
  }) {
    final List<AbiParameter> parameters = parameterMaps
        .map(
          (Map<String, dynamic> map) =>
              AbiParameter.fromMap(map, typeFactory: typeFactory),
        )
        .toList(growable: false);
    return InputParameters(parameters);
  }

  /// Internal list of parameters.
  final List<AbiParameter> _items;

  /// Gets parameter by name, returns null if not found.
  ///
  /// #### Parameters
  /// - `name` - Parameter name to find
  ///
  /// #### Returns
  /// `AbiParameter?` - Parameter or null if not found
  AbiParameter? getByName(String name) {
    try {
      return _items.firstWhere((AbiParameter param) => param.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Gets parameter at index.
  AbiParameter operator [](int index) => _items[index];

  /// Validates if values match these parameters.
  ///
  /// #### Parameters
  /// - `values` - Values to validate (count and types)
  ///
  /// #### Returns
  /// `bool` - true if count matches and all values valid for types
  bool areValuesValid(List<dynamic> values) {
    if (values.length != _items.length) {
      return false;
    }

    for (int i = 0; i < _items.length; i++) {
      if (!_items[i].isValidValue(values[i])) {
        return false;
      }
    }

    return true;
  }

  /// Converts to list of maps.
  ///
  /// #### Returns
  /// `List<Map<String, dynamic>>` - List of JSON-like maps
  List<Map<String, dynamic>> toMaps() {
    return _items.map((AbiParameter param) => param.toMap()).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InputParameters &&
          runtimeType == other.runtimeType &&
          CollectionUtils.listEquals(_items, other._items);

  @override
  int get hashCode => Object.hashAll(_items);

  @override
  String toString() => 'InputParameters{${_items.length} parameters}';
}

/// Collection of output parameters for smart contract function.
@immutable
final class OutputParameters extends Iterable<AbiParameter> {
  /// Creates output parameters.
  const OutputParameters(this._items);

  /// Creates empty output parameters.
  const OutputParameters.empty() : _items = const <AbiParameter>[];

  @override
  Iterator<AbiParameter> get iterator => _items.iterator;

  /// Creates from list of maps.
  ///
  /// #### Parameters
  /// - `parameterMaps` - List of JSON-like maps
  /// - `typeFactory` - Optional AbiTypeFactory for custom type resolution
  ///
  /// #### Returns
  /// `OutputParameters` - Collection instance
  factory OutputParameters.fromMaps(
    List<Map<String, dynamic>> parameterMaps, {
    AbiTypeFactory? typeFactory,
  }) {
    final List<AbiParameter> parameters = parameterMaps
        .map(
          (Map<String, dynamic> map) =>
              AbiParameter.fromMap(map, typeFactory: typeFactory),
        )
        .toList(growable: false);
    return OutputParameters(parameters);
  }

  /// Internal list of parameters.
  final List<AbiParameter> _items;

  /// Whether any output has multi_result flag (variable count, can be 0).
  bool get hasMultiResult =>
      _items.any((AbiParameter param) => param.multiResult);

  /// Gets parameter by name, returns null if not found.
  ///
  /// #### Parameters
  /// - `name` - Parameter name to find
  ///
  /// #### Returns
  /// `AbiParameter?` - Parameter or null if not found
  AbiParameter? getByName(String name) {
    try {
      return _items.firstWhere((AbiParameter param) => param.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Gets parameter at index.
  AbiParameter operator [](int index) => _items[index];

  /// Converts to list of maps.
  ///
  /// #### Returns
  /// `List<Map<String, dynamic>>` - List of JSON-like maps
  List<Map<String, dynamic>> toMaps() {
    return _items.map((AbiParameter param) => param.toMap()).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutputParameters &&
          runtimeType == other.runtimeType &&
          CollectionUtils.listEquals(_items, other._items);

  @override
  int get hashCode => Object.hashAll(_items);

  @override
  String toString() => 'OutputParameters{${_items.length} parameters}';
}
