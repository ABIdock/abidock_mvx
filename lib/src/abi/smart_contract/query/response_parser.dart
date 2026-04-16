/// Type-safe smart contract response parsing with ABI integration.
/// Parses encoded query responses into typed values using ABI definitions.

import 'dart:convert';
import 'dart:typed_data';

import '../../../utils/hex_utils.dart';
import '../../abi.dart';

/// Parses smart contract responses with ABI-based type safety.
///
/// #### Example
/// ```dart
/// final parser = ResponseParser(
///   serializer: ArgSerializer(),
///   resolver: EndpointResolver(abi),
/// );
///
/// final results = parser.parseForEndpoint(
///   endpoint: endpoint,
///   returnData: response.returnDataParts,
/// );
/// ```
class ResponseParser {
  /// Creates a response parser with serializer and optional resolver.
  ///
  /// #### Parameters
  /// - `serializer` - Serializer for decoding typed values
  /// - `resolver` - Optional resolver for validation
  const ResponseParser({required this.serializer, this.resolver});

  /// The argument serializer for decoding typed values.
  final ArgSerializer serializer;

  /// Optional endpoint resolver for validation.
  final EndpointResolver? resolver;

  /// Parses response for specific endpoint with ABI validation.
  ///
  /// Main parsing method with endpoint validation.
  ///
  /// #### Parameters
  /// - `endpoint` - Endpoint definition with output types
  /// - `returnData` - Base64 or hex-encoded return data parts
  ///
  /// #### Returns
  /// `List<TypedValue>` with parsed and validated values
  ///
  /// #### Throws
  /// - `ResponseParsingException` - If parsing or validation fails
  List<TypedValue> parseForEndpoint({
    required AbiEndpoint endpoint,
    required List<String> returnData,
  }) {
    if (resolver != null) {
      resolver!.validateReturnCount(endpoint.name, returnData.length);
    }
    final List<TypedValue> typedValues = decodeReturnData(
      endpoint: endpoint,
      returnData: returnData,
    );

    return typedValues;
  }

  /// Decodes return data to typed values using endpoint output definitions.
  ///
  /// Low-level decoding without validation.
  ///
  /// #### Parameters
  /// - `endpoint` - Endpoint with output type definitions
  /// - `returnData` - Encoded return data
  ///
  /// #### Returns
  /// `List<TypedValue>` with decoded values
  ///
  /// #### Throws
  /// - `ResponseParsingException` - If decoding fails or count mismatch
  List<TypedValue> decodeReturnData({
    required AbiEndpoint endpoint,
    required List<String> returnData,
  }) {
    final List<AbiParameter> outputs = endpoint.outputs.toList();

    if (returnData.isEmpty && endpoint.outputs.hasMultiResult) {
      return <TypedValue>[];
    }

    final bool lastIsVariadic =
        outputs.isNotEmpty && outputs.last.type is VariadicType;

    if (!lastIsVariadic && returnData.length != outputs.length) {
      throw ResponseParsingException(
        'Return data count mismatch: expected ${outputs.length}, got ${returnData.length}',
        endpointName: endpoint.name,
      );
    }
    if (lastIsVariadic && returnData.length < outputs.length - 1) {
      throw ResponseParsingException(
        'Return data count mismatch: expected at least ${outputs.length - 1} '
        'non-variadic outputs, got ${returnData.length}',
        endpointName: endpoint.name,
      );
    }

    final List<TypedValue> typedValues = <TypedValue>[];

    final int fixedCount = lastIsVariadic ? outputs.length - 1 : outputs.length;
    for (int i = 0; i < fixedCount; i++) {
      typedValues.add(_safeDecode(outputs[i], returnData[i], i, endpoint.name));
    }

    if (lastIsVariadic) {
      final VariadicType variadicType = outputs.last.type as VariadicType;
      final AbiType itemType = variadicType.itemType;
      final List<TypedValue> items = <TypedValue>[];
      for (int i = fixedCount; i < returnData.length; i++) {
        final AbiParameter itemParam = AbiParameter(
          name: outputs.last.name,
          type: itemType,
        );
        items.add(_safeDecode(itemParam, returnData[i], i, endpoint.name));
      }
      typedValues.add(VariadicValue(items, itemType: itemType));
    }

    return typedValues;
  }

