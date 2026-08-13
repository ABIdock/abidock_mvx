/// Network configuration parameters from the blockchain.
/// Contains chain ID, gas parameters, transaction requirements, and timing configuration.

import 'dart:developer' as developer;

import '../../utils/helpers.dart';
import '../../utils/json_utils.dart';

class NetworkConfig {
  /// Creates network configuration with all required parameters.
  ///
  /// #### Parameters
  /// - `chainId` - Chain identifier (e.g., 'D', '1', 'T')
  /// - `gasPerDataByte` - Gas cost per byte of transaction data
  /// - `minGasLimit` - Minimum gas limit for any transaction
  /// - `minGasPrice` - Minimum gas price accepted by network
  /// - `minTransactionVersion` - Minimum transaction version required
  /// - `roundsPerEpoch` - Number of rounds in one epoch
  /// - `roundDuration` - Duration of one round in milliseconds
  /// - `topUpFactor` - Top-up factor for staking rewards
  /// - `extraGasLimitGuardedTx` - Extra gas limit for guarded transactions
  /// - `extraGasLimitRelayedTx` - Extra gas limit for relayed transactions
  /// - `maxGasPerTransaction` - Maximum gas limit allowed per transaction
  /// - `numShards` - Number of shards (excluding metachain)
  /// - `denomination` - Token denomination (number of decimals, default 18)
  /// - `gasPriceModifier` - Gas price modifier (`double` multiplier in `[0,1]`)
  /// - `adaptivity` - Network adaptivity flag
  /// - `hysteresis` - Hysteresis value for network
  /// - `latestTagSoftwareVersion` - Latest software version tag
  /// - `metaConsensusGroupSize` - Meta consensus group size
  /// - `numMetachainNodes` - Number of metachain nodes
  /// - `numNodesInShard` - Number of nodes per shard
  /// - `rewardsTopUpGradientPoint` - Rewards top-up gradient point
  /// - `shardConsensusGroupSize` - Shard consensus group size
  /// - `startTime` - Network start timestamp
  /// - `genesisTimestamp` - Optional genesis timestamp (`BigInt`)
  const NetworkConfig({
    required this.chainId,
    required this.gasPerDataByte,
    required this.minGasLimit,
    required this.minGasPrice,
    required this.minTransactionVersion,
    required this.roundsPerEpoch,
    required this.roundDuration,
    required this.topUpFactor,
    this.extraGasLimitGuardedTx = 50000,
    this.extraGasLimitRelayedTx = 50000,
    this.maxGasPerTransaction = 600000000,
    this.numShards = 3,
    this.denomination = 18,
    this.gasPriceModifier = 0.01,
    this.adaptivity = false,
    this.hysteresis = '0.2',
    this.latestTagSoftwareVersion,
    this.metaConsensusGroupSize,
    this.numMetachainNodes,
    this.numNodesInShard,
    this.rewardsTopUpGradientPoint,
    this.shardConsensusGroupSize,
    this.startTime,
    this._genesisTimestamp,
  });

  /// Creates configuration from REST API response.
  ///
  /// #### Parameters
  /// - `data` - JSON response from `/network/config` endpoint
  ///
  /// #### Returns
  /// `NetworkConfig` - Instance with parsed parameters
  factory NetworkConfig.fromApiResponse(Map<String, dynamic> data) {
    final Map<String, dynamic> config = _extractConfigSection(data);
    return _fromConfigMap(config);
  }

  /// Creates configuration from Gateway/Proxy response.
  ///
  /// #### Parameters
  /// - `data` - JSON response from Gateway `/network/config` endpoint with nested 'config' object
  ///
  /// #### Returns
  /// `NetworkConfig` - Instance with parsed parameters
  factory NetworkConfig.fromProxyResponse(Map<String, dynamic> data) {
    final Map<String, dynamic> config = _extractConfigSection(data);
    return _fromConfigMap(config);
  }

  /// Chain ID.
  final String chainId;

  /// Gas cost per data byte.
  final int gasPerDataByte;

  /// Minimum gas limit.
  final int minGasLimit;

  /// Minimum gas price.
  final int minGasPrice;

  /// Minimum transaction version.
  final int minTransactionVersion;

  /// Rounds per epoch.
  final int roundsPerEpoch;

  /// Round duration in milliseconds.
  final int roundDuration;

  /// Top-up factor for staking rewards.
  final double topUpFactor;

  /// Extra gas limit required for guarded (guardian) transactions.
  final int extraGasLimitGuardedTx;

  /// Extra gas limit required for relayed transactions.
  final int extraGasLimitRelayedTx;

  /// Maximum gas limit allowed per transaction.
  final int maxGasPerTransaction;

  /// Number of shards (excluding metachain).
  final int numShards;

  /// Token denomination (number of decimals, typically 18 for EGLD).
  final int denomination;

  /// Gas price modifier applied to the processing-gas portion of the fee.
  ///
  /// The chain reports this as a multiplier in `[0, 1]` (typically `0.01`),
  /// so only the movement-gas share of a transaction is billed at full price.
  final double gasPriceModifier;

  /// Whether network adaptivity is enabled.
  final bool adaptivity;

  /// Hysteresis value for network consensus.
  final String hysteresis;

  /// Latest software version tag.
  final String? latestTagSoftwareVersion;

  /// Meta consensus group size.
  final int? metaConsensusGroupSize;

  /// Number of metachain nodes.
  final int? numMetachainNodes;

