import 'package:abidock_mvx/abidock_mvx.dart';

/// Queries getAmountOut endpoint.
///
/// #### Read-only:
/// Yes
///
/// #### Parameters:
/// - `tokenIn`: TokenIdentifier
/// - `amountIn`: BigUint
///
/// #### Returns:
/// - `output`: BigUint
///
/// #### Throws:
/// - [NetworkException] if network request fails
/// - [ABIException] if ABI decoding fails
Future<BigInt> getAmountOut(
  SmartContractController controller,
  String tokenIn,
  BigInt amountIn,
) async {
  final tokenInValue = TokenIdentifierType.type.createValue(tokenIn);
  final amountInValue = BigUIntType.type.createValue(amountIn);

  return executeQuery(
    endpointName: 'getAmountOut',
    action: () async {
      final result = await controller.query(
        endpointName: 'getAmountOut',
        arguments: [tokenInValue, amountInValue],
      );

      return infer<BigInt>(result[0]);
    },
  );
}
