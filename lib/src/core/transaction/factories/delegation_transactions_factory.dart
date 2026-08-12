/// Factory for creating delegation and staking transactions.
/// Provides low-level builders for validator and delegator operations.
import 'dart:convert';
import 'dart:typed_data';

import '../../../abi/abi.dart';
import '../../../wallet/validator_keys.dart';
import '../../core.dart';

/// Configuration for delegation transactions.
/// Defines gas limits for delegation and staking operations.
class DelegationTransactionsConfig {
  const DelegationTransactionsConfig({
    required this.chainId,
    this.minGasLimit = 50000,
    this.gasLimitPerByte = 1500,
    this.gasLimitStake = 5000000,
    this.gasLimitUnstake = 5000000,
    this.gasLimitUnbond = 5000000,
    this.gasLimitCreateDelegationContract = 50000000,
    this.gasLimitDelegationOperations = 1000000,
    this.additionalGasLimitPerValidatorNode = 6000000,
    this.additionalGasLimitForDelegationOperations = 100000,
    this.defaultGasPrice = 1000000000,
  });

  /// Builds a [DelegationTransactionsConfig] from a shared [TransactionsFactoryConfig].
  ///
  /// #### Parameters
  /// - `shared` - Aggregate factory config populated by `NetworkEntrypoint`.
  ///
  /// #### Returns
  /// A new [DelegationTransactionsConfig] mirroring `shared`'s delegation fields.
  static DelegationTransactionsConfig fromShared(
    TransactionsFactoryConfig shared,
  ) => DelegationTransactionsConfig(
    chainId: shared.chainId,
    minGasLimit: shared.minGasLimit,
    gasLimitPerByte: shared.gasLimitPerByte,
    gasLimitStake: shared.gasLimitStake,
    gasLimitUnstake: shared.gasLimitUnstake,
    gasLimitUnbond: shared.gasLimitUnbond,
    gasLimitCreateDelegationContract: shared.gasLimitCreateDelegationContract,
    gasLimitDelegationOperations: shared.gasLimitDelegationOperations,
    additionalGasLimitPerValidatorNode:
        shared.additionalGasLimitPerValidatorNode,
    additionalGasLimitForDelegationOperations:
        shared.additionalGasLimitForDelegationOperations,
  );

  final ChainId chainId;
  final int minGasLimit;
  final int gasLimitPerByte;
  final int gasLimitStake;
  final int gasLimitUnstake;
  final int gasLimitUnbond;
  final int gasLimitCreateDelegationContract;
  final int gasLimitDelegationOperations;
  final int additionalGasLimitPerValidatorNode;
  final int additionalGasLimitForDelegationOperations;
  final int defaultGasPrice;
}

/// Factory for creating delegation and staking transactions.
///
/// Low-level factory for building unsigned delegation transactions.
class DelegationTransactionsFactory {
  DelegationTransactionsFactory(this.config);
  final ArgSerializer _argSerializer = ArgSerializer();
  final DelegationTransactionsConfig config;

  static const String _delegationManagerAddress =
      'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqylllslmq6y6';

  /// Creates transaction for creating new delegation contract.
  ///
  /// Builds transaction calling `createNewDelegationContract` on the delegation
  /// manager system contract. This deploys a new delegation smart contract that
  /// can accept delegated stake from other users.
  ///
  /// #### Parameters
  /// - `sender` - Validator address that will own the delegation contract
  /// - `totalDelegationCap` - Maximum total stake that can be delegated
  /// - `serviceFee` - Service fee in basis points
  /// - `amount` - Initial stake amount
  /// - `nonce` - Optional transaction nonce
  ///
  /// #### Returns
  /// `Transaction` - Unsigned transaction with calculated gas limit
  Transaction createTransactionForNewDelegationContract({
    required Address sender,
    required BigInt totalDelegationCap,
    required BigInt serviceFee,
    required Balance amount,
    Nonce? nonce,
  }) {
    final List<TypedValue> args = <TypedValue>[
      BigUIntValue(totalDelegationCap),
      BigUIntValue(serviceFee),
    ];

    final int executionGasLimit =
        config.gasLimitCreateDelegationContract +
        config.additionalGasLimitForDelegationOperations;

    return _buildTransaction(
      sender: sender,
      receiver: Address.fromBech32(_delegationManagerAddress),
      functionName: 'createNewDelegationContract',
      args: args,
      value: amount,
      executionGasLimit: executionGasLimit,
      nonce: nonce,
    );
  }

