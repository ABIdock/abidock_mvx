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
      final List<String> result = <String>[];
      for (final TypedValue value in values) {
        try {
          _expandAndEncode(value, result);
        } catch (e, stackTrace) {
          if (e is ArgumentEncodingException) {
            rethrow;
          }
          throw ArgumentEncodingException(
            'Failed to encode typed value: ${value.type}',
            argumentValue: value,
            expectedType: value.type.toString(),
            cause: e,
            stackTrace: stackTrace,
          );
        }
      }
      return result;
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

  /// Expands multi-value types and encodes each part as a separate hex argument.
  ///
  /// #### Parameters
  /// - `value` - TypedValue to expand and encode
  /// - `result` - Accumulator list for hex-encoded arguments
  void _expandAndEncode(TypedValue value, List<String> result) {
    if (value is VariadicValue) {
      if (value.isCounted) {
        final Uint8List countBuffer = serializer.codec.encodeTopLevel(
          U32Value(value.length),
        );
        result.add(_bytesToHex(countBuffer));
      }
      for (final TypedValue item in value.items) {
        _expandAndEncode(item, result);
      }
    } else if (value is MultiValueValue) {
      for (final TypedValue inner in value.values) {
        _expandAndEncode(inner, result);
      }
    } else if (value is CompositeValue) {
      for (final TypedValue field in value.fields) {
        _expandAndEncode(field, result);
      }
    } else if (value is OptionalValue) {
      if (value.isProvided) {
        _expandAndEncode(value.value!, result);
      }
    } else {
      final Uint8List buffer = serializer.codec.encodeTopLevel(value);
      result.add(_bytesToHex(buffer));
    }
  }

  /// Converts bytes to hex.
  String _bytesToHex(Uint8List bytes) => HexUtils.bytesToHex(bytes);

  /// Converts native values to typed values using endpoint definition.
  ///
  /// When the last input is variadic, the trailing arguments are collected into
  /// a single [VariadicValue], whether the caller flattened them into one
  /// argument per item or handed the whole run over already grouped.
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
      final VariadicValue? variadic = _buildVariadicValue(
        params.last,
        arguments.sublist(nonVariadicCount),
        nonVariadicCount,
        endpoint.name,
      );
      if (variadic != null) {
        typedValues.add(variadic);
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
    final VariadicValue? variadic = _buildVariadicValue(
      lastParam,
      arguments.sublist(nonVariadicCount),
      nonVariadicCount,
      'variadic',
    );
    if (variadic != null) {
      typedValues.add(variadic);
    }

    return encodeTypedValues(typedValues);
  }

  /// Groups the trailing arguments of an endpoint into a single variadic value.
  ///
  /// The trailing arguments may arrive either already grouped as one
  /// [VariadicValue] or flattened into one argument per item; both forms yield
  /// the same wire encoding. A `counted-variadic<T>` parameter always produces
  /// a counted value so that the leading `u32` item count reaches the wire,
  /// even when no items were supplied.
  ///
  /// #### Parameters
  /// - `param` - Trailing parameter, whose type must be a `VariadicType`
  /// - `trailing` - Arguments occupying the variadic parameter
  /// - `firstIndex` - Position of the first trailing argument in the call
  /// - `endpointName` - Endpoint name used in error reporting
  ///
  /// #### Returns
  /// `VariadicValue?` - Grouped value, or null when an uncounted variadic
  /// received no arguments
  ///
  /// #### Throws
  /// - `ArgumentEncodingException` - If an item cannot be converted
  VariadicValue? _buildVariadicValue(
    AbiParameter param,
    List<dynamic> trailing,
    int firstIndex,
    String endpointName,
  ) {
    final VariadicType variadicType = param.type as VariadicType;

    if (trailing.length == 1 && trailing.first is VariadicValue) {
      final VariadicValue provided = trailing.first as VariadicValue;
      if (provided.isCounted == variadicType.isCounted) {
        return provided;
      }
      return VariadicValue(
        provided.items,
        itemType: provided.itemType,
        isCounted: variadicType.isCounted,
      );
    }

    if (trailing.isEmpty && !variadicType.isCounted) {
      return null;
    }

    final AbiType itemType = variadicType.itemType;
    final List<TypedValue> items = <TypedValue>[];
    for (int i = 0; i < trailing.length; i++) {
      final AbiParameter itemParam = AbiParameter(
        name: '${param.name}_${firstIndex + i}',
        type: itemType,
      );
      items.add(
        _convertToTypedValue(
          itemParam,
          trailing[i],
          firstIndex + i,
          endpointName,
        ),
      );
    }

    return VariadicValue(
      items,
      itemType: itemType,
      isCounted: variadicType.isCounted,
    );
  }

  /// Converts native value to typed value.
  TypedValue _convertToTypedValue(
    AbiParameter param,
    dynamic value,
    int index,
    String endpointName,
  ) {
    final AbiType paramType = param.type;
    if (paramType is MultiValueType && value is! TypedValue) {
      return _convertToMultiValue(param, paramType, value, index, endpointName);
    }

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

  /// Converts a native value to a `multi<...>` group of top-level slots.
  ///
  /// Each member of a `multi<A,B>` occupies its own argument on the wire, so
  /// the native form is a list holding exactly one value per member.
  ///
  /// #### Parameters
  /// - `param` - Parameter declaring the multi-value group
  /// - `type` - Declared multi-value type
  /// - `value` - Native list holding one value per member
  /// - `index` - Argument position used in error reporting
  /// - `endpointName` - Endpoint name used in error reporting
  ///
  /// #### Returns
  /// `MultiValueValue` - Group holding one typed value per member
  ///
  /// #### Throws
  /// - `ArgumentEncodingException` - If the value is not a list of the declared
  ///   arity, or a member cannot be converted
  MultiValueValue _convertToMultiValue(
    AbiParameter param,
    MultiValueType type,
    dynamic value,
    int index,
    String endpointName,
  ) {
    if (value is! List || value.length != type.arity) {
      throw ArgumentEncodingException(
        'Expected a list of ${type.arity} values for ${type.name}',
        endpointName: endpointName,
        argumentIndex: index,
        argumentValue: value,
        expectedType: type.toString(),
      );
    }

    final List<TypedValue> members = <TypedValue>[];
    for (int i = 0; i < type.arity; i++) {
      final AbiParameter memberParam = AbiParameter(
        name: '${param.name}_$i',
        type: type.types[i],
      );
      members.add(
        _convertToTypedValue(memberParam, value[i], index, endpointName),
      );
    }

    return MultiValueValue(type, members);
  }

  /// Checks if parameter accepts an open-ended run of trailing arguments.
  ///
  /// Only `variadic<T>` and `counted-variadic<T>` are open-ended. A
  /// `multi<A,B>` declares a fixed number of top-level slots and is therefore
  /// an ordinary parameter that happens to occupy more than one slot.
  bool _isVariadicParameter(AbiParameter param) => param.type is VariadicType;

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
