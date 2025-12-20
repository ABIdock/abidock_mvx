---
id: relayed-transaction
title: Relayed Transaction
sidebar_position: 3
description: Execute gas-free transactions on MultiversX where a relayer pays the fees.
---

# Relayed Transactions

Execute gas-free transactions where a relayer pays the fees.

## Complete Example

```dart
import 'dart:io';
import 'package:abidock_mvx/abidock_mvx.dart';

Future<void> main() async {
  // 1. Setup logging
  final logger = ConsoleLogger(
    minLevel: LogLevel.debug,
    includeTimestamp: true,
    prettyPrintContext: true,
    showBorders: true,
    useColors: true,
  );

  // 2. Load user wallet (the one performing the swap)
  final pem = File('assets/alice.pem').readAsStringSync();
  final account = await Account.fromPem(pem);
  final aliceAddress = account.address;

  // 3. Load relayer wallet (pays gas fees)
  final pemRelayer = File('assets/bob.pem').readAsStringSync();
  final accountRelayer = UserSigner.fromPem(pemRelayer);
  final relayerAddress = await accountRelayer.getAddress();

  // 4. Connect to network
  final provider = ApiNetworkProvider.devnet(logger: logger);
  final freshAccount = await provider.getAccount(aliceAddress);
  final currentNonce = freshAccount.nonce;

  // 5. Load contract ABI
  final abiJson = File('assets/pair.abi.json').readAsStringSync();
  final abi = SmartContractAbi.fromJson(abiJson);
  
  // 6. Create controller
  final controller = SmartContractController(
    contractAddress: SmartContractAddress.fromBech32(
      'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
    ),
    abi: abi,
    networkProvider: provider,
    logger: logger,
  );

  // 7. Define swap parameters
  final wegldAmount = BigInt.from(1) * BigInt.from(10).pow(18); // 1 WEGLD
  final wegldToken = TokenIdentifierValue('WEGLD-a28c59');
  final mexToken = TokenIdentifierValue('MEX-a659d0');

  // 8. Query expected output
  final amountOutResult = await controller.query(
    endpointName: 'getAmountOut',
    arguments: [wegldToken, wegldAmount],
  );
  final amountOut = infer<BigInt>(amountOutResult[0]);
  final minAmountOut = (amountOut * BigInt.from(9900)) ~/ BigInt.from(10000);

  // 9. Build inner transaction with relayer option
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
    options: BaseControllerInput(
      gasLimit: GasLimit(25000000),
      relayer: relayerAddress,
    ), // Specify relayer
  );

  // 10. Relayer signs the transaction
  final fullySignedTx = await innerTx.signAsRelayer(accountRelayer);

  // 11. Send transaction
  final txHash = await provider.sendTransaction(fullySignedTx);

  // 12. Wait for completion
  final watcher = TransactionWatcher(networkProvider: provider);
  final result = await watcher.awaitCompleted(txHash);
  print('Relayed swap completed: $result');
}
```

## Key Concepts

### Two Wallets Required

1. **User wallet** (`alice.pem`) - Performs the action, signs the inner transaction
2. **Relayer wallet** (`bob.pem`) - Pays gas fees, signs as relayer

### Setting the Relayer

Pass the relayer address in `BaseControllerInput`:

```dart
options: BaseControllerInput(
  gasLimit: GasLimit(25000000),
  relayer: relayerAddress,
),
```

### Relayer Signature

After the user signs, the relayer must also sign:

```dart
final fullySignedTx = await innerTx.signAsRelayer(accountRelayer);
```

### Use Cases

- **Gasless UX** - Users don't need EGLD for gas
- **Sponsored transactions** - dApps pay user fees
- **Meta-transactions** - Backend relayer services

## Flow Diagram

```
┌─────────┐         ┌─────────┐         ┌──────────┐
│  User   │         │ Relayer │         │ Network  │
└────┬────┘         └────┬────┘         └────┬─────┘
     │                   │                   │
     │ 1. Build TX       │                   │
     │ (with relayer)    │                   │
     ├──────────────────►│                   │
     │                   │                   │
     │                   │ 2. Sign as        │
     │                   │    relayer        │
     │                   │                   │
     │                   │ 3. Send TX        │
     │                   ├──────────────────►│
     │                   │                   │
     │                   │ 4. TX executed    │
     │                   │◄──────────────────┤
     │                   │                   │
```

## See Also

- [Detailed Breakdown](/docs/advanced/cookbook-breakdown#relayed-transaction) - Step-by-step explanation
- [Best Practices](/docs/advanced/best-practices) - Security considerations
