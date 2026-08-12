/// Factory for building unsigned validator system-contract transactions.
///
/// Targets two system contracts:
///
/// - **Staking SC** (`stake`, `unStake*`, `unBond*`, `unJail`,
///   `changeRewardAddress`, `changeValidatorKeys`, `cleanRegisteredData`,
///   `reStakeUnStakedNodes`, `claim`).
/// - **Delegation manager SC** (`makeNewContractFromValidatorData`,
///   `mergeValidatorToDelegationWithWhitelist`,
///   `mergeValidatorToDelegationSameOwner`).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart' as convert;
import 'package:meta/meta.dart';

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
import 'staking_transactions_factory.dart'
    show SignedValidatorPublicKey, stakingContractBech32;

/// Bech32 address of the delegation-manager system contract.
const String delegationManagerContractBech32 =
    'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqylllslmq6y6';

/// Configuration for [ValidatorsTransactionsFactory].
@immutable
class ValidatorsTransactionsConfig {
  /// Creates a validators factory configuration.
  ///
  /// #### Parameters
  /// - `chainId` - Target chain id
  /// - `minGasLimit` - Minimum base gas
  /// - `gasLimitPerByte` - Per-byte data-field gas
  /// - `gasLimitStake` - Gas for `stake`
  /// - `gasLimitUnstakeTokens` - Gas for `unStakeTokens`
  /// - `gasLimitUnbondTokens` - Gas for `unBondTokens`
  /// - `gasLimitCleanRegisteredData` - Gas for `cleanRegisteredData`
  /// - `gasLimitRestakeUnstakedNodes` - Gas for `reStakeUnStakedNodes`
  /// - `gasLimitUnstake` - Gas for `unStake`
  /// - `gasLimitUnbond` - Gas for `unBond`
  /// - `gasLimitUnstakeNodes` - Gas for `unStakeNodes`
  /// - `gasLimitUnbondNodes` - Gas for `unBondNodes`
  /// - `gasLimitClaim` - Gas for `claim`
  /// - `gasLimitCreateDelegationFromValidator` - Gas for
  ///   `makeNewContractFromValidatorData`
  /// - `gasLimitMergeValidatorToDelegation` - Gas for
  ///   `mergeValidatorToDelegationSameOwner`
  /// - `gasLimitWhitelistForMerge` - Gas for
  ///   `mergeValidatorToDelegationWithWhitelist`
  /// - `defaultGasPrice` - Default gas price
  const ValidatorsTransactionsConfig({
    required this.chainId,
    this.minGasLimit = 50000,
    this.gasLimitPerByte = 1500,
    this.gasLimitStake = 5_000_000,
    this.gasLimitUnstakeTokens = 5_000_000,
    this.gasLimitUnbondTokens = 5_000_000,
    this.gasLimitCleanRegisteredData = 5_000_000,
    this.gasLimitRestakeUnstakedNodes = 5_000_000,
    this.gasLimitToppingUp = 5_000_000,
    this.gasLimitUnjailing = 5_000_000,
    this.gasLimitChangingRewardsAddress = 5_000_000,
    this.gasLimitChangingValidatorKeys = 5_000_000,
    this.gasLimitUnstake = 5_000_000,
    this.gasLimitUnbond = 5_000_000,
    this.gasLimitUnstakeNodes = 5_000_000,
    this.gasLimitUnbondNodes = 5_000_000,
    this.gasLimitClaim = 6_000_000,
    this.gasLimitCreateDelegationFromValidator = 50_000_000,
    this.gasLimitMergeValidatorToDelegation = 50_000_000,
    this.gasLimitWhitelistForMerge = 50_000_000,
    this.defaultGasPrice = 1000000000,
  });

