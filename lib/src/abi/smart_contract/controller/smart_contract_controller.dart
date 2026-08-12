/// Smart contract controller for signed transaction operations.
/// Combines Factory, QueryRunner, and EventRunner with transaction signing.

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../core/account/account_interface.dart';
import '../../../core/address.dart';
import '../../../core/balance.dart';
import '../../../core/nonce.dart';
import '../../../core/transaction/controllers/base_controller.dart';
import '../../../core/transaction/factories/smart_contract_transactions_factory.dart';
import '../../../core/transaction/gas_models/gas_limit.dart';
import '../../../core/transaction/outcome_parsers/smart_contract_outcome_parser.dart';
import '../../../core/transaction/transaction.dart';
import '../../../core/transaction/transaction_event_parser.dart';
import '../../../core/transaction/transaction_on_network.dart';
import '../../../core/transaction/transaction_watcher.dart';
import '../../../infrastructure/network/network_provider.dart';
import '../../abi.dart';

/// Smart contract controller providing query and call functionality.
///
/// Extends [BaseController] to provide smart contract interaction methods.
/// Uses internal Factory, QueryRunner, and EventRunner components.
///
/// Supports two modes of operation:
/// - **With ABI**: Arguments are native Dart values, responses are parsed
/// - **Without ABI**: Arguments must be [TypedValue] or [Uint8List], returns raw data
///
/// #### Example with ABI
/// ```dart
/// final controller = SmartContractController(
///   contractAddress: SmartContractAddress.fromBech32('erd1qqqqqq...'),
///   networkProvider: apiProvider,
///   abi: SmartContractAbi.fromJson(abiJson),
/// );
///
/// final result = await controller.query(endpointName: 'getTotal');
/// print('Total: ${result.first}');
///
/// final tx = await controller.call(
///   account: myAccount,
///   nonce: Nonce(42),
///   endpointName: 'deposit',
///   arguments: [BigInt.from(1000)],
///   options: BaseControllerInput(gasLimit: GasLimit(10000000)),
/// );
/// ```
///
/// #### Example without ABI
/// ```dart
/// final controller = SmartContractController.withoutAbi(
///   contractAddress: SmartContractAddress.fromBech32('erd1qqqqqq...'),
///   networkProvider: apiProvider,
/// );
///
/// final result = await controller.queryRaw(
///   endpointName: 'getBalance',
///   arguments: [AddressValue.fromBech32('erd1user...')],
/// );
///
/// final tx = await controller.callRaw(
///   account: myAccount,
///   nonce: Nonce(42),
///   endpointName: 'deposit',
///   arguments: [BigUIntValue(BigInt.from(1000))],
///   options: BaseControllerInput(gasLimit: GasLimit(10000000)),
/// );
/// ```
@immutable
final class SmartContractController extends BaseController {
  /// Creates controller with contract address, network provider, and ABI.
  ///
  /// #### Parameters
  /// - `contractAddress` - Target smart contract address
  /// - `networkProvider` - Network provider for API calls
  /// - `abi` - Smart contract ABI for validation and encoding
  /// - `logger` - Optional logger for debugging
  SmartContractController({
    required this.contractAddress,
    required this.networkProvider,
    required SmartContractAbi abi,
    super.gasLimitEstimator,
    super.logger,
  }) : _abi = abi,
       _factory = SmartContractCallFactory(
         contractAddress: contractAddress,
         abi: abi,
         chainId: networkProvider.chainId,
         logger: logger,
       ),
       _queryRunner = SmartContractQueryRunner(
         contractAddress: contractAddress,
         networkProvider: networkProvider,
         abi: abi,
         logger: logger,
       ),
       _eventRunner = SmartContractEventRunner(
         contractAddress: contractAddress,
         networkProvider: networkProvider,
         abi: abi,
         logger: logger,
       ),
       _outcomeParser = SmartContractOutcomeParser(abi: abi),
       _watcher = TransactionWatcher(networkProvider: networkProvider);

