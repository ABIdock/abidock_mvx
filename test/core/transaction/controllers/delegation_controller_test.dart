import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

import '../../../fixtures/test_fixtures.dart';

void main() {
  late DelegationController controller;
  late IAccount alice;
  late IAccount bob;
  late Address mockDelegationContract;
  setUpAll(() async {
    alice = await createAliceAccount();
    bob = await createBobAccount();
    controller = DelegationController(chainId: const ChainId.devnet());
    mockDelegationContract = Address.fromBech32(
      'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
    );
  });
  group('DelegationController - Contract Creation', () {
    test('should create transaction for new delegation contract', () async {
      final input = NewDelegationContractInput(
        totalDelegationCap: BigInt.from(100000000) * BigInt.from(10).pow(18),
        serviceFee: BigInt.from(1000),
        amount: Balance.fromEgld(1250),
      );
      const baseInput = BaseControllerInput(gasLimit: GasLimit(60000000));
      final tx = await controller.createTransactionForNewDelegationContract(
        alice,
        const Nonce(100),
        input,
        baseOptions: baseInput,
      );
      expect(tx.sender, equals(alice.address));
      expect(
        tx.receiver.bech32,
        equals(
          'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqylllslmq6y6',
        ),
      );
      expect(tx.value, equals(Balance.fromEgld(1250)));
      expect(tx.gasLimit.value, equals(60000000));
      expect(tx.nonce, equals(const Nonce(100)));
      expect(tx.signature, isNotNull);
    });
    test('should create transaction with different service fee', () async {
      final input = NewDelegationContractInput(
        totalDelegationCap: BigInt.from(50000000) * BigInt.from(10).pow(18),
        serviceFee: BigInt.from(500),
        amount: Balance.fromEgld(2500),
      );
      final tx = await controller.createTransactionForNewDelegationContract(
        alice,
        const Nonce(101),
        input,
      );
      expect(tx.sender, equals(alice.address));
      expect(tx.value, equals(Balance.fromEgld(2500)));
      expect(tx.signature, isNotNull);
    });
  });
  group('DelegationController - Delegator Operations', () {
    test('should create transaction for delegating funds', () async {
      final input = DelegateInput(
        delegationContract: mockDelegationContract,
        amount: Balance.fromEgld(100),
      );
      const baseInput = BaseControllerInput(gasLimit: GasLimit(12000000));
      final tx = await controller.createTransactionForDelegating(
        alice,
        const Nonce(110),
        input,
        baseOptions: baseInput,
      );
      expect(tx.sender, equals(alice.address));
      expect(tx.receiver, equals(mockDelegationContract));
      expect(tx.value, equals(Balance.fromEgld(100)));
      expect(tx.gasLimit.value, equals(12000000));
      expect(tx.nonce, equals(const Nonce(110)));
      expect(tx.signature, isNotNull);
    });
    test('should create transaction for undelegating funds', () async {
      final input = UndelegateInput(
        delegationContract: mockDelegationContract,
        amount: Balance.fromEgld(50),
      );
      const baseInput = BaseControllerInput(gasLimit: GasLimit(12000000));
      final tx = await controller.createTransactionForUndelegating(
        alice,
        const Nonce(111),
        input,
        baseOptions: baseInput,
      );
      expect(tx.sender, equals(alice.address));
      expect(tx.receiver, equals(mockDelegationContract));
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.gasLimit.value, equals(12000000));
      expect(tx.signature, isNotNull);
    });
    test('should create transaction for withdrawing funds', () async {
      final input = WithdrawInput(delegationContract: mockDelegationContract);
      const baseInput = BaseControllerInput(gasLimit: GasLimit(12000000));
      final tx = await controller.createTransactionForWithdrawing(
        alice,
        const Nonce(112),
        input,
        baseOptions: baseInput,
      );
      expect(tx.sender, equals(alice.address));
      expect(tx.receiver, equals(mockDelegationContract));
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.gasLimit.value, equals(12000000));
      expect(tx.signature, isNotNull);
    });
    test('should create transaction for claiming rewards', () async {
      final input = WithdrawInput(delegationContract: mockDelegationContract);
      const baseInput = BaseControllerInput(gasLimit: GasLimit(6000000));
      final tx = await controller.createTransactionForClaimingRewards(
        alice,
        const Nonce(113),
        input,
        baseOptions: baseInput,
      );
      expect(tx.sender, equals(alice.address));
      expect(tx.receiver, equals(mockDelegationContract));
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.gasLimit.value, equals(6000000));
      expect(tx.signature, isNotNull);
    });
    test('should create transaction for redelegating rewards', () async {
      final input = WithdrawInput(delegationContract: mockDelegationContract);
      const baseInput = BaseControllerInput(gasLimit: GasLimit(12000000));
      final tx = await controller.createTransactionForRedelegatingRewards(
        alice,
        const Nonce(114),
        input,
        baseOptions: baseInput,
      );
      expect(tx.sender, equals(alice.address));
      expect(tx.receiver, equals(mockDelegationContract));
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.gasLimit.value, equals(12000000));
      expect(tx.signature, isNotNull);
    });
  });
  group('DelegationController - Contract Settings', () {
    test('should create transaction for changing service fee', () async {
      final input = ChangeServiceFeeInput(
        delegationContract: mockDelegationContract,
        serviceFee: BigInt.from(1500),
      );
      const baseInput = BaseControllerInput(gasLimit: GasLimit(6000000));
      final tx = await controller.createTransactionForChangingServiceFee(
        alice,
        const Nonce(120),
        input,
        baseOptions: baseInput,
      );
      expect(tx.sender, equals(alice.address));
      expect(tx.receiver, equals(mockDelegationContract));
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.gasLimit.value, equals(6000000));
      expect(tx.signature, isNotNull);
    });
    test('should create transaction for modifying delegation cap', () async {
      final input = ModifyDelegationCapInput(
        delegationContract: mockDelegationContract,
        delegationCap: BigInt.from(200000000) * BigInt.from(10).pow(18),
      );
      const baseInput = BaseControllerInput(gasLimit: GasLimit(6000000));
      final tx = await controller.createTransactionForModifyingDelegationCap(
        alice,
        const Nonce(121),
        input,
        baseOptions: baseInput,
      );
      expect(tx.sender, equals(alice.address));
      expect(tx.receiver, equals(mockDelegationContract));
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.gasLimit.value, equals(6000000));
      expect(tx.signature, isNotNull);
    });
    test(
      'should create transaction for setting automatic activation',
      () async {
        final input = ManageDelegationContractInput(
          delegationContract: mockDelegationContract,
        );
        const baseInput = BaseControllerInput(gasLimit: GasLimit(6000000));
        final tx = await controller
            .createTransactionForSettingAutomaticActivation(
              alice,
              const Nonce(122),
              input,
              baseOptions: baseInput,
            );
        expect(tx.sender, equals(alice.address));
        expect(tx.receiver, equals(mockDelegationContract));
        expect(tx.value.value, equals(BigInt.zero));
        expect(tx.signature, isNotNull);
      },
    );
    test('should create transaction for setting metadata', () async {
      final input = SetMetadataInput(
        delegationContract: mockDelegationContract,
        name: 'My Staking Provider',
        website: 'https://mystaking.com',
        identifier: 'mystaking',
      );
      const baseInput = BaseControllerInput(gasLimit: GasLimit(6000000));
      final tx = await controller.createTransactionForSettingMetadata(
        alice,
        const Nonce(123),
        input,
        baseOptions: baseInput,
      );
      expect(tx.sender, equals(alice.address));
      expect(tx.receiver, equals(mockDelegationContract));
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.signature, isNotNull);
    });
  });
  group('DelegationController - Multiple Accounts', () {
    test(
      'should allow different accounts to delegate to same contract',
      () async {
        final aliceInput = DelegateInput(
          delegationContract: mockDelegationContract,
          amount: Balance.fromEgld(75),
        );
        final bobInput = DelegateInput(
          delegationContract: mockDelegationContract,
          amount: Balance.fromEgld(125),
        );
        final aliceTx = await controller.createTransactionForDelegating(
          alice,
          const Nonce(130),
          aliceInput,
        );
        final bobTx = await controller.createTransactionForDelegating(
          bob,
          const Nonce(50),
          bobInput,
        );
        expect(aliceTx.sender, equals(alice.address));
        expect(aliceTx.value, equals(Balance.fromEgld(75)));
        expect(aliceTx.receiver, equals(mockDelegationContract));
        expect(bobTx.sender, equals(bob.address));
        expect(bobTx.value, equals(Balance.fromEgld(125)));
        expect(bobTx.receiver, equals(mockDelegationContract));
      },
    );
  });
  group('DelegationController - Transaction Properties', () {
    test(
      'should use correct delegation manager address for contract creation',
      () async {
        final input = NewDelegationContractInput(
          totalDelegationCap: BigInt.from(10000000) * BigInt.from(10).pow(18),
          serviceFee: BigInt.from(1000),
          amount: Balance.fromEgld(1250),
        );
        final tx = await controller.createTransactionForNewDelegationContract(
          alice,
          const Nonce(140),
          input,
        );
        expect(
          tx.receiver.bech32,
          equals(
            'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqylllslmq6y6',
          ),
        );
      },
    );
    test('should have valid transaction signatures', () async {
      final input = DelegateInput(
        delegationContract: mockDelegationContract,
        amount: Balance.fromEgld(50),
      );
      final tx = await controller.createTransactionForDelegating(
        alice,
        const Nonce(141),
        input,
      );
      expect(tx.signature, isNotNull);
      expect(tx.signature.hex.length, equals(128));
    });
    test('should handle large delegation amounts', () async {
      final input = DelegateInput(
        delegationContract: mockDelegationContract,
        amount: Balance.fromEgld(1000000),
      );
      final tx = await controller.createTransactionForDelegating(
        alice,
        const Nonce(142),
        input,
      );
      expect(tx.value, equals(Balance.fromEgld(1000000)));
      expect(tx.signature, isNotNull);
    });
  });
}
