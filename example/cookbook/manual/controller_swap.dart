import 'dart:io';

import 'package:abidock_mvx/abidock_mvx.dart';

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

  final abiJson = File('example/cookbook/pair.abi.json').readAsStringSync();
  final abi = SmartContractAbi.fromJson(abiJson);
  final contractAddress = SmartContractAddress.fromBech32(
    'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
  );
  final controller = SmartContractController(
    contractAddress: contractAddress,
    abi: abi,
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

  final amountOutResult = await controller.query(
    endpointName: 'getAmountOut',
    arguments: [wegldToken.nativeValue, wegldAmount],
  );
  final amountOut = infer<BigInt>(amountOutResult[0]);
  final minAmountOut = (amountOut * BigInt.from(9900)) ~/ BigInt.from(10000);

  final tokenTransfer = TokenTransferValue.fromPrimitives(
    tokenIdentifier: wegldToken.nativeValue,
    amount: wegldAmount,
  );

  final tx = await controller.call(
    account: account,
    nonce: currentNonce,
    endpointName: 'swapTokensFixedInput',
    arguments: [mexToken.nativeValue, minAmountOut],
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
