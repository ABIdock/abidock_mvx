import '../abi/abi.dart';
import '../core/address.dart';
import '../core/transaction/chain_id.dart';
import '../core/transaction/controllers/base_controller.dart';
import '../core/transaction/factories/delegation_transactions_factory.dart';
import '../core/transaction/factories/governance_transactions_factory.dart';
import '../core/transaction/factories/multisig_transactions_factory.dart';
import '../core/transaction/factories/token_management_transactions_factory.dart';
import '../core/transaction/factories/transfer_transactions_factory.dart';
import '../core/transaction/factories/validators_transactions_factory.dart';
import '../core/transaction/transaction_watcher.dart';
import '../core/transaction/transactions_factory_config.dart';
import '../infrastructure/network/api_network_provider.dart';
import '../infrastructure/network/gateway_network_provider.dart';
import '../infrastructure/network/network_provider_config.dart';

/// Public REST endpoints for the official MultiversX networks.
///
/// Covers both the API hosts (used by [NetworkEntrypoint] ->
/// [ApiNetworkProvider]) and the Gateway hosts (used by
/// [ProxyNetworkEntrypoint] -> [GatewayNetworkProvider]).
class EntrypointUrls {
  EntrypointUrls._();

  /// Devnet public API.
  static const String devnet = 'https://devnet-api.multiversx.com';

  /// Testnet public API.
  static const String testnet = 'https://testnet-api.multiversx.com';

  /// Mainnet public API.
  static const String mainnet = 'https://api.multiversx.com';

  /// Devnet public Gateway (Proxy).
  static const String devnetGateway = 'https://devnet-gateway.multiversx.com';

  /// Testnet public Gateway (Proxy).
  static const String testnetGateway = 'https://testnet-gateway.multiversx.com';

  /// Mainnet public Gateway (Proxy).
  static const String mainnetGateway = 'https://gateway.multiversx.com';
}

/// Top-level façade over the SDK.
///
/// Constructs an [ApiNetworkProvider] for the given `url` / `chainId` and
/// exposes one-liner factories that return the SDK's existing controllers and
/// factories without adding new behavior. Use the subclasses
/// [DevnetEntrypoint], [TestnetEntrypoint], or [MainnetEntrypoint] for the
/// public network defaults.
///
/// #### Example
/// ```dart
/// final entrypoint = DevnetEntrypoint();
/// final provider = entrypoint.createNetworkProvider();
/// final transfers = entrypoint.createTransfersFactory();
/// ```
class NetworkEntrypoint {
  /// Creates a network entrypoint.
  ///
  /// #### Parameters
  /// - `url` - HTTP(S) base URL of the API node.
  /// - `chainId` - Chain identifier that all factories will tag transactions
  ///   with.
  /// - `networkProviderConfig` - Optional configuration forwarded to the
  ///   constructed [ApiNetworkProvider]. If `clientName` is also supplied,
  ///   it overrides the matching field on this config.
  /// - `clientName` - Optional `User-Agent` suffix forwarded to the
  ///   `NetworkProviderConfig`. Convenience shortcut so callers do not need
  ///   to build a config just to set the client name.
  /// - `gasLimitEstimator` - Optional gas-limit estimator shared with every
  ///   controller this entrypoint creates.
  NetworkEntrypoint({
    required this.url,
    required this.chainId,
    NetworkProviderConfig? networkProviderConfig,
    String? clientName,
    this.gasLimitEstimator,
  }) : networkProviderConfig = _mergeClientName(
         networkProviderConfig,
         clientName,
       );

  /// Base URL of the underlying API node.
  final String url;

  /// Chain id every factory will tag transactions with.
  final ChainId chainId;

  /// Effective `NetworkProviderConfig`. Always non-null when `clientName` was
  /// supplied; otherwise may be null and providers fall back to defaults.
  final NetworkProviderConfig? networkProviderConfig;

  /// Optional gas-limit estimator for controllers that accept one.
  final IGasLimitEstimator? gasLimitEstimator;

  /// Cached shared factory config built once per entrypoint instance.
  late final TransactionsFactoryConfig _sharedConfig =
      TransactionsFactoryConfig(chainId: chainId);

