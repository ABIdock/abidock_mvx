import 'package:dio/dio.dart';

import '../../core/account/account_on_network.dart';
import '../../core/address.dart';
import '../../core/token_on_network.dart';
import '../../core/transaction/chain_id.dart';
import '../../core/transaction/transaction_on_network.dart';
import '../../core/transaction/transaction_status.dart';
import '../../core/transaction/transaction_watcher.dart';
import '../../utils/helpers.dart';
import '../../utils/sdk_exceptions.dart';
import '../logging/logger.dart';
import 'base_network_provider.dart';
import 'block_on_network.dart';
import 'network_config.dart';
import 'network_economics.dart';
import 'network_provider_config.dart';
import 'network_status.dart';
import 'send_transactions_result.dart';

/// API Network Provider for MultiversX REST API.
///
/// Uses the MultiversX API endpoints (api.multiversx.com) which provide
/// direct JSON responses without data envelope wrapping.
///
/// #### Example
/// ```dart
/// // Standard networks
/// final mainnetProvider = ApiNetworkProvider.mainnet();
/// final devnetProvider = ApiNetworkProvider.devnet(logger: ConsoleLogger());
///
/// // Custom network with circuit breaker
/// final customProvider = ApiNetworkProvider(
///   baseUrl: 'https://my-api.example.com',
///   chainId: ChainId('1'),
///   logger: ConsoleLogger(),
///   enableCircuitBreaker: true,
/// );
///
/// // Fetch account
/// final account = await devnetProvider.getAccount(address);
///
/// // Send transaction
/// final txHash = await devnetProvider.sendTransaction(signedTx);
///
/// // Query contract
/// final response = await devnetProvider.queryContract(query);
///
/// // Cleanup
/// devnetProvider.close();
/// ```
class ApiNetworkProvider extends BaseNetworkProvider {
  /// Creates an API network provider.
  ApiNetworkProvider({
    required super.baseUrl,
    required super.chainId,
    super.client,
    super.logger,
    super.enableCircuitBreaker,
    super.config,
  });

  /// Creates provider for mainnet.
  factory ApiNetworkProvider.mainnet({
    Dio? client,
    Logger? logger,
    bool enableCircuitBreaker = false,
    NetworkProviderConfig? config,
  }) {
    return ApiNetworkProvider(
      baseUrl: 'https://api.multiversx.com',
      chainId: const ChainId('1'),
      client: client,
      logger: logger,
      enableCircuitBreaker: enableCircuitBreaker,
      config: config,
    );
  }

  /// Creates provider for testnet.
  factory ApiNetworkProvider.testnet({
    Dio? client,
    Logger? logger,
    bool enableCircuitBreaker = false,
    NetworkProviderConfig? config,
  }) {
    return ApiNetworkProvider(
      baseUrl: 'https://testnet-api.multiversx.com',
      chainId: const ChainId('T'),
      client: client,
      logger: logger,
      enableCircuitBreaker: enableCircuitBreaker,
      config: config,
    );
  }

  /// Creates provider for devnet.
  factory ApiNetworkProvider.devnet({
    Dio? client,
    Logger? logger,
    bool enableCircuitBreaker = false,
    NetworkProviderConfig? config,
  }) {
    return ApiNetworkProvider(
      baseUrl: 'https://devnet-api.multiversx.com',
      chainId: const ChainId('D'),
      client: client,
      logger: logger,
      enableCircuitBreaker: enableCircuitBreaker,
      config: config,
    );
  }

  /// Awaits a transaction reaching the terminal `completed` state using
  /// the default `TransactionWatcher` polling settings.
  Future<TransactionOnNetwork> awaitTransactionCompleted(String txHash) {
    return TransactionWatcher(networkProvider: this).awaitCompleted(txHash);
  }