  /// Creates transaction for adding validator nodes to delegation contract.
  ///
  /// Builds transaction calling `addNodes@pubkey1@sig1@pubkey2@sig2...` on the
  /// delegation contract. Each node requires a public key and signed message for
  /// proof of ownership.
  ///
  /// #### Parameters
  /// - `sender` - Validator address that owns the delegation contract
  /// - `delegationContract` - Address of the delegation smart contract
  /// - `publicKeys` - List of BLS public keys for validator nodes
  /// - `signedMessages` - List of signed messages proving node ownership
  /// - `nonce` - Optional transaction nonce
  ///
  /// #### Returns
  /// `Transaction` - Unsigned transaction with calculated gas limit
  ///
  /// #### Throws
  /// - `ArgumentError` - If publicKeys and signedMessages lengths don't match
  Transaction createTransactionForAddingNodes({
    required Address sender,
    required Address delegationContract,
    required List<ValidatorPublicKey> publicKeys,
    required List<Uint8List> signedMessages,
    Nonce? nonce,
  }) {
    if (publicKeys.length != signedMessages.length) {
      throw ArgumentError(
        'The number of public keys should match the number of signed messages',
      );
    }

    final List<String> dataParts = <String>['addNodes'];
    for (int i = 0; i < publicKeys.length; i++) {
      dataParts.add(publicKeys[i].hex);

      final ValuesToStringResult sigResult = _argSerializer.valuesToString(
        <TypedValue>[BytesValue(signedMessages[i])],
      );
      final String sigHex = sigResult.argumentsString;
      dataParts.add(sigHex);
    }

    final Uint8List data = utf8.encode(dataParts.join('@'));
    final int executionGasLimit = _computeExecutionGasLimitForNodesManagement(
      publicKeys.length,
    );

    return Transaction(
      sender: sender,
      receiver: delegationContract,
      data: data,
      nonce: nonce ?? const Nonce(0),
      gasLimit: GasLimit(_totalGasLimit(executionGasLimit, data)),
      gasPrice: GasPrice(config.defaultGasPrice),
      value: Balance.zero(),
      chainId: config.chainId,
      version: const TransactionVersion(1),
      signature: const Signature.empty(),
    );
  }

  /// Creates transaction for removing validator nodes from delegation contract.
  ///
  /// Builds transaction calling `removeNodes@pubkey1@pubkey2...` on the delegation
  /// contract. Nodes must be unstaked and unbonded before removal.
  ///
  /// #### Parameters
  /// - `sender` - Validator address that owns the delegation contract
  /// - `delegationContract` - Address of the delegation smart contract
  /// - `publicKeys` - List of BLS public keys for validator nodes to remove
  /// - `nonce` - Optional transaction nonce
  ///
  /// #### Returns
  /// `Transaction` - Unsigned transaction with calculated gas limit
  Transaction createTransactionForRemovingNodes({
    required Address sender,
    required Address delegationContract,
    required List<ValidatorPublicKey> publicKeys,
    Nonce? nonce,
  }) {
    final List<String> dataParts = <String>['removeNodes'];
    for (final ValidatorPublicKey key in publicKeys) {
      dataParts.add(key.hex);
    }

    final Uint8List data = utf8.encode(dataParts.join('@'));
    final int executionGasLimit = _computeExecutionGasLimitForNodesManagement(
      publicKeys.length,
    );

    return Transaction(
      sender: sender,
      receiver: delegationContract,
      data: data,
      nonce: nonce ?? const Nonce(0),
      gasLimit: GasLimit(_totalGasLimit(executionGasLimit, data)),
      gasPrice: GasPrice(config.defaultGasPrice),
      value: Balance.zero(),
      chainId: config.chainId,
      version: const TransactionVersion(1),
      signature: const Signature.empty(),
    );
  }

