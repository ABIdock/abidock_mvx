import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  final factory = RelayedTransactionsFactory(
    const RelayedTransactionsConfig(chainId: ChainId('D')),
  );
  final relayer = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  final alice = Address.fromBech32(
    'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
  );

  Transaction signedInner({
    Address? relayerOverride,
    ChainId? chainIdOverride,
    int gas = 50_000,
  }) {
    return Transaction(
      nonce: const Nonce(0),
      sender: alice,
      receiver: alice,
      gasLimit: GasLimit(gas),
      gasPrice: const GasPrice(1_000_000_000),
      chainId: chainIdOverride ?? const ChainId('D'),
      version: const TransactionVersion(2),
      data: Uint8List(0),
      relayer: relayerOverride ?? relayer,
      signature: Signature('ab' * 64),
    );
  }

  group('RelayedTransactionsFactory', () {
    test('wraps inner transactions with totalized gas', () {
      final inner1 = signedInner(gas: 50_000);
      final inner2 = signedInner(gas: 80_000);

      final outer = factory.createRelayedTransaction(
        relayerAddress: relayer,
        relayerNonce: const Nonce(42),
        innerTransactions: <Transaction>[inner1, inner2],
      );

      expect(outer.sender, relayer);
      expect(outer.receiver, relayer);
      expect(outer.nonce.value, 42);
      expect(outer.gasLimit.value, 50_000 + 80_000 + 50_000 * 2);
      expect(outer.innerTransactions.length, 2);
      expect(outer.data, isEmpty);
    });

    test('rejects empty inner list', () {
      expect(
        () => factory.createRelayedTransaction(
          relayerAddress: relayer,
          relayerNonce: const Nonce(0),
          innerTransactions: const <Transaction>[],
        ),
        throwsArgumentError,
      );
    });

    test('rejects unsigned inner', () {
      final unsigned = Transaction(
        nonce: const Nonce(0),
        sender: alice,
        receiver: alice,
        gasLimit: const GasLimit(50_000),
        gasPrice: const GasPrice(1_000_000_000),
        chainId: const ChainId('D'),
        version: const TransactionVersion(2),
        data: Uint8List(0),
        relayer: relayer,
      );

      expect(
        () => factory.createRelayedTransaction(
          relayerAddress: relayer,
          relayerNonce: const Nonce(0),
          innerTransactions: <Transaction>[unsigned],
        ),
        throwsArgumentError,
      );
    });

    test('rejects inner whose relayer does not match', () {
      final bob = Address.fromBech32(
        'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
      );

      expect(
        () => factory.createRelayedTransaction(
          relayerAddress: relayer,
          relayerNonce: const Nonce(0),
          innerTransactions: <Transaction>[signedInner(relayerOverride: bob)],
        ),
        throwsArgumentError,
      );
    });

    test('rejects inner with mismatching chainID', () {
      expect(
        () => factory.createRelayedTransaction(
          relayerAddress: relayer,
          relayerNonce: const Nonce(0),
          innerTransactions: <Transaction>[
            signedInner(chainIdOverride: const ChainId('1')),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}
