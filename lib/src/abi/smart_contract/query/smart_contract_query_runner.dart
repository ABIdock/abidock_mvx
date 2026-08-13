/// Smart contract query execution with a single unified API.
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/address.dart';
import '../../../core/balance.dart';
import '../../../infrastructure/logging/logger.dart';
import '../../../infrastructure/network/network_provider.dart';
import '../../abi.dart';
import '../utils/argument_validation.dart';

/// Result of a smart contract query containing both raw and typed data.
///
/// Provides access to query results in multiple formats:
/// - `values` - Native Dart values (int, String, BigInt, etc.)
/// - `typedValues` - TypedValue objects with ABI type information
/// - `rawData` - Original base64-encoded response parts
///
/// #### Example
/// ```dart
/// final result = await queryRunner.query(endpointName: 'getData');
///
/// // Access native values directly
/// print('First value: ${result.values[0]}');
///
/// // Access typed values for more control
/// for (final typed in result.typedValues) {
///   print('Type: ${typed.type.name}, Value: ${typed.nativeValue}');
/// }
/// ```
final class QueryResult {
  /// Creates a query result with all data representations.
  const QueryResult({
    required this.values,
    required this.typedValues,
    required this.rawData,
    required this.returnCode,
  });

  /// Native Dart values extracted from the response.
  ///
  /// Types are automatically converted based on ABI:
  /// - `u32`, `u64`, `BigUint` → `BigInt`
  /// - `Address` → `Address`
  /// - `bytes` → `Uint8List`
  /// - Custom structs → `Map<String, dynamic>`
  final List<dynamic> values;

  /// TypedValue objects with full ABI type information.
  ///
  /// Use this when you need access to the ABI type metadata
  /// or when working with complex nested types.
  final List<TypedValue> typedValues;

  /// Raw base64-encoded response parts from the API.
  ///
  /// Useful for debugging or when you need the original data.
  final List<String> rawData;

  /// The return code from the query execution.
  final ReturnCode returnCode;

  /// Whether the query was successful.
  bool get isSuccess => returnCode.isSuccess;

  /// Whether the query returned no data.
  bool get isEmpty => values.isEmpty;

  /// Gets the first value or null if empty.
  ///
  /// Convenient for single-return-value endpoints.
  ///
  /// #### Example
  /// ```dart
  /// final total = result.first as BigInt;
  /// ```
  dynamic get first => values.isNotEmpty ? values.first : null;

  /// Gets a value at the specified index.
  ///
  /// #### Parameters
  /// - `index` - Index of the value
  ///
  /// #### Returns
  /// Value at index
  ///
  /// #### Throws
  /// - `RangeError` - If index is out of bounds
  dynamic operator [](int index) => values[index];

  /// The number of return values.
  int get length => values.length;

  @override
  String toString() {
    return 'QueryResult{values: $values, returnCode: $returnCode}';
  }
}

/// Result of a smart contract query without ABI parsing.
///
/// Returns raw byte data from the smart contract without type interpretation.
/// Use this when interacting with contracts without an ABI definition.
///
/// #### Example
/// ```dart
/// final result = await queryRunner.queryRaw(
///   endpointName: 'getBalance',
///   arguments: [AddressValue.fromBech32('erd1user...')],
/// );
///
/// // Access raw bytes
/// final balanceBytes = result.returnDataParts[0];
/// final balance = BigInt.parse(HexUtils.bytesToHex(balanceBytes), radix: 16);
/// ```
final class RawQueryResult {
  /// Creates a raw query result.
  const RawQueryResult({
    required this.returnDataParts,
    required this.returnCode,
    required this.returnMessage,
  });

  /// Raw byte arrays from the smart contract response.
  ///
  /// Each element corresponds to one return value from the contract.
  /// The bytes are not interpreted - you must decode them yourself.
  final List<Uint8List> returnDataParts;

  /// The return code from query execution.
  final ReturnCode returnCode;

  /// The return message from query execution.
  final String returnMessage;

  /// Whether the query was successful.
  bool get isSuccess => returnCode.isSuccess;

  /// Whether the query returned no data.
  bool get isEmpty => returnDataParts.isEmpty;

  /// Gets the first data part or null if empty.
  Uint8List? get first =>
      returnDataParts.isNotEmpty ? returnDataParts.first : null;

  /// Gets a data part at the specified index.
  ///
  /// #### Parameters
  /// - `index` - Index of the data part
  ///
  /// #### Returns
  /// Raw bytes at index
  ///
  /// #### Throws
  /// - `RangeError` - If index is out of bounds
  Uint8List operator [](int index) => returnDataParts[index];

  /// The number of return data parts.
  int get length => returnDataParts.length;

