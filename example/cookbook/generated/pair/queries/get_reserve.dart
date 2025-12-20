import 'package:abidock_mvx/abidock_mvx.dart';

/// Queries getReserve endpoint.
///
/// #### Read-only:
/// Yes
///
/// #### Parameters:
/// - `tokenId`: TokenIdentifier
///
/// #### Returns:
/// - `output`: BigUint
///
/// #### Throws:
/// - [NetworkException] if network request fails
/// - [ABIException] if ABI decoding fails
Future<BigInt> getReserve(
  SmartContractController controller,
  String tokenId,
) async {
  final tokenIdValue = TokenIdentifierType.type.createValue(tokenId);

  return executeQuery(
    endpointName: 'getReserve',
    action: () async {
      final result = await controller.query(
        endpointName: 'getReserve',
        arguments: [tokenIdValue],
      );

      return infer<BigInt>(result[0]);
    },
  );
}
