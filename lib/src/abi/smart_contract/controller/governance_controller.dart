/// High-level controller for governance system-contract operations.
///
/// Wraps [GovernanceTransactionsFactory] with [BaseController] for unified
/// gas/guardian/relayer/signing handling.
import 'package:meta/meta.dart';

import '../../../core/account/account_interface.dart';
import '../../../core/address.dart';
import '../../../core/nonce.dart';
import '../../../core/transaction/chain_id.dart';
import '../../../core/transaction/controllers/base_controller.dart';
import '../../../core/transaction/factories/governance_transactions_factory.dart';
import '../../../core/transaction/outcome_parsers/governance_outcome_parser.dart';
import '../../../core/transaction/transaction.dart';
import '../../../core/transaction/transaction_on_network.dart';
import '../../../core/transaction/transaction_watcher.dart';
import '../../../infrastructure/network/network_provider.dart';

/// Controller for governance system-contract operations.
///
/// #### Example
/// ```dart
/// final controller = GovernanceController(
///   chainId: const ChainId.devnet(),
/// );
/// final tx = await controller.createTransactionForVoting(
///   alice,
///   const Nonce(1),
///   VoteInput(proposalNonce: 7, vote: VoteType.yes),
/// );
/// ```
@immutable
class GovernanceController extends BaseController {
  /// Creates a governance controller.
  ///
  /// #### Parameters
  /// - `chainId` - Target chain id
  /// - `networkProvider` - Optional network provider
  /// - `gasLimitEstimator` - Optional gas-limit estimator
  /// - `logger` - Optional logger
  GovernanceController({
    required ChainId chainId,
    this.networkProvider,
    super.gasLimitEstimator,
    super.logger,
  }) : factory = GovernanceTransactionsFactory(
         GovernanceTransactionsConfig(chainId: chainId),
       ),
       _parser = const GovernanceOutcomeParser();

  /// Underlying factory.
  final GovernanceTransactionsFactory factory;

  /// Optional network provider (only needed for tx-completion helpers).
  final NetworkProvider? networkProvider;

  final GovernanceOutcomeParser _parser;

