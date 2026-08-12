/// Factory for creating token transfer transactions.
/// Provides low-level builders for EGLD, ESDT, NFT, and multi-token transfers.
import 'dart:convert';
import 'dart:typed_data';

import '../../../abi/abi.dart';
import '../../core.dart';

/// Constants for gas estimation
const int additionalGasForEsdtTransfer = 100000;
const int additionalGasForEsdtNftTransfer = 800000;

/// Identifier for native EGLD inside a `MultiESDTNFTTransfer` payload.
///
/// Sending the bare 4-byte `EGLD` here is invalid on-chain; the wire form
/// must be the full `EGLD-000000` sentinel.
///
/// DO NOT change this constant — `test/core/transaction/factories/egld_sentinel_pinning_test.dart`
/// pins the value to prevent silent regressions.
const String egldIdentifierForMultiTransfer = 'EGLD-000000';

/// Configuration for transfer transactions.
/// Defines gas limits for different transfer types based on data length and token complexity.
class TransferTransactionsConfig {
  /// Creates transfer transactions configuration.
  const TransferTransactionsConfig({
    required this.chainId,
    this.minGasLimit = 50000,
    this.gasLimitPerByte = 1500,
    this.gasLimitEsdtTransfer = 200000,
    this.gasLimitEsdtNftTransfer = 200000,
    this.gasLimitMultiEsdtNftTransfer = 200000,
  });

  /// Builds a [TransferTransactionsConfig] from a shared [TransactionsFactoryConfig].
  ///
  /// #### Parameters
  /// - `shared` - Aggregate factory config populated by `NetworkEntrypoint`.
  ///
  /// #### Returns
  /// A new [TransferTransactionsConfig] mirroring `shared`'s relevant fields.
  static TransferTransactionsConfig fromShared(
    TransactionsFactoryConfig shared,
  ) => TransferTransactionsConfig(
    chainId: shared.chainId,
    minGasLimit: shared.minGasLimit,
    gasLimitPerByte: shared.gasLimitPerByte,
    gasLimitEsdtTransfer: shared.gasLimitEsdtTransfer,
    gasLimitEsdtNftTransfer: shared.gasLimitEsdtNftTransfer,
    gasLimitMultiEsdtNftTransfer: shared.gasLimitMultiEsdtNftTransfer,
  );

  final ChainId chainId;
  final int minGasLimit;
  final int gasLimitPerByte;
  final int gasLimitEsdtTransfer;
  final int gasLimitEsdtNftTransfer;
  final int gasLimitMultiEsdtNftTransfer;
}

/// Represents token transfer.
/// Encapsulates single token transfer with identifier, amount, and optional nonce.
class TokenTransfer {
  /// Creates token transfer.
  const TokenTransfer({
    required this.tokenIdentifier,
    required this.amount,
    this.nonce = 0,
  });

  /// Creates fungible token transfer.
  factory TokenTransfer.fungible({
    required String tokenIdentifier,
    required BigInt amount,
  }) {
    return TokenTransfer(
      tokenIdentifier: tokenIdentifier,
      amount: amount,
      nonce: 0,
    );
  }

  /// Creates non-fungible token transfer.
  factory TokenTransfer.nonFungible({
    required String tokenIdentifier,
    required int nonce,
    required BigInt amount,
  }) {
    return TokenTransfer(
      tokenIdentifier: tokenIdentifier,
      amount: amount,
      nonce: nonce,
    );
  }

  /// Creates native EGLD transfer.
  factory TokenTransfer.egld(BigInt amount) {
    return TokenTransfer(
      tokenIdentifier: egldIdentifierForMultiTransfer,
      amount: amount,
      nonce: 0,
    );
  }

  final String tokenIdentifier;
  final BigInt amount;
  final int nonce;

  /// Returns true if fungible token.
  bool get isFungible => nonce == 0;

  /// Returns true if non-fungible token.
  bool get isNonFungible => nonce > 0;

  /// Returns true if EGLD transfer.
  bool get isEgld => tokenIdentifier == egldIdentifierForMultiTransfer;

  /// Extracts base identifier without nonce.
  String get baseIdentifier {
    final List<String> parts = tokenIdentifier.split('-');
    if (parts.length >= 2) {
      return '${parts[0]}-${parts[1]}';
    }
    return tokenIdentifier;
  }
}

/// Factory for creating token transfer transactions.
/// Low-level factory for building unsigned transfer transactions.
/// Automatically selects appropriate transfer protocol based on token type and count.
class TransferTransactionsFactory {
  /// Creates transfer transactions factory.
  TransferTransactionsFactory({required this.config})
    : _tokenTransfersBuilder = TokenTransfersDataBuilder(
        serializer: ArgSerializer(),
      );

