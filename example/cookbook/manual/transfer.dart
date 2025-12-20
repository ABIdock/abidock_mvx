import 'dart:io';
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  final ConsoleLogger logger = ConsoleLogger(
    minLevel: LogLevel.debug,
    includeTimestamp: true,
    prettyPrintContext: true,
    showBorders: true,
    useColors: true,
  );

  final alicePem = File('assets/alice.pem').readAsStringSync();
  final alice = await Account.fromPem(alicePem);

  final provider = GatewayNetworkProvider.devnet(logger: logger);
  final aliceOnNetwork = await provider.getAccount(alice.address);
  final Nonce currentNonce = aliceOnNetwork.nonce;

  final bobAddress = Address.fromBech32(
    'erd12m6dwylyqvz3282j857mldsdrfln476ww7k3kmpq0f0h7pvhl8qs4ucen5',
  );

  final controller = TransfersController(chainId: const ChainId.devnet());
  final tx = await controller.createTransactionForNativeTransfer(
    alice,
    currentNonce,
    NativeTransferInput(receiver: bobAddress, amount: Balance.fromEgld(0.1)),
  );

  final txHash = await provider.sendTransaction(tx);
  print('Transaction hash: $txHash');

  final awaiter = AccountAwaiter(networkProvider: provider);
  final newAccount = await awaiter.awaitNonceIncrement(
    alice.address,
    currentNonce,
    options: const AccountAwaitingOptions(
      timeout: Duration(minutes: 2),
      pollingInterval: Duration(seconds: 5),
    ),
  );

  print(
    'Transaction completed - New balance: ${newAccount.balance.toDenominated} EGLD',
  );
}
