import 'package:abidock_mvx/abidock_mvx.dart';

import '../models/token_pair.dart';

/// Queries getTrustedSwapPairs endpoint.
///
/// #### Read-only:
/// Yes
///
/// #### Returns:
/// - `output`: variadic&lt;multi&lt;TokenPair,Address&gt;&gt;
///
/// #### Throws:
/// - [NetworkException] if network request fails
/// - [ABIException] if ABI decoding fails
Future<List<(TokenPair, String)>> getTrustedSwapPairs(
  SmartContractController controller,
) async {
  return executeQuery(
    endpointName: 'getTrustedSwapPairs',
    action: () async {
      final result = await controller.query(
        endpointName: 'getTrustedSwapPairs',
      );

      if (result.isEmpty) {
        return <(TokenPair, String)>[];
      }
      return infer<List<(TokenPair, String)>>(result[0]);
    },
  );
}
