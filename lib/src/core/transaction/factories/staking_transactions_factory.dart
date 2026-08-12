/// Factory for validator staking transactions against the direct-staking
/// system smart contract (not the delegation manager).
///
/// Covers `stake`, `unStake`, `unBond`, `claim`, `changeRewardAddress`,
/// `changeValidatorKeys`, `unJail`, `reStakeUnStakedNodes`. The BLS
/// signatures accompanying validator-public-key arguments must be produced
/// outside this SDK, by whichever operator tool holds the validator secret
/// keys.
import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart' as convert;

import '../../../wallet/validator_keys.dart';
import '../../address.dart';
import '../../balance.dart';
import '../../nonce.dart';
import '../chain_id.dart';
import '../gas_models/gas_limit.dart';
import '../gas_models/gas_price.dart';
import '../transaction.dart';
import '../transaction_version.dart';
import '../transactions_factory_config.dart';

/// Validator ("auction") system smart contract address, in hex; its last four
/// bytes are `0001ffff`.
///
/// Direct staking calls are addressed here, not to the staking system
/// contract: every entry point on the staking contract requires the caller to
/// be the validator contract itself, so a wallet-signed transaction sent
/// straight to the staking contract can never succeed.
///
/// DO NOT change this constant: it is the on-chain address of a fixed system
/// contract, and [stakingContractBech32] is its bech32 form of the same bytes.
const String stakingContractAddressHex =
    '000000000000000000010000000000000000000000000000000000000001ffff';

/// Validator ("auction") system smart contract address, in bech32 form.
const String stakingContractBech32 =
    'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqplllst77y4l';

/// Gas + per-op defaults for the staking factory.
class StakingTransactionsConfig {
  const StakingTransactionsConfig({
    required this.chainId,
    this.minGasLimit = 50000,
    this.gasLimitPerByte = 1500,
    this.gasLimitStake = 5_000_000,
    this.gasLimitUnstake = 5_000_000,
    this.gasLimitUnbond = 5_000_000,
    this.gasLimitClaim = 6_000_000,
    this.gasLimitChangeRewardAddress = 6_000_000,
    this.gasLimitChangeValidatorKeys = 6_000_000,
    this.gasLimitUnjail = 5_000_000,
    this.gasLimitRestakeUnstakedNodes = 6_000_000,
    this.gasLimitUnjailCost = '2500000000000000000',
    this.defaultGasPrice = 1000000000,
  });

  /// Derives a [StakingTransactionsConfig] from a shared
  /// [TransactionsFactoryConfig].
  ///
  /// #### Parameters
  /// - `shared` - Aggregate factory config populated by `NetworkEntrypoint`.
  ///
  /// #### Returns
  /// `StakingTransactionsConfig` populated from the shared chain id and
  /// stake / unstake / unbond / unjail / restake gas-limit fields.
  static StakingTransactionsConfig fromShared(
    TransactionsFactoryConfig shared,
  ) => StakingTransactionsConfig(
    chainId: shared.chainId,
    minGasLimit: shared.minGasLimit,
    gasLimitPerByte: shared.gasLimitPerByte,
    gasLimitStake: shared.gasLimitStake,
    gasLimitUnstake: shared.gasLimitUnstake,
    gasLimitUnbond: shared.gasLimitUnbond,
    gasLimitRestakeUnstakedNodes: shared.gasLimitRestakeUnstakedNodes,
  );

  final ChainId chainId;
  final int minGasLimit;
  final int gasLimitPerByte;
  final int gasLimitStake;
  final int gasLimitUnstake;
  final int gasLimitUnbond;
  final int gasLimitClaim;
  final int gasLimitChangeRewardAddress;
  final int gasLimitChangeValidatorKeys;
  final int gasLimitUnjail;
  final int gasLimitRestakeUnstakedNodes;
  final String gasLimitUnjailCost;
  final int defaultGasPrice;
}

/// A BLS validator public key paired with the BLS signature proving key
/// ownership. Both halves must be produced externally; this SDK only
/// shuttles them into the staking tx data field.
class SignedValidatorPublicKey {
  const SignedValidatorPublicKey({
    required this.publicKey,
    required this.signature,
  });

  final ValidatorPublicKey publicKey;

  /// 96-byte BLS signature of the validator's owner address.
  final Uint8List signature;
}

/// Builds transactions against the direct-staking system SC.
class StakingTransactionsFactory {
  StakingTransactionsFactory(this.config)
    : _stakingContract = Address.fromBech32(stakingContractBech32);

  final StakingTransactionsConfig config;
  final Address _stakingContract;

  /// Stake one or more validator nodes with `amount` EGLD at risk.
  Transaction createTransactionForStaking({
    required Address sender,
    required int numNodes,
    required List<SignedValidatorPublicKey> nodes,
    required Balance amount,
    String rewardAddress = '',
  }) {
    if (nodes.length != numNodes) {
      throw ArgumentError(
        'numNodes ($numNodes) does not match nodes list length (${nodes.length})',
      );
    }
    final StringBuffer data = StringBuffer('stake')
      ..write('@')
      ..write(
        numNodes
            .toRadixString(16)
            .padLeft(2, '0')
            .padLeft((numNodes.toRadixString(16).length + 1) & ~1, '0'),
      );
    for (final SignedValidatorPublicKey node in nodes) {
      data
        ..write('@')
        ..write(convert.hex.encode(node.publicKey.bytes))
        ..write('@')
        ..write(convert.hex.encode(node.signature));
    }
    if (rewardAddress.isNotEmpty) {
      data
        ..write('@')
        ..write(convert.hex.encode(Address.fromBech32(rewardAddress).bytes));
    }
    final int gas = config.gasLimitStake * numNodes;
    return _build(
      sender: sender,
      data: data.toString(),
      gas: gas,
      value: amount,
    );
  }

