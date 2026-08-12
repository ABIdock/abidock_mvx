import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('NetworkConfig parser', () {
    test('populates extraGasLimitForGuardedTransactions, gasPriceModifier, '
        'and genesisTimestamp from canonical erd_* keys', () {
      final Map<String, dynamic> payload = <String, dynamic>{
        'config': <String, dynamic>{
          'erd_chain_id': 'D',
          'erd_gas_per_data_byte': 1500,
          'erd_min_gas_limit': 50000,
          'erd_min_gas_price': 1000000000,
          'erd_min_transaction_version': 1,
          'erd_rounds_per_epoch': 14400,
          'erd_round_duration': 6000,
          'erd_top_up_factor': 0.5,
          'erd_extra_gas_limit_guarded_tx': 77777,
          'erd_gas_price_modifier': 0.0125,
          'erd_start_time': 1700000000,
        },
      };

      final NetworkConfig config = NetworkConfig.fromApiResponse(payload);

      expect(config.extraGasLimitForGuardedTransactions, 77777);
      expect(config.gasPriceModifier, closeTo(0.0125, 1e-9));
      expect(config.genesisTimestamp, BigInt.from(1700000000));
      expect(config.startTime, 1700000000);
    });

    test('uses sensible defaults when the three keys are absent', () {
      final Map<String, dynamic> payload = <String, dynamic>{
        'config': <String, dynamic>{'erd_chain_id': 'D'},
      };

      final NetworkConfig config = NetworkConfig.fromApiResponse(payload);

      expect(config.extraGasLimitForGuardedTransactions, 50000);
      expect(config.gasPriceModifier, 0.01);
      expect(config.genesisTimestamp, isNull);
    });
  });
}
