/// Smart contract query input, response, execution, and exception classes.

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../core/address.dart';
import '../../../core/balance.dart';
import '../../../utils/collection_utils.dart';
import '../../../utils/helpers.dart';
import '../../../utils/hex_utils.dart';
import '../../../utils/sdk_exceptions.dart';
import '../../abi.dart';

/// Exception for smart contract query failures.
///
/// Provides detailed error information including the original response
/// and the function that failed.
///
/// Part of the unified SDK hierarchy: catch it as [SmartContractException] or
/// as [AbidockException].
@immutable
class SmartContractQueryException extends SmartContractException {
  /// Creates a query exception.
  ///
  /// #### Parameters
  /// - `message` - Human-readable error description
  /// - `code` - Error code from the smart contract
  /// - `response` - The original query response
  const SmartContractQueryException({
    required String message,
    required this.code,
    this.response,
  }) : super(message);

  /// Creates exception from query response.
  ///
  /// #### Parameters
  /// - `response` - The failed query response
  ///
  /// #### Returns
  /// `SmartContractQueryException` with response details
  factory SmartContractQueryException.fromResponse(
    SmartContractQueryResponse response,
  ) {
    return SmartContractQueryException(
      message: response.returnMessage.isNotEmpty
          ? response.returnMessage
          : 'Query failed with code: ${response.returnCode}',
      code: response.returnCode,
      response: response,
    );
  }

  /// Creates exception for network errors.
  ///
  /// #### Parameters
  /// - `error` - The underlying error
  /// - `functionName` - The function that was being called
  ///
  /// #### Returns
  /// `SmartContractQueryException` for network failure
  factory SmartContractQueryException.networkError(
    Object error,
    String functionName,
  ) {
    return SmartContractQueryException(
      message: 'Network error querying "$functionName": $error',
      code: 'network_error',
    );
  }

  /// Error code from the smart contract or system.
  final String code;

  /// The original query response, if available.
  final SmartContractQueryResponse? response;

  /// The function that was being queried.
  SmartContractFunction? get function => response?.function;

  @override
  String toString() => 'SmartContractQueryException: $message (code: $code)';
}

/// Input parameters for smart contract queries with optional ABI validation.
///
/// Define query parameters with or without ABI integration.
@immutable
final class SmartContractQueryInput {
  /// Creates smart contract query input.
  ///
  /// #### Parameters
  /// - `contract` - Smart contract address
  /// - `function` - Function name
  /// - `arguments` - Function arguments (default: empty)
  /// - `caller` - Optional caller address for access control
  /// - `value` - Optional EGLD value (default: zero)
  /// - `abi` - Optional ABI for type validation
  /// - `endpointResolver` - Optional resolver
  /// - `argumentEncoder` - Optional encoder
  /// - `encodedArguments` - Optional pre-encoded args
  SmartContractQueryInput({
    required this.contract,
    required this.function,
    this.arguments = const <dynamic>[],
    this.caller,
    Balance? value,
    this.abi,
    this.endpointResolver,
    this.argumentEncoder,
    this.encodedArguments,
  }) : value = value ?? Balance.zero();

  /// Creates ABI-enabled query input with automatic type validation.
  ///
  /// Create type-safe query with ABI validation and encoding.
  ///
  /// #### Parameters
  /// - `abi` - Contract ABI definition
  /// - `contract` - Contract address
  /// - `function` - Function name
  /// - `arguments` - Function arguments
  /// - `caller` - Optional caller address
  /// - `value` - Optional EGLD value
  ///
  /// #### Returns
  /// `SmartContractQueryInput` with ABI integration
  ///
  /// #### Throws
  /// - `EndpointNotFoundException` - If function not found in ABI
  ///
  /// #### Example
  /// ```dart
  /// final input = SmartContractQueryInput.fromAbi(
  ///   abi: smartContractAbi,
  ///   contract: contractAddr,
  ///   function: SmartContractFunction('balanceOf'),
  ///   arguments: [Address.fromBech32('erd1...')],
  /// );
  /// ```
  factory SmartContractQueryInput.fromAbi({
    required SmartContractAbi abi,
    required SmartContractAddress contract,
    required SmartContractFunction function,
    List<dynamic> arguments = const <dynamic>[],
    Address? caller,
    Balance? value,
  }) {
    final EndpointResolver resolver = EndpointResolver(abi);
    final ArgSerializer serializer = ArgSerializer();
    final ArgumentEncoder encoder = ArgumentEncoder(
      serializer: serializer,
      resolver: resolver,
    );
    if (!resolver.hasEndpoint(function.name)) {
      throw EndpointNotFoundException.withSuggestions(
        endpointName: function.name,
        abi: abi,
      );
    }

    return SmartContractQueryInput(
      contract: contract,
      function: function,
      arguments: arguments,
      caller: caller,
      value: value,
      abi: abi,
      endpointResolver: resolver,
      argumentEncoder: encoder,
    );
  }