  @override
  String toString() {
    return 'RawQueryResult{parts: ${returnDataParts.length}, returnCode: $returnCode}';
  }
}

/// Executes smart contract queries with a single unified API.
///
/// Supports two modes of operation:
/// - **With ABI**: Arguments are native Dart values, responses are parsed
/// - **Without ABI**: Arguments must be [TypedValue] or [Uint8List], returns raw bytes
///
/// #### Features
/// - Single `query()` method for ABI-based queries
/// - `queryRaw()` method for raw queries without ABI
/// - Automatic argument encoding and response parsing with ABI
/// - Optional caller address for access-controlled views
///
/// #### Example with ABI
/// ```dart
/// final queryRunner = SmartContractQueryRunner(
///   contractAddress: SmartContractAddress.fromBech32('erd1qqqqqq...'),
///   networkProvider: provider,
///   abi: SmartContractAbi.fromJson(abiJson),
/// );
///
/// final total = await queryRunner.query(endpointName: 'getTotal');
/// print('Total: ${total.first}');
/// ```
///
/// #### Example without ABI
/// ```dart
/// final queryRunner = SmartContractQueryRunner.withoutAbi(
///   contractAddress: SmartContractAddress.fromBech32('erd1qqqqqq...'),
///   networkProvider: provider,
/// );
///
/// final result = await queryRunner.queryRaw(
///   endpointName: 'getBalance',
///   arguments: [AddressValue.fromBech32('erd1user...')],
/// );
/// final balanceBytes = result.returnDataParts[0];
/// ```
final class SmartContractQueryRunner {
  /// Creates query runner with contract address, network provider, and ABI.
  ///
  /// #### Parameters
  /// - `contractAddress` - Target smart contract address
  /// - `networkProvider` - Network provider for API calls
  /// - `abi` - Smart contract ABI for encoding/decoding
  /// - `logger` - Optional logger for debugging
  factory SmartContractQueryRunner({
    required SmartContractAddress contractAddress,
    required NetworkProvider networkProvider,
    required SmartContractAbi abi,
    Logger? logger,
  }) {
    final EndpointResolver resolver = EndpointResolver(abi, logger: logger);
    return SmartContractQueryRunner._internal(
      contractAddress: contractAddress,
      networkProvider: networkProvider,
      abi: abi,
      endpointResolver: resolver,
      responseParser: ResponseParser(
        serializer: ArgSerializer(),
        resolver: resolver,
      ),
      logger: logger,
    );
  }

  SmartContractQueryRunner._internal({
    required this.contractAddress,
    required this._networkProvider,
    required SmartContractAbi this._abi,
    required EndpointResolver this._endpointResolver,
    required ResponseParser this._responseParser,
    this.logger,
  }) : _rawArgValidator = RawArgumentValidator(ArgSerializer());

  /// Creates query runner without ABI for raw [TypedValue] or [Uint8List] arguments.
  ///
  /// When no ABI is provided:
  /// - Use `queryRaw()` instead of `query()`
  /// - Arguments must be [TypedValue] instances or [Uint8List]
  /// - Responses are returned as raw bytes, not parsed
  ///
  /// #### Parameters
  /// - `contractAddress` - Target smart contract address
  /// - `networkProvider` - Network provider for API calls
  /// - `logger` - Optional logger for debugging
  ///
  /// #### Example
  /// ```dart
  /// final queryRunner = SmartContractQueryRunner.withoutAbi(
  ///   contractAddress: SmartContractAddress.fromBech32('erd1qqqqqq...'),
  ///   networkProvider: provider,
  /// );
  ///
  /// final result = await queryRunner.queryRaw(
  ///   endpointName: 'getBalance',
  ///   arguments: [AddressValue.fromBech32('erd1user...')],
  /// );
  /// ```
  SmartContractQueryRunner.withoutAbi({
    required this.contractAddress,
    required this._networkProvider,
    this.logger,
  }) : _abi = null,
       _endpointResolver = null,
       _responseParser = null,
       _rawArgValidator = RawArgumentValidator(ArgSerializer());

  /// The target smart contract address.
  final SmartContractAddress contractAddress;

  /// The smart contract ABI (optional).
  final SmartContractAbi? _abi;

  /// The smart contract ABI.
  ///
  /// #### Throws
  /// - [StateError] if runner was created without ABI
  SmartContractAbi get abi {
    if (_abi == null) {
      throw StateError(
        'ABI is not available. Runner was created with withoutAbi().',
      );
    }
    return _abi;
  }

  /// Whether this runner has an ABI for validation and parsing.
  bool get hasAbi => _abi != null;

  /// Optional logger for debugging.
  final Logger? logger;

  /// Internal network provider for direct API calls.
  final NetworkProvider _networkProvider;

  /// Internal endpoint resolver for ABI validation (null when no ABI).
  final EndpointResolver? _endpointResolver;

