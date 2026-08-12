/// Controller for transfer transactions.
import 'dart:typed_data';

import '../../core.dart';

/// Input for native EGLD transfer.
///
/// Specifies the receiver, amount, and optional data payload for native token transfers.
///
/// #### Parameters
/// - `receiver` - Destination address for the transfer
/// - `amount` - Amount of EGLD to transfer
/// - `data` - Optional arbitrary data to attach
///
/// #### Example
/// ```dart
/// // Simple transfer
/// final input = NativeTransferInput(
///   receiver: Address.fromBech32('erd1...'),
///   amount: Balance.fromEgld(1.5),
/// );
///
/// // Transfer with data
/// final inputWithData = NativeTransferInput(
///   receiver: Address.fromBech32('erd1...'),
///   amount: Balance.fromEgld(0.1),
///   data: utf8.encode('payment for service'),
/// );
/// ```
class NativeTransferInput {
  const NativeTransferInput({
    required this.receiver,
    required this.amount,
    this.data,
  });

  final Address receiver;
  final Balance amount;
  final Uint8List? data;
}

/// Input for ESDT token transfers (single or multiple).
///
/// Specifies the receiver and list of token transfers. Supports fungible,
/// semi-fungible, and non-fungible tokens in a single transaction.
///
/// #### Parameters
/// - `receiver` - Destination address for the tokens
/// - `transfers` - List of token transfers
///
/// #### Example
/// ```dart
/// // Single token transfer
/// final input = TokenTransferInput(
///   receiver: Address.fromBech32('erd1...'),
///   transfers: [
///     TokenTransfer.fungible(
///       tokenIdentifier: 'MYTOKEN-abc123',
///       amount: BigInt.from(1000),
///     ),
///   ],
/// );
///
/// // Multi-token transfer
/// final multiInput = TokenTransferInput(
///   receiver: Address.fromBech32('erd1...'),
///   transfers: [
///     TokenTransfer.fungible(
///       tokenIdentifier: 'TOKEN-abc123',
///       amount: BigInt.from(500),
///     ),
///     TokenTransfer.nonFungible(
///       tokenIdentifier: 'NFT-def456',
///       nonce: 1,
///       amount: BigInt.one,
///     ),
///   ],
/// );
/// ```
class TokenTransferInput {
  const TokenTransferInput({required this.receiver, required this.transfers});

  final Address receiver;
  final List<TokenTransfer> transfers;
}

/// Controller for transfer operations.
///
/// Extends [BaseController] to provide high-level API for creating transfer transactions.
/// Handles both native EGLD transfers and ESDT token transfers with automatic gas
/// estimation, guardian support, and signing.
/// Create controller once and reuse for multiple transfers.
///
/// #### Example
/// ```dart
/// final controller = TransfersController(
///   chainId: const ChainId.devnet(), // Devnet
///   gasLimitEstimator: myEstimator,
/// );
/// ```
class TransfersController extends BaseController {
  /// Creates transfers controller.
  ///
  /// #### Parameters
  /// - `chainId` - Network chain ID
  /// - `gasLimitEstimator` - Optional gas estimation service
  ///
  /// #### Example
  /// ```dart
  /// // With gas estimator
  /// final controller = TransfersController(
  ///   chainId: const ChainId.devnet(),
  ///   gasLimitEstimator: GasEstimator(networkProvider: apiProvider),
  /// );
  ///
  /// // Without estimator (manual gas limits)
  /// final simpleController = TransfersController(chainId: const ChainId.mainnet());
  /// ```
  TransfersController({required ChainId chainId, super.gasLimitEstimator})
    : factory = TransferTransactionsFactory(
        config: TransferTransactionsConfig(chainId: chainId),
      );

  final TransferTransactionsFactory factory;