  /// Awaits a transaction whose status satisfies `condition` via
  /// `TransactionWatcher`.
  ///
  /// #### Parameters
  /// - `txHash` - Transaction hash to poll
  /// - `condition` - Predicate evaluated against the current `TransactionStatus`
  ///
  /// #### Returns
  /// `Future<TransactionOnNetwork>` - The transaction once the predicate matches
  Future<TransactionOnNetwork> awaitTransactionOnCondition(
    String txHash,
    bool Function(TransactionStatus status) condition,
  ) {
    return TransactionWatcher(
      networkProvider: this,
    ).awaitOnCondition(txHash, condition);
  }

  @override
  String get providerName => 'API';

  @override
  String get errorPrefix => 'API Error';

  /// Endpoint for account data, always requesting guardian information.
  ///
  /// `GET /accounts/:address` only populates `isGuarded` and the flat
  /// `activeGuardian*` / `pendingGuardian*` fields when `withGuardianInfo=true`
  /// is sent, so the flag is part of the path. `appendPagination` switches the
  /// leading separator to `&`, keeping the query string valid for callers that
  /// add their own parameters.
  @override
  String accountEndpoint(Address address) =>
      'accounts/${address.bech32}?withGuardianInfo=true';

  @override
  String accountStorageEndpoint(Address address) =>
      'address/${address.bech32}/keys';

  @override
  String accountStorageKeyEndpoint(Address address, String keyHex) =>
      'address/${address.bech32}/key/$keyHex';

  @override
  String sendTransactionEndpoint() => 'transactions';

  @override
  String queryContractEndpoint() => 'query';

  @override
  String networkStatusEndpoint({int shard = 4294967295}) =>
      'network/status/$shard';

  /// Endpoint for transaction cost estimation.
  ///
  /// The API host proxies `POST /transaction/cost` straight through to the
  /// gateway, so the same path the Gateway provider uses is served here too.
  @override
  String? estimateTransactionCostEndpoint() => 'transaction/cost';

  @override
  String sendMultipleTransactionsEndpoint() => 'transaction/send-multiple';

  /// Endpoint for a single transaction by hash.
  ///
  /// `GET /transactions/:txHash` declares only `fields` and
  /// `withActionTransferValue` as query parameters and already returns the
  /// smart-contract results by default, so `withProcessStatus` adds nothing to
  /// the path and is deliberately ignored.
  @override
  String getTransactionEndpoint(
    String txHash, {
    bool withProcessStatus = false,
  }) {
    return 'transactions/$txHash';
  }

  @override
  String getTransactionStatusEndpoint(String txHash) =>
      'transactions/$txHash?fields=status';

  /// Endpoint for transaction simulation.
  ///
  /// There is no `/transactions/simulate` route on the API; simulation is
  /// served by the gateway passthrough `POST /transaction/simulate`, whose
  /// `checkSignature` parameter defaults to skipping signature verification.
  @override
  String simulateTransactionEndpoint() =>
      'transaction/simulate?checkSignature=false';

  /// Endpoint for a single token balance of an account.
  ///
  /// Extended identifiers carrying a nonce segment (`TICKER-abcdef-01`) are
  /// served by `/accounts/{bech32}/nfts/{identifier}`; the `/tokens` route only
  /// answers for fungible ESDTs and 404s on anything with a nonce.
  @override
  String tokenOfAccountEndpoint(Address address, String tokenIdentifier) {
    return _isExtendedIdentifier(tokenIdentifier)
        ? 'accounts/${address.bech32}/nfts/$tokenIdentifier'
        : 'accounts/${address.bech32}/tokens/$tokenIdentifier';
  }

  @override
  String fungibleTokensEndpoint(Address address) =>
      'accounts/${address.bech32}/tokens';

  @override
  String nonFungibleTokensEndpoint(Address address) =>
      'accounts/${address.bech32}/nfts';

  /// First index requested on `/accounts/{bech32}/tokens` and
  /// `/accounts/{bech32}/nfts` when the caller passes none.
  @override
  int? get defaultTokenListingFrom => 0;

