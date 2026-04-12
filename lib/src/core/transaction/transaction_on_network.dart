import 'dart:convert';
import 'dart:typed_data';

import '../core.dart';

/// Transaction on the MultiversX network.
/// Contains original transaction data plus execution metadata: status, block info, results, logs, and gas usage.
///
/// #### Example
/// ```dart
/// // Fetch transaction
/// final txOnNetwork = await networkProvider.getTransaction(txHash);
///
/// // Check status
/// if (txOnNetwork.isSuccessful) {
///   print('Transaction succeeded in block ${txOnNetwork.blockNonce}');
/// } else if (txOnNetwork.hasFailed) {
///   print('Transaction failed: ${txOnNetwork.status.status}');
/// } else if (txOnNetwork.isPending) {
///   print('Transaction still pending');
/// }
///
/// // Access results
/// if (txOnNetwork.smartContractResults != null) {
///   for (final scr in txOnNetwork.smartContractResults!) {
///     print('Smart contract result: ${scr['data']}');
///   }
/// }
///
/// // Parse events
/// if (txOnNetwork.logs != null) {
///   for (final event in txOnNetwork.logs!.events) {
///     print('Event: ${event.identifier}');
///   }
/// }
/// ```
class TransactionOnNetwork {
  /// Creates transaction on network.
  ///
  /// #### Parameters
  /// - `transaction` - Original transaction
  /// - `status` - Current execution status
  /// - `txHash` - Transaction hash (ID)
  /// - `blockNonce` - Block nonce containing transaction (optional)
  /// - `hyperblockNonce` - Hyperblock nonce (optional)
  /// - `blockHash` - Block hash (optional)
  /// - `hyperblockHash` - Hyperblock hash (optional)
  /// - `timestamp` - Execution timestamp (optional)
  /// - `function` - Smart contract function name (optional)
  /// - `executionReceipt` - Gas usage receipt (optional)
  /// - `smartContractResults` - Generated results (optional)
  /// - `logs` - Event logs (optional)
  /// - `gasUsed` - Gas actually consumed (optional)
  /// - `fee` - Transaction fee in atomic units (optional)
  /// - `senderShard` - Sender's shard ID (optional)
  /// - `receiverShard` - Receiver's shard ID (optional)
  /// - `round` - Round number (optional)
  /// - `epoch` - Epoch number (optional)
  /// - `miniBlockHash` - Miniblock hash containing tx (optional)
  /// - `senderUsername` - Sender herotag/username (optional)
  /// - `receiverUsername` - Receiver herotag/username (optional)
  /// - `action` - Decoded action with category, name, arguments (optional)
  /// - `operations` - Token operations performed (optional)
  /// - `type` - Transaction type: normal, reward (optional)
  /// - `originalTxHash` - Original transaction hash for SCRs (optional)
  /// - `pendingResults` - Whether results are still pending (optional)
  /// - `guardianAddress` - Guardian address if guarded (optional)
  /// - `guardianSignature` - Guardian signature (optional)
  /// - `isRelayed` - Whether transaction is relayed (optional)
  /// - `relayer` - Relayer address (optional)
  /// - `relayerSignature` - Relayer signature (optional)
  /// - `isScCall` - Whether transaction is SC call (optional)
  /// - `scamInfo` - Scam detection information (optional)
  /// - `price` - EGLD price at transaction time (optional)
  /// - `relayedVersion` - Version of relayed transaction protocol (optional)
  /// - `senderAssets` - Asset metadata for sender (optional)
  /// - `receiverAssets` - Asset metadata for receiver (optional)
  /// - `completedAt` - Completion timestamp from API (optional)
  /// - `initiallyPaidFee` - Initially paid fee (optional)
  ///
  /// #### Example
  /// ```dart
  /// final txOnNetwork = TransactionOnNetwork(
  ///   transaction: originalTx,
  ///   status: TransactionStatus('success'),
  ///   txHash: '3a4b5c6d...',
  ///   blockNonce: 12345,
  ///   timestamp: 1699999999,
  /// );
  /// ```
  const TransactionOnNetwork({
    required this.transaction,
    required this.status,
    required this.txHash,
    this.blockNonce,
    this.hyperblockNonce,
    this.blockHash,
    this.hyperblockHash,
    this.timestamp,
    this.function,
    this.executionReceipt,
    this.smartContractResults,
    this.logs,
    this.gasUsed,
    this.fee,
    this.senderShard,
    this.receiverShard,
    this.round,
    this.epoch,
    this.miniBlockHash,
    this.senderUsername,
    this.receiverUsername,
    this.action,
    this.operations,
    this.type,
    this.originalTxHash,
    this.pendingResults,
    this.guardianAddress,
    this.guardianSignature,
    this.isRelayed,
    this.relayer,
    this.relayerSignature,
    this.isScCall,
    this.scamInfo,
    this.price,
    this.relayedVersion,
    this.senderAssets,
    this.receiverAssets,
    this.completedAt,
    this.initiallyPaidFee,
  });

