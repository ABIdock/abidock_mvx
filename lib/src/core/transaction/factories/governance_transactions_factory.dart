/// Factory for governance system-smart-contract transactions: proposing,
/// voting, delegate-voting, closing proposals, and claiming accumulated fees.
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

const String governanceContractBech32 =
    'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqxlllshevkwc';

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
    this.gasLimitDelegateVote = 6_000_000,
    this.gasLimitCloseProposal = 50_000_000,
    this.gasLimitClaimFees = 6_000_000,
    this.defaultGasPrice = 1000000000,
    this.proposalCost = '1000000000000000000000',
  });

  final ChainId chainId;
  final int minGasLimit;
  final int gasLimitPerByte;
  final int gasLimitProposal;
  final int gasLimitVote;
  final int gasLimitDelegateVote;
  final int gasLimitCloseProposal;
  final int gasLimitClaimFees;
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
  /// [commitHash] is the 40-char git hash of the off-chain proposal text.
  /// [startVoteEpoch] and [endVoteEpoch] bound the voting window.
  Transaction createTransactionForNewProposal({
    required Address sender,
    required String commitHash,
    required int startVoteEpoch,
    required int endVoteEpoch,
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
        '@${startVoteEpoch._evenHex()}'
        '@${endVoteEpoch._evenHex()}';
    return _build(
      sender: sender,
      data: data,
      gas: config.gasLimitProposal,
      value: Balance.fromString(config.proposalCost),
    );
  }

  /// Cast a vote on [proposalNonce] with [vote].
  Transaction createTransactionForVoting({
    required Address sender,
    required int proposalNonce,
    required VoteType vote,
  }) {
    final String data =
        'vote@${proposalNonce._evenHex()}'
        '@${convert.hex.encode(utf8.encode(vote.wireName))}';
    return _build(sender: sender, data: data, gas: config.gasLimitVote);
  }

  /// Cast a delegated vote on behalf of [delegator].
  Transaction createTransactionForDelegatingVote({
    required Address sender,
    required int proposalNonce,
    required VoteType vote,
    required Address delegator,
    required BigInt userStake,
  }) {
    final String data =
        'delegateVote@${proposalNonce._evenHex()}'
        '@${convert.hex.encode(utf8.encode(vote.wireName))}'
        '@${convert.hex.encode(delegator.bytes)}'
        '@${userStake._evenHex()}';
    return _build(sender: sender, data: data, gas: config.gasLimitDelegateVote);
  }

  /// Close a proposal whose voting window has ended.
  Transaction createTransactionForClosingProposal({
    required Address sender,
    required int proposalNonce,
  }) {
    final String data = 'closeProposal@${proposalNonce._evenHex()}';
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

  Transaction _build({
    required Address sender,
    required String data,
    required int gas,
    Balance? value,
  }) {
    final Uint8List bytes = Uint8List.fromList(utf8.encode(data));
    final int finalGas =
        gas + config.minGasLimit + bytes.length * config.gasLimitPerByte;
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

extension on int {
  String _evenHex() {
    final String hex = toRadixString(16);
    return hex.length.isOdd ? '0$hex' : hex;
  }
}

extension on BigInt {
  String _evenHex() {
    final String hex = toRadixString(16);
    return hex.length.isOdd ? '0$hex' : hex;
  }
}
