import 'package:abidock_mvx/abidock_mvx.dart';

/// Queries getRouterManagedAddress endpoint.
///
/// #### Read-only:
/// Yes
///
/// #### Returns:
/// - `output`: Address
///
/// #### Throws:
/// - [NetworkException] if network request fails
/// - [ABIException] if ABI decoding fails
Future<String> getRouterManagedAddress(
  SmartContractController controller,
) async {
  return executeQuery(
    endpointName: 'getRouterManagedAddress',
    action: () async {
      final result = await controller.query(
        endpointName: 'getRouterManagedAddress',
      );

      return infer<String>(result[0]);
    },
  );
}
