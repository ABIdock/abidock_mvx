import 'package:abidock_mvx/abidock_mvx.dart';

/// Queries getLockingDeadlineEpoch endpoint.
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
Future<BigInt> getLockingDeadlineEpoch(
  SmartContractController controller,
) async {
  return executeQuery(
    endpointName: 'getLockingDeadlineEpoch',
    action: () async {
      final result = await controller.query(
        endpointName: 'getLockingDeadlineEpoch',
      );

      return infer<BigInt>(result[0]);
    },
  );
}
