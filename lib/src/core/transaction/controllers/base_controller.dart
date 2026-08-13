/// Base controller for transaction operations.
/// Provides common functionality for gas estimation, guardian setup, and signing.

import 'dart:typed_data';

import '../../../infrastructure/logging/logger.dart';
import '../../account/account_interface.dart';
import '../../address.dart';
import '../../nonce.dart';
import '../../signature.dart';
import '../gas_models/gas_limit.dart';
import '../gas_models/gas_price.dart';
import '../transaction.dart';
import '../transaction_constants.dart';
import '../transaction_version.dart';

/// Extra gas limit for guarded transactions (50,000 gas).
const int extraGasLimitForGuardedTransactions = 50000;

/// Extra gas limit for relayed transactions (50,000 gas).
const int extraGasLimitForRelayedTransactions = 50000;

/// Base options for controller methods with optional overrides.
///
/// Provides optional overrides for transaction creation methods.
///
/// #### Example
/// ```dart
/// final options = BaseControllerInput(
///   gasLimit: GasLimit(500000),
///   gasPrice: GasPrice(1000000000),
///   guardian: guardianAddress,  // For 2FA protection
/// );
/// ```
class BaseControllerInput {
  /// Creates base controller input with optional overrides.
  ///
  /// #### Parameters
  /// - `guardian` - Guardian address for 2FA protection
  /// - `relayer` - Relayer address for meta-transactions
  /// - `gasPrice` - Override gas price
  /// - `gasLimit` - Override gas limit
  const BaseControllerInput({
    this.guardian,
    this.relayer,
    this.gasPrice,
    this.gasLimit,
  });

  /// Guardian address for transaction co-signing (2FA).
  final Address? guardian;

  /// Relayer address for meta-transaction forwarding.
  final Address? relayer;

  /// Override gas price (null = use network default).
  final GasPrice? gasPrice;

  /// Override execution gas limit (null = auto-estimate).
  ///
  /// Guardian and relayer allowances are added on top of this value.
  final GasLimit? gasLimit;
}

/// Interface for gas limit estimation.
abstract interface class IGasLimitEstimator {
  /// Estimates gas limit for transaction.
  ///
  /// #### Parameters
  /// - `transaction` - Transaction to estimate gas for
  ///
  /// #### Returns
  /// `Future<int>` - Estimated gas limit
  Future<int> estimateGasLimit({required Transaction transaction});
}

/// Base controller providing common transaction setup functionality.
///
/// Handles guardian/relayer handling, version setting, and signing.
///
/// #### Example
/// ```dart
/// class MyController extends BaseController {
///   MyController({super.gasLimitEstimator, super.logger});
/// }
/// ```
class BaseController {
  /// Creates base controller with optional gas estimator and logger.
  ///
  /// #### Parameters
  /// - `gasLimitEstimator` - Optional gas estimator
  /// - `logger` - Optional logger
  BaseController({this.gasLimitEstimator, this.logger});

  /// Optional gas limit estimator for automatic gas calculation.
  final IGasLimitEstimator? gasLimitEstimator;

  /// Optional logger for transaction setup operations.
  final Logger? logger;

  /// Adds extra gas limit for guarded or relayed transactions.
  ///
  /// Adds [extraGasLimitForGuardedTransactions] when a guardian is set and
  /// [extraGasLimitForRelayedTransactions] when a relayer is set. Both
  /// allowances are added when the transaction is guarded and relayed.
  ///
  /// #### Parameters
  /// - `transaction` - Transaction to check for guardian/relayer
  ///
  /// #### Returns
  /// `Transaction` - Transaction with updated gas limit if guardian/relayer present
  ///
  /// #### Example
  /// ```dart
  /// final tx = draft.copyWith(newGasLimit: GasLimit(500000));
  /// final adjusted = addExtraGasLimitIfRequired(tx);
  /// // If guardian set: gasLimit = 550,000 (500,000 + 50,000)
  /// ```
  Transaction addExtraGasLimitIfRequired(Transaction transaction) {
    int newGasLimit = transaction.gasLimit.value;
    final originalGasLimit = transaction.gasLimit.value;

    if (transaction.guardian != null && !transaction.guardian!.isZero) {
      newGasLimit = newGasLimit + extraGasLimitForGuardedTransactions;
      logger?.debug(
        'Adding extra gas for guardian transaction',
        context: {
          'extraGas': extraGasLimitForGuardedTransactions,
          'originalGasLimit': originalGasLimit,
          'newGasLimit': newGasLimit,
          'reason': 'guardian',
        },
      );
    }

    if (transaction.relayer != null && !transaction.relayer!.isZero) {
      newGasLimit = newGasLimit + extraGasLimitForRelayedTransactions;
      logger?.debug(
        'Adding extra gas for relayed transaction',
        context: {
          'extraGas': extraGasLimitForRelayedTransactions,
          'originalGasLimit': originalGasLimit,
          'newGasLimit': newGasLimit,
          'reason': 'relayer',
        },
      );
    }

    return transaction.copyWith(newGasLimit: GasLimit(newGasLimit));
  }

