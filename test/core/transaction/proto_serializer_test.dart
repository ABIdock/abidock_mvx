import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  const serializer = ProtoSerializer();
  final sender = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  final receiver = Address.fromBech32(
    'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
  );

  Transaction tx({
    Nonce nonce = const Nonce(0),
    Balance? value,
    Address? relayer,
    Signature relayerSig = const Signature.empty(),
    List<Transaction> innerTransactions = const <Transaction>[],
  }) {
    return Transaction(
      nonce: nonce,
      sender: sender,
      receiver: receiver,
      value: value,
      gasLimit: const GasLimit(50000),
      gasPrice: const GasPrice(1_000_000_000),
      chainId: const ChainId('D'),
      version: const TransactionVersion(2),
      data: Uint8List(0),
      relayer: relayer,
      relayerSignature: relayerSig,
      innerTransactions: innerTransactions,
    );
  }

  group('ProtoSerializer', () {
    test('serializes zero value as [0x00, 0x00]', () {
      final bytes = serializer.serializeTransaction(tx());

      const valueFieldKey = (2 << 3) | 2;
      final idx = bytes.indexOf(valueFieldKey);
      expect(idx, isNonNegative);
      expect(bytes[idx + 1], 2);
      expect(bytes[idx + 2], 0x00);
      expect(bytes[idx + 3], 0x00);
    });

    test('serializes non-zero value with sign byte', () {
      final bytes = serializer.serializeTransaction(
        tx(value: Balance(BigInt.from(255))),
      );

      const valueFieldKey = (2 << 3) | 2;
      final idx = bytes.indexOf(valueFieldKey);
      expect(bytes[idx + 1], 2);
      expect(bytes[idx + 2], 0x00);
      expect(bytes[idx + 3], 0xff);
    });

    test('emits inner transactions on field 18', () {
      final relayerAddr = sender;
      final inner = tx(
        relayer: relayerAddr,
      ).copyWith(newSignature: Signature('ab' * 64));
      final outer = tx(innerTransactions: <Transaction>[inner]);

      final bytes = serializer.serializeTransaction(outer);
      const field18Key = (18 << 3) | 2;
      expect(bytes.contains(field18Key), isTrue);
    });

    test('elides guardian fields when no guardian signature', () {
      final out = serializer.serializeTransaction(tx());
      const field14Key = (14 << 3) | 2;
      const field15Key = (15 << 3) | 2;
      expect(out.contains(field14Key), isFalse);
      expect(out.contains(field15Key), isFalse);
    });

    test('produces deterministic output for the same tx', () {
      final a = serializer.serializeTransaction(tx(nonce: const Nonce(5)));
      final b = serializer.serializeTransaction(tx(nonce: const Nonce(5)));
      expect(a, orderedEquals(b));
    });
  });
}