  /// Number of nodes in each shard.
  final int? numNodesInShard;

  /// Rewards top-up gradient point.
  final String? rewardsTopUpGradientPoint;

  /// Shard consensus group size.
  final int? shardConsensusGroupSize;

  /// Network start timestamp (Unix timestamp).
  final int? startTime;

  /// Genesis timestamp expressed as a `BigInt`.
  ///
  /// Defaults to the value of `startTime` when not provided explicitly.
  BigInt? get genesisTimestamp =>
      _genesisTimestamp ?? (startTime != null ? BigInt.from(startTime!) : null);

  final BigInt? _genesisTimestamp;

  /// Long-form alias for [extraGasLimitGuardedTx].
  int get extraGasLimitForGuardedTransactions => extraGasLimitGuardedTx;

  /// Long-form alias for [extraGasLimitRelayedTx].
  int get extraGasLimitForRelayedTransactions => extraGasLimitRelayedTx;

  static NetworkConfig _fromConfigMap(Map<String, dynamic> config) {
    final String? chainId = optionalAs<String>(
      config['erd_chain_id'],
      'erd_chain_id',
    );
    if (chainId == null || chainId.isEmpty) {
      throw const FormatException('Network config missing erd_chain_id');
    }

    if (!const <String>{'D', '1', 'T'}.contains(chainId)) {
      developer.log(
        'Unrecognized chain ID: "$chainId". '
        'Expected one of: "D" (devnet), "1" (mainnet), "T" (testnet).',
        name: 'NetworkConfig',
        level: 900,
      );
    }

    return NetworkConfig(
      chainId: chainId,
      gasPerDataByte: JsonUtils.parseInt(config['erd_gas_per_data_byte'], 1500),
      minGasLimit: JsonUtils.parseInt(config['erd_min_gas_limit'], 50000),
      minGasPrice: JsonUtils.parseInt(config['erd_min_gas_price'], 1000000000),
      minTransactionVersion: JsonUtils.parseInt(
        config['erd_min_transaction_version'],
        1,
      ),
      roundsPerEpoch: JsonUtils.parseInt(config['erd_rounds_per_epoch'], 14400),
      roundDuration: JsonUtils.parseInt(config['erd_round_duration'], 6000),
      topUpFactor: JsonUtils.parseDouble(config['erd_top_up_factor'], 0.5),
      extraGasLimitGuardedTx: JsonUtils.parseInt(
        config['erd_extra_gas_limit_guarded_tx'],
        50000,
      ),
      extraGasLimitRelayedTx: JsonUtils.parseInt(
        config['erd_extra_gas_limit_relayed_tx'],
        50000,
      ),
      maxGasPerTransaction: JsonUtils.parseInt(
        config['erd_max_gas_per_transaction'],
        600000000,
      ),
      numShards: JsonUtils.parseInt(config['erd_num_shards_without_meta'], 3),
      denomination: JsonUtils.parseInt(config['erd_denomination'], 18),
      gasPriceModifier: JsonUtils.parseDouble(
        config['erd_gas_price_modifier'],
        0.01,
      ),
      adaptivity: config['erd_adaptivity'] == true,
      hysteresis: config['erd_hysteresis']?.toString() ?? '0.2',
      latestTagSoftwareVersion: optionalAs<String>(
        config['erd_latest_tag_software_version'],
        'erd_latest_tag_software_version',
      ),
      metaConsensusGroupSize: config['erd_meta_consensus_group_size'] != null
          ? JsonUtils.parseInt(config['erd_meta_consensus_group_size'], 0)
          : null,
      numMetachainNodes: config['erd_num_metachain_nodes'] != null
          ? JsonUtils.parseInt(config['erd_num_metachain_nodes'], 0)
          : null,
      numNodesInShard: config['erd_num_nodes_in_shard'] != null
          ? JsonUtils.parseInt(config['erd_num_nodes_in_shard'], 0)
          : null,
      rewardsTopUpGradientPoint: optionalAs<String>(
        config['erd_rewards_top_up_gradient_point'],
        'erd_rewards_top_up_gradient_point',
      ),
      shardConsensusGroupSize: config['erd_shard_consensus_group_size'] != null
          ? JsonUtils.parseInt(config['erd_shard_consensus_group_size'], 0)
          : null,
      startTime: config['erd_start_time'] != null
          ? JsonUtils.parseInt(config['erd_start_time'], 0)
          : null,
      genesisTimestamp: config['erd_start_time'] != null
          ? BigInt.from(JsonUtils.parseInt(config['erd_start_time'], 0))
          : null,
    );
  }

  static Map<String, dynamic> _extractConfigSection(
    Map<String, dynamic> payload,
  ) {
    final dynamic directConfig = payload['config'];
    if (directConfig is Map<String, dynamic>) {
      return directConfig;
    }

    final dynamic dataSection = payload['data'];
    if (dataSection is Map<String, dynamic>) {
      final dynamic nestedConfig = dataSection['config'];
      if (nestedConfig is Map<String, dynamic>) {
        return nestedConfig;
      }
      return dataSection;
    }

    if (payload.containsKey('erd_chain_id')) {
      return payload;
    }

    throw const FormatException('Unsupported network config payload shape');
  }

  @override
  String toString() =>
      'NetworkConfig(chainId: $chainId, '
      'gasPerDataByte: $gasPerDataByte, '
      'minGasLimit: $minGasLimit, '
      'minGasPrice: $minGasPrice)';
}
