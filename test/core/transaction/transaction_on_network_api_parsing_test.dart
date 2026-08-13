/// Parsing tests for [TransactionOnNetwork.fromApiResponse] against payloads
/// shaped exactly like `GET /transactions/:txHash` on the public API.
///
/// Payload strings are asserted as literals (decoded base64, bech32 addresses,
/// exact version strings) rather than against the constants the parser itself
/// consumes.
import 'dart:convert';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

/// Sender of the fixture transaction.
const String sender =
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th';

/// Receiving contract of the fixture transaction.
const String contract =
    'erd1qqqqqqqqqqqqqpgq6wegs2xkypfpync8mn2sa5cmpqjlvrhwz5nqgepyg8';

/// Relayer used by the relayed-transaction fixtures.
const String relayer =
    'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8';

/// Base64 of the literal payload `@6f6b@0de0b6b3a7640000`.
const String okScrDataBase64 = 'QDZmNmJAMGRlMGI2YjNhNzY0MDAwMA==';

/// Base64 of the literal payload
/// `ESDTTransfer@5745474c442d626434643739@0de0b6b3a7640000`.
const String transferScrDataBase64 =
    'RVNEVFRyYW5zZmVyQDU3NDU0NzRjNDQyZDYyNjQzNDY0MzczOUAwZGUwYjZiM2E3NjQwMDAw';

/// Builds the fixture body, letting each test override or add keys.
Map<String, dynamic> apiTransaction([Map<String, dynamic>? extra]) {
  final Map<String, dynamic> body = <String, dynamic>{
    'txHash':
        '4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e',
    'status': 'success',
    'sender': sender,
    'receiver': contract,
    'value': '0',
    'nonce': 42,
    'gasLimit': 60000000,
    'gasPrice': 1000000000,
    'chainID': 'D',
  };
  if (extra != null) body.addAll(extra);
  return body;
}

