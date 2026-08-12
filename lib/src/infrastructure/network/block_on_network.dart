import '../../utils/helpers.dart';
import 'network_status.dart';

/// Collapses a missing hash and an explicitly empty one into `null`.
///
/// Hash fields that a provider always serialises report "nothing here" as an
/// empty string rather than by omitting the key, so both spellings have to mean
/// the same thing to callers.
String? _hashOrNull(String? value) =>
    value == null || value.isEmpty ? null : value;

/// Block metadata as observed on the MultiversX network.
///
/// Returned by [NetworkProvider.getBlock] and [NetworkProvider.getLatestBlock].
/// Holds shard-block level data: nonce, hash, epoch/round, shard and basic
/// cross-reference fields. The raw API response is preserved in [raw] so
/// callers can reach fields not surfaced as named getters.
///
/// #### Example
/// ```dart
/// final block = await provider.getLatestBlock(shard: 1);
/// print('Shard ${block.shard} — nonce ${block.nonce}');
/// print('Hash: ${block.hash}');
/// print('Previous hash: ${block.previousHash}');
/// ```
class BlockOnNetwork {
  /// Creates a [BlockOnNetwork].
  ///
  /// #### Parameters
  /// - `hash` - Block hash (hex)
  /// - `nonce` - Block nonce within its shard
  /// - `round` - Consensus round
  /// - `epoch` - Epoch number
  /// - `shard` - Shard ID (metachain is `4294967295`)
  /// - `previousHash` - Parent block hash (optional)
  /// - `timestamp` - Block timestamp in seconds (optional)
  /// - `timestampMs` - Block timestamp in milliseconds (optional)
  /// - `numTxs` - Number of transactions in the block (optional)
  /// - `stateRootHash` - State trie root hash the block reports (optional)
  /// - `lastExecutionResultHash` - Hash of the block whose execution result
  ///   this block notarises (optional)
  /// - `lastExecutionResultNonce` - Nonce of that same block (optional)
  /// - `raw` - Raw API response map
  const BlockOnNetwork({
    required this.hash,
    required this.nonce,
    required this.round,
    required this.epoch,
    required this.shard,
    required this.raw,
    this.previousHash,
    this.timestamp,
    this.timestampMs,
    this.numTxs,
    this.stateRootHash,
    this.lastExecutionResultHash,
    this.lastExecutionResultNonce,
  });

  /// Parses from a network response map.
  ///
  /// Accepts both API (`api.multiversx.com`) and Gateway (`/block/by-hash/...`)
  /// shapes by looking up the common field aliases. The back-reference to the
  /// last notarised execution result is read from the flat
  /// `lastExecutionResultHash` / `lastExecutionResultNonce` pair and, failing
  /// that, from the nested `lastExecutionResult` object's `headerHash` /
  /// `headerNonce`.
  factory BlockOnNetwork.fromJson(Map<String, dynamic> data) {
    final Map<String, dynamic>? executionResult =
        optionalAs<Map<String, dynamic>>(
          data['lastExecutionResult'],
          'lastExecutionResult',
        );
    final String? executionResultHash = _hashOrNull(
      optionalAs<String>(
            data['lastExecutionResultHash'],
            'lastExecutionResultHash',
          ) ??
          optionalAs<String>(executionResult?['headerHash'], 'headerHash'),
    );

    return BlockOnNetwork(
      hash:
          optionalAs<String>(data['hash'], 'hash') ??
          optionalAs<String>(data['blockHash'], 'blockHash') ??
          '',
      nonce:
          optionalInt(data['nonce'], 'nonce') ??
          optionalInt(data['blockNonce'], 'blockNonce') ??
          0,
      round: optionalInt(data['round'], 'round') ?? 0,
      epoch: optionalInt(data['epoch'], 'epoch') ?? 0,
      shard:
          optionalInt(data['shard'], 'shard') ??
          optionalInt(data['shardId'], 'shardId') ??
          optionalInt(data['shardID'], 'shardID') ??
          0,
      previousHash:
          optionalAs<String>(data['prevHash'], 'prevHash') ??
          optionalAs<String>(data['prevBlockHash'], 'prevBlockHash') ??
          optionalAs<String>(data['previousBlockHash'], 'previousBlockHash'),
      timestamp: optionalInt(data['timestamp'], 'timestamp'),
      timestampMs: optionalInt(data['timestampMs'], 'timestampMs'),
      numTxs:
          optionalInt(data['txCount'], 'txCount') ??
          optionalInt(data['numTxs'], 'numTxs'),
      stateRootHash: _hashOrNull(
        optionalAs<String>(data['stateRootHash'], 'stateRootHash'),
      ),
      lastExecutionResultHash: executionResultHash,
      lastExecutionResultNonce: executionResultHash == null
          ? null
          : optionalInt(
                  data['lastExecutionResultNonce'],
                  'lastExecutionResultNonce',
                ) ??
                optionalInt(executionResult?['headerNonce'], 'headerNonce'),
      raw: data,
    );
  }

