---
id: transaction-tracking
title: Transaction Tracking
sidebar_position: 6
description: Monitor MultiversX transaction status, wait for completion, and handle pending transactions with TransactionWatcher.
---

# Transaction Tracking

Monitor transaction status and wait for completion.

## TransactionWatcher

The main tool for tracking transactions:

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  
  // After sending a transaction
  final txHash = '...';
  
  // Create watcher
  final watcher = TransactionWatcher(networkProvider: provider);
  
  // Wait for completion
  final tx = await watcher.awaitCompleted(txHash);
  
  print('Status: ${tx.status.status}');
}
```

## Configuration Options

```dart
final watcher = TransactionWatcher(networkProvider: provider);

// Custom options for awaitCompleted
const options = TransactionAwaitingOptions(
  pollingInterval: Duration(seconds: 1), // Check frequency
  timeout: Duration(minutes: 5),         // Max wait time
);

final tx = await watcher.awaitCompleted(txHash, options: options);
```

## Transaction States

| Status | Description | Final? |
|--------|-------------|--------|
| `pending` | In mempool | No |
| `success` | Completed successfully | Yes |
| `fail` | Execution failed | Yes |
| `invalid` | Rejected by network | Yes |

## Handling Results

```dart
final watcher = TransactionWatcher(networkProvider: provider);
final tx = await watcher.awaitCompleted(txHash);

// Use convenience getters for status checks
if (tx.isSuccessful) {
  print('Transaction successful!');
  // Process results...
} else if (tx.hasFailed) {
  print('Transaction failed');
  // Check logs for error details
  if (tx.logs != null) {
    for (final event in tx.logs!.events) {
      if (event.identifier == 'signalError') {
        print('Error: ${event.topics}');
      }
    }
  }
} else if (tx.status.isInvalid) {
  print('Transaction invalid');
} else {
  print('Status: ${tx.status.status}');
}
```

## Parsing Transaction Results

### Smart Contract Results

```dart
final watcher = TransactionWatcher(networkProvider: provider);
final tx = await watcher.awaitCompleted(txHash);

if (tx.isSuccessful) {
  // Get smart contract results
  final scResults = tx.smartContractResults;
  
  if (scResults != null) {
    for (final result in scResults) {
      print('SC Result:');
      print('  Data: ${result['data']}');
      print('  Sender: ${result['sender']}');
      print('  Receiver: ${result['receiver']}');
    }
  }
}
```

### Events (Logs)

```dart
final watcher = TransactionWatcher(networkProvider: provider);
final tx = await watcher.awaitCompleted(txHash);

if (tx.logs != null) {
  for (final event in tx.logs!.events) {
    print('Event: ${event.identifier}');
    print('Topics: ${event.topics}');
    print('Data: ${event.data}');
  }
}
```

## Get Transaction Without Waiting

Check status without blocking:

```dart
void main() async {
  final provider = GatewayNetworkProvider.devnet();
  
  // Get current status
  final tx = await provider.getTransaction(txHash);
  
  if (tx.status.isPending) {
    print('Still processing...');
  } else {
    print('Completed: ${tx.status.status}');
  }
}
```

## Polling Manually

For custom tracking logic:

```dart
Future<TransactionOnNetwork> waitWithProgress(
  NetworkProvider provider,
  String txHash,
) async {
  var attempts = 0;
  const maxAttempts = 50;
  
  while (attempts < maxAttempts) {
    final tx = await provider.getTransaction(txHash);
    
    print('Attempt ${attempts + 1}: ${tx.status.status}');
    
    if (!tx.status.isPending) {
      return tx;
    }
    
    await Future.delayed(Duration(seconds: 1));
    attempts++;
  }
  
  throw TransactionWatcherTimeoutException(
    'Transaction polling exceeded $maxAttempts attempts',
    transactionHash: txHash,
  );
}
```

## Batch Transaction Tracking

Track multiple transactions:

```dart
Future<List<TransactionOnNetwork>> waitForAll(
  TransactionWatcher watcher,
  List<String> hashes,
) async {
  return Future.wait(
    hashes.map((hash) => watcher.awaitCompleted(hash)),
  );
}

// Usage
final results = await waitForAll(watcher, [hash1, hash2, hash3]);

for (final result in results) {
  print('${result.txHash}: ${result.status.status}');
}
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:convert';
import 'dart:typed_data';

void main() async {
  print('=== Transaction Tracking Demo ===\n');
  
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('your mnemonic...');
  
  // Send a transaction
  final config = await provider.getNetworkConfig();
  final networkAccount = await provider.getAccount(account.address);
  
  final tx = Transaction(
    sender: account.address,
    receiver: account.address, // Self-transfer for demo
    value: Balance.zero(),
    nonce: networkAccount.nonce,
    gasLimit: GasLimit(50000),
    gasPrice: GasPrice(1000000000),
    chainId: ChainId(config.chainId),
    version: TransactionVersion(1),
    data: Uint8List.fromList(utf8.encode('tracking demo')),
  );
  
  final signature = await account.signTransaction(tx);
  final signed = tx.copyWith(newSignature: Signature.fromUint8List(signature));
  final hash = await provider.sendTransaction(signed);
  
  print('Transaction sent: $hash');
  print('');
  
  // Track with progress
  final watcher = TransactionWatcher(networkProvider: provider);
  
  String lastStatus = '';
  
  // Poll until complete
  while (true) {
    final current = await provider.getTransaction(hash);
    final currentStatusStr = current.status.status;
    
    if (currentStatusStr != lastStatus) {
      lastStatus = currentStatusStr;
      print('  Status: $lastStatus');
    }
    
    if (!current.status.isPending) {
      break;
    }
    
    await Future.delayed(Duration(seconds: 3));
  }
  
  // Get final details
  final finalTx = await provider.getTransaction(hash);
  
  print('Hash: ${finalTx.txHash}');
  print('Status: ${finalTx.status.status}');
  print('Sender: ${finalTx.transaction.sender.bech32}');
  print('Receiver: ${finalTx.transaction.receiver.bech32}');
  print('Value: ${finalTx.transaction.value}');
  print('Gas Limit: ${finalTx.transaction.gasLimit.value}');
  print('Gas Price: ${finalTx.transaction.gasPrice.value}');
  
  if (finalTx.smartContractResults?.isNotEmpty ?? false) {
    for (final scr in finalTx.smartContractResults!) {
      print('  - ${scr['data']}');
    }
  }
  

}
```

## Error Handling

```dart
try {
  final tx = await watcher.awaitCompleted(
    txHash,
    options: const TransactionAwaitingOptions(
      timeout: Duration(minutes: 2),
    ),
  );
  
  if (tx.hasFailed) {
    throw Exception(
      'Transaction failed: ${tx.status.status}',
    );
  }
  
  return tx;
} on TransactionWatcherTimeoutException {
  print('Transaction is taking too long');
  // Could still be pending - check later
} on TransactionWatcherException catch (e) {
  print('Watcher error: $e');
}
```

## Next Steps

- [Transactions Overview](/docs/transactions/overview) - Transaction basics
- [Smart Contracts](/docs/smart-contracts/overview) - Contract interactions
- [Network Providers](/docs/network/providers) - Provider configuration