  /// Request that [publicKeys] be removed from active staking.
  Transaction createTransactionForUnstaking({
    required Address sender,
    required List<ValidatorPublicKey> publicKeys,
  }) {
    return _multiKey(
      sender: sender,
      functionName: 'unStake',
      publicKeys: publicKeys,
      gasPerKey: config.gasLimitUnstake,
    );
  }

  /// Withdraw stake after the unbonding period has elapsed.
  Transaction createTransactionForUnbonding({
    required Address sender,
    required List<ValidatorPublicKey> publicKeys,
  }) {
    return _multiKey(
      sender: sender,
      functionName: 'unBond',
      publicKeys: publicKeys,
      gasPerKey: config.gasLimitUnbond,
    );
  }

  /// Claim accrued validator rewards.
  Transaction createTransactionForClaimingRewards({required Address sender}) {
    return _build(sender: sender, data: 'claim', gas: config.gasLimitClaim);
  }

  /// Re-stake rewards that are currently in the unstaked bucket.
  Transaction createTransactionForRestakingUnstakedNodes({
    required Address sender,
    required List<ValidatorPublicKey> publicKeys,
  }) {
    return _multiKey(
      sender: sender,
      functionName: 'reStakeUnStakedNodes',
      publicKeys: publicKeys,
      gasPerKey: config.gasLimitRestakeUnstakedNodes,
    );
  }

  /// Change the reward destination address for this validator.
  Transaction createTransactionForChangingRewardAddress({
    required Address sender,
    required Address newRewardAddress,
  }) {
    final String data =
        'changeRewardAddress@${convert.hex.encode(newRewardAddress.bytes)}';
    return _build(
      sender: sender,
      data: data,
      gas: config.gasLimitChangeRewardAddress,
    );
  }

  /// Rotate the BLS validator keys for this validator (old → new pairs).
  Transaction createTransactionForChangingValidatorKeys({
    required Address sender,
    required List<SignedValidatorPublicKey> oldKeys,
    required List<SignedValidatorPublicKey> newKeys,
  }) {
    if (oldKeys.length != newKeys.length) {
      throw ArgumentError('oldKeys and newKeys must have the same length');
    }
    final StringBuffer data = StringBuffer('changeValidatorKeys')
      ..write('@')
      ..write(newKeys.length.toRadixString(16).padLeft(2, '0'));
    for (int i = 0; i < newKeys.length; i++) {
      data
        ..write('@')
        ..write(convert.hex.encode(oldKeys[i].publicKey.bytes))
        ..write('@')
        ..write(convert.hex.encode(newKeys[i].publicKey.bytes))
        ..write('@')
        ..write(convert.hex.encode(newKeys[i].signature));
    }
    return _build(
      sender: sender,
      data: data.toString(),
      gas: config.gasLimitChangeValidatorKeys,
    );
  }

  /// Unjail jailed validators. Requires [amount] EGLD (2500 EGLD per node
  /// on mainnet).
  Transaction createTransactionForUnjailing({
    required Address sender,
    required List<ValidatorPublicKey> publicKeys,
    required Balance amount,
  }) {
    final StringBuffer data = StringBuffer('unJail');
    for (final ValidatorPublicKey key in publicKeys) {
      data
        ..write('@')
        ..write(convert.hex.encode(key.bytes));
    }
    return _build(
      sender: sender,
      data: data.toString(),
      gas: config.gasLimitUnjail * publicKeys.length,
      value: amount,
    );
  }

  Transaction _multiKey({
    required Address sender,
    required String functionName,
    required List<ValidatorPublicKey> publicKeys,
    required int gasPerKey,
  }) {
    final StringBuffer data = StringBuffer(functionName);
    for (final ValidatorPublicKey key in publicKeys) {
      data
        ..write('@')
        ..write(convert.hex.encode(key.bytes));
    }
    return _build(
      sender: sender,
      data: data.toString(),
      gas: gasPerKey * publicKeys.length,
    );
  }

  Transaction _build({
    required Address sender,
    required String data,
    required int gas,
    Balance? value,
  }) {
    final Uint8List bytes = Uint8List.fromList(utf8.encode(data));
    final int finalGas =
        config.minGasLimit + bytes.length * config.gasLimitPerByte + gas;
    return Transaction(
      nonce: const Nonce(0),
      sender: sender,
      receiver: _stakingContract,
      value: value ?? Balance.zero(),
      gasLimit: GasLimit(finalGas),
      gasPrice: GasPrice(config.defaultGasPrice),
      chainId: config.chainId,
      version: const TransactionVersion(2),
      data: bytes,
    );
  }
}
