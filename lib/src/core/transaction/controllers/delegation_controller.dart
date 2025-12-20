/// Controller for delegation and staking transactions.
///
/// Provides high-level API for creating delegation contracts, managing validator
/// nodes, and handling delegator operations (stake, unstake, rewards). Supports
/// full validator lifecycle and staking provider management.
///
/// #### Validator Operations
/// - Create delegation contract
/// - Add/remove/stake/unstake/unbond nodes
/// - Unjail nodes
/// - Change service fee and delegation cap
/// - Set metadata
///
/// #### Delegator Operations
/// - Delegate funds
/// - Undelegate funds
/// - Withdraw/claim rewards
/// - Redelegate rewards
import 'dart:typed_data';

import '../../../wallet/validator_keys.dart';
import '../../core.dart';

/// Input for creating a new delegation contract.
///
/// Defines delegation cap, service fee, and initial stake amount.
///
/// #### Example
/// ```dart
/// final input = NewDelegationContractInput(
///   totalDelegationCap: BigInt.from(100000000),  // 100M EGLD cap
///   serviceFee: BigInt.from(1000),  // 10% fee (10000 = 100%)
///   amount: Balance.fromEgld(1250),  // 1250 EGLD initial stake
/// );
/// ```
class NewDelegationContractInput {
  /// Creates input for new delegation contract.
  ///
  /// #### Parameters
  /// - `totalDelegationCap` - Maximum total stake
  /// - `serviceFee` - Service fee percentage
  /// - `amount` - Initial stake amount
  const NewDelegationContractInput({
    required this.totalDelegationCap,
    required this.serviceFee,
    required this.amount,
  });

  /// Maximum total delegation cap (in smallest denomination).
  final BigInt totalDelegationCap;

  /// Service fee percentage (1000 = 10%, 10000 = 100%).
  final BigInt serviceFee;

  /// Initial stake amount.
  final Balance amount;
}

/// Input for adding validator nodes to delegation contract.
///
/// #### Example
/// ```dart
/// final input = AddNodesInput(
///   delegationContract: contractAddress,
///   publicKeys: [validatorPubKey1, validatorPubKey2],
///   signedMessages: [signedMsg1, signedMsg2],
/// );
/// ```
class AddNodesInput {
  /// Creates input for adding validator nodes.
  const AddNodesInput({
    required this.delegationContract,
    required this.publicKeys,
    required this.signedMessages,
  });

  /// Delegation contract address.
  final Address delegationContract;

  /// List of validator public keys to add.
  final List<ValidatorPublicKey> publicKeys;

  /// List of signed messages corresponding to the public keys.
  final List<Uint8List> signedMessages;
}

/// Input for managing nodes (remove, stake, unstake, unbond).
class ManageNodesInput {
  /// Creates input for managing validator nodes.
  const ManageNodesInput({
    required this.delegationContract,
    required this.publicKeys,
  });

  /// Delegation contract address.
  final Address delegationContract;

  /// List of validator public keys to manage.
  final List<ValidatorPublicKey> publicKeys;
}

/// Input for unjailing nodes.
class UnjailingNodesInput {
  /// Creates input for unjailing validator nodes.
  const UnjailingNodesInput({
    required this.delegationContract,
    required this.publicKeys,
    required this.amount,
  });

  /// Delegation contract address.
  final Address delegationContract;

  /// List of validator public keys to unjail.
  final List<ValidatorPublicKey> publicKeys;

  /// Amount to pay for unjailing.
  final Balance amount;
}

/// Input for changing service fee.
class ChangeServiceFeeInput {
  /// Creates input for changing service fee.
  const ChangeServiceFeeInput({
    required this.delegationContract,
    required this.serviceFee,
  });

  /// Delegation contract address.
  final Address delegationContract;

  /// New service fee percentage (1000 = 10%, 10000 = 100%).
  final BigInt serviceFee;
}

/// Input for modifying delegation cap.
class ModifyDelegationCapInput {
  /// Creates input for modifying delegation cap.
  const ModifyDelegationCapInput({
    required this.delegationContract,
    required this.delegationCap,
  });

  /// Delegation contract address.
  final Address delegationContract;

  /// New delegation cap (in smallest denomination).
  final BigInt delegationCap;
}

