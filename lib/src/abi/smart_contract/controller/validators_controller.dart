/// High-level controller for validator system-contract operations.
///
/// Wraps [ValidatorsTransactionsFactory] with [BaseController] for unified
/// gas/guardian/relayer/signing handling.
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../core/account/account_interface.dart';
import '../../../core/address.dart';
import '../../../core/balance.dart';
import '../../../core/nonce.dart';
import '../../../core/transaction/chain_id.dart';
import '../../../core/transaction/controllers/base_controller.dart';
import '../../../core/transaction/factories/staking_transactions_factory.dart'
    show SignedValidatorPublicKey;
import '../../../core/transaction/factories/validators_transactions_factory.dart';
import '../../../core/transaction/smart_contract_result.dart';
import '../../../core/transaction/transaction.dart';
import '../../../core/transaction/transaction_event.dart';
import '../../../core/transaction/transaction_on_network.dart';
import '../../../core/transaction/transaction_watcher.dart';
import '../../../infrastructure/network/network_provider.dart';
import '../../../wallet/validator_keys.dart';

/// Controller for validator system-contract operations.
///
/// #### Example
/// ```dart
/// final controller = ValidatorsController(
///   chainId: const ChainId.devnet(),
/// );
/// final tx = await controller.createTransactionForStake(
///   alice,
///   const Nonce(1),
///   StakeValidatorsInput(
///     nodes: [SignedValidatorPublicKey(publicKey: pk, signature: sig)],
///     amount: Balance.fromEgld(2500),
///   ),
/// );
/// ```
@immutable
class ValidatorsController extends BaseController {
  /// Creates a validators controller.
  ///
  /// #### Parameters
  /// - `chainId` - Target chain id
  /// - `networkProvider` - Optional network provider (only used by
  ///   helpers that await tx completion)
  /// - `gasLimitEstimator` - Optional gas-limit estimator
  /// - `logger` - Optional logger
  ValidatorsController({
    required ChainId chainId,
    this.networkProvider,
    super.gasLimitEstimator,
    super.logger,
  }) : factory = ValidatorsTransactionsFactory(
         ValidatorsTransactionsConfig(chainId: chainId),
       );

  /// Underlying factory.
  final ValidatorsTransactionsFactory factory;

  /// Optional network provider (only needed for tx-completion helpers).
  final NetworkProvider? networkProvider;

