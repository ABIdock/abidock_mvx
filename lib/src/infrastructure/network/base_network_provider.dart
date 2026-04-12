import 'dart:io';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../../abi/smart_contract/query/query.dart';
import '../../core/account/account_on_network.dart';
import '../../core/address.dart';
import '../../core/token_on_network.dart';
import '../../core/transaction/chain_id.dart';
import '../../core/transaction/transaction.dart';
import '../../core/transaction/transaction_on_network.dart';
import '../../core/transaction/transaction_status.dart';
import '../../utils/helpers.dart';
import '../../utils/hex_utils.dart';
import '../../utils/sdk_exceptions.dart';
import '../logging/logger.dart';
import '../resilience/circuit_breaker.dart';
import '../resilience/circuit_breaker_exception.dart';
import 'account_storage.dart';
import 'account_storage_entry.dart';
import 'block_on_network.dart';
import 'network_config.dart';
import 'network_provider.dart';
import 'network_status.dart';
import 'send_transactions_result.dart';

/// Base class for MultiversX network providers.
///
/// Provides shared implementation for API and Gateway providers including
/// HTTP client management, circuit breaker, logging, and common operations.
abstract class BaseNetworkProvider implements NetworkProvider {
  /// Creates a base network provider.
  ///
  /// #### Parameters
  /// - `baseUrl` - Base URL of the network endpoint
  /// - `chainId` - Network chain ID (mainnet, devnet, testnet)
  /// - `client` - Optional custom Dio HTTP client
  /// - `logger` - Optional logger for debugging
  /// - `enableCircuitBreaker` - Enable circuit breaker for resilience
  BaseNetworkProvider({
    required String baseUrl,
    required ChainId chainId,
    Dio? client,
    this.logger,
    this.enableCircuitBreaker = false,
  }) : _baseUrl = baseUrl,
       _chainId = chainId,
       _dio = client ?? Dio() {
    if (enableCircuitBreaker) {
      _circuitBreaker = CircuitBreaker(
        failureThreshold: 5,
        timeout: defaultTimeout,
        retryDelay: const Duration(minutes: 1),
        onOpen: () => logger?.warning(
          '$providerName circuit breaker opened - too many failures',
          context: <String, dynamic>{'baseUrl': baseUrl},
        ),
        onClose: () => logger?.info(
          '$providerName circuit breaker closed - service recovered',
          context: <String, dynamic>{'baseUrl': baseUrl},
        ),
        onHalfOpen: () => logger?.info(
          '$providerName circuit breaker testing recovery',
          context: <String, dynamic>{'baseUrl': baseUrl},
        ),
      );
    } else {
      _circuitBreaker = null;
    }

    logger?.info(
      '$providerName initialized',
      context: <String, dynamic>{
        'baseUrl': baseUrl,
        'chainId': chainId.value,
        'circuitBreaker': enableCircuitBreaker.toString(),
      },
    );
  }

  @override
  String get baseUrl => _baseUrl;
  final String _baseUrl;

  @override
  ChainId get chainId => _chainId;
  final ChainId _chainId;

  /// HTTP client for requests.
  @protected
  Dio get dio => _dio;
  final Dio _dio;

  /// Logger for debugging and monitoring.
  final Logger? logger;

  /// Enable circuit breaker for resilient calls.
  final bool enableCircuitBreaker;

  /// Circuit breaker for resilient calls (if enabled).
  late final CircuitBreaker? _circuitBreaker;

  /// Default timeout for requests.
  @protected
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// Provider name for logging (e.g., 'API', 'Gateway').
  @protected
  String get providerName;

  /// Error prefix for exception messages (e.g., 'API Error', 'Gateway error').
  @protected
  String get errorPrefix;

  /// Endpoint for account data.
  @protected
  String accountEndpoint(Address address);

  /// Endpoint for account storage keys.
  @protected
  String accountStorageEndpoint(Address address);

  /// Endpoint for specific account storage key.
  @protected
  String accountStorageKeyEndpoint(Address address, String keyHex);

  /// Endpoint for sending single transaction.
  @protected
  String sendTransactionEndpoint();

  /// Endpoint for sending multiple transactions.
  @protected
  String sendMultipleTransactionsEndpoint();

  /// Endpoint for getting transaction by hash.
  @protected
  String getTransactionEndpoint(String txHash, {bool withProcessStatus});