/// Input for managing delegation contract settings.
class ManageDelegationContractInput {
  /// Creates input for managing delegation contract settings.
  const ManageDelegationContractInput({required this.delegationContract});

  /// Delegation contract address.
  final Address delegationContract;
}

/// Input for setting metadata.
class SetMetadataInput {
  /// Creates input for setting delegation contract metadata.
  const SetMetadataInput({
    required this.delegationContract,
    required this.name,
    required this.website,
    required this.identifier,
  });

  /// Delegation contract address.
  final Address delegationContract;

  /// Delegation contract name.
  final String name;

  /// Delegation contract website.
  final String website;

  /// Delegation contract identifier.
  final String identifier;
}

/// Input for delegating funds.
class DelegateInput {
  /// Creates input for delegating funds.
  const DelegateInput({required this.delegationContract, required this.amount});

  /// Delegation contract address.
  final Address delegationContract;

  /// Amount to delegate.
  final Balance amount;
}

/// Input for undelegating funds.
class UndelegateInput {
  /// Creates input for undelegating funds.
  const UndelegateInput({
    required this.delegationContract,
    required this.amount,
  });

  /// Delegation contract address.
  final Address delegationContract;

  /// Amount to undelegate.
  final Balance amount;
}

/// Input for withdrawing/claiming from delegation contract.
class WithdrawInput {
  /// Creates input for withdrawing/claiming funds.
  const WithdrawInput({required this.delegationContract});

  /// Delegation contract address.
  final Address delegationContract;
}

/// Controller for delegation and staking operations.
/// Extends BaseController for gas estimation and signing.
///
/// #### Example
/// ```dart
/// final controller = DelegationController(
///   chainId: '1',
///   gasLimitEstimator: estimator,
/// );
/// ```
class DelegationController extends BaseController {
  /// Creates delegation controller with chain ID and optional gas estimator.
  ///
  /// #### Parameters
  /// - `chainId` - Network chain ID
  /// - `gasLimitEstimator` - Optional gas estimator
  DelegationController({required ChainId chainId, super.gasLimitEstimator})
    : factory = DelegationTransactionsFactory(
        DelegationTransactionsConfig(chainId: chainId),
      );

  /// Factory for creating delegation transactions.
  final DelegationTransactionsFactory factory;

