/// Factory for governance system-smart-contract transactions: proposing,
/// voting, closing proposals, clearing ended proposals, changing the
/// on-chain governance config, and claiming accumulated fees.
import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart' as convert;

import '../../address.dart';
import '../../balance.dart';
import '../../nonce.dart';
import '../chain_id.dart';
import '../gas_models/gas_limit.dart';
import '../gas_models/gas_price.dart';
import '../transaction.dart';
import '../transaction_version.dart';
import '../transactions_factory_config.dart';
import '_factory_helpers.dart';

/// The governance system smart contract; its last four bytes are `0003ffff`.
const String governanceContractAddressHex =
    '000000000000000000010000000000000000000000000000000000000003ffff';

/// The governance system smart contract, in bech32 form.
const String governanceContractBech32 =
    'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqrlllsrujgla';

/// Vote option on a governance proposal.
enum VoteType {
  yes('yes'),
  no('no'),
  veto('veto'),
  abstain('abstain');

  const VoteType(this.wireName);
  final String wireName;
}

/// Configuration for the governance factory.
class GovernanceTransactionsConfig {
  const GovernanceTransactionsConfig({
    required this.chainId,
    this.minGasLimit = 50000,
    this.gasLimitPerByte = 1500,
    this.gasLimitProposal = 50_000_000,
    this.gasLimitVote = 6_000_000,
    this.gasLimitCloseProposal = 50_000_000,
    this.gasLimitClaimFees = 6_000_000,
    this.gasLimitClearEndedProposals = 50_000_000,
    this.gasLimitChangeConfig = 50_000_000,
    this.defaultGasPrice = 1000000000,
    this.proposalCost = '1000000000000000000000',
  });

  /// Builds a [GovernanceTransactionsConfig] from a shared [TransactionsFactoryConfig].
  ///
  /// #### Parameters
  /// - `shared` - Aggregate factory config populated by `NetworkEntrypoint`.
  ///
  /// #### Returns
  /// A new [GovernanceTransactionsConfig] carrying `shared`'s governance
  /// fields.
  static GovernanceTransactionsConfig fromShared(
    TransactionsFactoryConfig shared,
  ) => GovernanceTransactionsConfig(
    chainId: shared.chainId,
    minGasLimit: shared.minGasLimit,
    gasLimitPerByte: shared.gasLimitPerByte,
    gasLimitProposal: shared.gasLimitProposal,
    gasLimitVote: shared.gasLimitVote,
    gasLimitCloseProposal: shared.gasLimitClearEndedProposals,
    gasLimitClaimFees: shared.gasLimitClaimAccumulatedFees,
    gasLimitClearEndedProposals: shared.gasLimitClearEndedProposals,
    gasLimitChangeConfig: shared.gasLimitChangeConfig,
  );

  final ChainId chainId;
  final int minGasLimit;
  final int gasLimitPerByte;
  final int gasLimitProposal;
  final int gasLimitVote;
  final int gasLimitCloseProposal;
  final int gasLimitClaimFees;

  /// Gas used by `clearEndedProposals`.
  final int gasLimitClearEndedProposals;

  /// Gas used by `changeConfig`.
  final int gasLimitChangeConfig;
  final int defaultGasPrice;

  /// Required EGLD stake attached to `proposal` (1000 EGLD on mainnet).
  final String proposalCost;
}

/// Builds governance system-SC transactions.
class GovernanceTransactionsFactory {
  GovernanceTransactionsFactory(this.config)
    : _governanceContract = Address.fromBech32(governanceContractBech32);

  final GovernanceTransactionsConfig config;
  final Address _governanceContract;

  /// Open a new proposal.
  ///
  /// #### Parameters
  /// - `sender` - Proposer address (pays the protocol-defined `proposalFee`).
  /// - `commitHash` - 40-char hex git commit hash of the off-chain proposal text.
  /// - `startVoteEpoch` - First epoch in which votes are accepted.
  /// - `endVoteEpoch` - Last epoch in which votes are accepted (inclusive).
  /// - `nativeTokenAmount` - EGLD amount attached to the call. The governance
  ///   contract requires this to equal the on-chain `proposalFee`. Defaults
  ///   to [GovernanceTransactionsConfig.proposalCost] for backwards-compat
  ///   with the historical 1000-EGLD mainnet fee; **pass the live value**
  ///   from `getOnChainConfig().proposalFee` in production.
  ///
  /// #### Returns
  /// Unsigned [Transaction].
  Transaction createTransactionForNewProposal({
    required Address sender,
    required String commitHash,
    required int startVoteEpoch,
    required int endVoteEpoch,
    BigInt? nativeTokenAmount,
  }) {
    if (commitHash.length != 40) {
      throw ArgumentError.value(
        commitHash,
        'commitHash',
        'must be the 40-character hex of a git commit hash',
      );
    }
    final String data =
        'proposal@${convert.hex.encode(utf8.encode(commitHash))}'
        '@${evenHexInt(startVoteEpoch)}'
        '@${evenHexInt(endVoteEpoch)}';
    final Balance value = nativeTokenAmount != null
        ? Balance(nativeTokenAmount)
        : Balance.fromString(config.proposalCost);
    return _build(
      sender: sender,
      data: data,
      gas: config.gasLimitProposal,
      value: value,
    );
  }

