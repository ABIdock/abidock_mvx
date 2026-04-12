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
  ///
  /// #### Example
  /// ```dart
  /// if (txStatus == TransactionStatus.pending) {
  ///   print('Waiting for validators to process...');
  /// }
  /// ```
  static const TransactionStatus pending = TransactionStatus('pending');

  /// Transaction was successfully executed.
  ///
  /// #### Example
  /// ```dart
  /// if (txStatus == TransactionStatus.executed) {
  ///   print('Transaction executed successfully');
  /// }
  /// ```
  static const TransactionStatus executed = TransactionStatus('executed');

  /// Transaction is invalid.
  ///
  /// #### Example
  /// ```dart
  /// if (txStatus == TransactionStatus.invalid) {
  ///   print('Transaction has invalid fields or signature');
  /// }
  /// ```
  static const TransactionStatus invalid = TransactionStatus('invalid');

  /// Transaction execution failed.
  ///
  /// #### Example
  /// ```dart
  /// if (txStatus == TransactionStatus.failed) {
  ///   print('Transaction execution failed');
  ///   // Check logs for error details
  /// }
  /// ```
  static const TransactionStatus failed = TransactionStatus('failed');

  /// Transaction succeeded.
  ///
  /// #### Example
  /// ```dart
  /// if (txStatus == TransactionStatus.success) {
  ///   print('Transaction completed successfully');
  /// }
  /// ```
  static const TransactionStatus success = TransactionStatus('success');

  /// Transaction was not executable in its block.
  ///
  /// Indicates the transaction was proposed but could not be executed.
  /// This is NOT a final state — the transaction may be retried in a
  /// subsequent block.
  ///
  /// #### Example
  /// ```dart
  /// if (txStatus == TransactionStatus.notExecutable) {
  ///   print('Transaction not executable in this block, will be retried');
  /// }
  /// ```
  static const TransactionStatus notExecutable = TransactionStatus(
    'not-executable-in-block',
  );

  /// Transaction was recalled (relayed v3 / future protocol support).
  ///
  /// #### Example
  /// ```dart
  /// if (txStatus == TransactionStatus.recalled) {
  ///   print('Transaction was recalled by relayer');
  /// }
  /// ```
  static const TransactionStatus recalled = TransactionStatus('recalled');

  /// Raw status string from blockchain.
  final String status;

  /// Checks if transaction is pending.
  ///
  /// #### Returns
  /// `bool` - True if status is 'pending'
  ///
  /// #### Example
  /// ```dart
  /// if (status.isPending) {
  ///   print('Transaction not yet processed');
  ///   await Future.delayed(Duration(seconds: 1));
  /// }
  /// ```
  bool get isPending => status.toLowerCase() == 'pending';

  /// Checks if transaction was executed.
  ///
  /// #### Returns
  /// `bool` - True if status is 'executed' or 'success'
  ///
  /// #### Example
  /// ```dart
  /// if (status.isExecuted) {
  ///   print('Transaction executed in block');
  ///   // Process results
  /// }
  /// ```
  bool get isExecuted {
    final String lowerStatus = status.toLowerCase();
    return lowerStatus == 'executed' || lowerStatus == 'success';
  }

  /// Checks if transaction failed.
  ///
  /// #### Returns
  /// `bool` - True if status is 'failed'
  ///
  /// #### Example
  /// ```dart
  /// if (status.isFailed) {
  ///   print('Transaction execution failed');
  ///   // Check transaction logs for error message
  ///   final logs = txOnNetwork.logs;
  ///   if (logs != null) {
  ///     for (final event in logs.events) {
  ///       if (event.identifier == 'signalError') {
  ///         print('Error: ${event.topics}');
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  bool get isFailed => status.toLowerCase() == 'failed';

  /// Checks if transaction is invalid.
  ///
  /// #### Returns
  /// `bool` - True if status is 'invalid'
  ///
  /// #### Example
  /// ```dart
  /// if (status.isInvalid) {
  ///   print('Transaction rejected - check signature and fields');
  /// }
  /// ```
  bool get isInvalid => status.toLowerCase() == 'invalid';

  /// Checks if transaction was not executable in its block.
  ///
  /// This is NOT a final state. The transaction may be retried in a
  /// subsequent block by the protocol.
  ///
  /// #### Returns
  /// `bool` - True if status is 'not-executable-in-block'
  bool get isNotExecutableInBlock =>
      status.toLowerCase() == 'not-executable-in-block';

  /// Checks if transaction was recalled.
  ///
  /// #### Returns
  /// `bool` - True if status is 'recalled'
  bool get isRecalled => status.toLowerCase() == 'recalled';

  /// Checks if transaction has completed.
  ///
  /// #### Returns
  /// `bool` - True if transaction reached final state
  ///
  /// #### Example
  /// ```dart
  /// while (!status.isFinal) {
  ///   await Future.delayed(Duration(seconds: 1));
  ///   final tx = await networkProvider.getTransaction(txHash);
  ///   status = tx.status;
  /// }
  /// print('Transaction finalized');
  /// ```
  bool get isFinal => isExecuted || isFailed || isInvalid || isRecalled;

  /// Checks if transaction completed successfully.
  ///
  /// #### Returns
  /// `bool` - True if transaction executed successfully
  ///
  /// #### Example
  /// ```dart
  /// if (status.isSuccessful) {
  ///   print('Transaction succeeded!');
  ///   // Parse smart contract results
  ///   final results = txOnNetwork.smartContractResults;
  /// } else {
  ///   print('Transaction did not succeed');
  /// }
  /// ```
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
