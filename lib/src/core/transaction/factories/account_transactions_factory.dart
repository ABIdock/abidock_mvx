/// Factory for creating account management transactions.
/// Provides low-level builders for key-value storage and guardian operations.
import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart' as convert;

import '../../core.dart';

/// Configuration for account management transactions.
/// Defines gas limits for key-value storage and guardian operations.
class AccountTransactionsConfig {
  const AccountTransactionsConfig({
    required this.chainId,
    this.minGasLimit = 50000,
    this.gasLimitPerByte = 1500,
    this.gasLimitSaveKeyValue = 100000,
    this.gasLimitPersistPerByte = 1000,
    this.gasLimitStorePerByte = 50000,
    this.gasLimitSetGuardian = 250000,
    this.gasLimitGuardAccount = 250000,
    this.gasLimitUnguardAccount = 250000,
    this.defaultGasPrice = 1000000000,
  });
  final ChainId chainId;
  final int minGasLimit;
  final int gasLimitPerByte;
  final int gasLimitSaveKeyValue;
  final int gasLimitPersistPerByte;
  final int gasLimitStorePerByte;
  final int gasLimitSetGuardian;
  final int gasLimitGuardAccount;
  final int gasLimitUnguardAccount;
  final int defaultGasPrice;
}

/// Factory for creating account management transactions.
///
/// Low-level factory for building unsigned account transactions. For high-level API
/// with automatic gas estimation and signing.
class AccountTransactionsFactory {
  AccountTransactionsFactory(this.config);
  final AccountTransactionsConfig config;

  /// Creates transaction for saving key-value pairs to account storage.
  ///
  /// Builds transaction calling `SaveKeyValue@key1_hex@value1_hex@key2_hex@value2_hex...`
  /// on sender's own account. Gas is automatically calculated based on data size.
  ///
  /// #### Parameters
  /// - `sender` - Account address that will store the data
  /// - `keyValuePairs` - Map of keys to values (both as byte arrays)
  /// - `nonce` - Optional transaction nonce
  ///
  /// #### Returns
  /// `Transaction` - Unsigned transaction with calculated gas limit
  Transaction createTransactionForSavingKeyValue({
    required Address sender,
    required Map<Uint8List, Uint8List> keyValuePairs,
    Nonce? nonce,
  }) {
    final List<String> dataParts = <String>['SaveKeyValue'];

    for (final MapEntry<Uint8List, Uint8List> entry in keyValuePairs.entries) {
      final String keyHex = convert.hex.encode(entry.key);
      final String valueHex = convert.hex.encode(entry.value);
      dataParts.add(keyHex);
      dataParts.add(valueHex);
    }

    final Uint8List data = utf8.encode(dataParts.join('@'));

    final int extraGas = _computeExtraGasForSavingKeyValue(keyValuePairs);
    final int dataMovementGas =
        config.minGasLimit + config.gasLimitPerByte * data.length;
    final int totalGas = dataMovementGas + extraGas;

    return Transaction(
      sender: sender,
      receiver: sender,
      data: data,
      nonce: nonce ?? const Nonce(0),
      gasLimit: GasLimit(totalGas),
      gasPrice: GasPrice(config.defaultGasPrice),
      value: Balance.zero(),
      chainId: config.chainId,
      version: const TransactionVersion(1),
      signature: const Signature.empty(),
    );
  }

