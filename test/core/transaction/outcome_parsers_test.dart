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

  group('Governance Outcome Parser (ArgSerializer-backed)', () {
    test('parseNewProposal decodes (proposalNonce, commitHash, '
        'startEpoch, endEpoch) through ArgSerializer.buffersToValues', () {
      const parser = GovernanceOutcomeParser();
      final contract = Address.fromBech32(
        'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u',
      );
      final baseTx = Transaction(
        sender: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        receiver: contract,
        value: Balance.zero(),
        gasLimit: const GasLimit(60000000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('D'),
        nonce: const Nonce(1),
        data: Uint8List.fromList('proposal'.codeUnits),
        version: const TransactionVersion(1),
      );

      final commitHashBytes = Uint8List.fromList('hash'.codeUnits);
      final event = TransactionEvent(
        address: contract,
        identifier: 'proposal',
        topics: [
          Uint8List.fromList(<int>[0x2a]),
          commitHashBytes,
          Uint8List.fromList(<int>[0x05]),
          Uint8List.fromList(<int>[0x09]),
        ],
        data: Uint8List(0),
        additionalData: const <Uint8List>[],
      );

      final tx = TransactionOnNetwork(
        transaction: baseTx,
        status: TransactionStatus.success,
        txHash: '00' * 32,
        logs: TransactionLogs(address: contract, events: [event]),
      );

      final outcomes = parser.parseNewProposal(tx);

      expect(outcomes, hasLength(1));
      expect(outcomes.first.proposalNonce, equals(BigInt.from(42)));
      expect(outcomes.first.commitHash, equals('hash'));
      expect(outcomes.first.startVoteEpoch, equals(BigInt.from(5)));
      expect(outcomes.first.endVoteEpoch, equals(BigInt.from(9)));
    });

    test('parseVote decodes vote string + BigUInt stake/power', () {
      const parser = GovernanceOutcomeParser();
      final contract = Address.fromBech32(
        'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u',
      );
      final baseTx = Transaction(
        sender: Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
        receiver: contract,
        value: Balance.zero(),
        gasLimit: const GasLimit(60000000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('D'),
        nonce: const Nonce(1),
        data: Uint8List.fromList('vote'.codeUnits),
        version: const TransactionVersion(1),
      );

      final event = TransactionEvent(
        address: contract,
        identifier: 'vote',
        topics: [
          Uint8List.fromList(<int>[0x07]),
          Uint8List.fromList('yes'.codeUnits),
          Uint8List.fromList(<int>[0x64]),
          Uint8List.fromList(<int>[0x32]),
        ],
        data: Uint8List(0),
        additionalData: const <Uint8List>[],
      );
      final tx = TransactionOnNetwork(
        transaction: baseTx,
        status: TransactionStatus.success,
        txHash: '00' * 32,
        logs: TransactionLogs(address: contract, events: [event]),
      );

      final outcomes = parser.parseVote(tx);

      expect(outcomes, hasLength(1));
      expect(outcomes.first.proposalNonce, equals(BigInt.from(7)));
      expect(outcomes.first.vote, equals('yes'));
      expect(outcomes.first.totalStake, equals(BigInt.from(100)));
      expect(outcomes.first.votingPower, equals(BigInt.from(50)));
    });

    group('parseDelegateVote voter address', () {
      final voterBytes = Uint8List.fromList(<int>[
        0x01, 0x39, 0x47, 0x2e, 0xff, 0x68, 0x86, 0x77, //
        0x1a, 0x98, 0x2f, 0x30, 0x83, 0xda, 0x5d, 0x42, //
        0x1f, 0x24, 0xc2, 0x91, 0x81, 0xe6, 0x38, 0x88, //
        0x22, 0x8d, 0xc8, 0x1c, 0xa6, 0x0d, 0x69, 0xe1, //
      ]);

      TransactionOnNetwork delegateVoteTx() {
        final contract = Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u',
        );
        final baseTx = Transaction(
          sender: Address.fromBech32(
            'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
          ),
          receiver: contract,
          value: Balance.zero(),
          gasLimit: const GasLimit(60000000),
          gasPrice: const GasPrice(1000000000),
          chainId: const ChainId('D'),
          nonce: const Nonce(1),
          data: Uint8List.fromList('delegateVote'.codeUnits),
          version: const TransactionVersion(1),
        );
        final event = TransactionEvent(
          address: contract,
          identifier: 'delegateVote',
          topics: <Uint8List>[
            Uint8List.fromList(<int>[0x0b]),
            Uint8List.fromList('yes'.codeUnits),
            voterBytes,
            Uint8List.fromList(<int>[0x64]),
            Uint8List.fromList(<int>[0x32]),
          ],
          data: Uint8List(0),
          additionalData: const <Uint8List>[],
        );
        return TransactionOnNetwork(
          transaction: baseTx,
          status: TransactionStatus.success,
          txHash: '00' * 32,
          logs: TransactionLogs(
            address: contract,
            events: <TransactionEvent>[event],
          ),
        );
      }

      test('defaults to the erd human-readable part', () {
        const parser = GovernanceOutcomeParser();

        final outcomes = parser.parseDelegateVote(delegateVoteTx());

        expect(outcomes, hasLength(1));
        expect(outcomes.first.proposalNonce, equals(BigInt.from(11)));
        expect(outcomes.first.vote, equals('yes'));
        expect(
          outcomes.first.voter.bech32,
          equals(
            'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
          ),
        );
        expect(outcomes.first.userStake, equals(BigInt.from(100)));
        expect(outcomes.first.votingPower, equals(BigInt.from(50)));
      });

      test('honours a non-erd human-readable part override', () {
        const parser = GovernanceOutcomeParser(addressHrp: 'test');

        final outcomes = parser.parseDelegateVote(delegateVoteTx());

        expect(outcomes, hasLength(1));
        expect(outcomes.first.voter.hrp, equals('test'));
        expect(
          outcomes.first.voter.bech32,
          equals(
            'test1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ss5hqhtr',
          ),
        );
        expect(
          outcomes.first.voter.hex,
          equals(
            '0139472eff6886771a982f3083da5d421f24c29181e63888228dc81ca60d69e1',
          ),
        );
      });
    });
  });
}