  /// Endpoint for transaction status.
  @protected
  String getTransactionStatusEndpoint(String txHash);

  /// Endpoint for simulating transaction.
  @protected
  String simulateTransactionEndpoint();

  /// Endpoint for token balance of account.
  @protected
  String tokenOfAccountEndpoint(Address address, String tokenIdentifier);

  /// Endpoint for all fungible tokens of account.
  @protected
  String fungibleTokensEndpoint(Address address);

  /// Endpoint for all NFTs of account.
  @protected
  String nonFungibleTokensEndpoint(Address address);

  /// Endpoint for fungible-token metadata lookup.
  @protected
  String fungibleTokenDefinitionEndpoint(String identifier);

  /// Endpoint for collection (NFT/SFT/MetaESDT) metadata lookup.
  @protected
  String tokenCollectionDefinitionEndpoint(String collection);

  /// Endpoint for a single NFT / SFT / MetaESDT instance by `collection-nonceHex`.
  @protected
  String nonFungibleInstanceEndpoint(String collection, int nonce);

  /// Endpoint for fetching a block by hash.
  @protected
  String blockByHashEndpoint(String hash);

  /// Endpoint for fetching the latest block for a shard.
  @protected
  String latestBlockEndpoint(int shard);

  /// Endpoint for fetching a hyperblock by nonce.
  @protected
  String hyperblockByNonceEndpoint(int nonce);

  /// Parses NetworkConfig from response.
  @protected
  NetworkConfig parseNetworkConfig(Map<String, dynamic> response);

  /// Parses NetworkStatus from response.
  @protected
  NetworkStatus parseNetworkStatus(Map<String, dynamic> response);

  /// Parses AccountOnNetwork from response.
  @protected
  AccountOnNetwork parseAccount(Map<String, dynamic> response);

  /// Parses transaction hash from send response.
  @protected
  String parseSendTransactionHash(dynamic response);

  /// Parses send multiple transactions result.
  @protected
  SendTransactionsResult parseSendMultipleResult(dynamic response, int txCount);

  /// Parses TransactionOnNetwork from response.
  @protected
  TransactionOnNetwork parseTransaction(dynamic response, String txHash);

  /// Parses simulation result.
  @protected
  TransactionOnNetwork parseSimulationResult(dynamic response);

  /// Parses transaction cost estimation.
  @protected
  Map<String, dynamic> parseTransactionCost(dynamic response);

  /// Parses query response data from raw response.
  @protected
  Map<String, dynamic> parseQueryResponseData(Map<String, dynamic> response);

  /// Parses fungible tokens list from response.
  @protected
  List<TokenOnNetwork> parseFungibleTokens(dynamic response);

  /// Parses NFT list from response.
  @protected
  List<TokenOnNetwork> parseNonFungibleTokens(dynamic response);

  /// Parses single token from response.
  @protected
  TokenOnNetwork parseTokenOfAccount(dynamic response, String tokenIdentifier);

  /// Parses a fungible-token definition payload.
  @protected
  TokenOnNetwork parseFungibleTokenDefinition(
    dynamic response,
    String identifier,
  );

  /// Parses a collection definition payload.
  @protected
  TokenOnNetwork parseTokenCollectionDefinition(
    dynamic response,
    String collection,
  );

  /// Parses a single NFT instance payload.
  @protected
  TokenOnNetwork parseNonFungibleInstance(
    dynamic response,
    String collection,
    int nonce,
  );

  /// Parses a block payload.
  @protected
  BlockOnNetwork parseBlock(dynamic response);

  /// Parses a hyperblock payload.
  @protected
  HyperblockOnNetwork parseHyperblock(dynamic response);

  /// Extracts data from generic GET response.
  @protected
  dynamic extractGetResponseData(Map<String, dynamic> response);

  /// Extracts data from generic POST response.
  @protected
  dynamic extractPostResponseData(Map<String, dynamic> response);

  /// Parses error from response data.
  @protected
  String? parseErrorFromResponse(Map<String, dynamic> response);

  /// Parses error from DioException response.
  @protected
  String parseErrorFromDioException(DioException e, String url);

  @override
  Future<NetworkConfig> getNetworkConfig() async {
    logger?.debug('Fetching network configuration');

    final response = await executeWithCircuitBreaker(
      () => doGetGeneric('network/config'),
    );

    return parseNetworkConfig(
      requireAs<Map<String, dynamic>>(response, 'response'),
    );
  }