  final TransferTransactionsConfig config;
  final TokenTransfersDataBuilder _tokenTransfersBuilder;

  /// Creates transaction for native EGLD transfer.
  /// Builds standard value transfer transaction with optional data payload.
  ///
  /// #### Parameters
  /// - `sender` - Address sending the EGLD
  /// - `receiver` - Address receiving the EGLD
  /// - `nativeAmount` - Amount of EGLD to transfer
  /// - `data` - Optional arbitrary data
  /// - `gasLimit` - Optional manual gas limit
  ///
  /// #### Returns
  /// `Transaction` - Unsigned transaction with calculated gas limit
  Transaction createTransactionForNativeTokenTransfer({
    required Address sender,
    required Address receiver,
    required Balance nativeAmount,
    Uint8List? data,
    GasLimit? gasLimit,
  }) {
    final Uint8List dataPayload = data ?? Uint8List(0);

    final int calculatedGasLimit =
        gasLimit?.value ??
        _calculateGasLimit(dataLength: dataPayload.length, extraGas: 0);

    return Transaction(
      sender: sender,
      receiver: receiver,
      value: nativeAmount,
      nonce: const Nonce(0),
      gasLimit: GasLimit(calculatedGasLimit),
      gasPrice: const GasPrice(defaultMinGasPrice),
      data: dataPayload,
      chainId: config.chainId,
      version: const TransactionVersion(1),
      signature: const Signature.empty(),
    );
  }

  /// Creates transaction for ESDT/NFT/SFT token transfer(s).
  /// Automatically selects appropriate protocol based on token types.
  ///
  /// #### Parameters
  /// - `sender` - Address sending the tokens
  /// - `receiver` - Address receiving the tokens
  /// - `tokenTransfers` - List of token transfers
  /// - `gasLimit` - Optional manual gas limit
  ///
  /// #### Returns
  /// `Transaction` - Unsigned transaction with calculated gas limit
  ///
  /// #### Throws
  /// - `ArgumentError` - If tokenTransfers is empty
  Transaction createTransactionForEsdtTransfer({
    required Address sender,
    required Address receiver,
    required List<TokenTransfer> tokenTransfers,
    GasLimit? gasLimit,
  }) {
    if (tokenTransfers.isEmpty) {
      throw ArgumentError('No token transfers provided');
    }

    if (tokenTransfers.length == 1) {
      return _createSingleEsdtTransferTransaction(
        sender: sender,
        receiver: receiver,
        transfer: tokenTransfers.first,
        gasLimit: gasLimit,
      );
    }

    return _createMultiEsdtNftTransferTransaction(
      sender: sender,
      receiver: receiver,
      tokenTransfers: tokenTransfers,
      gasLimit: gasLimit,
    );
  }

  /// Creates unified transfer transaction.
  Transaction createTransactionForTransfer({
    required Address sender,
    required Address receiver,
    Balance? nativeAmount,
    List<TokenTransfer>? tokenTransfers,
    Uint8List? data,
    GasLimit? gasLimit,
  }) {
    final Balance amount = nativeAmount ?? Balance.zero();
    final List<TokenTransfer> transfers = tokenTransfers ?? <TokenTransfer>[];

    if (transfers.isNotEmpty && data != null && data.isNotEmpty) {
      throw ArgumentError('Cannot set data field when sending ESDT tokens');
    }
    if ((amount.value > BigInt.zero && transfers.isEmpty) || data != null) {
      return createTransactionForNativeTokenTransfer(
        sender: sender,
        receiver: receiver,
        nativeAmount: amount,
        data: data,
        gasLimit: gasLimit,
      );
    }

    final List<TokenTransfer> allTransfers = <TokenTransfer>[...transfers];
    if (amount.value > BigInt.zero) {
      allTransfers.add(TokenTransfer.egld(amount.value));
    }

    return createTransactionForEsdtTransfer(
      sender: sender,
      receiver: receiver,
      tokenTransfers: allTransfers,
      gasLimit: gasLimit,
    );
  }

  Transaction _createSingleEsdtTransferTransaction({
    required Address sender,
    required Address receiver,
    required TokenTransfer transfer,
    GasLimit? gasLimit,
  }) {
    final _TransferData transferData = _buildTransferData(
      transfer: transfer,
      sender: sender,
      receiver: receiver,
    );

    final int calculatedGasLimit =
        gasLimit?.value ??
        _calculateGasLimit(
          dataLength: transferData.dataPayload.length,
          extraGas: transferData.extraGas,
        );

    return Transaction(
      sender: sender,
      receiver: transferData.receiverAddress,
      value: Balance.zero(),
      nonce: const Nonce(0),
      gasLimit: GasLimit(calculatedGasLimit),
      gasPrice: const GasPrice(defaultMinGasPrice),
      data: transferData.dataPayload,
      chainId: config.chainId,
      version: const TransactionVersion(1),
      signature: const Signature.empty(),
    );
  }