  /// Creates from API response.
  ///
  /// #### Parameters
  /// - `data` - JSON map from API response
  /// - `txHash` - Transaction hash (optional, extracted from data if not provided)
  ///
  /// #### Returns
  /// `TransactionOnNetwork` - Parsed transaction instance
  ///
  /// #### Example
  /// ```dart
  /// final apiResponse = {
  ///   'txHash': '3a4b5c6d7e8f...',
  ///   'status': 'success',
  ///   'sender': 'erd1...',
  ///   'receiver': 'erd1qqqqqqqqqqqqqpgq...',
  ///   'value': '1000000000000000000',
  ///   'nonce': 5,
  ///   'gasLimit': 60000000,
  ///   'gasPrice': 1000000000,
  ///   'chainID': '1',
  ///   'blockNonce': 12345,
  ///   'timestamp': 1699999999,
  ///   'function': 'claimRewards',
  ///   'smartContractResults': [...],
  ///   'logs': {...},
  /// };
  ///
  /// final txOnNetwork = TransactionOnNetwork.fromApiResponse(apiResponse);
  /// print('Status: ${txOnNetwork.status.status}');
  /// print('Block: ${txOnNetwork.blockNonce}');
  /// ```
  factory TransactionOnNetwork.fromApiResponse(
    Map<String, dynamic> data, {
    String? txHash,
  }) {
    final String statusStr =
        optionalAs<String>(data['status'], 'status') ?? 'pending';
    final TransactionStatus status = TransactionStatus(statusStr);
    final String? dataStr = optionalAs<String>(data['data'], 'data');
    Uint8List dataBytes;
    if (dataStr != null) {
      try {
        dataBytes = Uint8List.fromList(base64Decode(dataStr));
      } catch (_) {
        dataBytes = Uint8List.fromList(utf8.encode(dataStr));
      }
    } else {
      dataBytes = Uint8List(0);
    }

    final String? signatureStr = optionalAs<String>(
      data['signature'],
      'signature',
    );
    final Signature signature = signatureStr != null
        ? Signature(signatureStr)
        : const Signature.empty();

    final Transaction transaction = Transaction(
      sender: Address.fromBech32(requireAs<String>(data['sender'], 'sender')),
      receiver: Address.fromBech32(
        requireAs<String>(data['receiver'], 'receiver'),
      ),
      value: Balance.fromString(
        optionalAs<String>(data['value'], 'value') ?? '0',
      ),
      nonce: Nonce((data['nonce'] as num?)?.toInt() ?? 0),
      gasLimit: GasLimit((data['gasLimit'] as num?)?.toInt() ?? 0),
      gasPrice: GasPrice((data['gasPrice'] as num?)?.toInt() ?? 1000000000),
      data: dataBytes,
      chainId: ChainId.fromApiResponse(
        optionalAs<String>(data['chainID'], 'chainID'),
      ),
      version: TransactionVersion.validated(
        (data['version'] as num?)?.toInt() ?? 1,
      ),
      signature: signature,
    );

    final TransactionLogs? logs = data['logs'] != null
        ? TransactionLogs.fromHttpResponse(
            requireAs<Map<String, dynamic>>(data['logs'], 'logs'),
          )
        : null;

    final String? functionName = optionalAs<String>(
      data['function'],
      'function',
    );

    final String resolvedTxHash =
        txHash ??
        optionalAs<String>(data['txHash'], 'txHash') ??
        optionalAs<String>(data['hash'], 'hash') ??
        '';

    return TransactionOnNetwork(
      transaction: transaction,
      status: status,
      txHash: resolvedTxHash,
      blockNonce: (data['blockNonce'] as num?)?.toInt(),
      hyperblockNonce: (data['hyperblockNonce'] as num?)?.toInt(),
      blockHash: optionalAs<String>(data['blockHash'], 'blockHash'),
      hyperblockHash: optionalAs<String>(
        data['hyperblockHash'],
        'hyperblockHash',
      ),
      timestamp: (data['timestamp'] as num?)?.toInt(),
      function: functionName,
      executionReceipt: optionalAs<Map<String, dynamic>>(
        data['receipt'],
        'receipt',
      ),
      smartContractResults:
          (optionalAs<List<dynamic>>(
                data['smartContractResults'],
                'smartContractResults',
              ))
              ?.map(
                (dynamic e) => SmartContractResult.fromJson(
                  requireAs<Map<String, dynamic>>(e, 'smartContractResults[]'),
                ),
              )
              .toList(),
      logs: logs,
      gasUsed: (data['gasUsed'] as num?)?.toInt(),
      fee: optionalAs<String>(data['fee'], 'fee'),
      senderShard: (data['senderShard'] as num?)?.toInt(),
      receiverShard: (data['receiverShard'] as num?)?.toInt(),
      round: (data['round'] as num?)?.toInt(),
      epoch: (data['epoch'] as num?)?.toInt(),
      miniBlockHash: optionalAs<String>(data['miniBlockHash'], 'miniBlockHash'),
      senderUsername: optionalAs<String>(
        data['senderUsername'],
        'senderUsername',
      ),
      receiverUsername: optionalAs<String>(
        data['receiverUsername'],
        'receiverUsername',
      ),
      action: optionalAs<Map<String, dynamic>>(data['action'], 'action'),
      operations: (optionalAs<List<dynamic>>(
        data['operations'],
        'operations',
      ))?.cast<Map<String, dynamic>>(),
      type: optionalAs<String>(data['type'], 'type'),
      originalTxHash: optionalAs<String>(
        data['originalTxHash'],
        'originalTxHash',
      ),
      pendingResults: optionalAs<bool>(
        data['pendingResults'],
        'pendingResults',
      ),
      guardianAddress: optionalAs<String>(
        data['guardianAddress'],
        'guardianAddress',
      ),
      guardianSignature: optionalAs<String>(
        data['guardianSignature'],
        'guardianSignature',
      ),
      isRelayed: optionalAs<bool>(data['isRelayed'], 'isRelayed'),
      relayer: optionalAs<String>(data['relayer'], 'relayer'),
      relayerSignature: optionalAs<String>(
        data['relayerSignature'],
        'relayerSignature',
      ),
      isScCall: optionalAs<bool>(data['isScCall'], 'isScCall'),
      scamInfo: optionalAs<Map<String, dynamic>>(data['scamInfo'], 'scamInfo'),
      price: (data['price'] as num?)?.toDouble(),
      relayedVersion: (data['relayedVersion'] as num?)?.toInt(),
      senderAssets: optionalAs<Map<String, dynamic>>(
        data['senderAssets'],
        'senderAssets',
      ),
      receiverAssets: optionalAs<Map<String, dynamic>>(
        data['receiverAssets'],
        'receiverAssets',
      ),
      completedAt: (data['completedAt'] as num?)?.toInt(),
      initiallyPaidFee: optionalAs<String>(
        data['initiallyPaidFee'],
        'initiallyPaidFee',
      ),
    );
  }