  /// Creates controller without ABI for raw [TypedValue] or [Uint8List] arguments.
  ///
  /// When no ABI is provided:
  /// - Use `queryRaw()` instead of `query()`
  /// - Use `callRaw()` instead of `call()`
  /// - Arguments must be [TypedValue] instances or [Uint8List]
  /// - Responses are returned as raw bytes, not parsed
  /// - Event methods are not available
  ///
  /// #### Parameters
  /// - `contractAddress` - Target smart contract address
  /// - `networkProvider` - Network provider for API calls
  /// - `logger` - Optional logger for debugging
  ///
  /// #### Example
  /// ```dart
  /// final controller = SmartContractController.withoutAbi(
  ///   contractAddress: SmartContractAddress.fromBech32('erd1qqqqqq...'),
  ///   networkProvider: provider,
  /// );
  ///
  /// final result = await controller.queryRaw(
  ///   endpointName: 'getBalance',
  ///   arguments: [AddressValue.fromBech32('erd1user...')],
  /// );
  ///
  /// final tx = await controller.callRaw(
  ///   account: myAccount,
  ///   nonce: Nonce(42),
  ///   endpointName: 'swap',
  ///   arguments: [
  ///     TokenIdentifierValue('WEGLD-abc123'),
  ///     BigUIntValue(BigInt.from(1000000000000000000)),
  ///   ],
  ///   options: BaseControllerInput(gasLimit: GasLimit(15000000)),
  /// );
  /// ```
  SmartContractController.withoutAbi({
    required this.contractAddress,
    required this.networkProvider,
    super.gasLimitEstimator,
    super.logger,
  }) : _abi = null,
       _factory = SmartContractCallFactory.withoutAbi(
         contractAddress: contractAddress,
         chainId: networkProvider.chainId,
         logger: logger,
       ),
       _queryRunner = SmartContractQueryRunner.withoutAbi(
         contractAddress: contractAddress,
         networkProvider: networkProvider,
         logger: logger,
       ),
       _eventRunner = null,
       _outcomeParser = const SmartContractOutcomeParser(),
       _watcher = TransactionWatcher(networkProvider: networkProvider);

  /// The target smart contract address.
  final Address contractAddress;

  /// The network provider for API calls.
  final NetworkProvider networkProvider;

  /// The smart contract ABI (optional).
  final SmartContractAbi? _abi;

  /// The smart contract ABI.
  ///
  /// #### Throws
  /// - [StateError] if controller was created without ABI
  SmartContractAbi get abi {
    if (_abi == null) {
      throw StateError(
        'ABI is not available. Controller was created with withoutAbi().',
      );
    }
    return _abi;
  }

  /// Whether this controller has an ABI for validation and parsing.
  bool get hasAbi => _abi != null;

  /// Internal factory for creating unsigned transactions.
  final SmartContractCallFactory _factory;

  /// Internal query runner for executing queries.
  final SmartContractQueryRunner _queryRunner;

  /// Internal event runner for event operations (null when no ABI).
  final SmartContractEventRunner? _eventRunner;

  /// Internal outcome parser for deploy / execute results.
  final SmartContractOutcomeParser _outcomeParser;

  /// Internal transaction watcher for awaitCompleted* methods.
  final TransactionWatcher _watcher;

  /// Creates an unsigned deploy transaction for this contract's bytecode.
  ///
  /// Delegates to [SmartContractTransactionsFactory.createTransactionForDeploy]
  /// without signing — caller is responsible for nonce and signing.
  ///
  /// #### Parameters
  /// - `sender` - Deployer address
  /// - `nonce` - Sender's account nonce
  /// - `bytecode` - WASM contract bytecode
  /// - `gasLimit` - Gas limit for the deploy transaction
  /// - `codeMetadata` - Optional code metadata bytes
  /// - `vmType` - Optional VM type identifier (default `0500`)
  /// - `arguments` - Optional constructor argument byte parts
  ///
  /// #### Returns
  /// Unsigned [Transaction] ready to be signed by the caller.
  ///
  /// #### Example
  /// ```dart
  /// final tx = controller.createTransactionForDeploy(
  ///   sender: alice.address,
  ///   nonce: const Nonce(7),
  ///   bytecode: wasm,
  ///   gasLimit: const GasLimit(60000000),
  /// );
  /// ```
  Transaction createTransactionForDeploy({
    required Address sender,
    required Nonce nonce,
    required Uint8List bytecode,
    required GasLimit gasLimit,
    Uint8List? codeMetadata,
    String vmType = '0500',
    List<Uint8List> arguments = const <Uint8List>[],
  }) {
    final SmartContractTransactionsFactory factory =
        SmartContractTransactionsFactory(
          SmartContractTransactionsConfig(chainId: networkProvider.chainId),
        );
    return factory.createTransactionForDeploy(
      sender: sender,
      bytecode: bytecode,
      gasLimit: gasLimit,
      codeMetadata: codeMetadata,
      vmType: vmType,
      arguments: arguments,
      nonce: nonce,
    );
  }

