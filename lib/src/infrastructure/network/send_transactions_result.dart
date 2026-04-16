/// Outcome for a single tx inside a bulk send.
sealed class SendTxOutcome {
  const SendTxOutcome(this.index);

  /// 0-based index into the original request list.
  final int index;
}

/// Successful broadcast: the node accepted the transaction and returned [hash].
final class SendTxSuccess extends SendTxOutcome {
  const SendTxSuccess(super.index, this.hash);
  final String hash;
}

/// Failed broadcast: the node rejected the transaction.
final class SendTxFailure extends SendTxOutcome {
  const SendTxFailure(super.index, {this.reason});

  /// Node-provided reason, when present (e.g. "insufficient gas", "invalid
  /// signature"). `null` if the transaction never reached the node.
  final String? reason;
}

/// Result of broadcasting multiple transactions in one call.
///
/// Both the aggregate counts and per-transaction outcomes are exposed so
/// callers can drive a resubmission loop without rebuilding the list.
class SendTransactionsResult {
  /// Creates send transactions result with counts, hashes, and outcomes.
  const SendTransactionsResult({
    required this.numSent,
    required this.txHashes,
    this.outcomes = const <SendTxOutcome>[],
  });

  /// Number of transactions the node accepted.
  final int numSent;

  /// Transaction hashes aligned with the input list (null for failed items).
  final List<String?> txHashes;

  /// Per-transaction outcome, one entry per submitted tx. Empty for providers
  /// that do not surface per-tx errors; callers should fall back to
  /// [txHashes] in that case.
  final List<SendTxOutcome> outcomes;

  /// Successful transaction hashes only.
  List<String> get successfulHashes {
    return txHashes.whereType<String>().toList();
  }

  /// Number of failed broadcasts.
  int get numFailed => txHashes.length - numSent;

  /// Failed outcomes only (empty when per-tx outcomes are not available).
  List<SendTxFailure> get failures =>
      outcomes.whereType<SendTxFailure>().toList();

  @override
  String toString() =>
      'SendTransactionsResult('
      'sent: $numSent/${txHashes.length}, '
      'failed: $numFailed)';
}
