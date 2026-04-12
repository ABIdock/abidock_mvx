import '../../utils/helpers.dart';

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
  /// - `timestamp` - Unix timestamp (optional)
  /// - `numTxs` - Number of transactions in the block (optional)
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
    this.numTxs,
  });

  /// Parses from a network response map.
  ///
  /// Accepts both API (`api.multiversx.com`) and Gateway (`/block/by-hash/...`)
  /// shapes by looking up the common field aliases.
  factory BlockOnNetwork.fromJson(Map<String, dynamic> data) {
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
          optionalAs<String>(data['previousBlockHash'], 'previousBlockHash'),
      timestamp: optionalInt(data['timestamp'], 'timestamp'),
      numTxs:
          optionalInt(data['txCount'], 'txCount') ??
          optionalInt(data['numTxs'], 'numTxs'),
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

  /// Unix timestamp, if reported.
  final int? timestamp;

  /// Number of transactions in the block, if reported.
  final int? numTxs;

  /// Raw response map for access to provider-specific fields.
  final Map<String, dynamic> raw;

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
  /// - `timestamp` - Unix timestamp (optional)
  /// - `numTxs` - Number of transactions (optional)
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
    this.numTxs,
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
      numTxs:
          optionalInt(data['numTxs'], 'numTxs') ??
          (txHashes.isEmpty ? null : txHashes.length),
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

  /// Unix timestamp, if reported.
  final int? timestamp;

  /// Number of transactions, if reported.
  final int? numTxs;

  /// Raw response map for access to provider-specific fields.
  final Map<String, dynamic> raw;

  @override
  String toString() =>
      'HyperblockOnNetwork(nonce: $nonce, hash: $hash, txs: ${transactionHashes.length})';
}
