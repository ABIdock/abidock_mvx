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
  patience: Duration(seconds: 2),        // Re-fetch delay once in a block
);

final tx = await watcher.awaitCompleted(txHash, options: options);
```

| Option | Default | Effect |
|--------|---------|--------|
| `timeout` | 9 s | Gives up with `TransactionWatcherTimeoutException` |
| `pollingInterval` | 600 ms | Delay between status fetches |
| `patience` | `Duration.zero` | Once the status is final **and** the transaction is in a block, wait this long and fetch once more, so late-arriving logs and results are included |
| `maxConsecutiveErrors` | 5 | Consecutive fetch failures tolerated before throwing `TransactionWatcherException` |
| `awaitCrossShardCompletion` | `false` | Also wait for the chain's `completedTxEvent` log |
| `numShards` / `roundDuration` | `null` | When both are set, the effective timeout becomes `max(timeout, roundDuration * (numShards + 1) * 3)` |

### Cross-shard calls

A cross-shard contract call often reads as successful the moment it is included
on the source shard, while its destination smart contract result is still in
flight -- so the snapshot you get back can be missing results. Set
`awaitCrossShardCompletion: true` to hold until the chain emits
`completedTxEvent`, which fires once every cross-shard result has been
produced. Pair it with a longer timeout scaled from the network's round
duration:

```dart
final config = await provider.getNetworkConfig();

final options = TransactionAwaitingOptions(
  awaitCrossShardCompletion: true,
  numShards: config.numShards,
  roundDuration: Duration(milliseconds: config.roundDuration),
);

final tx = await watcher.awaitCompleted(txHash, options: options);
```

## Transaction States

`awaitCompleted` returns as soon as the status is **final** -- meaning it will
not change again:

| Status | Description | Final? |
|--------|-------------|--------|
| `pending` | In mempool | No |
| `received` | Accepted into the mempool | No |
| `executed` | Executed in a block | Yes |
| `success` | Completed successfully | Yes |
| `successful` | Completed successfully (Gateway spelling) | Yes |
| `fail` | Execution failed (short spelling) | Yes |
| `failed` | Execution failed | Yes |
| `unsuccessful` | Execution failed (Gateway spelling) | Yes |
| `invalid` | Rejected before execution | Yes |
| `not-executable-in-block` | Proposed in a block but missing from its execution result | Yes |

`not-executable-in-block` is final but is neither a success nor a failure, so
`isCompleted` is `false` for it while `isFinal` is `true`. Such a transaction
carries no logs and no smart contract results -- check
`status.isNotExecutableInBlock` explicitly if you need to distinguish it.

## Handling Results

```dart
final watcher = TransactionWatcher(networkProvider: provider);
final tx = await watcher.awaitCompleted(txHash);

// Use convenience getters for status checks
if (tx.isSuccessful) {
  print('Transaction successful!');
  // Process results...
} else if (tx.status.isInvalid) {
  // Check this before hasFailed: `invalid` is also reported as a failure.
  print('Transaction rejected before execution');
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
} else if (tx.status.isNotExecutableInBlock) {
  print('Transaction was not executed in its proposed block');
} else {
  print('Status: ${tx.status.status}');
}
```

:::note Ordering matters
`isInvalid` implies `hasFailed`, so an `invalid` transaction takes the
`hasFailed` branch unless you test `isInvalid` first.
:::

## Parsing Transaction Results

### Smart Contract Results

```dart
final watcher = TransactionWatcher(networkProvider: provider);
final tx = await watcher.awaitCompleted(txHash);

if (tx.isSuccessful) {
  // Get smart contract results (typed SmartContractResult objects)
  final scResults = tx.smartContractResults;

  if (scResults != null) {
    for (final result in scResults) {
      print('SC Result:');
      print('  Data: ${utf8.decode(result.data)}');
      print('  Sender: ${result.sender.bech32}');
      print('  Receiver: ${result.receiver.bech32}');
      print('  Return code: ${result.returnCode}');
      print('  Return data parts: ${result.returnData.length}');
    }
  }
}
```

Each entry is a `SmartContractResult`, not a raw map: `data` is a `Uint8List`,
`sender`/`receiver` are `Address` values, and the `@`-delimited payload is
already split into `returnCode` and `returnData`. The untouched JSON is still
available as `result.raw` if you need a field the type does not surface.

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

Future<void> reportAll(TransactionWatcher watcher) async {
  final results = await waitForAll(watcher, [hash1, hash2, hash3]);

  for (final result in results) {
    print('${result.txHash}: ${result.status.status}');
  }
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
      print('  - ${utf8.decode(scr.data)}');
    }
  }
  

}
```

## Error Handling

```dart
Future<TransactionOnNetwork?> awaitOrReport(
  TransactionWatcher watcher,
  String txHash,
) async {
  try {
    final tx = await watcher.awaitCompleted(
      txHash,
      options: const TransactionAwaitingOptions(
        timeout: Duration(minutes: 2),
      ),
    );

    if (tx.hasFailed) {
      throw TransactionException('Transaction failed: ${tx.status.status}');
    }

    return tx;
  } on TransactionWatcherTimeoutException {
    print('Transaction is taking too long');
    // Could still be pending - check later
    return null;
  } on TransactionWatcherException catch (e) {
    print('Watcher error: $e');
    return null;
  }
}
```

`TransactionWatcherTimeoutException` and `TransactionWatcherException` are
siblings -- both extend `TransactionException` directly, neither one catches
the other. Catch `TransactionException` if you want to handle both plus any
other transaction-layer failure in one place.

## Next Steps

- [Transactions Overview](/docs/transactions/overview) - Transaction basics
- [Smart Contracts](/docs/smart-contracts/overview) - Contract interactions
- [Network Providers](/docs/network/providers) - Provider configuration
