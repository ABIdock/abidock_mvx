import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  final factory = SmartContractTransactionsFactory(
    const SmartContractTransactionsConfig(chainId: ChainId('D')),
  );
  final sender = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  final contract = Address.fromBech32(
    'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
  );

  group('SmartContractTransactionsFactory', () {
    test('deploy targets zero address with deployer HRP', () {
      final tx = factory.createTransactionForDeploy(
        sender: sender,
        bytecode: Uint8List.fromList(<int>[0xde, 0xad, 0xbe, 0xef]),
        gasLimit: const GasLimit(30_000_000),
      );

      expect(tx.receiver, Address.zero(hrp: sender.hrp));
      expect(tx.value.value, BigInt.zero);
      expect(tx.version.value, 2);

      final data = utf8.decode(tx.data);
      expect(data, startsWith('deadbeef@0500@'));
      expect(data, endsWith('0506'));
    });

    test('deploy passes through custom metadata and constructor args', () {
      final tx = factory.createTransactionForDeploy(
        sender: sender,
        bytecode: Uint8List.fromList(<int>[0x00]),
        gasLimit: const GasLimit(30_000_000),
        codeMetadata: Uint8List.fromList(<int>[0x01, 0x02]),
        arguments: <Uint8List>[
          Uint8List.fromList(<int>[0xaa]),
          Uint8List.fromList(<int>[0xbb, 0xcc]),
        ],
      );

      expect(utf8.decode(tx.data), '00@0500@0102@aa@bbcc');
    });

    test('upgrade uses upgradeContract function prefix', () {
      final tx = factory.createTransactionForUpgrade(
        sender: sender,
        contract: contract,
        bytecode: Uint8List.fromList(<int>[0xab, 0xcd]),
        gasLimit: const GasLimit(30_000_000),
      );

      expect(tx.receiver, contract);
      expect(utf8.decode(tx.data), 'upgradeContract@abcd@0506');
    });

    test('change owner encodes new owner hex', () {
      final newOwner = Address.fromBech32(
        'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
      );
      final tx = factory.createTransactionForChangeOwnerAddress(
        sender: sender,
        contract: contract,
        newOwner: newOwner,
      );

      expect(tx.receiver, contract);
      final data = utf8.decode(tx.data);
      expect(data, startsWith('ChangeOwnerAddress@'));
      expect(data.split('@')[1], newOwner.hex);
      expect(tx.gasLimit.value, greaterThan(6_000_000));
    });

    test('claim developer rewards produces constant data', () {
      final tx = factory.createTransactionForClaimDeveloperRewards(
        sender: sender,
        contract: contract,
      );

      expect(utf8.decode(tx.data), 'ClaimDeveloperRewards');
      expect(tx.receiver, contract);
      expect(tx.value.value, BigInt.zero);
    });
  });
}