  /// Sets up and signs transaction with common options and account signature.
  ///
  /// Handles relayer, gas estimation, version setting, and signing.
  ///
  /// #### Parameters
  /// - `transaction` - Base transaction to set up
  /// - `options` - Base controller options
  /// - `nonce` - Transaction nonce from account
  /// - `sender` - Account to sign with
  ///
  /// #### Returns
  /// `Future<Transaction>` - Fully configured and signed transaction ready for broadcast
  ///
  /// #### Example
  /// ```dart
  /// final baseTx = Transaction(
  ///   sender: account.address,
  ///   receiver: receiver,
  ///   value: Balance.fromEgld(1),
  ///   // ... other fields
  /// );
  ///
  /// final signedTx = await setupAndSignTransaction(
  ///   baseTx,
  ///   BaseControllerInput(gasLimit: GasLimit(500000)),
  ///   Nonce(5),
  ///   account,
  /// );
  ///
  /// await networkProvider.sendTransaction(signedTx);
  /// ```
  Future<Transaction> setupAndSignTransaction(
    Transaction transaction,
    BaseControllerInput options,
    Nonce nonce,
    IAccount sender,
  ) async {
    logger?.info(
      'Setting up transaction',
      context: {
        'sender': transaction.sender.bech32,
        'receiver': transaction.receiver.bech32,
        'value': transaction.value.toString(),
        'nonce': nonce.value,
        'hasGuardian': options.guardian != null,
        'hasRelayer': options.relayer != null,
        'hasGasOverride': options.gasLimit != null,
      },
    );

    try {
      Transaction tx = transaction.copyWith(
        newGuardian: options.guardian,
        newRelayer: options.relayer,
        newNonce: nonce,
      );

      tx = setVersionAndOptionsForGuardian(tx);
      tx = _setVersionForRelayer(tx);
      tx = await setTransactionGasOptions(tx, options);

      logger?.debug('Signing transaction');
      final Uint8List signatureBytes = await sender.signTransaction(tx);
      final signedTx = tx.copyWith(
        newSignature: Signature.fromBytes(signatureBytes),
      );

      logger?.info(
        'Transaction setup complete',
        context: {
          'gasLimit': signedTx.gasLimit.value,
          'gasPrice': signedTx.gasPrice.value,
          'version': signedTx.version.value,
          'options': signedTx.options,
        },
      );

      return signedTx;
    } catch (e, stackTrace) {
      logger?.error(
        'Transaction setup failed',
        error: e,
        stackTrace: stackTrace,
        context: {
          'sender': transaction.sender.bech32,
          'receiver': transaction.receiver.bech32,
        },
      );
      rethrow;
    }
  }

  /// Sets version and options for guarded transactions (guardian present).
  ///
  /// Sets version and options flag when guardian is set.
  ///
  /// #### Parameters
  /// - `transaction` - Transaction to check for guardian
  ///
  /// #### Returns
  /// `Transaction` - Transaction with version=2 and options=2 if guardian present
  ///
  /// #### Example
  /// ```dart
  /// final tx = draft.copyWith(newGuardian: guardianAddress);
  /// final upgraded = setVersionAndOptionsForGuardian(tx);
  /// // Result: version=2, options=2 (GuardedTransaction flag)
  /// ```
  Transaction setVersionAndOptionsForGuardian(Transaction transaction) {
    if (transaction.guardian == null || transaction.guardian!.isZero) {
      return transaction;
    }
    final int newOptions = transaction.options | transactionOptionsTxGuarded;
    final TransactionVersion newVersion =
        transaction.version.value < minTransactionVersionThatSupportsOptions
        ? const TransactionVersion(minTransactionVersionThatSupportsOptions)
        : transaction.version;
    logger?.debug(
      'Configuring guardian transaction',
      context: {
        'guardian': transaction.guardian!.bech32,
        'newVersion': newVersion.value,
        'newOptions': newOptions,
      },
    );
    return transaction.copyWith(newVersion: newVersion, newOptions: newOptions);
  }

