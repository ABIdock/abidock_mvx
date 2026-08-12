---
id: overview
title: Transactions Overview
sidebar_position: 1
description: Guide to MultiversX transactions including EGLD, ESDT, NFT, and multi-transfers with signing and tracking.
---

# Transactions

abidock_mvx handles EGLD, ESDT tokens, NFTs, and multi-transfers.

## Transaction Types

| Type | Description |
|------|-------------|
| **EGLD Transfer** | Native token transfers |
| **ESDT Transfer** | Fungible token transfers |
| **NFT Transfer** | Non-fungible token transfers |
| **Multi Transfer** | Multiple tokens in one transaction |
| **Smart Contract** | Contract interactions |

## Basic Transaction Structure

Every transaction requires typed parameters:

```dart
import 'dart:typed_data';

final senderAddress = Address.fromBech32('erd1...sender...');
final receiverAddress = Address.fromBech32('erd1...receiver...');

final tx = Transaction(
  sender: senderAddress,              // Who sends (Address)
  receiver: receiverAddress,          // Who receives (Address)
  value: Balance.fromEgld(0.1),       // EGLD amount (Balance)
  nonce: Nonce(5),                    // Sender's next nonce (Nonce)
  gasLimit: GasLimit(50000),          // Maximum gas (GasLimit)
  gasPrice: GasPrice(1000000000),     // Gas price (GasPrice)
  chainId: ChainId('D'),              // Network (ChainId)
  version: TransactionVersion(1),      // Transaction version
  data: Uint8List(0),                 // Optional data field (Uint8List)
);
```

## Transaction Flow

```
┌─────────────┐
│  1. Create  │  Build transaction
└──────┬──────┘
       │
┌──────▼──────┐
│   2. Sign   │  Cryptographic signature
└──────┬──────┘
       │
┌──────▼──────┐
│   3. Send   │  Submit to network
└──────┬──────┘
       │
┌──────▼──────┐
│   4. Wait   │  Monitor status
└──────┬──────┘
       │
┌──────▼──────┐
│  5. Verify  │  Check results
└─────────────┘
```

