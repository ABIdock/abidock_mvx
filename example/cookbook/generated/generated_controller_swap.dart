import 'dart:io';
import 'package:abidock_mvx/abidock_mvx.dart';

import 'pair/pair.dart';

Future<void> main() async {
  final pem = File('assets/alice.pem').readAsStringSync();
  final account = await Account.fromPem(pem);

  final provider = ApiNetworkProvider.devnet();
  final accountOnNetwork = await provider.getAccount(account.address);
  final Nonce currentNonce = accountOnNetwork.nonce;
  final controller = PairController(
    contractAddress:
        'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
    networkProvider: provider,
  );

  final wegldAmount = BigInt.from(1) * BigInt.from(10).pow(18);
  const wegldIdentifier = 'WEGLD-a28c59';
  const mexIdentifier = 'MEX-a659d0';

  final amountOut = await controller.getAmountOut(wegldIdentifier, wegldAmount);

  final minAmountOut = (amountOut * BigInt.from(9900)) ~/ BigInt.from(10000);

  final wegldTransfer = TokenTransferValue.fromPrimitives(
    tokenIdentifier: wegldIdentifier,
    amount: wegldAmount,
  );

  final tx = await controller.swapTokensFixedInput(
    account,
    currentNonce,
    mexIdentifier,
    minAmountOut,
    tokenTransfers: [wegldTransfer],
  );

  final txHash = await provider.sendTransaction(tx);
  print('Generated codegen swap: $txHash');

  final watcher = TransactionWatcher(networkProvider: provider);
  final receipt = await watcher.awaitCompleted(txHash);
  print('Execution status: ${receipt.status}');
}
