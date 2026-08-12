/// Shared gas-limit resolution for transaction factories.
///
/// Provides a single hook factory classes can use to consult an optional
/// [IGasLimitEstimator] when the caller did not supply an explicit
/// gas-limit override.
import 'package:meta/meta.dart';

import '../controllers/base_controller.dart' show IGasLimitEstimator;
import '../gas_models/gas_limit.dart';
import '../transaction.dart';

/// Base factory helper exposing gas-limit resolution with an optional
/// estimator.
///
/// Concrete factories can extend this class to gain the [setGasLimit]
/// helper. Existing factories continue to work unchanged because the
/// estimator field is optional and the helper falls back to the supplied
/// transaction's gas-limit when no estimator is wired.
///
/// #### Example
/// ```dart
/// final factory = MyFactory(config, estimator: estimator);
/// final tx = factory.build(...);
/// final adjusted = await factory.setGasLimit(tx);
/// ```
@immutable
abstract class BaseFactory {
  /// Creates a base factory with an optional gas-limit estimator.
  ///
  /// #### Parameters
  /// - `gasLimitEstimator` - Optional [IGasLimitEstimator]
  const BaseFactory({this.gasLimitEstimator});

  /// Optional gas-limit estimator.
  final IGasLimitEstimator? gasLimitEstimator;

  /// Resolves the final gas-limit for [transaction].
  ///
  /// When [explicitGasLimit] is non-null it wins. Otherwise, when
  /// [gasLimitEstimator] is wired and [autoEstimate] is `true`, the
  /// estimator is consulted. As a last resort the transaction's own
  /// gas-limit is preserved.
  ///
  /// #### Parameters
  /// - `transaction` - Transaction to (potentially) re-gas
  /// - `explicitGasLimit` - Optional caller-supplied override
  /// - `autoEstimate` - Whether to consult the estimator (default `true`)
  ///
  /// #### Returns
  /// A [Transaction] with the resolved gas-limit applied.
  ///
  /// #### Example
  /// ```dart
  /// final adjusted = await factory.setGasLimit(
  ///   tx,
  ///   explicitGasLimit: const GasLimit(60000000),
  /// );
  /// ```
  Future<Transaction> setGasLimit(
    Transaction transaction, {
    GasLimit? explicitGasLimit,
    bool autoEstimate = true,
  }) async {
    if (explicitGasLimit != null) {
      return transaction.copyWith(newGasLimit: explicitGasLimit);
    }
    if (autoEstimate && gasLimitEstimator != null) {
      try {
        final int estimated = await gasLimitEstimator!.estimateGasLimit(
          transaction: transaction,
        );
        return transaction.copyWith(newGasLimit: GasLimit(estimated));
      } catch (_) {
        return transaction;
      }
    }
    return transaction;
  }
}
