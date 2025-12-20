import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

import '../../../fixtures/test_fixtures.dart';

void main() {
  late TransfersController controller;
  late IAccount alice;
  late IAccount bob;

  setUpAll(() async {
    alice = await createAliceAccount();
    bob = await createBobAccount();
    controller = TransfersController(chainId: const ChainId.devnet());
  });

  group('Native EGLD Transfers', () {
    test('creates basic transfers with data and gas options', () async {
      final simpleTx = await controller.createTransactionForNativeTransfer(
        alice,
        const Nonce(42),
        NativeTransferInput(
          receiver: bob.address,
          amount: Balance.fromEgld(1.5),
        ),
      );
      expect(simpleTx.sender, equals(alice.address));
      expect(simpleTx.receiver, equals(bob.address));
      expect(simpleTx.value, equals(Balance.fromEgld(1.5)));
      expect(simpleTx.chainId.value, equals('D'));
      expect(simpleTx.signature, isNotNull);

      final dataTx = await controller.createTransactionForNativeTransfer(
        alice,
        const Nonce(10),
        NativeTransferInput(
          receiver: bob.address,
          amount: Balance.zero(),
          data: Uint8List.fromList(utf8.encode('Payment for service')),
        ),
      );
      expect(dataTx.value, equals(Balance.zero()));
      expect(utf8.decode(dataTx.data), equals('Payment for service'));

      final customGasTx = await controller.createTransactionForNativeTransfer(
        alice,
        const Nonce(20),
        NativeTransferInput(
          receiver: bob.address,
          amount: Balance.fromEgld(1.0),
        ),
        baseOptions: const BaseControllerInput(gasLimit: GasLimit(100000)),
      );
      expect(customGasTx.gasLimit.value, equals(100000));
    });

    test('handles signatures and transaction properties', () async {
      final tx = await controller.createTransactionForNativeTransfer(
        alice,
        const Nonce(5),
        NativeTransferInput(
          receiver: bob.address,
          amount: Balance.fromEgld(0.1),
        ),
      );
      expect(tx.signature.bytes.length, equals(64));

      final hash = const TransactionComputer().computeTransactionHash(tx);
      expect(hash.length, equals(64));

      final json = tx.toJson();
      expect(json['sender'], isNotNull);
      expect(json['chainID'], equals('D'));
      expect(json['signature'], isNotNull);
    });

    test('supports bidirectional transfers', () async {
      final aliceToBobTx = await controller.createTransactionForNativeTransfer(
        alice,
        const Nonce(1),
        NativeTransferInput(
          receiver: bob.address,
          amount: Balance.fromEgld(2.5),
        ),
      );
      expect(aliceToBobTx.sender, equals(alice.address));
      expect(aliceToBobTx.receiver, equals(bob.address));

      final bobToAliceTx = await controller.createTransactionForNativeTransfer(
        bob,
        const Nonce(1),
        NativeTransferInput(
          receiver: alice.address,
          amount: Balance.fromEgld(3.7),
        ),
      );
      expect(bobToAliceTx.sender, equals(bob.address));
      expect(bobToAliceTx.receiver, equals(alice.address));
    });
  });

  group('Token Transfers', () {
    test('handles fungible and non-fungible tokens', () async {
      final fungibleTx = await controller.createTransactionForTokenTransfer(
        alice,
        const Nonce(50),
        TokenTransferInput(
          receiver: bob.address,
          transfers: [
            TokenTransfer.fungible(
              tokenIdentifier: 'MYTOKEN-abc123',
              amount: BigInt.from(1000),
            ),
          ],
        ),
      );
      expect(fungibleTx.sender, equals(alice.address));
      expect(fungibleTx.receiver, equals(bob.address));
      expect(fungibleTx.value, equals(Balance.zero()));
      expect(fungibleTx.data, isNotNull);

      final nftTx = await controller.createTransactionForTokenTransfer(
        alice,
        const Nonce(60),
        TokenTransferInput(
          receiver: bob.address,
          transfers: [
            TokenTransfer.nonFungible(
              tokenIdentifier: 'NFT-def456',
              nonce: 42,
              amount: BigInt.one,
            ),
          ],
        ),
      );
      expect(nftTx.data, isNotNull);
    });

    test('supports multi-token transfers', () async {
      final multiTx = await controller.createTransactionForMultiTokenTransfer(
        bob,
        const Nonce(80),
        TokenTransferInput(
          receiver: alice.address,
          transfers: [
            TokenTransfer.fungible(
              tokenIdentifier: 'TOKEN-aaa111',
              amount: BigInt.from(500),
            ),
            TokenTransfer.fungible(
              tokenIdentifier: 'TOKEN-bbb222',
              amount: BigInt.from(300),
            ),
            TokenTransfer.nonFungible(
              tokenIdentifier: 'NFT-ccc333',
              nonce: 1,
              amount: BigInt.one,
            ),
          ],
        ),
      );
      expect(multiTx.sender, equals(bob.address));
      expect(multiTx.value, equals(Balance.zero()));
      expect(multiTx.data, isNotNull);
    });

    test('handles token transfers with custom gas', () async {
      final tx = await controller.createTransactionForTokenTransfer(
        alice,
        const Nonce(90),
        TokenTransferInput(
          receiver: bob.address,
          transfers: [
            TokenTransfer.fungible(
              tokenIdentifier: 'CUSTOM-a1b2c3',
              amount: BigInt.from(999),
            ),
          ],
        ),
        baseOptions: const BaseControllerInput(gasLimit: GasLimit(500000)),
      );
      expect(tx.gasLimit.value, equals(500000));
    });
  });

  group('Edge Cases and Advanced Features', () {
    test('handles edge cases', () async {
      final minimalTx = await controller.createTransactionForNativeTransfer(
        alice,
        const Nonce(100),
        NativeTransferInput(receiver: bob.address, amount: Balance(BigInt.one)),
      );
      expect(minimalTx.value, equals(Balance(BigInt.one)));

      final selfTx = await controller.createTransactionForNativeTransfer(
        alice,
        const Nonce(103),
        NativeTransferInput(
          receiver: alice.address,
          amount: Balance.fromEgld(0.5),
        ),
      );
      expect(selfTx.sender, equals(alice.address));
      expect(selfTx.receiver, equals(alice.address));

      final longDataTx = await controller.createTransactionForNativeTransfer(
        alice,
        const Nonce(102),
        NativeTransferInput(
          receiver: bob.address,
          amount: Balance.fromEgld(0.1),
          data: Uint8List.fromList(utf8.encode('A' * 1000)),
        ),
      );
      expect(longDataTx.data.length, equals(1000));
    });

    test('supports nonce handling', () async {
      final nonces = [10, 11, 12];
      final transactions = <Transaction>[];
      for (final nonce in nonces) {
        final tx = await controller.createTransactionForNativeTransfer(
          alice,
          Nonce(nonce),
          NativeTransferInput(
            receiver: bob.address,
            amount: Balance.fromEgld(0.1),
          ),
        );
        transactions.add(tx);
        expect(tx.nonce.value, equals(nonce));
      }
      expect(transactions.length, equals(3));

      final highNonceTx = await controller.createTransactionForNativeTransfer(
        alice,
        const Nonce(999999),
        NativeTransferInput(
          receiver: bob.address,
          amount: Balance.fromEgld(0.01),
        ),
      );
      expect(highNonceTx.nonce.value, equals(999999));
    });

    test('simulates real-world scenarios', () async {
      final paymentTx = await controller.createTransactionForNativeTransfer(
        alice,
        const Nonce(500),
        NativeTransferInput(
          receiver: bob.address,
          amount: Balance.fromEgld(49.99),
          data: Uint8List.fromList(utf8.encode('Order #12345')),
        ),
      );
      expect(paymentTx.value, equals(Balance.fromEgld(49.99)));
      expect(utf8.decode(paymentTx.data), contains('Order #12345'));

      final nftSaleTx = await controller.createTransactionForTokenTransfer(
        bob,
        const Nonce(502),
        TokenTransferInput(
          receiver: alice.address,
          transfers: [
            TokenTransfer.nonFungible(
              tokenIdentifier: 'COLLEC-abc123',
              nonce: 7,
              amount: BigInt.one,
            ),
          ],
        ),
      );
      expect(nftSaleTx.sender, equals(bob.address));
    });
  });
}
