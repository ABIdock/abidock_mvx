/// Result of broadcasting multiple transactions to the network.
/// Tracks success and failure counts with transaction hashes.
class SendTransactionsResult {
  /// Creates send transactions result with counts and hashes.
  ///
  /// #### Parameters
  /// - `numSent` - Number of transactions successfully sent
  /// - `txHashes` - List of transaction hashes (null for failed transactions)
  const SendTransactionsResult({required this.numSent, required this.txHashes});

  /// Number of transactions successfully sent.
  final int numSent;

  /// Transaction hashes (null for failed transactions).
  final List<String?> txHashes;

  /// Gets list of successful transaction hashes.
  List<String> get successfulHashes {
    return txHashes.whereType<String>().toList();
  }

  /// Gets count of failed transaction submissions.
  int get numFailed => txHashes.length - numSent;

  @override
  String toString() =>
      'SendTransactionsResult('
      'sent: $numSent/${txHashes.length}, '
      'failed: $numFailed)';
}