  @override
  Future<NetworkStatus> getNetworkStatus() async {
    logger?.debug('Fetching network status');

    final response = await executeWithCircuitBreaker(
      () => doGetGeneric('network/status/4294967295'),
    );

    return parseNetworkStatus(
      requireAs<Map<String, dynamic>>(response, 'response'),
    );
  }

  @override
  Future<AccountOnNetwork> getAccount(Address address) async {
    logger?.debug(
      'Fetching account',
      context: <String, dynamic>{'address': address.bech32},
    );

    final response = await executeWithCircuitBreaker(
      () => doGetGeneric(accountEndpoint(address)),
    );

    return parseAccount(requireAs<Map<String, dynamic>>(response, 'response'));
  }

  @override
  Future<AccountStorage> getAccountStorage(Address address) async {
    logger?.debug(
      'Fetching account storage',
      context: <String, dynamic>{'address': address.bech32},
    );

    final response = await executeWithCircuitBreaker(
      () => doGetGeneric(accountStorageEndpoint(address)),
    );

    return AccountStorage.fromHttpResponse(
      requireAs<Map<String, dynamic>>(response, 'response'),
    );
  }

  @override
  Future<AccountStorageEntry> getAccountStorageEntry(
    Address address,
    String key,
  ) async {
    logger?.debug(
      'Fetching account storage entry',
      context: <String, dynamic>{'address': address.bech32, 'key': key},
    );

    final String keyHex = HexUtils.stringToHex(key);

    final response = await executeWithCircuitBreaker(
      () => doGetGeneric(accountStorageKeyEndpoint(address, keyHex)),
    );

    return AccountStorageEntry.fromHttpResponse(
      requireAs<Map<String, dynamic>>(response, 'response'),
      key,
    );
  }

  @override
  Future<String> sendTransaction(Transaction tx) async {
    logger?.info(
      'Sending transaction',
      context: <String, dynamic>{
        'sender': tx.sender.bech32,
        'receiver': tx.receiver.bech32,
        'value': tx.value.toString(),
        'nonce': tx.nonce.value.toString(),
      },
    );

    final response = await executeWithCircuitBreaker(
      () => doPostGeneric(sendTransactionEndpoint(), tx.toJson()),
    );

    final String txHash = parseSendTransactionHash(response);

    logger?.info(
      'Transaction sent successfully',
      context: <String, dynamic>{'txHash': txHash},
    );

    return txHash;
  }

  @override
  Future<SendTransactionsResult> sendTransactions(List<Transaction> txs) async {
    logger?.info(
      'Sending multiple transactions',
      context: <String, dynamic>{'count': txs.length},
    );

    final List<Map<String, dynamic>> data = txs
        .map((Transaction tx) => tx.toJson())
        .toList();

    final response = await executeWithCircuitBreaker(
      () => doPostGeneric(sendMultipleTransactionsEndpoint(), data),
    );

    final result = parseSendMultipleResult(response, txs.length);

    logger?.info(
      'Transactions sent',
      context: <String, dynamic>{'sent': result.numSent, 'total': txs.length},
    );

    return result;
  }

  @override
  Future<TransactionOnNetwork> getTransaction(
    String txHash, {
    bool withProcessStatus = false,
  }) async {
    logger?.debug(
      'Fetching transaction',
      context: <String, dynamic>{
        'txHash': txHash,
        'withProcessStatus': withProcessStatus.toString(),
      },
    );

    final response = await executeWithCircuitBreaker(
      () => doGetGeneric(
        getTransactionEndpoint(txHash, withProcessStatus: withProcessStatus),
      ),
    );

    return parseTransaction(response, txHash);
  }

  @override
  Future<TransactionStatus> getTransactionStatus(String txHash) async {
    logger?.debug(
      'Fetching transaction status',
      context: <String, dynamic>{'txHash': txHash},
    );

    final response = await executeWithCircuitBreaker(
      () => doGetGeneric(getTransactionStatusEndpoint(txHash)),
    );

    return TransactionStatus.fromHttpResponse(
      requireAs<Map<String, dynamic>>(response, 'response'),
    );
  }

