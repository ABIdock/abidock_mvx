---
id: egld-transfers
title: EGLD Transfers
sidebar_position: 2
description: Transfer native EGLD tokens between MultiversX addresses with optional data payloads and proper gas configuration.
---

# EGLD Transfers

Transfer native EGLD tokens between addresses.

## Simple Transfer

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:typed_data';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('your mnemonic...');
  
  // Get network info
  final config = await provider.getNetworkConfig();
  final accountInfo = await provider.getAccount(account.address);
  
  // Create transfer
  final tx = Transaction(
    sender: account.address,
    receiver: Address.fromBech32('erd1...recipient...'),
    value: Balance.fromEgld(1.0),
    nonce: accountInfo.nonce,
    gasLimit: GasLimit(50000),
    gasPrice: GasPrice(1000000000),
    chainId: ChainId(config.chainId),
    version: TransactionVersion(1),
    data: Uint8List(0),
  );
  
  // Sign and send
  final signature = await account.signTransaction(tx);
  final signed = tx.copyWith(newSignature: Signature.fromUint8List(signature));
  final hash = await provider.sendTransaction(signed);
  
  print('Sent: $hash');
}
```

## EGLD Denominations

| Denomination | Amount | In EGLD |
|--------------|--------|---------|
| 1 EGLD | 10^18 | 1 |
| 0.1 EGLD | 10^17 | 0.1 |
| 0.01 EGLD | 10^16 | 0.01 |

### Balance Class

Use the `Balance` class for EGLD amounts:

```dart
// Create from EGLD
final amount1 = Balance.fromEgld(1.5);  // 1.5 EGLD

// Create from string (atomic units)
final amount2 = Balance.fromString('1500000000000000000');  // 1.5 EGLD

// Create zero balance
final zero = Balance.zero();

// Access raw value
print(amount1.value);  // BigInt: 1500000000000000000
```

## Transfer with Message

Add a message to your transfer:

```dart
import 'dart:convert';

final message = 'Thank you for dinner!';

final tx = Transaction(
  sender: account.address,
  receiver: Address.fromBech32('erd1...'),
  value: Balance.fromEgld(0.1),
  nonce: accountInfo.nonce,
  gasLimit: GasLimit(50000 + (message.length * config.gasPerDataByte)),
  gasPrice: GasPrice(1000000000),
  chainId: ChainId(config.chainId),
  version: TransactionVersion(1),
  data: Uint8List.fromList(utf8.encode(message)),
);
```

:::tip Gas Calculation
When adding data, increase gas limit by `data.length * gasPerDataByte`
:::

## Check Balance Before Transfer

```dart
void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final accountInfo = await provider.getAccount(account.address);
  
  final amount = Balance.fromEgld(1.0);
  final gasEstimate = Balance.fromString('50000000000000'); // ~50k gas
  
  final totalNeeded = Balance.fromString(
    (amount.value + gasEstimate.value).toString()
  );
  
  if (accountInfo.balance < totalNeeded) {
    print('Insufficient balance!');
    return;
  }
  
  // Proceed with transfer...
}
```

## Batch Transfers

Send to multiple recipients:

```dart
void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('...');
  
  final config = await provider.getNetworkConfig();
  var accountInfo = await provider.getAccount(account.address);
  var nonce = accountInfo.nonce;
  
  final recipients = [
    ('erd1...alice...', Balance.fromEgld(0.1)),
    ('erd1...bob...', Balance.fromEgld(0.2)),
    ('erd1...charlie...', Balance.fromEgld(0.3)),
  ];
  
  for (final (recipientBech32, amount) in recipients) {
    final tx = Transaction(
      sender: account.address,
      receiver: Address.fromBech32(recipientBech32),
      value: amount,
      nonce: nonce,
      gasLimit: GasLimit(50000),
      gasPrice: GasPrice(1000000000),
      chainId: ChainId(config.chainId),
      version: TransactionVersion(1),
      data: Uint8List(0),
    );
    
    final signature = await account.signTransaction(tx);
    final signed = tx.copyWith(newSignature: Signature.fromUint8List(signature));
    final hash = await provider.sendTransaction(signed);
    print('Sent: $hash');
    
    // Increment nonce for next transaction
    nonce = nonce.increment();
  }
}
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:typed_data';

void main() async {
  print('=== EGLD Transfer Demo ===\n');
  
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('your 24 word mnemonic phrase...');
  
  print('Sender: ${account.address.bech32}');
  
  // Get account info
  final config = await provider.getNetworkConfig();
  final accountInfo = await provider.getAccount(account.address);
  
  print('Balance: ${accountInfo.balance.value}');
  print('Nonce: ${accountInfo.nonce.value}');
  
  // Recipient
  final recipient = Address.fromBech32(
    'erd1spyavw0956vq68xj8y4tenjpq2wd5a9p2c6j8gsz7ztyrnpxrruqzu66jx'
  );
  final amount = Balance.fromEgld(0.01);
  
  // Create transaction
  final tx = Transaction(
    sender: account.address,
    receiver: recipient,
    value: amount,
    nonce: accountInfo.nonce,
    gasLimit: GasLimit(50000),
    gasPrice: GasPrice(1000000000),
    chainId: ChainId(config.chainId),
    version: TransactionVersion(1),
    data: Uint8List(0),
  );
  
  print('  To: ${recipient.bech32.substring(0, 20)}...');
  print('  Amount: ${amount.value} (0.01 EGLD)');
  print('  Gas: 50000');
  
  // Sign
  final signature = await account.signTransaction(tx);
  final signed = tx.copyWith(newSignature: Signature.fromUint8List(signature));
  
  // Send
  final hash = await provider.sendTransaction(signed);
  print('Sent! Hash: $hash');
  
  // Wait for confirmation
  final watcher = TransactionWatcher(networkProvider: provider);
  final result = await watcher.awaitCompleted(hash);
  
  
  // Check new balance
  final newAccountInfo = await provider.getAccount(account.address);
  print('New balance: ${newAccountInfo.balance.value}');
}
```

## Next Steps

- [ESDT Transfers](/docs/transactions/esdt-transfers) - Token transfers
- [NFT Transfers](/docs/transactions/nft-transfers) - NFT transfers
- [Transaction Tracking](/docs/transactions/transaction-tracking) - Monitor status
