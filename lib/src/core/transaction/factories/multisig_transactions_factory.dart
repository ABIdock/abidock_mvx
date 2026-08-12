/// Factory for building unsigned multisig system-contract transactions.
///
/// Multisig contracts on MultiversX expose `propose*`, `sign`, `unsign`,
/// `performAction`, `discardAction`, batch variants, and `deposit` /
/// `depositExecute` endpoints. This factory only encodes the `data` field —
/// the caller signs and broadcasts.
///
/// Every method below funnels its arguments through [ArgSerializer]
/// (`valuesToStrings`), so `OptionValue<U64>`, `VariadicValue<TypedValue>`,
/// `CodeMetadataValue`, `BytesValue` and `AddressValue` reach the `data`
/// field in exactly the byte layout the contract's argument decoder expects.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart' as convert;
import 'package:meta/meta.dart';

import '../../../abi/core/type_system.dart';
import '../../../abi/serializers/arg_serializer.dart';
import '../../../abi/types/collections/option.dart';
import '../../../abi/types/primitives/address.dart';
import '../../../abi/types/primitives/biguint.dart';
import '../../../abi/types/primitives/u32.dart';
import '../../../abi/types/primitives/u64.dart';
import '../../../abi/types/special/code_metadata.dart';
import '../../address.dart';
import '../../balance.dart';
import '../../nonce.dart';
import '../chain_id.dart';
import '../gas_models/gas_limit.dart';
import '../gas_models/gas_price.dart';
import '../transaction.dart';
import '../transaction_version.dart';
import '../transactions_factory_config.dart';

/// Configuration for [MultisigTransactionsFactory].
@immutable
class MultisigTransactionsConfig {
  /// Creates a multisig factory configuration.
  ///
  /// #### Parameters
  /// - `chainId` - Target chain id
  /// - `minGasLimit` - Minimum base gas (default 50_000)
  /// - `gasLimitPerByte` - Per-byte data-field gas (default 1_500)
  /// - `gasLimitProposeAction` - Gas for `propose*` calls
  /// - `gasLimitSign` - Gas for `sign` / `unsign`
  /// - `gasLimitPerformAction` - Gas for `performAction` / `discardAction`
  /// - `defaultGasPrice` - Default gas price (default 1_000_000_000)
  const MultisigTransactionsConfig({
    required this.chainId,
    this.minGasLimit = 50000,
    this.gasLimitPerByte = 1500,
    this.gasLimitProposeAction = 25_000_000,
    this.gasLimitSign = 10_000_000,
    this.gasLimitPerformAction = 30_000_000,
    this.defaultGasPrice = 1000000000,
  });

  /// Builds a [MultisigTransactionsConfig] from a shared [TransactionsFactoryConfig].
  ///
  /// #### Parameters
  /// - `shared` - Aggregate factory config populated by `NetworkEntrypoint`.
  ///
  /// #### Returns
  /// A new [MultisigTransactionsConfig] mirroring `shared`'s multisig fields.
  static MultisigTransactionsConfig fromShared(
    TransactionsFactoryConfig shared,
  ) => MultisigTransactionsConfig(
    chainId: shared.chainId,
    minGasLimit: shared.minGasLimit,
    gasLimitPerByte: shared.gasLimitPerByte,
    gasLimitProposeAction: shared.gasLimitForMultisigOperations,
    gasLimitSign: shared.gasLimitForMultisigOperations,
    gasLimitPerformAction: shared.gasLimitForMultisigOperations,
  );

  /// Target chain id.
  final ChainId chainId;

  /// Minimum base gas.
  final int minGasLimit;

  /// Per-byte data-field gas.
  final int gasLimitPerByte;

  /// Gas used by every `propose*` call.
  final int gasLimitProposeAction;

  /// Gas used by `sign` / `unsign`.
  final int gasLimitSign;

  /// Gas used by `performAction` / `discardAction`.
  final int gasLimitPerformAction;

  /// Default gas price.
  final int defaultGasPrice;
}

