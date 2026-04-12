import 'package:dio/dio.dart';

import '../../core/account/account_on_network.dart';
import '../../core/address.dart';
import '../../core/token_on_network.dart';
import '../../core/transaction/chain_id.dart';
import '../../core/transaction/transaction_on_network.dart';
import '../../utils/helpers.dart';
import '../../utils/sdk_exceptions.dart';
import '../logging/logger.dart';
import 'base_network_provider.dart';
import 'block_on_network.dart';
import 'network_config.dart';
import 'network_economics.dart';
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
  });

  /// Creates provider for mainnet.
  factory ApiNetworkProvider.mainnet({
    Dio? client,
    Logger? logger,
    bool enableCircuitBreaker = false,
  }) {
    return ApiNetworkProvider(
      baseUrl: 'https://api.multiversx.com',
      chainId: const ChainId('1'),
      client: client,
      logger: logger,
      enableCircuitBreaker: enableCircuitBreaker,
    );
  }

  /// Creates provider for testnet.
  factory ApiNetworkProvider.testnet({
    Dio? client,
    Logger? logger,
    bool enableCircuitBreaker = false,
  }) {
    return ApiNetworkProvider(
      baseUrl: 'https://testnet-api.multiversx.com',
      chainId: const ChainId('T'),
      client: client,
      logger: logger,
      enableCircuitBreaker: enableCircuitBreaker,
    );
  }

  /// Creates provider for devnet.
  factory ApiNetworkProvider.devnet({
    Dio? client,
    Logger? logger,
    bool enableCircuitBreaker = false,
  }) {
    return ApiNetworkProvider(
      baseUrl: 'https://devnet-api.multiversx.com',
      chainId: const ChainId('D'),
      client: client,
      logger: logger,
      enableCircuitBreaker: enableCircuitBreaker,
    );
  }

  @override
  String get providerName => 'API';

  @override
  String get errorPrefix => 'API Error';

  @override
  String accountEndpoint(Address address) => 'accounts/${address.bech32}';

  @override
  String accountStorageEndpoint(Address address) =>
      'accounts/${address.bech32}/keys';

  @override
  String accountStorageKeyEndpoint(Address address, String keyHex) =>
      'accounts/${address.bech32}/keys/$keyHex';

  @override
  String sendTransactionEndpoint() => 'transactions';

  @override
  String sendMultipleTransactionsEndpoint() => 'transactions';

  @override
  String getTransactionEndpoint(
    String txHash, {
    bool withProcessStatus = false,
  }) {
    final String fields = withProcessStatus
        ? '?fields=processingTypeOnSource,processingTypeOnDestination'
        : '';
    return 'transactions/$txHash$fields';
  }

  @override
  String getTransactionStatusEndpoint(String txHash) =>
      'transactions/$txHash?fields=status';

  @override
  String simulateTransactionEndpoint() => 'transactions/simulate';

  @override
  String tokenOfAccountEndpoint(Address address, String tokenIdentifier) =>
      'accounts/${address.bech32}/tokens/$tokenIdentifier';

  @override
  String fungibleTokensEndpoint(Address address) =>
      'accounts/${address.bech32}/tokens';

  @override
  String nonFungibleTokensEndpoint(Address address) =>
      'accounts/${address.bech32}/nfts';

  @override
  String fungibleTokenDefinitionEndpoint(String identifier) =>
      'tokens/$identifier';

  @override
  String tokenCollectionDefinitionEndpoint(String collection) =>
      'collections/$collection';

  @override
  String nonFungibleInstanceEndpoint(String collection, int nonce) {
    final String nonceHex = nonce.toRadixString(16).padLeft(2, '0');
    return 'nfts/$collection-$nonceHex';
  }

  @override
  String blockByHashEndpoint(String hash) => 'blocks/$hash';

  @override
  String latestBlockEndpoint(int shard) => 'blocks?shard=$shard&size=1';

  @override
  String hyperblockByNonceEndpoint(int nonce) => throw UnsupportedError(
    'Hyperblocks are not exposed by the API provider. '
    'Use GatewayNetworkProvider.getHyperblock instead.',
  );

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

      final List<String?> hashes = List<String?>.filled(txCount, null);
      for (int i = 0; i < txCount; i++) {
        hashes[i] = optionalAs<String>(
          txsHashes[i.toString()],
          'txsHashes[$i]',
        );
      }

      return SendTransactionsResult(numSent: numSent, txHashes: hashes);
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

  @override
  TransactionOnNetwork parseSimulationResult(dynamic response) {
    return TransactionOnNetwork.fromApiResponse(
      requireAs<Map<String, dynamic>>(response, 'response'),
    );
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
    final String nonceHex = nonce.toRadixString(16).padLeft(2, '0');
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
    throw UnsupportedError(
      'Hyperblocks are not exposed by the API provider. '
      'Use GatewayNetworkProvider.getHyperblock instead.',
    );
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
}
