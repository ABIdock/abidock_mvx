import 'package:dio/dio.dart';

import '../../core/account/account_on_network.dart';
import '../../core/address.dart';
import '../../core/token_on_network.dart';
import '../../core/transaction/chain_id.dart';
import '../../core/transaction/transaction_on_network.dart';
import '../../utils/helpers.dart';
import '../logging/logger.dart';
import 'base_network_provider.dart';
import 'network_config.dart';
import 'network_economics.dart';
import 'network_status.dart';
import 'send_transactions_result.dart';

/// Gateway Network Provider for MultiversX Gateway (Proxy).
///
/// Uses the MultiversX Gateway endpoints (gateway.multiversx.com) which wrap
/// responses in a data envelope structure.
///
/// #### Example
/// ```dart
/// // Standard networks
/// final mainnetGateway = GatewayNetworkProvider.mainnet();
/// final devnetGateway = GatewayNetworkProvider.devnet(logger: ConsoleLogger());
///
/// // Custom gateway with circuit breaker
/// final customGateway = GatewayNetworkProvider(
///   baseUrl: 'https://my-gateway.example.com',
///   chainId: ChainId('D'),
///   logger: ConsoleLogger(),
///   enableCircuitBreaker: true,
/// );
///
/// // Same interface as ApiNetworkProvider
/// final account = await devnetGateway.getAccount(address);
/// final txHash = await devnetGateway.sendTransaction(signedTx);
/// final response = await devnetGateway.queryContract(query);
///
/// // Cleanup
/// devnetGateway.close();
/// ```
class GatewayNetworkProvider extends BaseNetworkProvider {
  /// Creates a Gateway network provider.
  GatewayNetworkProvider({
    required super.baseUrl,
    required super.chainId,
    super.client,
    super.logger,
    super.enableCircuitBreaker,
  });

  /// Creates provider for mainnet.
  factory GatewayNetworkProvider.mainnet({
    Dio? client,
    Logger? logger,
    bool enableCircuitBreaker = false,
  }) {
    return GatewayNetworkProvider(
      baseUrl: 'https://gateway.multiversx.com',
      chainId: const ChainId('1'),
      client: client,
      logger: logger,
      enableCircuitBreaker: enableCircuitBreaker,
    );
  }

  /// Creates provider for testnet.
  factory GatewayNetworkProvider.testnet({
    Dio? client,
    Logger? logger,
    bool enableCircuitBreaker = false,
  }) {
    return GatewayNetworkProvider(
      baseUrl: 'https://testnet-gateway.multiversx.com',
      chainId: const ChainId('T'),
      client: client,
      logger: logger,
      enableCircuitBreaker: enableCircuitBreaker,
    );
  }

  /// Creates provider for devnet.
  factory GatewayNetworkProvider.devnet({
    Dio? client,
    Logger? logger,
    bool enableCircuitBreaker = false,
  }) {
    return GatewayNetworkProvider(
      baseUrl: 'https://devnet-gateway.multiversx.com',
      chainId: const ChainId('D'),
      client: client,
      logger: logger,
      enableCircuitBreaker: enableCircuitBreaker,
    );
  }

  @override
  String get providerName => 'Gateway';

  @override
  String get errorPrefix => 'Gateway error';

  @override
  String accountEndpoint(Address address) => 'address/${address.bech32}';

  @override
  String accountStorageEndpoint(Address address) =>
      'address/${address.bech32}/keys';

  @override
  String accountStorageKeyEndpoint(Address address, String keyHex) =>
      'address/${address.bech32}/key/$keyHex';

  @override
  String sendTransactionEndpoint() => 'transaction/send';

  @override
  String sendMultipleTransactionsEndpoint() => 'transaction/send-multiple';

  @override
  String getTransactionEndpoint(
    String txHash, {
    bool withProcessStatus = false,
  }) {
    final String results = withProcessStatus ? '?withResults=true' : '';
    return 'transaction/$txHash$results';
  }

  @override
  String getTransactionStatusEndpoint(String txHash) =>
      'transaction/$txHash/status';

  @override
  String simulateTransactionEndpoint() =>
      'transaction/simulate?checkSignature=false';

  @override
  String tokenOfAccountEndpoint(Address address, String tokenIdentifier) =>
      'address/${address.bech32}/esdt/$tokenIdentifier';

  @override
  String fungibleTokensEndpoint(Address address) =>
      'address/${address.bech32}/esdt';

  @override
  String nonFungibleTokensEndpoint(Address address) =>
      'address/${address.bech32}/nft';

  @override
  NetworkConfig parseNetworkConfig(Map<String, dynamic> response) {
    final Map<String, dynamic> configData =
        optionalAs<Map<String, dynamic>>(response['config'], 'config') ??
        response;
    return NetworkConfig.fromProxyResponse(configData);
  }