  @override
  Future<TransactionOnNetwork> simulateTransaction(Transaction tx) async {
    logger?.info(
      'Simulating transaction',
      context: <String, dynamic>{
        'sender': tx.sender.bech32,
        'receiver': tx.receiver.bech32,
      },
    );

    final response = await executeWithCircuitBreaker(
      () => doPostGeneric(simulateTransactionEndpoint(), tx.toJson()),
    );

    return parseSimulationResult(response);
  }

  @override
  Future<Map<String, dynamic>> estimateTransactionCost(Transaction tx) async {
    logger?.info(
      'Estimating transaction cost',
      context: <String, dynamic>{
        'sender': tx.sender.bech32,
        'receiver': tx.receiver.bech32,
      },
    );

    final Map<String, dynamic> txData = tx.toJson();
    txData['gasLimit'] = 0;
    if (tx.signature.hex.isEmpty) {
      txData['signature'] = '00' * 64;
    }
    if (tx.guardian != null && tx.guardianSignature.hex.isEmpty) {
      txData['guardianSignature'] = '00' * 64;
    }

    logger?.debug(
      'Transaction cost estimation request',
      context: <String, dynamic>{'txData': txData},
    );

    final response = await executeWithCircuitBreaker(
      () => doPostGeneric('transaction/cost', txData),
    );

    logger?.debug(
      'Transaction cost estimation response',
      context: <String, dynamic>{'response': response},
    );

    final result = parseTransactionCost(response);

    if (result['returnMessage'] != null &&
        (requireAs<String>(
          result['returnMessage'],
          'returnMessage',
        )).isNotEmpty) {
      logger?.warning(
        'Transaction cost estimation returned message',
        context: <String, dynamic>{'message': result['returnMessage']},
      );
    }

    return result;
  }

  @override
  Future<SmartContractQueryResponse> queryContract(
    SmartContractQuery query,
  ) async {
    logger?.info(
      'Executing smart contract query',
      context: <String, dynamic>{
        'contract': query.contract.bech32,
        'function': query.function.name,
        'argumentsCount': query.arguments.length,
      },
    );

    final DateTime startTime = DateTime.now();

    try {
      final Map<String, dynamic> requestBody = query.toMap();

      logger?.debug('Query request body', context: requestBody);

      final Response<dynamic> response = await dio
          .post<dynamic>(
            '$baseUrl/vm-values/query',
            data: requestBody,
            options: Options(
              headers: <String, dynamic>{
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ),
          )
          .timeout(defaultTimeout);

      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.created) {
        logger?.warning(
          'Query HTTP request failed',
          context: <String, dynamic>{
            'statusCode': response.statusCode,
            'function': query.function.name,
          },
        );
        throw NetworkException(
          'HTTP ${response.statusCode}: ${response.statusMessage}',
          statusCode: response.statusCode,
        );
      }

      final Map<String, dynamic> responseData = requireAs<Map<String, dynamic>>(
        response.data,
        'response.data',
      );

      final String? error = parseErrorFromResponse(responseData);
      if (error != null && error.isNotEmpty) {
        logger?.error(
          '$providerName error in query',
          context: <String, dynamic>{
            'function': query.function.name,
            'error': error,
          },
        );
        throw NetworkException('$errorPrefix: $error');
      }

      final Map<String, dynamic> data = parseQueryResponseData(responseData);

      logger?.debug('Raw response data', context: data);

      final SmartContractQueryResponse queryResponse =
          SmartContractQueryResponse.fromHttpResponse(data, query.function);

      if (queryResponse.isFailure) {
        logger?.warning(
          'Smart contract query failed',
          context: <String, dynamic>{
            'function': query.function.name,
            'returnCode': queryResponse.returnCode,
            'returnMessage': queryResponse.returnMessage,
          },
        );
        throw NetworkException(
          'Query failed: ${queryResponse.returnMessage} (${queryResponse.returnCode})',
        );
      }

      final Duration duration = DateTime.now().difference(startTime);
      logger?.debug(
        'Query executed successfully',
        context: <String, dynamic>{
          'function': query.function.name,
          'latencyMs': duration.inMilliseconds,
          'returnDataCount': queryResponse.returnDataParts.length,
        },
      );

      return queryResponse;
    } catch (e) {
      logger?.error(
        'Query execution failed',
        error: e,
        context: <String, dynamic>{'function': query.function.name},
      );
      rethrow;
    }
  }

