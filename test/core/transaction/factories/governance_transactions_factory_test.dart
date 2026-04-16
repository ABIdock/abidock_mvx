import 'dart:convert';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  final factory = GovernanceTransactionsFactory(
    const GovernanceTransactionsConfig(chainId: ChainId('1')),
  );
  final sender = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  final commitHash = 'a' * 40;

  group('GovernanceTransactionsFactory', () {
    test('proposal targets governance contract with cost attached', () {
      final tx = factory.createTransactionForNewProposal(
        sender: sender,
        commitHash: commitHash,
        startVoteEpoch: 16,
        endVoteEpoch: 32,
      );

      expect(tx.receiver.bech32, governanceContractBech32);
      expect(tx.value.value, BigInt.parse('1000000000000000000000'));
      final parts = utf8.decode(tx.data).split('@');
      expect(parts[0], 'proposal');
      expect(parts[2], '10');
      expect(parts[3], '20');
    });

    test('proposal rejects non-40-char hash', () {
      expect(
        () => factory.createTransactionForNewProposal(
          sender: sender,
          commitHash: 'short',
          startVoteEpoch: 1,
          endVoteEpoch: 2,
        ),
        throwsArgumentError,
      );
    });

    test('vote encodes proposalNonce and vote wire name', () {
      final tx = factory.createTransactionForVoting(
        sender: sender,
        proposalNonce: 5,
        vote: VoteType.yes,
      );

      final parts = utf8.decode(tx.data).split('@');
      expect(parts[0], 'vote');
      expect(parts[1], '05');
      expect(utf8.decode(_hexDecode(parts[2])), 'yes');
    });

    test('delegateVote includes delegator and stake', () {
      final delegator = Address.fromBech32(
        'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
      );
      final tx = factory.createTransactionForDelegatingVote(
        sender: sender,
        proposalNonce: 1,
        vote: VoteType.veto,
        delegator: delegator,
        userStake: BigInt.from(0x100),
      );

      final parts = utf8.decode(tx.data).split('@');
      expect(parts[0], 'delegateVote');
      expect(parts[3], delegator.hex);
      expect(parts[4], '0100');
    });

    test('closeProposal encodes nonce', () {
      final tx = factory.createTransactionForClosingProposal(
        sender: sender,
        proposalNonce: 7,
      );
      expect(utf8.decode(tx.data), 'closeProposal@07');
    });

    test('claimAccumulatedFees produces constant data', () {
      final tx = factory.createTransactionForClaimingAccumulatedFees(
        sender: sender,
      );
      expect(utf8.decode(tx.data), 'claimAccumulatedFees');
    });
  });
}

List<int> _hexDecode(String s) {
  final out = <int>[];
  for (int i = 0; i < s.length; i += 2) {
    out.add(int.parse(s.substring(i, i + 2), radix: 16));
  }
  return out;
}