  /// Creates transaction for setting guardian on account.
  ///
  /// Builds transaction calling `SetGuardian@guardian_hex@serviceId_hex` on sender's
  /// account. This configures a guardian address for 2FA protection but does not
  /// activate it yet (use [createTransactionForGuardingAccount] to activate).
  ///
  /// #### Parameters
  /// - `sender` - Account address that will have guardian configured
  /// - `guardianAddress` - Address of the guardian account
  /// - `serviceId` - Service identifier for the guardian provider
  /// - `nonce` - Optional transaction nonce
  ///
  /// #### Returns
  /// `Transaction` - Unsigned transaction with fixed gas limit
  Transaction createTransactionForSettingGuardian({
    required Address sender,
    required Address guardianAddress,
    required String serviceId,
    Nonce? nonce,
  }) {
    final List<String> dataParts = <String>[
      'SetGuardian',
      guardianAddress.hex,
      convert.hex.encode(utf8.encode(serviceId)),
    ];

    final Uint8List data = utf8.encode(dataParts.join('@'));

    return Transaction(
      sender: sender,
      receiver: sender,
      data: data,
      nonce: nonce ?? const Nonce(0),
      gasLimit: GasLimit(config.gasLimitSetGuardian),
      gasPrice: GasPrice(config.defaultGasPrice),
      value: Balance.zero(),
      chainId: config.chainId,
      version: const TransactionVersion(1),
      signature: const Signature.empty(),
    );
  }

  /// Creates transaction for activating guardian protection.
  ///
  /// Builds transaction calling `GuardAccount` on sender's account. This activates
  /// the previously configured guardian, requiring guardian co-signature for future
  /// transactions. Guardian must be set first via [createTransactionForSettingGuardian].
  ///
  /// #### Parameters
  /// - `sender` - Account address that will have guardian protection activated
  /// - `nonce` - Optional transaction nonce
  ///
  /// #### Returns
  /// `Transaction` - Unsigned transaction with fixed gas limit
  Transaction createTransactionForGuardingAccount({
    required Address sender,
    Nonce? nonce,
  }) {
    final List<String> dataParts = <String>['GuardAccount'];
    final Uint8List data = utf8.encode(dataParts.join('@'));

    return Transaction(
      sender: sender,
      receiver: sender,
      data: data,
      nonce: nonce ?? const Nonce(0),
      gasLimit: GasLimit(config.gasLimitGuardAccount),
      gasPrice: GasPrice(config.defaultGasPrice),
      value: Balance.zero(),
      chainId: config.chainId,
      version: const TransactionVersion(1),
      signature: const Signature.empty(),
    );
  }

  /// Creates transaction for deactivating guardian protection.
  ///
  /// Builds transaction calling `UnGuardAccount` on sender's account. This removes
  /// guardian protection, allowing transactions without guardian co-signature. If
  /// guardian is provided, the transaction is marked as guarded (options=2) requiring
  /// guardian co-signature for this final deactivation.
  ///
  /// #### Parameters
  /// - `sender` - Account address that will have guardian protection removed
  /// - `guardian` - Optional guardian address
  /// - `nonce` - Optional transaction nonce
  ///
  /// #### Returns
  /// `Transaction` - Unsigned transaction with fixed gas limit
  Transaction createTransactionForUnguardingAccount({
    required Address sender,
    Address? guardian,
    Nonce? nonce,
  }) {
    final List<String> dataParts = <String>['UnGuardAccount'];
    final Uint8List data = utf8.encode(dataParts.join('@'));

    return Transaction(
      sender: sender,
      receiver: sender,
      data: data,
      nonce: nonce ?? const Nonce(0),
      gasLimit: GasLimit(config.gasLimitUnguardAccount),
      gasPrice: GasPrice(config.defaultGasPrice),
      value: Balance.zero(),
      chainId: config.chainId,
      version: const TransactionVersion(1),
      signature: const Signature.empty(),

      guardian: guardian,
      options: guardian != null ? transactionOptionsTxGuarded : 0,
    );
  }

  /// Computes extra gas needed for storing key-value pairs.
  int _computeExtraGasForSavingKeyValue(
    Map<Uint8List, Uint8List> keyValuePairs,
  ) {
    int extraGas = 0;

    for (final MapEntry<Uint8List, Uint8List> entry in keyValuePairs.entries) {
      final int keyLength = entry.key.length;
      final int valueLength = entry.value.length;

      extraGas += config.gasLimitPersistPerByte * (keyLength + valueLength);
      extraGas += config.gasLimitStorePerByte * valueLength;
    }

    return extraGas + config.gasLimitSaveKeyValue;
  }
}
