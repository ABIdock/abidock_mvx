import 'package:abidock_mvx/abidock_mvx.dart';

/// Calls setupFeesCollector endpoint.
///
/// `fees_collector_cut_percentage` of the special fees are sent to the fees_collector_address SC
///
/// For example, if special fees is 5%, and fees_collector_cut_percentage is 10%,
/// then of the 5%, 10% are reserved, and only the rest are split between other pair contracts.
///
/// #### Parameters:
/// - `feesCollectorAddress`: Address
/// - `feesCollectorCutPercentage`: u64
///
/// #### Throws:
/// - [NetworkException] if network request fails
/// - [EndpointNotFoundException] if endpoint not found in ABI
/// - [ArgumentEncodingException] if ABI encoding fails
Future<Transaction> setupFeesCollector(
  SmartContractController controller,
  IAccount sender,
  Nonce nonce,
  String feesCollectorAddress,
  BigInt feesCollectorCutPercentage, {
  Address? relayer,
  Address? guardian,
  Balance? value,
}) async {
  // Create transaction with max gas for simulation
  final simulationTx = await controller.call(
    account: sender,
    nonce: nonce,
    endpointName: 'setupFeesCollector',
    arguments: <dynamic>[feesCollectorAddress, feesCollectorCutPercentage],
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
    endpointName: 'setupFeesCollector',
    arguments: <dynamic>[feesCollectorAddress, feesCollectorCutPercentage],
    value: value,
    options: BaseControllerInput(
      gasLimit: gasLimit,
      relayer: relayer,
      guardian: guardian,
    ),
  );
}

/// Builds an unsigned transaction for setupFeesCollector endpoint.
/// #### Parameters:
/// - `feesCollectorAddress`: Address
/// - `feesCollectorCutPercentage`: u64
///
/// #### Returns:
/// Unsigned [Transaction] ready to be signed
///
/// #### Example:
/// ```dart
/// // Build unsigned transactions for batch signing
/// final tx1 = setupFeesCollectorUnsigned(factory, sender, nonce1, ...);
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
Transaction setupFeesCollectorUnsigned(
  SmartContractCallFactory factory,
  Address sender,
  Nonce nonce,
  String feesCollectorAddress,
  BigInt feesCollectorCutPercentage, {
  required GasLimit gasLimit,
  Balance? value,
}) {
  return factory.createCall(
    sender: sender,
    nonce: nonce,
    endpointName: 'setupFeesCollector',
    arguments: <dynamic>[feesCollectorAddress, feesCollectorCutPercentage],
    gasLimit: gasLimit,
    value: value,
  );
}