/// Builds unsigned multisig system-contract transactions.
///
/// #### Example
/// ```dart
/// final factory = MultisigTransactionsFactory(
///   const MultisigTransactionsConfig(chainId: ChainId.devnet()),
/// );
/// final tx = factory.createTransactionForProposeAddBoardMember(
///   sender: alice.address,
///   multisigContract: multisig,
///   boardMember: bob.address,
/// );
/// ```
@immutable
class MultisigTransactionsFactory {
  /// Creates a multisig transactions factory.
  MultisigTransactionsFactory(this.config) : _argSerializer = ArgSerializer();

  /// Factory configuration.
  final MultisigTransactionsConfig config;

  /// Arg-serializer used to encode every typed value to its MultiversX
  /// wire-format hex chunk.
  final ArgSerializer _argSerializer;

  /// Creates an unsigned `proposeAddBoardMember` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Caller address
  /// - `multisigContract` - Multisig contract address
  /// - `boardMember` - New board-member address
  ///
  /// #### Returns
  /// Unsigned [Transaction].
  ///
  /// #### Example
  /// ```dart
  /// factory.createTransactionForProposeAddBoardMember(
  ///   sender: alice.address,
  ///   multisigContract: multisig,
  ///   boardMember: bob.address,
  /// );
  /// ```
  Transaction createTransactionForProposeAddBoardMember({
    required Address sender,
    required Address multisigContract,
    required Address boardMember,
  }) {
    return _execute(
      sender: sender,
      multisigContract: multisigContract,
      function: 'proposeAddBoardMember',
      args: <TypedValue>[_addressValue(boardMember)],
      gas: config.gasLimitProposeAction,
    );
  }

  /// Creates an unsigned `proposeAddProposer` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Caller address
  /// - `multisigContract` - Multisig contract address
  /// - `proposer` - New proposer address
  ///
  /// #### Returns
  /// Unsigned [Transaction].
  Transaction createTransactionForProposeAddProposer({
    required Address sender,
    required Address multisigContract,
    required Address proposer,
  }) {
    return _execute(
      sender: sender,
      multisigContract: multisigContract,
      function: 'proposeAddProposer',
      args: <TypedValue>[_addressValue(proposer)],
      gas: config.gasLimitProposeAction,
    );
  }

  /// Creates an unsigned `proposeRemoveUser` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Caller address
  /// - `multisigContract` - Multisig contract address
  /// - `user` - Address to remove from the board / proposer list
  ///
  /// #### Returns
  /// Unsigned [Transaction].
  Transaction createTransactionForProposeRemoveUser({
    required Address sender,
    required Address multisigContract,
    required Address user,
  }) {
    return _execute(
      sender: sender,
      multisigContract: multisigContract,
      function: 'proposeRemoveUser',
      args: <TypedValue>[_addressValue(user)],
      gas: config.gasLimitProposeAction,
    );
  }

  /// Creates an unsigned `proposeChangeQuorum` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Caller address
  /// - `multisigContract` - Multisig contract address
  /// - `newQuorum` - New quorum size (positive)
  ///
  /// #### Returns
  /// Unsigned [Transaction].
  Transaction createTransactionForProposeChangeQuorum({
    required Address sender,
    required Address multisigContract,
    required int newQuorum,
  }) {
    return _execute(
      sender: sender,
      multisigContract: multisigContract,
      function: 'proposeChangeQuorum',
      args: <TypedValue>[U32Value(newQuorum)],
      gas: config.gasLimitProposeAction,
    );
  }

