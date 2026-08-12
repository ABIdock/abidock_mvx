/// Tests for the asynchronous-execution and millisecond-timestamp fields on
/// [BlockOnNetwork] and [HyperblockOnNetwork].
///
/// Fixtures are literal JSON shaped like the real responses: the public API
/// spells the execution-result back-reference flat, the gateway nests it under
/// a `lastExecutionResult` object, and only the gateway guarantees both
/// timestamp halves.
library;

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('BlockOnNetwork execution-result back-reference', () {
    test('reads the flat lastExecutionResult* pair from the API shape', () {
      final BlockOnNetwork block = BlockOnNetwork.fromJson(<String, dynamic>{
        'hash':
            '99fcd63076e5f561501666d0d31cbe0b7fa8437167b767dc27f954834a65a50a',
        'epoch': 1000,
        'nonce': 14553815,
        'prevHash':
            '5b5528f1c8266af2cd73ff178ac7fdedf267f8f09df8d45f7dc0c537bbb9827a',
        'round': 14574008,
        'shard': 4294967295,
        'stateRootHash':
            '683c040b7e20e1e26b82b96c9ae7071b58b073022da43e32cc0326fc769d44b6',
        'timestamp': 1683561648,
        'txCount': 3,
        'lastExecutionResultHash':
            '414d526161587ae9f53453aa0392971272c48dbb3cc54a33448972d388e0deeb',
        'lastExecutionResultNonce': 14553814,
      });

      expect(
        block.lastExecutionResultHash,
        '414d526161587ae9f53453aa0392971272c48dbb3cc54a33448972d388e0deeb',
      );
      expect(block.lastExecutionResultNonce, 14553814);
      expect(
        block.stateRootHash,
        '683c040b7e20e1e26b82b96c9ae7071b58b073022da43e32cc0326fc769d44b6',
      );
    });

    test('reads the nested lastExecutionResult object from the gateway '
        'shape', () {
      final BlockOnNetwork block = BlockOnNetwork.fromJson(<String, dynamic>{
        'nonce': 512,
        'round': 520,
        'epoch': 3,
        'shard': 1,
        'numTxs': 7,
        'hash': 'ab',
        'prevBlockHash': 'aa',
        'stateRootHash': 'cc',
        'lastExecutionResult': <String, dynamic>{
          'headerHash': 'dd',
          'headerNonce': 509,
          'headerRound': 517,
          'headerEpoch': 3,
          'rootHash': 'cc',
          'receiptsHash': '',
          'executedTxCount': 7,
        },
      });

      expect(block.lastExecutionResultHash, 'dd');
      expect(block.lastExecutionResultNonce, 509);
      expect(block.stateRootHash, 'cc');
    });

    test('flat pair wins over the nested object when both are present', () {
      final BlockOnNetwork block = BlockOnNetwork.fromJson(<String, dynamic>{
        'nonce': 1,
        'lastExecutionResultHash': 'flat',
        'lastExecutionResultNonce': 11,
        'lastExecutionResult': <String, dynamic>{
          'headerHash': 'nested',
          'headerNonce': 22,
        },
      });

      expect(block.lastExecutionResultHash, 'flat');
      expect(block.lastExecutionResultNonce, 11);
    });

    test('empty flat hash with a zero nonce reports no back-reference', () {
      final BlockOnNetwork block = BlockOnNetwork.fromJson(<String, dynamic>{
        'hash': 'ab',
        'nonce': 42,
        'lastExecutionResultHash': '',
        'lastExecutionResultNonce': 0,
      });

      expect(block.lastExecutionResultHash, isNull);
      expect(block.lastExecutionResultNonce, isNull);
    });

    test('absent keys report no back-reference', () {
      final BlockOnNetwork block = BlockOnNetwork.fromJson(<String, dynamic>{
        'hash': 'ab',
        'nonce': 42,
      });

      expect(block.lastExecutionResultHash, isNull);
      expect(block.lastExecutionResultNonce, isNull);
    });
  });

  group('BlockOnNetwork.stateRootHash', () {
    test('is null when the node serves an empty string', () {
      final BlockOnNetwork block = BlockOnNetwork.fromJson(<String, dynamic>{
        'hash': 'ab',
        'nonce': 9,
        'stateRootHash': '',
      });

      expect(block.stateRootHash, isNull);
    });

    test('is null when the key is absent', () {
      final BlockOnNetwork block = BlockOnNetwork.fromJson(<String, dynamic>{
        'hash': 'ab',
        'nonce': 9,
      });

      expect(block.stateRootHash, isNull);
    });
  });

  group('BlockOnNetwork timestamps', () {
    test('keeps both halves verbatim and dates from the millisecond one', () {
      final BlockOnNetwork block = BlockOnNetwork.fromJson(<String, dynamic>{
        'hash': 'ab',
        'nonce': 9,
        'timestamp': 1766062438,
        'timestampMs': 1766062438750,
      });

      expect(block.timestamp, 1766062438);
      expect(block.timestampMs, 1766062438750);
      expect(block.producedAt, DateTime.utc(2025, 12, 18, 12, 53, 58, 750));
      expect(block.producedAt!.millisecondsSinceEpoch, 1766062438750);
    });

    test('promotes a seconds-only timestamp to milliseconds', () {
      final BlockOnNetwork block = BlockOnNetwork.fromJson(<String, dynamic>{
        'hash': 'ab',
        'nonce': 9,
        'timestamp': 1683561648,
      });

      expect(block.timestampMs, isNull);
      expect(block.producedAt!.millisecondsSinceEpoch, 1683561648000);
      expect(block.producedAt, DateTime.utc(2023, 5, 8, 16, 0, 48));
    });

    test('never reads a millisecond value as seconds', () {
      final BlockOnNetwork block = BlockOnNetwork.fromJson(<String, dynamic>{
        'hash': 'ab',
        'nonce': 9,
        'timestamp': 1766062438750,
      });

      expect(block.producedAt!.year, 2025);
      expect(block.producedAt!.millisecondsSinceEpoch, 1766062438750);
    });

    test('is null when neither timestamp is reported', () {
      final BlockOnNetwork block = BlockOnNetwork.fromJson(<String, dynamic>{
        'hash': 'ab',
        'nonce': 9,
      });

      expect(block.timestamp, isNull);
      expect(block.timestampMs, isNull);
      expect(block.producedAt, isNull);
    });

    test('treats a zero timestamp as not reported', () {
      final BlockOnNetwork block = BlockOnNetwork.fromJson(<String, dynamic>{
        'hash': 'ab',
        'nonce': 9,
        'timestamp': 0,
        'timestampMs': 0,
      });

      expect(block.timestamp, 0);
      expect(block.timestampMs, 0);
      expect(block.producedAt, isNull);
    });
  });

  group('HyperblockOnNetwork Supernova fields', () {
    test('parses timestampMs and stateRootHash from the gateway shape', () {
      final HyperblockOnNetwork hyperblock = HyperblockOnNetwork.fromJson(
        <String, dynamic>{
          'hash': 'hb',
          'prevBlockHash': 'hbprev',
          'stateRootHash': 'ee11',
          'nonce': 42,
          'round': 420,
          'epoch': 7,
          'numTxs': 2,
          'timestamp': 1766062438,
          'timestampMs': 1766062438750,
          'shardBlocks': <Map<String, dynamic>>[
            <String, dynamic>{'hash': 'sb0', 'shard': 0, 'rootHash': 'r0'},
          ],
          'transactions': <Map<String, dynamic>>[
            <String, dynamic>{'hash': 'tx1'},
            <String, dynamic>{'hash': 'tx2'},
          ],
        },
      );

      expect(hyperblock.timestamp, 1766062438);
      expect(hyperblock.timestampMs, 1766062438750);
      expect(hyperblock.stateRootHash, 'ee11');
      expect(hyperblock.producedAt!.millisecondsSinceEpoch, 1766062438750);
    });

    test('promotes a seconds-only timestamp and nulls an empty root '
        'hash', () {
      final HyperblockOnNetwork hyperblock = HyperblockOnNetwork.fromJson(
        <String, dynamic>{
          'hash': 'hb',
          'nonce': 1,
          'stateRootHash': '',
          'timestamp': 1683561648,
        },
      );

      expect(hyperblock.stateRootHash, isNull);
      expect(hyperblock.timestampMs, isNull);
      expect(hyperblock.producedAt!.millisecondsSinceEpoch, 1683561648000);
    });

    test('reports no instant when no timestamp is present', () {
      final HyperblockOnNetwork hyperblock = HyperblockOnNetwork.fromJson(
        <String, dynamic>{'hash': 'hb', 'nonce': 1},
      );

      expect(hyperblock.producedAt, isNull);
    });
  });
}
