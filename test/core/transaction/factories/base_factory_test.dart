/// Tests for [BaseFactory.setGasLimit] — priority ordering + estimator hook.
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

class _FixedEstimator implements IGasLimitEstimator {
  const _FixedEstimator(this.estimated);
  final int estimated;

  @override
  Future<int> estimateGasLimit({required Transaction transaction}) async {
    return estimated;
  }
}

class _ThrowingEstimator implements IGasLimitEstimator {
  const _ThrowingEstimator();

  @override
  Future<int> estimateGasLimit({required Transaction transaction}) async {
    throw StateError('boom');
  }
}

class _CountingEstimator implements IGasLimitEstimator {
  _CountingEstimator();
  int calls = 0;

  @override
  Future<int> estimateGasLimit({required Transaction transaction}) async {
    calls += 1;
    return 99999;
  }
}

class _TestFactory extends BaseFactory {
  const _TestFactory({super.gasLimitEstimator});
}

Transaction _tx() => Transaction(
  nonce: const Nonce(0),
  sender: Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  ),
  receiver: Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  ),
  value: Balance.zero(),
  gasLimit: const GasLimit(50000),
  gasPrice: const GasPrice(1000000000),
  chainId: const ChainId.devnet(),
  version: const TransactionVersion(2),
  data: Uint8List(0),
);

void main() {
  group('BaseFactory.setGasLimit', () {
    test('explicit gasLimit override always wins', () async {
      final _TestFactory factory = _TestFactory(
        gasLimitEstimator: _CountingEstimator(),
      );
      final Transaction adjusted = await factory.setGasLimit(
        _tx(),
        explicitGasLimit: const GasLimit(123456),
      );
      expect(adjusted.gasLimit.value, equals(123456));
      expect((factory.gasLimitEstimator! as _CountingEstimator).calls, 0);
    });

    test('estimator is consulted when explicit override is absent', () async {
      const _TestFactory factory = _TestFactory(
        gasLimitEstimator: _FixedEstimator(70000),
      );
      final Transaction adjusted = await factory.setGasLimit(_tx());
      expect(adjusted.gasLimit.value, equals(70000));
    });

    test('estimator is skipped when autoEstimate is false', () async {
      const _TestFactory factory = _TestFactory(
        gasLimitEstimator: _FixedEstimator(70000),
      );
      final Transaction adjusted = await factory.setGasLimit(
        _tx(),
        autoEstimate: false,
      );
      expect(adjusted.gasLimit.value, equals(50000));
    });

    test('estimator throw is swallowed and original gasLimit is preserved', () {
      const _TestFactory factory = _TestFactory(
        gasLimitEstimator: _ThrowingEstimator(),
      );
      expect(
        factory.setGasLimit(_tx()).then((Transaction t) => t.gasLimit.value),
        completion(equals(50000)),
      );
    });

    test(
      'no estimator + no override returns the original transaction',
      () async {
        const _TestFactory factory = _TestFactory();
        final Transaction original = _tx();
        final Transaction adjusted = await factory.setGasLimit(original);
        expect(adjusted.gasLimit.value, equals(original.gasLimit.value));
      },
    );
  });
}
