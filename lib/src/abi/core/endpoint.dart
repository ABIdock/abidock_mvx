/// Smart contract ABI endpoint definitions.
import 'package:meta/meta.dart';

import '../../utils/collection_utils.dart';
import '../../utils/helpers.dart';
import 'parameter.dart';
import 'types.dart';

/// Smart contract endpoint (function) in the ABI.
///
/// Represents a single endpoint/function with its metadata.
@immutable
final class AbiEndpoint {
  /// Creates endpoint with all properties.
  ///
  /// #### Parameters
  /// - `name` - Endpoint/function name (required)
  /// - `inputs` - Input parameters (default: empty)
  /// - `outputs` - Output parameters (default: empty)
  /// - `payableInTokens` - Accepted tokens (empty = not payable)
  /// - `isView` - Whether read-only (default: false)
  /// - `isOnlyOwner` - Whether owner-only (default: false)
  /// - `isOnlyAdmin` - Whether admin-only (default: false)
  /// - `title` - Human-readable title (optional)
  /// - `labels` - Labels for contract variants (optional)
  /// - `allowMultipleVarArgs` - Whether multiple variadic args allowed (default: false)
  /// - `documentation` - Optional docs
  /// - `internalMethodName` - Method name inside the contract source (optional)
  const AbiEndpoint({
    required this.name,
    this.inputs = const InputParameters.empty(),
    this.outputs = const OutputParameters.empty(),
    this.payableInTokens = const <String>[],
    this.isView = false,
    this.isOnlyOwner = false,
    this.isOnlyAdmin = false,
    this.title,
    this.labels = const <String>[],
    this.allowMultipleVarArgs = false,
    this.documentation,
    this.mutability,
    this.internalMethodName,
  });

  /// Creates endpoint from JSON-like map.
  ///
  /// #### Parameters
  /// - `data` - Map with 'name', 'inputs', 'outputs', 'mutability', etc.
  ///
  /// #### Throws
  /// - `ArgumentError` - If name is empty
  factory AbiEndpoint.fromMap(
    Map<String, dynamic> data, {
    AbiTypeFactory? typeFactory,
  }) {
    final String name = optionalAs<String>(data['name'], 'name') ?? '';
    if (name.isEmpty) {
      throw ArgumentError('Endpoint name cannot be empty');
    }

    final List<dynamic> inputsList =
        optionalAs<List<dynamic>>(data['inputs'], 'inputs') ?? <dynamic>[];
    final InputParameters inputs = InputParameters.fromMaps(
      inputsList.cast<Map<String, dynamic>>(),
      typeFactory: typeFactory,
    );

    final List<dynamic> outputsList =
        optionalAs<List<dynamic>>(data['outputs'], 'outputs') ?? <dynamic>[];
    final OutputParameters outputs = OutputParameters.fromMaps(
      outputsList.cast<Map<String, dynamic>>(),
      typeFactory: typeFactory,
    );

    final List<dynamic>? payableInTokensList = optionalAs<List<dynamic>>(
      data['payableInTokens'],
      'payableInTokens',
    );
    List<String> payableInTokens =
        payableInTokensList?.map((dynamic e) => e.toString()).toList() ??
        <String>[];

    final bool? payable = optionalAs<bool>(data['payable'], 'payable');
    if (payable == true && payableInTokens.isEmpty) {
      payableInTokens = <String>['EGLD'];
    }

    final String mutability =
        optionalAs<String>(data['mutability'], 'mutability') ?? '';
    final bool isView = mutability == 'readonly' || mutability == 'pure';

    final bool isOnlyOwner =
        optionalAs<bool>(data['onlyOwner'], 'onlyOwner') ?? false;
    final bool isOnlyAdmin =
        optionalAs<bool>(data['onlyAdmin'], 'onlyAdmin') ?? false;

    final String? title = optionalAs<String>(data['title'], 'title');

    final String? internalMethodName = optionalAs<String>(
      data['rustMethodName'],
      'rustMethodName',
    );

    final List<dynamic>? labelsList = optionalAs<List<dynamic>>(
      data['labels'],
      'labels',
    );
    final List<String> labels =
        labelsList?.map((dynamic e) => e.toString()).toList() ?? <String>[];

    final bool allowMultipleVarArgs =
        optionalAs<bool>(
          data['allowMultipleVarArgs'],
          'allowMultipleVarArgs',
        ) ??
        false;

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

    return AbiEndpoint(
      name: name,
      inputs: inputs,
      outputs: outputs,
      payableInTokens: payableInTokens,
      isView: isView,
      isOnlyOwner: isOnlyOwner,
      isOnlyAdmin: isOnlyAdmin,
      title: title,
      labels: labels,
      allowMultipleVarArgs: allowMultipleVarArgs,
      documentation: docs,
      mutability: mutability.isEmpty ? null : mutability,
      internalMethodName: internalMethodName,
    );
  }