  /// Creates transaction for creating new delegation contract.
  Future<Transaction> createTransactionForNewDelegationContract(
    IAccount sender,
    Nonce nonce,
    NewDelegationContractInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory
        .createTransactionForNewDelegationContract(
          sender: sender.address,
          totalDelegationCap: options.totalDelegationCap,
          serviceFee: options.serviceFee,
          amount: options.amount,
        );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for adding validator nodes.
  Future<Transaction> createTransactionForAddingNodes(
    IAccount sender,
    Nonce nonce,
    AddNodesInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory.createTransactionForAddingNodes(
      sender: sender.address,
      delegationContract: options.delegationContract,
      publicKeys: options.publicKeys,
      signedMessages: options.signedMessages,
    );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for removing validator nodes.
  Future<Transaction> createTransactionForRemovingNodes(
    IAccount sender,
    Nonce nonce,
    ManageNodesInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory.createTransactionForRemovingNodes(
      sender: sender.address,
      delegationContract: options.delegationContract,
      publicKeys: options.publicKeys,
    );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for staking validator nodes.
  Future<Transaction> createTransactionForStakingNodes(
    IAccount sender,
    Nonce nonce,
    ManageNodesInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory.createTransactionForStakingNodes(
      sender: sender.address,
      delegationContract: options.delegationContract,
      publicKeys: options.publicKeys,
    );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for unstaking validator nodes.
  Future<Transaction> createTransactionForUnstakingNodes(
    IAccount sender,
    Nonce nonce,
    ManageNodesInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory.createTransactionForUnstakingNodes(
      sender: sender.address,
      delegationContract: options.delegationContract,
      publicKeys: options.publicKeys,
    );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for unbonding validator nodes.
  Future<Transaction> createTransactionForUnbondingNodes(
    IAccount sender,
    Nonce nonce,
    ManageNodesInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory.createTransactionForUnbondingNodes(
      sender: sender.address,
      delegationContract: options.delegationContract,
      publicKeys: options.publicKeys,
    );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for unjailing validator nodes.
  Future<Transaction> createTransactionForUnjailingNodes(
    IAccount sender,
    Nonce nonce,
    UnjailingNodesInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory.createTransactionForUnjailingNodes(
      sender: sender.address,
      delegationContract: options.delegationContract,
      publicKeys: options.publicKeys,
      amount: options.amount,
    );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for changing service fee.
  Future<Transaction> createTransactionForChangingServiceFee(
    IAccount sender,
    Nonce nonce,
    ChangeServiceFeeInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory
        .createTransactionForChangingServiceFee(
          sender: sender.address,
          delegationContract: options.delegationContract,
          serviceFee: options.serviceFee,
        );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for modifying delegation cap.
  Future<Transaction> createTransactionForModifyingDelegationCap(
    IAccount sender,
    Nonce nonce,
    ModifyDelegationCapInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory
        .createTransactionForModifyingDelegationCap(
          sender: sender.address,
          delegationContract: options.delegationContract,
          delegationCap: options.delegationCap,
        );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for setting automatic activation.
  Future<Transaction> createTransactionForSettingAutomaticActivation(
    IAccount sender,
    Nonce nonce,
    ManageDelegationContractInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory
        .createTransactionForSettingAutomaticActivation(
          sender: sender.address,
          delegationContract: options.delegationContract,
        );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for unsetting automatic activation.
  Future<Transaction> createTransactionForUnsettingAutomaticActivation(
    IAccount sender,
    Nonce nonce,
    ManageDelegationContractInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory
        .createTransactionForUnsettingAutomaticActivation(
          sender: sender.address,
          delegationContract: options.delegationContract,
        );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for setting cap check on redelegate rewards.
  Future<Transaction> createTransactionForSettingCapCheckOnRedelegateRewards(
    IAccount sender,
    Nonce nonce,
    ManageDelegationContractInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory
        .createTransactionForSettingCapCheckOnRedelegateRewards(
          sender: sender.address,
          delegationContract: options.delegationContract,
        );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for unsetting cap check on redelegate rewards.
  Future<Transaction> createTransactionForUnsettingCapCheckOnRedelegateRewards(
    IAccount sender,
    Nonce nonce,
    ManageDelegationContractInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory
        .createTransactionForUnsettingCapCheckOnRedelegateRewards(
          sender: sender.address,
          delegationContract: options.delegationContract,
        );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for setting metadata.
  Future<Transaction> createTransactionForSettingMetadata(
    IAccount sender,
    Nonce nonce,
    SetMetadataInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory.createTransactionForSettingMetadata(
      sender: sender.address,
      delegationContract: options.delegationContract,
      name: options.name,
      website: options.website,
      identifier: options.identifier,
    );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for delegating funds.
  Future<Transaction> createTransactionForDelegating(
    IAccount sender,
    Nonce nonce,
    DelegateInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory.createTransactionForDelegating(
      sender: sender.address,
      delegationContract: options.delegationContract,
      amount: options.amount,
    );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for undelegating funds.
  Future<Transaction> createTransactionForUndelegating(
    IAccount sender,
    Nonce nonce,
    UndelegateInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory.createTransactionForUndelegating(
      sender: sender.address,
      delegationContract: options.delegationContract,
      amount: options.amount,
    );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for withdrawing funds.
  Future<Transaction> createTransactionForWithdrawing(
    IAccount sender,
    Nonce nonce,
    WithdrawInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory.createTransactionForWithdrawing(
      sender: sender.address,
      delegationContract: options.delegationContract,
    );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for claiming rewards.
  Future<Transaction> createTransactionForClaimingRewards(
    IAccount sender,
    Nonce nonce,
    WithdrawInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory.createTransactionForClaimingRewards(
      sender: sender.address,
      delegationContract: options.delegationContract,
    );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for redelegating rewards.
  Future<Transaction> createTransactionForRedelegatingRewards(
    IAccount sender,
    Nonce nonce,
    WithdrawInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory
        .createTransactionForRedelegatingRewards(
          sender: sender.address,
          delegationContract: options.delegationContract,
        );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }
}
