---
id: token-swap
title: Token Swap
sidebar_position: 2
description: Swap WEGLD to MEX tokens on xExchange DEX using abidock_mvx SDK.
---

# Token Swap on xExchange

Swap WEGLD for MEX tokens on the xExchange DEX.

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

  // 2. Load wallet
  final pem = File('assets/alice.pem').readAsStringSync();
  final account = await Account.fromPem(pem);
  final aliceAddress = account.address;

  // 3. Connect to network
  final provider = ApiNetworkProvider.devnet(logger: logger);
  final freshAccount = await provider.getAccount(aliceAddress);
  final currentNonce = freshAccount.nonce;

  // 4. Load contract ABI
  final abiJson = File('assets/pair.abi.json').readAsStringSync();
  final abi = SmartContractAbi.fromJson(abiJson);
  
  // 5. Create controller
  final controller = SmartContractController(
    contractAddress: SmartContractAddress.fromBech32(
      'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
    ),
    abi: abi,
    networkProvider: provider,
    logger: logger,
  );

  // 6. Define swap parameters
  final wegldAmount = BigInt.from(1) * BigInt.from(10).pow(17); // 0.1 WEGLD
  final wegldToken = TokenIdentifierValue('WEGLD-a28c59');
  final mexToken = TokenIdentifierValue('MEX-a659d0');

  // 7. Query expected output
  final amountOutResult = await controller.query(
    endpointName: 'getAmountOut',
    arguments: [wegldToken, wegldAmount],
  );
  final amountOut = amountOutResult.typedValues[0].nativeValue as BigInt;
  
  // 8. Calculate minimum with 1% slippage
  final minAmountOut = (amountOut * BigInt.from(9900)) ~/ BigInt.from(10000);

  // 9. Build swap transaction
  final tokenTransfer = TokenTransferValue.fromPrimitives(
    tokenIdentifier: wegldToken.identifier,
    amount: wegldAmount,
  );

  final tx = await controller.call(
    account: account,
    nonce: currentNonce,
    endpointName: 'swapTokensFixedInput',
    arguments: [mexToken, minAmountOut],
    tokenTransfers: [tokenTransfer],
    options: BaseControllerInput(gasLimit: GasLimit(25000000)),
  );

  // 10. Send transaction
  final txHash = await provider.sendTransaction(tx);

  // 11. Wait for completion
  final watcher = TransactionWatcher(networkProvider: provider);
  final result = await watcher.awaitCompleted(txHash);
  print('Swap completed: ${result.status.status}');
}
```

## Key Concepts

### Querying Expected Output

Before swapping, query the contract to get the expected output amount:

```dart
final amountOutResult = await controller.query(
  endpointName: 'getAmountOut',
  arguments: [wegldToken, wegldAmount],
);

// values[i] is the decoded native; typedValues[i] keeps the ABI type
final amountOut = amountOutResult.typedValues[0].nativeValue as BigInt;
```

### Slippage Protection

Always set a minimum output amount to protect against price changes:

```dart
// 1% slippage tolerance
final minAmountOut = (amountOut * BigInt.from(9900)) ~/ BigInt.from(10000);
```

### Token Transfers

Attach tokens to the transaction using `TokenTransferValue`:

```dart
final tokenTransfer = TokenTransferValue.fromPrimitives(
  tokenIdentifier: 'WEGLD-a28c59',
  amount: wegldAmount,
);
```

## See Also

- [Detailed Breakdown](/docs/advanced/cookbook-breakdown#token-swap) - Step-by-step explanation
- [Error Handling](/docs/advanced/error-handling) - Handle swap failures
