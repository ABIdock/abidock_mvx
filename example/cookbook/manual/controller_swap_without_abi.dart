import 'dart:io';

import 'package:abidock_mvx/abidock_mvx.dart';

/// Example demonstrating smart contract interaction without ABI.
///
/// This example shows how to:
/// - Create a [SmartContractController] without an ABI definition
/// - Use [queryRaw] to query contract state with pre-typed arguments
/// - Use [callRaw] to execute contract functions with pre-typed arguments
///
/// When working without an ABI:
/// - Arguments must be [TypedValue] instances (e.g., [BigUIntValue], [TokenIdentifierValue])
/// - Query results are returned as raw [Uint8List] bytes (not parsed)
/// - You must manually decode response bytes using appropriate codecs
///
/// This approach is useful when:
/// - The contract ABI is not available
/// - You want to interact with arbitrary contracts
/// - You need maximum control over argument encoding/decoding
Future<void> main() async {
  final ConsoleLogger logger = ConsoleLogger(
    minLevel: LogLevel.debug,
    includeTimestamp: true,
    prettyPrintContext: true,
    showBorders: true,
    useColors: true,
  );

  final pem = File('example/assets/alice.pem').readAsStringSync();
  final account = await Account.fromPem(pem);
  final aliceAddress = account.address;

  final provider = ApiNetworkProvider.devnet(logger: logger);
  final freshAccount = await provider.getAccount(aliceAddress);
  final Nonce currentNonce = freshAccount.nonce;

  final contractAddress = SmartContractAddress.fromBech32(
    'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
  );

  // Create controller WITHOUT ABI
  final controller = SmartContractController.withoutAbi(
    contractAddress: contractAddress,
    networkProvider: provider,
    logger: logger,
  );

  final wegldAmount = BigInt.from(1) * BigInt.from(10).pow(17);
  final wegldToken = TokenIdentifierValue('WEGLD-a28c59');
  final mexToken = TokenIdentifierValue('MEX-a659d0');

  final oldMexTokenOnNetwork = await provider.getTokenOfAccount(
    aliceAddress,
    mexToken.nativeValue,
  );
  final oldWegldTokenOnNetwork = await provider.getTokenOfAccount(
    aliceAddress,
    wegldToken.nativeValue,
  );

  // Query using raw method - arguments must be TypedValue instances
  final amountOutResult = await controller.queryRaw(
    endpointName: 'getAmountOut',
    arguments: [wegldToken, BigUIntValue(wegldAmount)],
  );

  // Decode the raw bytes manually
  // The response is a list of raw byte arrays - we need to decode them
  // Using the result's first getter which is null-safe
  final amountOutBytes = amountOutResult.first;
  if (amountOutBytes == null) {
    throw StateError('No data returned from getAmountOut query');
  }
  final amountOut = BinaryCodecUtils.bufferToBigInt(amountOutBytes);
  final minAmountOut = (amountOut * BigInt.from(9900)) ~/ BigInt.from(10000);

  print('Queried amount out: $amountOut');
  print('Minimum amount out (99%): $minAmountOut');

  final tokenTransfer = TokenTransferValue.fromPrimitives(
    tokenIdentifier: wegldToken.nativeValue,
    amount: wegldAmount,
  );

  // Call using raw method - arguments must be TypedValue instances
  final tx = await controller.callRaw(
    account: account,
    nonce: currentNonce,
    endpointName: 'swapTokensFixedInput',
    arguments: [mexToken, BigUIntValue(minAmountOut)],
    tokenTransfers: [tokenTransfer],
    options: const BaseControllerInput(gasLimit: GasLimit(15000000)),
  );
  final txHash = await provider.sendTransaction(tx);

  final watcher = TransactionWatcher(networkProvider: provider);
  final result = await watcher.awaitCompleted(txHash);
  print('Swap transaction: $result');

  final awaiter = AccountAwaiter(networkProvider: provider);
  final newAccount = await awaiter.awaitNonceIncrement(
    aliceAddress,
    currentNonce,
    options: const AccountAwaitingOptions(
      timeout: Duration(minutes: 2),
      pollingInterval: Duration(seconds: 5),
    ),
  );

  final mexTokenOnNetwork = await provider.getTokenOfAccount(
    aliceAddress,
    mexToken.nativeValue,
  );
  final wegldTokenOnNetwork = await provider.getTokenOfAccount(
    aliceAddress,
    wegldToken.nativeValue,
  );
  print('Old EGLD balance: ${freshAccount.balance.toDenominatedTrimmed}');
  print('New EGLD balance: ${newAccount.balance.toDenominatedTrimmed}');
  print('');
  print('Old WEGLD balance: ${oldWegldTokenOnNetwork.denominatedBalance}');
  print('New WEGLD balance: ${wegldTokenOnNetwork.denominatedBalance}');
  print('');
  print('Old MEX balance: ${oldMexTokenOnNetwork.denominatedBalance}');
  print('New MEX balance: ${mexTokenOnNetwork.denominatedBalance}');
}
