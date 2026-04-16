import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  final factory = StakingTransactionsFactory(
    const StakingTransactionsConfig(chainId: ChainId('1')),
  );
  final sender = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  final pubKey = ValidatorPublicKey(
    Uint8List.fromList(List<int>.filled(96, 0xaa)),
  );
  final signature = Uint8List.fromList(List<int>.filled(96, 0xbb));

  group('StakingTransactionsFactory', () {
    test('stake targets canonical staking contract', () {
      final tx = factory.createTransactionForStaking(
        sender: sender,
        numNodes: 1,
        nodes: <SignedValidatorPublicKey>[
          SignedValidatorPublicKey(publicKey: pubKey, signature: signature),
        ],
        amount: Balance.fromEgld(2500),
      );

      expect(tx.receiver.bech32, stakingContractBech32);
      expect(tx.value.value, BigInt.parse('2500000000000000000000'));
      final parts = utf8.decode(tx.data).split('@');
      expect(parts[0], 'stake');
      expect(parts[1], '01');
      expect(parts[2], 'aa' * 96);
      expect(parts[3], 'bb' * 96);
    });

    test('stake rejects numNodes mismatch', () {
      expect(
        () => factory.createTransactionForStaking(
          sender: sender,
          numNodes: 2,
          nodes: <SignedValidatorPublicKey>[
            SignedValidatorPublicKey(publicKey: pubKey, signature: signature),
          ],
          amount: Balance.zero(),
        ),
        throwsArgumentError,
      );
    });

    test('unStake emits function with hex-encoded keys', () {
      final tx = factory.createTransactionForUnstaking(
        sender: sender,
        publicKeys: <ValidatorPublicKey>[pubKey, pubKey],
      );

      final data = utf8.decode(tx.data);
      expect(data.split('@')[0], 'unStake');
      expect(data.split('@').length, 3);
    });

    test('claim has no args', () {
      final tx = factory.createTransactionForClaimingRewards(sender: sender);
      expect(utf8.decode(tx.data), 'claim');
    });

    test('changeRewardAddress encodes bech32 bytes', () {
      final newReward = Address.fromBech32(
        'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
      );
      final tx = factory.createTransactionForChangingRewardAddress(
        sender: sender,
        newRewardAddress: newReward,
      );

      final parts = utf8.decode(tx.data).split('@');
      expect(parts[0], 'changeRewardAddress');
      expect(parts[1], newReward.hex);
    });

    test('unJail attaches fee and lists keys', () {
      final tx = factory.createTransactionForUnjailing(
        sender: sender,
        publicKeys: <ValidatorPublicKey>[pubKey],
        amount: Balance.fromEgld(2.5),
      );

      expect(tx.value.value, BigInt.parse('2500000000000000000'));
      expect(utf8.decode(tx.data), startsWith('unJail@${'aa' * 96}'));
    });

    test('changeValidatorKeys requires equal-length lists', () {
      expect(
        () => factory.createTransactionForChangingValidatorKeys(
          sender: sender,
          oldKeys: <SignedValidatorPublicKey>[
            SignedValidatorPublicKey(publicKey: pubKey, signature: signature),
          ],
          newKeys: <SignedValidatorPublicKey>[],
        ),
        throwsArgumentError,
      );
    });
  });
}
