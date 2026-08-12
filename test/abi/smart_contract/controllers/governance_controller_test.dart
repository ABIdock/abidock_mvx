/// Happy-path tests for [GovernanceController] parse* methods.
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

TransactionOnNetwork _buildTx({required List<TransactionEvent> events}) {
  final Address sender = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  final Address governance = Address.fromBech32(
    'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqxlllshevkwc',
  );
  final Transaction inner = Transaction(
    nonce: const Nonce(0),
    sender: sender,
    receiver: governance,
    value: Balance.zero(),
    gasLimit: const GasLimit(60_000_000),
    gasPrice: const GasPrice(1000000000),
    chainId: const ChainId.devnet(),
    version: const TransactionVersion(2),
    data: Uint8List(0),
  );
  return TransactionOnNetwork(
    transaction: inner,
    status: TransactionStatus.success,
    txHash: '0000000000000000000000000000000000000000000000000000000000000000',
    logs: TransactionLogs(address: governance, events: events),
  );
}

Uint8List _bigIntTopic(BigInt v) {
  final String hex = v.toRadixString(16);
  final String padded = hex.length.isOdd ? '0$hex' : hex;
  final Uint8List out = Uint8List(padded.length ~/ 2);
  for (int i = 0; i < out.length; i++) {
    out[i] = int.parse(padded.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

Uint8List _utf8Topic(String s) =>
    Uint8List.fromList(<int>[for (final int c in s.codeUnits) c]);

void main() {
  final Address governance = Address.fromBech32(
    'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqxlllshevkwc',
  );
  late GovernanceController controller;

  setUpAll(() {
    controller = GovernanceController(chainId: const ChainId.devnet());
  });

  test(
    'parseNewProposal extracts proposal metadata from a synthetic event',
    () {
      final TransactionEvent event = TransactionEvent(
        address: governance,
        identifier: 'proposal',
        topics: <Uint8List>[
          _bigIntTopic(BigInt.from(7)),
          _utf8Topic('a' * 40),
          _bigIntTopic(BigInt.from(100)),
          _bigIntTopic(BigInt.from(110)),
        ],
        data: Uint8List(0),
      );
      final TransactionOnNetwork tx = _buildTx(
        events: <TransactionEvent>[event],
      );

      final List<NewProposalOutcome> outcomes = controller.parseNewProposal(tx);

      expect(outcomes, hasLength(1));
      expect(outcomes.first.proposalNonce, equals(BigInt.from(7)));
      expect(outcomes.first.commitHash, equals('a' * 40));
      expect(outcomes.first.startVoteEpoch, equals(BigInt.from(100)));
      expect(outcomes.first.endVoteEpoch, equals(BigInt.from(110)));
    },
  );

  test(
    'parseClearEndedProposals returns true when no signalError is present',
    () {
      final TransactionOnNetwork tx = _buildTx(
        events: const <TransactionEvent>[],
      );
      expect(controller.parseClearEndedProposals(tx), isTrue);
    },
  );
}
