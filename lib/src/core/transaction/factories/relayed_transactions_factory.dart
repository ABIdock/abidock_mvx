/// Factory for relayed-v3 transactions.
///
/// The outer transaction carries a list of pre-signed inner transactions.
/// Each inner transaction must already be fully signed and must declare the
/// outer sender as its `relayer`. The outer transaction itself has no data
/// payload: it is pure relayer metadata plus the bundle.
import 'dart:typed_data';

import '../../address.dart';
import '../../balance.dart';
import '../../nonce.dart';
import '../chain_id.dart';
import '../gas_models/gas_limit.dart';
import '../gas_models/gas_price.dart';
import '../transaction.dart';
import '../transaction_version.dart';

/// Gas / chain-ID configuration for the relayer factory.
class RelayedTransactionsConfig {
  const RelayedTransactionsConfig({
    required this.chainId,
    this.extraGasLimitForRelayedTransactions = 50000,
    this.defaultGasPrice = 1000000000,
  });

  final ChainId chainId;
  final int extraGasLimitForRelayedTransactions;
  final int defaultGasPrice;
}

/// Assembles a relayed-v3 outer transaction from a list of already-signed
/// inner transactions.
class RelayedTransactionsFactory {
  RelayedTransactionsFactory(this.config);
  final RelayedTransactionsConfig config;

  /// Builds the outer (unsigned) relayed-v3 transaction.
  ///
  /// Every entry of [innerTransactions] must already be signed by its own
  /// sender, with `relayer == relayerAddress` set on the inner tx. Gas is
  /// the sum of the inner gas limits plus one relayer-overhead per inner.
  Transaction createRelayedTransaction({
    required Address relayerAddress,
    required Nonce relayerNonce,
    required List<Transaction> innerTransactions,
  }) {
    if (innerTransactions.isEmpty) {
      throw ArgumentError('At least one inner transaction is required');
    }

    int totalGas = 0;
    for (int i = 0; i < innerTransactions.length; i++) {
      final Transaction inner = innerTransactions[i];
      if (inner.signature.isEmpty) {
        throw ArgumentError('Inner transaction at index $i is not signed');
      }
      if (inner.relayer == null || inner.relayer != relayerAddress) {
        throw ArgumentError(
          'Inner transaction at index $i must have `relayer` set to '
          '${relayerAddress.bech32}',
        );
      }
      if (inner.chainId.value != config.chainId.value) {
        throw ArgumentError(
          'Inner transaction at index $i has chainID '
          '"${inner.chainId.value}" but the outer is "${config.chainId.value}"',
        );
      }
      totalGas +=
          inner.gasLimit.value + config.extraGasLimitForRelayedTransactions;
    }

    return Transaction(
      nonce: relayerNonce,
      sender: relayerAddress,
      receiver: relayerAddress,
      value: Balance.zero(),
      gasLimit: GasLimit(totalGas),
      gasPrice: GasPrice(config.defaultGasPrice),
      chainId: config.chainId,
      version: const TransactionVersion(2),
      data: Uint8List(0),
      innerTransactions: innerTransactions,
    );
  }
}