  Transaction _createMultiEsdtNftTransferTransaction({
    required Address sender,
    required Address receiver,
    required List<TokenTransfer> tokenTransfers,
    GasLimit? gasLimit,
  }) {
    final Uint8List dataPayload = _buildMultiEsdtNftTransferData(
      receiver: receiver,
      transfers: tokenTransfers,
    );

    final int extraGas =
        config.gasLimitMultiEsdtNftTransfer * tokenTransfers.length +
        additionalGasForEsdtNftTransfer;

    final int calculatedGasLimit =
        gasLimit?.value ??
        _calculateGasLimit(dataLength: dataPayload.length, extraGas: extraGas);

    return Transaction(
      sender: sender,
      receiver: sender,
      value: Balance.zero(),
      nonce: const Nonce(0),
      gasLimit: GasLimit(calculatedGasLimit),
      gasPrice: const GasPrice(defaultMinGasPrice),
      data: dataPayload,
      chainId: config.chainId,
      version: const TransactionVersion(1),
      signature: const Signature.empty(),
    );
  }

  _TransferData _buildTransferData({
    required TokenTransfer transfer,
    required Address sender,
    required Address receiver,
  }) {
    if (transfer.isFungible) {
      if (transfer.isEgld) {
        final Uint8List dataPayload = _buildMultiEsdtNftTransferData(
          receiver: receiver,
          transfers: <TokenTransfer>[transfer],
        );
        return _TransferData(
          dataPayload: dataPayload,
          extraGas:
              config.gasLimitMultiEsdtNftTransfer +
              additionalGasForEsdtNftTransfer,
          receiverAddress: sender,
        );
      } else {
        final Uint8List dataPayload = _buildEsdtTransferData(transfer);
        return _TransferData(
          dataPayload: dataPayload,
          extraGas: config.gasLimitEsdtTransfer + additionalGasForEsdtTransfer,
          receiverAddress: receiver,
        );
      }
    } else {
      final Uint8List dataPayload = _buildSingleEsdtNftTransferData(
        transfer: transfer,
        receiver: receiver,
      );
      return _TransferData(
        dataPayload: dataPayload,
        extraGas:
            config.gasLimitEsdtNftTransfer + additionalGasForEsdtNftTransfer,
        receiverAddress: sender,
      );
    }
  }

  Uint8List _buildEsdtTransferData(TokenTransfer transfer) {
    final TokenTransferValue transferValue = TokenTransferValue.fromPrimitives(
      tokenIdentifier: transfer.tokenIdentifier,
      amount: transfer.amount,
    );

    final List<String> dataParts = _tokenTransfersBuilder
        .buildDataPartsForESDTTransfer(transferValue);

    return utf8.encode(dataParts.join('@'));
  }

  Uint8List _buildSingleEsdtNftTransferData({
    required TokenTransfer transfer,
    required Address receiver,
  }) {
    final TokenTransferValue transferValue = TokenTransferValue.fromPrimitives(
      tokenIdentifier: transfer.baseIdentifier,
      nonce: BigInt.from(transfer.nonce),
      amount: transfer.amount,
    );

    final List<String> dataParts = _tokenTransfersBuilder
        .buildDataPartsForSingleESDTNFTTransfer(transferValue, receiver);

    return utf8.encode(dataParts.join('@'));
  }

  Uint8List _buildMultiEsdtNftTransferData({
    required Address receiver,
    required List<TokenTransfer> transfers,
  }) {
    final List<TokenTransferValue> transferValues = transfers
        .map(
          (TokenTransfer t) => TokenTransferValue.fromPrimitives(
            tokenIdentifier: t.baseIdentifier,
            nonce: t.nonce > 0 ? BigInt.from(t.nonce) : null,
            amount: t.amount,
          ),
        )
        .toList();

    final List<String> dataParts = _tokenTransfersBuilder
        .buildDataPartsForMultiESDTNFTTransfer(receiver, transferValues);

    return utf8.encode(dataParts.join('@'));
  }

  int _calculateGasLimit({required int dataLength, required int extraGas}) {
    final int baseGas =
        config.minGasLimit + (dataLength * config.gasLimitPerByte);
    return baseGas + extraGas;
  }
}

/// Internal helper class for transfer data.
class _TransferData {
  const _TransferData({
    required this.dataPayload,
    required this.extraGas,
    required this.receiverAddress,
  });

  final Uint8List dataPayload;
  final int extraGas;
  final Address receiverAddress;
}
