import 'package:abidock_mvx/abidock_mvx.dart';

/// Queries getLpTokenIdentifier endpoint.
///
/// #### Read-only:
/// Yes
///
/// #### Returns:
/// - `output`: TokenIdentifier
///
/// #### Throws:
/// - [NetworkException] if network request fails
/// - [ABIException] if ABI decoding fails
Future<String> getLpTokenIdentifier(SmartContractController controller) async {
  return executeQuery(
    endpointName: 'getLpTokenIdentifier',
    action: () async {
      final result = await controller.query(
        endpointName: 'getLpTokenIdentifier',
      );

      return infer<String>(result[0]);
    },
  );
}
