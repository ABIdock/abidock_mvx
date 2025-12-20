/// Gas estimation service for smart contract transactions.
/// Provides automated gas limit estimation through network simulation with safety multiplier.
import 'dart:async';

import '../../../abi/core/core_types.dart';
import '../../../infrastructure/logging/logger.dart';
import '../../../infrastructure/network/network_provider.dart';
import '../../../utils/helpers.dart';
import '../controllers/base_controller.dart';
import '../transaction.dart';
import 'gas_limit.dart';

/// Estimates gas limits for smart contract transactions using network simulation.
class GasEstimator implements IGasLimitEstimator {
  /// Creates gas estimator with network provider and safety multiplier.
  ///
  /// #### Parameters
  /// - `networkProvider` - Network provider for simulation
  /// - `gasMultiplier` - Safety multiplier (default: 1.1)
  /// - `logger` - Optional logger
  GasEstimator({
    required this.networkProvider,
    this.gasMultiplier = 1.1,
    this.logger,
  });

  /// Network provider for transaction simulation.
  final NetworkProvider networkProvider;

  /// Safety multiplier applied to estimated gas (e.g., 1.1 = 10% buffer).
  final double gasMultiplier;

  /// Optional logger for tracking estimation metrics.
  final Logger? logger;

  @override
  Future<int> estimateGasLimit({required Transaction transaction}) async {
    final result = await estimate(transaction);
    return result.value;
  }

  /// Estimates gas limit for single transaction using network simulation.
  ///
  /// #### Parameters
  /// - `transaction` - Transaction to estimate gas for
  ///
  /// #### Returns
  /// `GasLimit` - Gas limit with safety multiplier applied
  ///
  /// #### Throws
  /// - `GasEstimationException` - If estimation times out
  /// - `NetworkException` - If network provider request fails
  Future<GasLimit> estimate(Transaction transaction) async {
    logger?.info(
      'Starting gas estimation for Transaction',
      context: <String, dynamic>{
        'sender': transaction.sender.bech32,
        'receiver': transaction.receiver.bech32,
        'data': transaction.data,
        'value': transaction.value.toString(),
      },
    );

    final DateTime startTime = DateTime.now();

    try {
      final Map<String, dynamic> response = await networkProvider
          .estimateTransactionCost(transaction);

      logger?.debug(
        'Gas estimation raw response',
        context: <String, dynamic>{'response': response},
      );

      final int? gasLimitRaw = optionalAs<int>(
        response['gasLimit'],
        'gasLimit',
      );
      final String? returnMessage = optionalAs<String>(
        response['returnMessage'],
        'returnMessage',
      );
      final String? status = optionalAs<String>(response['status'], 'status');

      if (gasLimitRaw == null) {
        logger?.error(
          'Gas estimation failed - no gasLimit in response',
          context: <String, dynamic>{
            'response': response,
            'returnMessage': returnMessage,
            'status': status,
            'receiver': transaction.receiver.bech32,
          },
        );

        throw GasEstimationException.fromApiResponse(
          response,
          transactionType: 'call',
          contract: transaction.receiver.bech32,
        );
      }

      final int gasLimit = gasLimitRaw;

      if (_isSimulationFailed(gasLimit, status, returnMessage)) {
        logger?.error(
          'Transaction simulation failed during gas estimation',
          context: <String, dynamic>{
            'gasLimit': gasLimit,
            'returnMessage': returnMessage,
            'status': status,
            'receiver': transaction.receiver.bech32,
          },
        );

        throw GasEstimationException.fromApiResponse(
          response,
          transactionType: 'call',
          contract: transaction.receiver.bech32,
        );
      }

      if (gasLimit > 0 && gasLimit < 50000) {
        logger?.warning(
          'Gas estimation returned unusually low value',
          context: <String, dynamic>{
            'gasLimit': gasLimit,
            'receiver': transaction.receiver.bech32,
          },
        );
      }

      final GasLimit estimatedGas = GasLimit(
        (gasLimit * gasMultiplier).floor(),
      );
      logger?.info(
        'Gas estimation successful',
        context: <String, dynamic>{
          'estimatedGas': estimatedGas,
          'rawGas': gasLimit,
          'multiplier': gasMultiplier,
          'latencyMs': DateTime.now().difference(startTime).inMilliseconds,
          'data': transaction.data,
          'status': status ?? 'unknown',
        },
      );

      return estimatedGas;
    } on TimeoutException {
      logger?.warning(
        'Gas estimation timed out',
        context: <String, dynamic>{'data': transaction.data},
      );

      throw const GasEstimationException(
        'Request timed out',
        transactionType: 'timeout',
      );
    } on GasEstimationException {
      rethrow;
    } catch (e, stackTrace) {
      logger?.error(
        'Gas estimation failed',
        error: e,
        stackTrace: stackTrace,
        context: <String, dynamic>{'data': transaction.data},
      );

      rethrow;
    }
  }

  bool _isSimulationFailed(
    int gasLimit,
    String? status,
    String? returnMessage,
  ) {
    if (status == 'fail') {
      return true;
    }

    if (gasLimit == 0 && returnMessage != null && returnMessage.isNotEmpty) {
      return true;
    }

    if (gasLimit == 0 && status != 'success') {
      return true;
    }

    return false;
  }

  /// Estimates gas limits for multiple transactions in batch.
  /// Processes transactions sequentially with network simulation.
  ///
  /// #### Parameters
  /// - `transactions` - List of transactions to estimate
  ///
  /// #### Returns
  /// `List<GasLimit>` - Gas limits in same order as input
  ///
  /// #### Throws
  /// - `GasEstimationException` - If any estimation times out
  /// - `NetworkException` - If any network request fails
  Future<List<GasLimit>> estimateBatchGasLimits(
    List<Transaction> transactions,
  ) async {
    final List<GasLimit> results = <GasLimit>[];

    for (final Transaction transaction in transactions) {
      final GasLimit gasLimit = await estimate(transaction);
      results.add(gasLimit);
    }

    return results;
  }

  /// Estimates gas limit with confidence scoring based on estimation quality.
  /// Confidence score (0.0-1.0) indicates estimation reliability.
  ///
  /// #### Parameters
  /// - `transaction` - Transaction to estimate gas for
  ///
  /// #### Returns
  /// `GasEstimationResult` - Gas limit with confidence score
  ///
  /// #### Throws
  /// - `GasEstimationException` - If estimation times out
  /// - `NetworkException` - If network provider request fails
  Future<GasEstimationResult> estimateGasLimitWithConfidence(
    Transaction transaction,
  ) async {
    final GasLimit gasLimit = await estimate(transaction);
    double confidence = 1.0;
    if (gasLimit > const GasLimit(100000000)) {
      confidence *= 0.9;
    }
    if (gasMultiplier > 1.3) {
      confidence *= 0.85;
    }

    return GasEstimationResult(gasLimit: gasLimit, confidence: confidence);
  }
}

/// Gas estimation result with confidence scoring.
/// Confidence score (0.0-1.0) indicates estimation reliability.
class GasEstimationResult {
  /// Creates gas estimation result with gas limit and confidence score.
  ///
  /// #### Parameters
  /// - `gasLimit` - Estimated gas limit
  /// - `confidence` - Confidence score (0.0 to 1.0)
  const GasEstimationResult({required this.gasLimit, required this.confidence});

  /// Estimated gas limit with safety multiplier applied.
  final GasLimit gasLimit;

  /// Confidence score (0.0-1.0) indicating estimation reliability.
  final double confidence;

  @override
  String toString() =>
      'GasEstimationResult(gasLimit: ${gasLimit.value}, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
}