  /// Creates transaction for staking validator nodes.
  ///
  /// Builds transaction calling `stakeNodes@pubkey1@pubkey2...` on the delegation
  /// contract. Activates nodes for validation, requiring them to have sufficient stake.
  ///
  /// #### Parameters
  /// - `sender` - Validator address that owns the delegation contract
  /// - `delegationContract` - Address of the delegation smart contract
  /// - `publicKeys` - List of BLS public keys for validator nodes to stake
  /// - `nonce` - Optional transaction nonce
  ///
  /// #### Returns
  /// `Transaction` - Unsigned transaction with calculated gas limit
  Transaction createTransactionForStakingNodes({
    required Address sender,
    required Address delegationContract,
    required List<ValidatorPublicKey> publicKeys,
    Nonce? nonce,
  }) {
    final List<String> dataParts = <String>['stakeNodes'];
    for (final ValidatorPublicKey key in publicKeys) {
      dataParts.add(key.hex);
    }

    final Uint8List data = utf8.encode(dataParts.join('@'));

    final int numNodes = publicKeys.length;
    final BigInt additionalGasForAllNodes =
        BigInt.from(numNodes) *
        BigInt.from(config.additionalGasLimitPerValidatorNode);
    final int executionGasLimit =
        additionalGasForAllNodes.toInt() +
        config.gasLimitStake +
        config.gasLimitDelegationOperations;

    return Transaction(
      sender: sender,
      receiver: delegationContract,
      data: data,
      nonce: nonce ?? const Nonce(0),
      gasLimit: GasLimit(_totalGasLimit(executionGasLimit, data)),
      gasPrice: GasPrice(config.defaultGasPrice),
      value: Balance.zero(),
      chainId: config.chainId,
      version: const TransactionVersion(1),
      signature: const Signature.empty(),
    );
  }

  /// Creates transaction for unstaking validator nodes.
  ///
  /// Builds transaction calling `unStakeNodes@pubkey1@pubkey2...` on the delegation
  /// contract. Deactivates nodes from validation, starting the unbonding period (10 epochs).
  ///
  /// #### Parameters
  /// - `sender` - Validator address that owns the delegation contract
  /// - `delegationContract` - Address of the delegation smart contract
  /// - `publicKeys` - List of BLS public keys for validator nodes to unstake
  /// - `nonce` - Optional transaction nonce
  ///
  /// #### Returns
  /// `Transaction` - Unsigned transaction with calculated gas limit
  Transaction createTransactionForUnstakingNodes({
    required Address sender,
    required Address delegationContract,
    required List<ValidatorPublicKey> publicKeys,
    Nonce? nonce,
  }) {
    final List<String> dataParts = <String>['unStakeNodes'];
    for (final ValidatorPublicKey key in publicKeys) {
      dataParts.add(key.hex);
    }

    final Uint8List data = utf8.encode(dataParts.join('@'));

    final int numNodes = publicKeys.length;
    final BigInt executionGasLimit =
        BigInt.from(numNodes) *
            BigInt.from(config.additionalGasLimitPerValidatorNode) +
        BigInt.from(config.gasLimitUnstake) +
        BigInt.from(config.gasLimitDelegationOperations);

    return Transaction(
      sender: sender,
      receiver: delegationContract,
      data: data,
      nonce: nonce ?? const Nonce(0),
      gasLimit: GasLimit(_totalGasLimit(executionGasLimit.toInt(), data)),
      gasPrice: GasPrice(config.defaultGasPrice),
      value: Balance.zero(),
      chainId: config.chainId,
      version: const TransactionVersion(1),
      signature: const Signature.empty(),
    );
  }

