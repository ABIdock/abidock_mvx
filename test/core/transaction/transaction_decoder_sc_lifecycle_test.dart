import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

Transaction _tx({
  required Uint8List data,
  Address? receiver,
  Address? relayer,
  Signature? signature,
}) {
  return Transaction(
    nonce: const Nonce(0),
    sender: Address.fromBech32(
      'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
    ),
    receiver: receiver ?? Address.zero(),
    gasLimit: const GasLimit(50000),
    gasPrice: const GasPrice(1000000000),
    chainId: const ChainId('D'),
    version: const TransactionVersion(2),
    data: data,
    relayer: relayer,
    signature: signature ?? const Signature.empty(),
  );
}

String _hex(List<int> bytes) =>
    bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  const decoder = TransactionDecoder();

  group('TransactionDecoder SC lifecycle', () {
    test('decodes contract deploy with no args', () {
      final deploy = _tx(
        data: Uint8List.fromList(utf8.encode('@deadbeef@0500@0506')),
      );
      final result = decoder.decode(deploy);
      expect(result, isA<ContractDeploy>());
      final d = result as ContractDeploy;
      expect(d.bytecode, <int>[0xde, 0xad, 0xbe, 0xef]);
      expect(d.vmType, <int>[0x05, 0x00]);
      expect(d.codeMetadata, <int>[0x05, 0x06]);
      expect(d.arguments, isEmpty);
    });

    test('decodes contract deploy with constructor args', () {
      final deploy = _tx(
        data: Uint8List.fromList(utf8.encode('@abcd@0500@0506@01@0205')),
      );
      final result = decoder.decode(deploy) as ContractDeploy;
      expect(result.arguments.length, 2);
      expect(result.arguments[0], <int>[0x01]);
      expect(result.arguments[1], <int>[0x02, 0x05]);
    });

    test('decodes upgradeContract', () {
      final upgrade = _tx(
        data: Uint8List.fromList(utf8.encode('upgradeContract@abcd@0506')),
        receiver: Address.fromBech32(
          'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
        ),
      );
      final result = decoder.decode(upgrade) as ContractUpgrade;
      expect(result.bytecode, <int>[0xab, 0xcd]);
      expect(result.codeMetadata, <int>[0x05, 0x06]);
      expect(result.arguments, isEmpty);
    });

    test('decodes ChangeOwnerAddress', () {
      final newOwner = Address.fromBech32(
        'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
      );
      final tx = _tx(
        data: Uint8List.fromList(
          utf8.encode('ChangeOwnerAddress@${_hex(newOwner.bytes)}'),
        ),
      );
      final result = decoder.decode(tx) as ContractChangeOwner;
      expect(result.newOwner.bech32, newOwner.bech32);
    });

    test('decodes ClaimDeveloperRewards', () {
      final tx = _tx(
        data: Uint8List.fromList(utf8.encode('ClaimDeveloperRewards')),
      );
      final result = decoder.decode(tx);
      expect(result, isA<ClaimDeveloperRewards>());
    });

    test('a relayed transaction decodes as the call it carries', () {
      final relayer = Address.fromBech32(
        'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
      );
      final relayed = _tx(
        data: Uint8List.fromList(utf8.encode('ClaimDeveloperRewards')),
        receiver: Address.fromBech32(
          'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
        ),
        relayer: relayer,
        signature: Signature('ab' * 64),
      );

      final result = decoder.decode(relayed);

      expect(result, isA<ClaimDeveloperRewards>());
      expect(
        result.transaction.relayer!.bech32,
        'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
      );
    });

    test('returns UnknownTransaction for truncated deploy', () {
      final tx = _tx(data: Uint8List.fromList(utf8.encode('@abcd')));
      final result = decoder.decode(tx);
      expect(result, isA<UnknownTransaction>());
    });

    test('returns UnknownTransaction for malformed ChangeOwnerAddress', () {
      final tx = _tx(
        data: Uint8List.fromList(utf8.encode('ChangeOwnerAddress@notahex')),
      );
      final result = decoder.decode(tx);
      expect(result, isA<UnknownTransaction>());
    });
  });
}
