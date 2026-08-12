/// Pinning tests for numeric constants in [TransactionsFactoryConfig].
///
/// These tests exist because `additionalGasLimitForDelegationOperations` was
/// already silently regressed from `10_000_000` to the wrong `1_000_000`
/// once, and a later review paraphrased the direction inverted, so the fix
/// wave initially preserved the wrong value.
///
/// DO NOT change these constants without confirming the cost the system
/// contracts actually charge on the network, and bumping this package's major
/// version if you are intentionally diverging.
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionsFactoryConfig canonical numeric constants (pinning)', () {
    const TransactionsFactoryConfig config = TransactionsFactoryConfig(
      chainId: ChainId.devnet(),
    );

    test('additionalGasLimitForDelegationOperations is exactly 10_000_000', () {
      expect(
        config.additionalGasLimitForDelegationOperations,
        equals(10000000),
        reason:
            'The delegation system contract charges 10_000_000 gas per '
            'operation. An earlier review inverted the direction (claiming '
            'this was 10x too high) — the truth is the opposite. Delegation '
            'transactions are systematically under-gassed if this falls back '
            'to 1_000_000.',
      );
    });

    test('additionalGasLimitPerValidatorNode is exactly 6_000_000', () {
      expect(config.additionalGasLimitPerValidatorNode, equals(6000000));
    });

    test('extraGasLimitForGuardedTransactions is exactly 50_000', () {
      expect(config.extraGasLimitForGuardedTransactions, equals(50000));
    });

    test('extraGasLimitForRelayedTransactions is exactly 50_000', () {
      expect(config.extraGasLimitForRelayedTransactions, equals(50000));
    });

    test('minGasLimit is exactly 50_000', () {
      expect(config.minGasLimit, equals(50000));
    });

    test('gasLimitPerByte is exactly 1_500', () {
      expect(config.gasLimitPerByte, equals(1500));
    });
  });
}