  /// Creates query for view function with no arguments.
  factory SmartContractQueryInput.view({
    required SmartContractAddress contract,
    required SmartContractFunction function,
    Address? caller,
  }) {
    return SmartContractQueryInput(
      contract: contract,
      function: function,
      arguments: const <dynamic>[],
      caller: caller,
      value: Balance.zero(),
    );
  }

  /// Creates query with single argument.
  factory SmartContractQueryInput.withSingleArgument({
    required SmartContractAddress contract,
    required SmartContractFunction function,
    required dynamic argument,
    Address? caller,
  }) {
    return SmartContractQueryInput(
      contract: contract,
      function: function,
      arguments: <dynamic>[argument],
      caller: caller,
      value: Balance.zero(),
    );
  }

  /// The address of the smart contract to query.
  final Address contract;

  /// The name of the function to call.
  final SmartContractFunction function;

  /// The arguments to pass to the function.
  final List<dynamic> arguments;

  /// The caller address (optional, used for access control).
  final Address? caller;

  /// The value to send with the query (usually zero for view functions).
  final Balance value;

  /// Optional ABI definition for type-safe queries.
  final SmartContractAbi? abi;

  /// Optional endpoint resolver for ABI validation.
  final EndpointResolver? endpointResolver;

  /// Optional argument encoder for ABI encoding.
  final ArgumentEncoder? argumentEncoder;

  /// Pre-encoded arguments (used when arguments are already encoded).
  final List<String>? encodedArguments;

  /// Whether this query uses ABI integration.
  bool get hasAbi => abi != null;

  /// Whether arguments need encoding (ABI-based query with arguments).
  bool get needsEncoding => hasAbi && arguments.isNotEmpty;

  /// Validates query against ABI endpoint definition.
  void validateAgainstAbi() {
    if (!hasAbi) {
      return;
    }

    final EndpointResolver? resolver = endpointResolver;
    if (resolver == null) {
      return;
    }
    if (!resolver.hasEndpoint(function.name)) {
      throw EndpointNotFoundException.withSuggestions(
        endpointName: function.name,
        abi: abi!,
      );
    }

    try {
      resolver.validateArgumentCount(function.name, arguments.length);
    } catch (e) {
      if (e is ArgumentValidationException) {
        rethrow;
      }
      final AbiEndpoint? endpoint = abi!.getEndpoint(function);
      final int expectedCount = endpoint?.inputs.length ?? 0;
      throw ArgumentValidationException.countMismatch(
        endpointName: function.name,
        expected: expectedCount,
        actual: arguments.length,
      );
    }
  }

