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

  final pemRelayer = File('example/assets/bob.pem').readAsStringSync();
  final accountRelayer = UserSigner.fromPem(pemRelayer);
  final relayerAddress = await accountRelayer.getAddress();

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

  final wegldAmount = BigInt.from(1) * BigInt.from(10).pow(18);
  final wegldToken = TokenIdentifierValue('WEGLD-a28c59');
  final mexToken = TokenIdentifierValue('MEX-a659d0');

  final amountOutResult = await controller.query(
    endpointName: 'getAmountOut',
    arguments: [wegldToken, wegldAmount],
  );
  final amountOut = infer<BigInt>(amountOutResult[0]);
  final minAmountOut = (amountOut * BigInt.from(9900)) ~/ BigInt.from(10000);

  final tokenTransfer = TokenTransferValue.fromPrimitives(
    tokenIdentifier: wegldToken.identifier,
    amount: wegldAmount,
  );

  final innerTx = await controller.call(
    account: account,
    nonce: currentNonce,
    endpointName: 'swapTokensFixedInput',
    arguments: [mexToken, minAmountOut],
    tokenTransfers: [tokenTransfer],
    options: BaseControllerInput(relayer: relayerAddress),
  );

  final fullySignedTx = await innerTx.signAsRelayer(accountRelayer);
  final txHash = await provider.sendTransaction(fullySignedTx);

  final watcher = TransactionWatcher(networkProvider: provider);
  final result = await watcher.awaitCompleted(txHash);
  print('Swap transaction: $result');
}
