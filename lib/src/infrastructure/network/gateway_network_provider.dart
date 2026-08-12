import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../../core/account/account_on_network.dart';
import '../../core/address.dart';
import '../../core/token_on_network.dart';
import '../../core/transaction/chain_id.dart';
import '../../core/transaction/transaction_on_network.dart';
import '../../core/transaction/transaction_status.dart';
import '../../utils/helpers.dart';
import '../logging/logger.dart';
import 'base_network_provider.dart';
import 'block_on_network.dart';
import 'network_config.dart';
import 'network_economics.dart';
import 'network_provider_config.dart';
import 'network_status.dart';
import 'send_transactions_result.dart';

/// Chain-level economics metrics served by the Gateway's
/// `GET /network/economics`.
///
/// This is deliberately a different type from `NetworkEconomics`: the proxy
/// forwards the metachain observer's `erd_*` metric map, which carries no
/// price, market cap or APR — those are computed only by
/// `api.multiversx.com`. Every monetary value is an atomic `1e-18` amount
/// serialised as a decimal string, so it is exposed as `BigInt`;
/// `erd_total_supply` alone is `2e25` on mainnet and overflows a 64-bit `int`.
///
/// #### Example
/// ```dart
/// final economics = await gateway.getGatewayEconomics();
/// print(economics.totalSupply); // 20000000000000000000000000
/// print(economics.epochForEconomicsData); // 263
/// ```
final class GatewayEconomics {
  /// Total EGLD supply in atomic units (`erd_total_supply`).
  final BigInt totalSupply;

  /// Accumulated fees for the epoch in atomic units (`erd_total_fees`).
  final BigInt totalFees;

  /// Developer rewards for the epoch in atomic units (`erd_dev_rewards`).
  final BigInt devRewards;

  /// Inflation for the epoch in atomic units (`erd_inflation`).
  final BigInt inflation;

  /// Epoch the metrics were computed for (`erd_epoch_for_economics_data`).
  final int epochForEconomicsData;

  /// Base staked value in atomic units (`erd_total_base_staked_value`).
  final BigInt totalBaseStakedValue;

  /// Top-up value in atomic units (`erd_total_top_up_value`).
  final BigInt totalTopUpValue;

  /// Raw metrics map exactly as returned by the Gateway.
  final Map<String, dynamic> raw;

  /// Creates a new [GatewayEconomics] instance.
  const GatewayEconomics({
    required this.totalSupply,
    required this.totalFees,
    required this.devRewards,
    required this.inflation,
    required this.epochForEconomicsData,
    required this.totalBaseStakedValue,
    required this.totalTopUpValue,
    required this.raw,
  });

  /// Creates a [GatewayEconomics] from the Gateway's economics payload.
  ///
  /// Accepts either the unwrapped `data` object (`{"metrics": {...}}`) or the
  /// bare metrics map. Unknown or unparsable values fall back to zero rather
  /// than throwing, mirroring the other proxy parsers in this provider.
  ///
  /// #### Parameters
  /// - `response` - Unwrapped `data` envelope from `GET /network/economics`
  ///
  /// #### Returns
  /// `GatewayEconomics` - Parsed chain economics metrics
  factory GatewayEconomics.fromProxyResponse(Map<String, dynamic> response) {
    final Map<String, dynamic> metrics =
        optionalAs<Map<String, dynamic>>(response['metrics'], 'metrics') ??
        response;
    return GatewayEconomics(
      totalSupply: _bigIntMetric(metrics, 'erd_total_supply'),
      totalFees: _bigIntMetric(metrics, 'erd_total_fees'),
      devRewards: _bigIntMetric(metrics, 'erd_dev_rewards'),
      inflation: _bigIntMetric(metrics, 'erd_inflation'),
      epochForEconomicsData:
          optionalInt(
            metrics['erd_epoch_for_economics_data'],
            'erd_epoch_for_economics_data',
          ) ??
          0,
      totalBaseStakedValue: _bigIntMetric(
        metrics,
        'erd_total_base_staked_value',
      ),
      totalTopUpValue: _bigIntMetric(metrics, 'erd_total_top_up_value'),
      raw: metrics,
    );
  }

  static BigInt _bigIntMetric(Map<String, dynamic> metrics, String key) {
    final dynamic value = metrics[key];
    if (value == null) return BigInt.zero;
    return BigInt.tryParse(value.toString()) ?? BigInt.zero;
  }

