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

void main() {
  late IAccount alice;
  late Address guardian;
  late Address relayer;
  late Transaction draft;

  setUpAll(() async {
    alice = await createAliceAccount();
    guardian = Address.fromBech32(
      'erd1k2s324ww2g0yj38qn2ch2jwctdy8mnfxep94q9arncc6xecg3xaq6mjse8',
    );
    relayer = Address.fromBech32(
      'erd1spyavw0956vq68xj8y4tenjpq2wd5a9p2c6j8gsz7ztyrnpxrruqzu66jx',
    );
    draft = Transaction(
      nonce: const Nonce(7),
      sender: alice.address,
      receiver: alice.address,
      data: Uint8List(0),
      gasLimit: const GasLimit(1000000),
      gasPrice: const GasPrice(1000000000),
      chainId: const ChainId.devnet(),
      version: const TransactionVersion(2),
    );
  });

  group('extra gas allowances', () {
    test('allowance constants are 50,000 gas each', () {
      expect(extraGasLimitForGuardedTransactions, equals(50000));
      expect(extraGasLimitForRelayedTransactions, equals(50000));
    });

    test(
      'guardian allowance is added on top of an explicit gas limit',
      () async {
        final BaseController controller = BaseController();
        final Transaction tx = await controller.setupAndSignTransaction(
          draft,
          BaseControllerInput(
            gasLimit: const GasLimit(1000000),
            guardian: guardian,
          ),
          const Nonce(7),
          alice,
        );

        expect(tx.gasLimit.value, equals(1050000));
      },
    );

    test(
      'relayer allowance is added on top of an explicit gas limit',
      () async {
        final BaseController controller = BaseController();
        final Transaction tx = await controller.setupAndSignTransaction(
          draft,
          BaseControllerInput(
            gasLimit: const GasLimit(1000000),
            relayer: relayer,
          ),
          const Nonce(7),
          alice,
        );

        expect(tx.gasLimit.value, equals(1050000));
      },
    );

    test('guardian and relayer allowances stack', () async {
      final BaseController controller = BaseController();
      final Transaction tx = await controller.setupAndSignTransaction(
        draft,
        BaseControllerInput(
          gasLimit: const GasLimit(1000000),
          guardian: guardian,
          relayer: relayer,
        ),
        const Nonce(7),
        alice,
      );

      expect(tx.gasLimit.value, equals(1100000));
    });

    test('no allowance is added without guardian or relayer', () async {
      final BaseController controller = BaseController();
      final Transaction tx = await controller.setupAndSignTransaction(
        draft,
        const BaseControllerInput(gasLimit: GasLimit(1000000)),
        const Nonce(7),
        alice,
      );

      expect(tx.gasLimit.value, equals(1000000));
    });
  });

  group('gas limit estimation', () {
    test(
      'an explicit gas limit pins the budget and skips the estimator',
      () async {
        final _RecordingEstimator estimator = _RecordingEstimator();
        final BaseController controller = BaseController(
          gasLimitEstimator: estimator,
        );

        final Transaction tx = await controller.setupAndSignTransaction(
          draft,
          const BaseControllerInput(gasLimit: GasLimit(1000000)),
          const Nonce(7),
          alice,
        );

        expect(estimator.calls, equals(0));
        expect(tx.gasLimit.value, equals(1000000));
      },
    );

    test(
      'the estimator is consulted when the caller did not pin the gas',
      () async {
        final _RecordingEstimator estimator = _RecordingEstimator();
        final BaseController controller = BaseController(
          gasLimitEstimator: estimator,
        );

        final Transaction tx = await controller.setupAndSignTransaction(
          draft,
          const BaseControllerInput(),
          const Nonce(7),
          alice,
        );

        expect(estimator.calls, equals(1));
        expect(tx.gasLimit.value, equals(7777777));
      },
    );

    test('the guardian allowance is added on top of the estimate', () async {
      final _RecordingEstimator estimator = _RecordingEstimator();
      final BaseController controller = BaseController(
        gasLimitEstimator: estimator,
      );

      final Transaction tx = await controller.setupAndSignTransaction(
        draft,
        BaseControllerInput(guardian: guardian),
        const Nonce(7),
        alice,
      );

      expect(estimator.calls, equals(1));
      expect(estimator.observedGasLimit, equals(1000000));
      expect(tx.gasLimit.value, equals(7827777));
    });

    test('the relayer allowance is added on top of the estimate', () async {
      final _RecordingEstimator estimator = _RecordingEstimator();
      final BaseController controller = BaseController(
        gasLimitEstimator: estimator,
      );

      final Transaction tx = await controller.setupAndSignTransaction(
        draft,
        BaseControllerInput(relayer: relayer),
        const Nonce(7),
        alice,
      );

      expect(estimator.observedGasLimit, equals(1000000));
      expect(tx.gasLimit.value, equals(7827777));
    });

    test(
      'a failing estimator falls back to the draft budget plus allowance',
      () async {
        final _FailingEstimator estimator = _FailingEstimator();
        final BaseController controller = BaseController(
          gasLimitEstimator: estimator,
        );

        final Transaction tx = await controller.setupAndSignTransaction(
          draft,
          BaseControllerInput(guardian: guardian),
          const Nonce(7),
          alice,
        );

        expect(estimator.calls, equals(1));
        expect(tx.gasLimit.value, equals(1050000));
      },
    );

    test('gas price override still applies alongside the allowance', () async {
      final BaseController controller = BaseController();
      final Transaction tx = await controller.setupAndSignTransaction(
        draft,
        BaseControllerInput(
          gasLimit: const GasLimit(1000000),
          gasPrice: const GasPrice(2000000000),
          guardian: guardian,
        ),
        const Nonce(7),
        alice,
      );

      expect(tx.gasPrice.value, equals(2000000000));
      expect(tx.gasLimit.value, equals(1050000));
    });
  });

  group('relayed transaction version', () {
    test('a version 1 draft is raised to version 2 for a relayer', () async {
      final BaseController controller = BaseController();
      final Transaction v1Draft = Transaction(
        nonce: const Nonce(7),
        sender: alice.address,
        receiver: alice.address,
        data: Uint8List(0),
        gasLimit: const GasLimit(1000000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId.devnet(),
        version: const TransactionVersion(1),
      );

      final Transaction tx = await controller.setupAndSignTransaction(
        v1Draft,
        BaseControllerInput(
          gasLimit: const GasLimit(1000000),
          relayer: relayer,
        ),
        const Nonce(7),
        alice,
      );

      expect(tx.version.value, equals(2));
      expect(tx.options, equals(0));
      expect(tx.gasLimit.value, equals(1050000));
    });

    test('a version 1 draft without a relayer keeps version 1', () async {
      final BaseController controller = BaseController();
      final Transaction v1Draft = Transaction(
        nonce: const Nonce(7),
        sender: alice.address,
        receiver: alice.address,
        data: Uint8List(0),
        gasLimit: const GasLimit(1000000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId.devnet(),
        version: const TransactionVersion(1),
      );

      final Transaction tx = await controller.setupAndSignTransaction(
        v1Draft,
        const BaseControllerInput(gasLimit: GasLimit(1000000)),
        const Nonce(7),
        alice,
      );

      expect(tx.version.value, equals(1));
      expect(tx.gasLimit.value, equals(1000000));
    });
  });
}