  /// Creates transaction for unbonding validator nodes.
  ///
  /// Builds transaction calling `unBondNodes@pubkey1@pubkey2...` on the delegation
  /// contract. Completes the unbonding period, allowing stake withdrawal. Can only
  /// be called after 10 epochs since unstaking.
  ///
  /// #### Parameters
  /// - `sender` - Validator address that owns the delegation contract
  /// - `delegationContract` - Address of the delegation smart contract
  /// - `publicKeys` - List of BLS public keys for validator nodes to unbond
  /// - `nonce` - Optional transaction nonce
  ///
  /// #### Returns
  /// `Transaction` - Unsigned transaction with calculated gas limit
  Transaction createTransactionForUnbondingNodes({
    required Address sender,
    required Address delegationContract,
    required List<ValidatorPublicKey> publicKeys,
    Nonce? nonce,
  }) {
    final List<String> dataParts = <String>['unBondNodes'];
    for (final ValidatorPublicKey key in publicKeys) {
      dataParts.add(key.hex);
    }

    final Uint8List data = utf8.encode(dataParts.join('@'));

    final int numNodes = publicKeys.length;
    final BigInt executionGasLimit =
        BigInt.from(numNodes) *
            BigInt.from(config.additionalGasLimitPerValidatorNode) +
        BigInt.from(config.gasLimitUnbond) +
        BigInt.from(config.gasLimitDelegationOperations);

    return Transaction(
      sender: sender,
      receiver: delegationContract,
      data: data,
      nonce: nonce ?? const Nonce(0),
      gasLimit: GasLimit(_totalGasLimit(executionGasLimit.toInt(), data)),
      gasPrice: GasPrice(config.defaultGasPrice),
      value: Balance.zero(),
      chainId: config.chainId,
      version: const TransactionVersion(1),
      signature: const Signature.empty(),
    );
  }

  /// Creates transaction for unjailing validator nodes.
  ///
  /// Builds transaction calling `unJailNodes@pubkey1@pubkey2...` on the delegation
  /// contract. Releases nodes from jail (penalty for downtime) by paying a fine of
  /// 2.5 EGLD per node.
  ///
  /// #### Parameters
  /// - `sender` - Validator address that owns the delegation contract
  /// - `delegationContract` - Address of the delegation smart contract
  /// - `publicKeys` - List of BLS public keys for validator nodes to unjail
  /// - `amount` - Fine amount to pay
  /// - `nonce` - Optional transaction nonce
  ///
  /// #### Returns
  /// `Transaction` - Unsigned transaction with calculated gas limit
  Transaction createTransactionForUnjailingNodes({
    required Address sender,
    required Address delegationContract,
    required List<ValidatorPublicKey> publicKeys,
    required Balance amount,
    Nonce? nonce,
  }) {
    final List<String> dataParts = <String>['unJailNodes'];
    for (final ValidatorPublicKey key in publicKeys) {
      dataParts.add(key.hex);
    }

    final Uint8List data = utf8.encode(dataParts.join('@'));
    final int executionGasLimit = _computeExecutionGasLimitForNodesManagement(
      publicKeys.length,
    );

    return Transaction(
      sender: sender,
      receiver: delegationContract,
      data: data,
      nonce: nonce ?? const Nonce(0),
      gasLimit: GasLimit(_totalGasLimit(executionGasLimit, data)),
      gasPrice: GasPrice(config.defaultGasPrice),
      value: amount,
      chainId: config.chainId,
      version: const TransactionVersion(1),
      signature: const Signature.empty(),
    );
  }

  /// Creates transaction for changing service fee of delegation contract.
  Transaction createTransactionForChangingServiceFee({
    required Address sender,
    required Address delegationContract,
    required BigInt serviceFee,
    Nonce? nonce,
  }) {
    final List<TypedValue> args = <TypedValue>[BigUIntValue(serviceFee)];

    final int executionGasLimit =
        config.gasLimitDelegationOperations +
        config.additionalGasLimitForDelegationOperations;

    return _buildTransaction(
      sender: sender,
      receiver: delegationContract,
      functionName: 'changeServiceFee',
      args: args,
      executionGasLimit: executionGasLimit,
      nonce: nonce,
    );
  }

