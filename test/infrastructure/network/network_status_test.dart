/// Tests for [NetworkStatus] block-timestamp parsing and [ChainTimestamp].
///
/// The two `/network/status` metrics `erd_block_timestamp` and
/// `erd_block_timestamp_ms` receive the same raw header value on the node, and
/// the Supernova header reports milliseconds where earlier headers report
/// seconds. Each metric is therefore correct on exactly one side of the
/// activation epoch, so the raw fields are echoed verbatim and only
/// [NetworkStatus.blockTime] is normalised.
///
/// Every expectation below is a literal, never a constant re-read from the
/// library.
import 'package:abidock_mvx/src/infrastructure/network/network_status.dart';
import 'package:test/test.dart';

void main() {
  group('ChainTimestamp.toMilliseconds', () {
    test('scales a second-magnitude value by 1000', () {
      expect(ChainTimestamp.toMilliseconds(1766062438), equals(1766062438000));
    });

    test('passes a millisecond-magnitude value through untouched', () {
      expect(
        ChainTimestamp.toMilliseconds(1766062438000),
        equals(1766062438000),
      );
    });

    test('treats exactly 100000000000 as milliseconds (boundary)', () {
      expect(ChainTimestamp.toMilliseconds(100000000000), equals(100000000000));
    });

    test('treats 99999999999 as seconds (boundary minus one)', () {
      expect(
        ChainTimestamp.toMilliseconds(99999999999),
        equals(99999999999000),
      );
    });

    test('returns null for null and for zero', () {
      expect(ChainTimestamp.toMilliseconds(null), isNull);
      expect(ChainTimestamp.toMilliseconds(0), isNull);
    });
  });

  group('ChainTimestamp.toDateTime', () {
    test('reads seconds as 2025-12-18T12:53:58Z', () {
      expect(
        ChainTimestamp.toDateTime(1766062438)!.toIso8601String(),
        equals('2025-12-18T12:53:58.000Z'),
      );
    });

    test('reads milliseconds as the same instant', () {
      expect(
        ChainTimestamp.toDateTime(1766062438000)!.toIso8601String(),
        equals('2025-12-18T12:53:58.000Z'),
      );
    });

    test('returns a UTC instant', () {
      expect(ChainTimestamp.toDateTime(1766062438)!.isUtc, isTrue);
    });

    test('returns null for zero', () {
      expect(ChainTimestamp.toDateTime(0), isNull);
    });
  });

  group('NetworkStatus.fromApiResponse block timestamps', () {
    test('parses both metrics verbatim without converting either', () {
      final NetworkStatus status = NetworkStatus.fromApiResponse(
        <String, dynamic>{
          'erd_current_round': 3510000,
          'erd_epoch_number': 1500,
          'erd_nonce': 3509000,
          'erd_nonce_at_epoch_start': 3495000,
          'erd_rounds_per_epoch': 14400,
          'erd_rounds_passed_in_current_epoch': 15000,
          'erd_block_timestamp': 1766062438,
          'erd_block_timestamp_ms': 1766062438000,
        },
      );

      expect(status.blockTimestamp, equals(1766062438));
      expect(status.blockTimestampMs, equals(1766062438000));
    });

    test('leaves both fields null when the node reports neither key', () {
      final NetworkStatus status = NetworkStatus.fromApiResponse(
        <String, dynamic>{
          'erd_current_round': 3510000,
          'erd_epoch_number': 1500,
          'erd_nonce': 3509000,
          'erd_nonce_at_epoch_start': 3495000,
          'erd_rounds_per_epoch': 14400,
          'erd_rounds_passed_in_current_epoch': 15000,
        },
      );

      expect(status.blockTimestamp, isNull);
      expect(status.blockTimestampMs, isNull);
      expect(status.blockTime, isNull);
    });
  });

  group('NetworkStatus.fromProxyResponse block timestamps', () {
    test('reads both metrics from the nested status object', () {
      final NetworkStatus status = NetworkStatus.fromProxyResponse(
        <String, dynamic>{
          'status': <String, dynamic>{
            'erd_current_round': 3510000,
            'erd_epoch_number': 1500,
            'erd_nonce': 3509000,
            'erd_nonce_at_epoch_start': 3495000,
            'erd_rounds_per_epoch': 14400,
            'erd_rounds_passed_in_current_epoch': 15000,
            'erd_block_timestamp': 1766062438,
            'erd_block_timestamp_ms': 1766062438000,
          },
        },
      );

      expect(status.blockTimestamp, equals(1766062438));
      expect(status.blockTimestampMs, equals(1766062438000));
      expect(
        status.blockTime!.toIso8601String(),
        equals('2025-12-18T12:53:58.000Z'),
      );
    });
  });

  group('NetworkStatus.blockTime across the Supernova unit swap', () {
    /// Builds a status carrying only the two block-timestamp metrics.
    NetworkStatus statusWith(int timestamp, int timestampMs) {
      return NetworkStatus.fromApiResponse(<String, dynamic>{
        'erd_current_round': 3510000,
        'erd_epoch_number': 1500,
        'erd_nonce': 3509000,
        'erd_nonce_at_epoch_start': 3495000,
        'erd_rounds_per_epoch': 14400,
        'erd_rounds_passed_in_current_epoch': 15000,
        'erd_block_timestamp': timestamp,
        'erd_block_timestamp_ms': timestampMs,
      });
    }

    test('pre-Supernova: both metrics hold seconds, not 1970', () {
      expect(
        statusWith(1766062438, 1766062438).blockTime!.toIso8601String(),
        equals('2025-12-18T12:53:58.000Z'),
      );
    });

    test('post-Supernova: both metrics hold milliseconds, not year 57000', () {
      expect(
        statusWith(1766062438000, 1766062438000).blockTime!.toIso8601String(),
        equals('2025-12-18T12:53:58.000Z'),
      );
    });

    test('correctly-formed pair resolves to the same instant', () {
      expect(
        statusWith(1766062438, 1766062438000).blockTime!.toIso8601String(),
        equals('2025-12-18T12:53:58.000Z'),
      );
    });

    test('a zero metric pair yields null rather than 1970', () {
      expect(statusWith(0, 0).blockTime, isNull);
    });

    test('falls back to the seconds metric when only it is reported', () {
      final NetworkStatus status = NetworkStatus.fromApiResponse(
        <String, dynamic>{
          'erd_current_round': 3510000,
          'erd_epoch_number': 1500,
          'erd_nonce': 3509000,
          'erd_nonce_at_epoch_start': 3495000,
          'erd_rounds_per_epoch': 14400,
          'erd_rounds_passed_in_current_epoch': 15000,
          'erd_block_timestamp': 1766062438,
        },
      );

      expect(status.blockTimestampMs, isNull);
      expect(
        status.blockTime!.toIso8601String(),
        equals('2025-12-18T12:53:58.000Z'),
      );
    });
  });
}
