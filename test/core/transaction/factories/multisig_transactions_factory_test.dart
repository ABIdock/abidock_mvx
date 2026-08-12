/// Happy-path tests for [MultisigTransactionsFactory].
///
/// Each test asserts the wire shape the multisig contract's argument
/// decoder expects, as produced by [ArgSerializer.valuesToStrings]. For the
/// non-trivial typed arguments (`U32Value`, `OptionValue<U64>`,
/// `CodeMetadataValue`, `BigUIntValue`, `AddressValue`) the test decodes the
/// produced data and compares it to the hand-computed expected hex.
import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  final MultisigTransactionsFactory factory = MultisigTransactionsFactory(
    const MultisigTransactionsConfig(chainId: ChainId.devnet()),
  );
  final Address alice = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  final Address bob = Address.fromBech32(
    'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
  );
  final Address multisig = Address.fromBech32(
    'erd1qqqqqqqqqqqqqpgq6wegs2xkypfpync8mn2sa5cmpqjlvrhwz5nqgepyg8',
  );

  group('MultisigTransactionsFactory', () {
    test('proposeAddBoardMember encodes address as canonical AddressValue', () {
      final Transaction tx = factory.createTransactionForProposeAddBoardMember(
        sender: alice,
        multisigContract: multisig,
        boardMember: bob,
      );
      expect(tx.sender, equals(alice));
      expect(tx.receiver, equals(multisig));
      final String data = utf8.decode(tx.data);
      expect(data, startsWith('proposeAddBoardMember@'));
      final List<String> parts = data.split('@');
      expect(parts.length, equals(2));
      expect(parts[1], equals(bob.hex));
    });

    test('proposeAddProposer targets multisig contract', () {
      final Transaction tx = factory.createTransactionForProposeAddProposer(
        sender: alice,
        multisigContract: multisig,
        proposer: bob,
      );
      expect(tx.receiver, equals(multisig));
      final String data = utf8.decode(tx.data);
      expect(data, equals('proposeAddProposer@${bob.hex}'));
    });

    test('proposeRemoveUser targets multisig contract', () {
      final Transaction tx = factory.createTransactionForProposeRemoveUser(
        sender: alice,
        multisigContract: multisig,
        user: bob,
      );
      expect(utf8.decode(tx.data), equals('proposeRemoveUser@${bob.hex}'));
    });

    test(
      'proposeChangeQuorum encodes quorum via ArgSerializer top-level U32',
      () {
        final Transaction tx = factory.createTransactionForProposeChangeQuorum(
          sender: alice,
          multisigContract: multisig,
          newQuorum: 3,
        );
        expect(utf8.decode(tx.data), equals('proposeChangeQuorum@03'));
      },
    );

    test('proposeTransferExecute (typed) encodes egldAmount as BigUInt and '
        'OptionValue<U64>.none as empty buffer', () {
      final Transaction tx = factory.createTransactionForProposeTransferExecute(
        sender: alice,
        multisigContract: multisig,
        to: bob,
        egldAmount: BigInt.from(1000000000000000000),
      );
      final String data = utf8.decode(tx.data);
      final List<String> parts = data.split('@');
      expect(parts[0], equals('proposeTransferExecute'));
      expect(parts[1], equals(bob.hex));
      expect(parts[2], equals('0de0b6b3a7640000'));
      expect(parts.length, equals(4));
      expect(parts[3], equals(''));
    });

    test(
      'proposeTransferExecute with optGasLimit emits Some(U64) wire bytes',
      () {
        final Transaction tx = factory
            .createTransactionForProposeTransferExecute(
              sender: alice,
              multisigContract: multisig,
              to: bob,
              egldAmount: BigInt.zero,
              optGasLimit: BigInt.from(5000000),
            );
        final String data = utf8.decode(tx.data);
        final List<String> parts = data.split('@');
        expect(parts[0], equals('proposeTransferExecute'));
        expect(parts[1], equals(bob.hex));
        expect(parts[2], equals(''));
        expect(parts[3], equals('0100000000004c4b40'));
      },
    );

    test('proposeTransferExecute appends the forwarded call after the '
        'Option<U64> gas-limit slot', () {
      final Transaction tx = factory.createTransactionForProposeTransferExecute(
        sender: alice,
        multisigContract: multisig,
        to: bob,
        egldAmount: BigInt.from(42),
        functionCall: <TypedValue>[BytesValue(utf8.encode('setOwner'))],
      );
      final String data = utf8.decode(tx.data);
      expect(
        data,
        equals('proposeTransferExecute@${bob.hex}@2a@@7365744f776e6572'),
      );
    });

    test('proposeAsyncCall encodes zero egldAmount as empty BigUInt', () {
      final Transaction tx = factory.createTransactionForProposeAsyncCall(
        sender: alice,
        multisigContract: multisig,
        to: multisig,
      );
      final String data = utf8.decode(tx.data);
      final List<String> parts = data.split('@');
      expect(parts[0], equals('proposeAsyncCall'));
      expect(parts[1], equals(multisig.hex));
      expect(parts[2], equals(''));
      expect(parts[3], equals(''));
    });

    test('sign encodes actionId via top-level U32 (trimmed leading zeros)', () {
      final Transaction tx = factory.createTransactionForSign(
        sender: alice,
        multisigContract: multisig,
        actionId: 42,
      );
      expect(utf8.decode(tx.data), equals('sign@2a'));
    });

    test('unsign encodes actionId via top-level U32', () {
      final Transaction tx = factory.createTransactionForUnsign(
        sender: alice,
        multisigContract: multisig,
        actionId: 7,
      );
      expect(utf8.decode(tx.data), equals('unsign@07'));
    });

    test('performAction encodes actionId via top-level U32', () {
      final Transaction tx = factory.createTransactionForPerformAction(
        sender: alice,
        multisigContract: multisig,
        actionId: 1,
      );
      expect(utf8.decode(tx.data), equals('performAction@01'));
    });

    test('discardAction encodes actionId via top-level U32', () {
      final Transaction tx = factory.createTransactionForDiscardAction(
        sender: alice,
        multisigContract: multisig,
        actionId: 5,
      );
      expect(utf8.decode(tx.data), equals('discardAction@05'));
    });

    test('signBatch / unsignBatch / performBatch encode groupId as U32', () {
      final Transaction signBatch = factory.createTransactionForSignBatch(
        sender: alice,
        multisigContract: multisig,
        groupId: 9,
      );
      expect(utf8.decode(signBatch.data), equals('signBatch@09'));

      final Transaction unsignBatch = factory.createTransactionForUnsignBatch(
        sender: alice,
        multisigContract: multisig,
        groupId: 9,
      );
      expect(utf8.decode(unsignBatch.data), equals('unsignBatch@09'));

      final Transaction performBatch = factory.createTransactionForPerformBatch(
        sender: alice,
        multisigContract: multisig,
        groupId: 9,
      );
      expect(utf8.decode(performBatch.data), equals('performBatch@09'));
    });

    test('discardBatch encodes each id as U32 separated by @', () {
      final Transaction tx = factory.createTransactionForDiscardBatch(
        sender: alice,
        multisigContract: multisig,
        actionIds: const <int>[1, 2, 3],
      );
      expect(utf8.decode(tx.data), equals('discardBatch@01@02@03'));
    });

    test(
      'unsignForOutdatedBoardMembers encodes actionId + variadic outdated ids',
      () {
        final Transaction tx = factory
            .createTransactionForUnsignForOutdatedBoardMembers(
              sender: alice,
              multisigContract: multisig,
              actionId: 4,
              outdatedBoardMembers: const <int>[1, 2],
            );
        expect(
          utf8.decode(tx.data),
          equals('unsignForOutdatedBoardMembers@04@01@02'),
        );
      },
    );

    test(
      'proposeContractDeployFromSource encodes BigUInt amount + AddressValue '
      'source + CodeMetadataValue flags + variadic typed args',
      () {
        final Transaction tx = factory
            .createTransactionForProposeContractDeployFromSource(
              sender: alice,
              multisigContract: multisig,
              amount: BigInt.from(10),
              source: bob,
              codeMetadata: Uint8List.fromList(<int>[0x05, 0x06]),
              arguments: <TypedValue>[U32Value(7)],
            );
        final String data = utf8.decode(tx.data);
        final List<String> parts = data.split('@');
        expect(parts[0], equals('proposeSCDeployFromSource'));
        expect(parts[1], equals('0a'));
        expect(parts[2], equals(bob.hex));
        expect(parts[3], equals('0506'));
        expect(parts[4], equals('07'));
      },
    );

    test(
      'createTransactionForDeploy encodes quorum + variadic board addresses',
      () {
        final Uint8List bytecode = Uint8List.fromList(<int>[
          0xde,
          0xad,
          0xbe,
          0xef,
        ]);
        final Transaction tx = factory.createTransactionForDeploy(
          sender: alice,
          bytecode: bytecode,
          quorum: 2,
          board: <Address>[alice, bob],
          gasLimit: 60_000_000,
        );
        expect(tx.sender, equals(alice));
        expect(tx.receiver, equals(Address.zero()));
        final String data = utf8.decode(tx.data);
        final List<String> parts = data.split('@');
        expect(parts[0], equals('deadbeef'));
        expect(parts[1], equals('0500'));
        expect(parts[2], equals('0506'));
        expect(parts[3], equals('02'));
        expect(parts[4], equals(alice.hex));
        expect(parts[5], equals(bob.hex));
      },
    );

    test('deposit forwards EGLD and explicit gasLimit untouched', () {
      final Transaction tx = factory.createTransactionForDeposit(
        sender: alice,
        multisigContract: multisig,
        nativeTransferAmount: BigInt.from(100),
        gasLimit: 5_000_000,
      );
      expect(tx.value.value, equals(BigInt.from(100)));
      expect(tx.gasLimit.value, equals(5_000_000));
      expect(utf8.decode(tx.data), equals('deposit'));
    });
  });
}