  /// Page size requested on `/accounts/{bech32}/tokens` and
  /// `/accounts/{bech32}/nfts` when the caller passes none.
  ///
  /// Both routes fall back to `size=25` when the parameter is omitted, which
  /// truncates the holdings of most accounts with no error and no signal in
  /// the payload. Requesting 100 keeps the common case whole; accounts holding
  /// more must be paged explicitly through `from`/`size`.
  @override
  int? get defaultTokenListingSize => 100;

  /// Endpoint for guardian data.
  ///
  /// The accounts controller exposes no `guardian-data` route; the API host
  /// serves the gateway passthrough `GET /address/:address/guardian-data`,
  /// which returns the envelope `GuardianData.fromHttpResponse` already
  /// unwraps.
  @override
  String guardianDataEndpoint(Address address) =>
      'address/${address.bech32}/guardian-data';

  @override
  String fungibleTokenDefinitionEndpoint(String identifier) =>
      'tokens/$identifier';

  @override
  String tokenCollectionDefinitionEndpoint(String collection) =>
      'collections/$collection';

  @override
  String nonFungibleInstanceEndpoint(String collection, int nonce) {
    final String nonceHex = _nonceToEvenLengthHex(nonce);
    return 'nfts/$collection-$nonceHex';
  }

  @override
  String blockByHashEndpoint(int shard, String hash) => 'blocks/$hash';

  @override
  String latestBlockEndpoint(int shard) => 'blocks?shard=$shard&size=1';

  /// Endpoint for a hyperblock by nonce.
  ///
  /// Served by the gateway passthrough `GET /hyperblock/by-nonce/:nonce`, so
  /// the payload arrives in the gateway envelope and is parsed the same way as
  /// on the Gateway provider.
  @override
  String hyperblockByNonceEndpoint(int nonce) => 'hyperblock/by-nonce/$nonce';

  @override
  NetworkConfig parseNetworkConfig(Map<String, dynamic> response) {
    final Map<String, dynamic> configData =
        optionalAs<Map<String, dynamic>>(response['config'], 'config') ??
        response;
    return NetworkConfig.fromApiResponse(configData);
  }

  @override
  NetworkStatus parseNetworkStatus(Map<String, dynamic> response) {
    final Map<String, dynamic> statusData =
        optionalAs<Map<String, dynamic>>(response['status'], 'status') ??
        response;
    return NetworkStatus.fromApiResponse(statusData);
  }

  /// Fetches network economics data from the API.
  ///
  /// The economics endpoint provides information about token supply,
  /// staking, market data, and Annual Percentage Rates (APR).
  ///
  /// #### Returns
  /// `NetworkEconomics` - Economics data
  @override
  Future<NetworkEconomics> getNetworkEconomics() async {
    final dynamic response = await doGetGeneric('economics');
    if (response is Map<String, dynamic>) {
      return NetworkEconomics.fromJson(response);
    }
    throw const NetworkException(
      'Invalid economics response format',
      endpoint: 'economics',
    );
  }

  @override
  AccountOnNetwork parseAccount(Map<String, dynamic> response) =>
      AccountOnNetwork.fromApiResponse(response);

  @override
  String parseSendTransactionHash(dynamic response) {
    if (response is Map<String, dynamic>) {
      return optionalAs<String>(response['txHash'], 'txHash') ?? '';
    }
    return response.toString();
  }