  /// Creates an unsigned upgrade transaction for this contract.
  ///
  /// #### Parameters
  /// - `sender` - Caller (current contract owner) address
  /// - `nonce` - Sender's account nonce
  /// - `bytecode` - New WASM contract bytecode
  /// - `gasLimit` - Gas limit for the upgrade transaction
  /// - `codeMetadata` - Optional code metadata bytes
  /// - `arguments` - Optional upgrade-constructor argument byte parts
  ///
  /// #### Returns
  /// Unsigned [Transaction] ready to be signed by the caller.
  ///
  /// #### Example
  /// ```dart
  /// final tx = controller.createTransactionForUpgrade(
  ///   sender: alice.address,
  ///   nonce: const Nonce(8),
  ///   bytecode: newWasm,
  ///   gasLimit: const GasLimit(60000000),
  /// );
  /// ```
  Transaction createTransactionForUpgrade({
    required Address sender,
    required Nonce nonce,
    required Uint8List bytecode,
    required GasLimit gasLimit,
    Uint8List? codeMetadata,
    List<Uint8List> arguments = const <Uint8List>[],
  }) {
    final SmartContractTransactionsFactory factory =
        SmartContractTransactionsFactory(
          SmartContractTransactionsConfig(chainId: networkProvider.chainId),
        );
    return factory.createTransactionForUpgrade(
      sender: sender,
      contract: contractAddress,
      bytecode: bytecode,
      gasLimit: gasLimit,
      codeMetadata: codeMetadata,
      arguments: arguments,
      nonce: nonce,
    );
  }

  /// Parses a completed deploy transaction into a structured outcome.
  ///
  /// #### Parameters
  /// - `transaction` - Completed [TransactionOnNetwork] from `getTransaction`
  ///
  /// #### Returns
  /// [SmartContractDeployOutcome] with deployed-contract address, owner,
  /// and code hash.
  ///
  /// #### Example
  /// ```dart
  /// final tx = await provider.getTransaction(hash, withProcessStatus: true);
  /// final outcome = controller.parseDeploy(tx);
  /// print(outcome.contracts.first.address.bech32);
  /// ```
  SmartContractDeployOutcome parseDeploy(TransactionOnNetwork transaction) {
    return _outcomeParser.parseDeploy(transaction);
  }

  /// Parses a completed execute transaction into a structured outcome.
  ///
  /// When ABI is available and a `function` is known, decoded typed values
  /// are returned; otherwise raw return-data buffers are returned.
  ///
  /// #### Parameters
  /// - `transaction` - Completed [TransactionOnNetwork] from `getTransaction`
  /// - `function` - Optional endpoint name to drive ABI decoding
  ///
  /// #### Returns
  /// [ParsedSmartContractCallOutcome] containing the return code, message,
  /// and decoded values.
  ///
  /// #### Example
  /// ```dart
  /// final tx = await provider.getTransaction(hash, withProcessStatus: true);
  /// final outcome = controller.parseExecute(transaction: tx, function: 'swap');
  /// ```
  ParsedSmartContractCallOutcome parseExecute({
    required TransactionOnNetwork transaction,
    String? function,
  }) {
    return _outcomeParser.parseExecute(transaction, function: function);
  }

  /// Decodes a raw [SmartContractQueryResponse] into native ABI values.
  ///
  /// Requires ABI: the endpoint's declared output types drive the decoding.
  ///
  /// #### Parameters
  /// - `response` - Raw query response from `networkProvider.queryContract`
  /// - `endpointName` - Endpoint name for output-type lookup
  ///
  /// #### Returns
  /// List of decoded native Dart values matching endpoint outputs.
  ///
  /// #### Throws
  /// - [StateError] if controller has no ABI
  /// - [EndpointNotFoundException] if the endpoint is not in the ABI
  ///
  /// #### Example
  /// ```dart
  /// final raw = await provider.queryContract(query);
  /// final values = controller.parseQueryResponse(
  ///   response: raw,
  ///   endpointName: 'getTotal',
  /// );
  /// ```
  List<dynamic> parseQueryResponse({
    required SmartContractQueryResponse response,
    required String endpointName,
  }) {
    _requireAbiForEndpoints();
    final AbiEndpoint? endpoint = abi.endpoints.getByName(endpointName);
    if (endpoint == null) {
      throw EndpointNotFoundException.withSuggestions(
        endpointName: endpointName,
        abi: abi,
      );
    }
    final ResponseParser parser = ResponseParser(serializer: ArgSerializer());
    final List<TypedValue> typed = parser.parseForEndpoint(
      endpoint: endpoint,
      returnData: response.returnDataParts,
    );
    return typed.map((TypedValue tv) => tv.nativeValue).toList();
  }