  /// Internal response parser for decoding results (null when no ABI).
  final ResponseParser? _responseParser;

  /// Validator for raw arguments (used when no ABI).
  final RawArgumentValidator _rawArgValidator;

  /// Executes a smart contract query and returns parsed results.
  ///
  /// This is the single unified query method that replaces all the confusing
  /// variants (queryTyped, queryWithInput, queryBatch).
  ///
  /// #### Parameters
  /// - `endpointName` - View function name to call
  /// - `arguments` - Function arguments (native Dart values)
  /// - `caller` - Optional caller address for access-controlled views
  /// - `value` - Optional EGLD value (usually zero for queries)
  ///
  /// #### Returns
  /// `QueryResult` containing native values, typed values, and raw data
  ///
  /// #### Throws
  /// - `EndpointNotFoundException` - If endpoint not found in ABI
  /// - `SmartContractQueryException` - If query execution fails
  /// - `ResponseParsingException` - If response parsing fails
  ///
  /// #### Example
  /// ```dart
  /// // Query without arguments
  /// final result = await queryRunner.query(endpointName: 'getTotal');
  /// final total = result.first as BigInt;
  ///
  /// // Query with arguments (pass bech32 string for Address types)
  /// final balanceResult = await queryRunner.query(
  ///   endpointName: 'balanceOf',
  ///   arguments: ['erd1...'],  // bech32 string, auto-converted to Address
  /// );
  /// final balance = balanceResult.first as BigInt;
  ///
  /// // Query with caller for access control
  /// final adminResult = await queryRunner.query(
  ///   endpointName: 'getAdminStats',
  ///   caller: adminAddress,
  /// );
  /// ```
  Future<QueryResult> query({
    required String endpointName,
    List<dynamic> arguments = const <dynamic>[],
    Address? caller,
    Balance? value,
  }) async {
    final SmartContractFunction function = SmartContractFunction.validated(
      endpointName,
    );

    logger?.info(
      'Executing smart contract query',
      context: <String, dynamic>{
        'contract': contractAddress.bech32,
        'endpoint': endpointName,
        'argsCount': arguments.length,
        'hasCaller': (caller != null).toString(),
      },
    );

    final Stopwatch stopwatch = Stopwatch()..start();

    try {
      final SmartContractQueryInput input = SmartContractQueryInput.fromAbi(
        abi: abi,
        contract: contractAddress,
        function: function,
        arguments: arguments,
        caller: caller,
        value: value,
      );

      final SmartContractQuery queryObj = SmartContractQuery(input);
      final SmartContractQueryResponse response = await _networkProvider
          .queryContract(queryObj);

      if (!response.isSuccess) {
        logger?.warning(
          'Smart contract query returned error',
          context: <String, dynamic>{
            'endpoint': endpointName,
            'returnCode': response.returnCode,
            'returnMessage': response.returnMessage,
            'latencyMs': stopwatch.elapsedMilliseconds.toString(),
          },
        );
        throw SmartContractQueryException.fromResponse(response);
      }

      final AbiEndpoint endpoint = _endpointResolver!.getEndpoint(endpointName);
      final List<TypedValue> typedValues = _responseParser!.parseForEndpoint(
        endpoint: endpoint,
        returnData: response.returnDataParts,
      );

      final List<dynamic> nativeValues = typedValues
          .map((TypedValue tv) => tv.nativeValue)
          .toList();

      logger?.info(
        'Smart contract query successful',
        context: <String, dynamic>{
          'endpoint': endpointName,
          'resultCount': typedValues.length.toString(),
          'latencyMs': stopwatch.elapsedMilliseconds.toString(),
        },
      );

      return QueryResult(
        values: nativeValues,
        typedValues: typedValues,
        rawData: response.returnDataParts,
        returnCode: response.parsedReturnCode,
      );
    } catch (e, stackTrace) {
      logger?.error(
        'Smart contract query failed',
        error: e,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'endpoint': endpointName,
          'latencyMs': stopwatch.elapsedMilliseconds.toString(),
        },
      );
      rethrow;
    }
  }

  /// Executes a smart contract query without ABI and returns raw results.
  ///
  /// Use this method when you don't have an ABI definition. Arguments must
  /// be pre-typed as [TypedValue] or [Uint8List] instances.
  ///
  /// #### Parameters
  /// - `endpointName` - View function name to call
  /// - `arguments` - Pre-typed arguments ([TypedValue] or [Uint8List])
  /// - `caller` - Optional caller address for access-controlled views
  /// - `value` - Optional EGLD value (usually zero for queries)
  ///
  /// #### Returns
  /// [RawQueryResult] containing raw byte arrays from the response
  ///
  /// #### Throws
  /// - [SmartContractQueryException] if query execution fails
  /// - [ArgumentEncodingException] if arguments are not [TypedValue] or [Uint8List]
  ///
  /// #### Example
  /// ```dart
  /// final result = await queryRunner.queryRaw(
  ///   endpointName: 'getBalance',
  ///   arguments: [AddressValue.fromBech32('erd1user...')],
  /// );
  ///
  /// // Decode raw bytes manually
  /// final balanceBytes = result.returnDataParts[0];
  /// final balance = BigInt.parse(HexUtils.bytesToHex(balanceBytes), radix: 16);
  /// ```
  Future<RawQueryResult> queryRaw({
    required String endpointName,
    List<dynamic> arguments = const <dynamic>[],
    Address? caller,
    Balance? value,
  }) async {
    final SmartContractFunction function = SmartContractFunction.validated(
      endpointName,
    );

    logger?.info(
      'Executing raw smart contract query',
      context: <String, dynamic>{
        'contract': contractAddress.bech32,
        'endpoint': endpointName,
        'argsCount': arguments.length,
        'hasCaller': (caller != null).toString(),
        'hasAbi': hasAbi.toString(),
      },
    );

    final Stopwatch stopwatch = Stopwatch()..start();

    try {
      final List<String> encodedArgs = _encodeArguments(arguments);

      final SmartContractQueryInput input = SmartContractQueryInput(
        contract: contractAddress,
        function: function,
        caller: caller,
        value: value,
        encodedArguments: encodedArgs,
      );

      final SmartContractQuery queryObj = SmartContractQuery(input);
      final SmartContractQueryResponse response = await _networkProvider
          .queryContract(queryObj);

      if (!response.isSuccess) {
        logger?.warning(
          'Raw smart contract query returned error',
          context: <String, dynamic>{
            'endpoint': endpointName,
            'returnCode': response.returnCode,
            'returnMessage': response.returnMessage,
            'latencyMs': stopwatch.elapsedMilliseconds.toString(),
          },
        );
        throw SmartContractQueryException.fromResponse(response);
      }

      final List<Uint8List> returnDataParts = response.returnDataParts
          .map((String b64) => Uint8List.fromList(base64Decode(b64)))
          .toList();

      logger?.info(
        'Raw smart contract query successful',
        context: <String, dynamic>{
          'endpoint': endpointName,
          'resultCount': returnDataParts.length.toString(),
          'latencyMs': stopwatch.elapsedMilliseconds.toString(),
        },
      );

      return RawQueryResult(
        returnDataParts: returnDataParts,
        returnCode: response.parsedReturnCode,
        returnMessage: response.returnMessage,
      );
    } catch (e, stackTrace) {
      logger?.error(
        'Raw smart contract query failed',
        error: e,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'endpoint': endpointName,
          'latencyMs': stopwatch.elapsedMilliseconds.toString(),
        },
      );
      rethrow;
    }
  }

  /// Encodes arguments for raw queries.
  List<String> _encodeArguments(List<dynamic> arguments) {
    return _rawArgValidator.encodeRawArguments(arguments, context: 'raw query');
  }

  /// Checks if an endpoint exists in the ABI.
  ///
  /// #### Parameters
  /// - `endpointName` - Name of the endpoint to check
  ///
  /// #### Returns
  /// `true` if endpoint exists, `false` otherwise
  ///
  /// #### Throws
  /// - [StateError] if runner was created without ABI
  bool hasEndpoint(String endpointName) {
    if (_endpointResolver == null) {
      throw StateError(
        'Cannot check endpoint: runner was created without ABI.',
      );
    }
    return _endpointResolver.hasEndpoint(endpointName);
  }

  /// Gets an endpoint definition from the ABI.
  ///
  /// #### Parameters
  /// - `endpointName` - Name of the endpoint
  ///
  /// #### Returns
  /// `AbiEndpoint` definition
  ///
  /// #### Throws
  /// - [EndpointNotFoundException] if endpoint not found
  /// - [StateError] if runner was created without ABI
  AbiEndpoint getEndpoint(String endpointName) {
    if (_endpointResolver == null) {
      throw StateError('Cannot get endpoint: runner was created without ABI.');
    }
    return _endpointResolver.getEndpoint(endpointName);
  }

  /// Gets all view endpoints from the ABI.
  ///
  /// #### Returns
  /// List of view endpoints that can be queried
  ///
  /// #### Throws
  /// - [StateError] if runner was created without ABI
  List<AbiEndpoint> getViewEndpoints() {
    if (_endpointResolver == null) {
      throw StateError('Cannot get endpoints: runner was created without ABI.');
    }
    return _endpointResolver
        .getAllEndpoints()
        .where((AbiEndpoint e) => e.isView)
        .toList();
  }
}