  /// Block hash (hex).
  final String hash;

  /// Block nonce within its shard.
  final int nonce;

  /// Consensus round.
  final int round;

  /// Epoch number.
  final int epoch;

  /// Shard ID (metachain is `4294967295`).
  final int shard;

  /// Parent block hash.
  final String? previousHash;

  /// Block timestamp in seconds, if reported.
  ///
  /// Block routes report this field in seconds on both sides of the
  /// millisecond-granularity upgrade: once block headers started carrying
  /// milliseconds, the node divides the header value down before serving it
  /// here and serves the millisecond value as [timestampMs]. Prefer
  /// [producedAt], which does not depend on that promise holding.
  final int? timestamp;

  /// Block timestamp in milliseconds, if reported.
  ///
  /// Absent when the provider does not report one: the field is omitted when
  /// it would be zero, and blocks indexed before it existed carry only
  /// [timestamp].
  final int? timestampMs;

  /// Number of transactions in the block, if reported.
  final int? numTxs;

  /// State trie root hash the block reports, or `null` when it reports none.
  ///
  /// Blocks in the asynchronous-execution format carry no root hash of their
  /// own, because proposing a block and executing its transactions are separate
  /// steps. What the node serves for such a block is the root hash produced by
  /// the last execution result the block notarises — the state reached after an
  /// *earlier* block, the one named by [lastExecutionResultHash] and
  /// [lastExecutionResultNonce]. The value degrades to an empty string when the
  /// node cannot resolve that result, and is surfaced here as `null`.
  final String? stateRootHash;

  /// Hash of the block whose execution result this block notarises.
  ///
  /// Under asynchronous execution a block is proposed before the transactions
  /// of earlier blocks have finished executing, so each block carries a
  /// back-reference to the most recent block whose execution result has been
  /// notarised. `null` for blocks that carry no such reference, which is how
  /// every block in the synchronous-execution format reports.
  final String? lastExecutionResultHash;

  /// Nonce of the block named by [lastExecutionResultHash].
  ///
  /// `null` exactly when [lastExecutionResultHash] is `null`: the two are the
  /// halves of a single back-reference, and a nonce without its hash does not
  /// identify a block.
  final int? lastExecutionResultNonce;

  /// Raw response map for access to provider-specific fields.
  final Map<String, dynamic> raw;

  /// Instant at which the block was produced, normalised to UTC.
  ///
  /// Prefers [timestampMs] and falls back to [timestamp], deciding the unit of
  /// whichever value it uses by magnitude via [ChainTimestamp], so a
  /// millisecond value is never read as seconds.
  ///
  /// #### Returns
  /// `DateTime?` - UTC instant, or `null` when the provider reported neither
  /// timestamp
  ///
  /// #### Example
  /// ```dart
  /// final BlockOnNetwork block = await provider.getLatestBlock();
  /// print('Produced at ${block.producedAt}');
  /// ```
  DateTime? get producedAt =>
      ChainTimestamp.toDateTime(timestampMs ?? timestamp);

  @override
  String toString() =>
      'BlockOnNetwork(shard: $shard, nonce: $nonce, hash: $hash)';
}

/// Hyperblock — a cross-shard finalized block.
///
/// A hyperblock is a metablock with all shard miniblocks merged in, providing
/// a point-in-time snapshot that is final across the whole network. It is
/// returned by [NetworkProvider.getHyperblock] and is typically used when
/// reconciling state across shards or auditing cross-shard execution.
///
/// #### Example
/// ```dart
/// final hb = await provider.getHyperblock(12345);
/// print('Hyperblock ${hb.nonce} — ${hb.numTxs} transactions');
/// for (final txHash in hb.transactionHashes) {
///   final tx = await provider.getTransaction(txHash);
///   // ...
/// }
/// ```
class HyperblockOnNetwork {
  /// Creates a [HyperblockOnNetwork].
  ///
  /// #### Parameters
  /// - `hash` - Hyperblock hash (hex)
  /// - `nonce` - Hyperblock nonce
  /// - `round` - Consensus round
  /// - `epoch` - Epoch number
  /// - `shardBlocks` - Shard blocks merged into this hyperblock
  /// - `transactionHashes` - Hashes of all included transactions
  /// - `timestamp` - Hyperblock timestamp in seconds (optional)
  /// - `timestampMs` - Hyperblock timestamp in milliseconds (optional)
  /// - `numTxs` - Number of transactions (optional)
  /// - `stateRootHash` - State trie root hash the metablock reports (optional)
  /// - `raw` - Raw API response map
  const HyperblockOnNetwork({
    required this.hash,
    required this.nonce,
    required this.round,
    required this.epoch,
    required this.shardBlocks,
    required this.transactionHashes,
    required this.raw,
    this.timestamp,
    this.timestampMs,
    this.numTxs,
    this.stateRootHash,
  });

