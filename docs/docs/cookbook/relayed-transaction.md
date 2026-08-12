---
id: relayed-transaction
title: Relayed Transaction
sidebar_position: 3
description: Execute transactions on MultiversX where a relayer pays the fees.
---

# Relayed Transactions

A relayed transaction is one flat transaction that carries **two** signatures:
the sender's, and the relayer's. The relayer pays the fee; the sender's own
EGLD balance is untouched. There is no wrapper transaction and no nested
payload — the relayer is a field on the transaction itself, next to a second
signature slot.

That has one consequence worth memorising: **the relayer must be set before
anyone signs**, because the relayer address is part of the bytes both parties
sign.

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
  final relayerSigner = UserSigner.fromPem(pemRelayer);
  final relayerAddress = await relayerSigner.getAddress();

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
  final amountOut = amountOutResult.typedValues[0].nativeValue as BigInt;
  final minAmountOut = (amountOut * BigInt.from(9900)) ~/ BigInt.from(10000);

  // 9. Build and sign the call with the relayer already attached
  final tokenTransfer = TokenTransferValue.fromPrimitives(
    tokenIdentifier: wegldToken.identifier,
    amount: wegldAmount,
  );

  final senderSigned = await controller.call(
    account: account,
    nonce: currentNonce,
    endpointName: 'swapTokensFixedInput',
    arguments: [mexToken, minAmountOut],
    tokenTransfers: [tokenTransfer],
    options: BaseControllerInput(
      gasLimit: GasLimit(25000000),
      relayer: relayerAddress, // part of the signed payload
    ),
  );

  // 10. Relayer adds the second signature
  final broadcastable = await senderSigned.signAsRelayer(relayerSigner);

  // 11. Send transaction
  final txHash = await provider.sendTransaction(broadcastable);

  // 12. Wait for completion
  final watcher = TransactionWatcher(networkProvider: provider);
  final result = await watcher.awaitCompleted(txHash);
  print('Relayed swap completed: ${result.status.status}');
}
```

## Key Concepts

### Two Wallets, One Transaction

1. **User wallet** (`alice.pem`) - performs the action, produces `signature`
2. **Relayer wallet** (`bob.pem`) - pays the fee, produces `relayerSignature`

Both sign the same serialized payload, so the order of the two signatures does
not matter.

### Setting the Relayer

Through a controller, pass the relayer in `BaseControllerInput`; the controller
attaches it before it signs:

```dart
options: BaseControllerInput(
  gasLimit: GasLimit(25000000),
  relayer: relayerAddress,
),
```

Building the transaction by hand? Use `RelayedTransactionsFactory.applyRelayer`
on the **unsigned** transaction. It also bumps the version so the transaction
can carry options, and adds the relayed base gas once:

```dart
final factory = RelayedTransactionsFactory(
  RelayedTransactionsConfig(chainId: const ChainId.devnet()),
);

final relayed = factory.applyRelayer(unsignedTx, relayerAddress);
final senderSigned = await relayed.signWith(senderSigner);
final broadcastable = await senderSigned.signAsRelayer(relayerSigner);
```

### Relayer Signature

`signAsRelayer` fills in `relayerSignature` and returns a new transaction:

```dart
final broadcastable = await senderSigned.signAsRelayer(relayerSigner);
print(broadcastable.isFullySigned); // true
```

### Rules the SDK Enforces

| Rule | What happens if you break it |
|------|------------------------------|
| Relayer set before any signature | `applyRelayer` throws `ArgumentError` |
| Sender and relayer in the same shard | `applyRelayer` and `signAsRelayer` throw |
| Relayer differs from the guardian | `applyRelayer` throws — the chain rejects it |
| One relayer per transaction | Re-relaying with a different address throws `StateError` |
| Transaction chain ID matches the factory | `applyRelayer` throws `ArgumentError` |

Use `Address.getShardOfAddress` up front if you need to pick a relayer that
matches the sender's shard.

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
     │ 1. Build TX with  │                   │
     │    relayer field  │                   │
     │    set, then sign │                   │
     ├──────────────────►│                   │
     │                   │                   │
     │                   │ 2. Add relayer    │
     │                   │    signature      │
     │                   │                   │
     │                   │ 3. Send TX        │
     │                   ├──────────────────►│
     │                   │                   │
     │                   │ 4. Relayer pays   │
     │                   │    the fee        │
     │                   │◄──────────────────┤
     │                   │                   │
```

## See Also

- [Detailed Breakdown](/docs/advanced/cookbook-breakdown#relayed-transaction) - Step-by-step explanation
- [Relayed Transactions](/docs/smart-contracts/relayed-transactions) - Factory-level reference
- [Best Practices](/docs/advanced/best-practices) - Security considerations
