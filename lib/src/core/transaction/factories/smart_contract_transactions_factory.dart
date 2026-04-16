/// Factory for smart-contract lifecycle transactions: deploy, upgrade,
/// change owner, and claim developer rewards.
///
/// The call-path (invoking an existing endpoint) is handled by
/// [SmartContractCallFactory]; this factory covers the ABI-free lifecycle ops.
import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart' as convert;

import '../../address.dart';
import '../../balance.dart';
import '../../nonce.dart';
import '../chain_id.dart';
import '../gas_models/gas_limit.dart';
import '../gas_models/gas_price.dart';
import '../transaction.dart';
import '../transaction_version.dart';

/// Configuration constants for the SC lifecycle factory.
class SmartContractTransactionsConfig {
  const SmartContractTransactionsConfig({
    required this.chainId,
    this.minGasLimit = 50000,
    this.gasLimitPerByte = 1500,
    this.gasLimitClaimDeveloperRewards = 6000000,
    this.gasLimitChangeOwnerAddress = 6000000,
    this.defaultGasPrice = 1000000000,
  });

  final ChainId chainId;
  final int minGasLimit;
  final int gasLimitPerByte;
  final int gasLimitClaimDeveloperRewards;
  final int gasLimitChangeOwnerAddress;
  final int defaultGasPrice;
}

/// Builds deploy / upgrade / change-owner / claim-developer-rewards
/// transactions. Gas floors are additive over a caller-supplied processing
/// allowance; pass an explicit `gasLimit` or accept the default which covers
/// the move-balance portion only.
class SmartContractTransactionsFactory {
  SmartContractTransactionsFactory(this.config);
  final SmartContractTransactionsConfig config;

  /// Creates an unsigned contract-deploy transaction.
  ///
  /// Data-field shape: `<codeHex>@<vmTypeHex>@<metadataHex>[@<argHex>...]`.
  /// VM type defaults to `0500` (WASM).
  Transaction createTransactionForDeploy({
    required Address sender,
    required Uint8List bytecode,
    required GasLimit gasLimit,
    Uint8List? codeMetadata,
    String vmType = '0500',
    List<Uint8List> arguments = const <Uint8List>[],
    Nonce? nonce,
  }) {
    final List<String> parts = <String>[
      convert.hex.encode(bytecode),
      vmType,
      convert.hex.encode(codeMetadata ?? Uint8List.fromList(<int>[0x05, 0x06])),
      for (final Uint8List arg in arguments) convert.hex.encode(arg),
    ];
    final Uint8List data = Uint8List.fromList(utf8.encode(parts.join('@')));

    return Transaction(
      nonce: nonce ?? const Nonce(0),
      sender: sender,
      receiver: Address.zero(hrp: sender.hrp),
      gasLimit: gasLimit,
      gasPrice: GasPrice(config.defaultGasPrice),
      chainId: config.chainId,
      version: const TransactionVersion(2),
      data: data,
      value: Balance.zero(),
    );
  }

  /// Creates an unsigned contract-upgrade transaction.
  ///
  /// Data-field shape: `upgradeContract@<codeHex>@<metadataHex>[@<argHex>...]`.
  Transaction createTransactionForUpgrade({
    required Address sender,
    required Address contract,
    required Uint8List bytecode,
    required GasLimit gasLimit,
    Uint8List? codeMetadata,
    List<Uint8List> arguments = const <Uint8List>[],
    Nonce? nonce,
  }) {
    final List<String> parts = <String>[
      'upgradeContract',
      convert.hex.encode(bytecode),
      convert.hex.encode(codeMetadata ?? Uint8List.fromList(<int>[0x05, 0x06])),
      for (final Uint8List arg in arguments) convert.hex.encode(arg),
    ];
    final Uint8List data = Uint8List.fromList(utf8.encode(parts.join('@')));

    return Transaction(
      nonce: nonce ?? const Nonce(0),
      sender: sender,
      receiver: contract,
      gasLimit: gasLimit,
      gasPrice: GasPrice(config.defaultGasPrice),
      chainId: config.chainId,
      version: const TransactionVersion(2),
      data: data,
      value: Balance.zero(),
    );
  }

  /// Creates an unsigned change-owner transaction for a contract.
  ///
  /// Data-field: `ChangeOwnerAddress@<newOwnerHex>`.
  Transaction createTransactionForChangeOwnerAddress({
    required Address sender,
    required Address contract,
    required Address newOwner,
    Nonce? nonce,
  }) {
    final Uint8List data = Uint8List.fromList(
      utf8.encode('ChangeOwnerAddress@${convert.hex.encode(newOwner.bytes)}'),
    );
    final int gas =
        config.gasLimitChangeOwnerAddress +
        config.minGasLimit +
        data.length * config.gasLimitPerByte;

    return Transaction(
      nonce: nonce ?? const Nonce(0),
      sender: sender,
      receiver: contract,
      gasLimit: GasLimit(gas),
      gasPrice: GasPrice(config.defaultGasPrice),
      chainId: config.chainId,
      version: const TransactionVersion(2),
      data: data,
      value: Balance.zero(),
    );
  }

  /// Creates an unsigned `ClaimDeveloperRewards` transaction.
  ///
  /// Must be sent by the current contract owner.
  Transaction createTransactionForClaimDeveloperRewards({
    required Address sender,
    required Address contract,
    Nonce? nonce,
  }) {
    final Uint8List data = Uint8List.fromList(
      utf8.encode('ClaimDeveloperRewards'),
    );
    final int gas =
        config.gasLimitClaimDeveloperRewards +
        config.minGasLimit +
        data.length * config.gasLimitPerByte;

    return Transaction(
      nonce: nonce ?? const Nonce(0),
      sender: sender,
      receiver: contract,
      gasLimit: GasLimit(gas),
      gasPrice: GasPrice(config.defaultGasPrice),
      chainId: config.chainId,
      version: const TransactionVersion(2),
      data: data,
      value: Balance.zero(),
    );
  }
}
