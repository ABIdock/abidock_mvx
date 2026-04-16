import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  const computer = TransactionComputer();
  final sender = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  final receiver = Address.fromBech32(
    'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
  );
  final guardian = Address.fromBech32(
    'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
  );

  Transaction baseTx({
    int version = 2,
    int options = 0,
    Address? guardianAddr,
    Address? relayerAddr,
    String senderUsername = '',
  }) {
    return Transaction(
      nonce: const Nonce(1),
      sender: sender,
      receiver: receiver,
      gasLimit: const GasLimit(100000),
      gasPrice: const GasPrice(1_000_000_000),
      chainId: const ChainId('D'),
      version: TransactionVersion(version),
      data: Uint8List(0),
      options: options,
      senderUsername: senderUsername,
      guardian: guardianAddr,
      relayer: relayerAddr,
    );
  }

  group('TransactionComputer validation', () {
    test('rejects unknown option bits', () {
      final tx = baseTx(options: 0x80);
      expect(() => computer.computeBytesForSigning(tx), throwsArgumentError);
    });

    test('rejects options on version 1', () {
      final tx = baseTx(version: 1, options: 0x02, guardianAddr: guardian);
      expect(() => computer.computeBytesForSigning(tx), throwsArgumentError);
    });

    test('rejects guardian without flag', () {
      final tx = baseTx(guardianAddr: guardian);
      expect(() => computer.computeBytesForSigning(tx), throwsArgumentError);
    });

    test('rejects herotag longer than 32 bytes', () {
      final tx = baseTx(senderUsername: 'x' * 33);
      expect(() => computer.computeBytesForSigning(tx), throwsArgumentError);
    });

    test('accepts valid guarded transaction', () {
      final tx = baseTx(options: 0x02, guardianAddr: guardian);
      final bytes = computer.computeBytesForSigning(tx);
      expect(bytes, isNotEmpty);
    });
  });

  group('TransactionComputer.applyGuardian', () {
    test('sets version, options and guardian', () {
      final tx = baseTx(version: 1);
      final guarded = computer.applyGuardian(tx, guardian);

      expect(guarded.version.value, 2);
      expect(guarded.options & 0x02, 0x02);
      expect(guarded.guardian, guardian);
    });

    test('throws when replacing a different guardian', () {
      final other = Address.fromBech32(
        'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
      );
      final guarded = computer.applyGuardian(baseTx(), guardian);

      expect(
        () => computer.applyGuardian(guarded, other),
        throwsA(isA<StateError>()),
      );
    });

    test('is idempotent when re-guarded with the same guardian', () {
      final guarded = computer.applyGuardian(baseTx(), guardian);
      final again = computer.applyGuardian(guarded, guardian);
      expect(again.guardian, guardian);
    });
  });

  group('TransactionComputer hash signing', () {
    test('computeBytesForVerifying returns hash when hash-sign bit set', () {
      final tx = computer.applyOptionsForHashSigning(baseTx(version: 1));
      expect(computer.hasOptionsSetForHashSigning(tx), isTrue);

      final signing = computer.computeBytesForSigning(tx);
      final verifying = computer.computeBytesForVerifying(tx);
      expect(verifying.length, 32);
      expect(verifying, isNot(equals(signing)));
    });
  });

  group('TransactionComputer.computeTransactionFee', () {
    const config = DevnetNetworkConfiguration();

    test('charges minimum when gasLimit == moveGas', () {
      final tx = baseTx().copyWith(
        newGasLimit: GasLimit(config.minGasLimit.value),
      );
      final fee = computer.computeTransactionFee(tx, config);
      expect(
        fee,
        BigInt.from(config.minGasLimit.value) * BigInt.from(1_000_000_000),
      );
    });

    test('adds guardian floor for guarded transactions', () {
      final guarded = computer.applyGuardian(baseTx(), guardian);
      final withEnoughGas = guarded.copyWith(
        newGasLimit: const GasLimit(200_000),
      );

      final plain = baseTx().copyWith(newGasLimit: const GasLimit(200_000));
      final guardedFee = computer.computeTransactionFee(withEnoughGas, config);
      final plainFee = computer.computeTransactionFee(plain, config);

      expect(guardedFee > plainFee, isTrue);
    });

    test('throws when gasLimit below moveGas', () {
      final tx = baseTx().copyWith(newGasLimit: const GasLimit(1));
      expect(
        () => computer.computeTransactionFee(tx, config),
        throwsArgumentError,
      );
    });
  });

  group('TransactionComputer.toPlainObject', () {
    test('emits innerTransactions when present', () {
      final inner = baseTx().copyWith(
        newRelayer: sender,
        newSignature: Signature('cd' * 64),
      );
      final outer = baseTx().copyWith(
        newInnerTransactions: <Transaction>[inner],
      );

      final json = computer.toPlainObject(outer);
      expect(json['innerTransactions'], isA<List<dynamic>>());
      expect((json['innerTransactions'] as List<dynamic>).length, 1);
    });

    test('omits signatures when withSignature is false', () {
      final tx = baseTx().copyWith(newSignature: Signature('ab' * 64));
      final json = computer.toPlainObject(tx);
      expect(json.containsKey('signature'), isFalse);
    });

    test('base64-encodes data field', () {
      final tx = baseTx().copyWith(
        newData: Uint8List.fromList(utf8.encode('hello')),
      );
      final json = computer.toPlainObject(tx);
      expect(json['data'], base64.encode(utf8.encode('hello')));
    });
  });
}