  /// Creates and signs a `proposal` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Caller account
  /// - `nonce` - Sender nonce
  /// - `options` - Proposal inputs
  /// - `baseOptions` - Optional overrides
  ///
  /// #### Returns
  /// Signed [Transaction].
  ///
  /// #### Example
  /// ```dart
  /// await controller.createTransactionForNewProposal(
  ///   alice,
  ///   const Nonce(1),
  ///   NewProposalInput(
  ///     commitHash: '0' * 40,
  ///     startVoteEpoch: 100,
  ///     endVoteEpoch: 110,
  ///   ),
  /// );
  /// ```
  Future<Transaction> createTransactionForNewProposal(
    IAccount sender,
    Nonce nonce,
    NewProposalInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForNewProposal(
      sender: sender.address,
      commitHash: options.commitHash,
      startVoteEpoch: options.startVoteEpoch,
      endVoteEpoch: options.endVoteEpoch,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs a `vote` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Caller account
  /// - `nonce` - Sender nonce
  /// - `options` - Vote inputs
  /// - `baseOptions` - Optional overrides
  ///
  /// #### Returns
  /// Signed [Transaction].
  ///
  /// #### Example
  /// ```dart
  /// await controller.createTransactionForVoting(
  ///   alice,
  ///   const Nonce(2),
  ///   VoteInput(proposalNonce: 7, vote: VoteType.yes),
  /// );
  /// ```
  Future<Transaction> createTransactionForVoting(
    IAccount sender,
    Nonce nonce,
    VoteInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForVoting(
      sender: sender.address,
      proposalNonce: options.proposalNonce,
      vote: options.vote,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs a `closeProposal` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Caller account
  /// - `nonce` - Sender nonce
  /// - `options` - Close-proposal inputs
  /// - `baseOptions` - Optional overrides
  ///
  /// #### Returns
  /// Signed [Transaction].
  ///
  /// #### Example
  /// ```dart
  /// await controller.createTransactionForClosingProposal(
  ///   alice,
  ///   const Nonce(4),
  ///   CloseProposalInput(proposalNonce: 7),
  /// );
  /// ```
  Future<Transaction> createTransactionForClosingProposal(
    IAccount sender,
    Nonce nonce,
    CloseProposalInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForClosingProposal(
      sender: sender.address,
      proposalNonce: options.proposalNonce,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs a `claimAccumulatedFees` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Caller account
  /// - `nonce` - Sender nonce
  /// - `baseOptions` - Optional overrides
  ///
  /// #### Returns
  /// Signed [Transaction].
  ///
  /// #### Example
  /// ```dart
  /// await controller.createTransactionForClaimingAccumulatedFees(
  ///   alice,
  ///   const Nonce(5),
  /// );
  /// ```
  Future<Transaction> createTransactionForClaimingAccumulatedFees(
    IAccount sender,
    Nonce nonce, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForClaimingAccumulatedFees(
      sender: sender.address,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs a `clearEndedProposals` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Caller account
  /// - `nonce` - Sender nonce
  /// - `options` - Clear-ended inputs
  /// - `baseOptions` - Optional overrides
  ///
  /// #### Returns
  /// Signed [Transaction].
  ///
  /// #### Example
  /// ```dart
  /// await controller.createTransactionForClearingEndedProposals(
  ///   alice,
  ///   const Nonce(6),
  ///   ClearEndedProposalsInput(proposers: [alice.address]),
  /// );
  /// ```
  Future<Transaction> createTransactionForClearingEndedProposals(
    IAccount sender,
    Nonce nonce,
    ClearEndedProposalsInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForClearingEndedProposals(
      sender: sender.address,
      proposers: options.proposers,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs a `changeConfig` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Caller account
  /// - `nonce` - Sender nonce
  /// - `options` - Change-config inputs
  /// - `baseOptions` - Optional overrides
  ///
  /// #### Returns
  /// Signed [Transaction].
  ///
  /// #### Example
  /// ```dart
  /// await controller.createTransactionForChangingConfig(
  ///   alice,
  ///   const Nonce(7),
  ///   ChangeConfigInput(
  ///     proposalFee: '1000000000000000000000',
  ///     lastProposalFee: '1000000000000000000000',
  ///     minQuorum: 2000,
  ///     minVetoThreshold: 3300,
  ///     minPassThreshold: 6700,
  ///   ),
  /// );
  /// ```
  Future<Transaction> createTransactionForChangingConfig(
    IAccount sender,
    Nonce nonce,
    ChangeConfigInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForChangingConfig(
      sender: sender.address,
      proposalFee: options.proposalFee,
      lastProposalFee: options.lastProposalFee,
      minQuorum: options.minQuorum,
      minVetoThreshold: options.minVetoThreshold,
      minPassThreshold: options.minPassThreshold,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Parses `proposal` events emitted by a new-proposal transaction.
  ///
  /// #### Parameters
  /// - `transaction` - Completed [TransactionOnNetwork]
  ///
  /// #### Returns
  /// List of [NewProposalOutcome].
  List<NewProposalOutcome> parseNewProposal(TransactionOnNetwork transaction) {
    return _parser.parseNewProposal(transaction);
  }

  /// Parses `vote` events emitted by a vote transaction.
  ///
  /// #### Parameters
  /// - `transaction` - Completed [TransactionOnNetwork]
  ///
  /// #### Returns
  /// List of [VoteOutcome].
  List<VoteOutcome> parseVote(TransactionOnNetwork transaction) {
    return _parser.parseVote(transaction);
  }

  /// Parses `delegateVote` events emitted by the governance contract.
  ///
  /// `delegateVote` is callable only by a smart contract, so these events
  /// appear on transactions whose caller is a contract (e.g. a staking
  /// provider voting on behalf of its delegators).
  ///
  /// #### Parameters
  /// - `transaction` - Completed [TransactionOnNetwork]
  ///
  /// #### Returns
  /// List of [DelegateVoteOutcome].
  List<DelegateVoteOutcome> parseDelegateVote(
    TransactionOnNetwork transaction,
  ) {
    return _parser.parseDelegateVote(transaction);
  }

  /// Parses `closeProposal` events emitted by a close-proposal transaction.
  ///
  /// #### Parameters
  /// - `transaction` - Completed [TransactionOnNetwork]
  ///
  /// #### Returns
  /// List of [CloseProposalOutcome].
  List<CloseProposalOutcome> parseCloseProposal(
    TransactionOnNetwork transaction,
  ) {
    return _parser.parseCloseProposal(transaction);
  }

  /// Parses `clearEndedProposals` outcome (success/failure check only).
  ///
  /// #### Parameters
  /// - `transaction` - Completed [TransactionOnNetwork]
  ///
  /// #### Returns
  /// `true` when the transaction reports no signalError, `false` otherwise.
  bool parseClearEndedProposals(TransactionOnNetwork transaction) {
    return !(transaction.logs?.hasErrors ?? false);
  }

  /// Parses `changeConfig` outcome (success/failure check only).
  bool parseChangeConfig(TransactionOnNetwork transaction) {
    return !(transaction.logs?.hasErrors ?? false);
  }

  /// Parses `claimAccumulatedFees` outcome (success/failure check only).
  bool parseClaimAccumulatedFees(TransactionOnNetwork transaction) {
    return !(transaction.logs?.hasErrors ?? false);
  }

  /// Awaits a governance execute transaction and returns the raw
  /// [TransactionOnNetwork] so the caller can route into the appropriate
  /// `parse*` helper.
  ///
  /// #### Parameters
  /// - `txHash` - Transaction hash returned by `sendTransaction`
  ///
  /// #### Returns
  /// Completed [TransactionOnNetwork].
  ///
  /// #### Example
  /// ```dart
  /// final tx = await controller.awaitCompletedExecute(hash);
  /// final outcomes = controller.parseVote(tx);
  /// ```
  Future<TransactionOnNetwork> awaitCompletedExecute(String txHash) async {
    final NetworkProvider provider = _requireProvider();
    final TransactionWatcher watcher = TransactionWatcher(
      networkProvider: provider,
    );
    return watcher.awaitCompleted(txHash);
  }

  NetworkProvider _requireProvider() {
    final NetworkProvider? provider = networkProvider;
    if (provider == null) {
      throw StateError(
        'GovernanceController.networkProvider is required for '
        'awaitCompleted*',
      );
    }
    return provider;
  }
}

/// Input for `proposal`.
@immutable
class NewProposalInput {
  /// Creates a new-proposal input.
  const NewProposalInput({
    required this.commitHash,
    required this.startVoteEpoch,
    required this.endVoteEpoch,
  });

  /// 40-char git commit hash of the off-chain proposal text.
  final String commitHash;

  /// Start epoch of the voting window.
  final int startVoteEpoch;

  /// End epoch of the voting window.
  final int endVoteEpoch;
}

/// Input for `vote`.
@immutable
class VoteInput {
  /// Creates a vote input.
  const VoteInput({required this.proposalNonce, required this.vote});

  /// Proposal nonce being voted on.
  final int proposalNonce;

  /// Vote choice.
  final VoteType vote;
}

/// Input for `closeProposal`.
@immutable
class CloseProposalInput {
  /// Creates a close-proposal input.
  const CloseProposalInput({required this.proposalNonce});

  /// Proposal nonce being closed.
  final int proposalNonce;
}

/// Input for `clearEndedProposals`.
@immutable
class ClearEndedProposalsInput {
  /// Creates a clear-ended-proposals input.
  const ClearEndedProposalsInput({required this.proposers});

  /// Proposer addresses whose ended proposals should be cleared.
  final List<Address> proposers;
}

/// Input for `changeConfig`.
@immutable
class ChangeConfigInput {
  /// Creates a change-config input.
  const ChangeConfigInput({
    required this.proposalFee,
    required this.lastProposalFee,
    required this.minQuorum,
    required this.minVetoThreshold,
    required this.minPassThreshold,
  });

  /// New `proposalFee` (string, attoEGLD).
  final String proposalFee;

  /// New `lastProposalFee`.
  final String lastProposalFee;

  /// New minimum quorum (percent * 1e4).
  final int minQuorum;

  /// New minimum veto threshold.
  final int minVetoThreshold;

  /// New minimum pass threshold.
  final int minPassThreshold;
}
