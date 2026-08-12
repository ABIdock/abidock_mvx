/// Tests for the indexed-account timestamp fields on [AccountOnNetwork].
///
/// The API reports `timestamp` / `timestampMs` only when the account is
/// requested with `withTimestamp=true`, so the default shape must leave both
/// null rather than inventing an epoch instant.
library;

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  const String bech32 =
      'erd1qga7ze0l03chfgru0a32wxqf2226nzrxnyhzer9lmudqhjgy7ycqjjyknz';

  group('AccountOnNetwork.fromApiResponse timestamps', () {
    test('parses both halves and dates from the millisecond one', () {
      final AccountOnNetwork account =
          AccountOnNetwork.fromApiResponse(<String, dynamic>{
            'address': bech32,
            'balance': '4462840504000000000',
            'nonce': 42,
            'timestamp': 1676979360,
            'timestampMs': 1676979360000,
            'shard': 0,
          });

      expect(account.timestamp, 1676979360);
      expect(account.timestampMs, 1676979360000);
      expect(account.indexedAt, DateTime.utc(2023, 2, 21, 11, 36));
      expect(account.indexedAt!.millisecondsSinceEpoch, 1676979360000);
    });

    test('promotes a seconds-only timestamp to milliseconds', () {
      final AccountOnNetwork account = AccountOnNetwork.fromApiResponse(
        <String, dynamic>{
          'address': bech32,
          'balance': '0',
          'nonce': 0,
          'timestamp': 1676979360,
        },
      );

      expect(account.timestampMs, isNull);
      expect(account.indexedAt!.millisecondsSinceEpoch, 1676979360000);
    });

    test('never reads a millisecond value as seconds', () {
      final AccountOnNetwork account = AccountOnNetwork.fromApiResponse(
        <String, dynamic>{
          'address': bech32,
          'balance': '0',
          'nonce': 0,
          'timestamp': 1676979360000,
        },
      );

      expect(account.indexedAt!.year, 2023);
      expect(account.indexedAt!.millisecondsSinceEpoch, 1676979360000);
    });

    test('leaves both null without the withTimestamp request flag', () {
      final AccountOnNetwork account = AccountOnNetwork.fromApiResponse(
        <String, dynamic>{
          'address': bech32,
          'balance': '4462840504000000000',
          'nonce': 42,
          'shard': 0,
        },
      );

      expect(account.timestamp, isNull);
      expect(account.timestampMs, isNull);
      expect(account.indexedAt, isNull);
    });

    test('participates in equality and hashCode', () {
      final AccountOnNetwork withTimestamp =
          AccountOnNetwork.fromApiResponse(<String, dynamic>{
            'address': bech32,
            'balance': '1',
            'nonce': 1,
            'timestamp': 1676979360,
            'timestampMs': 1676979360000,
          });
      final AccountOnNetwork sameTimestamp =
          AccountOnNetwork.fromApiResponse(<String, dynamic>{
            'address': bech32,
            'balance': '1',
            'nonce': 1,
            'timestamp': 1676979360,
            'timestampMs': 1676979360000,
          });
      final AccountOnNetwork withoutTimestamp =
          AccountOnNetwork.fromApiResponse(<String, dynamic>{
            'address': bech32,
            'balance': '1',
            'nonce': 1,
          });

      expect(withTimestamp, sameTimestamp);
      expect(withTimestamp.hashCode, sameTimestamp.hashCode);
      expect(withTimestamp, isNot(withoutTimestamp));
    });
  });

  group('AccountOnNetwork.fromProxyResponse timestamps', () {
    test('leaves both null for the gateway account shape', () {
      final AccountOnNetwork account =
          AccountOnNetwork.fromProxyResponse(<String, dynamic>{
            'address': bech32,
            'nonce': '7',
            'balance': '100000000000000000',
            'username': '',
            'code': '',
            'codeHash': null,
            'rootHash': 'q6Ov9jZ1WvVrOEQaevZUZFuI3zRVFqcLPvOX8HG5DDU=',
            'codeMetadata': null,
            'developerReward': '0',
            'ownerAddress': '',
          });

      expect(account.timestamp, isNull);
      expect(account.timestampMs, isNull);
      expect(account.indexedAt, isNull);
    });
  });
}
