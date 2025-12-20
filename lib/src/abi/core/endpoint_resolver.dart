/// Endpoint resolution and validation from ABI definitions.
import '../../infrastructure/logging/logger.dart';
import '../abi.dart';

/// Resolves and validates endpoints from ABI.
///
/// Fast O(1) endpoint lookup with validation and type checking.
class EndpointResolver {
  /// Creates resolver with ABI definition.
  ///
  /// #### Parameters
  /// - `abi` - Smart contract ABI (required)
  /// - `logger` - Optional logger for debugging
  EndpointResolver(this.abi, {this.logger});

  /// ABI definition containing all endpoints.
  final SmartContractAbi abi;

  /// Optional logger.
  final Logger? logger;

  /// Cache for endpoint lookups.
  final Map<String, AbiEndpoint> _endpointCache = <String, AbiEndpoint>{};

  bool _cacheInitialized = false;

  /// Initializes endpoint cache for O(1) lookup.
  void _initializeCacheIfNeeded() {
    if (_cacheInitialized) return;

    for (final AbiEndpoint endpoint in abi.endpoints) {
      _endpointCache[endpoint.name] = endpoint;
    }

    _cacheInitialized = true;
  }

  /// Gets endpoint by name.
  ///
  /// #### Parameters
  /// - `name` - Endpoint name to find
  ///
  /// #### Returns
  /// `AbiEndpoint` - Endpoint instance
  ///
  /// #### Throws
  /// - `EndpointNotFoundException` - If endpoint not in ABI (with suggestions)
  AbiEndpoint getEndpoint(String name) {
    _initializeCacheIfNeeded();

    final AbiEndpoint? endpoint = _endpointCache[name];
    if (endpoint == null) {
      logger?.warning(
        'Endpoint not found in ABI',
        context: <String, dynamic>{
          'endpoint': name,
          'availableEndpoints': _endpointCache.keys.toList(),
        },
      );
      throw EndpointNotFoundException.withSuggestions(
        endpointName: name,
        abi: abi,
      );
    }

    return endpoint;
  }

  /// Checks if endpoint exists in ABI.
  ///
  /// #### Parameters
  /// - `name` - Endpoint name to check
  ///
  /// #### Returns
  /// `bool` - True if endpoint exists
  bool hasEndpoint(String name) {
    _initializeCacheIfNeeded();
    return _endpointCache.containsKey(name);
  }

  /// Gets all endpoints defined in ABI.
  ///
  /// #### Returns
  /// `List<AbiEndpoint>` - Unmodifiable list of all endpoints
  List<AbiEndpoint> getAllEndpoints() {
    return List<AbiEndpoint>.unmodifiable(abi.endpoints.toList());
  }

  /// Gets endpoints by type (view/mutable/payable).
  ///
  /// #### Parameters
  /// - `type` - EndpointType filter
  ///
  /// #### Returns
  /// `List<AbiEndpoint>` - List of matching endpoints
  List<AbiEndpoint> getEndpointsByType(EndpointType type) {
    switch (type) {
      case EndpointType.view:
        return abi.endpoints.where((AbiEndpoint e) => e.isView).toList();
      case EndpointType.mutable:
        return abi.endpoints.where((AbiEndpoint e) => !e.isView).toList();
      case EndpointType.payable:
        return abi.endpoints.where((AbiEndpoint e) => e.isPayable).toList();
      case EndpointType.readonly:
        return abi.endpoints.where((AbiEndpoint e) => e.isView).toList();
      case EndpointType.pure:
        return abi.endpoints.where((AbiEndpoint e) => e.isView).toList();
    }
  }

  /// Gets input parameter types for endpoint.
  ///
  /// #### Parameters
  /// - `endpointName` - Endpoint to query
  ///
  /// #### Returns
  /// `List<AbiParameter>` - List of input parameters
  ///
  /// #### Throws
  /// - `EndpointNotFoundException` - If endpoint not found
  List<AbiParameter> getInputTypes(String endpointName) {
    final AbiEndpoint endpoint = getEndpoint(endpointName);
    return endpoint.inputs.toList();
  }

  /// Gets output parameter types for endpoint.
  ///
  /// #### Parameters
  /// - `endpointName` - Endpoint to query
  ///
  /// #### Returns
  /// `List<AbiParameter>` - List of output parameters
  ///
  /// #### Throws
  /// - `EndpointNotFoundException` - If endpoint not found
  List<AbiParameter> getOutputTypes(String endpointName) {
    final AbiEndpoint endpoint = getEndpoint(endpointName);
    return endpoint.outputs.toList();
  }