  /// Original transaction.
  final Transaction transaction;

  /// Current transaction status.
  final TransactionStatus status;

  /// Transaction hash.
  final String txHash;

  /// Block nonce containing transaction.
  final int? blockNonce;

  /// Hyperblock nonce containing transaction.
  final int? hyperblockNonce;

  /// Block hash containing transaction.
  final String? blockHash;

  /// Hyperblock hash containing transaction.
  final String? hyperblockHash;

  /// Execution timestamp (Unix).
  final int? timestamp;

  /// Function name being called.
  final String? function;

  /// Execution receipt with gas usage.
  final Map<String, dynamic>? executionReceipt;

  /// Smart contract results generated (parsed into typed form).
  ///
  /// Each entry carries the decoded `returnCode`, hex-decoded `returnData`,
  /// and VM call-type metadata, so callers don't have to re-parse the raw
  /// `@`-delimited data string themselves.
  final List<SmartContractResult>? smartContractResults;

  /// Event logs emitted by transaction.
  final TransactionLogs? logs;

  /// Gas actually consumed by the transaction.
  final int? gasUsed;

  /// Transaction fee in atomic units (string for big numbers).
  final String? fee;

  /// Shard ID of the sender.
  final int? senderShard;

  /// Shard ID of the receiver.
  final int? receiverShard;