  /// Single cached [ApiNetworkProvider] reused across every `create*` call.
  late final ApiNetworkProvider _provider = ApiNetworkProvider(
    baseUrl: url,
    chainId: chainId,
    config: networkProviderConfig,
  );

  /// Returns the cached [ApiNetworkProvider]. Multiple calls return the same
  /// instance for the lifetime of this entrypoint.
  ApiNetworkProvider createNetworkProvider() => _provider;

  /// Creates a [SmartContractController] for [address] using [abi].
  SmartContractController createSmartContractController({
    required SmartContractAbi abi,
    required Address address,
  }) => SmartContractController(
    contractAddress: address,
    networkProvider: createNetworkProvider(),
    abi: abi,
    gasLimitEstimator: gasLimitEstimator,
  );

  /// Creates a [TransferTransactionsFactory] for [chainId].
  TransferTransactionsFactory createTransfersFactory() =>
      TransferTransactionsFactory(
        config: TransferTransactionsConfig.fromShared(_sharedConfig),
      );

  /// Creates a [TokenManagementTransactionsFactory] for [chainId].
  TokenManagementTransactionsFactory createTokenManagementFactory() =>
      TokenManagementTransactionsFactory(
        config: TokenManagementConfig.fromShared(_sharedConfig),
      );

  /// Creates a [DelegationTransactionsFactory] for [chainId].
  DelegationTransactionsFactory createDelegationFactory() =>
      DelegationTransactionsFactory(
        DelegationTransactionsConfig.fromShared(_sharedConfig),
      );

  /// Creates a [MultisigTransactionsFactory] for [chainId].
  MultisigTransactionsFactory createMultisigFactory() =>
      MultisigTransactionsFactory(
        MultisigTransactionsConfig.fromShared(_sharedConfig),
      );

  /// Creates a [ValidatorsTransactionsFactory] for [chainId].
  ValidatorsTransactionsFactory createValidatorsFactory() =>
      ValidatorsTransactionsFactory(
        ValidatorsTransactionsConfig.fromShared(_sharedConfig),
      );

  /// Creates a [GovernanceTransactionsFactory] for [chainId].
  GovernanceTransactionsFactory createGovernanceFactory() =>
      GovernanceTransactionsFactory(
        GovernanceTransactionsConfig.fromShared(_sharedConfig),
      );

  /// Creates a [MultisigController] for [chainId].
  MultisigController createMultisigController() => MultisigController(
    chainId: chainId,
    networkProvider: createNetworkProvider(),
    gasLimitEstimator: gasLimitEstimator,
  );

  /// Creates a [ValidatorsController] for [chainId].
  ValidatorsController createValidatorsController() => ValidatorsController(
    chainId: chainId,
    networkProvider: createNetworkProvider(),
    gasLimitEstimator: gasLimitEstimator,
  );

  /// Creates a [GovernanceController] for [chainId].
  GovernanceController createGovernanceController() => GovernanceController(
    chainId: chainId,
    networkProvider: createNetworkProvider(),
    gasLimitEstimator: gasLimitEstimator,
  );

  /// Creates a [TransactionWatcher] bound to the cached network provider.
  TransactionWatcher createTransactionWatcher() =>
      TransactionWatcher(networkProvider: createNetworkProvider());
}

/// Merges a free-standing `clientName` into a [NetworkProviderConfig].
///
/// If both are null, returns null. If only `clientName` is provided, builds a
/// minimal config with just that field. If both are provided, the explicit
/// `clientName` overrides the value on `existing` and every other field of
/// `existing` — headers, request timeout, base URL override, retry, throttle
/// and cache policies — is carried over unchanged.
///
/// #### Parameters
/// - `existing` - Config supplied by the caller, or `null`.
/// - `clientName` - `User-Agent` suffix that wins over `existing.clientName`.
///
/// #### Returns
/// The effective config, or `null` when the caller supplied neither.
NetworkProviderConfig? _mergeClientName(
  NetworkProviderConfig? existing,
  String? clientName,
) {
  if (clientName == null) {
    return existing;
  }
  if (existing == null) {
    return NetworkProviderConfig(clientName: clientName);
  }
  return NetworkProviderConfig(
    clientName: clientName,
    headers: existing.headers,
    requestTimeout: existing.requestTimeout,
    baseUrl: existing.baseUrl,
    retryPolicy: existing.retryPolicy,
    throttlePolicy: existing.throttlePolicy,
    cachePolicy: existing.cachePolicy,
  );
}

