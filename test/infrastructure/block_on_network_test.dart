import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('BlockOnNetwork.fromJson', () {
    test('parses API shape (hash/nonce/shard)', () {
      final block = BlockOnNetwork.fromJson(<String, dynamic>{
        'hash': 'aabbcc',
        'nonce': 10,
        'round': 100,
        'epoch': 4,
        'shard': 1,
        'prevHash': '001122',
        'timestamp': 1_700_000_000,
        'txCount': 25,
      });

      expect(block.hash, 'aabbcc');
      expect(block.nonce, 10);
      expect(block.round, 100);
      expect(block.epoch, 4);
      expect(block.shard, 1);
      expect(block.previousHash, '001122');
      expect(block.timestamp, 1_700_000_000);
      expect(block.numTxs, 25);
    });

    test('parses Gateway aliases (shardID, previousBlockHash)', () {
      final block = BlockOnNetwork.fromJson(<String, dynamic>{
        'hash': 'ff',
        'nonce': 5,
        'round': 50,
        'epoch': 2,
        'shardID': 4294967295, // metachain
        'previousBlockHash': 'ee',
        'numTxs': 0,
      });

      expect(block.shard, 4294967295);
      expect(block.previousHash, 'ee');
      expect(block.numTxs, 0);
    });

    test('falls back to defaults on missing fields', () {
      final block = BlockOnNetwork.fromJson(<String, dynamic>{});
      expect(block.hash, '');
      expect(block.nonce, 0);
      expect(block.previousHash, isNull);
    });
  });

  group('HyperblockOnNetwork.fromJson', () {
    test('collects shard block hashes and tx hashes from maps', () {
      final hb = HyperblockOnNetwork.fromJson(<String, dynamic>{
        'hash': 'hb',
        'nonce': 42,
        'round': 420,
        'epoch': 7,
        'shardBlocks': <Map<String, dynamic>>[
          <String, dynamic>{'hash': 'sb0', 'shard': 0},
          <String, dynamic>{'hash': 'sb1', 'shard': 1},
        ],
        'transactions': <Map<String, dynamic>>[
          <String, dynamic>{'hash': 'tx1'},
          <String, dynamic>{'hash': 'tx2'},
        ],
        'timestamp': 1_700_000_000,
      });

      expect(hb.hash, 'hb');
      expect(hb.nonce, 42);
      expect(hb.shardBlocks, <String>['sb0', 'sb1']);
      expect(hb.transactionHashes, <String>['tx1', 'tx2']);
      expect(hb.numTxs, 2);
    });

    test('tolerates raw-string shard block / tx entries', () {
      final hb = HyperblockOnNetwork.fromJson(<String, dynamic>{
        'hash': 'hb',
        'nonce': 1,
        'shardBlocks': <String>['aaa', 'bbb'],
        'transactions': <String>['tx'],
      });
      expect(hb.shardBlocks, <String>['aaa', 'bbb']);
      expect(hb.transactionHashes, <String>['tx']);
    });

    test('handles missing collections', () {
      final hb = HyperblockOnNetwork.fromJson(<String, dynamic>{
        'hash': 'hb',
        'nonce': 0,
      });
      expect(hb.shardBlocks, isEmpty);
      expect(hb.transactionHashes, isEmpty);
      expect(hb.numTxs, isNull);
    });
  });
}