  /// Round number when transaction was processed.
  final int? round;

  /// Epoch number when transaction was processed.
  final int? epoch;

  /// Miniblock hash containing this transaction.
  final String? miniBlockHash;

  /// Sender's herotag/username (e.g., '@alice').
  final String? senderUsername;

  /// Receiver's herotag/username (e.g., '@bob').
  final String? receiverUsername;

  /// Decoded action with category, name, description, and arguments.
  /// Provides human-readable interpretation of the transaction.
  final Map<String, dynamic>? action;

  /// Token operations performed by this transaction.
  /// Each operation contains type, identifier, sender, receiver, value.
  final List<Map<String, dynamic>>? operations;

  /// Transaction type: 'normal' or 'reward'.
  final String? type;

  /// Original transaction hash for smart contract results.
  /// Present when this is a SCR derived from another transaction.
  final String? originalTxHash;

  /// Whether there are pending results for this transaction.
  final bool? pendingResults;

  /// Guardian address for guarded transactions.
  final String? guardianAddress;

  /// Guardian signature for guarded transactions.
  final String? guardianSignature;

  /// Whether this is a relayed transaction.
  final bool? isRelayed;

  /// Relayer address for relayed transactions.
  final String? relayer;

  /// Relayer signature for relayed transactions.
  final String? relayerSignature;

  /// Whether this transaction is a smart contract call.
  final bool? isScCall;

  /// Scam detection information if flagged.
  /// Contains 'type' and 'info' fields when present.
  final Map<String, dynamic>? scamInfo;

  /// EGLD price in USD at transaction time.
  final double? price;

  /// Relayed transaction protocol version (1 or 2).
  final int? relayedVersion;

  /// Asset metadata for sender address (name, icon, etc.).
  final Map<String, dynamic>? senderAssets;

  /// Asset metadata for receiver address (name, icon, etc.).
  final Map<String, dynamic>? receiverAssets;

  /// Timestamp when transaction was completed (from API).
  final int? completedAt;

  /// Fee initially paid before refunds.
  final String? initiallyPaidFee;

  /// Checks if transaction is completed.
  ///
  /// #### Returns
  /// `bool` - True if transaction reached final state
  ///
  /// #### Example
  /// ```dart
  /// while (!txOnNetwork.isCompleted) {
  ///   await Future.delayed(Duration(seconds: 1));
  ///   txOnNetwork = await networkProvider.getTransaction(txHash);
  /// }
  /// print('Transaction finished');
  /// ```
  bool get isCompleted => status.isFinal;

  /// Checks if transaction was successful.
  ///
  /// #### Returns
  /// `bool` - True if transaction executed successfully
  ///
  /// #### Example
  /// ```dart
  /// if (txOnNetwork.isSuccessful) {
  ///   print('Transaction succeeded!');
  ///   // Process results
  ///   if (txOnNetwork.smartContractResults != null) {
  ///     for (final result in txOnNetwork.smartContractResults!) {
  ///       print('Result: ${result['data']}');
  ///     }
  ///   }
  /// }
  /// ```
  bool get isSuccessful => status.isSuccessful;

  /// Checks if transaction failed.
  ///
  /// #### Returns
  /// `bool` - True if transaction execution failed
  ///
  /// #### Example
  /// ```dart
  /// if (txOnNetwork.hasFailed) {
  ///   print('Transaction failed: ${txOnNetwork.status.status}');
  ///   // Check logs for error details
  ///   if (txOnNetwork.logs != null) {
  ///     for (final event in txOnNetwork.logs!.events) {
  ///       if (event.identifier == 'signalError') {
  ///         print('Error: ${utf8.decode(base64.decode(event.topics[1]))}');
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  bool get hasFailed => status.isFailed;

  /// Checks if transaction is pending.
  ///
  /// #### Returns
  /// `bool` - True if transaction is still pending execution
  ///
  /// #### Example
  /// ```dart
  /// if (txOnNetwork.isPending) {
  ///   print('Waiting for transaction...');
  ///   await Future.delayed(Duration(seconds: 1));
  ///   // Retry fetch
  /// }
  /// ```
  bool get isPending => status.isPending;

  /// Checks if transaction is in block.
  ///
  /// #### Returns
  /// `bool` - True if transaction is included in a block
  ///
  /// #### Example
  /// ```dart
  /// if (txOnNetwork.isInBlock) {
  ///   print('Transaction in block ${txOnNetwork.blockNonce}');
  ///   print('Block hash: ${txOnNetwork.blockHash}');
  /// }
  /// ```
  bool get isInBlock => blockNonce != null;

