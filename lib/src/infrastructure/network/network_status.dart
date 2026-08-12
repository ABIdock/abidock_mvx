import '../../utils/helpers.dart';

/// Unit-agnostic reader for chain timestamps whose unit is not stable.
///
/// At the Supernova activation epoch the chain switches several timestamp
/// fields from seconds to milliseconds without renaming them
/// (`erd_block_timestamp` on `/network/status`, `timestamp` on
/// `/transaction/:hash`). On `/network/status` the seconds-named and
/// milliseconds-named fields carry the identical value, so exactly one of the
/// two is correct on each side of the activation. The name of a field is
/// therefore not evidence of its unit; the unit has to be decided per value,
/// from its magnitude.
class ChainTimestamp {
  const ChainTimestamp._();

  /// Smallest raw value interpreted as milliseconds instead of seconds.
  ///
  /// `100000000000` is 1973-03-03 when read as milliseconds and the year 5138
  /// when read as seconds, so no chain timestamp of either unit is ambiguous.
  static const int millisecondThreshold = 100000000000;

  /// Converts a raw chain timestamp of unknown unit to milliseconds.
  ///
  /// #### Parameters
  /// - `value` - Raw timestamp exactly as the provider reported it
  ///
  /// #### Returns
  /// `int?` - Milliseconds since the Unix epoch, or `null` when `value` is
  /// `null` or `0` (both mean "not reported": a round that cannot be dated is
  /// reported as `0`, and the key is omitted entirely otherwise)
  ///
  /// #### Example
  /// ```dart
  /// ChainTimestamp.toMilliseconds(1766062438);
  /// ChainTimestamp.toMilliseconds(1766062438000);
  /// ```
  static int? toMilliseconds(int? value) {
    if (value == null || value == 0) return null;
    return value >= millisecondThreshold ? value : value * 1000;
  }

  /// Converts a raw chain timestamp of unknown unit to a UTC [DateTime].
  ///
  /// #### Parameters
  /// - `value` - Raw timestamp exactly as the provider reported it
  ///
  /// #### Returns
  /// `DateTime?` - UTC instant, or `null` when `value` is `null` or `0`
  ///
  /// #### Example
  /// ```dart
  /// final DateTime? at = ChainTimestamp.toDateTime(status.blockTimestamp);
  /// ```
  static DateTime? toDateTime(int? value) {
    final int? milliseconds = toMilliseconds(value);
    if (milliseconds == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }
}

/// Network status representing current blockchain state.
/// Provides current epoch, round numbers, and block height information.
class NetworkStatus {
  /// Creates network status with all timing parameters.
  ///
  /// #### Parameters
  /// - `currentRound` - Current round number in the blockchain
  /// - `epochNumber` - Current epoch number
  /// - `nonce` - Current block height (number of blocks)
  /// - `nonceAtEpochStart` - Block height when current epoch started
  /// - `roundsPerEpoch` - Total rounds in one epoch
  /// - `roundsPassedInCurrentEpoch` - Rounds completed in current epoch
  /// - `highestFinalNonce` - Highest finalized block nonce (optional)
  /// - `noncesPassedInCurrentEpoch` - Nonces passed in current epoch (optional)
  /// - `roundAtEpochStart` - Round number when current epoch started (optional)
  /// - `crossCheckBlockHeight` - Cross-check block height (optional, Gateway only)
  /// - `blockTimestamp` - Last synchronised block timestamp (optional, unit varies)
  /// - `blockTimestampMs` - Last synchronised block timestamp in milliseconds (optional, unit varies)
  const NetworkStatus({
    required this.currentRound,
    required this.epochNumber,
    required this.nonce,
    required this.nonceAtEpochStart,
    required this.roundsPerEpoch,
    required this.roundsPassedInCurrentEpoch,
    this.highestFinalNonce,
    this.noncesPassedInCurrentEpoch,
    this.roundAtEpochStart,
    this.crossCheckBlockHeight,
    this.blockTimestamp,
    this.blockTimestampMs,
  });

  /// Creates status from REST API response.
  ///
  /// #### Parameters
  /// - `data` - JSON response from `/network/status` endpoint
  ///
  /// #### Returns
  /// `NetworkStatus` - Instance with parsed timing information
  factory NetworkStatus.fromApiResponse(Map<String, dynamic> data) {
    return NetworkStatus(
      currentRound: requireInt(data['erd_current_round'], 'erd_current_round'),
      epochNumber: requireInt(data['erd_epoch_number'], 'erd_epoch_number'),
      nonce: requireInt(data['erd_nonce'], 'erd_nonce'),
      nonceAtEpochStart: requireInt(
        data['erd_nonce_at_epoch_start'],
        'erd_nonce_at_epoch_start',
      ),
      roundsPerEpoch: requireInt(
        data['erd_rounds_per_epoch'],
        'erd_rounds_per_epoch',
      ),
      roundsPassedInCurrentEpoch: requireInt(
        data['erd_rounds_passed_in_current_epoch'],
        'erd_rounds_passed_in_current_epoch',
      ),
      highestFinalNonce: optionalInt(
        data['erd_highest_final_nonce'],
        'erd_highest_final_nonce',
      ),
      noncesPassedInCurrentEpoch: optionalInt(
        data['erd_nonces_passed_in_current_epoch'],
        'erd_nonces_passed_in_current_epoch',
      ),
      roundAtEpochStart: optionalInt(
        data['erd_round_at_epoch_start'],
        'erd_round_at_epoch_start',
      ),
      crossCheckBlockHeight: data['erd_cross_check_block_height']?.toString(),
      blockTimestamp: optionalInt(
        data['erd_block_timestamp'],
        'erd_block_timestamp',
      ),
      blockTimestampMs: optionalInt(
        data['erd_block_timestamp_ms'],
        'erd_block_timestamp_ms',
      ),
    );
  }

