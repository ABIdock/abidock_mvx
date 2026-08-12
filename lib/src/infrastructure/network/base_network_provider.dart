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
import '../caching/cache_manager.dart';
import '../logging/logger.dart';
import '../resilience/circuit_breaker.dart';
import '../resilience/circuit_breaker_exception.dart';
import '../resilience/request_throttle.dart';
import '../resilience/retry_helper.dart';
import 'account_storage.dart';
import 'account_storage_entry.dart';
import 'block_on_network.dart';
import 'guardian_data.dart';
import 'network_config.dart';
import 'network_provider.dart';
import 'network_provider_config.dart';
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
  /// - `config` - Optional `NetworkProviderConfig` controlling client name,
  ///   extra HTTP headers, request timeout, base URL override, and the
  ///   retry / throttle / response-cache policies. Every policy defaults to
  ///   off, so omitting `config` leaves one plain HTTP request per call.
  BaseNetworkProvider({
    required String baseUrl,
    required ChainId chainId,
    Dio? client,
    this.logger,
    this.enableCircuitBreaker = false,
    NetworkProviderConfig? config,
  }) : _baseUrl = _normalizeBaseUrl(config?.baseUrl ?? baseUrl),
       _chainId = chainId,
       _dio = client ?? Dio(),
       _ownsClient = client == null,
       _config = config {
    /// Only mutate the Dio default options when the provider owns the
    /// client. When a shared Dio is injected (M2-14), we leave its headers /
    /// timeouts untouched and instead carry per-request overrides via Options.
    if (_ownsClient) {
      _applyConfigToDio();
    }

    if (enableCircuitBreaker) {
      _circuitBreaker = CircuitBreaker(
        failureThreshold: 5,
        timeout: requestTimeout,
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
  final bool _ownsClient;

  /// Logger for debugging and monitoring.
  final Logger? logger;

  /// Enable circuit breaker for resilient calls.
  final bool enableCircuitBreaker;

  /// Optional configuration block forwarded from the user / Entrypoint.
  final NetworkProviderConfig? _config;

  /// Returns the active `NetworkProviderConfig`, if any.
  NetworkProviderConfig? get config => _config;

  /// Circuit breaker for resilient calls (if enabled).
  late final CircuitBreaker? _circuitBreaker;

  /// Lazily built `RetryHelper`. Only created when the supplied
  /// `NetworkProviderConfig.retryPolicy` is enabled (M2-15).
  RetryHelper? get _retryHelper {
    final RetryPolicy? policy = _config?.retryPolicy;
    if (policy == null || !policy.enabled) return null;
    return _cachedRetryHelper ??= RetryHelper(
      config: policy.config ?? const RetryConfig(),
      logger: logger,
    );
  }

  RetryHelper? _cachedRetryHelper;

  /// Lazily built `RequestThrottle`. Only created when the supplied
  /// `NetworkProviderConfig.throttlePolicy` is enabled.
  RequestThrottle? get _throttle {
    final ThrottlePolicy? policy = _config?.throttlePolicy;
    if (policy == null || !policy.enabled) return null;
    return _cachedThrottle ??= RequestThrottle(
      capacity: policy.capacity!,
      refillPerSecond: policy.refillPerSecond!,
    );
  }

  RequestThrottle? _cachedThrottle;

  /// Lazily built response `CacheManager`. Only created when the supplied
  /// `NetworkProviderConfig.cachePolicy` is enabled.
  CacheManager? get _responseCache {
    final ResponseCachePolicy? policy = _config?.cachePolicy;
    if (policy == null || !policy.enabled) return null;
    return _cachedResponseCache ??= CacheManager(
      defaultConfig: policy.defaultConfig ?? const CacheConfig(),
      endpointConfigs: policy.endpointConfigs,
    );
  }

  CacheManager? _cachedResponseCache;

  /// Waits for a slot from the configured request throttle.
  ///
  /// Returns immediately when `NetworkProviderConfig.throttlePolicy` is
  /// disabled, which is the default, so an unconfigured provider pays nothing
  /// for this call.
  @protected
  Future<void> acquireRequestSlot() async {
    final RequestThrottle? throttle = _throttle;
    if (throttle == null) return;
    await throttle.acquire();
  }

  /// Drops every entry from the opt-in `GET` response cache.
  ///
  /// No-op when `NetworkProviderConfig.cachePolicy` is disabled. The cache is
  /// already cleared automatically after every successful `POST`; call this
  /// when state changed through some other channel.
  void clearResponseCache() => _cachedResponseCache?.clearAll();

  /// Default timeout for requests.
  @protected
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// Effective request timeout used for per-call races and Dio defaults.
  @protected
  Duration get requestTimeout => _config?.requestTimeout ?? defaultTimeout;

  static String _normalizeBaseUrl(String url) {
    String trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// Combines `baseUrl` with `resourceUrl` while collapsing duplicate slashes.
  @protected
  String resolveUrl(String resourceUrl) => _resolveUrl(resourceUrl);

  String _resolveUrl(String resourceUrl) {
    String path = resourceUrl;
    while (path.startsWith('/')) {
      path = path.substring(1);
    }
    return '$_baseUrl/$path';
  }

  void _applyConfigToDio() {
    final Duration effective = requestTimeout;
    _dio.options.connectTimeout = effective;
    _dio.options.receiveTimeout = effective;
    _dio.options.sendTimeout = effective;

    final String userAgent = UserAgent.build(clientName: _config?.clientName);
    _dio.options.headers['User-Agent'] = userAgent;

    final Map<String, String>? extra = _config?.headers;
    if (extra != null) {
      for (final MapEntry<String, String> entry in extra.entries) {
        _dio.options.headers[entry.key] = entry.value;
      }
    }
  }

  /// Builds the per-request header map combining configured headers, the
  /// SDK user-agent, and any extra entries provided by the caller.
  ///
  /// When the underlying Dio is shared (not owned), this is the only place
  /// header customisation happens — `_applyConfigToDio` is skipped so the
  /// shared client's defaults remain untouched (M2-14).
  Map<String, dynamic> _buildRequestHeaders([Map<String, dynamic>? extra]) {
    final Map<String, dynamic> headers = <String, dynamic>{};
    if (!_ownsClient) {
      headers['User-Agent'] = UserAgent.build(clientName: _config?.clientName);
      final Map<String, String>? configured = _config?.headers;
      if (configured != null) {
        for (final MapEntry<String, String> entry in configured.entries) {
          headers[entry.key] = entry.value;
        }
      }
    }
    if (extra != null) headers.addAll(extra);
    return headers;
  }

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

  /// Endpoint for `getGuardianData`.
  ///
  /// API: `accounts/{bech32}/guardian-data`. Gateway: `address/{bech32}/guardian-data`.
  @protected
  String guardianDataEndpoint(Address address);

  /// First index sent on the account token/NFT listing routes when the caller
  /// asks for no particular page.
  ///
  /// `null` means "send nothing", which is correct for hosts whose listing
  /// route returns the account's complete holdings in one payload.
  @protected
  int? get defaultTokenListingFrom => null;

  /// Page size sent on the account token/NFT listing routes when the caller
  /// asks for no particular page.
  ///
  /// `null` means "send nothing" and therefore accept whatever the host
  /// defaults to.
  @protected
  int? get defaultTokenListingSize => null;

  /// Appends `?from=...&size=...` to `path` when the params are non-null.
  ///
  /// Preserves existing query strings on `path` by switching the leading
  /// separator from `?` to `&` as needed.
  @protected
  String appendPagination(String path, {int? from, int? size}) {
    if (from == null && size == null) {
      return path;
    }
    final List<String> parts = <String>[];
    if (from != null) parts.add('from=$from');
    if (size != null) parts.add('size=$size');
    final String sep = path.contains('?') ? '&' : '?';
    return '$path$sep${parts.join('&')}';
  }

  /// Endpoint for fungible-token metadata lookup.
  @protected
  String fungibleTokenDefinitionEndpoint(String identifier);

  /// Endpoint for collection (NFT/SFT/MetaESDT) metadata lookup.
  @protected
  String tokenCollectionDefinitionEndpoint(String collection);

  /// Endpoint for a single NFT / SFT / MetaESDT instance by `collection-nonceHex`.
  @protected
  String nonFungibleInstanceEndpoint(String collection, int nonce);

  /// Endpoint for fetching a block by hash within a given shard.
  ///
  /// Gateway requires both `shard` and `hash` in the URL
  /// (`block/{shard}/by-hash/{hash}`). API ignores `shard` because it indexes
  /// blocks globally by hash; implementations should still accept the value.
  @protected
  String blockByHashEndpoint(int shard, String hash);

  /// Endpoint for fetching the latest block for a shard.
  @protected
  String latestBlockEndpoint(int shard);

  /// Endpoint for fetching a hyperblock by nonce.
  @protected
  String hyperblockByNonceEndpoint(int nonce);

  /// Endpoint for smart-contract VM queries.
  @protected
  String queryContractEndpoint();

  /// Endpoint for fetching network status. API uses a single path;
  /// Gateway takes a shard suffix.
  @protected
  String networkStatusEndpoint({int shard = 4294967295});

  /// Endpoint for transaction cost estimation.
  ///
  /// `POST /transaction/cost` is served by the Gateway and proxied by the API
  /// host, so the default is correct for both. Return `null` only from a
  /// provider pointed at a host that does not expose the route.
  @protected
  String? estimateTransactionCostEndpoint() => 'transaction/cost';

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
  Future<NetworkStatus> getNetworkStatus({int shard = 4294967295}) async {
    logger?.debug(
      'Fetching network status',
      context: <String, dynamic>{'shard': shard.toString()},
    );

    final response = await executeWithCircuitBreaker(
      () => doGetGeneric(networkStatusEndpoint(shard: shard)),
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

    final String? endpoint = estimateTransactionCostEndpoint();
    if (endpoint == null) {
      throw UnsupportedError(
        'estimateTransactionCost is not wired on $providerName: '
        'estimateTransactionCostEndpoint() returned null. Both the API and '
        'the Gateway hosts serve POST /transaction/cost, which is the '
        'default this hook returns.',
      );
    }
    final response = await executeWithCircuitBreaker(
      () => doPostGeneric(endpoint, txData),
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

      final Response<dynamic> response = await executeWithCircuitBreaker(
        () async {
          await acquireRequestSlot();
          return dio
              .post<dynamic>(
                _resolveUrl(queryContractEndpoint()),
                data: requestBody,
                options: Options(
                  headers: _buildRequestHeaders(<String, dynamic>{
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                  }),
                ),
              )
              .timeout(requestTimeout);
        },
      );

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
    Address address, {
    int? from,
    int? size,
  }) async {
    final int? effectiveFrom = from ?? defaultTokenListingFrom;
    final int? effectiveSize = size ?? defaultTokenListingSize;

    logger?.debug(
      'Fetching fungible tokens',
      context: <String, dynamic>{
        'address': address.bech32,
        'from': effectiveFrom?.toString() ?? 'default',
        'size': effectiveSize?.toString() ?? 'default',
      },
    );

    final String url = appendPagination(
      fungibleTokensEndpoint(address),
      from: effectiveFrom,
      size: effectiveSize,
    );

    final response = await executeWithCircuitBreaker(() => doGetGeneric(url));

    return parseFungibleTokens(response);
  }

  @override
  Future<List<TokenOnNetwork>> getNonFungibleTokensOfAccount(
    Address address, {
    int? from,
    int? size,
  }) async {
    final int? effectiveFrom = from ?? defaultTokenListingFrom;
    final int? effectiveSize = size ?? defaultTokenListingSize;

    logger?.debug(
      'Fetching NFTs',
      context: <String, dynamic>{
        'address': address.bech32,
        'from': effectiveFrom?.toString() ?? 'default',
        'size': effectiveSize?.toString() ?? 'default',
      },
    );

    final String url = appendPagination(
      nonFungibleTokensEndpoint(address),
      from: effectiveFrom,
      size: effectiveSize,
    );

    final response = await executeWithCircuitBreaker(() => doGetGeneric(url));

    return parseNonFungibleTokens(response);
  }

  @override
  Future<GuardianData> getGuardianData(Address address) async {
    logger?.debug(
      'Fetching guardian data',
      context: <String, dynamic>{'address': address.bech32},
    );

    final response = await executeWithCircuitBreaker(
      () => doGetGeneric(guardianDataEndpoint(address)),
    );

    return GuardianData.fromHttpResponse(
      requireAs<Map<String, dynamic>>(response, 'response'),
    );
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
  Future<BlockOnNetwork> getBlock(String hash, {int shard = 4294967295}) async {
    logger?.debug(
      'Fetching block',
      context: <String, dynamic>{'hash': hash, 'shard': shard.toString()},
    );

    final response = await executeWithCircuitBreaker(
      () => doGetGeneric(blockByHashEndpoint(shard, hash)),
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
    final CacheManager? cache = _responseCache;
    if (cache != null) {
      final dynamic cached = cache.get<dynamic>(resourceUrl);
      if (cached != null) {
        logger?.debug(
          'GET served from cache',
          context: <String, dynamic>{'resource': resourceUrl},
        );
        return cached;
      }
    }

    final RetryHelper? retry = _retryHelper;
    final dynamic result = retry == null
        ? await _doGetGenericOnce(resourceUrl)
        : await retry.execute<dynamic>(
            operation: () => _doGetGenericOnce(resourceUrl),
            isRetryable: RetryHelper.isTransientError,
            operationName: 'GET $resourceUrl',
          );

    if (cache != null && result != null) {
      cache.put<dynamic>(resourceUrl, result);
    }

    return result;
  }

  Future<dynamic> _doGetGenericOnce(String resourceUrl) async {
    final String url = _resolveUrl(resourceUrl);

    logger?.debug('GET request', context: <String, dynamic>{'url': url});

    await acquireRequestSlot();

    try {
      final Response<dynamic> response = await dio
          .get<dynamic>(url, options: Options(headers: _buildRequestHeaders()))
          .timeout(requestTimeout);

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
    } on DioException catch (e, stack) {
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
        cause: e,
        stackTrace: stack,
      );
    }
  }

  @override
  Future<dynamic> doPostGeneric(String resourceUrl, dynamic payload) async {
    final RetryHelper? retry = _retryHelper;
    final dynamic result = retry == null
        ? await _doPostGenericOnce(resourceUrl, payload)
        : await retry.execute<dynamic>(
            operation: () => _doPostGenericOnce(resourceUrl, payload),
            isRetryable: RetryHelper.isTransientError,
            operationName: 'POST $resourceUrl',
          );

    /// A successful POST may have changed chain state — a sent transaction
    /// bumps the sender nonce — so any cached GET body is now suspect.
    _cachedResponseCache?.clearAll();

    return result;
  }

  Future<dynamic> _doPostGenericOnce(
    String resourceUrl,
    dynamic payload,
  ) async {
    final String url = _resolveUrl(resourceUrl);

    logger?.debug('POST request', context: <String, dynamic>{'url': url});

    await acquireRequestSlot();

    try {
      final Response<dynamic> response = await dio
          .post<dynamic>(
            url,
            data: payload,
            options: Options(
              headers: _buildRequestHeaders(<String, dynamic>{
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              }),
            ),
          )
          .timeout(requestTimeout);

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
    } on DioException catch (e, stack) {
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
        cause: e,
        stackTrace: stack,
      );
    }
  }

  @override
  void close() {
    logger?.debug('Closing $providerName');
    if (_ownsClient) {
      _dio.close(force: true);
    }
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