  @override
  SendTransactionsResult parseSendMultipleResult(
    dynamic response,
    int txCount,
  ) {
    if (response is Map<String, dynamic>) {
      final int numSent =
          optionalAs<int>(response['numOfSentTxs'], 'numOfSentTxs') ?? 0;
      final Map<String, dynamic> txsHashes =
          optionalAs<Map<String, dynamic>>(
            response['txsHashes'],
            'txsHashes',
          ) ??
          <String, dynamic>{};
      final Map<String, dynamic> txsErrors =
          optionalAs<Map<String, dynamic>>(
            response['txsErrors'],
            'txsErrors',
          ) ??
          <String, dynamic>{};

      final List<String?> hashes = List<String?>.filled(txCount, null);
      final List<SendTxOutcome> outcomes = <SendTxOutcome>[];
      for (int i = 0; i < txCount; i++) {
        final String? hash = optionalAs<String>(
          txsHashes[i.toString()],
          'txsHashes[$i]',
        );
        hashes[i] = hash;
        if (hash != null) {
          outcomes.add(SendTxSuccess(i, hash));
        } else {
          outcomes.add(
            SendTxFailure(
              i,
              reason: optionalAs<String>(
                txsErrors[i.toString()],
                'txsErrors[$i]',
              ),
            ),
          );
        }
      }

      return SendTransactionsResult(
        numSent: numSent,
        txHashes: hashes,
        outcomes: outcomes,
      );
    }
    return SendTransactionsResult(
      numSent: 0,
      txHashes: List<String?>.filled(txCount, null),
    );
  }

  @override
  TransactionOnNetwork parseTransaction(dynamic response, String txHash) {
    return TransactionOnNetwork.fromApiResponse(
      requireAs<Map<String, dynamic>>(response, 'response'),
      txHash: txHash,
    );
  }

  /// Parses a simulation response.
  ///
  /// `/transaction/simulate` is a gateway passthrough, so the body is
  /// gateway-shaped: the simulated transaction sits under `result` and its
  /// payloads are plain UTF-8 rather than base64.
  @override
  TransactionOnNetwork parseSimulationResult(dynamic response) {
    final Map<String, dynamic> data = requireAs<Map<String, dynamic>>(
      response,
      'response',
    );
    final Map<String, dynamic> result =
        optionalAs<Map<String, dynamic>>(data['result'], 'result') ?? data;
    return TransactionOnNetwork.fromProxyResponse(result);
  }

  @override
  Map<String, dynamic> parseTransactionCost(dynamic response) {
    final Map<String, dynamic> data = requireAs<Map<String, dynamic>>(
      response,
      'response',
    );
    return <String, dynamic>{
      'gasLimit': data['txGasUnits'] ?? data['gasLimit'] ?? 0,
      'returnMessage': data['returnMessage'] ?? '',
      'status': data['returnMessage'] == null || data['returnMessage'] == ''
          ? 'success'
          : 'fail',
    };
  }

  @override
  Map<String, dynamic> parseQueryResponseData(Map<String, dynamic> response) {
    final dynamic data = response['data'];
    if (data is Map<String, dynamic>) {
      final dynamic innerData = data['data'];
      if (innerData is Map<String, dynamic>) {
        return innerData;
      }
      return data;
    }
    return response;
  }

  @override
  List<TokenOnNetwork> parseFungibleTokens(dynamic response) {
    if (response is List) {
      return response
          .map(
            (dynamic item) => TokenOnNetwork.fromJson(
              requireAs<Map<String, dynamic>>(item, 'item'),
            ),
          )
          .toList();
    }
    return <TokenOnNetwork>[];
  }

  @override
  List<TokenOnNetwork> parseNonFungibleTokens(dynamic response) {
    if (response is List) {
      return response
          .map(
            (dynamic item) => TokenOnNetwork.fromJson(
              requireAs<Map<String, dynamic>>(item, 'item'),
            ),
          )
          .toList();
    }
    return <TokenOnNetwork>[];
  }

  @override
  TokenOnNetwork parseTokenOfAccount(dynamic response, String tokenIdentifier) {
    return TokenOnNetwork.fromJson(
      requireAs<Map<String, dynamic>>(response, 'response'),
    );
  }

  @override
  TokenOnNetwork parseFungibleTokenDefinition(
    dynamic response,
    String identifier,
  ) {
    final Map<String, dynamic> data = requireAs<Map<String, dynamic>>(
      response,
      'response',
    );
    return TokenOnNetwork.fromJson(<String, dynamic>{
      'identifier': data['identifier'] ?? identifier,
      'balance': data['balance'] ?? '0',
      'nonce': data['nonce'] ?? 0,
      ...data,
    });
  }