  /// Creates transaction for modifying delegation cap.
  Transaction createTransactionForModifyingDelegationCap({
    required Address sender,
    required Address delegationContract,
    required BigInt delegationCap,
    Nonce? nonce,
  }) {
    final List<TypedValue> args = <TypedValue>[BigUIntValue(delegationCap)];

    final int executionGasLimit =
        config.gasLimitDelegationOperations +
        config.additionalGasLimitForDelegationOperations;

    return _buildTransaction(
      sender: sender,
      receiver: delegationContract,
      functionName: 'modifyTotalDelegationCap',
      args: args,
      executionGasLimit: executionGasLimit,
      nonce: nonce,
    );
  }

  /// Creates transaction for enabling automatic activation of nodes.
  Transaction createTransactionForSettingAutomaticActivation({
    required Address sender,
    required Address delegationContract,
    Nonce? nonce,
  }) {
    final List<TypedValue> args = <TypedValue>[StringValue('true')];

    final int executionGasLimit =
        config.gasLimitDelegationOperations +
        config.additionalGasLimitForDelegationOperations;

    return _buildTransaction(
      sender: sender,
      receiver: delegationContract,
      functionName: 'setAutomaticActivation',
      args: args,
      executionGasLimit: executionGasLimit,
      nonce: nonce,
    );
  }

  /// Creates transaction for disabling automatic activation of nodes.
  Transaction createTransactionForUnsettingAutomaticActivation({
    required Address sender,
    required Address delegationContract,
    Nonce? nonce,
  }) {
    final List<TypedValue> args = <TypedValue>[StringValue('false')];

    final int executionGasLimit =
        config.gasLimitDelegationOperations +
        config.additionalGasLimitForDelegationOperations;

    return _buildTransaction(
      sender: sender,
      receiver: delegationContract,
      functionName: 'setAutomaticActivation',
      args: args,
      executionGasLimit: executionGasLimit,
      nonce: nonce,
    );
  }

  /// Creates transaction for enabling cap check on redelegate rewards.
  Transaction createTransactionForSettingCapCheckOnRedelegateRewards({
    required Address sender,
    required Address delegationContract,
    Nonce? nonce,
  }) {
    final List<TypedValue> args = <TypedValue>[StringValue('true')];

    final int executionGasLimit =
        config.gasLimitDelegationOperations +
        config.additionalGasLimitForDelegationOperations;

    return _buildTransaction(
      sender: sender,
      receiver: delegationContract,
      functionName: 'setCheckCapOnReDelegateRewards',
      args: args,
      executionGasLimit: executionGasLimit,
      nonce: nonce,
    );
  }

  /// Creates transaction for disabling cap check on redelegate rewards.
  Transaction createTransactionForUnsettingCapCheckOnRedelegateRewards({
    required Address sender,
    required Address delegationContract,
    Nonce? nonce,
  }) {
    final List<TypedValue> args = <TypedValue>[StringValue('false')];

    final int executionGasLimit =
        config.gasLimitDelegationOperations +
        config.additionalGasLimitForDelegationOperations;

    return _buildTransaction(
      sender: sender,
      receiver: delegationContract,
      functionName: 'setCheckCapOnReDelegateRewards',
      args: args,
      executionGasLimit: executionGasLimit,
      nonce: nonce,
    );
  }

  /// Creates transaction for setting delegation contract metadata.
  Transaction createTransactionForSettingMetadata({
    required Address sender,
    required Address delegationContract,
    required String name,
    required String website,
    required String identifier,
    Nonce? nonce,
  }) {
    final List<TypedValue> args = <TypedValue>[
      StringValue(name),
      StringValue(website),
      StringValue(identifier),
    ];

    final int executionGasLimit =
        config.gasLimitDelegationOperations +
        config.additionalGasLimitForDelegationOperations;

    return _buildTransaction(
      sender: sender,
      receiver: delegationContract,
      functionName: 'setMetaData',
      args: args,
      executionGasLimit: executionGasLimit,
      nonce: nonce,
    );
  }

  /// Creates transaction for delegating tokens to staking provider.
  Transaction createTransactionForDelegating({
    required Address sender,
    required Address delegationContract,
    required Balance amount,
    Nonce? nonce,
  }) {
    final int executionGasLimit =
        config.gasLimitDelegationOperations +
        config.additionalGasLimitForDelegationOperations;

    return _buildTransaction(
      sender: sender,
      receiver: delegationContract,
      functionName: 'delegate',
      args: <TypedValue>[],
      value: amount,
      executionGasLimit: executionGasLimit,
      nonce: nonce,
    );
  }