  /// Awaits a deploy transaction until completion and returns the parsed outcome.
  ///
  /// #### Parameters
  /// - `txHash` - Transaction hash returned by `sendTransaction`
  ///
  /// #### Returns
  /// [SmartContractDeployOutcome] with deployed-contract metadata.
  ///
  /// #### Example
  /// ```dart
  /// final outcome = await controller.awaitCompletedDeploy(hash);
  /// ```
  Future<SmartContractDeployOutcome> awaitCompletedDeploy(String txHash) async {
    final TransactionOnNetwork tx = await _watcher.awaitCompleted(txHash);
    return parseDeploy(tx);
  }

  /// Awaits an execute transaction until completion and returns the parsed outcome.
  ///
  /// #### Parameters
  /// - `txHash` - Transaction hash returned by `sendTransaction`
  /// - `function` - Optional endpoint name used to drive ABI decoding
  ///
  /// #### Returns
  /// [ParsedSmartContractCallOutcome] with decoded return values.
  ///
  /// #### Example
  /// ```dart
  /// final outcome = await controller.awaitCompletedExecute(
  ///   hash,
  ///   function: 'swap',
  /// );
  /// ```
  Future<ParsedSmartContractCallOutcome> awaitCompletedExecute(
    String txHash, {
    String? function,
  }) async {
    final TransactionOnNetwork tx = await _watcher.awaitCompleted(txHash);
    return parseExecute(transaction: tx, function: function);
  }

  /// Executes a smart contract query and returns parsed results.
  ///
  /// Requires ABI. Use `queryRaw()` for queries without ABI.
  ///
  /// #### Parameters
  /// - `endpointName` - View function name to call
  /// - `arguments` - Function arguments (native Dart values)
  /// - `caller` - Optional caller address for access-controlled views
  /// - `value` - Optional EGLD value (usually zero for queries)
  ///
  /// #### Returns
  /// [QueryResult] containing native values, typed values, and raw data
  ///
  /// #### Throws
  /// - [EndpointNotFoundException] if endpoint not found in ABI
  /// - [SmartContractQueryException] if query execution fails
  /// - [StateError] if controller was created without ABI
  ///
  /// #### Example
  /// ```dart
  /// final result = await controller.query(endpointName: 'getTotal');
  /// final total = result.first as BigInt;
  /// ```
  Future<QueryResult> query({
    required String endpointName,
    List<dynamic> arguments = const <dynamic>[],
    Address? caller,
    Balance? value,
  }) {
    return _queryRunner.query(
      endpointName: endpointName,
      arguments: arguments,
      caller: caller,
      value: value,
    );
  }

  /// Executes a smart contract query without ABI and returns raw results.
  ///
  /// Use this method when you don't have an ABI. Arguments must be
  /// pre-typed as [TypedValue] or [Uint8List] instances.
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
  /// final result = await controller.queryRaw(
  ///   endpointName: 'getBalance',
  ///   arguments: [AddressValue.fromBech32('erd1user...')],
  /// );
  ///
  /// // Decode raw bytes manually
  /// final balanceBytes = result.returnDataParts[0];
  /// ```
  Future<RawQueryResult> queryRaw({
    required String endpointName,
    List<dynamic> arguments = const <dynamic>[],
    Address? caller,
    Balance? value,
  }) {
    return _queryRunner.queryRaw(
      endpointName: endpointName,
      arguments: arguments,
      caller: caller,
      value: value,
    );
  }