  /// Creates view-only endpoint.
  ///
  /// #### Parameters
  /// - `name` - Endpoint name (required)
  /// - `inputs` - Input parameters (optional)
  /// - `outputs` - Output parameters (optional)
  /// - `documentation` - Optional docs
  factory AbiEndpoint.view({
    required String name,
    InputParameters inputs = const InputParameters.empty(),
    OutputParameters outputs = const OutputParameters.empty(),
    String? documentation,
  }) {
    return AbiEndpoint(
      name: name,
      inputs: inputs,
      outputs: outputs,
      isView: true,
      payableInTokens: const <String>[],
      isOnlyOwner: false,
      documentation: documentation,
    );
  }

  /// Creates payable endpoint.
  ///
  /// #### Parameters
  /// - `name` - Endpoint name (required)
  /// - `inputs` - Input parameters (optional)
  /// - `outputs` - Output parameters (optional)
  /// - `payableInTokens` - Accepted tokens (default: ['EGLD'])
  /// - `isOnlyOwner` - Owner-only restriction (default: false)
  /// - `documentation` - Optional docs
  factory AbiEndpoint.payable({
    required String name,
    InputParameters inputs = const InputParameters.empty(),
    OutputParameters outputs = const OutputParameters.empty(),
    List<String> payableInTokens = const <String>['EGLD'],
    bool isOnlyOwner = false,
    String? documentation,
  }) {
    return AbiEndpoint(
      name: name,
      inputs: inputs,
      outputs: outputs,
      payableInTokens: payableInTokens,
      isView: false,
      isOnlyOwner: isOnlyOwner,
      documentation: documentation,
    );
  }

  /// Endpoint/function name.
  final String name;

  /// Input parameters.
  final InputParameters inputs;

  /// Output parameters.
  final OutputParameters outputs;

  /// Tokens accepted (empty = not payable, ['EGLD'] = EGLD only, ['*'] = any).
  final List<String> payableInTokens;

  /// Whether this is a view function (read-only).
  final bool isView;

  /// Whether only contract owner can call this.
  final bool isOnlyOwner;

  /// Whether only admin addresses can call this.
  final bool isOnlyAdmin;

  /// Human-readable title for the endpoint.
  final String? title;

  /// Labels for contract variant generation.
  ///
  /// Declared in the ABI to drive build-time splitting of one contract source
  /// into several deployable variants.
  final List<String> labels;

  /// Whether this endpoint allows multiple variadic arguments.
  ///
  /// Declared in the ABI as a validation hint for the endpoint's argument list.
  final bool allowMultipleVarArgs;

  /// Documentation.
  final String? documentation;

  /// Raw mutability string from ABI ('mutable', 'readonly', or 'pure').
  ///
  /// Distinguishes `pure` (no state reads) from `readonly` (may read state).
  /// Null when endpoint was not constructed from ABI JSON.
  final String? mutability;

  /// Method name this endpoint carries inside the contract's own source.
  ///
  /// The chain dispatches on [name], but a contract author may spell the
  /// implementing method differently in the contract source. The ABI records
  /// that internal spelling only when the two differ, so this is null whenever
  /// the endpoint's internal method name is identical to [name] or the ABI
  /// omits it.
  final String? internalMethodName;

  /// Whether endpoint is declared as pure (no state reads).
  bool get isPure => mutability == 'pure';

  /// Whether endpoint is declared as readonly (may read state, no writes).
  bool get isReadonly => mutability == 'readonly';

  /// Whether this endpoint is payable.
  bool get isPayable => payableInTokens.isNotEmpty;

  /// Whether accepts EGLD payments.
  bool get acceptsEgld => isPayableByToken('EGLD');

  /// Whether can be queried.
  bool get canQuery => isView;

  /// Whether modifies contract state.
  bool get modifiesState => !isView;

  /// Total number of input parameters.
  int get inputCount => inputs.length;

  /// Total number of output parameters.
  int get outputCount => outputs.length;

  /// Checks if endpoint accepts a specific token.
  ///
  /// #### Parameters
  /// - `tokenIdentifier` - Token ID to check (e.g., 'EGLD', 'TOKEN-abc123')
  ///
  /// #### Returns
  /// `bool` - True if token is accepted
  bool isPayableByToken(String tokenIdentifier) {
    if (payableInTokens.isEmpty) {
      return false;
    }

    if (payableInTokens.contains(tokenIdentifier)) {
      return true;
    }

    final String exclusion = '!$tokenIdentifier';
    if (payableInTokens.contains(exclusion)) {
      return false;
    }

    if (payableInTokens.contains('*')) {
      return true;
    }

    return false;
  }

  /// Validates if input values are compatible with this endpoint.
  ///
  /// #### Parameters
  /// - `values` - List of values to validate
  ///
  /// #### Returns
  /// `bool` - True if values are valid for this endpoint
  bool areInputsValid(List<dynamic> values) {
    return inputs.areValuesValid(values);
  }

