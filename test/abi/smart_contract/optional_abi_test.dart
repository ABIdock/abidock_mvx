import 'dart:convert';
import 'dart:typed_data';
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('SmartContractCallFactory.withoutAbi', () {
    late SmartContractCallFactory factory;
    late Address sender;
    late SmartContractAddress contractAddress;

    setUp(() {
      sender = Address.fromBech32(
        'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
      );
      contractAddress = SmartContractAddress.fromBech32(
        'erd1qqqqqqqqqqqqqpgqp699jngundfqw07d8jzkepucvpzush6k3wvqyc44rx',
      );
      factory = SmartContractCallFactory.withoutAbi(
        contractAddress: contractAddress,
        chainId: const ChainId.devnet(),
      );
    });

    test('creates factory without ABI', () {
      expect(factory.hasAbi, isFalse);
    });

    test('createCall with TypedValue arguments', () {
      final tx = factory.createCall(
        sender: sender,
        nonce: const Nonce(42),
        endpointName: 'myFunction',
        arguments: [
          BigUIntValue(BigInt.from(1000)),
          TokenIdentifierValue('TOKEN-abc123'),
        ],
        gasLimit: const GasLimit(10000000),
      );

      expect(tx.sender, sender);
      expect(tx.receiver, contractAddress);
      expect(tx.nonce, const Nonce(42));
      expect(tx.gasLimit, const GasLimit(10000000));
      expect(utf8.decode(tx.data), contains('myFunction'));
    });

    test('createCall with Uint8List arguments', () {
      final tx = factory.createCall(
        sender: sender,
        nonce: const Nonce(42),
        endpointName: 'myFunction',
        arguments: [
          Uint8List.fromList([0x01, 0x02, 0x03]),
          Uint8List.fromList([0xAB, 0xCD]),
        ],
        gasLimit: const GasLimit(10000000),
      );

      expect(tx.sender, sender);
      expect(utf8.decode(tx.data), contains('myFunction'));
    });

    test('createCall with empty arguments', () {
      final tx = factory.createCall(
        sender: sender,
        nonce: const Nonce(42),
        endpointName: 'noArgsFunction',
        arguments: [],
        gasLimit: const GasLimit(10000000),
      );

      expect(utf8.decode(tx.data), 'noArgsFunction');
    });

    test('createCall throws for mixed argument types', () {
      expect(
        () => factory.createCall(
          sender: sender,
          nonce: const Nonce(42),
          endpointName: 'myFunction',
          arguments: [BigUIntValue(BigInt.from(1000)), 'invalid_native_value'],
          gasLimit: const GasLimit(10000000),
        ),
        throwsA(isA<ArgumentEncodingException>()),
      );
    });

    test('createCall throws for native values without ABI', () {
      expect(
        () => factory.createCall(
          sender: sender,
          nonce: const Nonce(42),
          endpointName: 'myFunction',
          arguments: [BigInt.from(1000)],
          gasLimit: const GasLimit(10000000),
        ),
        throwsA(isA<ArgumentEncodingException>()),
      );
    });

    test(
      'createCall throws helpful error for TokenTransferValue in arguments',
      () {
        final transfer = TokenTransferValue.fromPrimitives(
          tokenIdentifier: 'TEST-abc123',
          amount: BigInt.from(1000),
        );

        expect(
          () => factory.createCall(
            sender: sender,
            nonce: const Nonce(42),
            endpointName: 'myFunction',
            arguments: [transfer], // Wrong! Should be in tokenTransfers
            gasLimit: const GasLimit(10000000),
          ),
          throwsA(
            allOf(
              isA<ArgumentEncodingException>(),
              predicate<ArgumentEncodingException>(
                (e) =>
                    e.message.contains('TokenTransferValue') &&
                    e.message.contains('tokenTransfers'),
              ),
            ),
          ),
        );
      },
    );

    test('createCall with value transfer', () {
      final tx = factory.createCall(
        sender: sender,
        nonce: const Nonce(42),
        endpointName: 'deposit',
        arguments: [],
        gasLimit: const GasLimit(10000000),
        value: Balance.fromEgld(1),
      );

      expect(tx.value, Balance.fromEgld(1));
    });

    test('createCall with token transfers', () {
      final tx = factory.createCall(
        sender: sender,
        nonce: const Nonce(42),
        endpointName: 'swap',
        arguments: [TokenIdentifierValue('OUT-abc123')],
        tokenTransfers: [
          TokenTransferValue.fromPrimitives(
            tokenIdentifier: 'IN-abc1234',
            amount: BigInt.from(1000),
          ),
        ],
        gasLimit: const GasLimit(10000000),
      );

      expect(utf8.decode(tx.data), contains('ESDTTransfer'));
    });

    test('hasEndpoint throws without ABI', () {
      expect(() => factory.hasEndpoint('anyEndpoint'), throwsStateError);
    });

    test('getEndpoint throws without ABI', () {
      expect(() => factory.getEndpoint('anyEndpoint'), throwsStateError);
    });

    test('getMutableEndpoints throws without ABI', () {
      expect(() => factory.getMutableEndpoints(), throwsStateError);
    });

    test('abi getter throws without ABI', () {
      expect(() => factory.abi, throwsStateError);
    });
  });

  group('RawQueryResult', () {
    test('creates from return data parts', () {
      final returnDataParts = [
        Uint8List.fromList([0x01, 0x02]),
        Uint8List.fromList([0x03, 0x04, 0x05]),
      ];
      final result = RawQueryResult(
        returnDataParts: returnDataParts,
        returnCode: ReturnCode.ok,
        returnMessage: 'success',
      );

      expect(result.returnDataParts.length, 2);
      expect(result.returnDataParts[0], Uint8List.fromList([0x01, 0x02]));
      expect(result.returnDataParts[1], Uint8List.fromList([0x03, 0x04, 0x05]));
    });

    test('creates empty result', () {
      // ignore: prefer_const_constructors
      final result = RawQueryResult(
        returnDataParts: const [],
        returnCode: ReturnCode.ok,
        returnMessage: '',
      );

      expect(result.returnDataParts, isEmpty);
    });

    test('isEmpty returns true for empty result', () {
      // ignore: prefer_const_constructors
      final result = RawQueryResult(
        returnDataParts: const [],
        returnCode: ReturnCode.ok,
        returnMessage: '',
      );

      expect(result.isEmpty, isTrue);
    });

    test('isEmpty returns false for non-empty result', () {
      final result = RawQueryResult(
        returnDataParts: [
          Uint8List.fromList([0x01]),
        ],
        returnCode: ReturnCode.ok,
        returnMessage: '',
      );

      expect(result.isEmpty, isFalse);
    });

    test('length returns correct count', () {
      final result = RawQueryResult(
        returnDataParts: [
          Uint8List.fromList([0x01]),
          Uint8List.fromList([0x02]),
          Uint8List.fromList([0x03]),
        ],
        returnCode: ReturnCode.ok,
        returnMessage: '',
      );

      expect(result.length, 3);
    });

    test('first returns first element', () {
      final result = RawQueryResult(
        returnDataParts: [
          Uint8List.fromList([0x01, 0x02]),
          Uint8List.fromList([0x03, 0x04]),
        ],
        returnCode: ReturnCode.ok,
        returnMessage: '',
      );

      expect(result.first, Uint8List.fromList([0x01, 0x02]));
    });

    test('first returns null for empty result', () {
      // ignore: prefer_const_constructors
      final result = RawQueryResult(
        returnDataParts: const [],
        returnCode: ReturnCode.ok,
        returnMessage: '',
      );

      expect(result.first, isNull);
    });

    test('operator [] returns element at index', () {
      final result = RawQueryResult(
        returnDataParts: [
          Uint8List.fromList([0x01]),
          Uint8List.fromList([0x02]),
          Uint8List.fromList([0x03]),
        ],
        returnCode: ReturnCode.ok,
        returnMessage: '',
      );

      expect(result[0], Uint8List.fromList([0x01]));
      expect(result[1], Uint8List.fromList([0x02]));
      expect(result[2], Uint8List.fromList([0x03]));
    });

    test('isSuccess returns true for successful return code', () {
      // ignore: prefer_const_constructors
      final result = RawQueryResult(
        returnDataParts: const [],
        returnCode: ReturnCode.ok,
        returnMessage: '',
      );

      expect(result.isSuccess, isTrue);
    });

    test('toString returns correct format', () {
      final result = RawQueryResult(
        returnDataParts: [
          Uint8List.fromList([0x01]),
        ],
        returnCode: ReturnCode.ok,
        returnMessage: '',
      );

      expect(result.toString(), contains('RawQueryResult'));
      expect(result.toString(), contains('parts: 1'));
    });
  });
}
