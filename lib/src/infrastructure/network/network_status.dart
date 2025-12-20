import '../../utils/helpers.dart';

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

  @override
  String toString() =>
      'NetworkStatus(epoch: $epochNumber, '
      'round: $currentRound, '
      'nonce: $nonce, '
      'highestFinalNonce: $highestFinalNonce)';
}
