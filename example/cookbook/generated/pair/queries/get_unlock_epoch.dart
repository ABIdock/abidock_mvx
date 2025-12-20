import 'package:abidock_mvx/abidock_mvx.dart';

/// Queries getUnlockEpoch endpoint.
///
/// #### Read-only:
/// Yes
///
/// #### Returns:
/// - `output`: u64
///
/// #### Throws:
/// - [NetworkException] if network request fails
/// - [ABIException] if ABI decoding fails
Future<BigInt> getUnlockEpoch(SmartContractController controller) async {
  return executeQuery(
    endpointName: 'getUnlockEpoch',
    action: () async {
      final result = await controller.query(endpointName: 'getUnlockEpoch');

      return infer<BigInt>(result[0]);
    },
  );
}