  /// Creates and signs a smart contract call transaction.
  ///
  /// Builds the transaction, applies guardian/relayer if specified,
  /// and signs with the provided account. Supports both EGLD-only calls
  /// and calls with ESDT/NFT token transfers.
  ///
  /// #### Parameters
  /// - `account` - Account to sign the transaction
  /// - `nonce` - Transaction nonce (you must manage this)
  /// - `endpointName` - Function name to call
  /// - `arguments` - Function arguments (native Dart values)
  /// - `options` - Gas limit, guardian, and relayer options
  /// - `tokenTransfers` - Optional token payments to include
  /// - `value` - Optional EGLD value to send
  ///
  /// #### Returns
  /// `Transaction` - Signed transaction ready for broadcast
  ///
  /// #### Throws
  /// - `EndpointNotFoundException` - If endpoint not found
  /// - `ArgumentError` - If endpoint is view-only
  /// - `ArgumentEncodingException` - If arguments don't match
  ///
  /// #### Example
  /// ```dart
  /// // Simple call
  /// final tx = await controller.call(
  ///   account: myAccount,
  ///   nonce: Nonce(42),
  ///   endpointName: 'deposit',
  ///   arguments: [BigInt.from(1000)],
  ///   options: BaseControllerInput(gasLimit: GasLimit(10000000)),
  /// );
  ///
  /// // Call with token transfer
  /// final txWithTokens = await controller.call(
  ///   account: myAccount,
  ///   nonce: Nonce(43),
  ///   endpointName: 'stake',
  ///   tokenTransfers: [
  ///     TokenTransferValue.fromPrimitives(
  ///       tokenIdentifier: 'STAKE-abc123',
  ///       amount: BigInt.from(1000000),
  ///     ),
  ///   ],
  ///   options: BaseControllerInput(gasLimit: GasLimit(15000000)),
  /// );
  /// ```
  Future<Transaction> call({
    required IAccount account,
    required Nonce nonce,
    required String endpointName,
    List<dynamic> arguments = const <dynamic>[],
    required BaseControllerInput options,
    List<TokenTransferValue> tokenTransfers = const <TokenTransferValue>[],
    Balance? value,
  }) async {
    if (options.gasLimit == null) {
      throw ArgumentError(
        'gasLimit is required in BaseControllerInput for smart contract calls.',
      );
    }

    logger?.info(
      'Creating signed smart contract call',
      context: <String, dynamic>{
        'contract': contractAddress.bech32,
        'endpoint': endpointName,
        'sender': account.address.bech32,
        'nonce': nonce.value,
        'gasLimit': options.gasLimit!.value,
        'hasGuardian': (options.guardian != null).toString(),
        'hasRelayer': (options.relayer != null).toString(),
        'tokenTransfersCount': tokenTransfers.length,
      },
    );

    final tx = _factory.createCall(
      sender: account.address,
      nonce: nonce,
      endpointName: endpointName,
      arguments: arguments,
      tokenTransfers: tokenTransfers,
      gasLimit: options.gasLimit!,
      value: value,
    );

    return setupAndSignTransaction(tx, options, nonce, account);
  }

  /// Creates and signs a smart contract call transaction without ABI.
  ///
  /// Use this method when you don't have an ABI. Arguments must be
  /// pre-typed as [TypedValue] or [Uint8List] instances.
  ///
  /// #### Parameters
  /// - `account` - Account to sign the transaction
  /// - `nonce` - Transaction nonce (you must manage this)
  /// - `endpointName` - Function name to call
  /// - `arguments` - Pre-typed arguments ([TypedValue] or [Uint8List])
  /// - `options` - Gas limit, guardian, and relayer options
  /// - `tokenTransfers` - Optional token payments to include
  /// - `value` - Optional EGLD value to send
  ///
  /// #### Returns
  /// [Transaction] - Signed transaction ready for broadcast
  ///
  /// #### Throws
  /// - [ArgumentError] if gasLimit not provided or arguments invalid
  ///
  /// #### Example
  /// ```dart
  /// final tx = await controller.callRaw(
  ///   account: myAccount,
  ///   nonce: Nonce(42),
  ///   endpointName: 'swap',
  ///   arguments: [
  ///     TokenIdentifierValue('WEGLD-abc123'),
  ///     BigUIntValue(BigInt.from(1000000000000000000)),
  ///   ],
  ///   options: BaseControllerInput(gasLimit: GasLimit(15000000)),
  /// );
  /// ```
  Future<Transaction> callRaw({
    required IAccount account,
    required Nonce nonce,
    required String endpointName,
    List<dynamic> arguments = const <dynamic>[],
    required BaseControllerInput options,
    List<TokenTransferValue> tokenTransfers = const <TokenTransferValue>[],
    Balance? value,
  }) async {
    if (options.gasLimit == null) {
      throw ArgumentError(
        'gasLimit is required in BaseControllerInput for smart contract calls.',
      );
    }

    logger?.info(
      'Creating raw signed smart contract call',
      context: <String, dynamic>{
        'contract': contractAddress.bech32,
        'endpoint': endpointName,
        'sender': account.address.bech32,
        'nonce': nonce.value,
        'gasLimit': options.gasLimit!.value,
        'hasAbi': hasAbi.toString(),
      },
    );

    final tx = _factory.createCall(
      sender: account.address,
      nonce: nonce,
      endpointName: endpointName,
      arguments: arguments,
      tokenTransfers: tokenTransfers,
      gasLimit: options.gasLimit!,
      value: value,
    );

    return setupAndSignTransaction(tx, options, nonce, account);
  }