  /// Creates an unsigned `proposeTransferExecute` transaction (forwards
  /// native EGLD and an optional inline contract-call payload).
  ///
  /// Argument order on the wire is `to`, `egldAmount`, `Option<U64>` gas
  /// limit, then the variadic forwarded call.
  ///
  /// #### Parameters
  /// - `sender` - Caller address
  /// - `multisigContract` - Multisig contract address
  /// - `to` - Destination address
  /// - `egldAmount` - Native EGLD amount to forward (in attoEGLD)
  /// - `optGasLimit` - Optional `U64` gas limit for the forwarded call
  /// - `functionCall` - Optional already-typed arguments for the forwarded
  ///   call (function name + ABI-typed args). Pass `<TypedValue>[]` when
  ///   making a pure value transfer.
  ///
  /// #### Returns
  /// Unsigned [Transaction].
  Transaction createTransactionForProposeTransferExecute({
    required Address sender,
    required Address multisigContract,
    required Address to,
    required BigInt egldAmount,
    BigInt? optGasLimit,
    List<TypedValue> functionCall = const <TypedValue>[],
  }) {
    final List<TypedValue> args = <TypedValue>[
      _addressValue(to),
      BigUIntValue(egldAmount),
      _u64Option(optGasLimit),
      ...functionCall,
    ];
    return _executeArgs(
      sender: sender,
      multisigContract: multisigContract,
      function: 'proposeTransferExecute',
      args: args,
      gas: config.gasLimitProposeAction,
    );
  }

  /// Creates an unsigned `proposeTransferExecuteEsdt` transaction (forwards
  /// ESDT/NFT token transfers and an optional inline contract-call payload).
  ///
  /// #### Parameters
  /// - `sender` - Caller address
  /// - `multisigContract` - Multisig contract address
  /// - `to` - Destination address
  /// - `tokens` - Already-encoded `EsdtTokenPayment` typed values
  /// - `optGasLimit` - Optional `U64` gas limit for the forwarded call
  /// - `functionCall` - Optional already-typed arguments for the forwarded
  ///   call (function name + ABI-typed args).
  Transaction createTransactionForProposeTransferExecuteEsdt({
    required Address sender,
    required Address multisigContract,
    required Address to,
    required List<TypedValue> tokens,
    BigInt? optGasLimit,
    List<TypedValue> functionCall = const <TypedValue>[],
  }) {
    return _executeArgs(
      sender: sender,
      multisigContract: multisigContract,
      function: 'proposeTransferExecuteEsdt',
      args: <TypedValue>[
        _addressValue(to),
        ...tokens,
        _u64Option(optGasLimit),
        ...functionCall,
      ],
      gas: config.gasLimitProposeAction,
    );
  }

  /// Creates an unsigned `proposeAsyncCall` transaction.
  ///
  /// Argument order on the wire is `to`, `egldAmount`, `Option<U64>` gas
  /// limit, then the variadic forwarded call.
  ///
  /// #### Parameters
  /// - `sender` - Caller address
  /// - `multisigContract` - Multisig contract address
  /// - `to` - Destination contract address
  /// - `egldAmount` - Optional native EGLD amount to forward (default zero)
  /// - `optGasLimit` - Optional `U64` gas limit
  /// - `functionCall` - Function-name + ABI-typed arg values
  Transaction createTransactionForProposeAsyncCall({
    required Address sender,
    required Address multisigContract,
    required Address to,
    BigInt? egldAmount,
    BigInt? optGasLimit,
    List<TypedValue> functionCall = const <TypedValue>[],
  }) {
    return _executeArgs(
      sender: sender,
      multisigContract: multisigContract,
      function: 'proposeAsyncCall',
      args: <TypedValue>[
        _addressValue(to),
        BigUIntValue(egldAmount ?? BigInt.zero),
        _u64Option(optGasLimit),
        ...functionCall,
      ],
      gas: config.gasLimitProposeAction,
    );
  }

  /// Creates an unsigned `proposeSCDeployFromSource` transaction (proposes
  /// to deploy a new contract by copying another contract's bytecode).
  ///
  /// #### Parameters
  /// - `sender` - Caller address
  /// - `multisigContract` - Multisig contract address
  /// - `amount` - EGLD to attach to the deploy
  /// - `source` - Existing contract whose code will be copied
  /// - `codeMetadata` - Two-byte code-metadata flags
  /// - `arguments` - Typed-value constructor arguments
  Transaction createTransactionForProposeContractDeployFromSource({
    required Address sender,
    required Address multisigContract,
    required BigInt amount,
    required Address source,
    required Uint8List codeMetadata,
    List<TypedValue> arguments = const <TypedValue>[],
  }) {
    return _executeArgs(
      sender: sender,
      multisigContract: multisigContract,
      function: 'proposeSCDeployFromSource',
      args: <TypedValue>[
        BigUIntValue(amount),
        _addressValue(source),
        CodeMetadataValue(_codeMetadataInt(codeMetadata)),
        ...arguments,
      ],
      gas: config.gasLimitProposeAction,
    );
  }

