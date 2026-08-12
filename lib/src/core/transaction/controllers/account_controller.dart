/// Controller for account management transactions.
///
/// Provides high-level API for creating and signing account-related transactions
/// including storage operations and guardian management. Handles transaction setup,
/// gas estimation, and signing through unified interface.
///
/// #### Supported Operations
/// - Save key-value pairs to account storage
/// - Set guardian (2FA protection)
/// - Guard account (activate guardian)
/// - Unguard account (remove guardian)
import 'dart:typed_data';

import '../../account/account_interface.dart';
import '../../address.dart';
import '../../nonce.dart';
import '../chain_id.dart';
import '../factories/account_transactions_factory.dart';
import '../transaction.dart';
import 'base_controller.dart';

/// Input for saving key-value pairs to account storage.
///
/// Both keys and values are byte arrays for maximum flexibility.
///
/// #### Example
/// ```dart
/// final input = SaveKeyValueInput(
///   keyValuePairs: {
///     Uint8List.fromList(utf8.encode('username')):
///       Uint8List.fromList(utf8.encode('alice')),
///     Uint8List.fromList(utf8.encode('age')):
///       Uint8List.fromList([25]),
///   },
/// );
/// ```
class SaveKeyValueInput {
  /// Creates input with key-value pairs.
  ///
  /// #### Parameters
  /// - `keyValuePairs` - Map of byte keys to byte values
  const SaveKeyValueInput({required this.keyValuePairs});

  /// Map of keys to values (both as byte arrays).
  final Map<Uint8List, Uint8List> keyValuePairs;
}

/// Input for setting guardian (2FA protection).
///
/// Guardian must co-sign sensitive transactions when active.
///
/// #### Example
/// ```dart
/// final input = SetGuardianInput(
///   guardianAddress: Address.fromBech32('erd1qqqqqqqqqqqqqpgq...'),
///   serviceId: 'my-2fa-service',
/// );
/// ```
class SetGuardianInput {
  /// Creates guardian setup input.
  ///
  /// #### Parameters
  /// - `guardianAddress` - Address of guardian account
  /// - `serviceId` - 2FA service provider identifier
  const SetGuardianInput({
    required this.guardianAddress,
    required this.serviceId,
  });

  /// Guardian account address.
  final Address guardianAddress;

  /// 2FA service provider identifier.
  final String serviceId;
}

/// Controller for account management operations.
///
/// Extends BaseController for gas estimation and transaction setup.
///
/// #### Example
/// ```dart
/// final controller = AccountController(
///   chainId: const ChainId.devnet(),
///   gasLimitEstimator: estimator,
/// );
///
/// final tx = await controller.createTransactionForGuardingAccount(
///   account,
///   Nonce(7),
/// );
/// ```
class AccountController extends BaseController {
  /// Creates account controller with chain ID and optional gas estimator.
  ///
  /// #### Parameters
  /// - `chainId` - Network chain ID
  /// - `gasLimitEstimator` - Optional gas estimator
  ///
  /// #### Example
  /// ```dart
  /// // With gas estimation
  /// final controller = AccountController(
  ///   chainId: const ChainId.devnet(),
  ///   gasLimitEstimator: GasEstimator(networkProvider: provider),
  /// );
  ///
  /// // Without gas estimation
  /// final simpleController = AccountController(chainId: const ChainId.mainnet());
  /// ```
  AccountController({required ChainId chainId, super.gasLimitEstimator})
    : factory = AccountTransactionsFactory(
        AccountTransactionsConfig(chainId: chainId),
      );

  /// Transaction factory for creating account transactions.
  final AccountTransactionsFactory factory;

