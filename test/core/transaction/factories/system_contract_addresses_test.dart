/// Pinning tests for every hardcoded system smart contract address.
///
/// Each constant is asserted against a **literal** hex string, never against
/// the constant under test. The governance and validator addresses were both
/// wrong for a long time precisely because the existing assertions compared a
/// factory's receiver with the very constant that produced it, so any value
/// passed. Keep the literals here and never replace them with a reference.
///
/// The addresses share the first 30 bytes; only byte 29 distinguishes them:
/// `00` staking, `01` validator, `02` ESDT, `03` governance, `04` delegation
/// manager.
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

/// Byte 29 of every system contract address, by contract.
const String stakingHex =
    '000000000000000000010000000000000000000000000000000000000000ffff';
const String validatorHex =
    '000000000000000000010000000000000000000000000000000000000001ffff';
const String esdtHex =
    '000000000000000000010000000000000000000000000000000000000002ffff';
const String governanceHex =
    '000000000000000000010000000000000000000000000000000000000003ffff';

void main() {
  group('governance system contract address', () {
    test('hex constant is the governance contract', () {
      expect(governanceContractAddressHex, equals(governanceHex));
    });

    test('bech32 constant decodes to the governance contract', () {
      expect(
        Address.fromBech32(governanceContractBech32).hex,
        equals(governanceHex),
      );
    });

    test('is not the staking or validator contract', () {
      expect(governanceContractAddressHex, isNot(equals(stakingHex)));
      expect(governanceContractAddressHex, isNot(equals(validatorHex)));
    });
  });

  group('validator ("auction") system contract address', () {
    test('hex constant is the validator contract', () {
      expect(stakingContractAddressHex, equals(validatorHex));
    });

    test('bech32 constant decodes to the validator contract', () {
      expect(
        Address.fromBech32(stakingContractBech32).hex,
        equals(validatorHex),
      );
    });

    test('is not the staking contract, which rejects wallet callers', () {
      expect(stakingContractAddressHex, isNot(equals(stakingHex)));
    });
  });

  group('ESDT system contract address', () {
    test('hex constant is the ESDT contract', () {
      expect(esdtContractAddressHex, equals(esdtHex));
    });
  });

  group('factory receivers resolve to the pinned addresses', () {
    final Address alice = Address.fromBech32(
      'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
    );

    test(
      'governance transactions are addressed to the governance contract',
      () {
        final GovernanceTransactionsFactory factory =
            GovernanceTransactionsFactory(
              const GovernanceTransactionsConfig(chainId: ChainId.devnet()),
            );
        final Transaction tx = factory.createTransactionForVoting(
          sender: alice,
          proposalNonce: 1,
          vote: VoteType.yes,
        );

        expect(tx.receiver.hex, equals(governanceHex));
      },
    );

    test('staking transactions are addressed to the validator contract', () {
      final StakingTransactionsFactory factory = StakingTransactionsFactory(
        const StakingTransactionsConfig(chainId: ChainId.devnet()),
      );
      final Transaction tx = factory.createTransactionForClaimingRewards(
        sender: alice,
      );

      expect(tx.receiver.hex, equals(validatorHex));
    });
  });
}