void main() {
  group('TransactionOnNetwork.fromApiResponse smart contract results', () {
    test('parses SCRs delivered under the API "results" key', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromApiResponse(
        apiTransaction(<String, dynamic>{
          'results': <dynamic>[
            <String, dynamic>{
              'hash': 'c0ffee11223344556677889900aabbccddeeff00112233445566778899aabbcc',
              'nonce': 43,
              'value': '0',
              'sender': contract,
              'receiver': sender,
              'data': okScrDataBase64,
              'prevTxHash': '4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e',
              'originalTxHash': '4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e',
              'callType': '0',
            },
            <String, dynamic>{
              'hash': 'deadbeef1122334455667788990011223344556677889900aabbccddeeff0011',
              'nonce': 0,
              'value': '0',
              'sender': contract,
              'receiver': sender,
              'data': transferScrDataBase64,
              'callType': '0',
            },
          ],
        }),
      );

      expect(tx.smartContractResults, isNotNull);
      expect(tx.smartContractResults!.length, equals(2));

      final SmartContractResult first = tx.smartContractResults!.first;
      expect(utf8.decode(first.data), equals('@6f6b@0de0b6b3a7640000'));
      expect(first.returnCode.code, equals('ok'));
      expect(
        first.returnData.single,
        equals(<int>[0x0d, 0xe0, 0xb6, 0xb3, 0xa7, 0x64, 0x00, 0x00]),
      );
      expect(
        first.hash,
        equals(
          'c0ffee11223344556677889900aabbccddeeff00112233445566778899aabbcc',
        ),
      );
      expect(
        first.receiver.bech32,
        equals(
          'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
        ),
      );
      expect(
        first.sender.bech32,
        equals(
          'erd1qqqqqqqqqqqqqpgq6wegs2xkypfpync8mn2sa5cmpqjlvrhwz5nqgepyg8',
        ),
      );
      expect(first.nonce, equals(43));

      final SmartContractResult second = tx.smartContractResults![1];
      expect(
        utf8.decode(second.data),
        equals('ESDTTransfer@5745474c442d626434643739@0de0b6b3a7640000'),
      );
    });

    test('still tolerates the legacy "smartContractResults" key', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromApiResponse(
        apiTransaction(<String, dynamic>{
          'smartContractResults': <dynamic>[
            <String, dynamic>{
              'hash': 'c0ffee11223344556677889900aabbccddeeff00112233445566778899aabbcc',
              'sender': contract,
              'receiver': sender,
              'data': okScrDataBase64,
            },
          ],
        }),
      );

      expect(tx.smartContractResults!.length, equals(1));
      expect(
        utf8.decode(tx.smartContractResults!.single.data),
        equals('@6f6b@0de0b6b3a7640000'),
      );
    });

    test('yields null when the response carries no results', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromApiResponse(
        apiTransaction(),
      );

      expect(tx.smartContractResults, isNull);
    });
  });

  group('TransactionOnNetwork.fromApiResponse relayed version', () {
    test('parses the relayed-v3 string without throwing', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromApiResponse(
        apiTransaction(<String, dynamic>{
          'isRelayed': true,
          'relayer': relayer,
          'relayedVersion': 'v3',
        }),
      );

      expect(tx.relayedVersion, equals('v3'));
      expect(tx.isRelayed, isTrue);
      expect(
        tx.relayer,
        equals(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
      );
    });

    test('parses the relayed-v1 string', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromApiResponse(
        apiTransaction(<String, dynamic>{
          'isRelayed': true,
          'relayedVersion': 'v1',
        }),
      );

      expect(tx.relayedVersion, equals('v1'));
    });

    test('parses the relayed-v2 string', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromApiResponse(
        apiTransaction(<String, dynamic>{
          'isRelayed': true,
          'relayedVersion': 'v2',
        }),
      );

      expect(tx.relayedVersion, equals('v2'));
    });

    test('leaves relayedVersion null for a non-relayed transaction', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromApiResponse(
        apiTransaction(),
      );

      expect(tx.relayedVersion, isNull);
    });

    test('absorbs a numeric relayedVersion as its string form', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromApiResponse(
        apiTransaction(<String, dynamic>{'relayedVersion': 2}),
      );

      expect(tx.relayedVersion, equals('2'));
    });
  });

  group('TransactionOnNetwork.fromProxyResponse relayed version', () {
    test('keeps reading gateway SCRs under smartContractResults', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromProxyResponse(
        <String, dynamic>{
          'status': 'success',
          'sender': sender,
          'receiver': contract,
          'smartContractResults': <dynamic>[
            <String, dynamic>{
              'hash': 'c0ffee11223344556677889900aabbccddeeff00112233445566778899aabbcc',
              'sender': contract,
              'receiver': sender,
              'data': '@6f6b@0de0b6b3a7640000',
            },
          ],
        },
      );

      expect(tx.smartContractResults!.length, equals(1));
      expect(
        utf8.decode(tx.smartContractResults!.single.data),
        equals('@6f6b@0de0b6b3a7640000'),
      );
      expect(tx.smartContractResults!.single.returnCode.code, equals('ok'));
      expect(tx.relayedVersion, isNull);
    });

    test('accepts a string relayedVersion on the gateway path too', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromProxyResponse(
        <String, dynamic>{
          'status': 'success',
          'sender': sender,
          'receiver': contract,
          'relayedVersion': 'v3',
        },
      );

      expect(tx.relayedVersion, equals('v3'));
    });
  });

  group('TransactionOnNetwork.copyWith relayed version', () {
    test('carries the string version through copyWith', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromApiResponse(
        apiTransaction(<String, dynamic>{'relayedVersion': 'v1'}),
      );

      expect(tx.copyWith().relayedVersion, equals('v1'));
      expect(tx.copyWith(relayedVersion: 'v3').relayedVersion, equals('v3'));
    });
  });
}
