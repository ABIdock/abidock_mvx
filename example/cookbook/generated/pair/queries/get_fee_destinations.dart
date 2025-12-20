import 'package:abidock_mvx/abidock_mvx.dart';

/// Queries getFeeDestinations endpoint.
///
/// #### Read-only:
/// Yes
///
/// #### Returns:
/// - `output`: variadic&lt;multi&lt;Address,TokenIdentifier&gt;&gt;
///
/// #### Throws:
/// - [NetworkException] if network request fails
/// - [ABIException] if ABI decoding fails
Future<List<(String, String)>> getFeeDestinations(
  SmartContractController controller,
) async {
  return executeQuery(
    endpointName: 'getFeeDestinations',
    action: () async {
      final result = await controller.query(endpointName: 'getFeeDestinations');

      if (result.isEmpty) {
        return <(String, String)>[];
      }
      return infer<List<(String, String)>>(result[0]);
    },
  );
}