  /// Builds a [ValidatorsTransactionsConfig] from a shared [TransactionsFactoryConfig].
  ///
  /// #### Parameters
  /// - `shared` - Aggregate factory config populated by `NetworkEntrypoint`.
  ///
  /// #### Returns
  /// A new [ValidatorsTransactionsConfig] mirroring `shared`'s validator fields.
  static ValidatorsTransactionsConfig fromShared(
    TransactionsFactoryConfig shared,
  ) => ValidatorsTransactionsConfig(
    chainId: shared.chainId,
    minGasLimit: shared.minGasLimit,
    gasLimitPerByte: shared.gasLimitPerByte,
    gasLimitStake: shared.gasLimitStake,
    gasLimitUnstakeTokens: shared.gasLimitUnstakeTokens,
    gasLimitUnbondTokens: shared.gasLimitUnbondTokens,
    gasLimitCleanRegisteredData: shared.gasLimitCleanRegisteredData,
    gasLimitRestakeUnstakedNodes: shared.gasLimitRestakeUnstakedNodes,
    gasLimitUnstake: shared.gasLimitUnstake,
    gasLimitUnbond: shared.gasLimitUnbond,
  );

  /// Chain id.
  final ChainId chainId;

  /// Minimum base gas.
  final int minGasLimit;

  /// Per-byte data-field gas.
  final int gasLimitPerByte;

  /// Gas used by `stake`.
  final int gasLimitStake;

  /// Gas used by `unStakeTokens`.
  final int gasLimitUnstakeTokens;

  /// Gas used by `unBondTokens`.
  final int gasLimitUnbondTokens;

  /// Gas used by `cleanRegisteredData`.
  final int gasLimitCleanRegisteredData;

  /// Gas used by `reStakeUnStakedNodes`.
  final int gasLimitRestakeUnstakedNodes;

  /// Gas used by `stake` (topping-up flavour, no nodes registered).
  final int gasLimitToppingUp;

  /// Gas used by `unJail` per key.
  final int gasLimitUnjailing;

  /// Gas used by `changeRewardAddress`.
  final int gasLimitChangingRewardsAddress;

  /// Gas used by `changeValidatorKeys` per key pair.
  final int gasLimitChangingValidatorKeys;

  /// Gas used by `unStake` per key.
  final int gasLimitUnstake;

  /// Gas used by `unBond` per key.
  final int gasLimitUnbond;

  /// Gas used by `unStakeNodes` per key.
  final int gasLimitUnstakeNodes;

  /// Gas used by `unBondNodes` per key.
  final int gasLimitUnbondNodes;

  /// Gas used by `claim`.
  final int gasLimitClaim;

  /// Gas used by `makeNewContractFromValidatorData`.
  final int gasLimitCreateDelegationFromValidator;

  /// Gas used by `mergeValidatorToDelegationSameOwner`.
  final int gasLimitMergeValidatorToDelegation;

  /// Gas used by `mergeValidatorToDelegationWithWhitelist`.
  final int gasLimitWhitelistForMerge;

  /// Default gas price.
  final int defaultGasPrice;
}

/// Builds unsigned validator system-contract transactions.
///
/// #### Example
/// ```dart
/// final factory = ValidatorsTransactionsFactory(
///   const ValidatorsTransactionsConfig(chainId: ChainId.devnet()),
/// );
/// final tx = factory.createTransactionForStake(
///   sender: alice.address,
///   nodes: [signedKey1],
///   amount: Balance.fromEgld(2500),
/// );
/// ```
@immutable
class ValidatorsTransactionsFactory {
  /// Creates a validators transactions factory.
  ValidatorsTransactionsFactory(this.config)
    : _stakingContract = Address.fromBech32(stakingContractBech32),
      _delegationManager = Address.fromBech32(delegationManagerContractBech32);

  /// Factory configuration.
  final ValidatorsTransactionsConfig config;

  final Address _stakingContract;
  final Address _delegationManager;

  /// Creates an unsigned `stake` transaction for one or more validator keys.
  ///
  /// Each [SignedValidatorPublicKey] is a `(publicKey, signature)` pair where
  /// the signature is the BLS signature of the validator's owner address.
  ///
  /// #### Parameters
  /// - `sender` - Owner address
  /// - `nodes` - List of `(publicKey, signature)` pairs
  /// - `amount` - Total EGLD to stake (2500 EGLD per node on mainnet)
  /// - `rewardAddress` - Optional bech32 rewards-destination address
  Transaction createTransactionForStake({
    required Address sender,
    required List<SignedValidatorPublicKey> nodes,
    required Balance amount,
    String rewardAddress = '',
  }) {
    final StringBuffer data = StringBuffer('stake')
      ..write('@')
      ..write(nodes.length.toRadixString(16).padLeft(2, '0'));
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
    final int gas = config.gasLimitStake * nodes.length;
    return _build(
      sender: sender,
      data: data.toString(),
      gas: gas,
      value: amount,
    );
  }

