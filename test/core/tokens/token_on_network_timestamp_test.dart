/// Tests for the creation-timestamp accessors on [TokenOnNetwork].
///
/// Collection responses carry a millisecond half alongside the seconds one;
/// token, NFT and account-holding responses carry only the seconds half.
library;

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('TokenOnNetwork timestamps', () {
    test('parses both halves from a collection response', () {
      final TokenOnNetwork token = TokenOnNetwork.fromJson(<String, dynamic>{
        'collection': 'MEDAL-ae4d56',
        'type': 'NonFungibleESDT',
        'name': 'GLOBAL OFFENSIVE',
        'ticker': 'MEDAL',
        'owner':
            'erd1qqqqqqqqqqqqqpgq09vq93grfqy7x5fhgmh44ncqfp3xaw57ys5s7j9fed',
        'timestamp': 1676979360,
        'timestampMs': 1676979360000,
      });

      expect(token.timestamp, 1676979360);
      expect(token.timestampMs, 1676979360000);
      expect(token.createdAt, DateTime.utc(2023, 2, 21, 11, 36));
      expect(token.createdAt!.millisecondsSinceEpoch, 1676979360000);
    });

    test('promotes a seconds-only timestamp to milliseconds', () {
      final TokenOnNetwork token = TokenOnNetwork.fromJson(<String, dynamic>{
        'identifier': 'WEGLD-bd4d79',
        'balance': '1000000000000000000',
        'nonce': 0,
        'decimals': 18,
        'timestamp': 1676979360,
      });

      expect(token.timestampMs, isNull);
      expect(token.createdAt!.millisecondsSinceEpoch, 1676979360000);
    });

    test('never reads a millisecond value as seconds', () {
      final TokenOnNetwork token = TokenOnNetwork.fromJson(<String, dynamic>{
        'identifier': 'WEGLD-bd4d79',
        'balance': '0',
        'nonce': 0,
        'timestamp': 1676979360000,
      });

      expect(token.createdAt!.year, 2023);
      expect(token.createdAt!.millisecondsSinceEpoch, 1676979360000);
    });

    test('reports no instant when no timestamp is present', () {
      final TokenOnNetwork token = TokenOnNetwork.fromJson(<String, dynamic>{
        'identifier': 'WEGLD-bd4d79',
        'balance': '0',
        'nonce': 0,
      });

      expect(token.timestamp, isNull);
      expect(token.timestampMs, isNull);
      expect(token.createdAt, isNull);
    });
  });
}
