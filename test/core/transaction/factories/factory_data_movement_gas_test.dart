import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

/// Every builder that derives its own gas limit must charge the chain's
/// data-movement gas on top of the execution allowance for the call:
///
///     gasLimit = 50000 + 1500 * data.length + executionGas
///
/// The `50000` floor and the `1500`-per-byte rate are the protocol's
/// `MinGasLimit` and `GasPerDataByte` economics values. Every expectation in
/// this file is a literal integer worked out from those two numbers, never
/// read back from a config object.
void main() {
  const ChainId chainD = ChainId('D');

  final Address sender = Address.fromBech32(
    'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
  );
  final Address user = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  final Address delegationContract = Address.fromBech32(
    'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqylllslmq6y6',
  );

  String dataOf(Transaction tx) => utf8.decode(tx.data);

  ValidatorPublicKey blsKey(int fill) =>
      ValidatorPublicKey(Uint8List.fromList(List<int>.filled(96, fill)));

  group('TokenManagementTransactionsFactory data-movement gas', () {
    final TokenManagementTransactionsFactory factory =
        TokenManagementTransactionsFactory(
          config: const TokenManagementConfig(chainId: chainD),
        );

    test('issuing a fungible token charges 50000 + 1500/byte + 60000000', () {
      final Transaction tx = factory.createTransactionForIssuingFungible(
        sender: sender,
        tokenName: 'FrankToken',
        tokenTicker: 'FRANK',
        initialSupply: BigInt.from(100),
        decimals: 0,
      );

      expect(
        dataOf(tx),
        equals(
          'issue@4672616e6b546f6b656e@4652414e4b@64@'
          '@63616e467265657a65@66616c7365'
          '@63616e57697065@66616c7365'
          '@63616e5061757365@66616c7365'
          '@63616e4368616e67654f776e6572@66616c7365'
          '@63616e55706772616465@74727565'
          '@63616e4164645370656369616c526f6c6573@66616c7365',
        ),
      );
      expect(tx.data.length, equals(243));
      expect(tx.gasLimit.value, equals(60414500));
    });

    test('setting a special role charges the data-movement term', () {
      final Transaction tx = factory
          .createTransactionForSettingSpecialRoleOnFungibleToken(
            sender: sender,
            user: user,
            tokenIdentifier: 'FRANK-11ce3e',
            roles: const <String>['ESDTRoleLocalMint', 'ESDTRoleLocalBurn'],
          );

      expect(tx.data.length, equals(174));
      expect(tx.gasLimit.value, equals(60311000));
    });

    test('four URIs make the data-movement term dominate the storage term', () {
      final Transaction tx = factory.createTransactionForSettingNewUris(
        sender: sender,
        tokenIdentifier: 'COLL-abc123',
        nonce: 7,
        newUris: const <String>[
          'https://media.example/one.png',
          'https://media.example/two.png',
          'https://media.example/three.png',
          'https://media.example/four.png',
        ],
      );

      expect(tx.data.length, equals(282));
      expect(tx.gasLimit.value, equals(61663000));
    });

    test('a longer URI list raises gas by exactly 1500 per extra byte', () {
      final Transaction short = factory.createTransactionForSettingNewUris(
        sender: sender,
        tokenIdentifier: 'COLL-abc123',
        nonce: 7,
        newUris: const <String>['https://media.example/one.png'],
      );
      final Transaction long = factory.createTransactionForSettingNewUris(
        sender: sender,
        tokenIdentifier: 'COLL-abc123',
        nonce: 7,
        newUris: const <String>[
          'https://media.example/one.png',
          'https://media.example/one.png',
        ],
      );

      expect(long.data.length - short.data.length, equals(59));
      expect(long.gasLimit.value - short.gasLimit.value, equals(378500));
    });
  });

  group('AccountTransactionsFactory data-movement gas', () {
    final AccountTransactionsFactory factory = AccountTransactionsFactory(
      const AccountTransactionsConfig(chainId: chainD),
    );

    test('SetGuardian charges 50000 + 1500/byte + 250000', () {
      final Transaction tx = factory.createTransactionForSettingGuardian(
        sender: sender,
        guardianAddress: user,
        serviceId: 'ServiceID',
      );

      expect(tx.data.length, equals(95));
      expect(tx.gasLimit.value, equals(442500));
    });

    test('GuardAccount charges 50000 + 1500/byte + 250000', () {
      final Transaction tx = factory.createTransactionForGuardingAccount(
        sender: sender,
      );

      expect(dataOf(tx), equals('GuardAccount'));
      expect(tx.gasLimit.value, equals(318000));
    });

    test('UnGuardAccount charges 50000 + 1500/byte + 250000', () {
      final Transaction tx = factory.createTransactionForUnguardingAccount(
        sender: sender,
      );

      expect(dataOf(tx), equals('UnGuardAccount'));
      expect(tx.gasLimit.value, equals(321000));
    });

    test('SaveKeyValue does not double-count the 50000 floor', () {
      final Transaction tx = factory.createTransactionForSavingKeyValue(
        sender: sender,
        keyValuePairs: <Uint8List, Uint8List>{
          Uint8List.fromList(<int>[0x74, 0x65, 0x73, 0x74]): Uint8List.fromList(
            <int>[0x01, 0x02],
          ),
        },
      );

      expect(dataOf(tx), equals('SaveKeyValue@74657374@0102'));
      expect(tx.data.length, equals(26));
      expect(tx.gasLimit.value, equals(295000));
    });
  });

  group('DelegationTransactionsFactory data-movement gas', () {
    final DelegationTransactionsFactory factory = DelegationTransactionsFactory(
      const DelegationTransactionsConfig(chainId: chainD),
    );

    test('delegate charges 50000 + 1500/byte + 1000000 + 100000', () {
      final Transaction tx = factory.createTransactionForDelegating(
        sender: sender,
        delegationContract: delegationContract,
        amount: Balance(BigInt.from(1000000000000000000)),
      );

      expect(dataOf(tx), equals('delegate'));
      expect(tx.gasLimit.value, equals(1162000));
    });

    test('three BLS keys keep the 6000000-per-node term and add movement', () {
      final Transaction tx = factory.createTransactionForStakingNodes(
        sender: sender,
        delegationContract: delegationContract,
        publicKeys: <ValidatorPublicKey>[
          blsKey(0xaa),
          blsKey(0xbb),
          blsKey(0xcc),
        ],
      );

      expect(tx.data.length, equals(589));
      expect(tx.gasLimit.value, equals(24933500));
    });

    test('removeNodes scales per node and per data byte', () {
      final Transaction tx = factory.createTransactionForRemovingNodes(
        sender: sender,
        delegationContract: delegationContract,
        publicKeys: <ValidatorPublicKey>[
          blsKey(0xaa),
          blsKey(0xbb),
          blsKey(0xcc),
        ],
      );

      expect(tx.data.length, equals(590));
      expect(tx.gasLimit.value, equals(19935000));
    });

    test('each extra BLS key costs 6000000 plus 1500 per added byte', () {
      final Transaction two = factory.createTransactionForRemovingNodes(
        sender: sender,
        delegationContract: delegationContract,
        publicKeys: <ValidatorPublicKey>[blsKey(0xaa), blsKey(0xbb)],
      );
      final Transaction three = factory.createTransactionForRemovingNodes(
        sender: sender,
        delegationContract: delegationContract,
        publicKeys: <ValidatorPublicKey>[
          blsKey(0xaa),
          blsKey(0xbb),
          blsKey(0xcc),
        ],
      );

      expect(three.data.length - two.data.length, equals(193));
      expect(three.gasLimit.value - two.gasLimit.value, equals(6289500));
    });
  });

  group('per-item scaling survives alongside the data-movement term', () {
    test('validators unStake charges 5000000 per key plus movement', () {
      final ValidatorsTransactionsFactory factory =
          ValidatorsTransactionsFactory(
            const ValidatorsTransactionsConfig(chainId: chainD),
          );

      final Transaction tx = factory.createTransactionForUnstaking(
        sender: sender,
        publicKeys: <ValidatorPublicKey>[blsKey(0xaa), blsKey(0xbb)],
      );

      expect(tx.data.length, equals(393));
      expect(tx.gasLimit.value, equals(10639500));
    });

    test('staking claim charges 50000 + 1500/byte + 6000000 exactly once', () {
      final StakingTransactionsFactory factory = StakingTransactionsFactory(
        const StakingTransactionsConfig(chainId: chainD),
      );

      final Transaction tx = factory.createTransactionForClaimingRewards(
        sender: sender,
      );

      expect(dataOf(tx), equals('claim'));
      expect(tx.gasLimit.value, equals(6057500));
    });

    test('governance clearEndedProposals charges once per proposer', () {
      final GovernanceTransactionsFactory factory =
          GovernanceTransactionsFactory(
            const GovernanceTransactionsConfig(chainId: chainD),
          );

      final Transaction tx = factory.createTransactionForClearingEndedProposals(
        sender: sender,
        proposers: <Address>[sender, user],
      );

      expect(tx.data.length, equals(149));
      expect(tx.gasLimit.value, equals(150273500));
    });
  });

  group('an explicit gas limit still wins', () {
    test('transfer factory forwards the caller value untouched', () {
      final TransferTransactionsFactory factory = TransferTransactionsFactory(
        config: const TransferTransactionsConfig(chainId: chainD),
      );

      final Transaction tx = factory.createTransactionForEsdtTransfer(
        sender: sender,
        receiver: user,
        tokenTransfers: <TokenTransfer>[
          TokenTransfer.fungible(
            tokenIdentifier: 'FRANK-11ce3e',
            amount: BigInt.from(100),
          ),
        ],
        gasLimit: const GasLimit(7654321),
      );

      expect(tx.gasLimit.value, equals(7654321));
    });

    test('multisig deposit forwards the caller value untouched', () {
      final MultisigTransactionsFactory factory = MultisigTransactionsFactory(
        const MultisigTransactionsConfig(chainId: chainD),
      );

      final Transaction tx = factory.createTransactionForDeposit(
        sender: sender,
        multisigContract: delegationContract,
        nativeTransferAmount: BigInt.from(1000),
        gasLimit: 5000000,
      );

      expect(tx.gasLimit.value, equals(5000000));
    });
  });
}