  /// Creates an unsigned `proposeSCUpgradeFromSource` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Caller address
  /// - `multisigContract` - Multisig contract address
  /// - `target` - Contract to upgrade
  /// - `amount` - EGLD to attach
  /// - `source` - Existing contract whose code will be copied
  /// - `codeMetadata` - Two-byte code-metadata flags
  /// - `arguments` - Typed-value upgrade arguments
  Transaction createTransactionForProposeContractUpgradeFromSource({
    required Address sender,
    required Address multisigContract,
    required Address target,
    required BigInt amount,
    required Address source,
    required Uint8List codeMetadata,
    List<TypedValue> arguments = const <TypedValue>[],
  }) {
    return _executeArgs(
      sender: sender,
      multisigContract: multisigContract,
      function: 'proposeSCUpgradeFromSource',
      args: <TypedValue>[
        _addressValue(target),
        BigUIntValue(amount),
        _addressValue(source),
        CodeMetadataValue(_codeMetadataInt(codeMetadata)),
        ...arguments,
      ],
      gas: config.gasLimitProposeAction,
    );
  }

  /// Creates an unsigned `proposeBatch` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Caller address
  /// - `multisigContract` - Multisig contract address
  /// - `actions` - Already-typed encoded actions
  Transaction createTransactionForProposeBatch({
    required Address sender,
    required Address multisigContract,
    required List<TypedValue> actions,
  }) {
    return _executeArgs(
      sender: sender,
      multisigContract: multisigContract,
      function: 'proposeBatch',
      args: actions,
      gas: config.gasLimitProposeAction,
    );
  }

  /// Creates an unsigned `sign` transaction for an existing action.
  ///
  /// #### Parameters
  /// - `sender` - Signer address
  /// - `multisigContract` - Multisig contract address
  /// - `actionId` - Action identifier returned by a `propose*` call
  Transaction createTransactionForSign({
    required Address sender,
    required Address multisigContract,
    required int actionId,
  }) {
    return _executeArgs(
      sender: sender,
      multisigContract: multisigContract,
      function: 'sign',
      args: <TypedValue>[U32Value(actionId)],
      gas: config.gasLimitSign,
    );
  }

  /// Creates an unsigned `signBatch` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Signer address
  /// - `multisigContract` - Multisig contract address
  /// - `groupId` - Batch group identifier
  Transaction createTransactionForSignBatch({
    required Address sender,
    required Address multisigContract,
    required int groupId,
  }) {
    return _executeArgs(
      sender: sender,
      multisigContract: multisigContract,
      function: 'signBatch',
      args: <TypedValue>[U32Value(groupId)],
      gas: config.gasLimitSign,
    );
  }

  /// Creates an unsigned `signAndPerform` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Signer address
  /// - `multisigContract` - Multisig contract address
  /// - `actionId` - Action identifier
  Transaction createTransactionForSignAndPerform({
    required Address sender,
    required Address multisigContract,
    required int actionId,
  }) {
    return _executeArgs(
      sender: sender,
      multisigContract: multisigContract,
      function: 'signAndPerform',
      args: <TypedValue>[U32Value(actionId)],
      gas: config.gasLimitPerformAction,
    );
  }

  /// Creates an unsigned `signBatchAndPerform` transaction.
  Transaction createTransactionForSignBatchAndPerform({
    required Address sender,
    required Address multisigContract,
    required int groupId,
  }) {
    return _executeArgs(
      sender: sender,
      multisigContract: multisigContract,
      function: 'signBatchAndPerform',
      args: <TypedValue>[U32Value(groupId)],
      gas: config.gasLimitPerformAction,
    );
  }