  /// Alias of [createTransactionForStake].
  Transaction createTransactionForStaking({
    required Address sender,
    required List<SignedValidatorPublicKey> nodes,
    required Balance amount,
    String rewardAddress = '',
  }) => createTransactionForStake(
    sender: sender,
    nodes: nodes,
    amount: amount,
    rewardAddress: rewardAddress,
  );

  /// Creates an unsigned `unStakeTokens` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Owner address
  /// - `value` - Amount of validator-tokens to unstake (in attoEGLD)
  Transaction createTransactionForUnstakeTokens({
    required Address sender,
    required BigInt value,
  }) {
    final String data = 'unStakeTokens@${_evenBigHex(value)}';
    return _build(
      sender: sender,
      data: data,
      gas: config.gasLimitUnstakeTokens,
    );
  }

  /// Alias of [createTransactionForUnstakeTokens].
  Transaction createTransactionForUnstakingTokens({
    required Address sender,
    required BigInt amount,
  }) => createTransactionForUnstakeTokens(sender: sender, value: amount);

  /// Creates an unsigned `unBondTokens` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Owner address
  /// - `value` - Amount of validator-tokens to unbond (in attoEGLD)
  Transaction createTransactionForUnbondTokens({
    required Address sender,
    required BigInt value,
  }) {
    final String data = 'unBondTokens@${_evenBigHex(value)}';
    return _build(sender: sender, data: data, gas: config.gasLimitUnbondTokens);
  }

  /// Alias of [createTransactionForUnbondTokens].
  Transaction createTransactionForUnbondingTokens({
    required Address sender,
    required BigInt amount,
  }) => createTransactionForUnbondTokens(sender: sender, value: amount);

  /// Creates an unsigned `cleanRegisteredData` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Owner address
  Transaction createTransactionForCleanRegisteredData({
    required Address sender,
  }) {
    return _build(
      sender: sender,
      data: 'cleanRegisteredData',
      gas: config.gasLimitCleanRegisteredData,
    );
  }

  /// Alias of [createTransactionForCleanRegisteredData].
  Transaction createTransactionForCleaningRegisteredData({
    required Address sender,
  }) => createTransactionForCleanRegisteredData(sender: sender);

  /// Creates an unsigned `reStakeUnStakedNodes` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Owner address
  /// - `publicKeys` - Validator public keys to restake
  Transaction createTransactionForRestakeUnstakedNodes({
    required Address sender,
    required List<ValidatorPublicKey> publicKeys,
  }) {
    final StringBuffer data = StringBuffer('reStakeUnStakedNodes');
    for (final ValidatorPublicKey pk in publicKeys) {
      data
        ..write('@')
        ..write(convert.hex.encode(pk.bytes));
    }
    final int gas = config.gasLimitRestakeUnstakedNodes * publicKeys.length;
    return _build(sender: sender, data: data.toString(), gas: gas);
  }

  /// Alias of [createTransactionForRestakeUnstakedNodes].
  Transaction createTransactionForRestakingUnstakedNodes({
    required Address sender,
    required List<ValidatorPublicKey> publicKeys,
  }) => createTransactionForRestakeUnstakedNodes(
    sender: sender,
    publicKeys: publicKeys,
  );

  /// Creates an unsigned `stake` transaction with no nodes (topping-up).
  ///
  /// #### Parameters
  /// - `sender` - Owner address
  /// - `amount` - EGLD to attach as additional stake
  Transaction createTransactionForToppingUp({
    required Address sender,
    required Balance amount,
  }) {
    return _build(
      sender: sender,
      data: 'stake',
      gas: config.gasLimitToppingUp,
      value: amount,
    );
  }