  /// Parses from a gateway `/hyperblock/by-nonce/...` response.
  factory HyperblockOnNetwork.fromJson(Map<String, dynamic> data) {
    final List<String> shardBlocks = <String>[];
    final dynamic shardBlocksRaw = data['shardBlocks'];
    if (shardBlocksRaw is List) {
      for (final dynamic entry in shardBlocksRaw) {
        if (entry is Map<String, dynamic>) {
          final String? hash =
              optionalAs<String>(entry['hash'], 'hash') ??
              optionalAs<String>(entry['blockHash'], 'blockHash');
          if (hash != null) shardBlocks.add(hash);
        } else if (entry is String) {
          shardBlocks.add(entry);
        }
      }
    }

    final List<String> txHashes = <String>[];
    final dynamic txsRaw = data['transactions'];
    if (txsRaw is List) {
      for (final dynamic entry in txsRaw) {
        if (entry is Map<String, dynamic>) {
          final String? hash =
              optionalAs<String>(entry['hash'], 'hash') ??
              optionalAs<String>(entry['txHash'], 'txHash');
          if (hash != null) txHashes.add(hash);
        } else if (entry is String) {
          txHashes.add(entry);
        }
      }
    }

    return HyperblockOnNetwork(
      hash: optionalAs<String>(data['hash'], 'hash') ?? '',
      nonce: optionalInt(data['nonce'], 'nonce') ?? 0,
      round: optionalInt(data['round'], 'round') ?? 0,
      epoch: optionalInt(data['epoch'], 'epoch') ?? 0,
      shardBlocks: shardBlocks,
      transactionHashes: txHashes,
      timestamp: optionalInt(data['timestamp'], 'timestamp'),
      timestampMs: optionalInt(data['timestampMs'], 'timestampMs'),
      numTxs:
          optionalInt(data['numTxs'], 'numTxs') ??
          (txHashes.isEmpty ? null : txHashes.length),
      stateRootHash: _hashOrNull(
        optionalAs<String>(data['stateRootHash'], 'stateRootHash'),
      ),
      raw: data,
    );
  }

  /// Hyperblock hash (hex).
  final String hash;

  /// Hyperblock nonce.
  final int nonce;

  /// Consensus round.
  final int round;

  /// Epoch number.
  final int epoch;

  /// Hashes of the shard blocks merged into this hyperblock.
  final List<String> shardBlocks;

  /// Hashes of every transaction included in this hyperblock.
  final List<String> transactionHashes;

  /// Hyperblock timestamp in seconds, if reported.
  ///
  /// Carries the timestamp of the metablock the hyperblock was built from, in
  /// seconds. Prefer [producedAt].
  final int? timestamp;

  /// Hyperblock timestamp in milliseconds, if reported.
  ///
  /// Carries the timestamp of the metablock the hyperblock was built from, in
  /// milliseconds. Omitted when it would be zero.
  final int? timestampMs;

  /// Number of transactions, if reported.
  final int? numTxs;

  /// State trie root hash the underlying metablock reports, or `null` when it
  /// reports none.
  ///
  /// Inherits the behaviour of [BlockOnNetwork.stateRootHash]: for a metablock
  /// in the asynchronous-execution format this is the root hash of the last
  /// execution result the metablock notarises, not of the metablock itself.
  final String? stateRootHash;

  /// Raw response map for access to provider-specific fields.
  final Map<String, dynamic> raw;

  /// Instant at which the hyperblock was produced, normalised to UTC.
  ///
  /// Prefers [timestampMs] and falls back to [timestamp], deciding the unit of
  /// whichever value it uses by magnitude via [ChainTimestamp].
  ///
  /// #### Returns
  /// `DateTime?` - UTC instant, or `null` when the provider reported neither
  /// timestamp
  ///
  /// #### Example
  /// ```dart
  /// final HyperblockOnNetwork hyperblock = await provider.getHyperblock(1);
  /// print('Produced at ${hyperblock.producedAt}');
  /// ```
  DateTime? get producedAt =>
      ChainTimestamp.toDateTime(timestampMs ?? timestamp);

  @override
  String toString() =>
      'HyperblockOnNetwork(nonce: $nonce, hash: $hash, txs: ${transactionHashes.length})';
}