  /// Cast a vote on [proposalNonce] with [vote].
  Transaction createTransactionForVoting({
    required Address sender,
    required int proposalNonce,
    required VoteType vote,
  }) {
    final String data =
        'vote@${evenHexInt(proposalNonce)}'
        '@${convert.hex.encode(utf8.encode(vote.wireName))}';
    return _build(sender: sender, data: data, gas: config.gasLimitVote);
  }

  /// Close a proposal whose voting window has ended.
  Transaction createTransactionForClosingProposal({
    required Address sender,
    required int proposalNonce,
  }) {
    final String data = 'closeProposal@${evenHexInt(proposalNonce)}';
    return _build(
      sender: sender,
      data: data,
      gas: config.gasLimitCloseProposal,
    );
  }

  /// Claim accumulated protocol fees from closed proposals (governance
  /// admin / DAO treasury).
  Transaction createTransactionForClaimingAccumulatedFees({
    required Address sender,
  }) {
    return _build(
      sender: sender,
      data: 'claimAccumulatedFees',
      gas: config.gasLimitClaimFees,
    );
  }

  /// Clear ended proposals.
  ///
  /// The gas limit scales with the number of proposers: the contract charges
  /// the `ClearProposal` cost once per proposer, plus once for the call
  /// itself.
  ///
  /// #### Parameters
  /// - `sender` - Caller address
  /// - `proposers` - List of proposer addresses whose ended proposals
  ///   should be cleared.
  ///
  /// #### Returns
  /// Unsigned [Transaction].
  ///
  /// #### Example
  /// ```dart
  /// factory.createTransactionForClearingEndedProposals(
  ///   sender: alice.address,
  ///   proposers: [alice.address],
  /// );
  /// ```
  Transaction createTransactionForClearingEndedProposals({
    required Address sender,
    required List<Address> proposers,
  }) {
    final StringBuffer data = StringBuffer('clearEndedProposals');
    for (final Address a in proposers) {
      data
        ..write('@')
        ..write(convert.hex.encode(a.bytes));
    }
    return _build(
      sender: sender,
      data: data.toString(),
      gas:
          config.gasLimitClearEndedProposals +
          proposers.length * config.gasLimitClearEndedProposals,
    );
  }

  /// Change protocol-governance configuration.
  ///
  /// #### Parameters
  /// - `sender` - Caller address (governance owner)
  /// - `proposalFee` - New `proposalFee` value (string, attoEGLD)
  /// - `lastProposalFee` - New `lastProposalFee` value
  /// - `minQuorum` - New minimum quorum (percent * 1e4)
  /// - `minVetoThreshold` - New minimum veto threshold
  /// - `minPassThreshold` - New minimum pass threshold
  ///
  /// #### Returns
  /// Unsigned [Transaction].
  ///
  /// #### Example
  /// ```dart
  /// factory.createTransactionForChangingConfig(
  ///   sender: governance,
  ///   proposalFee: '1000000000000000000000',
  ///   lastProposalFee: '1000000000000000000000',
  ///   minQuorum: 2000,
  ///   minVetoThreshold: 3300,
  ///   minPassThreshold: 6700,
  /// );
  /// ```
  Transaction createTransactionForChangingConfig({
    required Address sender,
    required String proposalFee,
    required String lastProposalFee,
    required int minQuorum,
    required int minVetoThreshold,
    required int minPassThreshold,
  }) {
    final String data =
        'changeConfig'
        '@${convert.hex.encode(utf8.encode(proposalFee))}'
        '@${convert.hex.encode(utf8.encode(lastProposalFee))}'
        '@${convert.hex.encode(utf8.encode('$minQuorum'))}'
        '@${convert.hex.encode(utf8.encode('$minVetoThreshold'))}'
        '@${convert.hex.encode(utf8.encode('$minPassThreshold'))}';
    return _build(sender: sender, data: data, gas: config.gasLimitChangeConfig);
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
      receiver: _governanceContract,
      value: value ?? Balance.zero(),
      gasLimit: GasLimit(finalGas),
      gasPrice: GasPrice(config.defaultGasPrice),
      chainId: config.chainId,
      version: const TransactionVersion(2),
      data: bytes,
    );
  }
}