  /// Creates status from Gateway/Proxy response.
  ///
  /// #### Parameters
  /// - `data` - JSON response from Gateway `/network/status` endpoint with nested 'status' object
  ///
  /// #### Returns
  /// `NetworkStatus` - Instance with parsed timing information
  factory NetworkStatus.fromProxyResponse(Map<String, dynamic> data) {
    final Map<String, dynamic> status = requireAs<Map<String, dynamic>>(
      data['status'],
      'status',
    );
    return NetworkStatus(
      currentRound: requireInt(
        status['erd_current_round'],
        'erd_current_round',
      ),
      epochNumber: requireInt(status['erd_epoch_number'], 'erd_epoch_number'),
      nonce: requireInt(status['erd_nonce'], 'erd_nonce'),
      nonceAtEpochStart: requireInt(
        status['erd_nonce_at_epoch_start'],
        'erd_nonce_at_epoch_start',
      ),
      roundsPerEpoch: requireInt(
        status['erd_rounds_per_epoch'],
        'erd_rounds_per_epoch',
      ),
      roundsPassedInCurrentEpoch: requireInt(
        status['erd_rounds_passed_in_current_epoch'],
        'erd_rounds_passed_in_current_epoch',
      ),
      highestFinalNonce: optionalInt(
        status['erd_highest_final_nonce'],
        'erd_highest_final_nonce',
      ),
      noncesPassedInCurrentEpoch: optionalInt(
        status['erd_nonces_passed_in_current_epoch'],
        'erd_nonces_passed_in_current_epoch',
      ),
      roundAtEpochStart: optionalInt(
        status['erd_round_at_epoch_start'],
        'erd_round_at_epoch_start',
      ),
      crossCheckBlockHeight: status['erd_cross_check_block_height']?.toString(),
      blockTimestamp: optionalInt(
        status['erd_block_timestamp'],
        'erd_block_timestamp',
      ),
      blockTimestampMs: optionalInt(
        status['erd_block_timestamp_ms'],
        'erd_block_timestamp_ms',
      ),
    );
  }

  /// Current round.
  final int currentRound;

  /// Current epoch.
  final int epochNumber;

  /// Current nonce (block height).
  final int nonce;

  /// Nonce at epoch start.
  final int nonceAtEpochStart;

  /// Rounds per epoch.
  final int roundsPerEpoch;

  /// Rounds passed in current epoch.
  final int roundsPassedInCurrentEpoch;

  /// Highest finalized block nonce.
  final int? highestFinalNonce;

  /// Nonces passed in current epoch.
  final int? noncesPassedInCurrentEpoch;

  /// Round number when current epoch started.
  final int? roundAtEpochStart;

  /// Cross-check block height (Gateway only).
  final String? crossCheckBlockHeight;

  /// Timestamp of the last synchronised block, verbatim from
  /// `erd_block_timestamp`.
  ///
  /// UNITS ARE NOT STABLE: seconds before Supernova activation, milliseconds
  /// after, because the field carries the block header timestamp unchanged and
  /// the header itself switched to milliseconds. Use [blockTime] instead of
  /// reading this field as seconds.
  final int? blockTimestamp;

  /// Timestamp of the last synchronised block, verbatim from
  /// `erd_block_timestamp_ms`.
  ///
  /// UNITS ARE NOT STABLE: this field and [blockTimestamp] carry the identical
  /// value, so it holds seconds before Supernova activation and milliseconds
  /// after. The two fields effectively swap correctness at the activation
  /// epoch, which is why neither is normalised on parse — both stay faithful
  /// echoes of the wire. Use [blockTime].
  final int? blockTimestampMs;

  /// Time of the last synchronised block, normalised across the Supernova
  /// unit change.
  ///
  /// Prefers [blockTimestampMs] and falls back to [blockTimestamp], deciding
  /// the unit of whichever value it uses by magnitude via [ChainTimestamp].
  ///
  /// #### Returns
  /// `DateTime?` - UTC instant of the chain tip, or `null` when the node
  /// reported neither metric
  ///
  /// #### Example
  /// ```dart
  /// final NetworkStatus status = await provider.getNetworkStatus();
  /// final Duration? staleness = status.blockTime == null
  ///     ? null
  ///     : DateTime.now().toUtc().difference(status.blockTime!);
  /// ```
  DateTime? get blockTime =>
      ChainTimestamp.toDateTime(blockTimestampMs ?? blockTimestamp);

  @override
  String toString() =>
      'NetworkStatus(epoch: $epochNumber, '
      'round: $currentRound, '
      'nonce: $nonce, '
      'highestFinalNonce: $highestFinalNonce)';
}