  /// Raises the transaction version when a relayer is set.
  ///
  /// A relayed transaction is only accepted by the chain from version
  /// [minTransactionVersionThatSupportsOptions] onwards.
  ///
  /// #### Parameters
  /// - `transaction` - Transaction to check for a relayer
  ///
  /// #### Returns
  /// `Transaction` - Transaction whose version supports relaying
  Transaction _setVersionForRelayer(Transaction transaction) {
    if (transaction.relayer == null || transaction.relayer!.isZero) {
      return transaction;
    }
    if (transaction.version.value >= minTransactionVersionThatSupportsOptions) {
      return transaction;
    }
    logger?.debug(
      'Raising transaction version for relayed transaction',
      context: {
        'relayer': transaction.relayer!.bech32,
        'previousVersion': transaction.version.value,
        'newVersion': minTransactionVersionThatSupportsOptions,
      },
    );
    return transaction.copyWith(
      newVersion: const TransactionVersion(
        minTransactionVersionThatSupportsOptions,
      ),
    );
  }

  /// Sets transaction gas price and limit with automatic estimation.
  ///
  /// The execution budget is resolved first: an explicit `options.gasLimit`
  /// wins, otherwise [gasLimitEstimator] is consulted when available, and
  /// otherwise the transaction keeps the gas limit it was drafted with. The
  /// guardian and relayer allowances are then added on top of that budget by
  /// [addExtraGasLimitIfRequired], so a guarded or relayed transaction is
  /// always funded beyond its execution cost.
  ///
  /// #### Parameters
  /// - `transaction` - Transaction to configure gas for
  /// - `options` - Base controller options with optional gas overrides
  ///
  /// #### Returns
  /// `Transaction` - Transaction with gas price and limit configured
  ///
  /// #### Example
  /// ```dart
  /// // With overrides
  /// final tx1 = await setTransactionGasOptions(
  ///   baseTx,
  ///   BaseControllerInput(gasLimit: GasLimit(500000), gasPrice: GasPrice(1000000000)),
  /// );
  /// // Guarded: gasLimit = 550,000 (500,000 execution + 50,000 guardian)
  ///
  /// // With estimation
  /// final tx2 = await setTransactionGasOptions(
  ///   baseTx,
  ///   BaseControllerInput(),  // Will auto-estimate
  /// );
  /// ```
  Future<Transaction> setTransactionGasOptions(
    Transaction transaction,
    BaseControllerInput options,
  ) async {
    logger?.debug(
      'Configuring transaction gas',
      context: {
        'currentGasLimit': transaction.gasLimit.value,
        'currentGasPrice': transaction.gasPrice.value,
        'hasGasPriceOverride': options.gasPrice != null,
        'hasGasLimitOverride': options.gasLimit != null,
        'hasGuardian': transaction.guardian != null,
        'hasRelayer': transaction.relayer != null,
      },
    );

    Transaction tx = transaction;

    if (options.gasPrice != null) {
      logger?.debug(
        'Applying gas price override',
        context: {'gasPrice': options.gasPrice!.value.toString()},
      );
      tx = tx.copyWith(newGasPrice: options.gasPrice!);
    }

    if (options.gasLimit != null) {
      logger?.debug(
        'Applying gas limit override',
        context: {'gasLimit': options.gasLimit!.value.toString()},
      );
      tx = tx.copyWith(newGasLimit: options.gasLimit!);
    } else if (gasLimitEstimator != null) {
      try {
        logger?.debug('Estimating gas limit');
        final int estimatedLimit = await gasLimitEstimator!.estimateGasLimit(
          transaction: tx,
        );
        logger?.debug(
          'Gas limit estimated',
          context: {
            'estimated': estimatedLimit,
            'previousGasLimit': tx.gasLimit.value,
          },
        );
        tx = tx.copyWith(newGasLimit: GasLimit(estimatedLimit));
      } catch (e) {
        logger?.warning(
          'Gas estimation failed, using current gas limit',
          context: {
            'error': e.toString(),
            'fallbackGasLimit': tx.gasLimit.value,
          },
        );
      }
    } else {
      logger?.debug(
        'No gas estimator available, using current gas limit',
        context: {'gasLimit': tx.gasLimit.value},
      );
    }

    return addExtraGasLimitIfRequired(tx);
  }
}