  /// Converts endpoint to map representation.
  ///
  /// #### Returns
  /// `Map<String, dynamic>` - Map with 'name', 'inputs', 'outputs', 'mutability', etc.
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> result = <String, dynamic>{
      'name': name,
      'inputs': inputs.toMaps(),
      'outputs': outputs.toMaps(),
    };

    if (internalMethodName != null) {
      result['rustMethodName'] = internalMethodName;
    }

    if (isPayable) {
      result['payableInTokens'] = payableInTokens;
    }

    if (isView) {
      result['mutability'] = 'readonly';
    } else {
      result['mutability'] = 'mutable';
    }

    if (isOnlyOwner) {
      result['onlyOwner'] = true;
    }

    if (isOnlyAdmin) {
      result['onlyAdmin'] = true;
    }

    if (title != null && title!.isNotEmpty) {
      result['title'] = title;
    }

    if (labels.isNotEmpty) {
      result['labels'] = labels;
    }

    if (allowMultipleVarArgs) {
      result['allowMultipleVarArgs'] = true;
    }

    if (documentation != null) {
      result['documentation'] = documentation;
    }

    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AbiEndpoint &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          inputs == other.inputs &&
          outputs == other.outputs &&
          CollectionUtils.listEquals(payableInTokens, other.payableInTokens) &&
          isView == other.isView &&
          isOnlyOwner == other.isOnlyOwner &&
          isOnlyAdmin == other.isOnlyAdmin &&
          title == other.title &&
          CollectionUtils.listEquals(labels, other.labels) &&
          allowMultipleVarArgs == other.allowMultipleVarArgs &&
          documentation == other.documentation &&
          internalMethodName == other.internalMethodName;

  @override
  int get hashCode => Object.hash(
    name,
    inputs,
    outputs,
    Object.hashAll(payableInTokens),
    isView,
    isOnlyOwner,
    isOnlyAdmin,
    title,
    Object.hashAll(labels),
    allowMultipleVarArgs,
    documentation,
    internalMethodName,
  );

  @override
  String toString() {
    final List<String> modifiers = <String>[];
    if (isView) modifiers.add('view');
    if (isPayable) modifiers.add('payable');
    if (isOnlyOwner) modifiers.add('onlyOwner');
    if (isOnlyAdmin) modifiers.add('onlyAdmin');
    if (allowMultipleVarArgs) modifiers.add('allowMultipleVarArgs');

    final String modifierString = modifiers.isNotEmpty
        ? ' [${modifiers.join(', ')}]'
        : '';

    return 'AbiEndpoint{$name($inputCount inputs, $outputCount outputs)$modifierString}';
  }
}

/// Collection of smart contract endpoints.
@immutable
final class AbiEndpoints extends Iterable<AbiEndpoint> {
  /// Creates collection from list of endpoints.
  const AbiEndpoints(this._items);

  /// Creates empty collection.
  const AbiEndpoints.empty() : _items = const <AbiEndpoint>[];

  /// Creates endpoints from list of maps.
  factory AbiEndpoints.fromMaps(
    List<Map<String, dynamic>> endpointMaps, {
    AbiTypeFactory? typeFactory,
  }) {
    final List<AbiEndpoint> endpoints = endpointMaps
        .map(
          (Map<String, dynamic> map) =>
              AbiEndpoint.fromMap(map, typeFactory: typeFactory),
        )
        .toList(growable: false);
    return AbiEndpoints(endpoints);
  }

  /// Internal list of endpoints.
  final List<AbiEndpoint> _items;

  @override
  Iterator<AbiEndpoint> get iterator => _items.iterator;

  /// All view endpoints.
  List<AbiEndpoint> get viewEndpoints =>
      _items.where((AbiEndpoint endpoint) => endpoint.isView).toList();

  /// All mutable endpoints.
  List<AbiEndpoint> get mutableEndpoints =>
      _items.where((AbiEndpoint endpoint) => !endpoint.isView).toList();

  /// All payable endpoints.
  List<AbiEndpoint> get payableEndpoints =>
      _items.where((AbiEndpoint endpoint) => endpoint.isPayable).toList();

  /// Gets endpoint by name.
  AbiEndpoint? getByName(String name) {
    try {
      return _items.firstWhere((AbiEndpoint endpoint) => endpoint.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Gets endpoint by index.
  AbiEndpoint operator [](int index) => _items[index];

  /// Checks if endpoint exists by name.
  bool hasEndpoint(String name) => getByName(name) != null;

  /// Converts endpoints to list of maps.
  List<Map<String, dynamic>> toMaps() {
    return _items.map((AbiEndpoint endpoint) => endpoint.toMap()).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AbiEndpoints &&
          runtimeType == other.runtimeType &&
          CollectionUtils.listEquals(_items, other._items);

  @override
  int get hashCode => Object.hashAll(_items);

  @override
  String toString() => 'AbiEndpoints{${_items.length} endpoints}';
}
