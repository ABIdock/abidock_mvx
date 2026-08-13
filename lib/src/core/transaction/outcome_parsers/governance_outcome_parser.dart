/// Parser for governance transaction outcomes.
/// Extracts structured results from governance contract logs and detects
/// signalError events, decoding event topics through
/// [ArgSerializer.buffersToValues] using the event ABI types.
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../abi/serializers/arg_serializer.dart';
import '../../../abi/types/primitives/address.dart' as abi_addr;
import '../../../abi/types/primitives/biguint.dart';
import '../../../abi/types/primitives/string.dart';
import '../../../utils/sdk_exceptions.dart';
import '../../address.dart';
import '../transaction_event.dart';
import '../transaction_logs.dart';
import '../transaction_on_network.dart';

/// Exception for governance parsing failures.
/// Thrown when outcomes cannot be parsed due to missing data, unexpected
/// format, or transaction errors.
/// Part of the unified SDK hierarchy: catch it as [TransactionException] or as
/// [AbidockException].
class GovernanceParseException extends TransactionException {
  /// Creates governance parse exception.
  const GovernanceParseException(super.message, [Object? cause])
    : super(cause: cause);

  @override
  String toString() {
    if (cause != null) {
      return 'GovernanceParseException: $message\nCaused by: $cause';
    }
    return 'GovernanceParseException: $message';
  }
}

/// Result of a `proposal` event emitted when a new governance proposal is
/// created. Carries the proposal nonce, the commit hash that identifies the
/// proposal text, and the start/end voting epochs.
class NewProposalOutcome {
  /// Creates new proposal outcome.
  const NewProposalOutcome({
    required this.proposalNonce,
    required this.commitHash,
    required this.startVoteEpoch,
    required this.endVoteEpoch,
  });

  final BigInt proposalNonce;
  final String commitHash;
  final BigInt startVoteEpoch;
  final BigInt endVoteEpoch;

  @override
  String toString() =>
      'NewProposalOutcome(nonce: $proposalNonce, commitHash: $commitHash)';
}

/// Result of a `vote` event. Carries the proposal nonce, the encoded vote
/// choice (e.g. yes/no/abstain), the total stake bound to the vote, and the
/// effective voting power.
class VoteOutcome {
  /// Creates vote outcome.
  const VoteOutcome({
    required this.proposalNonce,
    required this.vote,
    required this.totalStake,
    required this.votingPower,
  });

  final BigInt proposalNonce;
  final String vote;
  final BigInt totalStake;
  final BigInt votingPower;

  @override
  String toString() =>
      'VoteOutcome(nonce: $proposalNonce, vote: $vote, power: $votingPower)';
}

/// Result of a `delegateVote` event. Carries the delegated voter address
/// alongside the standard vote payload (nonce, choice, user stake, voting
/// power).
class DelegateVoteOutcome {
  /// Creates delegate vote outcome.
  const DelegateVoteOutcome({
    required this.proposalNonce,
    required this.vote,
    required this.voter,
    required this.userStake,
    required this.votingPower,
  });

  final BigInt proposalNonce;
  final String vote;
  final Address voter;
  final BigInt userStake;
  final BigInt votingPower;

  @override
  String toString() =>
      'DelegateVoteOutcome(nonce: $proposalNonce, voter: ${voter.bech32})';
}

/// Result of a `closeProposal` event. Carries the commit hash and the
/// boolean pass/fail status of the proposal at closing time.
class CloseProposalOutcome {
  /// Creates close proposal outcome.
  const CloseProposalOutcome({required this.commitHash, required this.passed});

  final String commitHash;
  final bool passed;

  @override
  String toString() =>
      'CloseProposalOutcome(commitHash: $commitHash, passed: $passed)';
}

/// Parser for governance transaction outcomes.
///
/// Handles the four events the governance system contract emits — `proposal`,
/// `vote`, `delegateVote` and `closeProposal` — routing topic decoding
/// through [ArgSerializer.buffersToValues] with the event ABI types.
/// Also detects `signalError` events emitted by the governance contract.
@immutable
class GovernanceOutcomeParser {
  /// Creates a governance outcome parser.
  ///
  /// #### Parameters
  /// - `addressHrp` - Optional bech32 HRP override (defaults to `erd`).
  const GovernanceOutcomeParser({this.addressHrp = 'erd'});

  /// Bech32 HRP for any address decoded from event topics.
  final String addressHrp;

  /// ABI-typed topic schema for `proposal` events.
  static final List<ParameterDefinition> _proposalTopics =
      <ParameterDefinition>[
        ParameterDefinition(BigUIntType.type, 'proposalNonce'),
        ParameterDefinition(StringType.type, 'commitHash'),
        ParameterDefinition(BigUIntType.type, 'startVoteEpoch'),
        ParameterDefinition(BigUIntType.type, 'endVoteEpoch'),
      ];

  /// ABI-typed topic schema for `vote` events.
  static final List<ParameterDefinition> _voteTopics = <ParameterDefinition>[
    ParameterDefinition(BigUIntType.type, 'proposalNonce'),
    ParameterDefinition(StringType.type, 'vote'),
    ParameterDefinition(BigUIntType.type, 'totalStake'),
    ParameterDefinition(BigUIntType.type, 'votingPower'),
  ];

  /// ABI-typed topic schema for `delegateVote` events.
  static final List<ParameterDefinition> _delegateVoteTopics =
      <ParameterDefinition>[
        ParameterDefinition(BigUIntType.type, 'proposalNonce'),
        ParameterDefinition(StringType.type, 'vote'),
        ParameterDefinition(abi_addr.AddressType.type, 'voter'),
        ParameterDefinition(BigUIntType.type, 'userStake'),
        ParameterDefinition(BigUIntType.type, 'votingPower'),
      ];