  /// Encodes arguments using ABI encoder.
  List<String> encodeArguments() {
    if (encodedArguments != null) {
      return encodedArguments!;
    }

    if (arguments.isEmpty) {
      return <String>[];
    }
    final ArgumentEncoder? encoder = argumentEncoder;
    if (encoder == null || !hasAbi) {
      final BinaryCodec codec = BinaryCodec.withDefaults();
      return arguments.map<String>((dynamic arg) {
        if (arg is String) return arg;
        if (arg is Uint8List) return HexUtils.bytesToHex(arg);
        if (arg is List<int>) {
          return HexUtils.bytesToHex(Uint8List.fromList(arg));
        }
        if (arg is TypedValue) {
          return HexUtils.bytesToHex(codec.encodeTopLevel(arg));
        }
        throw ArgumentEncodingException(
          'Non-ABI query argument must be String (hex), Uint8List, or '
          'TypedValue; got ${arg.runtimeType}',
          endpointName: function.name,
          argumentValue: arg,
        );
      }).toList();
    }
    final AbiEndpoint? endpoint = abi!.getEndpoint(function);
    if (endpoint == null) {
      throw EndpointNotFoundException.withSuggestions(
        endpointName: function.name,
        abi: abi!,
      );
    }

    try {
      return encoder.encodeForEndpoint(
        endpoint: endpoint,
        arguments: arguments,
      );
    } catch (e) {
      if (e is ArgumentEncodingException || e is ArgumentValidationException) {
        rethrow;
      }
      throw ArgumentEncodingException(
        'Failed to encode arguments for endpoint "$function": $e',
        endpointName: function.name,
        argumentValue: arguments,
        cause: e,
      );
    }
  }

  /// Converts this query input to a map representation for HTTP requests.
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> result = <String, dynamic>{
      'scAddress': contract.bech32,
      'funcName': function.name,
      'args': encodeArguments(),
    };

    if (caller != null) {
      result['caller'] = caller!.bech32;
    }

    if (value.value != BigInt.zero) {
      result['value'] = value.value.toString();
    }

    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmartContractQueryInput &&
          runtimeType == other.runtimeType &&
          contract == other.contract &&
          function == other.function &&
          CollectionUtils.listEquals(arguments, other.arguments) &&
          caller == other.caller &&
          value.value == other.value.value;

  @override
  int get hashCode => Object.hash(
    contract,
    function,
    Object.hashAll(arguments),
    caller,
    value.value,
  );

  @override
  String toString() {
    return 'SmartContractQueryInput{contract: ${contract.bech32}, function: $function, args: ${arguments.length}}';
  }
}

/// Smart contract query response containing results or errors.
///
/// Represents the result of a smart contract query execution.
@immutable
final class SmartContractQueryResponse {
  /// Creates query response.
  ///
  /// #### Parameters
  /// - `function` - Function that was called
  /// - `returnCode` - Return code ('ok' for success)
  /// - `returnMessage` - Return message (empty for success)
  /// - `returnDataParts` - Base64-encoded return data parts
  const SmartContractQueryResponse({
    required this.function,
    required this.returnCode,
    required this.returnMessage,
    required this.returnDataParts,
  });

  /// Creates response from HTTP API data.
  factory SmartContractQueryResponse.fromHttpResponse(
    Map<String, dynamic> responseData,
    SmartContractFunction functionName,
  ) {
    final List<dynamic> returnData =
        optionalAs<List<dynamic>>(responseData['returnData'], 'returnData') ??
        optionalAs<List<dynamic>>(responseData['ReturnData'], 'ReturnData') ??
        <dynamic>[];

    final String returnCode =
        optionalAs<String>(responseData['returnCode'], 'returnCode') ??
        optionalAs<String>(responseData['ReturnCode'], 'ReturnCode') ??
        'unknown';

    final String returnMessage =
        optionalAs<String>(responseData['returnMessage'], 'returnMessage') ??
        optionalAs<String>(responseData['ReturnMessage'], 'ReturnMessage') ??
        '';

    return SmartContractQueryResponse(
      function: functionName,
      returnCode: returnCode,
      returnMessage: returnMessage,
      returnDataParts: returnData.map((item) => item.toString()).toList(),
    );
  }

  /// Creates successful response.
  factory SmartContractQueryResponse.success({
    required SmartContractFunction function,
    required List<String> returnDataParts,
  }) {
    return SmartContractQueryResponse(
      function: function,
      returnCode: 'ok',
      returnMessage: '',
      returnDataParts: returnDataParts,
    );
  }

  /// Creates error response.
  factory SmartContractQueryResponse.error({
    required SmartContractFunction function,
    required String returnCode,
    required String returnMessage,
  }) {
    return SmartContractQueryResponse(
      function: function,
      returnCode: returnCode,
      returnMessage: returnMessage,
      returnDataParts: const <String>[],
    );
  }

  /// The name of the function that was called.
  final SmartContractFunction function;

