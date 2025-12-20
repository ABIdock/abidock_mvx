/// Type-safe argument encoding for smart contract interactions.
import 'dart:typed_data';

import '../../infrastructure/logging/logger.dart';
import '../../utils/hex_utils.dart';
import '../abi.dart';

/// Encodes arguments for smart contract calls with type validation.
class ArgumentEncoder {
  /// Creates argument encoder with required serializer and resolver.
  ///
  /// #### Parameters
  /// - `serializer` - ArgSerializer for encoding
  /// - `nativeSerializer` - NativeSerializer (optional, uses default)
  /// - `resolver` - EndpointResolver for validation
  /// - `logger` - Optional logger
  ArgumentEncoder({
    required this.serializer,
    NativeSerializer? nativeSerializer,
    required this.resolver,
    this.logger,
  }) : nativeSerializer = nativeSerializer ?? NativeSerializer();

  /// Argument serializer for typed values.
  final ArgSerializer serializer;

  /// Native serializer for value conversion.
  final NativeSerializer nativeSerializer;

  /// Endpoint resolver for validation.
  final EndpointResolver resolver;

  /// Optional logger.
  final Logger? logger;

  /// Encodes arguments for endpoint with validation.
  ///
  /// #### Parameters
  /// - `endpoint` - ABI endpoint definition
  /// - `arguments` - Native Dart arguments to encode
  ///
  /// #### Throws
  /// - `ArgumentEncodingException` - Validation or encoding failure
  List<String> encodeForEndpoint({
    required AbiEndpoint endpoint,
    required List<dynamic> arguments,
  }) {
    logger?.debug(
      'Encoding arguments for endpoint',
      context: <String, dynamic>{
        'endpoint': endpoint.name,
        'argumentCount': arguments.length,
        'expectedInputs': endpoint.inputs.length,
      },
    );

    resolver.validateArgumentCount(endpoint.name, arguments.length);
    final List<TypedValue> typedValues = nativeToTyped(
      endpoint: endpoint,
      arguments: arguments,
    );
    resolver.validateArgumentTypes(endpoint.name, typedValues);
    final List<String> result = encodeTypedValues(typedValues);

    logger?.debug(
      'Successfully encoded arguments',
      context: <String, dynamic>{
        'endpoint': endpoint.name,
        'encodedCount': result.length,
      },
    );

    return result;
  }

  /// Encodes typed values directly.
  ///
  /// #### Parameters
  /// - `values` - TypedValue instances to encode
  ///
  /// #### Throws
  /// - `ArgumentEncodingException` - Encoding failure
  List<String> encodeTypedValues(List<TypedValue> values) {
    try {
      return values.map((TypedValue value) {
        try {
          final Uint8List buffer = serializer.codec.encodeTopLevel(value);
          return _bytesToHex(buffer);
        } catch (e, stackTrace) {
          throw ArgumentEncodingException(
            'Failed to encode typed value: ${value.type}',
            argumentValue: value,
            expectedType: value.type.toString(),
            cause: e,
            stackTrace: stackTrace,
          );
        }
      }).toList();
    } catch (e) {
      if (e is ArgumentEncodingException) {
        rethrow;
      }
      throw ArgumentEncodingException(
        'Failed to encode arguments: $e',
        cause: e,
      );
    }
  }

  /// Converts bytes to hex.
  String _bytesToHex(Uint8List bytes) => HexUtils.bytesToHex(bytes);

  /// Converts native values to typed values using endpoint definition.
  ///
  /// #### Parameters
  /// - `endpoint` - ABI endpoint definition
  /// - `arguments` - Native Dart values
  ///
  /// #### Throws
  /// - `ArgumentEncodingException` - Type conversion failure
  List<TypedValue> nativeToTyped({
    required AbiEndpoint endpoint,
    required List<dynamic> arguments,
  }) {
    final List<AbiParameter> params = endpoint.inputs.toList();
    final List<TypedValue> typedValues = <TypedValue>[];
    final bool hasVariadic =
        params.isNotEmpty && _isVariadicParameter(params.last);

    if (hasVariadic) {
      final int nonVariadicCount = params.length - 1;
      for (int i = 0; i < nonVariadicCount; i++) {
        final AbiParameter param = params[i];
        final arg = arguments[i];
        typedValues.add(_convertToTypedValue(param, arg, i, endpoint.name));
      }
      if (arguments.length > nonVariadicCount) {
        final AbiParameter variadicParam = params.last;
        final AbiType innerType = _extractVariadicInnerType(variadicParam);

        for (int i = nonVariadicCount; i < arguments.length; i++) {
          final arg = arguments[i];
          final AbiParameter innerParam = AbiParameter(
            name: '${variadicParam.name}_$i',
            type: innerType,
          );
          typedValues.add(
            _convertToTypedValue(innerParam, arg, i, endpoint.name),
          );
        }
      }
    } else {
      for (int i = 0; i < params.length; i++) {
        final AbiParameter param = params[i];
        final arg = arguments[i];
        typedValues.add(_convertToTypedValue(param, arg, i, endpoint.name));
      }
    }

    return typedValues;
  }

