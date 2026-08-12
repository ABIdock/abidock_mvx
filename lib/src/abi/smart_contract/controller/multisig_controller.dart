/// High-level controller for multisig system-contract operations.
///
/// Wraps [MultisigTransactionsFactory] with [BaseController] for unified
/// gas/guardian/relayer/signing handling.
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../core/account/account_interface.dart';
import '../../../core/address.dart';
import '../../../core/nonce.dart';
import '../../../core/transaction/chain_id.dart';
import '../../../core/transaction/controllers/base_controller.dart';
import '../../../core/transaction/factories/multisig_transactions_factory.dart';
import '../../../core/transaction/outcome_parsers/smart_contract_outcome_parser.dart';
import '../../../core/transaction/smart_contract_result.dart';
import '../../../core/transaction/transaction.dart';
import '../../../core/transaction/transaction_event.dart';
import '../../../core/transaction/transaction_on_network.dart';
import '../../../core/transaction/transaction_watcher.dart';
import '../../../infrastructure/network/network_provider.dart';
import '../../core/types.dart' show TypedValue;

/// Controller for multisig system-contract operations.
///
/// #### Example
/// ```dart
/// final controller = MultisigController(
///   chainId: const ChainId.devnet(),
///   networkProvider: provider,
/// );
/// final tx = await controller.createTransactionForSign(
///   alice,
///   const Nonce(7),
///   SignActionInput(multisigContract: multisig, actionId: 12),
/// );
/// ```
@immutable
class MultisigController extends BaseController {
  /// Creates a multisig controller.
  ///
  /// #### Parameters
  /// - `chainId` - Target chain id
  /// - `networkProvider` - Optional network provider (only required for
  ///   awaiting completion; not used for create-only flows).
  /// - `gasLimitEstimator` - Optional gas-limit estimator
  /// - `logger` - Optional logger
  MultisigController({
    required ChainId chainId,
    this.networkProvider,
    super.gasLimitEstimator,
    super.logger,
  }) : factory = MultisigTransactionsFactory(
         MultisigTransactionsConfig(chainId: chainId),
       );

  /// Underlying factory.
  final MultisigTransactionsFactory factory;

  /// Optional network provider (only needed for tx-completion helpers).
  final NetworkProvider? networkProvider;