  @override
  Future<TokenOnNetwork> getTokenOfAccount(
    Address address,
    String tokenIdentifier,
  ) async {
    logger?.debug(
      'Fetching token balance',
      context: <String, dynamic>{
        'address': address.bech32,
        'token': tokenIdentifier,
      },
    );

    try {
      final response = await executeWithCircuitBreaker(
        () => doGetGeneric(tokenOfAccountEndpoint(address, tokenIdentifier)),
      );

      return parseTokenOfAccount(response, tokenIdentifier);
    } on Exception catch (e) {
      if (e.toString().contains('404') ||
          e.toString().contains('Token for given account not found') ||
          e.toString().contains('account not found')) {
        logger?.debug(
          'Token not found for account, returning zero balance',
          context: <String, dynamic>{
            'address': address.bech32,
            'token': tokenIdentifier,
          },
        );

        return TokenOnNetwork(
          identifier: tokenIdentifier,
          balance: '0',
          nonce: 0,
          raw: <String, dynamic>{
            'identifier': tokenIdentifier,
            'balance': '0',
            'nonce': 0,
          },
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<TokenOnNetwork>> getFungibleTokensOfAccount(
    Address address,
  ) async {
    logger?.debug(
      'Fetching fungible tokens',
      context: <String, dynamic>{'address': address.bech32},
    );

    final response = await executeWithCircuitBreaker(
      () => doGetGeneric(fungibleTokensEndpoint(address)),
    );

    return parseFungibleTokens(response);
  }

  @override
  Future<List<TokenOnNetwork>> getNonFungibleTokensOfAccount(
    Address address,
  ) async {
    logger?.debug(
      'Fetching NFTs',
      context: <String, dynamic>{'address': address.bech32},
    );

    final response = await executeWithCircuitBreaker(
      () => doGetGeneric(nonFungibleTokensEndpoint(address)),
    );

    return parseNonFungibleTokens(response);
  }

  @override
  Future<TokenOnNetwork> getDefinitionOfFungibleToken(String identifier) async {
    logger?.debug(
      'Fetching fungible token definition',
      context: <String, dynamic>{'identifier': identifier},
    );

    final response = await executeWithCircuitBreaker(
      () => doGetGeneric(fungibleTokenDefinitionEndpoint(identifier)),
    );

    return parseFungibleTokenDefinition(response, identifier);
  }

  @override
  Future<TokenOnNetwork> getDefinitionOfTokenCollection(
    String collection,
  ) async {
    logger?.debug(
      'Fetching token collection definition',
      context: <String, dynamic>{'collection': collection},
    );

    final response = await executeWithCircuitBreaker(
      () => doGetGeneric(tokenCollectionDefinitionEndpoint(collection)),
    );

    return parseTokenCollectionDefinition(response, collection);
  }

  @override
  Future<TokenOnNetwork> getNonFungibleToken(
    String collection,
    int nonce,
  ) async {
    if (nonce <= 0) {
      throw ArgumentError.value(
        nonce,
        'nonce',
        'NFT/SFT/MetaESDT nonce must be positive',
      );
    }

    logger?.debug(
      'Fetching NFT instance',
      context: <String, dynamic>{
        'collection': collection,
        'nonce': nonce.toString(),
      },
    );

    final response = await executeWithCircuitBreaker(
      () => doGetGeneric(nonFungibleInstanceEndpoint(collection, nonce)),
    );

    return parseNonFungibleInstance(response, collection, nonce);
  }

  @override
  Future<BlockOnNetwork> getBlock(String hash) async {
    logger?.debug('Fetching block', context: <String, dynamic>{'hash': hash});

    final response = await executeWithCircuitBreaker(
      () => doGetGeneric(blockByHashEndpoint(hash)),
    );

    return parseBlock(response);
  }

  @override
  Future<BlockOnNetwork> getLatestBlock({int shard = 4294967295}) async {
    logger?.debug(
      'Fetching latest block',
      context: <String, dynamic>{'shard': shard.toString()},
    );

    final response = await executeWithCircuitBreaker(
      () => doGetGeneric(latestBlockEndpoint(shard)),
    );

    return parseBlock(response);
  }

  @override
  Future<HyperblockOnNetwork> getHyperblock(int nonce) async {
    if (nonce < 0) {
      throw ArgumentError.value(
        nonce,
        'nonce',
        'Hyperblock nonce must be >= 0',
      );
    }

    logger?.debug(
      'Fetching hyperblock',
      context: <String, dynamic>{'nonce': nonce.toString()},
    );

    final response = await executeWithCircuitBreaker(
      () => doGetGeneric(hyperblockByNonceEndpoint(nonce)),
    );

    return parseHyperblock(response);
  }

  @override
  Future<dynamic> doGetGeneric(String resourceUrl) async {
    final String url = '$baseUrl/$resourceUrl';

    logger?.debug('GET request', context: <String, dynamic>{'url': url});

    try {
      final Response<dynamic> response = await dio
          .get<dynamic>(url)
          .timeout(defaultTimeout);

      if (response.statusCode != HttpStatus.ok) {
        logger?.warning(
          'GET request failed',
          context: <String, dynamic>{
            'url': url,
            'statusCode': response.statusCode,
          },
        );
        throw NetworkException(
          'HTTP ${response.statusCode}: ${response.statusMessage}',
          statusCode: response.statusCode,
          endpoint: url,
        );
      }

      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        final String? error = parseErrorFromResponse(responseData);
        if (error != null && error.isNotEmpty) {
          logger?.error(
            '$providerName error',
            context: <String, dynamic>{'url': url, 'error': error},
          );
          throw NetworkException('$errorPrefix: $error', endpoint: url);
        }

        return extractGetResponseData(responseData);
      }

      return responseData;
    } on DioException catch (e) {
      final String errorMessage = parseErrorFromDioException(e, url);

      logger?.error(
        'GET request failed',
        error: e,
        context: <String, dynamic>{
          'url': url,
          'statusCode': e.response?.statusCode,
          'errorMessage': errorMessage,
        },
      );

      throw NetworkException(
        errorMessage,
        statusCode: e.response?.statusCode,
        endpoint: url,
      );
    }
  }

  @override
  Future<dynamic> doPostGeneric(String resourceUrl, dynamic payload) async {
    final String url = '$baseUrl/$resourceUrl';

    logger?.debug('POST request', context: <String, dynamic>{'url': url});

    try {
      final Response<dynamic> response = await dio
          .post<dynamic>(
            url,
            data: payload,
            options: Options(
              headers: <String, dynamic>{
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ),
          )
          .timeout(defaultTimeout);

      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.created) {
        logger?.warning(
          'POST request failed',
          context: <String, dynamic>{
            'url': url,
            'statusCode': response.statusCode,
          },
        );
        throw NetworkException(
          'HTTP ${response.statusCode}: ${response.statusMessage}',
          statusCode: response.statusCode,
          endpoint: url,
        );
      }

      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        final String? error = parseErrorFromResponse(responseData);
        if (error != null && error.isNotEmpty) {
          logger?.error(
            '$providerName error',
            context: <String, dynamic>{'url': url, 'error': error},
          );
          throw NetworkException('$errorPrefix: $error', endpoint: url);
        }

        return extractPostResponseData(responseData);
      }

      return responseData;
    } on DioException catch (e) {
      final String errorMessage = parseErrorFromDioException(e, url);

      logger?.error(
        'POST request failed',
        error: e,
        context: <String, dynamic>{
          'url': url,
          'statusCode': e.response?.statusCode,
          'errorMessage': errorMessage,
        },
      );

      throw NetworkException(
        errorMessage,
        statusCode: e.response?.statusCode,
        endpoint: url,
      );
    }
  }

  @override
  void close() {
    logger?.debug('Closing $providerName');
    _dio.close();
  }

  /// Executes operation with circuit breaker protection if enabled.
  @protected
  Future<T> executeWithCircuitBreaker<T>(Future<T> Function() operation) async {
    if (_circuitBreaker != null) {
      try {
        return await _circuitBreaker.execute(operation);
      } on CircuitBreakerOpenException catch (e) {
        final DateTime retryTime = e.lastFailureTime.add(e.retryDelay);
        logger?.error(
          'Circuit breaker is open - request rejected',
          error: e,
          context: <String, dynamic>{
            'retryDelay': e.retryDelay.inSeconds.toString(),
            'nextRetry': retryTime.toIso8601String(),
          },
        );
        throw NetworkException(
          'Network service temporarily unavailable. '
          'Retry after ${retryTime.toIso8601String()}',
        );
      }
    }

    return operation();
  }
}