  /// Creates an unsigned `unsign` transaction.
  Transaction createTransactionForUnsign({
    required Address sender,
    required Address multisigContract,
    required int actionId,
  }) {
    return _executeArgs(
      sender: sender,
      multisigContract: multisigContract,
      function: 'unsign',
      args: <TypedValue>[U32Value(actionId)],
      gas: config.gasLimitSign,
    );
  }

  /// Creates an unsigned `unsignBatch` transaction.
  Transaction createTransactionForUnsignBatch({
    required Address sender,
    required Address multisigContract,
    required int groupId,
  }) {
    return _executeArgs(
      sender: sender,
      multisigContract: multisigContract,
      function: 'unsignBatch',
      args: <TypedValue>[U32Value(groupId)],
      gas: config.gasLimitSign,
    );
  }

  /// Creates an unsigned `unsignForOutdatedBoardMembers` transaction.
  ///
  /// #### Parameters
  /// - `sender` - Caller address
  /// - `multisigContract` - Multisig contract address
  /// - `actionId` - Action identifier
  /// - `outdatedBoardMembers` - User-ids of outdated board members
  Transaction createTransactionForUnsignForOutdatedBoardMembers({
    required Address sender,
    required Address multisigContract,
    required int actionId,
    required List<int> outdatedBoardMembers,
  }) {
    return _executeArgs(
      sender: sender,
      multisigContract: multisigContract,
      args: <TypedValue>[
        U32Value(actionId),
        ...outdatedBoardMembers.map<TypedValue>((int id) => U32Value(id)),
      ],
      function: 'unsignForOutdatedBoardMembers',
      gas: config.gasLimitSign,
    );
  }

  /// Creates an unsigned `performAction` transaction.
  Transaction createTransactionForPerformAction({
    required Address sender,
    required Address multisigContract,
    required int actionId,
  }) {
    return _executeArgs(
      sender: sender,
      multisigContract: multisigContract,
      function: 'performAction',
      args: <TypedValue>[U32Value(actionId)],
      gas: config.gasLimitPerformAction,
    );
  }

  /// Creates an unsigned `performBatch` transaction.
  Transaction createTransactionForPerformBatch({
    required Address sender,
    required Address multisigContract,
    required int groupId,
  }) {
    return _executeArgs(
      sender: sender,
      multisigContract: multisigContract,
      function: 'performBatch',
      args: <TypedValue>[U32Value(groupId)],
      gas: config.gasLimitPerformAction,
    );
  }

  /// Creates an unsigned `discardAction` transaction.
  Transaction createTransactionForDiscardAction({
    required Address sender,
    required Address multisigContract,
    required int actionId,
  }) {
    return _executeArgs(
      sender: sender,
      multisigContract: multisigContract,
      function: 'discardAction',
      args: <TypedValue>[U32Value(actionId)],
      gas: config.gasLimitPerformAction,
    );
  }

  /// Creates an unsigned `discardBatch` transaction.
  Transaction createTransactionForDiscardBatch({
    required Address sender,
    required Address multisigContract,
    required List<int> actionIds,
  }) {
    return _executeArgs(
      sender: sender,
      multisigContract: multisigContract,
      function: 'discardBatch',
      args: actionIds.map<TypedValue>((int id) => U32Value(id)).toList(),
      gas: config.gasLimitPerformAction,
    );
  }

  /// Creates an unsigned `deposit` transaction (sends EGLD or ESDT to the
  /// multisig wallet without executing anything).
  ///
  /// #### Parameters
  /// - `sender` - Caller address
  /// - `multisigContract` - Multisig contract address
  /// - `nativeTransferAmount` - EGLD amount to deposit
  /// - `tokenTransfers` - Already-encoded ESDT/NFT transfer typed values
  /// - `gasLimit` - Explicit gas limit (no auto-estimation possible)
  Transaction createTransactionForDeposit({
    required Address sender,
    required Address multisigContract,
    required BigInt nativeTransferAmount,
    List<TypedValue> tokenTransfers = const <TypedValue>[],
    required int gasLimit,
  }) {
    return _executeArgs(
      sender: sender,
      multisigContract: multisigContract,
      function: 'deposit',
      args: tokenTransfers,
      gas: gasLimit,
      value: Balance(nativeTransferAmount),
      includeMinAndPerByte: false,
    );
  }

