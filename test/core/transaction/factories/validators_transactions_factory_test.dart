/// Happy-path tests for [ValidatorsTransactionsFactory].
///
/// Asserts each factory method targets the correct system contract (the
/// staking SC for stake/unstake/etc., the delegation-manager SC for the
/// `mergeValidator*` and `makeNewContractFromValidatorData` flows) and
/// produces the exact `data` field bytes the system contract expects.
import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  final ValidatorsTransactionsFactory factory = ValidatorsTransactionsFactory(
    const ValidatorsTransactionsConfig(chainId: ChainId.devnet()),
  );
  final Address alice = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  final ValidatorPublicKey pk1 = ValidatorPublicKey(
    Uint8List.fromList(List<int>.filled(96, 0xaa)),
  );
  final ValidatorPublicKey pk2 = ValidatorPublicKey(
    Uint8List.fromList(List<int>.filled(96, 0xbb)),
  );
  final Uint8List sig = Uint8List.fromList(List<int>.filled(96, 0xcc));

  group('ValidatorsTransactionsFactory', () {
    test('stake targets the staking system contract', () {
      final Transaction tx = factory.createTransactionForStake(
        sender: alice,
        nodes: <SignedValidatorPublicKey>[
          SignedValidatorPublicKey(publicKey: pk1, signature: sig),
        ],
        amount: Balance.fromEgld(2500),
      );
      expect(tx.sender, equals(alice));
      expect(tx.receiver.bech32, equals(stakingContractBech32));
      expect(tx.value.value, equals(BigInt.parse('2500000000000000000000')));
      final List<String> parts = utf8.decode(tx.data).split('@');
      expect(parts[0], equals('stake'));
      expect(parts[1], equals('01'));
      expect(parts[2], equals('aa' * 96));
      expect(parts[3], equals('cc' * 96));
    });

    test('stake alias `createTransactionForStaking` matches', () {
      final Transaction a = factory.createTransactionForStake(
        sender: alice,
        nodes: <SignedValidatorPublicKey>[
          SignedValidatorPublicKey(publicKey: pk1, signature: sig),
        ],
        amount: Balance.fromEgld(2500),
      );
      final Transaction b = factory.createTransactionForStaking(
        sender: alice,
        nodes: <SignedValidatorPublicKey>[
          SignedValidatorPublicKey(publicKey: pk1, signature: sig),
        ],
        amount: Balance.fromEgld(2500),
      );
      expect(utf8.decode(a.data), equals(utf8.decode(b.data)));
    });

    test('unStakeTokens emits even-hex BigInt', () {
      final Transaction tx = factory.createTransactionForUnstakeTokens(
        sender: alice,
        value: BigInt.from(1000000000000000000),
      );
      expect(tx.receiver.bech32, equals(stakingContractBech32));
      expect(utf8.decode(tx.data), equals('unStakeTokens@0de0b6b3a7640000'));
    });

    test('unBondTokens emits even-hex BigInt', () {
      final Transaction tx = factory.createTransactionForUnbondTokens(
        sender: alice,
        value: BigInt.from(7),
      );
      expect(utf8.decode(tx.data), equals('unBondTokens@07'));
    });

    test('cleanRegisteredData has no args', () {
      final Transaction tx = factory.createTransactionForCleanRegisteredData(
        sender: alice,
      );
      expect(utf8.decode(tx.data), equals('cleanRegisteredData'));
    });

    test(
      'cleaningRegisteredData alias is identical to cleanRegisteredData',
      () {
        final Transaction a = factory.createTransactionForCleanRegisteredData(
          sender: alice,
        );
        final Transaction b = factory
            .createTransactionForCleaningRegisteredData(sender: alice);
        expect(utf8.decode(a.data), equals(utf8.decode(b.data)));
      },
    );

    test('reStakeUnStakedNodes lists keys', () {
      final Transaction tx = factory.createTransactionForRestakeUnstakedNodes(
        sender: alice,
        publicKeys: <ValidatorPublicKey>[pk1, pk2],
      );
      final List<String> parts = utf8.decode(tx.data).split('@');
      expect(parts[0], equals('reStakeUnStakedNodes'));
      expect(parts[1], equals('aa' * 96));
      expect(parts[2], equals('bb' * 96));
    });

    test('toppingUp sends `stake` with EGLD value but no args', () {
      final Transaction tx = factory.createTransactionForToppingUp(
        sender: alice,
        amount: Balance.fromEgld(10),
      );
      expect(utf8.decode(tx.data), equals('stake'));
      expect(tx.value.value, equals(BigInt.parse('10000000000000000000')));
    });

    test('unJail attaches penalty fee and lists keys', () {
      final Transaction tx = factory.createTransactionForUnjailing(
        sender: alice,
        publicKeys: <ValidatorPublicKey>[pk1],
        amount: Balance.fromEgld(2.5),
      );
      expect(tx.value.value, equals(BigInt.parse('2500000000000000000')));
      expect(utf8.decode(tx.data), equals('unJail@${'aa' * 96}'));
    });

    test('changeRewardAddress encodes new address bytes', () {
      final Address newReward = Address.fromBech32(
        'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
      );
      final Transaction tx = factory.createTransactionForChangingRewardsAddress(
        sender: alice,
        rewardsAddress: newReward,
      );
      expect(
        utf8.decode(tx.data),
        equals('changeRewardAddress@${newReward.hex}'),
      );
    });

    test('changeValidatorKeys rejects mismatched list lengths', () {
      expect(
        () => factory.createTransactionForChangingValidatorKeys(
          sender: alice,
          oldPublicKeys: <ValidatorPublicKey>[pk1],
          newSignedKeys: <SignedValidatorPublicKey>[],
        ),
        throwsArgumentError,
      );
    });

    test('unStaking emits `unStake@<key>`', () {
      final Transaction tx = factory.createTransactionForUnstaking(
        sender: alice,
        publicKeys: <ValidatorPublicKey>[pk1],
      );
      expect(utf8.decode(tx.data), equals('unStake@${'aa' * 96}'));
    });

    test('unBonding emits `unBond@<key>`', () {
      final Transaction tx = factory.createTransactionForUnbonding(
        sender: alice,
        publicKeys: <ValidatorPublicKey>[pk1],
      );
      expect(utf8.decode(tx.data), equals('unBond@${'aa' * 96}'));
    });

    test('unStakingNodes emits `unStakeNodes@<keys>`', () {
      final Transaction tx = factory.createTransactionForUnstakingNodes(
        sender: alice,
        publicKeys: <ValidatorPublicKey>[pk1, pk2],
      );
      expect(
        utf8.decode(tx.data),
        equals('unStakeNodes@${'aa' * 96}@${'bb' * 96}'),
      );
    });

    test('unBondingNodes emits `unBondNodes@<keys>`', () {
      final Transaction tx = factory.createTransactionForUnbondingNodes(
        sender: alice,
        publicKeys: <ValidatorPublicKey>[pk1],
      );
      expect(utf8.decode(tx.data), equals('unBondNodes@${'aa' * 96}'));
    });

    test('claiming emits `claim` with no args', () {
      final Transaction tx = factory.createTransactionForClaiming(
        sender: alice,
      );
      expect(utf8.decode(tx.data), equals('claim'));
    });

    test('newDelegationContractFromValidatorData targets the delegation '
        'manager SC and encodes maxCap + fee', () {
      final Transaction tx = factory
          .createTransactionForNewDelegationContractFromValidatorData(
            sender: alice,
            maxCap: BigInt.from(0),
            fee: BigInt.from(1500),
          );
      expect(tx.receiver.bech32, equals(delegationManagerContractBech32));
      expect(
        utf8.decode(tx.data),
        equals('makeNewContractFromValidatorData@@05dc'),
      );
    });

    test('mergingValidatorToDelegationWithWhitelist targets the delegation '
        'manager SC and encodes the destination address', () {
      final Address delegationContract = Address.fromBech32(
        'erd1qqqqqqqqqqqqqpgq6wegs2xkypfpync8mn2sa5cmpqjlvrhwz5nqgepyg8',
      );
      final Transaction tx = factory
          .createTransactionForMergingValidatorToDelegationWithWhitelist(
            sender: alice,
            delegationAddress: delegationContract,
          );
      expect(tx.receiver.bech32, equals(delegationManagerContractBech32));
      expect(
        utf8.decode(tx.data),
        equals(
          'mergeValidatorToDelegationWithWhitelist@${delegationContract.hex}',
        ),
      );
    });

    test(
      'mergingValidatorToDelegationSameOwner emits its delegation-manager endpoint',
      () {
        final Address delegationContract = Address.fromBech32(
          'erd1qqqqqqqqqqqqqpgq6wegs2xkypfpync8mn2sa5cmpqjlvrhwz5nqgepyg8',
        );
        final Transaction tx = factory
            .createTransactionForMergingValidatorToDelegationSameOwner(
              sender: alice,
              delegationAddress: delegationContract,
            );
        expect(
          utf8.decode(tx.data),
          equals(
            'mergeValidatorToDelegationSameOwner@${delegationContract.hex}',
          ),
        );
      },
    );
  });
}
