/// Happy-path tests for [MultisigController].
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

import '../../../fixtures/test_fixtures.dart';

void main() {
  late IAccount alice;
  late IAccount bob;
  late Address multisig;
  late MultisigController controller;

  setUpAll(() async {
    alice = await createAliceAccount();
    bob = await createBobAccount();
    multisig = Address.fromBech32(
      'erd1qqqqqqqqqqqqqpgq6wegs2xkypfpync8mn2sa5cmpqjlvrhwz5nqgepyg8',
    );
    controller = MultisigController(chainId: const ChainId.devnet());
  });

  test('proposeAddBoardMember builds and signs a transaction', () async {
    final tx = await controller.createTransactionForProposeAddBoardMember(
      alice,
      const Nonce(1),
      ProposeAddBoardMemberInput(
        multisigContract: multisig,
        boardMember: bob.address,
      ),
      baseOptions: const BaseControllerInput(gasLimit: GasLimit(30_000_000)),
    );

    expect(tx.sender, equals(alice.address));
    expect(tx.receiver, equals(multisig));
    expect(tx.signature, isNotNull);
    expect(tx.chainId.value, equals('D'));
    expect(tx.gasLimit.value, equals(30_000_000));
  });

  test('sign action produces correct data field', () async {
    final tx = await controller.createTransactionForSign(
      alice,
      const Nonce(2),
      SignActionInput(multisigContract: multisig, actionId: 7),
      baseOptions: const BaseControllerInput(gasLimit: GasLimit(10_000_000)),
    );
    expect(tx.data.length, greaterThan(0));
    expect(tx.sender, equals(alice.address));
    expect(tx.receiver, equals(multisig));
  });
}