/// Devnet-flavoured [NetworkEntrypoint].
class DevnetEntrypoint extends NetworkEntrypoint {
  /// Creates a devnet entrypoint pre-filled with the public devnet API.
  DevnetEntrypoint({
    super.networkProviderConfig,
    super.clientName,
    super.gasLimitEstimator,
  }) : super(url: EntrypointUrls.devnet, chainId: const ChainId('D'));
}

/// Testnet-flavoured [NetworkEntrypoint].
class TestnetEntrypoint extends NetworkEntrypoint {
  /// Creates a testnet entrypoint pre-filled with the public testnet API.
  TestnetEntrypoint({
    super.networkProviderConfig,
    super.clientName,
    super.gasLimitEstimator,
  }) : super(url: EntrypointUrls.testnet, chainId: const ChainId('T'));
}

/// Mainnet-flavoured [NetworkEntrypoint].
class MainnetEntrypoint extends NetworkEntrypoint {
  /// Creates a mainnet entrypoint pre-filled with the public mainnet API.
  MainnetEntrypoint({
    super.networkProviderConfig,
    super.clientName,
    super.gasLimitEstimator,
  }) : super(url: EntrypointUrls.mainnet, chainId: const ChainId('1'));
}

/// Gateway (Proxy) variant of [NetworkEntrypoint].
///
/// Identical surface to [NetworkEntrypoint] but builds a
/// [GatewayNetworkProvider] (the MultiversX Proxy) instead of the
/// indexer-backed [ApiNetworkProvider]. Use this when you need direct node
/// access (e.g.
/// custom vm-values queries, raw protocol fields) at the cost of richer
/// indexer-side features (token lists, NFT metadata) that only the API
/// exposes.
///
/// #### Example
/// ```dart
/// final entrypoint = MainnetProxyEntrypoint();
/// final provider = entrypoint.createNetworkProvider();
/// final transfers = entrypoint.createTransfersFactory();
/// ```
class ProxyNetworkEntrypoint {
  /// Creates a proxy/gateway entrypoint.
  ///
  /// #### Parameters
  /// - `url` - HTTP(S) base URL of the MultiversX Gateway.
  /// - `chainId` - Chain identifier that all factories will tag transactions
  ///   with.
  /// - `networkProviderConfig` - Optional configuration forwarded to the
  ///   constructed [GatewayNetworkProvider]. If `clientName` is also
  ///   supplied, it overrides the matching field on this config.
  /// - `clientName` - Optional `User-Agent` suffix forwarded to the
  ///   `NetworkProviderConfig`.
  /// - `gasLimitEstimator` - Optional gas-limit estimator shared with every
  ///   controller this entrypoint creates.
  ProxyNetworkEntrypoint({
    required this.url,
    required this.chainId,
    NetworkProviderConfig? networkProviderConfig,
    String? clientName,
    this.gasLimitEstimator,
  }) : networkProviderConfig = _mergeClientName(
         networkProviderConfig,
         clientName,
       );

  /// Base URL of the underlying Gateway.
  final String url;

  /// Chain id every factory will tag transactions with.
  final ChainId chainId;

  /// Effective `NetworkProviderConfig`. Always non-null when `clientName` was
  /// supplied; otherwise may be null and providers fall back to defaults.
  final NetworkProviderConfig? networkProviderConfig;

  /// Optional gas-limit estimator for controllers that accept one.
  final IGasLimitEstimator? gasLimitEstimator;

  /// Cached shared factory config built once per entrypoint instance.
  late final TransactionsFactoryConfig _sharedConfig =
      TransactionsFactoryConfig(chainId: chainId);

  /// Single cached [GatewayNetworkProvider] reused across every `create*`
  /// call.
  late final GatewayNetworkProvider _provider = GatewayNetworkProvider(
    baseUrl: url,
    chainId: chainId,
    config: networkProviderConfig,
  );

  /// Returns the cached [GatewayNetworkProvider]. Multiple calls return the
  /// same instance for the lifetime of this entrypoint.
  GatewayNetworkProvider createNetworkProvider() => _provider;

