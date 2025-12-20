import 'package:abidock_mvx/abidock_mvx.dart';

/// Calls resume endpoint.
///
/// #### Throws:
/// - [NetworkException] if network request fails
/// - [EndpointNotFoundException] if endpoint not found in ABI
/// - [ArgumentEncodingException] if ABI encoding fails
Future<Transaction> resume(
  SmartContractController controller,
  IAccount sender,
  Nonce nonce, {
  Address? relayer,
  Address? guardian,
  Balance? value,
}) async {
  // Create transaction with max gas for simulation
  final simulationTx = await controller.call(
    account: sender,
    nonce: nonce,
    endpointName: 'resume',
    value: value,
    options: BaseControllerInput(
      gasLimit: const GasLimit(600000000),
      relayer: relayer,
      guardian: guardian,
    ),
  );

  // Estimate gas using simulation
  final gasLimit = await simulateGas(simulationTx, controller.networkProvider);

  // Create final transaction with estimated gas
  return controller.call(
    account: sender,
    nonce: nonce,
    endpointName: 'resume',
    value: value,
    options: BaseControllerInput(
      gasLimit: gasLimit,
      relayer: relayer,
      guardian: guardian,
    ),
  );
}

/// Builds an unsigned transaction for resume endpoint.
/// #### Returns:
/// Unsigned [Transaction] ready to be signed
///
/// #### Example:
/// ```dart
/// // Build unsigned transactions for batch signing
/// final tx1 = resumeUnsigned(factory, sender, nonce1, ...);
/// final tx2 = anotherUnsigned(factory2, sender, nonce2, ...);
///
/// // Sign batch
/// final sigs = await account.signTransactions([tx1, tx2]);
///
/// // Apply signatures and send
/// final signed1 = tx1.copyWith(newSignature: Signature.fromUint8List(sigs[0]));
/// final signed2 = tx2.copyWith(newSignature: Signature.fromUint8List(sigs[1]));
/// await provider.sendTransactions([signed1, signed2]);
/// ```
Transaction resumeUnsigned(
  SmartContractCallFactory factory,
  Address sender,
  Nonce nonce, {
  required GasLimit gasLimit,
  Balance? value,
}) {
  return factory.createCall(
    sender: sender,
    nonce: nonce,
    endpointName: 'resume',
    gasLimit: gasLimit,
    value: value,
  );
}