  /// Creates and signs a `stake` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Owner account
  /// - `nonce` - Sender nonce
  /// - `options` - Stake inputs
  /// - `baseOptions` - Optional gas/guardian/relayer overrides
  ///
  /// #### Returns
  /// Signed [Transaction].
  ///
  /// #### Example
  /// ```dart
  /// await controller.createTransactionForStake(
  ///   alice,
  ///   const Nonce(1),
  ///   StakeValidatorsInput(
  ///     nodes: [SignedValidatorPublicKey(publicKey: pk, signature: sig)],
  ///     amount: Balance.fromEgld(2500),
  ///   ),
  /// );
  /// ```
  Future<Transaction> createTransactionForStake(
    IAccount sender,
    Nonce nonce,
    StakeValidatorsInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForStake(
      sender: sender.address,
      nodes: options.nodes,
      amount: options.amount,
      rewardAddress: options.rewardAddress,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs an `unStakeTokens` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Owner account
  /// - `nonce` - Sender nonce
  /// - `options` - Unstake-tokens inputs
  /// - `baseOptions` - Optional overrides
  ///
  /// #### Returns
  /// Signed [Transaction].
  ///
  /// #### Example
  /// ```dart
  /// await controller.createTransactionForUnstakeTokens(
  ///   alice,
  ///   const Nonce(2),
  ///   UnstakeOrUnbondTokensInput(value: BigInt.from(1e18)),
  /// );
  /// ```
  Future<Transaction> createTransactionForUnstakeTokens(
    IAccount sender,
    Nonce nonce,
    UnstakeOrUnbondTokensInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForUnstakeTokens(
      sender: sender.address,
      value: options.value,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs an `unBondTokens` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Owner account
  /// - `nonce` - Sender nonce
  /// - `options` - Unbond-tokens inputs
  /// - `baseOptions` - Optional overrides
  ///
  /// #### Returns
  /// Signed [Transaction].
  ///
  /// #### Example
  /// ```dart
  /// await controller.createTransactionForUnbondTokens(
  ///   alice,
  ///   const Nonce(3),
  ///   UnstakeOrUnbondTokensInput(value: BigInt.from(1e18)),
  /// );
  /// ```
  Future<Transaction> createTransactionForUnbondTokens(
    IAccount sender,
    Nonce nonce,
    UnstakeOrUnbondTokensInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForUnbondTokens(
      sender: sender.address,
      value: options.value,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs a `cleanRegisteredData` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Owner account
  /// - `nonce` - Sender nonce
  /// - `baseOptions` - Optional overrides
  ///
  /// #### Returns
  /// Signed [Transaction].
  ///
  /// #### Example
  /// ```dart
  /// await controller.createTransactionForCleanRegisteredData(
  ///   alice,
  ///   const Nonce(4),
  /// );
  /// ```
  Future<Transaction> createTransactionForCleanRegisteredData(
    IAccount sender,
    Nonce nonce, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForCleanRegisteredData(
      sender: sender.address,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs a `reStakeUnStakedNodes` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Owner account
  /// - `nonce` - Sender nonce
  /// - `options` - Restake inputs
  /// - `baseOptions` - Optional overrides
  ///
  /// #### Returns
  /// Signed [Transaction].
  ///
  /// #### Example
  /// ```dart
  /// await controller.createTransactionForRestakeUnstakedNodes(
  ///   alice,
  ///   const Nonce(5),
  ///   RestakeUnstakedNodesInput(publicKeys: [pk1]),
  /// );
  /// ```
  Future<Transaction> createTransactionForRestakeUnstakedNodes(
    IAccount sender,
    Nonce nonce,
    RestakeUnstakedNodesInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForRestakeUnstakedNodes(
      sender: sender.address,
      publicKeys: options.publicKeys,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs a `stake` topping-up transaction (adds EGLD to an
  /// already-staked validator without registering new nodes).
  ///
  /// #### Parameters
  /// - `sender` - Owner account
  /// - `nonce` - Sender nonce
  /// - `options` - Topping-up inputs
  /// - `baseOptions` - Optional overrides
  ///
  /// #### Returns
  /// Signed [Transaction].
  ///
  /// #### Example
  /// ```dart
  /// await controller.createTransactionForToppingUp(
  ///   alice,
  ///   const Nonce(6),
  ///   ToppingUpInput(amount: Balance.fromEgld(10)),
  /// );
  /// ```
  Future<Transaction> createTransactionForToppingUp(
    IAccount sender,
    Nonce nonce,
    ToppingUpInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForToppingUp(
      sender: sender.address,
      amount: options.amount,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs an `unJail` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Owner account
  /// - `nonce` - Sender nonce
  /// - `options` - Unjail inputs
  /// - `baseOptions` - Optional overrides
  ///
  /// #### Returns
  /// Signed [Transaction].
  Future<Transaction> createTransactionForUnjailing(
    IAccount sender,
    Nonce nonce,
    UnjailingInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForUnjailing(
      sender: sender.address,
      publicKeys: options.publicKeys,
      amount: options.amount,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs a `changeRewardAddress` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Owner account
  /// - `nonce` - Sender nonce
  /// - `options` - New rewards-address inputs
  /// - `baseOptions` - Optional overrides
  ///
  /// #### Returns
  /// Signed [Transaction].
  Future<Transaction> createTransactionForChangingRewardsAddress(
    IAccount sender,
    Nonce nonce,
    ChangingRewardsAddressInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForChangingRewardsAddress(
      sender: sender.address,
      rewardsAddress: options.rewardsAddress,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs a `changeValidatorKeys` transaction (rotates BLS
  /// keys associated with a staked validator).
  ///
  /// #### Parameters
  /// - `sender` - Owner account
  /// - `nonce` - Sender nonce
  /// - `options` - Old → new key mapping
  /// - `baseOptions` - Optional overrides
  ///
  /// #### Returns
  /// Signed [Transaction].
  Future<Transaction> createTransactionForChangingValidatorKeys(
    IAccount sender,
    Nonce nonce,
    ChangingValidatorKeysInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForChangingValidatorKeys(
      sender: sender.address,
      oldPublicKeys: options.oldPublicKeys,
      newSignedKeys: options.newSignedKeys,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Parses a completed `stake` transaction.
  ///
  /// #### Parameters
  /// - `transaction` - Completed [TransactionOnNetwork]
  ///
  /// #### Returns
  /// [StakeOutcome] with any unprocessed BLS keys and (when present) the
  /// `topUp` / `totalStake` amounts returned by the staking contract.
  ///
  /// The staking contract places the two amounts last in the return data, so
  /// any preceding buffers are the BLS keys it did not process.
  StakeOutcome parseStake(TransactionOnNetwork transaction) {
    _ensureNoSignalError(transaction);
    final List<Uint8List> parts = _readReturnData(transaction);
    final List<Uint8List> unprocessed = <Uint8List>[];
    BigInt? topUp;
    BigInt? totalStake;
    if (parts.isNotEmpty) {
      final int unprocessedCount = parts.length >= 2 ? parts.length - 2 : 0;
      for (int i = 0; i < unprocessedCount; i++) {
        unprocessed.add(Uint8List.fromList(parts[i]));
      }
      if (parts.length >= 2) {
        topUp = _bytesToBigInt(parts[parts.length - 2]);
        totalStake = _bytesToBigInt(parts.last);
      }
    }
    return StakeOutcome(
      unprocessedPublicKeys: unprocessed,
      topUp: topUp,
      totalStake: totalStake,
    );
  }

  /// Parses an `unStakeTokens` outcome.
  ///
  /// #### Returns
  /// [UnstakeTokensOutcome] with the unstaked-tokens amount and the new
  /// total-unstaked tally returned by the staking contract.
  UnstakeTokensOutcome parseUnstakeTokens(TransactionOnNetwork transaction) {
    _ensureNoSignalError(transaction);
    final List<Uint8List> parts = _readReturnData(transaction);
    final BigInt unstaked = parts.isNotEmpty
        ? _bytesToBigInt(parts.first)
        : BigInt.zero;
    final BigInt total = parts.length >= 2
        ? _bytesToBigInt(parts[1])
        : BigInt.zero;
    return UnstakeTokensOutcome(unstakedTokens: unstaked, totalUnstaked: total);
  }

  /// Parses an `unBondTokens` outcome.
  ///
  /// #### Returns
  /// [UnBondTokensOutcome] with the unbonded-tokens amount.
  UnBondTokensOutcome parseUnBondTokens(TransactionOnNetwork transaction) {
    _ensureNoSignalError(transaction);
    final List<Uint8List> parts = _readReturnData(transaction);
    final BigInt unbonded = parts.isNotEmpty
        ? _bytesToBigInt(parts.first)
        : BigInt.zero;
    return UnBondTokensOutcome(unbondedTokens: unbonded);
  }

  /// Parses a `cleanRegisteredData` outcome.
  ///
  /// #### Returns
  /// [CleanRegisteredDataOutcome] indicating the transaction succeeded.
  CleanRegisteredDataOutcome parseCleanRegisteredData(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoSignalError(transaction);
    return const CleanRegisteredDataOutcome();
  }

  /// Parses a `reStakeUnStakedNodes` outcome.
  ///
  /// #### Returns
  /// [RestakeUnstakedOutcome] with any unprocessed BLS keys returned by
  /// the staking contract.
  RestakeUnstakedOutcome parseRestakeUnstaked(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoSignalError(transaction);
    final List<Uint8List> parts = _readReturnData(transaction);
    return RestakeUnstakedOutcome(
      unprocessedPublicKeys: <Uint8List>[
        for (final Uint8List part in parts) Uint8List.fromList(part),
      ],
    );
  }

  /// Awaits a validator execute transaction and parses the outcome as a
  /// stake outcome (callers using non-`stake` flows can call the specific
  /// parser themselves after `awaitCompleted`).
  ///
  /// #### Parameters
  /// - `txHash` - Transaction hash returned by `sendTransaction`
  ///
  /// #### Returns
  /// [StakeOutcome] decoded from the awaited transaction.
  Future<StakeOutcome> awaitCompletedExecute(String txHash) async {
    final NetworkProvider provider = _requireProvider();
    final TransactionWatcher watcher = TransactionWatcher(
      networkProvider: provider,
    );
    final TransactionOnNetwork tx = await watcher.awaitCompleted(txHash);
    return parseStake(tx);
  }

  /// Throws [ValidatorsParseException] if the transaction logs contain a
  /// `signalError` event, with a decoded message when available.
  void _ensureNoSignalError(TransactionOnNetwork transaction) {
    if (transaction.logs == null) return;
    final List<TransactionEvent> errs = transaction.logs!.errorEvents;
    if (errs.isEmpty) return;
    final TransactionEvent event = errs.first;
    final String message = event.topics.length > 1
        ? String.fromCharCodes(event.topics[1])
        : 'signalError';
    throw ValidatorsParseException('validators signalError: $message');
  }

  /// Reads the return-data buffers from the eligible SCR (one whose
  /// receiver matches the caller) or from the first SCR with return data.
  List<Uint8List> _readReturnData(TransactionOnNetwork transaction) {
    final List<SmartContractResult>? results = transaction.smartContractResults;
    if (results == null || results.isEmpty) return const <Uint8List>[];
    SmartContractResult? selected;
    for (final SmartContractResult scr in results) {
      if (scr.receiver == transaction.sender && scr.returnData.isNotEmpty) {
        selected = scr;
        break;
      }
    }
    selected ??= results.firstWhere(
      (SmartContractResult scr) => scr.returnData.isNotEmpty,
      orElse: () => results.first,
    );
    return List<Uint8List>.of(selected.returnData);
  }

  /// Big-endian conversion of an unsigned hex-encoded buffer into [BigInt].
  ///
  /// Top-level `BigUint` return values are encoded as a minimal big-endian
  /// magnitude with no length prefix, which is how return-data amounts arrive.
  static BigInt _bytesToBigInt(Uint8List buf) {
    if (buf.isEmpty) return BigInt.zero;
    BigInt result = BigInt.zero;
    for (final int b in buf) {
      result = (result << 8) | BigInt.from(b & 0xff);
    }
    return result;
  }

  NetworkProvider _requireProvider() {
    final NetworkProvider? provider = networkProvider;
    if (provider == null) {
      throw StateError(
        'ValidatorsController.networkProvider is required for '
        'awaitCompleted*',
      );
    }
    return provider;
  }
}

/// Exception thrown when validators outcome parsing fails.
@immutable
class ValidatorsParseException implements Exception {
  /// Creates a validators-parse exception.
  ///
  /// #### Parameters
  /// - `message` - Human-readable error description.
  const ValidatorsParseException(this.message);

  /// Human-readable error description.
  final String message;

  @override
  String toString() => 'ValidatorsParseException: $message';
}

/// Outcome of a `stake` transaction.
///
/// Carries the BLS public keys the staking contract left unprocessed and,
/// when the contract returns them, the top-up and total-stake amounts.
@immutable
class StakeOutcome {
  /// Creates a stake outcome.
  ///
  /// #### Parameters
  /// - `unprocessedPublicKeys` - BLS public keys the staking contract did
  ///   not process (e.g. duplicates).
  /// - `topUp` - Top-up amount returned by the staking contract.
  /// - `totalStake` - New total stake after the operation.
  const StakeOutcome({
    this.unprocessedPublicKeys = const <Uint8List>[],
    this.topUp,
    this.totalStake,
  });

  /// BLS public keys the staking contract did not process.
  final List<Uint8List> unprocessedPublicKeys;

  /// Optional top-up amount returned by the staking contract.
  final BigInt? topUp;

  /// Optional new total stake after the operation.
  final BigInt? totalStake;
}

/// Outcome of an `unStakeTokens` transaction.
@immutable
class UnstakeTokensOutcome {
  /// Creates an unstake-tokens outcome.
  ///
  /// #### Parameters
  /// - `unstakedTokens` - Amount actually unstaked by this transaction.
  /// - `totalUnstaked` - Cumulative unstaked-token tally after the op.
  const UnstakeTokensOutcome({
    required this.unstakedTokens,
    required this.totalUnstaked,
  });

  /// Amount actually unstaked by this transaction.
  final BigInt unstakedTokens;

  /// Cumulative unstaked-token tally after the operation.
  final BigInt totalUnstaked;
}

/// Outcome of an `unBondTokens` transaction.
@immutable
class UnBondTokensOutcome {
  /// Creates an unbond-tokens outcome.
  ///
  /// #### Parameters
  /// - `unbondedTokens` - Amount of tokens unbonded by this transaction.
  const UnBondTokensOutcome({required this.unbondedTokens});

  /// Amount of tokens unbonded by this transaction.
  final BigInt unbondedTokens;
}

/// Outcome of a `cleanRegisteredData` transaction.
///
/// The staking contract returns no payload; the outcome simply records
/// that the transaction completed without `signalError`.
@immutable
class CleanRegisteredDataOutcome {
  /// Creates a clean-registered-data outcome.
  const CleanRegisteredDataOutcome();
}

/// Outcome of a `reStakeUnStakedNodes` transaction.
@immutable
class RestakeUnstakedOutcome {
  /// Creates a restake-unstaked-nodes outcome.
  ///
  /// #### Parameters
  /// - `unprocessedPublicKeys` - BLS public keys the staking contract did
  ///   not process (e.g. unknown to the staking SC).
  const RestakeUnstakedOutcome({
    this.unprocessedPublicKeys = const <Uint8List>[],
  });

  /// BLS public keys the staking contract did not process.
  final List<Uint8List> unprocessedPublicKeys;
}

/// Input for `topUp` (stake additional EGLD without registering nodes).
@immutable
class ToppingUpInput {
  /// Creates topping-up input.
  const ToppingUpInput({required this.amount});

  /// EGLD amount to add to the existing validator stake.
  final Balance amount;
}

/// Input for `unJail`.
@immutable
class UnjailingInput {
  /// Creates unjailing input.
  const UnjailingInput({required this.publicKeys, required this.amount});

  /// Validator BLS public keys to unjail.
  final List<ValidatorPublicKey> publicKeys;

  /// EGLD penalty fee attached to the unjail call.
  final Balance amount;
}

/// Input for `changeRewardAddress`.
@immutable
class ChangingRewardsAddressInput {
  /// Creates change-rewards-address input.
  const ChangingRewardsAddressInput({required this.rewardsAddress});

  /// New rewards-destination address.
  final Address rewardsAddress;
}

/// Input for `changeValidatorKeys`.
@immutable
class ChangingValidatorKeysInput {
  /// Creates change-validator-keys input.
  const ChangingValidatorKeysInput({
    required this.oldPublicKeys,
    required this.newSignedKeys,
  });

  /// Currently-registered BLS public keys to rotate out.
  final List<ValidatorPublicKey> oldPublicKeys;

  /// New `(pubkey, signature)` pairs to register in their place.
  final List<SignedValidatorPublicKey> newSignedKeys;
}

/// Input for staking validator nodes.
@immutable
class StakeValidatorsInput {
  /// Creates stake input.
  const StakeValidatorsInput({
    required this.nodes,
    required this.amount,
    this.rewardAddress = '',
  });

  /// Validator `(pubkey, signature)` pairs.
  final List<SignedValidatorPublicKey> nodes;

  /// EGLD amount to stake.
  final Balance amount;

  /// Optional bech32 rewards address.
  final String rewardAddress;
}

/// Input for unstake-tokens and unbond-tokens.
@immutable
class UnstakeOrUnbondTokensInput {
  /// Creates input with the validator-token amount.
  const UnstakeOrUnbondTokensInput({required this.value});

  /// Validator-token amount in attoEGLD.
  final BigInt value;
}

/// Input for restake-unstaked-nodes.
@immutable
class RestakeUnstakedNodesInput {
  /// Creates input with validator public keys.
  const RestakeUnstakedNodesInput({required this.publicKeys});

  /// Validator public keys.
  final List<ValidatorPublicKey> publicKeys;
}