  /// Creates transaction for native EGLD transfer.
  ///
  /// Builds, configures, and signs a transaction for transferring native EGLD tokens.
  ///
  /// #### Parameters
  /// - `sender` - Account that will send the transaction
  /// - `nonce` - Transaction nonce
  /// - `options` - Transfer details
  /// - `baseOptions` - Optional overrides for gas, guardian, relayer
  ///
  /// #### Returns Signed transaction ready for broadcast
  ///
  /// #### Example
  /// ```dart
  /// final tx = await controller.createTransactionForNativeTransfer(
  ///   myAccount,
  ///   Nonce(42),
  ///   NativeTransferInput(
  ///     receiver: Address.fromBech32('erd1...'),
  ///     amount: Balance.fromEgld(1.5),
  ///     data: utf8.encode('payment'),
  ///   ),
  /// );
  /// await apiProvider.sendTransaction(tx);
  /// ```
  Future<Transaction> createTransactionForNativeTransfer(
    IAccount sender,
    Nonce nonce,
    NativeTransferInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory
        .createTransactionForNativeTokenTransfer(
          sender: sender.address,
          receiver: options.receiver,
          nativeAmount: options.amount,
          data: options.data,
        );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for ESDT token transfer.
  ///
  /// Builds, configures, and signs a transaction for transferring ESDT tokens
  /// (fungible, semi-fungible, or non-fungible). Supports multiple token transfers
  /// in a single transaction.
  ///
  /// #### Parameters
  /// - `sender` - Account that will send the transaction
  /// - `nonce` - Transaction nonce
  /// - `options` - Transfer details
  /// - `baseOptions` - Optional overrides for gas, guardian, relayer
  ///
  /// #### Returns Signed transaction ready for broadcast
  ///
  /// #### Example
  /// ```dart
  /// // Single token transfer
  /// final tx = await controller.createTransactionForTokenTransfer(
  ///   myAccount,
  ///   Nonce(42),
  ///   TokenTransferInput(
  ///     receiver: Address.fromBech32('erd1...'),
  ///     transfers: [
  ///       TokenTransfer.fungible(
  ///         tokenIdentifier: 'MYTOKEN-abc123',
  ///         amount: BigInt.from(1000),
  ///       ),
  ///     ],
  ///   ),
  /// );
  /// ```
  Future<Transaction> createTransactionForTokenTransfer(
    IAccount sender,
    Nonce nonce,
    TokenTransferInput options, {
    BaseControllerInput? baseOptions,
  }) async {
    final Transaction transaction = factory.createTransactionForEsdtTransfer(
      sender: sender.address,
      receiver: options.receiver,
      tokenTransfers: options.transfers,
    );

    return setupAndSignTransaction(
      transaction,
      baseOptions ?? const BaseControllerInput(),
      nonce,
      sender,
    );
  }

  /// Creates transaction for multi-token transfer.
  ///
  /// Convenience method that delegates to [createTransactionForTokenTransfer].
  /// Use [TokenTransferInput] with multiple transfers to send multiple tokens.
  ///
  /// #### Parameters
  /// - `sender` - Account that will send the transaction
  /// - `nonce` - Transaction nonce
  /// - `options` - Transfer details
  /// - `baseOptions` - Optional overrides for gas, guardian, relayer
  ///
  /// #### Returns Signed transaction ready for broadcast
  ///
  /// #### Example
  /// ```dart
  /// final tx = await controller.createTransactionForMultiTokenTransfer(
  ///   myAccount,
  ///   Nonce(42),
  ///   TokenTransferInput(
  ///     receiver: Address.fromBech32('erd1...'),
  ///     transfers: [
  ///       TokenTransfer.fungible(
  ///         tokenIdentifier: 'TOKEN-abc123',
  ///         amount: BigInt.from(500),
  ///       ),
  ///       TokenTransfer.nonFungible(
  ///         tokenIdentifier: 'NFT-def456',
  ///         nonce: 1,
  ///         amount: BigInt.one,
  ///       ),
  ///     ],
  ///   ),
  /// );
  /// ```
  Future<Transaction> createTransactionForMultiTokenTransfer(
    IAccount sender,
    Nonce nonce,
    TokenTransferInput options, {
    BaseControllerInput? baseOptions,
  }) {
    return createTransactionForTokenTransfer(
      sender,
      nonce,
      options,
      baseOptions: baseOptions,
    );
  }
}