  /// Creates transaction for saving key-value pairs to account storage.
  ///
  /// #### Parameters
  /// - `sender` - Account creating the transaction
  /// - `nonce` - Transaction nonce from account
  /// - `options` - SaveKeyValueInput with key-value pairs
  /// - `baseOptions` - Optional gas limit, gas price, chain ID overrides
  ///
  /// #### Returns
  /// `Future<Transaction>` - Signed transaction ready for broadcast
  ///
  /// #### Example
  /// ```dart
  /// final input = SaveKeyValueInput(
  ///   keyValuePairs: {
  ///     Uint8List.fromList(utf8.encode('preferences')):
  ///       Uint8List.fromList(utf8.encode('{"theme":"dark"}')),
  ///   },
  /// );
  ///
  /// final tx = await controller.createTransactionForSavingKeyValue(
  ///   account,
  ///   Nonce(5),
  ///   input,
  ///   baseOptions: BaseControllerInput(
  ///     gasLimit: GasLimit(500000),
  ///   ),
  /// );
  ///
  /// await networkProvider.sendTransaction(tx);
  /// ```
  Future<Transaction> createTransactionForSavingKeyValue(
    IAccount sender,
    Nonce nonce,
    SaveKeyValueInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory.createTransactionForSavingKeyValue(
      sender: sender.address,
      keyValuePairs: options.keyValuePairs,
    );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for setting guardian (2FA protection).
  ///
  /// #### Parameters
  /// - `sender` - Account setting up guardian
  /// - `nonce` - Transaction nonce from account
  /// - `options` - SetGuardianInput with guardian address and service ID
  /// - `baseOptions` - Optional gas limit, gas price, chain ID overrides
  ///
  /// #### Returns
  /// `Future<Transaction>` - Signed transaction ready for broadcast
  ///
  /// #### Example
  /// ```dart
  /// final guardianInput = SetGuardianInput(
  ///   guardianAddress: Address.fromBech32('erd1guardian...'),
  ///   serviceId: 'twikey-2fa',
  /// );
  ///
  /// final tx = await controller.createTransactionForSettingGuardian(
  ///   account,
  ///   Nonce(6),
  ///   guardianInput,
  /// );
  ///
  /// // Guardian must be activated separately
  /// await networkProvider.sendTransaction(tx);
  /// ```
  Future<Transaction> createTransactionForSettingGuardian(
    IAccount sender,
    Nonce nonce,
    SetGuardianInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory.createTransactionForSettingGuardian(
      sender: sender.address,
      guardianAddress: options.guardianAddress,
      serviceId: options.serviceId,
    );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for guarding account (activating guardian protection).
  ///
  /// Guardian must co-sign sensitive transactions like large transfers or smart contract calls.
  ///
  /// #### Parameters
  /// - `sender` - Account to activate guardian for
  /// - `nonce` - Transaction nonce from account
  /// - `options` - Optional gas limit, gas price, chain ID overrides
  ///
  /// #### Returns
  /// `Future<Transaction>` - Signed transaction ready for broadcast
  ///
  /// #### Example
  /// ```dart
  /// // Guardian must be set first via createTransactionForSettingGuardian
  /// final tx = await controller.createTransactionForGuardingAccount(
  ///   account,
  ///   Nonce(7),
  /// );
  ///
  /// await networkProvider.sendTransaction(tx);
  /// // Account is now protected by guardian
  /// ```
  Future<Transaction> createTransactionForGuardingAccount(
    IAccount sender,
    Nonce nonce, {
    BaseControllerInput? options,
  }) async {
    final Transaction transaction = factory.createTransactionForGuardingAccount(
      sender: sender.address,
    );

    return setupAndSignTransaction(
      transaction,
      options ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for unguarding account (removing guardian protection).
  ///
  /// Guardian must co-sign this transaction to confirm removal (provided via baseOptions.guardian).
  ///
  /// #### Parameters
  /// - `sender` - Account to remove guardian from
  /// - `nonce` - Transaction nonce from account
  /// - `options` - Required: must include guardian (for co-signing)
  ///
  /// #### Returns
  /// `Future<Transaction>` - Signed transaction ready for broadcast (requires guardian signature)
  ///
  /// #### Example
  /// ```dart
  /// final tx = await controller.createTransactionForUnguardingAccount(
  ///   account,
  ///   Nonce(8),
  ///   options: BaseControllerInput(
  ///     guardian: guardianAddress,  // Guardian must co-sign
  ///   ),
  /// );
  ///
  /// // Transaction needs both account and guardian signatures
  /// // Guardian signature added by guardian service
  /// await networkProvider.sendTransaction(tx);
  /// ```
  Future<Transaction> createTransactionForUnguardingAccount(
    IAccount sender,
    Nonce nonce, {
    required BaseControllerInput options,
  }) async {
    final Transaction transaction = factory
        .createTransactionForUnguardingAccount(
          sender: sender.address,
          guardian: options.guardian,
        );

    return setupAndSignTransaction(transaction, options, nonce, sender);
  }
}
