/// Regression tests for the completion predicates on [TransactionOnNetwork].
///
/// `TransactionOnNetwork.isCompleted` used to return `status.isFinal`, so for
/// a `not-executable-in-block` transaction `tx.isCompleted` answered `true`
/// while `tx.status.isCompleted` answered `false`. Two getters with the same
/// name disagreeing is a trap: code that branches on `tx.isCompleted` then
/// reads logs and smart contract results that such a transaction never has.
///
/// The protocol meaning fixes the split:
///   * completed — the chain executed the transaction and produced an outcome,
///     success or failure, and nothing else;
///   * final — the status will not change again, which additionally covers
///     `not-executable-in-block` (proposed in a block, absent from that
///     block's execution result).
///
/// `isCompleted` therefore forwards to `status.isCompleted` and the terminal
/// predicate is spelled `isFinal` on both objects.
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

TransactionOnNetwork _txWithStatus(String status) {
  final Address sender = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  final Address receiver = Address.fromBech32(
    'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
  );
  final Transaction inner = Transaction(
    nonce: const Nonce(7),
    sender: sender,
    receiver: receiver,
    value: Balance.zero(),
    gasLimit: const GasLimit(50000),
    gasPrice: const GasPrice(1000000000),
    chainId: const ChainId.devnet(),
    version: const TransactionVersion(2),
    data: Uint8List(0),
  );
  return TransactionOnNetwork(
    transaction: inner,
    status: TransactionStatus(status),
    txHash: '0000000000000000000000000000000000000000000000000000000000000000',
  );
}

void main() {
  group('TransactionOnNetwork.isCompleted agrees with status.isCompleted', () {
    const List<String> wireStatuses = <String>[
      'pending',
      'received',
      'success',
      'successful',
      'executed',
      'fail',
      'failed',
      'unsuccessful',
      'invalid',
      'reward-reverted',
      'not-executable-in-block',
      'unknown',
    ];

    for (final String wire in wireStatuses) {
      test('"$wire" answers identically on both objects', () {
        final TransactionOnNetwork tx = _txWithStatus(wire);

        expect(
          tx.isCompleted,
          equals(tx.status.isCompleted),
          reason: 'isCompleted must not disagree with status.isCompleted',
        );
        expect(
          tx.isFinal,
          equals(tx.status.isFinal),
          reason: 'isFinal must not disagree with status.isFinal',
        );
        expect(
          tx.isNotExecutableInBlock,
          equals(tx.status.isNotExecutableInBlock),
          reason: 'isNotExecutableInBlock must not disagree with status',
        );
      });
    }
  });

  group('not-executable-in-block is final but not completed', () {
    final TransactionOnNetwork tx = _txWithStatus('not-executable-in-block');

    test('isCompleted is false', () {
      expect(tx.isCompleted, isFalse);
    });

    test('isFinal is true so a polling loop terminates', () {
      expect(tx.isFinal, isTrue);
    });

    test('isNotExecutableInBlock explains why there is no outcome', () {
      expect(tx.isNotExecutableInBlock, isTrue);
    });

    test('it is neither successful nor failed', () {
      expect(tx.isSuccessful, isFalse);
      expect(tx.hasFailed, isFalse);
    });

    test('parsed from an API response the answers are the same', () {
      final TransactionOnNetwork
      parsed = TransactionOnNetwork.fromApiResponse(<String, dynamic>{
        'txHash':
            '0000000000000000000000000000000000000000000000000000000000000000',
        'sender':
            'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
        'receiver':
            'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        'value': '0',
        'nonce': 7,
        'status': 'not-executable-in-block',
      });

      expect(parsed.status.status, equals('not-executable-in-block'));
      expect(parsed.isCompleted, isFalse);
      expect(parsed.isFinal, isTrue);
      expect(parsed.isNotExecutableInBlock, isTrue);
    });
  });

  group('success and failure are both completed and final', () {
    test('success', () {
      final TransactionOnNetwork tx = _txWithStatus('success');
      expect(tx.isCompleted, isTrue);
      expect(tx.isFinal, isTrue);
      expect(tx.isSuccessful, isTrue);
      expect(tx.isNotExecutableInBlock, isFalse);
    });

    test('fail', () {
      final TransactionOnNetwork tx = _txWithStatus('fail');
      expect(tx.isCompleted, isTrue);
      expect(tx.isFinal, isTrue);
      expect(tx.hasFailed, isTrue);
      expect(tx.isNotExecutableInBlock, isFalse);
    });

    test('invalid', () {
      final TransactionOnNetwork tx = _txWithStatus('invalid');
      expect(tx.isCompleted, isTrue);
      expect(tx.isFinal, isTrue);
      expect(tx.hasFailed, isTrue);
    });
  });

  group('pending states are neither completed nor final', () {
    test('pending', () {
      final TransactionOnNetwork tx = _txWithStatus('pending');
      expect(tx.isPending, isTrue);
      expect(tx.isCompleted, isFalse);
      expect(tx.isFinal, isFalse);
    });

    test('received', () {
      final TransactionOnNetwork tx = _txWithStatus('received');
      expect(tx.isPending, isTrue);
      expect(tx.isCompleted, isFalse);
      expect(tx.isFinal, isFalse);
    });
  });
}
