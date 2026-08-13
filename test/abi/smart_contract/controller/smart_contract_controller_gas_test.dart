import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

import '../../../fixtures/test_fixtures.dart';

class _RecordingEstimator implements IGasLimitEstimator {
  int calls = 0;
  int? observedGasLimit;

  @override
  Future<int> estimateGasLimit({required Transaction transaction}) async {
    calls++;
    observedGasLimit = transaction.gasLimit.value;
    return 7777777;
  }
}

class _FailingEstimator implements IGasLimitEstimator {
  int calls = 0;

  @override
  Future<int> estimateGasLimit({required Transaction transaction}) async {
    calls++;
    throw StateError('estimation unavailable');
  }
}

class _OfflineProvider implements NetworkProvider {
  @override
  ChainId get chainId => const ChainId.devnet();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late IAccount alice;
  late Address guardian;
  late Address relayer;
  late Address contract;

  setUpAll(() async {
    alice = await createAliceAccount();
    guardian = Address.fromBech32(
      'erd1k2s324ww2g0yj38qn2ch2jwctdy8mnfxep94q9arncc6xecg3xaq6mjse8',
    );
    relayer = Address.fromBech32(
      'erd1spyavw0956vq68xj8y4tenjpq2wd5a9p2c6j8gsz7ztyrnpxrruqzu66jx',
    );
    contract = Address.fromBech32(
      'erd1qqqqqqqqqqqqqpgq3ytm9m8dpeud35v3us20vsafp77smqghd8ss4jtm0q',
    );
  });

  SmartContractController buildController({IGasLimitEstimator? estimator}) {
    return SmartContractController.withoutAbi(
      contractAddress: contract,
      networkProvider: _OfflineProvider(),
      gasLimitEstimator: estimator,
    );
  }

  group('guardian and relayer allowances on contract calls', () {
    test('a guarded call is funded beyond its execution budget', () async {
      final SmartContractController controller = buildController();

      final Transaction tx = await controller.callRaw(
        account: alice,
        nonce: const Nonce(7),
        endpointName: 'ping',
        arguments: <dynamic>[
          Uint8List.fromList(<int>[1]),
        ],
        options: BaseControllerInput(
          gasLimit: const GasLimit(10000000),
          guardian: guardian,
        ),
      );

      expect(tx.gasLimit.value, equals(10050000));
      expect(tx.guardian, equals(guardian));
    });

    test('a relayed call is funded beyond its execution budget', () async {
      final SmartContractController controller = buildController();

      final Transaction tx = await controller.callRaw(
        account: alice,
        nonce: const Nonce(7),
        endpointName: 'ping',
        options: BaseControllerInput(
          gasLimit: const GasLimit(10000000),
          relayer: relayer,
        ),
      );

      expect(tx.gasLimit.value, equals(10050000));
      expect(tx.relayer, equals(relayer));
      expect(tx.version.value, equals(2));
    });

    test('a guarded and relayed call receives both allowances', () async {
      final SmartContractController controller = buildController();

      final Transaction tx = await controller.callRaw(
        account: alice,
        nonce: const Nonce(7),
        endpointName: 'ping',
        options: BaseControllerInput(
          gasLimit: const GasLimit(10000000),
          guardian: guardian,
          relayer: relayer,
        ),
      );

      expect(tx.gasLimit.value, equals(10100000));
    });

    test('a plain call keeps exactly the requested gas limit', () async {
      final SmartContractController controller = buildController();

      final Transaction tx = await controller.callRaw(
        account: alice,
        nonce: const Nonce(7),
        endpointName: 'ping',
        options: const BaseControllerInput(gasLimit: GasLimit(10000000)),
      );

      expect(tx.gasLimit.value, equals(10000000));
    });
  });

  group('gas limit estimation on contract calls', () {
    test('the estimator is consulted when no gas limit is pinned', () async {
      final _RecordingEstimator estimator = _RecordingEstimator();
      final SmartContractController controller = buildController(
        estimator: estimator,
      );

      final Transaction tx = await controller.callRaw(
        account: alice,
        nonce: const Nonce(7),
        endpointName: 'ping',
        arguments: <dynamic>[
          Uint8List.fromList(<int>[1]),
        ],
        options: const BaseControllerInput(),
      );

      expect(estimator.calls, equals(1));
      expect(tx.gasLimit.value, equals(7777777));
    });

    test('an estimated guarded call also carries the allowance', () async {
      final _RecordingEstimator estimator = _RecordingEstimator();
      final SmartContractController controller = buildController(
        estimator: estimator,
      );

      final Transaction tx = await controller.callRaw(
        account: alice,
        nonce: const Nonce(7),
        endpointName: 'ping',
        options: BaseControllerInput(guardian: guardian),
      );

      expect(estimator.calls, equals(1));
      expect(tx.gasLimit.value, equals(7827777));
    });

    test('an un-pinned call is drafted with its payload cost', () async {
      final _FailingEstimator estimator = _FailingEstimator();
      final SmartContractController controller = buildController(
        estimator: estimator,
      );

      final Transaction tx = await controller.callRaw(
        account: alice,
        nonce: const Nonce(7),
        endpointName: 'ping',
        arguments: <dynamic>[
          Uint8List.fromList(<int>[1]),
        ],
        options: const BaseControllerInput(),
      );

      expect(estimator.calls, equals(1));
      expect(tx.data, equals(Uint8List.fromList('ping@01'.codeUnits)));
      expect(tx.gasLimit.value, equals(60500));
    });

    test('a pinned gas limit is never handed to the estimator', () async {
      final _RecordingEstimator estimator = _RecordingEstimator();
      final SmartContractController controller = buildController(
        estimator: estimator,
      );

      final Transaction tx = await controller.callRaw(
        account: alice,
        nonce: const Nonce(7),
        endpointName: 'ping',
        options: const BaseControllerInput(gasLimit: GasLimit(10000000)),
      );

      expect(estimator.calls, equals(0));
      expect(tx.gasLimit.value, equals(10000000));
    });

    test('call() consults the estimator when no gas limit is pinned', () async {
      final _RecordingEstimator estimator = _RecordingEstimator();
      final SmartContractController controller = SmartContractController(
        contractAddress: contract,
        networkProvider: _OfflineProvider(),
        abi: SmartContractAbi.fromJson(mockPairAbiJson),
        gasLimitEstimator: estimator,
      );

      final Transaction tx = await controller.call(
        account: alice,
        nonce: const Nonce(7),
        endpointName: 'addLiquidity',
        arguments: <dynamic>[BigInt.from(1), BigInt.from(2)],
        options: BaseControllerInput(guardian: guardian),
      );

      expect(estimator.calls, equals(1));
      expect(tx.gasLimit.value, equals(7827777));
    });

    test('a missing gas limit without an estimator is rejected', () async {
      final SmartContractController controller = buildController();

      await expectLater(
        controller.callRaw(
          account: alice,
          nonce: const Nonce(7),
          endpointName: 'ping',
          options: const BaseControllerInput(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