  TypedValue _safeDecode(
    AbiParameter output,
    String data,
    int index,
    String endpointName,
  ) {
    try {
      AbiType decodeType = output.type;
      if (output.multiResult && _isOptionalType(output.type)) {
        decodeType = _unwrapOptionalType(output.type);
      }
      return _decodeValue(data, decodeType, index, endpointName);
    } catch (e, stackTrace) {
      if (e is ResponseParsingException) rethrow;
      throw ResponseParsingException(
        'Failed to decode return data at index $index',
        endpointName: endpointName,
        returnIndex: index,
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Checks if type is an optional type.
  bool _isOptionalType(AbiType type) {
    return type is OptionalType || type is OptionType;
  }

  /// Unwraps the inner type from an optional type.
  AbiType _unwrapOptionalType(AbiType type) {
    if (type.typeParameters.isNotEmpty) {
      return type.typeParameters.first;
    }
    return type;
  }

  /// Decodes single return value.
  TypedValue _decodeValue(
    String data,
    AbiType type,
    int index,
    String endpointName,
  ) {
    try {
      final Uint8List bytes = _stringToBytes(data);
      final TypedValue typedValue = serializer.codec.decodeTopLevel(
        bytes,
        type,
      );

      return typedValue;
    } catch (e, stackTrace) {
      throw ResponseParsingException(
        'Failed to decode value at index $index to ${type.name}',
        endpointName: endpointName,
        returnIndex: index,
        expectedType: type.name,
        rawData: data,
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Converts base64 or hex to bytes.
  Uint8List _stringToBytes(String data) {
    if (data.isEmpty) {
      return Uint8List(0);
    }

    try {
      return Uint8List.fromList(base64.decode(data));
    } catch (_) {
      // Not valid base64, try hex
    }
    if (_isHexString(data)) {
      return HexUtils.hexToBytes(data);
    }
    throw ResponseParsingException(
      'Invalid data encoding: must be base64 or hex',
      rawData: data,
    );
  }

  static final RegExp _hexRegex = RegExp(r'^[0-9a-fA-F]+$');

  /// Checks if a string is valid hex.
  bool _isHexString(String str) {
    if (str.isEmpty) return true;
    if (str.length % 2 != 0) return false;

    return _hexRegex.hasMatch(str);
  }

  /// Parses response with explicit output types (no endpoint required).
  ///
  /// Parse when you have output types but not full endpoint.
  ///
  /// #### Parameters
  /// - `outputTypes` - Output parameter types
  /// - `returnData` - Encoded return data
  ///
  /// #### Returns
  /// `List<TypedValue>` with parsed values
  ///
  /// #### Throws
  /// - `ResponseParsingException` - If parsing fails
  List<TypedValue> parseWithTypes({
    required List<AbiParameter> outputTypes,
    required List<String> returnData,
  }) {
    if (returnData.length != outputTypes.length) {
      throw ResponseParsingException(
        'Return data count mismatch: expected ${outputTypes.length}, got ${returnData.length}',
      );
    }

    final List<TypedValue> typedValues = <TypedValue>[];

    for (int i = 0; i < returnData.length; i++) {
      final AbiParameter output = outputTypes[i];
      final String data = returnData[i];
      final TypedValue typedValue = _decodeValue(data, output.type, i, 'typed');
      typedValues.add(typedValue);
    }

    return typedValues;
  }

  /// Parses single value with explicit type.
  TypedValue parseSingleValue({
    required AbiParameter outputType,
    required String returnData,
  }) {
    return _decodeValue(returnData, outputType.type, 0, 'single');
  }

  /// Decodes typed values without validation.
  List<TypedValue> decodeTypedValues({
    required List<String> returnData,
    required List<AbiType> types,
  }) {
    if (returnData.length != types.length) {
      throw ResponseParsingException(
        'Data count mismatch: expected ${types.length}, got ${returnData.length}',
      );
    }

    final List<TypedValue> typedValues = <TypedValue>[];

    for (int i = 0; i < returnData.length; i++) {
      final TypedValue typedValue = _decodeValue(
        returnData[i],
        types[i],
        i,
        'direct',
      );
      typedValues.add(typedValue);
    }

    return typedValues;
  }

  /// Converts typed values to native Dart values.
  ///
  /// Extract native values (int, String, BigInt, etc.) from TypedValue.
  ///
  /// #### Parameters
  /// - `typedValues` - Typed values to convert
  ///
  /// #### Returns
  /// `List<dynamic>` with native Dart values
  List<dynamic> toNativeValues(List<TypedValue> typedValues) {
    return typedValues.map((TypedValue value) => value.valueOf()).toList();
  }
}