  /// Creates transaction for claiming staking rewards.
  Transaction createTransactionForClaimingRewards({
    required Address sender,
    required Address delegationContract,
    Nonce? nonce,
  }) {
    final int executionGasLimit =
        config.gasLimitDelegationOperations +
        config.additionalGasLimitForDelegationOperations;

    return _buildTransaction(
      sender: sender,
      receiver: delegationContract,
      functionName: 'claimRewards',
      args: <TypedValue>[],
      executionGasLimit: executionGasLimit,
      nonce: nonce,
    );
  }

  /// Creates transaction for redelegating staking rewards.
  Transaction createTransactionForRedelegatingRewards({
    required Address sender,
    required Address delegationContract,
    Nonce? nonce,
  }) {
    final int executionGasLimit =
        config.gasLimitDelegationOperations +
        config.additionalGasLimitForDelegationOperations;

    return _buildTransaction(
      sender: sender,
      receiver: delegationContract,
      functionName: 'reDelegateRewards',
      args: <TypedValue>[],
      executionGasLimit: executionGasLimit,
      nonce: nonce,
    );
  }

  /// Creates transaction for undelegating tokens from staking provider.
  Transaction createTransactionForUndelegating({
    required Address sender,
    required Address delegationContract,
    required Balance amount,
    Nonce? nonce,
  }) {
    final List<TypedValue> args = <TypedValue>[BigUIntValue(amount.value)];

    final int executionGasLimit =
        config.gasLimitDelegationOperations +
        config.additionalGasLimitForDelegationOperations;

    return _buildTransaction(
      sender: sender,
      receiver: delegationContract,
      functionName: 'unDelegate',
      args: args,
      executionGasLimit: executionGasLimit,
      nonce: nonce,
    );
  }

  /// Creates transaction for withdrawing undelegated tokens.
  Transaction createTransactionForWithdrawing({
    required Address sender,
    required Address delegationContract,
    Nonce? nonce,
  }) {
    final int executionGasLimit =
        config.gasLimitDelegationOperations +
        config.additionalGasLimitForDelegationOperations;

    return _buildTransaction(
      sender: sender,
      receiver: delegationContract,
      functionName: 'withdraw',
      args: <TypedValue>[],
      executionGasLimit: executionGasLimit,
      nonce: nonce,
    );
  }

  int _computeExecutionGasLimitForNodesManagement(int numNodes) {
    final int additionalGasForAllNodes =
        config.additionalGasLimitPerValidatorNode * numNodes;
    return config.gasLimitDelegationOperations + additionalGasForAllNodes;
  }

  /// Adds the gas the chain charges for moving [data] across the network to an
  /// execution gas allowance.
  int _totalGasLimit(int executionGasLimit, Uint8List data) =>
      config.minGasLimit +
      config.gasLimitPerByte * data.length +
      executionGasLimit;

  Transaction _buildTransaction({
    required Address sender,
    required Address receiver,
    required String functionName,
    required List<TypedValue> args,
    Balance? value,
    required int executionGasLimit,
    Nonce? nonce,
  }) {
    final ValuesToStringResult result = _argSerializer.valuesToString(args);

    final List<String> dataParts = <String>[functionName];
    if (result.count > 0) {
      dataParts.addAll(result.argumentsString.split('@'));
    }
    final Uint8List data = utf8.encode(dataParts.join('@'));

    return Transaction(
      sender: sender,
      receiver: receiver,
      data: data,
      nonce: nonce ?? const Nonce(0),
      gasLimit: GasLimit(_totalGasLimit(executionGasLimit, data)),
      gasPrice: GasPrice(config.defaultGasPrice),
      value: value ?? Balance.zero(),
      chainId: config.chainId,
      version: const TransactionVersion(1),
      signature: const Signature.empty(),
    );
  }
}