  /// Validates and encodes arguments (delegates to encodeForEndpoint).
  ///
  /// #### Parameters
  /// - `endpoint` - ABI endpoint definition
  /// - `arguments` - Native arguments
  List<String> validateAndEncode({
    required AbiEndpoint endpoint,
    required List<dynamic> arguments,
  }) {
    return encodeForEndpoint(endpoint: endpoint, arguments: arguments);
  }

  /// Encodes variadic arguments.
  ///
  /// #### Parameters
  /// - `parameterTypes` - Parameter type definitions (last must be variadic)
  /// - `arguments` - Native arguments
  ///
  /// #### Throws
  /// - `ArgumentEncodingException` - If last param not variadic or encoding fails
  List<String> encodeVariadicArgs({
    required List<AbiParameter> parameterTypes,
    required List<dynamic> arguments,
  }) {
    if (parameterTypes.isEmpty) {
      throw const ArgumentEncodingException(
        'No parameter types provided for variadic encoding',
      );
    }

    final AbiParameter lastParam = parameterTypes.last;
    if (!_isVariadicParameter(lastParam)) {
      throw ArgumentEncodingException(
        'Last parameter is not variadic: ${lastParam.type}',
      );
    }

    final List<TypedValue> typedValues = <TypedValue>[];
    final int nonVariadicCount = parameterTypes.length - 1;
    for (int i = 0; i < nonVariadicCount; i++) {
      final AbiParameter param = parameterTypes[i];
      final arg = arguments[i];
      typedValues.add(_convertToTypedValue(param, arg, i, 'variadic'));
    }
    final AbiParameter variadicParam = lastParam;
    final AbiType innerType = _extractVariadicInnerType(variadicParam);

    for (int i = nonVariadicCount; i < arguments.length; i++) {
      final arg = arguments[i];
      final AbiParameter innerParam = AbiParameter(
        name: '${variadicParam.name}_$i',
        type: innerType,
      );
      typedValues.add(_convertToTypedValue(innerParam, arg, i, 'variadic'));
    }

    return encodeTypedValues(typedValues);
  }

  /// Converts native value to typed value.
  TypedValue _convertToTypedValue(
    AbiParameter param,
    dynamic value,
    int index,
    String endpointName,
  ) {
    try {
      final EndpointParameterDefinition paramDef = EndpointParameterDefinition(
        param.name,
        null,
        param.type,
      );

      final EndpointDefinition tempEndpoint = EndpointDefinition(
        name: endpointName,
        input: <EndpointParameterDefinition>[paramDef],
        output: <EndpointParameterDefinition>[],
      );

      final List<TypedValue> result = NativeSerializer.nativeToTypedValues(
        <dynamic>[value],
        tempEndpoint,
      );
      return result.first;
    } catch (e, stackTrace) {
      throw ArgumentEncodingException(
        'Failed to convert argument $index to ${param.type}',
        endpointName: endpointName,
        argumentIndex: index,
        argumentValue: value,
        expectedType: param.type.toString(),
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Checks if parameter is variadic.
  bool _isVariadicParameter(AbiParameter param) {
    final String typeName = param.type.name.toLowerCase();
    return typeName.startsWith('variadic<') || typeName.startsWith('multi<');
  }

  /// Extracts inner type from variadic parameter.
  AbiType _extractVariadicInnerType(AbiParameter param) {
    if (param.type is VariadicType) {
      return (param.type as VariadicType).itemType;
    }
    final String typeName = param.type.name.toLowerCase();

    if (typeName.startsWith('variadic<') && typeName.endsWith('>')) {
      final String innerTypeName = param.type.name.substring(
        9,
        param.type.name.length - 1,
      );
      return AbiTypeFactory().fromString(innerTypeName);
    }

    if (typeName.startsWith('multi<') && typeName.endsWith('>')) {
      final String innerTypeName = param.type.name.substring(
        6,
        param.type.name.length - 1,
      );
      return AbiTypeFactory().fromString(innerTypeName);
    }

    throw ArgumentEncodingException(
      'Failed to extract inner type from variadic parameter: ${param.type}',
      expectedType: param.type.toString(),
    );
  }

  /// Encodes single argument.
  String encodeSingleArgument({
    required AbiParameter paramType,
    required dynamic value,
  }) {
    final TypedValue typedValue = _convertToTypedValue(
      paramType,
      value,
      0,
      'single',
    );
    final Uint8List buffer = serializer.codec.encodeTopLevel(typedValue);
    return _bytesToHex(buffer);
  }

  /// Encodes arguments with explicit types.
  ///
  /// #### Parameters
  /// - `paramTypes` - Parameter type definitions
  /// - `arguments` - Native arguments (must match count)
  ///
  /// #### Throws
  /// - `ArgumentEncodingException` - Count mismatch or encoding failure
  List<String> encodeWithTypes({
    required List<AbiParameter> paramTypes,
    required List<dynamic> arguments,
  }) {
    if (paramTypes.length != arguments.length) {
      throw ArgumentEncodingException(
        'Parameter count mismatch: expected ${paramTypes.length}, got ${arguments.length}',
      );
    }

    final List<TypedValue> typedValues = <TypedValue>[];
    for (int i = 0; i < paramTypes.length; i++) {
      final AbiParameter param = paramTypes[i];
      final arg = arguments[i];
      typedValues.add(_convertToTypedValue(param, arg, i, 'typed'));
    }

    return encodeTypedValues(typedValues);
  }
}