  /// Creates an unsigned `unJail` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Owner address
  /// - `publicKeys` - Validator BLS keys to unjail
  /// - `amount` - EGLD penalty fee
  Transaction createTransactionForUnjailing({
    required Address sender,
    required List<ValidatorPublicKey> publicKeys,
    required Balance amount,
  }) {
    final StringBuffer data = StringBuffer('unJail');
    for (final ValidatorPublicKey pk in publicKeys) {
      data
        ..write('@')
        ..write(convert.hex.encode(pk.bytes));
    }
    final int gas = config.gasLimitUnjailing * publicKeys.length;
    return _build(
      sender: sender,
      data: data.toString(),
      gas: gas,
      value: amount,
    );
  }

  /// Creates an unsigned `changeRewardAddress` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Owner address
  /// - `rewardsAddress` - New rewards-destination address
  Transaction createTransactionForChangingRewardsAddress({
    required Address sender,
    required Address rewardsAddress,
  }) {
    final String data =
        'changeRewardAddress@${convert.hex.encode(rewardsAddress.bytes)}';
    return _build(
      sender: sender,
      data: data,
      gas: config.gasLimitChangingRewardsAddress,
    );
  }

  /// Creates an unsigned `changeValidatorKeys` transaction.
  ///
  /// Each `oldPublicKeys[i]` is mapped to `newSignedKeys[i]`'s `(pubkey,
  /// signature)` pair. The two lists must have the same length.
  ///
  /// #### Parameters
  /// - `sender` - Owner address
  /// - `oldPublicKeys` - Currently-registered BLS keys to rotate out
  /// - `newSignedKeys` - New `(pubkey, signature)` pairs to register
  Transaction createTransactionForChangingValidatorKeys({
    required Address sender,
    required List<ValidatorPublicKey> oldPublicKeys,
    required List<SignedValidatorPublicKey> newSignedKeys,
  }) {
    if (oldPublicKeys.length != newSignedKeys.length) {
      throw ArgumentError(
        'oldPublicKeys and newSignedKeys must have the same length',
      );
    }
    final StringBuffer data = StringBuffer('changeValidatorKeys')
      ..write('@')
      ..write(oldPublicKeys.length.toRadixString(16).padLeft(2, '0'));
    for (int i = 0; i < oldPublicKeys.length; i++) {
      data
        ..write('@')
        ..write(convert.hex.encode(oldPublicKeys[i].bytes))
        ..write('@')
        ..write(convert.hex.encode(newSignedKeys[i].publicKey.bytes))
        ..write('@')
        ..write(convert.hex.encode(newSignedKeys[i].signature));
    }
    final int gas = config.gasLimitChangingValidatorKeys * oldPublicKeys.length;
    return _build(sender: sender, data: data.toString(), gas: gas);
  }

  /// Creates an unsigned `unStake` transaction.
  ///
  /// Removes validator nodes from active staking by BLS public key. To
  /// unstake by token amount instead, use [createTransactionForUnstakeTokens].
  ///
  /// #### Parameters
  /// - `sender` - Owner address
  /// - `publicKeys` - Validator BLS public keys to unstake
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

  /// Creates an unsigned `unBond` transaction.
  ///
  /// Withdraws the validator stake after the unbonding period has elapsed.
  ///
  /// #### Parameters
  /// - `sender` - Owner address
  /// - `publicKeys` - Validator BLS public keys to unbond
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

  /// Creates an unsigned `unStakeNodes` transaction.
  ///
  /// Differs from [createTransactionForUnstaking] in that it targets the
  /// `unStakeNodes` endpoint (selective per-node unstake) instead of
  /// `unStake`.
  ///
  /// #### Parameters
  /// - `sender` - Owner address
  /// - `publicKeys` - Validator BLS public keys to unstake
  Transaction createTransactionForUnstakingNodes({
    required Address sender,
    required List<ValidatorPublicKey> publicKeys,
  }) {
    return _multiKey(
      sender: sender,
      functionName: 'unStakeNodes',
      publicKeys: publicKeys,
      gasPerKey: config.gasLimitUnstakeNodes,
    );
  }