  /// Parses `proposal` events emitted by `proposalNew` calls.
  ///
  /// #### Parameters
  /// - `transaction` - Completed transaction whose logs to scan.
  ///
  /// #### Returns
  /// A list of decoded [NewProposalOutcome] (one per `proposal` event).
  List<NewProposalOutcome> parseNewProposal(TransactionOnNetwork transaction) {
    _ensureNoError(transaction.logs);
    final List<TransactionEvent> events = _findEventsByIdentifier(
      transaction,
      'proposal',
    );
    final ArgSerializer serializer = ArgSerializer();
    return events.map((TransactionEvent event) {
      final List<dynamic> values = _decodeTopics(
        serializer,
        event,
        _proposalTopics,
      );
      return NewProposalOutcome(
        proposalNonce: values[0] as BigInt,
        commitHash: values[1] as String,
        startVoteEpoch: values[2] as BigInt,
        endVoteEpoch: values[3] as BigInt,
      );
    }).toList();
  }

  /// Parses `vote` events emitted by `vote` calls.
  ///
  /// #### Returns
  /// A list of decoded [VoteOutcome].
  List<VoteOutcome> parseVote(TransactionOnNetwork transaction) {
    _ensureNoError(transaction.logs);
    final List<TransactionEvent> events = _findEventsByIdentifier(
      transaction,
      'vote',
    );
    final ArgSerializer serializer = ArgSerializer();
    return events.map((TransactionEvent event) {
      final List<dynamic> values = _decodeTopics(
        serializer,
        event,
        _voteTopics,
      );
      return VoteOutcome(
        proposalNonce: values[0] as BigInt,
        vote: values[1] as String,
        totalStake: values[2] as BigInt,
        votingPower: values[3] as BigInt,
      );
    }).toList();
  }

  /// Parses `delegateVote` events emitted by `delegateVote` calls.
  ///
  /// #### Returns
  /// A list of decoded [DelegateVoteOutcome].
  List<DelegateVoteOutcome> parseDelegateVote(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoError(transaction.logs);
    final List<TransactionEvent> events = _findEventsByIdentifier(
      transaction,
      'delegateVote',
    );
    final ArgSerializer serializer = ArgSerializer();
    return events.map((TransactionEvent event) {
      final List<dynamic> values = _decodeTopics(
        serializer,
        event,
        _delegateVoteTopics,
      );
      final dynamic voterValue = values[2];
      final List<int> voterBytes = voterValue is String
          ? Address.fromBech32(voterValue).bytes
          : _addressBytesFrom(event, 2);
      final Address voter = Address(voterBytes, hrp: addressHrp);
      return DelegateVoteOutcome(
        proposalNonce: values[0] as BigInt,
        vote: values[1] as String,
        voter: voter,
        userStake: values[3] as BigInt,
        votingPower: values[4] as BigInt,
      );
    }).toList();
  }

  /// Parses `closeProposal` events emitted by `closeProposal` calls.
  ///
  /// This event's topics are not ABI-encoded values: the contract writes them
  /// as raw UTF-8 text — the commit hash, then the literal `true` or `false`
  /// pass flag — so they are read as strings rather than decoded.
  List<CloseProposalOutcome> parseCloseProposal(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoError(transaction.logs);
    final List<TransactionEvent> events = _findEventsByIdentifier(
      transaction,
      'closeProposal',
    );
    return events.map((TransactionEvent event) {
      final String commitHash = event.topics.isNotEmpty
          ? String.fromCharCodes(event.topics[0])
          : '';
      final String passedRaw = event.topics.length > 1
          ? String.fromCharCodes(event.topics[1])
          : '';
      return CloseProposalOutcome(
        commitHash: commitHash,
        passed: passedRaw == 'true',
      );
    }).toList();
  }

  void _ensureNoError(TransactionLogs? logs) {
    if (logs == null) return;
    for (final TransactionEvent event in logs.events) {
      if (event.identifier == 'signalError') {
        final String data = event.additionalData.isNotEmpty
            ? String.fromCharCodes(event.additionalData[0].skip(1))
            : '';
        final String message = event.topics.length > 1
            ? String.fromCharCodes(event.topics[1])
            : '';
        throw GovernanceParseException(
          'encountered signalError: $message ($data)',
        );
      }
    }
  }

  List<TransactionEvent> _findEventsByIdentifier(
    TransactionOnNetwork transaction,
    String identifier,
  ) {
    if (transaction.logs == null) return <TransactionEvent>[];
    return transaction.logs!.findEvents(identifier);
  }

  /// Decodes the topics of [event] through [ArgSerializer.buffersToValues]
  /// using the supplied ABI [params] and returns the native Dart values.
  List<dynamic> _decodeTopics(
    ArgSerializer serializer,
    TransactionEvent event,
    List<ParameterDefinition> params,
  ) {
    final List<Uint8List> topics = <Uint8List>[
      for (int i = 0; i < params.length; i++)
        i < event.topics.length ? event.topics[i] : Uint8List(0),
    ];
    return serializer
        .buffersToValues(topics, params)
        .map((dynamic v) => v.valueOf())
        .toList();
  }

  /// Falls back to the raw topic bytes when the decoded address value is not
  /// a bech32 `String`. Yields 32 zero bytes when the topic is absent or is
  /// not exactly 32 bytes wide, the width of an account address.
  Uint8List _addressBytesFrom(TransactionEvent event, int index) {
    if (index >= event.topics.length || event.topics[index].length != 32) {
      return Uint8List(32);
    }
    return event.topics[index];
  }
}