  /// Fetches and parses events from a specific transaction.
  ///
  /// Requires ABI for event parsing.
  ///
  /// #### Parameters
  /// - `txHash` - Transaction hash to query events from
  /// - `eventIdentifier` - Event name to parse
  ///
  /// #### Returns
  /// `List<ParsedEvent>` - Parsed events with decoded values
  ///
  /// #### Throws
  /// - [NetworkException] if API request fails
  /// - [EventParsingException] if event parsing fails
  /// - [StateError] if controller was created without ABI
  ///
  /// #### Example
  /// ```dart
  /// final events = await controller.queryEvents(
  ///   txHash: 'abc123...',
  ///   eventIdentifier: 'transfer',
  /// );
  ///
  /// for (final event in events) {
  ///   final from = event.getValueByName('from');
  ///   final to = event.getValueByName('to');
  ///   final amount = event.getValueByName('amount');
  ///   print('Transfer: $from -> $to: $amount');
  /// }
  /// ```
  Future<List<ParsedEvent>> queryEvents({
    required String txHash,
    required String eventIdentifier,
  }) {
    _requireAbiForEvents();
    return _eventRunner!.queryEvents(
      txHash: txHash,
      eventIdentifier: eventIdentifier,
    );
  }

  /// Fetches and parses events from multiple transactions in batch.
  ///
  /// Requires ABI for event parsing.
  ///
  /// #### Parameters
  /// - `txHashes` - List of transaction hashes to query
  /// - `eventIdentifier` - Event name to parse
  ///
  /// #### Returns
  /// `Map<String, List<ParsedEvent>>` - Map of txHash → events
  ///
  /// #### Throws
  /// - [NetworkException] if API request fails
  /// - [StateError] if controller was created without ABI
  ///
  /// #### Example
  /// ```dart
  /// final batchEvents = await controller.queryEventsBatch(
  ///   txHashes: ['abc123...', 'def456...', 'ghi789...'],
  ///   eventIdentifier: 'transfer',
  /// );
  ///
  /// for (final entry in batchEvents.entries) {
  ///   print('Transaction ${entry.key}: ${entry.value.length} events');
  /// }
  /// ```
  Future<Map<String, List<ParsedEvent>>> queryEventsBatch({
    required List<String> txHashes,
    required String eventIdentifier,
  }) {
    _requireAbiForEvents();
    return _eventRunner!.queryEventsBatch(
      txHashes: txHashes,
      eventIdentifier: eventIdentifier,
    );
  }

  /// Fetches recent events from the contract's transaction history.
  ///
  /// Requires ABI for event parsing.
  ///
  /// #### Parameters
  /// - `eventIdentifier` - Event name to fetch
  /// - `limit` - Maximum number of events to return (default: 25)
  ///
  /// #### Returns
  /// `List<ParsedEvent>` - Recent parsed events
  ///
  /// #### Throws
  /// - [NetworkException] if API request fails
  /// - [StateError] if controller was created without ABI
  ///
  /// #### Example
  /// ```dart
  /// final recentDeposits = await controller.getEventHistory(
  ///   eventIdentifier: 'deposit',
  ///   limit: 50,
  /// );
  ///
  /// for (final deposit in recentDeposits) {
  ///   print('Deposit: ${deposit.getValueByName('amount')}');
  /// }
  /// ```
  Future<List<ParsedEvent>> getEventHistory({
    required String eventIdentifier,
    int limit = 25,
  }) {
    _requireAbiForEvents();
    return _eventRunner!.getEventHistory(
      eventIdentifier: eventIdentifier,
      limit: limit,
    );
  }