  @override
  TokenOnNetwork parseTokenCollectionDefinition(
    dynamic response,
    String collection,
  ) {
    final Map<String, dynamic> data = requireAs<Map<String, dynamic>>(
      response,
      'response',
    );
    return TokenOnNetwork.fromJson(<String, dynamic>{
      'identifier': data['collection'] ?? data['identifier'] ?? collection,
      'collection': data['collection'] ?? collection,
      'balance': data['balance'] ?? '0',
      'nonce': data['nonce'] ?? 0,
      ...data,
    });
  }

  @override
  TokenOnNetwork parseNonFungibleInstance(
    dynamic response,
    String collection,
    int nonce,
  ) {
    final Map<String, dynamic> data = requireAs<Map<String, dynamic>>(
      response,
      'response',
    );
    final String nonceHex = _nonceToEvenLengthHex(nonce);
    return TokenOnNetwork.fromJson(<String, dynamic>{
      'identifier': data['identifier'] ?? '$collection-$nonceHex',
      'collection': data['collection'] ?? collection,
      'balance': data['balance'] ?? '1',
      'nonce': data['nonce'] ?? nonce,
      ...data,
    });
  }

  @override
  BlockOnNetwork parseBlock(dynamic response) {
    if (response is List && response.isNotEmpty) {
      final dynamic first = response.first;
      return BlockOnNetwork.fromJson(
        requireAs<Map<String, dynamic>>(first, 'blocks[0]'),
      );
    }
    return BlockOnNetwork.fromJson(
      requireAs<Map<String, dynamic>>(response, 'response'),
    );
  }

  @override
  HyperblockOnNetwork parseHyperblock(dynamic response) {
    final Map<String, dynamic> data = requireAs<Map<String, dynamic>>(
      response,
      'response',
    );
    final Map<String, dynamic> hyperblock =
        optionalAs<Map<String, dynamic>>(data['hyperblock'], 'hyperblock') ??
        data;
    return HyperblockOnNetwork.fromJson(hyperblock);
  }

  @override
  dynamic extractGetResponseData(Map<String, dynamic> response) {
    if (response.containsKey('data') && response.containsKey('code')) {
      return response['data'];
    }
    return response;
  }

  @override
  dynamic extractPostResponseData(Map<String, dynamic> response) {
    if (response.containsKey('data') && response.containsKey('code')) {
      return response['data'];
    }
    return response;
  }

  @override
  String? parseErrorFromResponse(Map<String, dynamic> response) {
    final dynamic error = response['error'];
    if (error is Map<String, dynamic>) {
      return optionalAs<String>(error['message'], 'message');
    } else if (error is String) {
      return error;
    }
    return null;
  }

  @override
  String parseErrorFromDioException(DioException e, String url) {
    if (e.response?.data != null) {
      final dynamic responseData = e.response?.data;
      if (responseData is Map<String, dynamic>) {
        final dynamic error = responseData['error'];
        if (error is Map<String, dynamic>) {
          return optionalAs<String>(error['message'], 'message') ??
              'HTTP ${e.response?.statusCode}: Request failed';
        } else if (error is String && error.isNotEmpty) {
          return error;
        }
        final String? message = optionalAs<String>(
          responseData['message'],
          'message',
        );
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    }
    return 'HTTP ${e.response?.statusCode ?? 'unknown'}: ${e.message}';
  }

  /// Whether `identifier` carries a nonce segment (`TICKER-abcdef-01`).
  static bool _isExtendedIdentifier(String identifier) =>
      identifier.split('-').length >= 3;

  static String _nonceToEvenLengthHex(int nonce) {
    String hex = nonce.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';
    if (hex.length < 2) hex = hex.padLeft(2, '0');
    return hex;
  }
}
