import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('Token & Delegation Parsers', () {
    test('parses token issuance and NFT creation', () {
      const tokenParser = TokenManagementOutcomeParser();
      final baseTx = Transaction(
        sender: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        receiver: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u',
        ),
        value: Balance.zero(),
        gasLimit: const GasLimit(60000000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('D'),
        nonce: const Nonce(1),
        data: Uint8List.fromList('issue'.codeUnits),
        version: const TransactionVersion(1),
      );

      final tokenEvent = TransactionEvent(
        address: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u',
        ),
        identifier: 'issue',
        topics: [
          Uint8List.fromList('MYTOKEN-abc123'.codeUnits),
          Uint8List(0),
          Uint8List(0),
          Uint8List(0),
        ],
        data: Uint8List(0),
        additionalData: [],
      );

      final nftEvent = TransactionEvent(
        address: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        identifier: 'ESDTNFTCreate',
        topics: [
          Uint8List.fromList('MYNFT-abc123'.codeUnits),
          Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 42]),
          Uint8List.fromList([1, 0, 0, 0, 0, 0, 0, 0]),
          Uint8List(0),
        ],
        data: Uint8List(0),
        additionalData: [],
      );

      final tokenTx = TransactionOnNetwork(
        transaction: baseTx,
        status: TransactionStatus.success,
        txHash: '00' * 32,
        blockNonce: 100,
        timestamp: 1234567890,
        logs: TransactionLogs(
          address: tokenEvent.address,
          events: [tokenEvent],
        ),
      );

      final nftTx = TransactionOnNetwork(
        transaction: baseTx,
        status: TransactionStatus.success,
        txHash: '00' * 32,
        blockNonce: 100,
        timestamp: 1234567890,
        logs: TransactionLogs(address: nftEvent.address, events: [nftEvent]),
      );

      final tokenResults = tokenParser.parseIssueFungible(tokenTx);
      expect(tokenResults, hasLength(1));
      expect(tokenResults.first.tokenIdentifier, equals('MYTOKEN-abc123'));

      final nftResults = tokenParser.parseNftCreate(nftTx);
      expect(nftResults, hasLength(1));
      expect(nftResults.first.tokenIdentifier, equals('MYNFT-abc123'));
      expect(nftResults.first.nonce, equals(BigInt.from(42)));
    });

    test('parses delegation contract creation', () {
      const delegationParser = DelegationOutcomeParser();
      final contractAddress = Address.fromBech32(
        'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u',
      );
      final baseTx = Transaction(
        sender: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        receiver: contractAddress,
        value: Balance.zero(),
        gasLimit: const GasLimit(60000000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('D'),
        nonce: const Nonce(1),
        data: Uint8List.fromList('createNewDelegationContract'.codeUnits),
        version: const TransactionVersion(1),
      );

      final event = TransactionEvent(
        address: contractAddress,
        identifier: 'SCDeploy',
        topics: [
          Uint8List.fromList(contractAddress.bytes),
          Uint8List.fromList(
            Address.fromBech32(
              'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
            ).bytes,
          ),
          Uint8List(32),
        ],
        data: Uint8List(0),
        additionalData: [],
      );

      final tx = TransactionOnNetwork(
        transaction: baseTx,
        status: TransactionStatus.success,
        txHash: '00' * 32,
        blockNonce: 100,
        timestamp: 1234567890,
        logs: TransactionLogs(address: contractAddress, events: [event]),
      );

      final results = delegationParser.parseCreateNewDelegationContract(tx);
      expect(results, hasLength(1));
      expect(results.first.contractAddress, equals(contractAddress.bech32));
    });

    test('handles error scenarios correctly', () {
      const tokenParser = TokenManagementOutcomeParser();
      final baseTx = Transaction(
        sender: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        receiver: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u',
        ),
        value: Balance.zero(),
        gasLimit: const GasLimit(60000000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('D'),
        nonce: const Nonce(1),
        data: Uint8List.fromList('issue'.codeUnits),
        version: const TransactionVersion(1),
      );

      final emptyTx = TransactionOnNetwork(
        transaction: baseTx,
        status: TransactionStatus.success,
        txHash: '00' * 32,
        blockNonce: 100,
        timestamp: 1234567890,
        logs: null,
      );
      expect(() => tokenParser.parseIssueFungible(emptyTx), throwsA(anything));

      final errorEvent = TransactionEvent(
        address: Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u',
        ),
        identifier: 'signalError',
        topics: [Uint8List.fromList('token issue failed'.codeUnits)],
        data: Uint8List(0),
        additionalData: [],
      );

      final errorTx = TransactionOnNetwork(
        transaction: baseTx,
        status: TransactionStatus.success,
        txHash: '00' * 32,
        blockNonce: 100,
        timestamp: 1234567890,
        logs: TransactionLogs(
          address: errorEvent.address,
          events: [errorEvent],
        ),
      );
      expect(
        () => tokenParser.parseIssueFungible(errorTx),
        throwsA(isA<TokenManagementParseException>()),
      );
    });
  });

  group('Smart Contract Parsers', () {
    test('parses contract deployment and execution', () {
      const parser = SmartContractOutcomeParser();
      final contractAddress = Address.fromBech32(
        'erd1qqqqqqqqqqqqqpgqhe8t5jewej70zupmh44jurgn29psua5l2jps3ntjj3',
      );
      final baseTx = Transaction(
        sender: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        receiver: contractAddress,
        value: Balance.zero(),
        gasLimit: const GasLimit(60000000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('D'),
        nonce: const Nonce(1),
        data: Uint8List.fromList('deployContract'.codeUnits),
        version: const TransactionVersion(1),
      );

      final deployEvent = TransactionEvent(
        address: contractAddress,
        identifier: 'SCDeploy',
        topics: [
          Uint8List.fromList(contractAddress.bytes),
          Uint8List.fromList(
            Address.fromBech32(
              'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
            ).bytes,
          ),
          Uint8List(32),
        ],
        data: Uint8List(0),
        additionalData: [],
      );

      final deployTx = TransactionOnNetwork(
        transaction: baseTx,
        status: TransactionStatus.success,
        txHash: '00' * 32,
        blockNonce: 100,
        timestamp: 1234567890,
        logs: TransactionLogs(address: contractAddress, events: [deployEvent]),
      );

      final deployOutcome = parser.parseDeploy(deployTx);
      expect(deployOutcome.returnCode, equals('ok'));
      expect(deployOutcome.contracts, hasLength(1));
      expect(
        deployOutcome.contracts.first.address.bech32,
        equals(contractAddress.bech32),
      );

      final executeEvent = TransactionEvent(
        address: contractAddress,
        identifier: 'writeLog',
        topics: [Uint8List.fromList(contractAddress.bytes)],
        data: Uint8List.fromList('@6f6b@2a'.codeUnits),
        additionalData: [],
      );

      final executeTx = TransactionOnNetwork(
        transaction: Transaction(
          nonce: baseTx.nonce,
          sender: baseTx.sender,
          receiver: baseTx.receiver,
          data: Uint8List.fromList('getValue'.codeUnits),
          gasLimit: baseTx.gasLimit,
          gasPrice: baseTx.gasPrice,
          chainId: baseTx.chainId,
          version: baseTx.version,
          value: baseTx.value,
        ),
        status: TransactionStatus.success,
        txHash: '00' * 32,
        blockNonce: 100,
        timestamp: 1234567890,
        logs: TransactionLogs(address: contractAddress, events: [executeEvent]),
      );

      final executeOutcome = parser.parseExecute(executeTx);
      expect(executeOutcome.values, isNotNull);
    });

    test('supports parser configuration and error detection', () {
      expect(() => const TokenManagementOutcomeParser(), returnsNormally);
      expect(() => const DelegationOutcomeParser(), returnsNormally);
      expect(() => const SmartContractOutcomeParser(), returnsNormally);

      final abi = SmartContractAbi.fromJson('{"name":"test"}');
      expect(() => SmartContractOutcomeParser(abi: abi), returnsNormally);
    });
  });
}
