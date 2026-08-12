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

    test('guarded and plain transactions at identical gasLimit yield identical '
        'fees (C-4: no moveBalanceGas inflation)', () {
      final guarded = computer
          .applyGuardian(baseTx(), guardian)
          .copyWith(newGasLimit: const GasLimit(200_000));
      final plain = baseTx().copyWith(newGasLimit: const GasLimit(200_000));

      final guardedFee = computer.computeTransactionFee(guarded, config);
      final plainFee = computer.computeTransactionFee(plain, config);

      expect(
        guardedFee,
        equals(plainFee),
        reason:
            'Extra guardian gas must inflate transaction.gasLimit at the '
            'controller layer, NOT moveBalanceGas inside the fee computer.',
      );
    });

    test('plain transaction fee matches base moveBalance + processing', () {
      final tx = baseTx().copyWith(newGasLimit: const GasLimit(200_000));

      final BigInt fee = computer.computeTransactionFee(tx, config);

      final BigInt gasPrice = tx.gasPrice.toBigInt;
      final BigInt moveBalanceGas = config.minGasLimit.toBigInt;
      final BigInt feeForMove = moveBalanceGas * gasPrice;
      final BigInt processingGas = tx.gasLimit.toBigInt - moveBalanceGas;
      final int numerator = (config.gasPriceModifier.value * 10000).round();
      final BigInt feeForProcessing =
          processingGas *
          gasPrice *
          BigInt.from(numerator) ~/
          BigInt.from(10000);

      expect(fee, equals(feeForMove + feeForProcessing));
    });

    test('relayed v3 transaction fee equals plain fee at same gasLimit', () {
      final tx = baseTx(
        relayerAddr: sender,
      ).copyWith(newGasLimit: const GasLimit(200_000));
      final plain = baseTx().copyWith(newGasLimit: const GasLimit(200_000));

      expect(
        computer.computeTransactionFee(tx, config),
        equals(computer.computeTransactionFee(plain, config)),
        reason:
            'Relayed-v3 extras live in transaction.gasLimit (controller), '
            'not in moveBalanceGas.',
      );
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
    test('a relayer does not change the bytes the sender signs', () {
      final relayed = baseTx().copyWith(newRelayer: sender);

      final json = computer.toPlainObject(relayed);

      expect(json['relayer'], sender.bech32);
      expect(
        utf8.decode(computer.computeBytesForSigning(relayed)),
        isNot(utf8.decode(computer.computeBytesForSigning(baseTx()))),
      );
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