  /// Validates argument count matches endpoint definition.
  ///
  /// #### Parameters
  /// - `endpointName` - Endpoint to validate
  /// - `argCount` - Number of arguments provided
  ///
  /// #### Throws
  /// - `EndpointNotFoundException` - If endpoint not found
  /// - `ArgumentValidationException` - If count mismatch (handles variadic)
  void validateArgumentCount(String endpointName, int argCount) {
    final AbiEndpoint endpoint = getEndpoint(endpointName);
    final List<AbiParameter> params = endpoint.inputs.toList();

    int variadicCount = 0;
    int regularCount = 0;

    for (final AbiParameter param in params) {
      if (_isVariadicParameter(param)) {
        variadicCount++;
      } else {
        regularCount++;
      }
    }

    if (variadicCount > 0) {
      if (argCount < regularCount) {
        logger?.warning(
          'Argument count mismatch for variadic endpoint',
          context: <String, dynamic>{
            'endpoint': endpointName,
            'expected': 'at least $regularCount',
            'received': argCount,
            'isVariadic': true,
          },
        );
        throw ArgumentValidationException.countMismatch(
          endpointName: endpointName,
          expected: regularCount,
          actual: argCount,
        );
      }
    } else {
      if (argCount != params.length) {
        logger?.warning(
          'Argument count mismatch',
          context: <String, dynamic>{
            'endpoint': endpointName,
            'expected': params.length,
            'received': argCount,
          },
        );
        throw ArgumentValidationException.countMismatch(
          endpointName: endpointName,
          expected: params.length,
          actual: argCount,
        );
      }
    }

    logger?.debug(
      'Argument count validated',
      context: <String, dynamic>{'endpoint': endpointName, 'count': argCount},
    );
  }

  /// Checks if parameter is variadic.
  bool _isVariadicParameter(AbiParameter param) {
    final String typeName = param.type.name.toLowerCase();
    return typeName.startsWith('variadic<') || typeName.startsWith('multi<');
  }

  /// Validates argument types match endpoint definition.
  ///
  /// #### Parameters
  /// - `endpointName` - Endpoint to validate
  /// - `arguments` - Typed values to check
  ///
  /// #### Throws
  /// - `EndpointNotFoundException` if endpoint not found
  /// - `ArgumentValidationException` if type mismatches (with detailed errors)
  void validateArgumentTypes(String endpointName, List<TypedValue> arguments) {
    final AbiEndpoint endpoint = getEndpoint(endpointName);
    final List<AbiParameter> inputParams = endpoint.inputs.toList();

    validateArgumentCount(endpointName, arguments.length);

    final bool hasVariadic =
        inputParams.isNotEmpty && _isVariadicParameter(inputParams.last);

    if (hasVariadic) {
      final int nonVariadicCount = inputParams.length - 1;
      final List<String> errors = <String>[];

      for (int i = 0; i < nonVariadicCount; i++) {
        final AbiParameter param = inputParams[i];
        final TypedValue arg = arguments[i];

        if (!_isTypeCompatible(param, arg)) {
          errors.add('Argument $i: Expected ${param.type}, got ${arg.type}');
        }
      }

      if (arguments.length > nonVariadicCount) {
        final AbiParameter variadicParam = inputParams.last;
        final AbiType itemType = (variadicParam.type as VariadicType).itemType;
        final AbiParameter itemParam = AbiParameter(
          name: variadicParam.name,
          type: itemType,
        );

        for (int i = nonVariadicCount; i < arguments.length; i++) {
          final TypedValue arg = arguments[i];
          if (!_isTypeCompatible(itemParam, arg)) {
            errors.add(
              'Argument $i (variadic): Expected ${variadicParam.type}, got ${arg.type}',
            );
          }
        }
      }

      if (errors.isNotEmpty) {
        logger?.warning(
          'Argument type validation failed',
          context: <String, dynamic>{
            'endpoint': endpointName,
            'errors': errors,
            'isVariadic': true,
          },
        );
        throw ArgumentValidationException.typeErrors(
          endpointName: endpointName,
          expectedCount: inputParams.length,
          actualCount: arguments.length,
          errors: errors,
        );
      }
    } else {
      final List<String> errors = <String>[];

      for (int i = 0; i < inputParams.length; i++) {
        final AbiParameter param = inputParams[i];
        final TypedValue arg = arguments[i];

        if (!_isTypeCompatible(param, arg)) {
          errors.add('Argument $i: Expected ${param.type}, got ${arg.type}');
        }
      }

      if (errors.isNotEmpty) {
        logger?.warning(
          'Argument type validation failed',
          context: <String, dynamic>{
            'endpoint': endpointName,
            'errors': errors,
          },
        );
        throw ArgumentValidationException.typeErrors(
          endpointName: endpointName,
          expectedCount: inputParams.length,
          actualCount: arguments.length,
          errors: errors,
        );
      }
    }

    logger?.debug(
      'Argument types validated',
      context: <String, dynamic>{
        'endpoint': endpointName,
        'argumentCount': arguments.length,
      },
    );
  }