  /// Watches a transaction until completion and returns parsed events.
  ///
  /// Requires ABI for event parsing.
  ///
  /// #### Parameters
  /// - `txHash` - Transaction hash to monitor
  /// - `eventIdentifier` - Event name to parse
  /// - `timeout` - Maximum time to wait (default: 1 minute)
  /// - `pollingInterval` - How often to check status (default: 1 second)
  ///
  /// #### Returns
  /// `List<ParsedEvent>` - Parsed events once transaction completes
  ///
  /// #### Throws
  /// - [TimeoutException] if transaction doesn't complete in time
  /// - [StateError] if controller was created without ABI
  ///
  /// #### Example
  /// ```dart
  /// // Send transaction and watch for events
  /// final txHash = await provider.sendTransaction(signedTx);
  ///
  /// final events = await controller.watchTransaction(
  ///   txHash: txHash,
  ///   eventIdentifier: 'deposit',
  ///   timeout: Duration(minutes: 2),
  /// );
  ///
  /// print('Deposit completed! Events: ${events.length}');
  /// ```
  Future<List<ParsedEvent>> watchTransaction({
    required String txHash,
    required String eventIdentifier,
    Duration timeout = const Duration(minutes: 1),
    Duration pollingInterval = const Duration(seconds: 1),
  }) {
    _requireAbiForEvents();
    return _eventRunner!.watchTransaction(
      txHash: txHash,
      eventIdentifier: eventIdentifier,
      timeout: timeout,
      pollingInterval: pollingInterval,
    );
  }

  /// Creates a real-time stream of events by polling the contract.
  ///
  /// Requires ABI for event parsing.
  ///
  /// #### Parameters
  /// - `eventIdentifier` - Event name to watch for
  /// - `pollingInterval` - How often to check for new events (default: 2 seconds)
  /// - `startFrom` - Optional transaction hash to start from (for resuming)
  ///
  /// #### Returns
  /// `Stream<ParsedEvent>` that emits events as they occur
  ///
  /// #### Throws
  /// - [StateError] if controller was created without ABI
  ///
  /// #### Example
  /// ```dart
  /// // Subscribe to deposit events
  /// final subscription = controller.streamEvents(
  ///   eventIdentifier: 'deposit',
  /// ).listen(
  ///   (event) {
  ///     final amount = event.getValueByName('amount');
  ///     print('New deposit: $amount');
  ///   },
  ///   onError: (error) => print('Stream error: $error'),
  /// );
  ///
  /// // Later...
  /// await subscription.cancel();
  /// ```
  Stream<ParsedEvent> streamEvents({
    required String eventIdentifier,
    Duration pollingInterval = const Duration(seconds: 2),
    String? startFrom,
  }) {
    _requireAbiForEvents();
    return _eventRunner!.streamEvents(
      eventIdentifier: eventIdentifier,
      pollingInterval: pollingInterval,
      startFrom: startFrom,
    );
  }

  /// Creates a real-time stream of ALL events by polling the contract.
  ///
  /// Streams events for all event types defined in the ABI.
  /// Requires ABI for event parsing.
  ///
  /// #### Parameters
  /// - `pollingInterval` - How often to check for new events (default: 2 seconds)
  /// - `startFrom` - Optional transaction hash to start from (for resuming)
  ///
  /// #### Returns
  /// `Stream<ParsedEvent>` that emits events for ALL event types
  ///
  /// #### Throws
  /// - [StateError] if controller was created without ABI
  ///
  /// #### Example
  /// ```dart
  /// // Subscribe to all events
  /// final subscription = controller.streamAllEvents().listen(
  ///   (event) {
  ///     print('Event: ${event.definition.identifier}');
  ///     if (event.definition.identifier == 'swap') {
  ///       // Handle swap
  ///     } else if (event.definition.identifier == 'addLiquidity') {
  ///       // Handle add liquidity
  ///     }
  ///   },
  /// );
  /// ```
  Stream<ParsedEvent> streamAllEvents({
    Duration pollingInterval = const Duration(seconds: 2),
    String? startFrom,
  }) {
    _requireAbiForEvents();
    return _eventRunner!.streamAllEvents(
      pollingInterval: pollingInterval,
      startFrom: startFrom,
    );
  }

