/// Tests for Supernova timestamp handling on [TransactionOnNetwork].
///
/// The Gateway `/transaction/:hash` route switches `timestamp` from seconds to
/// milliseconds once `SupernovaFlag` activates, without renaming the field,
/// while the public API keeps seconds and adds a parallel `timestampMs`.
/// These tests pin both sides of that fork.
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

/// Fixed instant used across the fixtures: 2025-12-18T12:53:58Z.
const int secondsValue = 1766062438;

/// The same instant expressed in milliseconds, exactly as the proxy fixture
/// `process/testdata/tx-with-log-events.json` reports it on `rc/supernova`.
const int millisecondsValue = 1766062438000;

Map<String, dynamic> _proxyJson(
  Map<String, dynamic> overrides,
) => <String, dynamic>{
  'txHash': 'aa'.padLeft(64, '0'),
  'sender': 'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  'receiver': 'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  'value': '0',
  'gasLimit': 50000,
  'gasPrice': 1000000000,
  'nonce': 7,
  'status': 'success',
  ...overrides,
};

void main() {
  group('TransactionOnNetwork timestamp parsing', () {
    test('reads timestampMs alongside the legacy timestamp', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromProxyResponse(
        _proxyJson(<String, dynamic>{
          'timestamp': secondsValue,
          'timestampMs': millisecondsValue,
        }),
      );

      expect(tx.timestamp, equals(secondsValue));
      expect(tx.timestampMs, equals(millisecondsValue));
    });

    test('leaves timestampMs null when the provider omits it', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromProxyResponse(
        _proxyJson(<String, dynamic>{'timestamp': secondsValue}),
      );

      expect(tx.timestamp, equals(secondsValue));
      expect(tx.timestampMs, isNull);
    });
  });

  group('TransactionOnNetwork.executedAt', () {
    test('reads a pre-Supernova seconds timestamp as seconds', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromProxyResponse(
        _proxyJson(<String, dynamic>{'timestamp': secondsValue}),
      );

      expect(tx.executedAt, equals(DateTime.utc(2025, 12, 18, 12, 53, 58)));
    });

    test('reads a Supernova millisecond timestamp as milliseconds', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromProxyResponse(
        _proxyJson(<String, dynamic>{'timestamp': millisecondsValue}),
      );

      expect(tx.executedAt, equals(DateTime.utc(2025, 12, 18, 12, 53, 58)));
    });

    test('prefers timestampMs over the legacy timestamp', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromProxyResponse(
        _proxyJson(<String, dynamic>{
          'timestamp': secondsValue,
          'timestampMs': millisecondsValue,
        }),
      );

      expect(tx.executedAt, equals(DateTime.utc(2025, 12, 18, 12, 53, 58)));
    });

    test('is null when neither timestamp field is reported', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromProxyResponse(
        _proxyJson(<String, dynamic>{}),
      );

      expect(tx.executedAt, isNull);
    });

    test('never yields a year-57000 date from a millisecond value', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromProxyResponse(
        _proxyJson(<String, dynamic>{'timestamp': millisecondsValue}),
      );

      expect(tx.executedAt!.year, equals(2025));
    });
  });

  group('TransactionOnNetwork miniblock type', () {
    test('reads the node spelling `miniblockType`', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromProxyResponse(
        _proxyJson(<String, dynamic>{'miniblockType': 'TxBlock'}),
      );

      expect(tx.miniBlockType, equals('TxBlock'));
    });

    test('still accepts the upper-case `miniBlockType` spelling', () {
      final TransactionOnNetwork tx = TransactionOnNetwork.fromProxyResponse(
        _proxyJson(<String, dynamic>{'miniBlockType': 'TxBlock'}),
      );

      expect(tx.miniBlockType, equals('TxBlock'));
    });
  });
}