  /// Creates an unsigned multisig-contract deploy transaction.
  ///
  /// #### Parameters
  /// - `sender` - Deployer address
  /// - `bytecode` - Multisig wasm bytecode
  /// - `quorum` - Initial quorum
  /// - `board` - Initial board member addresses
  /// - `gasLimit` - Explicit gas limit for the deploy
  /// - `codeMetadata` - Optional code metadata (default upgradeable+readable)
  Transaction createTransactionForDeploy({
    required Address sender,
    required Uint8List bytecode,
    required int quorum,
    required List<Address> board,
    required int gasLimit,
    Uint8List? codeMetadata,
  }) {
    final List<TypedValue> constructorArgs = <TypedValue>[
      U32Value(quorum),
      ...board.map<TypedValue>(_addressValue),
    ];
    final List<String> encodedArgs = _argSerializer.valuesToStrings(
      constructorArgs,
    );
    final List<String> dataParts = <String>[
      convert.hex.encode(bytecode),
      '0500',
      convert.hex.encode(codeMetadata ?? Uint8List.fromList(<int>[0x05, 0x06])),
      ...encodedArgs,
    ];
    final Uint8List bytes = Uint8List.fromList(
      utf8.encode(dataParts.join('@')),
    );
    return Transaction(
      nonce: const Nonce(0),
      sender: sender,
      receiver: Address.zero(hrp: sender.hrp),
      value: Balance.zero(),
      gasLimit: GasLimit(gasLimit),
      gasPrice: GasPrice(config.defaultGasPrice),
      chainId: config.chainId,
      version: const TransactionVersion(2),
      data: bytes,
    );
  }

  Transaction _execute({
    required Address sender,
    required Address multisigContract,
    required String function,
    required List<TypedValue> args,
    required int gas,
  }) => _executeArgs(
    sender: sender,
    multisigContract: multisigContract,
    function: function,
    args: args,
    gas: gas,
  );

  Transaction _executeArgs({
    required Address sender,
    required Address multisigContract,
    required String function,
    required List<TypedValue> args,
    required int gas,
    Balance? value,
    bool includeMinAndPerByte = true,
  }) {
    final List<String> encoded = args.isEmpty
        ? const <String>[]
        : _argSerializer.valuesToStrings(args);
    return _buildFromHexParts(
      sender: sender,
      receiver: multisigContract,
      function: function,
      encodedArgs: encoded,
      gas: gas,
      value: value,
      includeMinAndPerByte: includeMinAndPerByte,
    );
  }

  Transaction _buildFromHexParts({
    required Address sender,
    required Address receiver,
    required String function,
    required List<String> encodedArgs,
    required int gas,
    Balance? value,
    bool includeMinAndPerByte = true,
  }) {
    final StringBuffer buffer = StringBuffer(function);
    for (final String part in encodedArgs) {
      buffer
        ..write('@')
        ..write(part);
    }
    final Uint8List bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    final int finalGas = includeMinAndPerByte
        ? config.minGasLimit + bytes.length * config.gasLimitPerByte + gas
        : gas;
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

  static AddressValue _addressValue(Address address) =>
      AddressValue(address.bytes);

  OptionValue _u64Option(BigInt? value) {
    final OptionType type = OptionType(U64Type.type);
    if (value == null) {
      return OptionValue.none(type);
    }
    return OptionValue.some(type, U64Value(value));
  }

  static int _codeMetadataInt(Uint8List bytes) {
    if (bytes.length != 2) {
      throw ArgumentError(
        'codeMetadata must be exactly 2 bytes, got ${bytes.length}',
      );
    }
    return (bytes[0] << 8) | bytes[1];
  }
}