  @override
  String toString() =>
      'GatewayEconomics('
      'totalSupply: $totalSupply, '
      'totalFees: $totalFees, '
      'devRewards: $devRewards, '
      'inflation: $inflation, '
      'epochForEconomicsData: $epochForEconomicsData, '
      'totalBaseStakedValue: $totalBaseStakedValue, '
      'totalTopUpValue: $totalTopUpValue)';
}

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
/// // Custom gateway with circuit breaker and a client identity
/// final customGateway = GatewayNetworkProvider(
///   baseUrl: 'https://my-gateway.example.com',
///   chainId: ChainId('D'),
///   logger: ConsoleLogger(),
///   enableCircuitBreaker: true,
///   config: NetworkProviderConfig(
///     clientName: 'my-dapp',
///     requestTimeout: Duration(seconds: 7),
///     headers: {'X-Request-Id': 'abc'},
///   ),
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
    super.config,
  });

  /// Creates provider for mainnet.
  factory GatewayNetworkProvider.mainnet({
    Dio? client,
    Logger? logger,
    bool enableCircuitBreaker = false,
    NetworkProviderConfig? config,
  }) {
    return GatewayNetworkProvider(
      baseUrl: 'https://gateway.multiversx.com',
      chainId: const ChainId('1'),
      client: client,
      logger: logger,
      enableCircuitBreaker: enableCircuitBreaker,
      config: config,
    );
  }

  /// Creates provider for testnet.
  factory GatewayNetworkProvider.testnet({
    Dio? client,
    Logger? logger,
    bool enableCircuitBreaker = false,
    NetworkProviderConfig? config,
  }) {
    return GatewayNetworkProvider(
      baseUrl: 'https://testnet-gateway.multiversx.com',
      chainId: const ChainId('T'),
      client: client,
      logger: logger,
      enableCircuitBreaker: enableCircuitBreaker,
      config: config,
    );
  }

  /// Creates provider for devnet.
  factory GatewayNetworkProvider.devnet({
    Dio? client,
    Logger? logger,
    bool enableCircuitBreaker = false,
    NetworkProviderConfig? config,
  }) {
    return GatewayNetworkProvider(
      baseUrl: 'https://devnet-gateway.multiversx.com',
      chainId: const ChainId('D'),
      client: client,
      logger: logger,
      enableCircuitBreaker: enableCircuitBreaker,
      config: config,
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
  String queryContractEndpoint() => 'vm-values/query';

  @override
  String networkStatusEndpoint({int shard = 4294967295}) =>
      'network/status/$shard';

  /// Endpoint for a transaction, always requesting the full result set.
  ///
  /// The proxy omits `smartContractResults` and `logs` unless `withResults` is
  /// set, and cross-shard completion can only be detected by finding the
  /// `completedTxEvent` inside `logs`, so they are requested unconditionally.
  /// `withProcessStatus` does not change the path; the proxy's derived status
  /// lives on `getTransactionStatusEndpoint`.
  @override
  String getTransactionEndpoint(
    String txHash, {
    bool withProcessStatus = false,
  }) => 'transaction/$txHash?withResults=true';

  @override
  String getTransactionStatusEndpoint(String txHash) =>
      'transaction/$txHash/process-status';

  @override
  String simulateTransactionEndpoint() =>
      'transaction/simulate?checkSignature=false';

  @override
  String tokenOfAccountEndpoint(Address address, String tokenIdentifier) =>
      'address/${address.bech32}/esdt/$tokenIdentifier';

  /// Endpoint for a single NFT / SFT / MetaESDT instance held by an account.
  ///
  /// The Gateway splits the balance lookup by nonce:
  /// `address/{bech32}/esdt/{identifier}` serves fungible tokens while
  /// `address/{bech32}/nft/{collection}/nonce/{nonce}` serves everything with
  /// a non-zero nonce. `tokenOfAccountEndpoint` cannot express the nonce, so
  /// this hook backs [getNftOfAccount].
  @protected
  String nftOfAccountEndpoint(Address address, String collection, int nonce) =>
      'address/${address.bech32}/nft/$collection/nonce/$nonce';

  @override
  String fungibleTokensEndpoint(Address address) =>
      'address/${address.bech32}/esdt';

  /// Endpoint listing every ESDT of the account; NFTs are split out locally.
  ///
  /// The Gateway exposes no route that lists only the NFTs of an account:
  /// `address/{bech32}/nft` is not registered on the proxy or on the observer,
  /// and `registered-nfts` returns collections issued by the address rather
  /// than the ones it holds. `parseNonFungibleTokens` therefore reads the same
  /// `address/{bech32}/esdt` payload as [fungibleTokensEndpoint] and keeps the
  /// entries whose nonce is non-zero.
  @override
  String nonFungibleTokensEndpoint(Address address) =>
      'address/${address.bech32}/esdt';

  @override
  String guardianDataEndpoint(Address address) =>
      'address/${address.bech32}/guardian-data';

  @override
  String fungibleTokenDefinitionEndpoint(String identifier) =>
      throw UnsupportedError(
        'Fungible token definition ("$identifier") is not exposed by the '
        'Gateway provider. The MultiversX Gateway has no REST endpoint for '
        'this lookup; the equivalent path on the API is '
        'GET /tokens/{identifier}. Use '
        'ApiNetworkProvider.getDefinitionOfFungibleToken, or query the ESDT '
        'system contract directly via queryContract() if you must stay on '
        'the Gateway (see vm-values/query on the ESDT system contract).',
      );

  @override
  String tokenCollectionDefinitionEndpoint(String collection) =>
      throw UnsupportedError(
        'Collection definition ("$collection") is not exposed by the Gateway '
        'provider. Equivalent API path: GET /collections/{collection}. Use '
        'ApiNetworkProvider.getDefinitionOfTokenCollection, or query the '
        'ESDT system contract directly via queryContract() if you must stay '
        'on the Gateway.',
      );

  @override
  String nonFungibleInstanceEndpoint(String collection, int nonce) =>
      throw UnsupportedError(
        'NFT instance lookup ("$collection-$nonce") is not exposed by the '
        'Gateway provider. Equivalent API path: '
        'GET /nfts/{collection}-{nonceHex}. Use '
        'ApiNetworkProvider.getNonFungibleToken instead.',
      );

  @override
  String blockByHashEndpoint(int shard, String hash) =>
      'block/$shard/by-hash/$hash';

  /// Returns the network-status path for the given shard.
  ///
  /// The gateway requires fetching the latest observed nonce from
  /// `network/status/$shard` before resolving the block. The parser dispatches
  /// based on this returned path.
  @override
  String latestBlockEndpoint(int shard) {
    return 'network/status/$shard';
  }

  @override
  String hyperblockByNonceEndpoint(int nonce) => 'hyperblock/by-nonce/$nonce';

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

  /// The Gateway cannot produce a [NetworkEconomics].
  ///
  /// `GET /network/economics` does exist on the proxy, but it returns the
  /// metachain's `erd_*` metric map: supply, fees, inflation, dev rewards,
  /// staked and top-up values only. Price, market cap, APR, circulating
  /// supply and token market cap are computed by `api.multiversx.com` and
  /// have no source on the Gateway, so the chain metrics are surfaced through
  /// [getGatewayEconomics] instead of being padded with zeros here.
  ///
  /// #### Throws
  /// - `UnsupportedError` - Always; use [getGatewayEconomics] for the chain
  ///   metrics or `ApiNetworkProvider.getNetworkEconomics()` for market data
  @override
  Future<NetworkEconomics> getNetworkEconomics() {
    throw UnsupportedError(
      'getNetworkEconomics is not supported by Gateway provider. The '
      'Gateway route GET /network/economics returns chain metrics only '
      '(no price, marketCap or APR). Use '
      'GatewayNetworkProvider.getGatewayEconomics() for those metrics, or '
      'ApiNetworkProvider.getNetworkEconomics() for market data.',
    );
  }

  /// Fetches the chain economics metrics from `GET /network/economics`.
  ///
  /// Values are atomic `1e-18` amounts exposed as `BigInt`; `totalSupply`
  /// alone exceeds the range of a 64-bit `int` on mainnet. Market data is not
  /// part of this payload — see [getNetworkEconomics].
  ///
  /// #### Returns
  /// `Future<GatewayEconomics>` - Supply, fees, inflation, dev rewards, staked
  /// and top-up values for the current economics epoch
  ///
  /// #### Example
  /// ```dart
  /// final economics = await gateway.getGatewayEconomics();
  /// print(economics.totalSupply);
  /// ```
  Future<GatewayEconomics> getGatewayEconomics() async {
    logger?.debug('Fetching gateway economics');

    final dynamic response = await executeWithCircuitBreaker(
      () => doGetGeneric('network/economics'),
    );
    return GatewayEconomics.fromProxyResponse(
      requireAs<Map<String, dynamic>>(response, 'response'),
    );
  }

  /// Fetches a transaction and overlays the proxy's derived process status.
  ///
  /// `GET /transaction/{hash}` reports the status the executing node recorded
  /// for the transaction itself, while `GET /transaction/{hash}/process-status`
  /// reports the proxy's verdict after walking the whole result tree: a
  /// notarised move-balance that emitted a `signalError` log event is
  /// `success` on the first route and `fail` on the second. This method takes
  /// the second, which is the one that accounts for failures raised by
  /// smart-contract results in other shards.
  ///
  /// The overlay costs a second request per call, so [getTransaction] keeps
  /// its single-request behaviour and this method is opt-in.
  ///
  /// #### Parameters
  /// - `txHash` - Transaction hash to fetch
  ///
  /// #### Returns
  /// `Future<TransactionOnNetwork>` - The transaction carrying the proxy's
  /// process status
  ///
  /// #### Example
  /// ```dart
  /// final tx = await gateway.getTransactionWithProcessStatus(txHash);
  /// if (tx.status.isFailed) {
  ///   print('failed somewhere in the result tree');
  /// }
  /// ```
  Future<TransactionOnNetwork> getTransactionWithProcessStatus(
    String txHash,
  ) async {
    logger?.debug(
      'Fetching transaction with process status',
      context: <String, dynamic>{'txHash': txHash},
    );

    final TransactionOnNetwork transaction = await getTransaction(txHash);
    final TransactionStatus processStatus = await getTransactionStatus(txHash);

    return transaction.copyWith(status: processStatus);
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
      final int numSent =
          optionalAs<int>(response['numOfSentTxs'], 'numOfSentTxs') ?? 0;
      final Map<String, dynamic> txHashesMap =
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
          txHashesMap[i.toString()],
          'txHash[$i]',
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
    final Map<String, dynamic> data = requireAs<Map<String, dynamic>>(
      response,
      'response',
    );
    final Map<String, dynamic> txData =
        optionalAs<Map<String, dynamic>>(data['transaction'], 'transaction') ??
        data;
    return TransactionOnNetwork.fromProxyResponse(txData, txHash: txHash);
  }

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
  List<TokenOnNetwork> parseFungibleTokens(dynamic response) =>
      _parseEsdts(response, fungible: true);

  @override
  List<TokenOnNetwork> parseNonFungibleTokens(dynamic response) =>
      _parseEsdts(response, fungible: false);

  List<TokenOnNetwork> _parseEsdts(dynamic response, {required bool fungible}) {
    if (response is! Map<String, dynamic>) return <TokenOnNetwork>[];
    final dynamic esdts = response['esdts'];
    if (esdts is! Map<String, dynamic>) return <TokenOnNetwork>[];

    final List<TokenOnNetwork> out = <TokenOnNetwork>[];
    for (final MapEntry<String, dynamic> entry in esdts.entries) {
      final Map<String, dynamic> tokenData = requireAs<Map<String, dynamic>>(
        entry.value,
        'esdts[${entry.key}]',
      );
      final int nonce = optionalInt(tokenData['nonce'], 'nonce') ?? 0;
      final bool isFungible = nonce == 0;
      if (isFungible != fungible) continue;
      out.add(
        TokenOnNetwork.fromJson(<String, dynamic>{
          'identifier': entry.key,
          ...tokenData,
        }),
      );
    }
    return out;
  }

  @override
  TokenOnNetwork parseFungibleTokenDefinition(
    dynamic response,
    String identifier,
  ) {
    throw UnsupportedError(
      'Fungible token definition is not exposed by the Gateway provider.',
    );
  }

  @override
  TokenOnNetwork parseTokenCollectionDefinition(
    dynamic response,
    String collection,
  ) {
    throw UnsupportedError(
      'Collection definition is not exposed by the Gateway provider.',
    );
  }

  @override
  TokenOnNetwork parseNonFungibleInstance(
    dynamic response,
    String collection,
    int nonce,
  ) {
    throw UnsupportedError(
      'NFT instance lookup is not exposed by the Gateway provider.',
    );
  }

  @override
  BlockOnNetwork parseBlock(dynamic response) {
    final Map<String, dynamic> data = requireAs<Map<String, dynamic>>(
      response,
      'response',
    );
    final Map<String, dynamic> blockData =
        optionalAs<Map<String, dynamic>>(data['block'], 'block') ?? data;
    return BlockOnNetwork.fromJson(blockData);
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

  /// Fetches the latest block for [shard] via Gateway.
  ///
  /// Gateway does not expose a direct "latest block" endpoint, so this method
  /// first reads `network/status/{shard}` to discover the current nonce and
  /// then fetches the block by nonce.
  @override
  Future<BlockOnNetwork> getLatestBlock({int shard = 4294967295}) async {
    logger?.debug(
      'Fetching latest block via gateway',
      context: <String, dynamic>{'shard': shard.toString()},
    );

    final dynamic statusResponse = await executeWithCircuitBreaker(
      () => doGetGeneric('network/status/$shard'),
    );
    final Map<String, dynamic> statusData = requireAs<Map<String, dynamic>>(
      statusResponse,
      'response',
    );
    final Map<String, dynamic> status =
        optionalAs<Map<String, dynamic>>(statusData['status'], 'status') ??
        statusData;
    final int nonce =
        optionalInt(status['erd_nonce'], 'erd_nonce') ??
        optionalInt(status['nonce'], 'nonce') ??
        0;

    final dynamic blockResponse = await executeWithCircuitBreaker(
      () => doGetGeneric('block/$shard/by-nonce/$nonce'),
    );
    return parseBlock(blockResponse);
  }

  /// Fetches the balance of one NFT / SFT / MetaESDT held by [address].
  ///
  /// `getTokenOfAccount` can only reach the fungible route because it has no
  /// nonce parameter. The Gateway serves any non-zero nonce from
  /// `address/{bech32}/nft/{collection}/nonce/{nonce}` instead, which is the
  /// route this method uses.
  ///
  /// #### Parameters
  /// - `address` - Holder of the instance
  /// - `collection` - Collection identifier, e.g. `COLL-123456`
  /// - `nonce` - Instance nonce inside the collection
  ///
  /// #### Returns
  /// `Future<TokenOnNetwork>` - Balance and metadata of the instance, with
  /// `identifier` normalised to `{collection}-{nonceHex}`
  ///
  /// #### Example
  /// ```dart
  /// final nft = await gateway.getNftOfAccount(address, 'COLL-123456', 3);
  /// print(nft.identifier); // COLL-123456-03
  /// ```
  Future<TokenOnNetwork> getNftOfAccount(
    Address address,
    String collection,
    int nonce,
  ) async {
    logger?.debug(
      'Fetching NFT of account',
      context: <String, dynamic>{
        'address': address.bech32,
        'collection': collection,
        'nonce': nonce.toString(),
      },
    );

    final dynamic response = await executeWithCircuitBreaker(
      () => doGetGeneric(nftOfAccountEndpoint(address, collection, nonce)),
    );
    final Map<String, dynamic> data = requireAs<Map<String, dynamic>>(
      response,
      'response',
    );
    final Map<String, dynamic> tokenData =
        optionalAs<Map<String, dynamic>>(data['tokenData'], 'tokenData') ??
        data;
    return TokenOnNetwork.fromJson(<String, dynamic>{
      ...tokenData,
      'identifier': '$collection-${_nonceToEvenLengthHex(nonce)}',
      'balance': tokenData['balance'] ?? '0',
      'nonce': tokenData['nonce'] ?? nonce,
    });
  }

  /// Fetches the fungible ESDTs of [address], paginating client-side.
  ///
  /// The Gateway route returns the account's complete ESDT map and ignores
  /// unknown query parameters, so `?from=&size=` would be dropped silently by
  /// the proxy. Slicing the parsed list honours the caller's intent instead.
  @override
  Future<List<TokenOnNetwork>> getFungibleTokensOfAccount(
    Address address, {
    int? from,
    int? size,
  }) async {
    final List<TokenOnNetwork> tokens = await super.getFungibleTokensOfAccount(
      address,
    );
    return _paginateLocally(tokens, from: from, size: size);
  }

  /// Fetches the non-fungible ESDTs of [address], paginating client-side.
  ///
  /// Same constraint as [getFungibleTokensOfAccount]: both read the single
  /// `address/{bech32}/esdt` payload, which the proxy never paginates.
  @override
  Future<List<TokenOnNetwork>> getNonFungibleTokensOfAccount(
    Address address, {
    int? from,
    int? size,
  }) async {
    final List<TokenOnNetwork> tokens = await super
        .getNonFungibleTokensOfAccount(address);
    return _paginateLocally(tokens, from: from, size: size);
  }

  List<TokenOnNetwork> _paginateLocally(
    List<TokenOnNetwork> tokens, {
    int? from,
    int? size,
  }) {
    if (from == null && size == null) return tokens;
    final int total = tokens.length;
    int start = from ?? 0;
    if (start < 0) start = 0;
    if (start > total) start = total;
    int end = size == null ? total : start + size;
    if (end < start) end = start;
    if (end > total) end = total;
    return tokens.sublist(start, end);
  }

  static String _nonceToEvenLengthHex(int nonce) {
    String hex = nonce.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';
    if (hex.length < 2) hex = hex.padLeft(2, '0');
    return hex;
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
        if (error is Map<String, dynamic>) {
          final String? nested = optionalAs<String>(
            error['message'],
            'message',
          );
          if (nested != null && nested.isNotEmpty) return nested;
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
