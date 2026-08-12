---
id: overview
title: Cookbook Overview
sidebar_position: 1
description: Runnable examples for swaps, transfers, relayed transactions, and event streaming.
---

# Cookbook

Copy-paste examples for swaps, transfers, relayed transactions, and event streaming.

## Available Examples

| Example | Description | Complexity |
|---------|-------------|------------|
| [Token Swap](/docs/cookbook/token-swap) | Swap tokens on xExchange DEX | ⭐⭐ |
| [Relayed Transaction](/docs/cookbook/relayed-transaction) | Gas-free transactions with relayer | ⭐⭐⭐ |
| [EGLD Transfer](/docs/cookbook/egld-transfer) | Send native EGLD between accounts | ⭐ |
| [WebSocket Events](/docs/cookbook/websocket-events) | Real-time blockchain event streaming | ⭐⭐ |

## Running Examples

All examples are located in the `example/cookbook/manual/` directory and can be run directly:

```bash
# Token swap example
dart run example/cookbook/manual/controller_swap.dart

# Same swap, built without an ABI (raw typed values)
dart run example/cookbook/manual/controller_swap_without_abi.dart

# Relayed transaction example
dart run example/cookbook/manual/controller_relayed_swap.dart

# EGLD transfer example
dart run example/cookbook/manual/transfer.dart

# WebSocket events example
dart run example/cookbook/manual/websocket_events.dart
```

Generated-code counterparts live in `example/cookbook/generated/`.

## Prerequisites

Before running examples, ensure you have:

1. **PEM wallet files** in `assets/` directory (alice.pem, bob.pem)
2. **Devnet tokens** - Get free tokens from the [MultiversX Faucet](https://devnet-wallet.multiversx.com/faucet)
3. **Dependencies installed** - Run `dart pub get`

:::tip
All examples use devnet by default. Never use mainnet credentials for testing!
:::

## Example Structure

Each cookbook example follows this pattern:

```dart
// 1. Setup logging and providers
final logger = ConsoleLogger(...);
final provider = GatewayNetworkProvider.devnet(logger: logger);

// 2. Load wallet and get account state
final account = await Account.fromPem(pem);
final freshAccount = await provider.getAccount(account.address);

// 3. Build transaction or query
final tx = await controller.call(
  account: account,
  nonce: freshAccount.nonce,
  endpointName: 'myEndpoint',
  arguments: [...],
  options: BaseControllerInput(gasLimit: GasLimit(10000000)),
);

// 4. Send and await completion
final txHash = await provider.sendTransaction(tx);
final result = await watcher.awaitCompleted(txHash);
```

## Detailed Breakdowns

For in-depth explanations of each example, see the [Advanced Cookbook](/docs/advanced/cookbook-breakdown) section.
