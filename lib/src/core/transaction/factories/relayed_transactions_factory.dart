/// Factory for relayed-v3 transactions.
///
/// A relayed-v3 transaction is a single, flat transaction: the user's own
/// transaction with `relayer` set and co-signed by that relayer. The protocol
/// has no outer wrapper and no inner-transaction bundle — `relayer` and
/// `relayerSignature` are the only additions to an ordinary transaction.
import '../../address.dart';
import '../chain_id.dart';
import '../gas_models/gas_limit.dart';
import '../transaction.dart';
import '../transaction_constants.dart';
import '../transaction_version.dart';
import '../transactions_factory_config.dart';

/// Gas / chain-ID configuration for the relayer factory.
class RelayedTransactionsConfig {
  const RelayedTransactionsConfig({
    required this.chainId,
    this.extraGasLimitForRelayedTransactions = 50000,
    this.defaultGasPrice = 1000000000,
  });

  /// Derives a [RelayedTransactionsConfig] from a shared
  /// [TransactionsFactoryConfig].
  ///
  /// #### Parameters
  /// - `shared` - Aggregate factory config populated by `NetworkEntrypoint`.
  ///
  /// #### Returns
  /// `RelayedTransactionsConfig` mirroring the shared chain id and the
  /// `extraGasLimitForRelayedTransactions` field.
  static RelayedTransactionsConfig fromShared(
    TransactionsFactoryConfig shared,
  ) => RelayedTransactionsConfig(
    chainId: shared.chainId,
    extraGasLimitForRelayedTransactions:
        shared.extraGasLimitForRelayedTransactions,
  );

  final ChainId chainId;
  final int extraGasLimitForRelayedTransactions;
  final int defaultGasPrice;
}

/// Turns a user transaction into a relayed-v3 transaction by attaching the
/// relayer that pays its fee.
///
/// The whole flow is three steps: [applyRelayer] on the still-unsigned user
/// transaction, then `Transaction.signWith` for the sender and
/// `Transaction.signAsRelayer` for the relayer. Both parties sign the same
/// serialized payload, so the order of the two signatures does not matter.
class RelayedTransactionsFactory {
  RelayedTransactionsFactory(this.config);
  final RelayedTransactionsConfig config;

  /// Marks [transaction] as relayed by [relayer] and adds the relayed base
  /// cost to its gas limit.
  ///
  /// Must be called BEFORE anyone signs: `relayer` is part of the signed
  /// payload. Sender and relayer then sign the very same bytes, in any order,
  /// through `signWith` and `signAsRelayer`. Re-applying the relayer that is
  /// already set leaves the gas limit untouched, so the base cost is never
  /// charged twice.
  ///
  /// #### Parameters
  /// - `transaction` - Unsigned user transaction
  /// - `relayer` - Address that pays the fee
  /// - `numberOfShards` - Shard count used for the same-shard check
  ///
  /// #### Returns
  /// `Transaction` - Copy with `relayer` set, `version` at least
  /// `minTransactionVersionThatSupportsOptions` and
  /// `extraGasLimitForRelayedTransactions` added to the gas limit
  ///
  /// #### Throws
  /// - `ArgumentError` - If the transaction already carries any signature, if
  ///   its chain id differs from the configured one, if `relayer` equals the
  ///   guardian, or if relayer and sender live in different shards
  /// - `StateError` - If a different relayer is already set
  ///
  /// #### Example
  /// ```dart
  /// final relayed = factory.applyRelayer(transaction, relayerAddress);
  /// final signed = await relayed.signWith(senderSigner);
  /// final broadcastable = await signed.signAsRelayer(relayerSigner);
  /// ```
  Transaction applyRelayer(
    Transaction transaction,
    Address relayer, {
    int numberOfShards = 3,
  }) {
    if (transaction.signature.isNotEmpty ||
        transaction.relayerSignature.isNotEmpty ||
        transaction.guardianSignature.isNotEmpty) {
      throw ArgumentError(
        'Set the relayer before signing: the relayer address is part of the '
        'signed payload, so any existing signature would become invalid.',
      );
    }

    if (transaction.chainId.value != config.chainId.value) {
      throw ArgumentError(
        'Transaction chainID "${transaction.chainId.value}" does not match '
        'the factory chainID "${config.chainId.value}"',
      );
    }

    final bool alreadyRelayed =
        transaction.relayer != null && !transaction.relayer!.isEmpty;

    if (alreadyRelayed && transaction.relayer != relayer) {
      throw StateError(
        'Transaction already has a different relayer '
        '(${transaction.relayer!.bech32}); construct a fresh transaction '
        'before re-relaying.',
      );
    }

    if (transaction.guardian != null && transaction.guardian == relayer) {
      throw ArgumentError(
        'Relayer must differ from guardian; the chain rejects such a '
        'transaction with ErrRelayedByGuardianNotAllowed',
      );
    }

    final int senderShard = Address.getShardOfAddress(
      transaction.sender,
      numberOfShards: numberOfShards,
    );
    final int relayerShard = Address.getShardOfAddress(
      relayer,
      numberOfShards: numberOfShards,
    );

    if (senderShard != relayerShard) {
      throw ArgumentError(
        'Relayer and sender must be in the same shard; sender '
        '${transaction.sender.bech32} is in shard $senderShard while relayer '
        '${relayer.bech32} is in shard $relayerShard',
      );
    }

    int version = transaction.version.value;
    if (version < minTransactionVersionThatSupportsOptions) {
      version = minTransactionVersionThatSupportsOptions;
    }

    return transaction.copyWith(
      newRelayer: relayer,
      newVersion: TransactionVersion(version),
      newGasLimit: alreadyRelayed
          ? transaction.gasLimit
          : GasLimit(
              transaction.gasLimit.value +
                  config.extraGasLimitForRelayedTransactions,
            ),
    );
  }
}