  /// Checks if typed value is compatible with parameter definition.
  bool _isTypeCompatible(AbiParameter param, TypedValue value) {
    final String paramType = param.type.toString();
    final String valueType = value.type.toString();

    if (paramType == valueType) {
      return true;
    }

    const Map<String, List<String>> unsignedWidening = <String, List<String>>{
      'BigUint': <String>['U8', 'U16', 'U32', 'U64'],
      'U64': <String>['U8', 'U16', 'U32'],
      'U32': <String>['U8', 'U16'],
      'U16': <String>['U8'],
    };

    const Map<String, List<String>> signedWidening = <String, List<String>>{
      'BigInt': <String>['I8', 'I16', 'I32', 'I64'],
      'I64': <String>['I8', 'I16', 'I32'],
      'I32': <String>['I8', 'I16'],
      'I16': <String>['I8'],
    };

    if (unsignedWidening[paramType]?.contains(valueType) ?? false) {
      return true;
    }

    if (signedWidening[paramType]?.contains(valueType) ?? false) {
      return true;
    }

    if (paramType == 'Address' && valueType == 'bytes[32]') {
      return true;
    }
    if (paramType == 'bytes[32]' && valueType == 'Address') {
      return true;
    }

    return false;
  }

  /// Validates response data count against endpoint definition.
  ///
  /// #### Parameters
  /// - `endpointName` - Endpoint to validate
  /// - `returnDataCount` - Number of return values received
  ///
  /// #### Throws
  /// - `EndpointNotFoundException` - If endpoint not found
  /// - `ResponseValidationException` - If count mismatch (skipped for multi_result)
  void validateReturnCount(String endpointName, int returnDataCount) {
    final AbiEndpoint endpoint = getEndpoint(endpointName);

    if (endpoint.outputs.hasMultiResult) {
      return;
    }

    final int expectedCount = endpoint.outputCount;

    if (returnDataCount != expectedCount) {
      throw ResponseValidationException.countMismatch(
        endpointName: endpointName,
        expected: expectedCount,
        actual: returnDataCount,
      );
    }
  }

  /// Gets number of input parameters.
  int getInputCount(String endpointName) {
    final AbiEndpoint endpoint = getEndpoint(endpointName);
    return endpoint.inputCount;
  }

  /// Gets number of output parameters.
  int getOutputCount(String endpointName) {
    final AbiEndpoint endpoint = getEndpoint(endpointName);
    return endpoint.outputCount;
  }

  /// Checks if endpoint is a view function.
  bool isViewFunction(String endpointName) {
    final AbiEndpoint endpoint = getEndpoint(endpointName);
    return endpoint.isView;
  }

  /// Checks if endpoint is payable.
  bool isPayableFunction(String endpointName) {
    final AbiEndpoint endpoint = getEndpoint(endpointName);
    return endpoint.isPayable;
  }

  /// Checks if endpoint requires owner privileges.
  bool isOwnerOnly(String endpointName) {
    final AbiEndpoint endpoint = getEndpoint(endpointName);
    return endpoint.isOnlyOwner;
  }

  /// Gets human-readable summary of endpoint.
  ///
  /// #### Parameters
  /// - `endpointName` - Endpoint to summarize
  ///
  /// #### Returns
  /// `String` - Multi-line string with endpoint details
  ///
  /// #### Throws
  /// - `EndpointNotFoundException` - If endpoint not found
  String getEndpointSummary(String endpointName) {
    final AbiEndpoint endpoint = getEndpoint(endpointName);
    final StringBuffer buffer = StringBuffer();

    buffer.writeln('Endpoint: ${endpoint.name}');

    final List<String> types = <String>[];
    if (endpoint.isView) types.add('view');
    if (endpoint.isPayable) types.add('payable');
    if (endpoint.isOnlyOwner) types.add('owner-only');
    if (types.isEmpty) types.add('mutable');
    buffer.writeln('Type: ${types.join(', ')}');

    buffer.write('Inputs: ${endpoint.inputCount}');
    if (endpoint.inputCount > 0) {
      buffer.write(' (');
      final String inputs = endpoint.inputs
          .map((AbiParameter p) => '${p.name}: ${p.type}')
          .join(', ');
      buffer.write(inputs);
      buffer.write(')');
    }
    buffer.writeln();

    buffer.write('Outputs: ${endpoint.outputCount}');
    if (endpoint.outputCount > 0) {
      buffer.write(' (');
      final String outputs = endpoint.outputs
          .map((AbiParameter p) => '${p.name}: ${p.type}')
          .join(', ');
      buffer.write(outputs);
      buffer.write(')');
    }

    if (endpoint.documentation != null) {
      buffer.writeln();
      buffer.write('Documentation: ${endpoint.documentation}');
    }

    return buffer.toString();
  }

  /// Clears endpoint cache.
  ///
  /// Call if ABI is modified after resolver creation.
  void clearCache() {
    _endpointCache.clear();
    _cacheInitialized = false;
  }
}

/// Types of smart contract endpoints.
///
/// Filter endpoints by their characteristics.
enum EndpointType {
  /// View/readonly functions that don't modify state.
  view,

  /// Readonly functions (synonym for view).
  readonly,

  /// Pure functions that don't read or modify state.
  pure,

  /// Mutable functions that can modify contract state.
  mutable,

  /// Payable functions that can receive EGLD or tokens.
  payable,
}
