---
id: overview
title: Smart Contracts Overview
sidebar_position: 1
description: Learn how to interact with MultiversX smart contracts using ABI definitions for type-safe queries and calls.
---

# Smart Contracts

abidock_mvx uses ABI (Application Binary Interface) files to interact with MultiversX smart contracts.

## What is an ABI?

An ABI defines the interface of a smart contract:
- **Endpoints** - Functions you can call
- **Views** - Read-only query functions  
- **Types** - Custom structs, enums, and type definitions
- **Events** - Emitted events

Example ABI structure:
```json
{
  "name": "MyContract",
  "endpoints": [
    {
      "name": "deposit",
      "mutability": "mutable",
      "inputs": [],
      "outputs": []
    },
    {
      "name": "getBalance",
      "mutability": "readonly",
      "inputs": [{"name": "address", "type": "Address"}],
      "outputs": [{"type": "BigUint"}]
    }
  ]
}
```

## Quick Start

```dart
import 'dart:io';

import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  // 1. Load the ABI
  final abiJson = await File('contract.abi.json').readAsString();
  final abi = SmartContractAbi.fromJson(abiJson);
  
  // 2. Create provider
  final provider = GatewayNetworkProvider.devnet();
  
  // 3. Create controller
  final contractAddress = SmartContractAddress.fromBech32('erd1qqq...');
  final controller = SmartContractController(
    contractAddress: contractAddress,
    abi: abi,
    networkProvider: provider,
  );
  
  // 4. Query the contract (pass bech32 string for address arguments)
  final result = await controller.query(
    endpointName: 'getBalance',
    arguments: ['erd1...user-address...'],  // bech32 string
  );
  
  print('Balance: ${result.first}');
}
```

## Controller vs Direct Calls

| Approach | Use Case |
|----------|----------|
| **SmartContractController** | Type-safe, ABI-aware calls |
| **SmartContractController.withoutAbi** | No ABI, manual TypedValue encoding |
| **Direct Provider Calls** | Low-level, maximum control |

### Controller with ABI (Recommended)

```dart
// Automatic encoding based on ABI
final result = await controller.query(
  endpointName: 'getUser',
  arguments: [BigInt.from(123)],
);
```

### Controller without ABI

```dart
// No ABI - use TypedValue arguments
final controller = SmartContractController.withoutAbi(
  contractAddress: SmartContractAddress.fromBech32('erd1qqq...'),
  networkProvider: provider,
);

// Query with TypedValue - returns raw bytes
final result = await controller.queryRaw(
  endpointName: 'getBalance',
  arguments: [AddressValue.fromBech32('erd1user...')],
);

// Call with TypedValue
final tx = await controller.callRaw(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'deposit',
  arguments: [BigUIntValue(BigInt.from(1000))],
  options: BaseControllerInput(gasLimit: GasLimit(10000000)),
);
```

### Direct Call

For direct low-level queries (advanced use):

```dart
// Low-level query without controller
final query = SmartContractQuery.view(
  contract: SmartContractAddress.fromBech32('erd1qqq...'),
  function: SmartContractFunction('getUser'),
  arguments: [BigUIntType.create(BigInt.from(123))], // Typed values
);

final response = await provider.queryContract(query);
```

## Key Concepts

### Endpoints vs Views

| Type | Mutability | Gas | State Change |
|------|------------|-----|--------------|
| **View** | `readonly` | Free | No |
| **Endpoint** | `mutable` | Required | Yes |

```dart
// View (query) - free, no transaction
final balance = await controller.query(
  endpointName: 'getBalance',
  arguments: [],
);

// Endpoint (call) - requires transaction
final tx = await controller.call(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'deposit',
  arguments: [],
  value: Balance.fromEgld(1),
  options: BaseControllerInput(gasLimit: GasLimit(10000000)),
);
```

### Payable Endpoints

Some endpoints accept EGLD or tokens:

```dart
// Payable in EGLD
final tx = await controller.call(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'deposit',
  arguments: [],
  value: Balance.fromEgld(1), // 1 EGLD
  options: BaseControllerInput(gasLimit: GasLimit(10000000)),
);

// Payable in ESDT
final tx = await controller.call(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'stake',
  arguments: [],
  tokenTransfers: [
    TokenTransferValue.fromPrimitives(
      tokenIdentifier: 'USDC-123456',
      amount: BigInt.from(1000000), // 1 USDC (6 decimals)
    ),
  ],
  options: BaseControllerInput(gasLimit: GasLimit(15000000)),
);
```

## Workflow Summary

```
1. Load ABI          → SmartContractAbi.fromJson()
2. Create Controller → SmartContractController()
3. Query Views       → controller.query()
4. Build Transaction → controller.call()
5. Sign Transaction  → (handled by controller internally)
6. Send Transaction  → provider.sendTransaction()
7. Wait for Result   → watcher.awaitCompleted()
```

## Next Steps

- [Loading ABI](/docs/smart-contracts/loading-abi) - Different ways to load ABIs
- [Queries](/docs/smart-contracts/queries) - Read data from contracts
- [Interactions](/docs/smart-contracts/interactions) - Execute contract calls
- [Relayed Transactions](/docs/smart-contracts/relayed-transactions) - Gas-free user transactions