  /// Gets sender address.
  Address get sender => transaction.sender;

  /// Gets receiver address.
  Address get receiver => transaction.receiver;

  /// Gets transaction value.
  Balance get value => transaction.value;

  /// Gets transaction nonce.
  Nonce get nonce => transaction.nonce;

  /// Gets transaction data.
  dynamic get data => transaction.data;

  /// Creates copy with updated fields.
  TransactionOnNetwork copyWith({
    Transaction? transaction,
    TransactionStatus? status,
    String? txHash,
    int? blockNonce,
    int? hyperblockNonce,
    String? blockHash,
    String? hyperblockHash,
    int? timestamp,
    String? function,
    Map<String, dynamic>? executionReceipt,
    List<SmartContractResult>? smartContractResults,
    TransactionLogs? logs,
    int? gasUsed,
    String? fee,
    int? senderShard,
    int? receiverShard,
    int? round,
    int? epoch,
    String? miniBlockHash,
    String? senderUsername,
    String? receiverUsername,
    Map<String, dynamic>? action,
    List<Map<String, dynamic>>? operations,
    String? type,
    String? originalTxHash,
    bool? pendingResults,
    String? guardianAddress,
    String? guardianSignature,
    bool? isRelayed,
    String? relayer,
    String? relayerSignature,
    bool? isScCall,
    Map<String, dynamic>? scamInfo,
    double? price,
    int? relayedVersion,
    Map<String, dynamic>? senderAssets,
    Map<String, dynamic>? receiverAssets,
    int? completedAt,
    String? initiallyPaidFee,
  }) {
    return TransactionOnNetwork(
      transaction: transaction ?? this.transaction,
      status: status ?? this.status,
      txHash: txHash ?? this.txHash,
      blockNonce: blockNonce ?? this.blockNonce,
      hyperblockNonce: hyperblockNonce ?? this.hyperblockNonce,
      blockHash: blockHash ?? this.blockHash,
      hyperblockHash: hyperblockHash ?? this.hyperblockHash,
      timestamp: timestamp ?? this.timestamp,
      function: function ?? this.function,
      executionReceipt: executionReceipt ?? this.executionReceipt,
      smartContractResults: smartContractResults ?? this.smartContractResults,
      logs: logs ?? this.logs,
      gasUsed: gasUsed ?? this.gasUsed,
      fee: fee ?? this.fee,
      senderShard: senderShard ?? this.senderShard,
      receiverShard: receiverShard ?? this.receiverShard,
      round: round ?? this.round,
      epoch: epoch ?? this.epoch,
      miniBlockHash: miniBlockHash ?? this.miniBlockHash,
      senderUsername: senderUsername ?? this.senderUsername,
      receiverUsername: receiverUsername ?? this.receiverUsername,
      action: action ?? this.action,
      operations: operations ?? this.operations,
      type: type ?? this.type,
      originalTxHash: originalTxHash ?? this.originalTxHash,
      pendingResults: pendingResults ?? this.pendingResults,
      guardianAddress: guardianAddress ?? this.guardianAddress,
      guardianSignature: guardianSignature ?? this.guardianSignature,
      isRelayed: isRelayed ?? this.isRelayed,
      relayer: relayer ?? this.relayer,
      relayerSignature: relayerSignature ?? this.relayerSignature,
      isScCall: isScCall ?? this.isScCall,
      scamInfo: scamInfo ?? this.scamInfo,
      price: price ?? this.price,
      relayedVersion: relayedVersion ?? this.relayedVersion,
      senderAssets: senderAssets ?? this.senderAssets,
      receiverAssets: receiverAssets ?? this.receiverAssets,
      completedAt: completedAt ?? this.completedAt,
      initiallyPaidFee: initiallyPaidFee ?? this.initiallyPaidFee,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionOnNetwork && txHash == other.txHash;
  }

  @override
  int get hashCode => txHash.hashCode;

  @override
  String toString() {
    return 'TransactionOnNetwork('
        'hash: $txHash, '
        'status: ${status.status}, '
        'block: $blockNonce, '
        'round: $round, '
        'epoch: $epoch, '
        'shard: $senderShard->$receiverShard, '
        'gasUsed: $gasUsed, '
        'fee: $fee, '
        'sender: ${sender.bech32}, '
        'receiver: ${receiver.bech32}'
        ')';
  }
}
