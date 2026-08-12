---
id: egld-transfer
title: EGLD Transfer
sidebar_position: 4
description: Send native EGLD tokens between MultiversX accounts with logging and tracking.
---

# EGLD Transfer

Send native EGLD tokens between accounts.

## Complete Example

```dart
import 'dart:io';
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  // 1. Setup logging
  final logger = ConsoleLogger(
    minLevel: LogLevel.debug,
    includeTimestamp: true,
    prettyPrintContext: true,
    showBorders: true,
    useColors: true,
  );

  // 2. Load sender wallet
  final alicePem = File('assets/alice.pem').readAsStringSync();
  final alice = await Account.fromPem(alicePem);

  // 3. Connect to network
  final provider = GatewayNetworkProvider.devnet(logger: logger);
  final aliceOnNetwork = await provider.getAccount(alice.address);
  final currentNonce = aliceOnNetwork.nonce;

  // 4. Define receiver
  final bobAddress = Address.fromBech32(
    'erd12m6dwylyqvz3282j857mldsdrfln476ww7k3kmpq0f0h7pvhl8qs4ucen5',
  );

  // 5. Create transfer controller
  final controller = TransfersController(chainId: const ChainId.devnet());
  
  // 6. Build transfer transaction
  final tx = await controller.createTransactionForNativeTransfer(
    alice,
    currentNonce,
    NativeTransferInput(
      receiver: bobAddress, 
      amount: Balance.fromEgld(0.1),
    ),
  );

  // 7. Send transaction
  final txHash = await provider.sendTransaction(tx);
  print('Transaction hash: $txHash');

  // 8. Wait for completion
  final awaiter = AccountAwaiter(networkProvider: provider);
  final newAccount = await awaiter.awaitNonceIncrement(
    alice.address,
    currentNonce,
    options: const AccountAwaitingOptions(
      timeout: Duration(minutes: 2),
      pollingInterval: Duration(seconds: 5),
    ),
  );

  print('Transaction completed!');
  print('New balance: ${newAccount.balance.toDenominated} EGLD');
}
```

## Key Concepts

### TransfersController

Use `TransfersController` for simple transfers instead of `SmartContractController`:

```dart
final controller = TransfersController(chainId: const ChainId.devnet());
```

### Balance Helpers

Create balance amounts using convenient methods:

```dart
Balance.fromEgld(0.1)           // 0.1 EGLD
Balance.fromEgld(1.5)           // 1.5 EGLD
Balance(BigInt.from(10).pow(17)) // 0.1 EGLD (raw)
```

### Awaiting Completion

Two ways to wait for transaction completion:

```dart
// Option 1: Watch transaction hash
final watcher = TransactionWatcher(networkProvider: provider);
await watcher.awaitCompleted(txHash);

// Option 2: Wait for nonce increment
final awaiter = AccountAwaiter(networkProvider: provider);
await awaiter.awaitNonceIncrement(address, currentNonce);
```

### Chain ID

Always specify the correct chain ID:

```dart
ChainId.mainnet()  // Mainnet
ChainId.devnet()   // Devnet
ChainId.testnet()  // Testnet
```

## Transfer Types

`TransfersController` exposes three methods; each returns a **signed**
transaction ready to broadcast.

| Method | Input | Sends |
|--------|-------|-------|
| `createTransactionForNativeTransfer` | `NativeTransferInput` | EGLD, with an optional `data` payload |
| `createTransactionForTokenTransfer` | `TokenTransferInput` | One or more ESDT / NFT / SFT transfers |
| `createTransactionForMultiTokenTransfer` | `TokenTransferInput` | Same as above, named for multi-token batches |

The transfer protocol is chosen for you from the transfer list —
`ESDTTransfer`, `ESDTNFTTransfer`, or `MultiESDTNFTTransfer`:

```dart
final tx = await controller.createTransactionForTokenTransfer(
  alice,
  currentNonce,
  TokenTransferInput(
    receiver: bobAddress,
    transfers: [
      TokenTransfer.fungible(
        tokenIdentifier: 'WEGLD-a28c59',
        amount: BigInt.from(10).pow(17),
      ),
      TokenTransfer.nonFungible(
        tokenIdentifier: 'APES-abcdef',
        nonce: 1,
        amount: BigInt.one,
      ),
    ],
  ),
);
```

Every method takes an optional `baseOptions` for gas, guardian, and relayer
overrides:

```dart
final tx = await controller.createTransactionForNativeTransfer(
  alice,
  currentNonce,
  NativeTransferInput(receiver: bobAddress, amount: Balance.fromEgld(0.1)),
  baseOptions: BaseControllerInput(gasLimit: GasLimit(60000)),
);
```

## See Also

- [Detailed Breakdown](/docs/advanced/cookbook-breakdown#egld-transfer) - Step-by-step explanation
- [Transaction Guide](/docs/transactions/overview) - All transaction types
