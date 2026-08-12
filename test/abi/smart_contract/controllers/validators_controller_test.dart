/// Happy-path tests for [ValidatorsController] parse* methods and the
/// newly-added factory entry points.
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
  final Address staking = Address.fromBech32(
    'erd1qqqqqqqqqqqqqpgq6wegs2xkypfpync8mn2sa5cmpqjlvrhwz5nqgepyg8',
  );
  final Transaction inner = Transaction(
    nonce: const Nonce(0),
    sender: sender,
    receiver: staking,
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
    logs: TransactionLogs(address: staking, events: events),
    smartContractResults: scResults,
  );
}

SmartContractResult _scrToSender({required List<Uint8List> returnData}) {
  final Address sender = Address.fromBech32(
    'erd1qqqqqqqqqqqqqpgq6wegs2xkypfpync8mn2sa5cmpqjlvrhwz5nqgepyg8',
  );
  final Address receiver = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  return SmartContractResult(
    hash: '0' * 64,
    nonce: 1,
    value: '0',
    sender: sender,
    receiver: receiver,
    data: Uint8List(0),
    returnCode: ReturnCode.ok,
    returnData: returnData,
  );
}

void main() {
  late ValidatorsController controller;
  late ValidatorsTransactionsFactory factory;

  setUpAll(() {
    controller = ValidatorsController(chainId: const ChainId.devnet());
    factory = ValidatorsTransactionsFactory(
      const ValidatorsTransactionsConfig(chainId: ChainId.devnet()),
    );
  });

  test(
    'parseStake decodes topUp / totalStake and unprocessed keys from SCR',
    () {
      final Uint8List blsKey = Uint8List(96)..[0] = 0xab;
      final Uint8List topUp = Uint8List.fromList(<int>[0x0a]);
      final Uint8List totalStake = Uint8List.fromList(<int>[0x64]);
      final SmartContractResult scr = _scrToSender(
        returnData: <Uint8List>[blsKey, topUp, totalStake],
      );
      final TransactionOnNetwork tx = _buildTx(
        events: const <TransactionEvent>[],
        scResults: <SmartContractResult>[scr],
      );

      final StakeOutcome outcome = controller.parseStake(tx);

      expect(outcome.unprocessedPublicKeys, hasLength(1));
      expect(outcome.unprocessedPublicKeys.first, equals(blsKey));
      expect(outcome.topUp, equals(BigInt.from(10)));
      expect(outcome.totalStake, equals(BigInt.from(100)));
    },
  );

  test('parseUnstakeTokens throws on signalError with decoded message', () {
    final TransactionEvent err = TransactionEvent(
      address: Address.fromBech32(
        'erd1qqqqqqqqqqqqqpgq6wegs2xkypfpync8mn2sa5cmpqjlvrhwz5nqgepyg8',
      ),
      identifier: 'signalError',
      topics: <Uint8List>[
        Uint8List(0),
        Uint8List.fromList(<int>[0x6f, 0x6f, 0x70, 0x73]),
      ],
      data: Uint8List(0),
    );
    final TransactionOnNetwork tx = _buildTx(events: <TransactionEvent>[err]);

    expect(
      () => controller.parseUnstakeTokens(tx),
      throwsA(isA<ValidatorsParseException>()),
    );
  });

  test('parseUnstakeTokens reads (unstakedTokens, totalUnstaked) from SCR', () {
    final SmartContractResult scr = _scrToSender(
      returnData: <Uint8List>[
        Uint8List.fromList(<int>[0x05]),
        Uint8List.fromList(<int>[0x09]),
      ],
    );
    final TransactionOnNetwork tx = _buildTx(
      events: const <TransactionEvent>[],
      scResults: <SmartContractResult>[scr],
    );

    final UnstakeTokensOutcome outcome = controller.parseUnstakeTokens(tx);

    expect(outcome.unstakedTokens, equals(BigInt.from(5)));
    expect(outcome.totalUnstaked, equals(BigInt.from(9)));
  });

  test('createTransactionForToppingUp produces a "stake" data field and '
      'attaches the EGLD amount', () {
    final Address sender = Address.fromBech32(
      'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
    );
    final Transaction tx = factory.createTransactionForToppingUp(
      sender: sender,
      amount: Balance.fromString('1000000000000000000'),
    );

    expect(String.fromCharCodes(tx.data), equals('stake'));
    expect(tx.value.value, equals(BigInt.parse('1000000000000000000')));
  });

  test('createTransactionForChangingRewardsAddress encodes hex address', () {
    final Address sender = Address.fromBech32(
      'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
    );
    final Address rewards = Address.fromBech32(
      'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
    );
    final Transaction tx = factory.createTransactionForChangingRewardsAddress(
      sender: sender,
      rewardsAddress: rewards,
    );

    final List<String> parts = String.fromCharCodes(tx.data).split('@');
    expect(parts.first, equals('changeRewardAddress'));
    expect(parts[1].length, equals(64));
  });
}
