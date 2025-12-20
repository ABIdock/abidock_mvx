import 'package:abidock_mvx/abidock_mvx.dart';

/// Queries getFirstTokenId endpoint.
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
Future<String> getFirstTokenId(SmartContractController controller) async {
  return executeQuery(
    endpointName: 'getFirstTokenId',
    action: () async {
      final result = await controller.query(endpointName: 'getFirstTokenId');

      return infer<String>(result[0]);
    },
  );
}