  /// Creates and signs a `proposeAddBoardMember` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Caller account (signs the tx)
  /// - `nonce` - Sender nonce
  /// - `options` - Proposal inputs
  /// - `baseOptions` - Optional gas/guardian/relayer overrides
  ///
  /// #### Returns
  /// Signed [Transaction] ready for broadcast.
  ///
  /// #### Example
  /// ```dart
  /// await controller.createTransactionForProposeAddBoardMember(
  ///   alice,
  ///   const Nonce(1),
  ///   ProposeAddBoardMemberInput(
  ///     multisigContract: multisig,
  ///     boardMember: bob.address,
  ///   ),
  /// );
  /// ```
  Future<Transaction> createTransactionForProposeAddBoardMember(
    IAccount sender,
    Nonce nonce,
    ProposeAddBoardMemberInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForProposeAddBoardMember(
      sender: sender.address,
      multisigContract: options.multisigContract,
      boardMember: options.boardMember,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs a `proposeAddProposer` transaction.
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
  /// await controller.createTransactionForProposeAddProposer(
  ///   alice,
  ///   const Nonce(2),
  ///   ProposeAddProposerInput(
  ///     multisigContract: multisig,
  ///     proposer: bob.address,
  ///   ),
  /// );
  /// ```
  Future<Transaction> createTransactionForProposeAddProposer(
    IAccount sender,
    Nonce nonce,
    ProposeAddProposerInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForProposeAddProposer(
      sender: sender.address,
      multisigContract: options.multisigContract,
      proposer: options.proposer,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs a `proposeRemoveUser` transaction.
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
  /// await controller.createTransactionForProposeRemoveUser(
  ///   alice,
  ///   const Nonce(3),
  ///   ProposeRemoveUserInput(
  ///     multisigContract: multisig,
  ///     user: bob.address,
  ///   ),
  /// );
  /// ```
  Future<Transaction> createTransactionForProposeRemoveUser(
    IAccount sender,
    Nonce nonce,
    ProposeRemoveUserInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForProposeRemoveUser(
      sender: sender.address,
      multisigContract: options.multisigContract,
      user: options.user,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs a `proposeChangeQuorum` transaction.
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
  /// await controller.createTransactionForProposeChangeQuorum(
  ///   alice,
  ///   const Nonce(4),
  ///   ProposeChangeQuorumInput(multisigContract: multisig, newQuorum: 3),
  /// );
  /// ```
  Future<Transaction> createTransactionForProposeChangeQuorum(
    IAccount sender,
    Nonce nonce,
    ProposeChangeQuorumInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForProposeChangeQuorum(
      sender: sender.address,
      multisigContract: options.multisigContract,
      newQuorum: options.newQuorum,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs a `proposeTransferExecute` transaction.
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
  /// await controller.createTransactionForProposeTransferExecute(
  ///   alice,
  ///   const Nonce(5),
  ///   ProposeTransferExecuteInput(
  ///     multisigContract: multisig,
  ///     to: target,
  ///     egldAmount: BigInt.from(1000000000000000000),
  ///   ),
  /// );
  /// ```
  Future<Transaction> createTransactionForProposeTransferExecute(
    IAccount sender,
    Nonce nonce,
    ProposeTransferExecuteInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForProposeTransferExecute(
      sender: sender.address,
      multisigContract: options.multisigContract,
      to: options.to,
      egldAmount: options.egldAmount,
      functionCall: options.functionCall,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs a `proposeAsyncCall` transaction.
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
  /// await controller.createTransactionForProposeAsyncCall(
  ///   alice,
  ///   const Nonce(6),
  ///   ProposeAsyncCallInput(
  ///     multisigContract: multisig,
  ///     to: child,
  ///     functionCall: <TypedValue>[StringValue('ping')],
  ///   ),
  /// );
  /// ```
  Future<Transaction> createTransactionForProposeAsyncCall(
    IAccount sender,
    Nonce nonce,
    ProposeAsyncCallInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForProposeAsyncCall(
      sender: sender.address,
      multisigContract: options.multisigContract,
      to: options.to,
      egldAmount: options.egldAmount,
      functionCall: options.functionCall,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs a `sign` transaction for an action id.
  ///
  /// #### Parameters
  /// - `sender` - Signer account
  /// - `nonce` - Sender nonce
  /// - `options` - Action inputs
  /// - `baseOptions` - Optional overrides
  ///
  /// #### Returns
  /// Signed [Transaction].
  ///
  /// #### Example
  /// ```dart
  /// await controller.createTransactionForSign(
  ///   alice,
  ///   const Nonce(7),
  ///   SignActionInput(multisigContract: multisig, actionId: 42),
  /// );
  /// ```
  Future<Transaction> createTransactionForSign(
    IAccount sender,
    Nonce nonce,
    SignActionInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForSign(
      sender: sender.address,
      multisigContract: options.multisigContract,
      actionId: options.actionId,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs an `unsign` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Signer account
  /// - `nonce` - Sender nonce
  /// - `options` - Action inputs
  /// - `baseOptions` - Optional overrides
  ///
  /// #### Returns
  /// Signed [Transaction].
  ///
  /// #### Example
  /// ```dart
  /// await controller.createTransactionForUnsign(
  ///   alice,
  ///   const Nonce(8),
  ///   SignActionInput(multisigContract: multisig, actionId: 42),
  /// );
  /// ```
  Future<Transaction> createTransactionForUnsign(
    IAccount sender,
    Nonce nonce,
    SignActionInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForUnsign(
      sender: sender.address,
      multisigContract: options.multisigContract,
      actionId: options.actionId,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs a `performAction` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Caller account
  /// - `nonce` - Sender nonce
  /// - `options` - Action inputs
  /// - `baseOptions` - Optional overrides
  ///
  /// #### Returns
  /// Signed [Transaction].
  ///
  /// #### Example
  /// ```dart
  /// await controller.createTransactionForPerformAction(
  ///   alice,
  ///   const Nonce(9),
  ///   SignActionInput(multisigContract: multisig, actionId: 42),
  /// );
  /// ```
  Future<Transaction> createTransactionForPerformAction(
    IAccount sender,
    Nonce nonce,
    SignActionInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForPerformAction(
      sender: sender.address,
      multisigContract: options.multisigContract,
      actionId: options.actionId,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates and signs a `discardAction` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Caller account
  /// - `nonce` - Sender nonce
  /// - `options` - Action inputs
  /// - `baseOptions` - Optional overrides
  ///
  /// #### Returns
  /// Signed [Transaction].
  ///
  /// #### Example
  /// ```dart
  /// await controller.createTransactionForDiscardAction(
  ///   alice,
  ///   const Nonce(10),
  ///   SignActionInput(multisigContract: multisig, actionId: 42),
  /// );
  /// ```
  Future<Transaction> createTransactionForDiscardAction(
    IAccount sender,
    Nonce nonce,
    SignActionInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction tx = factory.createTransactionForDiscardAction(
      sender: sender.address,
      multisigContract: options.multisigContract,
      actionId: options.actionId,
    );
    return setupAndSignTransaction(
      tx,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Parses a completed multisig-deploy transaction.
  ///
  /// #### Parameters
  /// - `transaction` - Completed [TransactionOnNetwork]
  ///
  /// #### Returns
  /// [SmartContractDeployOutcome] containing the new contract address(es).
  ///
  /// #### Example
  /// ```dart
  /// final outcome = controller.parseDeploy(tx);
  /// ```
  SmartContractDeployOutcome parseDeploy(TransactionOnNetwork transaction) {
    return const SmartContractOutcomeParser().parseDeploy(transaction);
  }

  /// Parses a `proposeAddBoardMember` transaction outcome.
  ///
  /// #### Parameters
  /// - `transaction` - Completed [TransactionOnNetwork]
  ///
  /// #### Returns
  /// [MultisigProposalOutcome] with the action id assigned by the contract.
  MultisigProposalOutcome parseProposeAddBoardMember(
    TransactionOnNetwork transaction,
  ) {
    return _parseProposal(transaction, 'startPerformAction');
  }

  /// Parses a `proposeRemoveUser` transaction outcome.
  MultisigProposalOutcome parseProposeRemoveUser(
    TransactionOnNetwork transaction,
  ) {
    return _parseProposal(transaction, 'startPerformAction');
  }

  /// Parses a `proposeChangeQuorum` transaction outcome.
  MultisigProposalOutcome parseProposeChangeQuorum(
    TransactionOnNetwork transaction,
  ) {
    return _parseProposal(transaction, 'startPerformAction');
  }

  /// Parses a `proposeTransferExecute` transaction outcome.
  MultisigProposalOutcome parseProposeTransferExecute(
    TransactionOnNetwork transaction,
  ) {
    return _parseProposal(transaction, 'startPerformAction');
  }

  /// Parses a `proposeAsyncCall` transaction outcome.
  MultisigProposalOutcome parseProposeAsyncCall(
    TransactionOnNetwork transaction,
  ) {
    return _parseProposal(transaction, 'startPerformAction');
  }

  /// Parses a `sign` transaction outcome.
  ///
  /// #### Parameters
  /// - `transaction` - Completed [TransactionOnNetwork]
  ///
  /// #### Returns
  /// [MultisigActionOutcome] with action id and whether the action was
  /// performed as a side-effect (auto-perform when quorum is reached).
  MultisigActionOutcome parseSign(TransactionOnNetwork transaction) {
    return _parseAction(transaction, 'sign');
  }

  /// Parses an `unsign` transaction outcome.
  MultisigActionOutcome parseUnsign(TransactionOnNetwork transaction) {
    return _parseAction(transaction, 'unsign');
  }

  /// Parses a `performAction` transaction outcome.
  ///
  /// #### Returns
  /// [MultisigPerformActionOutcome] containing the action id and, when the
  /// underlying action is a contract deploy, the deployed-contract address.
  MultisigPerformActionOutcome parsePerformAction(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoSignalError(transaction);
    final BigInt actionId = _readActionIdFromScResult(transaction);
    Address? deployedContract;
    final List<TransactionEvent> events =
        transaction.logs?.findEvents('SCDeploy') ?? const <TransactionEvent>[];
    if (events.isNotEmpty && events.first.topics.isNotEmpty) {
      final Uint8List addrBytes = events.first.topics.first;
      if (addrBytes.length == 32) {
        deployedContract = Address(addrBytes);
      }
    }
    return MultisigPerformActionOutcome(
      actionId: actionId,
      deployedContractAddress: deployedContract,
    );
  }

  /// Parses a `discardAction` transaction outcome.
  MultisigActionOutcome parseDiscardAction(TransactionOnNetwork transaction) {
    return _parseAction(transaction, 'discardAction');
  }

  /// Awaits an execute transaction (sign/unsign/perform/discard) and parses
  /// the action id from the resulting logs.
  ///
  /// #### Parameters
  /// - `txHash` - Transaction hash returned by `sendTransaction`
  ///
  /// #### Returns
  /// [MultisigActionOutcome] for the executed action.
  ///
  /// #### Example
  /// ```dart
  /// final outcome = await controller.awaitCompletedExecute(hash);
  /// ```
  Future<MultisigActionOutcome> awaitCompletedExecute(String txHash) async {
    final NetworkProvider provider = _requireProvider();
    final TransactionWatcher watcher = TransactionWatcher(
      networkProvider: provider,
    );
    final TransactionOnNetwork tx = await watcher.awaitCompleted(txHash);
    return _parseAction(tx, null);
  }

  /// Awaits a multisig-deploy transaction and parses the deployed contract.
  ///
  /// #### Parameters
  /// - `txHash` - Transaction hash returned by `sendTransaction`
  ///
  /// #### Returns
  /// [SmartContractDeployOutcome] with the deployed multisig metadata.
  Future<SmartContractDeployOutcome> awaitCompletedDeploy(String txHash) async {
    final NetworkProvider provider = _requireProvider();
    final TransactionWatcher watcher = TransactionWatcher(
      networkProvider: provider,
    );
    final TransactionOnNetwork tx = await watcher.awaitCompleted(txHash);
    return parseDeploy(tx);
  }

  MultisigProposalOutcome _parseProposal(
    TransactionOnNetwork transaction,
    String eventIdentifier,
  ) {
    _ensureNoSignalError(transaction);
    final BigInt actionId = _readActionIdFromScResult(transaction);
    return MultisigProposalOutcome(actionId: actionId);
  }

  MultisigActionOutcome _parseAction(
    TransactionOnNetwork transaction,
    String? eventIdentifier,
  ) {
    _ensureNoSignalError(transaction);
    final BigInt actionId = _readActionIdFromScResult(transaction);
    return MultisigActionOutcome(actionId: actionId);
  }

  void _ensureNoSignalError(TransactionOnNetwork transaction) {
    if (transaction.logs == null) return;
    final List<TransactionEvent> errs = transaction.logs!.errorEvents;
    if (errs.isNotEmpty) {
      final TransactionEvent event = errs.first;
      final String message = event.topics.length > 1
          ? String.fromCharCodes(event.topics[1])
          : 'signalError';
      throw MultisigParseException('multisig signalError: $message');
    }
  }

  /// Reads the action id from the smart-contract result that carries the
  /// return data of the multisig call.
  ///
  /// The contract returns the action id to the caller, so the eligible SCR is
  /// the one whose `receiver` is the caller (`transaction.sender`) and whose
  /// payload contains a single `BigUint` return value holding the new
  /// action id.
  ///
  /// #### Returns
  /// The decoded action id, or [BigInt.zero] when no eligible SCR is found.
  BigInt _readActionIdFromScResult(TransactionOnNetwork transaction) {
    final List<SmartContractResult>? results = transaction.smartContractResults;
    if (results == null || results.isEmpty) return BigInt.zero;
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
    if (selected.returnData.isEmpty) return BigInt.zero;
    return _bytesToBigInt(selected.returnData.first);
  }

  /// Big-endian conversion of an unsigned hex-encoded buffer into [BigInt].
  ///
  /// Top-level `BigUint` return values are encoded as a minimal big-endian
  /// magnitude with no length prefix, which is how the action id arrives.
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
        'MultisigController.networkProvider is required for awaitCompleted*',
      );
    }
    return provider;
  }
}

/// Exception thrown when multisig outcome parsing fails.
@immutable
class MultisigParseException implements Exception {
  /// Creates a multisig-parse exception.
  const MultisigParseException(this.message);

  /// Human-readable error description.
  final String message;

  @override
  String toString() => 'MultisigParseException: $message';
}

/// Outcome of a multisig `propose*` transaction.
///
/// The action id is the first decoded value of the proposal SCR return data
/// (a `BigUint`).
@immutable
class MultisigProposalOutcome {
  /// Creates a proposal outcome.
  ///
  /// #### Parameters
  /// - `actionId` - The action id assigned by the multisig contract.
  const MultisigProposalOutcome({required this.actionId});

  /// The action id assigned by the multisig contract, decoded from the
  /// SCResult return data.
  final BigInt actionId;
}

/// Outcome of a multisig sign / unsign / discard transaction.
@immutable
class MultisigActionOutcome {
  /// Creates an action outcome.
  ///
  /// #### Parameters
  /// - `actionId` - Action id this transaction acted on.
  const MultisigActionOutcome({required this.actionId});

  /// The action id this transaction acted on (decoded from SCResult).
  final BigInt actionId;
}

/// Outcome of a multisig `performAction` transaction.
@immutable
class MultisigPerformActionOutcome {
  /// Creates a perform-action outcome.
  ///
  /// #### Parameters
  /// - `actionId` - The action id that was performed.
  /// - `deployedContractAddress` - Optional address of the contract deployed
  ///   by the action (when the action was a deploy).
  const MultisigPerformActionOutcome({
    required this.actionId,
    this.deployedContractAddress,
  });

  /// The action id that was performed.
  final BigInt actionId;

  /// Address of the contract deployed by the action, if any.
  final Address? deployedContractAddress;
}

/// Input for proposing a new board member.
@immutable
class ProposeAddBoardMemberInput {
  /// Creates input for adding a board member.
  const ProposeAddBoardMemberInput({
    required this.multisigContract,
    required this.boardMember,
  });

  /// Multisig contract address.
  final Address multisigContract;

  /// New board-member address.
  final Address boardMember;
}

/// Input for proposing a new proposer.
@immutable
class ProposeAddProposerInput {
  /// Creates input for adding a proposer.
  const ProposeAddProposerInput({
    required this.multisigContract,
    required this.proposer,
  });

  /// Multisig contract address.
  final Address multisigContract;

  /// New proposer address.
  final Address proposer;
}

/// Input for proposing a user removal.
@immutable
class ProposeRemoveUserInput {
  /// Creates input for removing a user.
  const ProposeRemoveUserInput({
    required this.multisigContract,
    required this.user,
  });

  /// Multisig contract address.
  final Address multisigContract;

  /// Address to remove.
  final Address user;
}

/// Input for proposing a quorum change.
@immutable
class ProposeChangeQuorumInput {
  /// Creates input for changing the quorum.
  const ProposeChangeQuorumInput({
    required this.multisigContract,
    required this.newQuorum,
  });

  /// Multisig contract address.
  final Address multisigContract;

  /// New quorum.
  final int newQuorum;
}

/// Input for proposing a transfer-execute call.
@immutable
class ProposeTransferExecuteInput {
  /// Creates input for transfer-execute proposal.
  const ProposeTransferExecuteInput({
    required this.multisigContract,
    required this.to,
    required this.egldAmount,
    this.functionCall = const <TypedValue>[],
  });

  /// Multisig contract address.
  final Address multisigContract;

  /// Destination address.
  final Address to;

  /// Native EGLD amount to forward.
  final BigInt egldAmount;

  /// Optional function-name + ABI-typed args forwarded to the proposed call.
  final List<TypedValue> functionCall;
}

/// Input for proposing an async-call.
@immutable
class ProposeAsyncCallInput {
  /// Creates input for async-call proposal.
  const ProposeAsyncCallInput({
    required this.multisigContract,
    required this.to,
    this.egldAmount,
    this.functionCall = const <TypedValue>[],
  });

  /// Multisig contract address.
  final Address multisigContract;

  /// Destination contract address.
  final Address to;

  /// Optional native EGLD amount to forward.
  final BigInt? egldAmount;

  /// Function-name + ABI-typed args forwarded to the proposed async call.
  final List<TypedValue> functionCall;
}

/// Input for sign / unsign / performAction / discardAction.
@immutable
class SignActionInput {
  /// Creates input for an action-id-based multisig op.
  const SignActionInput({
    required this.multisigContract,
    required this.actionId,
  });

  /// Multisig contract address.
  final Address multisigContract;

  /// Action identifier.
  final int actionId;
}
