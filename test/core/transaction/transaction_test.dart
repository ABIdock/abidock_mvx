import 'dart:convert';
import 'dart:typed_data';
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('Transaction Creation', () {
    test('creates basic transactions', () {
      final egldTx = Transaction(
        nonce: const Nonce(10),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        value: Balance.fromEgld(1.5),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('D'),
        version: const TransactionVersion(1),
        data: Uint8List(0),
      );
      expect(egldTx.nonce.value, 10);
      expect(egldTx.value.value, Balance.fromEgld(1.5).value);
      expect(egldTx.gasLimit.value, 50000);
      expect(egldTx.chainId.value, 'D');
      expect(egldTx.signature.isEmpty, isTrue);

      final zeroTx = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(1),
        data: Uint8List(0),
      );
      expect(zeroTx.value.value, BigInt.zero);
    });

    test('handles transaction data and usernames', () {
      final data = Uint8List.fromList(utf8.encode('claimRewards'));
      final tx = Transaction(
        nonce: const Nonce(5),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd1qqqqqqqqqqqqqpgq6wegs2xkypfpync8mn2sa5cmpqjlvrhwz5nqgepyg8',
        ),
        gasLimit: const GasLimit(6000000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(1),
        data: data,
        senderUsername: 'alice.elrond',
        receiverUsername: 'bob.elrond',
      );
      expect(tx.data, data);
      expect(utf8.decode(tx.data), 'claimRewards');
      expect(tx.senderUsername, 'alice.elrond');
      expect(tx.receiverUsername, 'bob.elrond');
    });

    test('supports versions and options', () {
      final v1Tx = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(1),
        data: Uint8List(0),
      );
      expect(v1Tx.version.value, 1);

      final v2Tx = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(2),
        data: Uint8List(0),
        options: 0x02,
      );
      expect(v2Tx.version.value, 2);
      expect(v2Tx.options, 0x02);
    });
  });

  group('Advanced Features', () {
    test('supports guardian transactions', () {
      final guardedTx = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(2),
        data: Uint8List(0),
        guardian: Address.fromBech32(
          'erd1l453hd0gt5gzdp7czpuall8ggt2dcv5zwmfdf3sd3lguxseux2fsmsgldz',
        ),
        options: 0x02,
      );
      expect(guardedTx.guardian, isNotNull);
      expect(guardedTx.guardianSignature.isEmpty, isTrue);

      final normalTx = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(1),
        data: Uint8List(0),
      );
      expect(normalTx.guardian, isNull);
    });

    test('supports relayed transactions', () {
      final relayedTx = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(1),
        data: Uint8List(0),
        relayer: Address.fromBech32(
          'erd1l453hd0gt5gzdp7czpuall8ggt2dcv5zwmfdf3sd3lguxseux2fsmsgldz',
        ),
      );
      expect(relayedTx.relayer, isNotNull);
      expect(relayedTx.relayerSignature.isEmpty, isTrue);

      final normalTx = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(1),
        data: Uint8List(0),
      );
      expect(normalTx.relayer, isNull);
    });

    test('supports different chain IDs', () {
      final mainnetTx = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(1),
        data: Uint8List(0),
      );
      expect(mainnetTx.chainId.value, '1');

      final devnetTx = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('D'),
        version: const TransactionVersion(1),
        data: Uint8List(0),
      );
      expect(devnetTx.chainId.value, 'D');

      final testnetTx = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('T'),
        version: const TransactionVersion(1),
        data: Uint8List(0),
      );
      expect(testnetTx.chainId.value, 'T');
    });
  });

  group('TransactionComputer Fee Calculation', () {
    test('computes fee for simple transfer (move-balance only)', () {
      const computer = TransactionComputer();
      const config = MainnetNetworkConfiguration();

      final tx = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(1),
        data: Uint8List(0),
      );

      final fee = computer.computeTransactionFee(tx, config);
      expect(fee, BigInt.from(50000) * BigInt.from(1000000000));
    });

    test('computes fee with data (move-balance + data gas)', () {
      const computer = TransactionComputer();
      const config = MainnetNetworkConfiguration();

      final tx = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(65000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(1),
        data: Uint8List.fromList(utf8.encode('0123456789')), // 10 bytes
      );

      final fee = computer.computeTransactionFee(tx, config);
      expect(fee, BigInt.from(65000) * BigInt.from(1000000000));
    });

    test('computes fee with processing gas (uses gasPriceModifier)', () {
      const computer = TransactionComputer();
      const config = MainnetNetworkConfiguration();

      final tx = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd1qqqqqqqqqqqqqpgq6wegs2xkypfpync8mn2sa5cmpqjlvrhwz5nqgepyg8',
        ),
        gasLimit: const GasLimit(6000000), // Much more than move-balance
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(1),
        data: Uint8List.fromList(utf8.encode('claimRewards')), // 12 bytes
      );

      final fee = computer.computeTransactionFee(tx, config);
      final moveBalanceGas = BigInt.from(50000 + 12 * 1500);
      final processingGas = BigInt.from(6000000) - moveBalanceGas;
      final gasPrice = BigInt.from(1000000000);
      final modifiedGasPrice = BigInt.from((1000000000 * 0.01).floor());
      final expectedFee =
          moveBalanceGas * gasPrice + processingGas * modifiedGasPrice;

      expect(fee, expectedFee);
    });

    test('throws if gas limit is below minimum', () {
      const computer = TransactionComputer();
      const config = MainnetNetworkConfiguration();

      final tx = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(10000), // Below 50000 minimum
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(1),
        data: Uint8List(0),
      );

      expect(
        () => computer.computeTransactionFee(tx, config),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Transaction Equality', () {
    test('two transactions with same data are equal', () {
      final tx1 = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(1),
        data: Uint8List.fromList(utf8.encode('transfer')),
      );

      final tx2 = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(1),
        data: Uint8List.fromList(utf8.encode('transfer')),
      );

      expect(tx1, equals(tx2));
      expect(tx1.hashCode, equals(tx2.hashCode));
    });

    test('transactions with different data are not equal', () {
      final tx1 = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(1),
        data: Uint8List.fromList(utf8.encode('transfer')),
      );

      final tx2 = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(1),
        data: Uint8List.fromList(utf8.encode('stake')),
      );

      expect(tx1, isNot(equals(tx2)));
    });

    test('transactions with empty vs non-empty data are not equal', () {
      final tx1 = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(1),
        data: Uint8List(0),
      );

      final tx2 = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(1),
        data: Uint8List.fromList([1, 2, 3]),
      );

      expect(tx1, isNot(equals(tx2)));
    });

    test('identical transactions are equal', () {
      final tx = Transaction(
        nonce: const Nonce(1),
        sender: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
        receiver: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('1'),
        version: const TransactionVersion(1),
        data: Uint8List(0),
      );

      expect(tx, equals(tx));
    });
  });
}
