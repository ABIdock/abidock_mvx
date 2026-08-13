import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

import '../../../fixtures/test_fixtures.dart';

void main() {
  final RelayedTransactionsFactory factory = RelayedTransactionsFactory(
    const RelayedTransactionsConfig(chainId: ChainId('D')),
  );

  /// Mnemonic address index 1, shard 1.
  final Address sender = Address.fromBech32(
    'erd1xkrttq324elvla4kk83r6wns35cjyqw7vg5tmdfn7qmrc2drd7qswlwt6z',
  );

  /// Mnemonic address index 2, shard 1.
  final Address relayer = Address.fromBech32(
    'erd19assuvyq236dmr4th5wjy59c75cn98zjusd3m74kv5y9ylerl0esenuv3m',
  );

  /// Mnemonic address index 0, shard 0.
  final Address otherShardRelayer = Address.fromBech32(
    'erd1sqhjrtmsn5yjk6w85099p8v0ly0g8z9pxeqe5dvu5rlf2n7vq3vqytny9g',
  );

  final Address receiver = Address.fromBech32(
    'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
  );

  Transaction userTx({
    int version = 1,
    ChainId chainId = const ChainId('D'),
    Address? guardian,
    Signature signature = const Signature.empty(),
  }) {
    return Transaction(
      nonce: const Nonce(5),
      sender: sender,
      receiver: receiver,
      value: Balance(BigInt.parse('1000000000000000000')),
      gasLimit: const GasLimit(50000),
      gasPrice: const GasPrice(1000000000),
      chainId: chainId,
      version: TransactionVersion(version),
      data: Uint8List(0),
      guardian: guardian,
      signature: signature,
    );
  }

  const String relayedPayload =
      '{"nonce":5,"value":"1000000000000000000",'
      '"receiver":"erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8",'
      '"sender":"erd1xkrttq324elvla4kk83r6wns35cjyqw7vg5tmdfn7qmrc2drd7qswlwt6z",'
      '"gasPrice":1000000000,"gasLimit":100000,"chainID":"D","version":2,'
      '"relayer":"erd19assuvyq236dmr4th5wjy59c75cn98zjusd3m74kv5y9ylerl0esenuv3m"}';

  group('RelayedTransactionsFactory.applyRelayer', () {
    test('sets relayer, raises version to 2 and adds the base cost', () {
      final Transaction relayed = factory.applyRelayer(userTx(), relayer);

      expect(
        relayed.relayer!.bech32,
        'erd19assuvyq236dmr4th5wjy59c75cn98zjusd3m74kv5y9ylerl0esenuv3m',
      );
      expect(relayed.version.value, 2);
      expect(relayed.gasLimit.value, 100000);
      expect(utf8.decode(relayed.serializeForSigning()), relayedPayload);
    });

    test('produces a flat transaction without inner transactions', () {
      final Transaction relayed = factory.applyRelayer(userTx(), relayer);

      expect(relayed.toJson().containsKey('innerTransactions'), isFalse);
      expect(relayed.receiver.bech32, receiver.bech32);
      expect(relayed.sender.bech32, sender.bech32);
    });

    test('does not charge the base cost twice when re-applied', () {
      final Transaction once = factory.applyRelayer(userTx(), relayer);
      final Transaction twice = factory.applyRelayer(once, relayer);

      expect(twice.gasLimit.value, 100000);
      expect(utf8.decode(twice.serializeForSigning()), relayedPayload);
    });

    test('rejects a transaction that is already signed', () {
      expect(
        () => factory.applyRelayer(
          userTx(version: 2, signature: Signature('ab' * 64)),
          relayer,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a relayer in another shard', () {
      expect(
        () => factory.applyRelayer(userTx(), otherShardRelayer),
        throwsArgumentError,
      );
    });

    test('rejects a relayer that is also the guardian', () {
      expect(
        () => factory.applyRelayer(userTx(guardian: relayer), relayer),
        throwsArgumentError,
      );
    });

    test('rejects a chain id that differs from the factory config', () {
      expect(
        () =>
            factory.applyRelayer(userTx(chainId: const ChainId('1')), relayer),
        throwsArgumentError,
      );
    });

    test('rejects replacing an already set relayer', () {
      final Transaction relayed = factory.applyRelayer(userTx(), relayer);

      expect(
        () => factory.applyRelayer(relayed, receiver),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('RelayedTransactionsFactory signing', () {
    late UserSigner senderSigner;
    late UserSigner relayerSigner;

    setUp(() async {
      final Mnemonic mnemonic = Mnemonic.fromString(testMnemonic);
      senderSigner = UserSigner.fromSecretKey(
        await mnemonic.deriveKey(addressIndex: 1),
      );
      relayerSigner = UserSigner.fromSecretKey(
        await mnemonic.deriveKey(addressIndex: 2),
      );
    });

    test('sender and relayer sign the very same bytes, in any order', () async {
      final Transaction relayed = factory.applyRelayer(userTx(), relayer);

      final Transaction senderFirst = await (await relayed.signWith(
        senderSigner,
      )).signAsRelayer(relayerSigner);
      final Transaction relayerFirst = await (await relayed.signAsRelayer(
        relayerSigner,
      )).signWith(senderSigner);

      expect(
        senderFirst.signature.hex,
        '5796575bd003c90d57360ccb11366e10d8456c6486b041978fd55bd01b8c5874'
        '2f9542296671a75d82e3e8e817b4c0df280679e13e6907db99b91efa0938fd09',
      );
      expect(
        senderFirst.relayerSignature.hex,
        '49591433f59811de776eaea6a71752bed113efedb50a05be8d7b4b6049bb5f66'
        '115d53b1dc577efc612d0fce1b59897c59692dcf03979486d3a845797fd95c04',
      );
      expect(relayerFirst.signature.hex, senderFirst.signature.hex);
      expect(
        relayerFirst.relayerSignature.hex,
        senderFirst.relayerSignature.hex,
      );
    });

    test('signatures stay out of the signed payload', () async {
      final Transaction relayed = factory.applyRelayer(userTx(), relayer);
      final Transaction cosigned = await (await relayed.signWith(senderSigner))
          .signAsRelayer(relayerSigner);

      expect(utf8.decode(cosigned.serializeForSigning()), relayedPayload);

      const TransactionComputer computer = TransactionComputer();
      final Map<String, dynamic> payload = computer.toPlainObject(cosigned);
      expect(payload.containsKey('signature'), isFalse);
      expect(payload.containsKey('relayerSignature'), isFalse);
      expect(payload.containsKey('guardianSignature'), isFalse);
      expect(
        payload['relayer'],
        'erd19assuvyq236dmr4th5wjy59c75cn98zjusd3m74kv5y9ylerl0esenuv3m',
      );
    });
  });
}