  @override
  NetworkStatus parseNetworkStatus(Map<String, dynamic> response) {
    return NetworkStatus.fromProxyResponse(response);
  }

  /// Gateway does not support the economics endpoint.
  ///
  /// The economics data is only available through the API provider.
  /// Use `ApiNetworkProvider.getNetworkEconomics()` instead.
  ///
  /// #### Throws
  /// `UnsupportedError` - Always throws, as Gateway doesn't support this endpoint
  @override
  Future<NetworkEconomics> getNetworkEconomics() {
    throw UnsupportedError(
      'getNetworkEconomics is not supported by Gateway provider. '
      'Use ApiNetworkProvider instead.',
    );
  }

  @override
  AccountOnNetwork parseAccount(Map<String, dynamic> response) {
    final Map<String, dynamic> accountData =
        optionalAs<Map<String, dynamic>>(response['account'], 'account') ??
        response;
    return AccountOnNetwork.fromProxyResponse(accountData);
  }

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
      final int numSent = int.parse(response['numOfSentTxs'].toString());
      final Map<String, dynamic> txHashesMap =
          optionalAs<Map<String, dynamic>>(
            response['txsHashes'],
            'txsHashes',
          ) ??
          <String, dynamic>{};

      final List<String?> hashes = List<String?>.filled(txCount, null);
      for (int i = 0; i < txCount; i++) {
        hashes[i] = optionalAs<String>(txHashesMap[i.toString()], 'txHash[$i]');
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
    final Map<String, dynamic> data = requireAs<Map<String, dynamic>>(
      response,
      'response',
    );
    final Map<String, dynamic> txData =
        optionalAs<Map<String, dynamic>>(data['transaction'], 'transaction') ??
        data;
    return TransactionOnNetwork.fromApiResponse(txData, txHash: txHash);
  }

  @override
  TransactionOnNetwork parseSimulationResult(dynamic response) {
    final Map<String, dynamic> data = requireAs<Map<String, dynamic>>(
      response,
      'response',
    );
    final Map<String, dynamic> result =
        optionalAs<Map<String, dynamic>>(data['result'], 'result') ?? data;
    return TransactionOnNetwork.fromApiResponse(result);
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
      'status': data['status'] ?? 'unknown',
    };
  }

  @override
  Map<String, dynamic> parseQueryResponseData(Map<String, dynamic> response) {
    final dynamic data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return response;
  }

  @override
  List<TokenOnNetwork> parseFungibleTokens(dynamic response) {
    if (response is Map<String, dynamic>) {
      final dynamic esdts = response['esdts'];
      if (esdts is Map<String, dynamic>) {
        return esdts.entries.map((MapEntry<String, dynamic> entry) {
          final Map<String, dynamic> tokenData =
              requireAs<Map<String, dynamic>>(
                entry.value,
                'esdts[${entry.key}]',
              );
          return TokenOnNetwork.fromJson(<String, dynamic>{
            'identifier': entry.key,
            ...tokenData,
          });
        }).toList();
      }
    }
    return <TokenOnNetwork>[];
  }

  @override
  List<TokenOnNetwork> parseNonFungibleTokens(dynamic response) {
    if (response is Map<String, dynamic>) {
      final dynamic esdts = response['esdts'];
      if (esdts is Map<String, dynamic>) {
        return esdts.entries.map((MapEntry<String, dynamic> entry) {
          final Map<String, dynamic> tokenData =
              requireAs<Map<String, dynamic>>(
                entry.value,
                'esdts[${entry.key}]',
              );
          return TokenOnNetwork.fromJson(<String, dynamic>{
            'identifier': entry.key,
            ...tokenData,
          });
        }).toList();
      }
    }
    return <TokenOnNetwork>[];
  }

  @override
  TokenOnNetwork parseTokenOfAccount(dynamic response, String tokenIdentifier) {
    final Map<String, dynamic> data = requireAs<Map<String, dynamic>>(
      response,
      'response',
    );
    final Map<String, dynamic>? tokenData = optionalAs<Map<String, dynamic>>(
      data['tokenData'],
      'tokenData',
    );

    if (tokenData != null) {
      return TokenOnNetwork.fromJson(<String, dynamic>{
        'identifier': tokenData['tokenIdentifier'] ?? tokenIdentifier,
        'balance': tokenData['balance'] ?? '0',
        ...tokenData,
      });
    }

    return TokenOnNetwork.fromJson(data);
  }

  @override
  dynamic extractGetResponseData(Map<String, dynamic> response) {
    final dynamic data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return response;
  }

  @override
  dynamic extractPostResponseData(Map<String, dynamic> response) {
    final dynamic data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return response;
  }

  @override
  String? parseErrorFromResponse(Map<String, dynamic> response) {
    final dynamic error = response['error'];
    if (error is String && error.isNotEmpty) {
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
        if (error is String && error.isNotEmpty) {
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