## Quick Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:typed_data';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('your mnemonic...');
  
  // Get network config and account info
  final config = await provider.getNetworkConfig();
  final accountInfo = await provider.getAccount(account.address);
  
  // Create EGLD transfer
  final tx = Transaction(
    sender: account.address,
    receiver: Address.fromBech32('erd1...recipient...'),
    value: Balance.fromEgld(0.1),
    nonce: accountInfo.nonce,
    gasLimit: GasLimit(50000),
    gasPrice: GasPrice(1000000000),
    chainId: ChainId(config.chainId),
    version: TransactionVersion(1),
    data: Uint8List(0),
  );
  
  // Sign
  final signature = await account.signTransaction(tx);
  final signed = tx.copyWith(
    newSignature: Signature.fromUint8List(signature),
  );
  
  // Send
  final hash = await provider.sendTransaction(signed);
  print('Transaction: $hash');
  
  // Wait for completion
  final watcher = TransactionWatcher(networkProvider: provider);
  final result = await watcher.awaitCompleted(hash);
  
  print('Status: ${result.status.status}');
}
```

## Gas Configuration

Every gas limit the factories compute has two parts:

```
gasLimit = dataMovementGas + executionGas
dataMovementGas = minGasLimit + gasLimitPerByte * data.length
```

`minGasLimit` is 50,000 and `gasLimitPerByte` is 1,500 by default; both come
from `/network/config` (`config.minGasLimit`, `config.gasPerDataByte`). The
execution term is what the endpoint itself costs.

### Standard Gas Values

| Operation | Execution gas | Total (with data-movement term) |
|-----------|---------------|---------------------------------|
| EGLD Transfer (no data) | 0 | 50,000 |
| ESDT Transfer | 300,000 | 350,000 + 1,500 x data bytes |
| NFT / SFT Transfer | 1,000,000 | 1,050,000 + 1,500 x data bytes |
| Multi Transfer (N tokens) | 800,000 + 200,000 x N | 850,000 + 200,000 x N + 1,500 x data bytes |
| Contract call | Endpoint-specific | Endpoint cost + data-movement term |

### Gas Price

Default gas price is usually `1000000000`. Get from network config -- note that
`minGasPrice` is a plain `int`, so wrap it before handing it to a transaction:

```dart
final config = await provider.getNetworkConfig();
final gasPrice = GasPrice(config.minGasPrice);
```

## Transaction Status

`TransactionStatus` wraps the raw status string the node, Gateway or Proxy
reports. Several spellings mean the same thing, so prefer the predicates over
string comparison:

| Status | Meaning | Predicate |
|--------|---------|-----------|
| `pending` | In mempool, not yet processed | `isPending` |
| `received` | Accepted into the mempool | `isPending` |
| `executed` | Executed in a block | `isExecuted` / `isSuccessful` |
| `success` | Executed successfully | `isExecuted` / `isSuccessful` |
| `successful` | Executed successfully (Gateway spelling) | `isExecuted` / `isSuccessful` |
| `fail` | Execution failed (short spelling) | `isFailed` |
| `failed` | Execution failed | `isFailed` |
| `unsuccessful` | Execution failed (Gateway spelling) | `isFailed` |
| `invalid` | Rejected before execution | `isInvalid`, also `isFailed` |
| `not-executable-in-block` | Proposed in a block but absent from its execution result | `isNotExecutableInBlock` |
| `reward-reverted` | Reward transaction was reverted | - |
| `unknown` | No observer could report a status | - |

Two aggregate predicates matter when you are waiting on a transaction:

- `isCompleted` -- executed with an outcome, success **or** failure.
- `isFinal` -- broader: `isCompleted` plus `not-executable-in-block`, i.e. the
  status will not change again. This is what `TransactionWatcher.awaitCompleted`
  waits for.

```dart
final watcher = TransactionWatcher(networkProvider: provider);
final tx = await watcher.awaitCompleted(hash);

// Use convenience getters for status checks
if (tx.isSuccessful) {
  print('Transaction succeeded!');
} else if (tx.hasFailed) {
  print('Transaction failed: ${tx.status.status}');
  // Check logs for error details
  if (tx.logs != null) {
    for (final event in tx.logs!.events) {
      if (event.identifier == 'signalError') {
        print('Error: ${event.topics}');
      }
    }
  }
} else {
  print('Status: ${tx.status.status}');
}
```

## Error Handling

```dart
try {
  // Validate balance before sending (manual check)
  final account = await provider.getAccount(tx.sender);
  final totalCost = tx.value.value + tx.gasLimit.toBigInt * tx.gasPrice.toBigInt;
  
  if (account.balance.value < totalCost) {
    print('Not enough balance for transaction + gas');
    return;
  }
  
  // Validate nonce (manual check)
  if (tx.nonce != account.nonce) {
    print('Invalid nonce: expected ${account.nonce.value}, got ${tx.nonce.value}');
    return;
  }
  
  final hash = await provider.sendTransaction(signedTx);
  // ...
} on NetworkException catch (e) {
  print('Network error: ${e.message}');
  if (e.statusCode == 404) {
    print('Transaction not found');
  }
} on TransactionException catch (e) {
  print('Transaction error: ${e.message}');
}
```

## Next Steps

- [EGLD Transfers](/docs/transactions/egld-transfers) - Native token transfers
- [ESDT Transfers](/docs/transactions/esdt-transfers) - Fungible tokens
- [NFT Transfers](/docs/transactions/nft-transfers) - Non-fungible tokens
- [Multi Transfers](/docs/transactions/multi-transfers) - Multiple tokens
- [Transaction Tracking](/docs/transactions/transaction-tracking) - Monitor status