  /// Gets all event definitions from the ABI.
  ///
  /// Requires ABI for event definitions.
  ///
  /// #### Returns
  /// List of `EventDefinition` objects for all events in the ABI
  ///
  /// #### Throws
  /// - [StateError] if controller was created without ABI
  List<EventDefinition> getAllEventDefinitions() {
    _requireAbiForEvents();
    return _eventRunner!.getAllEventDefinitions();
  }

  /// Gets a specific event definition by identifier.
  ///
  /// Requires ABI for event definitions.
  ///
  /// #### Parameters
  /// - `eventIdentifier` - Event name to look up
  ///
  /// #### Returns
  /// `EventDefinition` if found, `null` otherwise
  ///
  /// #### Throws
  /// - [StateError] if controller was created without ABI
  EventDefinition? getEventDefinition(String eventIdentifier) {
    _requireAbiForEvents();
    return _eventRunner!.getEventDefinition(eventIdentifier);
  }

  /// Checks if an event exists in the ABI.
  ///
  /// Requires ABI for event definitions.
  ///
  /// #### Parameters
  /// - `eventIdentifier` - Event name to check
  ///
  /// #### Returns
  /// `true` if event exists in ABI, `false` otherwise
  ///
  /// #### Throws
  /// - [StateError] if controller was created without ABI
  bool hasEvent(String eventIdentifier) {
    _requireAbiForEvents();
    return _eventRunner!.hasEvent(eventIdentifier);
  }

  /// Checks if an endpoint exists in the ABI.
  ///
  /// Requires ABI for endpoint definitions.
  ///
  /// #### Parameters
  /// - `endpointName` - Name of the endpoint to check
  ///
  /// #### Returns
  /// `true` if endpoint exists, `false` otherwise
  ///
  /// #### Throws
  /// - [StateError] if controller was created without ABI
  bool hasEndpoint(String endpointName) {
    _requireAbiForEndpoints();
    return _factory.hasEndpoint(endpointName);
  }

  /// Gets an endpoint definition from the ABI.
  ///
  /// Requires ABI for endpoint definitions.
  ///
  /// #### Parameters
  /// - `endpointName` - Name of the endpoint
  ///
  /// #### Returns
  /// `AbiEndpoint` definition
  ///
  /// #### Throws
  /// - [EndpointNotFoundException] if endpoint not found
  /// - [StateError] if controller was created without ABI
  AbiEndpoint getEndpoint(String endpointName) {
    _requireAbiForEndpoints();
    return _factory.getEndpoint(endpointName);
  }

  /// Gets all view endpoints from the ABI.
  ///
  /// Requires ABI for endpoint definitions.
  ///
  /// #### Returns
  /// List of view `AbiEndpoint` definitions that can be queried
  ///
  /// #### Throws
  /// - [StateError] if controller was created without ABI
  List<AbiEndpoint> getViewEndpoints() {
    _requireAbiForEndpoints();
    return _queryRunner.getViewEndpoints();
  }

  /// Gets all mutable (non-view) endpoints from the ABI.
  ///
  /// Requires ABI for endpoint definitions.
  ///
  /// #### Returns
  /// List of mutable `AbiEndpoint` definitions that require transactions
  ///
  /// #### Throws
  /// - [StateError] if controller was created without ABI
  List<AbiEndpoint> getMutableEndpoints() {
    _requireAbiForEndpoints();
    return _factory.getMutableEndpoints();
  }

  /// Throws [StateError] if ABI is required for event operations but not available.
  void _requireAbiForEvents() {
    if (_eventRunner == null) {
      throw StateError(
        'Event operations require an ABI. '
        'Use SmartContractController() constructor with an ABI, '
        'or use callRaw()/queryRaw() for ABI-less operations.',
      );
    }
  }

  /// Throws [StateError] if ABI is required for endpoint introspection but not available.
  void _requireAbiForEndpoints() {
    if (_abi == null) {
      throw StateError(
        'Endpoint introspection requires an ABI. '
        'Use SmartContractController() constructor with an ABI, '
        'or use callRaw()/queryRaw() for ABI-less operations.',
      );
    }
  }
}