  /// Creates a [SmartContractController] for [address] using [abi].
  SmartContractController createSmartContractController({
    required SmartContractAbi abi,
    required Address address,
  }) => SmartContractController(
    contractAddress: address,
    networkProvider: createNetworkProvider(),
    abi: abi,
    gasLimitEstimator: gasLimitEstimator,
  );

  /// Creates a [TransferTransactionsFactory] for [chainId].
  TransferTransactionsFactory createTransfersFactory() =>
      TransferTransactionsFactory(
        config: TransferTransactionsConfig.fromShared(_sharedConfig),
      );

  /// Creates a [TokenManagementTransactionsFactory] for [chainId].
  TokenManagementTransactionsFactory createTokenManagementFactory() =>
      TokenManagementTransactionsFactory(
        config: TokenManagementConfig.fromShared(_sharedConfig),
      );

  /// Creates a [DelegationTransactionsFactory] for [chainId].
  DelegationTransactionsFactory createDelegationFactory() =>
      DelegationTransactionsFactory(
        DelegationTransactionsConfig.fromShared(_sharedConfig),
      );

  /// Creates a [MultisigTransactionsFactory] for [chainId].
  MultisigTransactionsFactory createMultisigFactory() =>
      MultisigTransactionsFactory(
        MultisigTransactionsConfig.fromShared(_sharedConfig),
      );

  /// Creates a [ValidatorsTransactionsFactory] for [chainId].
  ValidatorsTransactionsFactory createValidatorsFactory() =>
      ValidatorsTransactionsFactory(
        ValidatorsTransactionsConfig.fromShared(_sharedConfig),
      );

  /// Creates a [GovernanceTransactionsFactory] for [chainId].
  GovernanceTransactionsFactory createGovernanceFactory() =>
      GovernanceTransactionsFactory(
        GovernanceTransactionsConfig.fromShared(_sharedConfig),
      );

  /// Creates a [MultisigController] for [chainId].
  MultisigController createMultisigController() => MultisigController(
    chainId: chainId,
    networkProvider: createNetworkProvider(),
    gasLimitEstimator: gasLimitEstimator,
  );

  /// Creates a [ValidatorsController] for [chainId].
  ValidatorsController createValidatorsController() => ValidatorsController(
    chainId: chainId,
    networkProvider: createNetworkProvider(),
    gasLimitEstimator: gasLimitEstimator,
  );

  /// Creates a [GovernanceController] for [chainId].
  GovernanceController createGovernanceController() => GovernanceController(
    chainId: chainId,
    networkProvider: createNetworkProvider(),
    gasLimitEstimator: gasLimitEstimator,
  );

  /// Creates a [TransactionWatcher] bound to the cached gateway provider.
  TransactionWatcher createTransactionWatcher() =>
      TransactionWatcher(networkProvider: createNetworkProvider());
}

/// Devnet-flavoured [ProxyNetworkEntrypoint].
class DevnetProxyEntrypoint extends ProxyNetworkEntrypoint {
  /// Creates a devnet proxy entrypoint pre-filled with the public devnet
  /// Gateway.
  DevnetProxyEntrypoint({
    super.networkProviderConfig,
    super.clientName,
    super.gasLimitEstimator,
  }) : super(url: EntrypointUrls.devnetGateway, chainId: const ChainId('D'));
}

/// Testnet-flavoured [ProxyNetworkEntrypoint].
class TestnetProxyEntrypoint extends ProxyNetworkEntrypoint {
  /// Creates a testnet proxy entrypoint pre-filled with the public testnet
  /// Gateway.
  TestnetProxyEntrypoint({
    super.networkProviderConfig,
    super.clientName,
    super.gasLimitEstimator,
  }) : super(url: EntrypointUrls.testnetGateway, chainId: const ChainId('T'));
}

/// Mainnet-flavoured [ProxyNetworkEntrypoint].
class MainnetProxyEntrypoint extends ProxyNetworkEntrypoint {
  /// Creates a mainnet proxy entrypoint pre-filled with the public mainnet
  /// Gateway.
  MainnetProxyEntrypoint({
    super.networkProviderConfig,
    super.clientName,
    super.gasLimitEstimator,
  }) : super(url: EntrypointUrls.mainnetGateway, chainId: const ChainId('1'));
}