  /// The return code from the smart contract execution.
  final String returnCode;

  /// The return message from the smart contract execution.
  final String returnMessage;

  /// The return data parts as base64-encoded strings.
  final List<String> returnDataParts;

  /// Whether the query was successful.
  bool get isSuccess => returnCode.toReturnCode().isSuccess;

  /// Whether the query failed.
  bool get isFailure => !isSuccess;

  /// Gets the parsed return code as a [ReturnCode] instance.
  ReturnCode get parsedReturnCode => returnCode.toReturnCode();

  /// Whether the query has return data.
  bool get hasReturnData => returnDataParts.isNotEmpty;

  /// The number of return data parts.
  int get returnDataCount => returnDataParts.length;

  /// Gets return data at index.
  String getReturnData(int index) {
    if (index < 0 || index >= returnDataParts.length) {
      throw RangeError.index(index, returnDataParts, 'returnDataParts');
    }
    return returnDataParts[index];
  }

  /// Gets first return data part or null.
  String? get firstReturnData {
    return returnDataParts.isNotEmpty ? returnDataParts.first : null;
  }

  /// Converts this response to a map representation.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'function': function,
      'returnCode': returnCode,
      'returnMessage': returnMessage,
      'returnData': returnDataParts,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmartContractQueryResponse &&
          runtimeType == other.runtimeType &&
          function == other.function &&
          returnCode == other.returnCode &&
          returnMessage == other.returnMessage &&
          CollectionUtils.listEquals(returnDataParts, other.returnDataParts);

  @override
  int get hashCode => Object.hash(
    function,
    returnCode,
    returnMessage,
    Object.hashAll(returnDataParts),
  );

  @override
  String toString() {
    if (isSuccess) {
      return 'SmartContractQueryResponse{function: $function, success: true, data: ${returnDataParts.length} parts}';
    } else {
      return 'SmartContractQueryResponse{function: $function, error: $returnCode - $returnMessage}';
    }
  }
}

/// Complete smart contract query combining input and execution.
///
/// Represents a query ready for execution by a query provider.
@immutable
final class SmartContractQuery {
  /// Creates smart contract query from input parameters.
  ///
  /// #### Parameters
  /// - `input` - Query input parameters
  const SmartContractQuery(this.input);

  /// Creates a view function query with minimal parameters.
  ///
  /// Quick factory for simple view queries without arguments.
  ///
  /// #### Parameters
  /// - `contract` - Contract address
  /// - `function` - View function name
  /// - `arguments` - Optional arguments (default: empty)
  /// - `caller` - Optional caller address
  ///
  /// #### Returns
  /// `SmartContractQuery` instance
  ///
  /// #### Example
  /// ```dart
  /// final query = SmartContractQuery.view(
  ///   contract: SmartContractAddress.fromBech32('erd1qqqqqq...'),
  ///   function: SmartContractFunction('getTotal'),
  /// );
  /// ```
  factory SmartContractQuery.view({
    required SmartContractAddress contract,
    required SmartContractFunction function,
    List<dynamic> arguments = const <dynamic>[],
    Address? caller,
  }) {
    return SmartContractQuery(
      SmartContractQueryInput(
        contract: contract,
        function: function,
        arguments: arguments,
        caller: caller,
      ),
    );
  }

  /// The input parameters for this query.
  final SmartContractQueryInput input;

  /// The contract address being queried.
  Address get contract => input.contract;

  /// The function name being called.
  SmartContractFunction get function => input.function;

  /// The arguments being passed to the function.
  List<dynamic> get arguments => input.arguments;

  /// The caller address, if specified.
  Address? get caller => input.caller;

  /// The value being sent with the query.
  Balance get value => input.value;

  /// Whether this query has arguments.
  bool get hasArguments => arguments.isNotEmpty;

  /// The number of arguments.
  int get argumentCount => arguments.length;

  /// Converts this query to a map for HTTP requests.
  Map<String, dynamic> toMap() => input.toMap();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmartContractQuery &&
          runtimeType == other.runtimeType &&
          input == other.input;

  @override
  int get hashCode => input.hashCode;

  @override
  String toString() => 'SmartContractQuery{${input.toString()}}';
}