  /// Creates an unsigned `unBondNodes` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Owner address
  /// - `publicKeys` - Validator BLS public keys to unbond
  Transaction createTransactionForUnbondingNodes({
    required Address sender,
    required List<ValidatorPublicKey> publicKeys,
  }) {
    return _multiKey(
      sender: sender,
      functionName: 'unBondNodes',
      publicKeys: publicKeys,
      gasPerKey: config.gasLimitUnbondNodes,
    );
  }

  /// Creates an unsigned `claim` transaction (claims accrued validator
  /// rewards).
  ///
  /// #### Parameters
  /// - `sender` - Owner address
  Transaction createTransactionForClaiming({required Address sender}) {
    return _build(sender: sender, data: 'claim', gas: config.gasLimitClaim);
  }

  /// Creates an unsigned `makeNewContractFromValidatorData` transaction on
  /// the delegation-manager system contract. Migrates a direct-staking
  /// validator into a new delegation contract.
  ///
  /// #### Parameters
  /// - `sender` - Owner address
  /// - `maxCap` - Maximum delegation cap (in attoEGLD)
  /// - `fee` - Service fee, expressed as integer percentage * 100 (so `1500`
  ///   means 15%).
  Transaction createTransactionForNewDelegationContractFromValidatorData({
    required Address sender,
    required BigInt maxCap,
    required BigInt fee,
  }) {
    final String data =
        'makeNewContractFromValidatorData'
        '@${_evenBigHex(maxCap)}'
        '@${_evenBigHex(fee)}';
    return _buildOn(
      sender: sender,
      receiver: _delegationManager,
      data: data,
      gas: config.gasLimitCreateDelegationFromValidator,
    );
  }

  /// Creates an unsigned `mergeValidatorToDelegationWithWhitelist`
  /// transaction on the delegation-manager system contract.
  ///
  /// #### Parameters
  /// - `sender` - Owner address
  /// - `delegationAddress` - Existing delegation contract to merge into
  Transaction createTransactionForMergingValidatorToDelegationWithWhitelist({
    required Address sender,
    required Address delegationAddress,
  }) {
    final String data =
        'mergeValidatorToDelegationWithWhitelist'
        '@${convert.hex.encode(delegationAddress.bytes)}';
    return _buildOn(
      sender: sender,
      receiver: _delegationManager,
      data: data,
      gas: config.gasLimitWhitelistForMerge,
    );
  }

  /// Creates an unsigned `mergeValidatorToDelegationSameOwner` transaction
  /// on the delegation-manager system contract.
  ///
  /// #### Parameters
  /// - `sender` - Owner address
  /// - `delegationAddress` - Existing delegation contract owned by `sender`
  Transaction createTransactionForMergingValidatorToDelegationSameOwner({
    required Address sender,
    required Address delegationAddress,
  }) {
    final String data =
        'mergeValidatorToDelegationSameOwner'
        '@${convert.hex.encode(delegationAddress.bytes)}';
    return _buildOn(
      sender: sender,
      receiver: _delegationManager,
      data: data,
      gas: config.gasLimitMergeValidatorToDelegation,
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
  }) => _buildOn(
    sender: sender,
    receiver: _stakingContract,
    data: data,
    gas: gas,
    value: value,
  );

  Transaction _buildOn({
    required Address sender,
    required Address receiver,
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
      receiver: receiver,
      value: value ?? Balance.zero(),
      gasLimit: GasLimit(finalGas),
      gasPrice: GasPrice(config.defaultGasPrice),
      chainId: config.chainId,
      version: const TransactionVersion(2),
      data: bytes,
    );
  }

  /// Even-length hex encoding of a non-negative [BigInt] matching the
  /// MultiversX top-level `BigUInt` wire encoding (the empty buffer for
  /// `0`, even-length lower-case hex otherwise).
  static String _evenBigHex(BigInt v) {
    if (v == BigInt.zero) return '';
    final String hex = v.toRadixString(16);
    return hex.length.isOdd ? '0$hex' : hex;
  }
}
