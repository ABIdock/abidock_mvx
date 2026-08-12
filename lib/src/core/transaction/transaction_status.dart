import '../../utils/helpers.dart';

/// Transaction execution status on the blockchain.
/// Represents transaction state: pending, executed, success, failed, or invalid.
///
/// #### Example
/// ```dart
/// final txOnNetwork = await networkProvider.getTransaction(txHash);
/// final status = txOnNetwork.status;
///
/// if (status.isPending) {
///   print('Transaction is pending');
/// } else if (status.isSuccessful) {
///   print('Transaction succeeded!');
/// } else if (status.isFailed) {
///   print('Transaction failed');
/// }
///
/// while (!status.isFinal) {
///   await Future.delayed(Duration(seconds: 1));
///   txOnNetwork = await networkProvider.getTransaction(txHash);
///   status = txOnNetwork.status;
/// }
/// ```
class TransactionStatus {
  /// Creates transaction status.
  ///
  /// #### Parameters
  /// - `status` - Status string from API (case-insensitive)
  ///
  /// #### Example
  /// ```dart
  /// final status = TransactionStatus('success');
  ///
  /// final apiStatus = TransactionStatus(response['status']);
  ///
  /// final pending = TransactionStatus.pending;
  /// final success = TransactionStatus.success;
  /// ```
  const TransactionStatus(this.status);

  /// Creates status from network API response.
  ///
  /// #### Parameters
  /// - `data` - JSON response with 'status' field
  ///
  /// #### Returns
  /// `TransactionStatus` - Instance with parsed status
  factory TransactionStatus.fromHttpResponse(Map<String, dynamic> data) {
    return TransactionStatus(requireAs<String>(data['status'], 'status'));
  }

  /// Transaction is pending execution.
  static const TransactionStatus pending = TransactionStatus('pending');

  /// Transaction was received by the network (mempool); not yet executed.
  ///
  /// Treated as pending for the watcher.
  static const TransactionStatus received = TransactionStatus('received');

  /// Transaction was successfully executed.
  static const TransactionStatus executed = TransactionStatus('executed');

  /// Transaction succeeded (alias of `executed`).
  static const TransactionStatus success = TransactionStatus('success');

  /// Transaction was successful (Gateway/Proxy variant).
  static const TransactionStatus successful = TransactionStatus('successful');

  /// Transaction execution failed (short variant emitted by some endpoints).
  static const TransactionStatus fail = TransactionStatus('fail');

  /// Transaction execution failed.
  static const TransactionStatus failed = TransactionStatus('failed');

  /// Transaction was unsuccessful (Gateway variant; equivalent to `failed`).
  static const TransactionStatus unsuccessful = TransactionStatus(
    'unsuccessful',
  );

  /// Transaction is invalid — rejected by the node before execution.
  static const TransactionStatus invalid = TransactionStatus('invalid');

  /// Transaction was not executed as part of the block it was proposed in.
  ///
  /// Supernova-only status: the node emits it when a transaction appears in a
  /// proposed block but is absent from that block's execution result. Neither
  /// successful nor failed — see [isNotExecutableInBlock].
  static const TransactionStatus notExecutableInBlock = TransactionStatus(
    'not-executable-in-block',
  );

  /// Reward transaction was reverted.
  static const TransactionStatus rewardReverted = TransactionStatus(
    'reward-reverted',
  );

  /// Proxy could not determine the status from any observer.
  static const TransactionStatus unknown = TransactionStatus('unknown');

  /// Raw status string from blockchain.
  final String status;

  /// Checks if transaction is pending.
  ///
  /// True while the transaction has not reached a final state: `pending` and
  /// `received` (mempool intake) are both non-final wire strings.
  ///
  /// #### Returns
  /// `bool` - True if status is `pending` or `received`
  bool get isPending {
    final String lowered = status.toLowerCase();
    return lowered == 'pending' || lowered == 'received';
  }

  /// Checks if transaction was executed successfully.
  ///
  /// `executed`, `success` and `successful` are the three success strings
  /// used across node, Gateway and Proxy responses.
  ///
  /// #### Returns
  /// `bool` - True if status is `executed`, `success` or `successful`
  bool get isExecuted {
    final String lowered = status.toLowerCase();
    return lowered == 'executed' ||
        lowered == 'success' ||
        lowered == 'successful';
  }

  /// Checks if transaction failed.
  ///
  /// `fail`, `failed` and `unsuccessful` are the failure strings emitted
  /// across node, Gateway and Proxy responses. `invalid` — a transaction the
  /// node rejected before execution — counts as a failure too, so a watcher
  /// does not stall on it.
  ///
  /// #### Returns
  /// `bool` - True if status is `fail`, `failed`, `unsuccessful` or `invalid`
  bool get isFailed {
    final String lowered = status.toLowerCase();
    return lowered == 'fail' ||
        lowered == 'failed' ||
        lowered == 'unsuccessful' ||
        isInvalid;
  }

  /// Checks if transaction is invalid.
  ///
  /// #### Returns
  /// `bool` - True if status is `invalid`
  bool get isInvalid => status.toLowerCase() == 'invalid';

  /// Checks if transaction was not executable in its block.
  ///
  /// Reported for a transaction that was part of a proposed block but missing
  /// from that block's execution result. It is neither a success nor a
  /// failure, so it is excluded from [isCompleted]; [isFinal] still covers it
  /// because the status itself will not change again.
  ///
  /// #### Returns
  /// `bool` - True if status is `not-executable-in-block`
  bool get isNotExecutableInBlock =>
      status.toLowerCase() == 'not-executable-in-block';

  /// Checks if transaction has reached any terminal state.
  ///
  /// Terminal = `isExecuted || isFailed || isNotExecutableInBlock`.
  /// `isInvalid` is covered transitively through `isFailed`. Broader than
  /// [isCompleted], which stops at success or failure.
  ///
  /// #### Returns
  /// `bool` - True if transaction will not change status again
  bool get isFinal => isExecuted || isFailed || isNotExecutableInBlock;

  /// Checks if transaction reached a completed state.
  ///
  /// Completion means the transaction was executed by the chain and produced
  /// an outcome: success or failure only. `not-executable-in-block` is
  /// deliberately excluded — such a transaction carries no logs and no smart
  /// contract results. Check [isNotExecutableInBlock] separately, or use
  /// [isFinal] for the broader "will not change again" predicate.
  ///
  /// #### Returns
  /// `bool` - True if status is a success or a failure string
  bool get isCompleted => isExecuted || isFailed;

  /// Checks if transaction completed successfully.
  ///
  /// #### Returns
  /// `bool` - True if transaction executed successfully
  bool get isSuccessful => isExecuted;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionStatus &&
        status.toLowerCase() == other.status.toLowerCase();
  }

  @override
  int get hashCode => status.toLowerCase().hashCode;

  @override
  String toString() => 'TransactionStatus($status)';
}
