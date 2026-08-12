/// Happy-path tests for [MultisigController] parse* methods.
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

TransactionOnNetwork _buildTx({
  required List<TransactionEvent> events,
  List<SmartContractResult>? scResults,
}) {
  final Address sender = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  final Address multisig = Address.fromBech32(
    'erd1qqqqqqqqqqqqqpgq6wegs2xkypfpync8mn2sa5cmpqjlvrhwz5nqgepyg8',
  );
  final Transaction inner = Transaction(
    nonce: const Nonce(0),
    sender: sender,
    receiver: multisig,
    value: Balance.zero(),
    gasLimit: const GasLimit(60_000_000),
    gasPrice: const GasPrice(1000000000),
    chainId: const ChainId.devnet(),
    version: const TransactionVersion(2),
    data: Uint8List(0),
  );
  return TransactionOnNetwork(
    transaction: inner,
    status: TransactionStatus.success,
    txHash: '0000000000000000000000000000000000000000000000000000000000000000',
    logs: TransactionLogs(address: multisig, events: events),
    smartContractResults: scResults,
  );
}

SmartContractResult _scrToCaller({required List<Uint8List> returnData}) {
  final Address scrSender = Address.fromBech32(
    'erd1qqqqqqqqqqqqqpgq6wegs2xkypfpync8mn2sa5cmpqjlvrhwz5nqgepyg8',
  );
  final Address caller = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  return SmartContractResult(
    hash: '0' * 64,
    nonce: 1,
    value: '0',
    sender: scrSender,
    receiver: caller,
    data: Uint8List(0),
    returnCode: ReturnCode.ok,
    returnData: returnData,
  );
}

void main() {
  final Address multisig = Address.fromBech32(
    'erd1qqqqqqqqqqqqqpgq6wegs2xkypfpync8mn2sa5cmpqjlvrhwz5nqgepyg8',
  );
  late MultisigController controller;

  setUpAll(() {
    controller = MultisigController(chainId: const ChainId.devnet());
  });

  test('parseProposeAddBoardMember decodes the action id from SCResult '
      'return data (BigUint hex 0x01)', () {
    final SmartContractResult scr = _scrToCaller(
      returnData: <Uint8List>[
        Uint8List.fromList(<int>[0x01]),
      ],
    );
    final TransactionOnNetwork tx = _buildTx(
      events: const <TransactionEvent>[],
      scResults: <SmartContractResult>[scr],
    );

    final MultisigProposalOutcome outcome = controller
        .parseProposeAddBoardMember(tx);

    expect(outcome.actionId, equals(BigInt.one));
  });

  test('parseProposeAddBoardMember decodes a multi-byte BigUint action id', () {
    final SmartContractResult scr = _scrToCaller(
      returnData: <Uint8List>[
        Uint8List.fromList(<int>[0x01, 0x2a]),
      ],
    );
    final TransactionOnNetwork tx = _buildTx(
      events: const <TransactionEvent>[],
      scResults: <SmartContractResult>[scr],
    );

    final MultisigProposalOutcome outcome = controller
        .parseProposeAddBoardMember(tx);

    expect(outcome.actionId, equals(BigInt.from(0x012a)));
  });

  test('parsePerformAction surfaces deployed contract address when SCDeploy '
      'event is present', () {
    final Uint8List deployedBytes = Uint8List(32)..[31] = 0x01;
    final TransactionEvent deploy = TransactionEvent(
      address: multisig,
      identifier: 'SCDeploy',
      topics: <Uint8List>[deployedBytes],
      data: Uint8List(0),
    );
    final SmartContractResult scr = _scrToCaller(
      returnData: <Uint8List>[
        Uint8List.fromList(<int>[0x07]),
      ],
    );
    final TransactionOnNetwork tx = _buildTx(
      events: <TransactionEvent>[deploy],
      scResults: <SmartContractResult>[scr],
    );

    final MultisigPerformActionOutcome outcome = controller.parsePerformAction(
      tx,
    );

    expect(outcome.actionId, equals(BigInt.from(7)));
    expect(outcome.deployedContractAddress?.bytes, equals(deployedBytes));
  });

  test('parseSign throws MultisigParseException on signalError', () {
    final TransactionEvent err = TransactionEvent(
      address: multisig,
      identifier: 'signalError',
      topics: <Uint8List>[
        Uint8List(0),
        Uint8List.fromList(<int>[
          0x6e,
          0x6f,
          0x74,
          0x20,
          0x66,
          0x6f,
          0x75,
          0x6e,
          0x64,
        ]),
      ],
      data: Uint8List(0),
    );
    final TransactionOnNetwork tx = _buildTx(events: <TransactionEvent>[err]);

    expect(() => controller.parseSign(tx), throwsA(isA<Exception>()));
  });
}
