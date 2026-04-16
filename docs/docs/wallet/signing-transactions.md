---
id: signing-transactions
title: Signing Transactions
sidebar_position: 5
description: Sign MultiversX transactions and messages cryptographically using Account, SecretKey, or Signer classes.
---

# Signing Transactions

All MultiversX transactions must be cryptographically signed before they can be submitted to the network.

## Using Account for Signing

The `Account` class is the simplest way to sign transactions:

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  // Create account from mnemonic
  final account = await Account.fromMnemonic('your mnemonic...');
  
  // Sign a transaction
  final signature = await account.signTransaction(transaction);
  
  // Apply signature to transaction
  final signedTx = transaction.copyWith(
    newSignature: Signature.fromUint8List(signature),
  );
}
```

## Complete Signing Flow

```dart
void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('your mnemonic...');
  
  // 1. Get network config
  final networkConfig = await provider.getNetworkConfig();
  
  // 2. Get account info for nonce
  final accountInfo = await provider.getAccount(account.address);
  
  // 3. Create transaction with typed parameters
  final transaction = Transaction(
    sender: account.address,
    receiver: Address.fromBech32('erd1...recipient...'),
    value: Balance.fromEgld(1.0),
    nonce: accountInfo.nonce,
    gasLimit: GasLimit(50000),
    gasPrice: GasPrice(1000000000),
    chainId: ChainId(networkConfig.chainId),
    version: TransactionVersion(1),
    data: Uint8List(0),
  );
  
  // 4. Sign the transaction
  final signature = await account.signTransaction(transaction);
  final signedTx = transaction.copyWith(
    newSignature: Signature.fromUint8List(signature),
  );
  
  // 5. Send to network
  final txHash = await provider.sendTransaction(signedTx);
  print('Transaction hash: $txHash');
}
```

## Using UserSigner Directly

For more control, use `UserSigner`:

```dart
void main() async {
  final account = await Account.fromMnemonic('your mnemonic...');
  
  // Create signer from account's secret key
  final signer = UserSigner(account.secretKey);
  
  // Serialize transaction for signing
  final txBytes = transaction.serializeForSigning();
  
  // Sign the bytes
  final signature = await signer.sign(txBytes);
  
  // Apply signature
  final signedTx = transaction.copyWith(
    newSignature: Signature.fromUint8List(signature),
  );
}
```

## What Gets Signed?

The transaction is serialized to canonical JSON bytes for signing:

```dart
final txBytes = transaction.serializeForSigning();
final signature = await secretKey.sign(txBytes);
```

### Hash-signing for large transactions

When the transaction has the `TRANSACTION_OPTIONS_TX_HASH_SIGN` option bit set,
the chain expects the Ed25519 signature over the **Keccak-256 hash of the
signing JSON**, not the raw JSON bytes. This is the path a Ledger or any
hash-signer uses for transactions with large data payloads.

`Account.signTransaction(tx)` and `Account.verifyTransactionSignature(tx, sig)`
take care of this automatically -- they route through
`TransactionComputer.computeHashForSigning(tx)` when the options bit is set and
through `computeBytesForSigning(tx)` otherwise. You only need to call
`TransactionComputer.applyOptionsForHashSigning(tx)` to flip the option on:

```dart
const computer = TransactionComputer();
final hashSignedTx = computer.applyOptionsForHashSigning(tx);
final signature = await account.signTransaction(hashSignedTx); // signs the hash
```

## Signing Messages

You can sign arbitrary messages using `UserSigner`:

```dart
import 'dart:convert';

void main() async {
  final account = await Account.fromMnemonic('your mnemonic...');
  final signer = UserSigner(account.secretKey);
  
  // Sign a message
  final message = utf8.encode('Hello, MultiversX!');
  final signature = await signer.sign(Uint8List.fromList(message));
  
  print('Message: Hello, MultiversX!');
  print('Signature: ${convert.hex.encode(signature)}');
}
```

## Signable Messages (with Replay Protection)

For dApp authentication, use `SignableMessage` which provides protection against:
- **Replay attacks** - timestamps and nonces prevent reusing signatures
- **Cross-chain attacks** - chain ID binding prevents use on other networks
- **Relay attacks** - recipient binding prevents use with different backends

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  final account = await Account.fromMnemonic('your mnemonic...');
  
  // Create signable message with automatic timestamp and nonce
  final message = SignableMessage.fromMessage(
    'Login to MyDApp',
    chainId: 'D',                    // Prevent cross-chain replay
    recipient: 'erd1webapp...',      // Prevent relay to other backends
  );

  // Sign with account
  final signature = await account.signMessage(message);

  // Send to backend for verification
  final authData = {
    'message': message.bytes,
    'timestamp': message.timestamp,
    'nonce': message.nonce,
    'chainId': message.chainId,
    'recipient': message.recipient,
    'signature': signature,
  };
}
```

### Custom Timestamp and Nonce

```dart
final customMessage = SignableMessage.fromMessage(
  'Custom auth message',
  timestamp: DateTime.now().millisecondsSinceEpoch,
  nonce: 'unique-session-id-123',
  chainId: '1',  // Mainnet
);
```

## Creating Signers from Different Sources

```dart
import 'dart:io';

void main() async {
  // From mnemonic
  final signer1 = await UserSigner.fromMnemonic('word1 word2 word3...');

  // From PEM file
  final pemContent = await File('wallet.pem').readAsString();
  final signer2 = UserSigner.fromPem(pemContent);

  // From keystore
  final keystoreJson = await File('wallet.json').readAsString();
  final signer3 = await UserSigner.fromKeystore(keystoreJson, 'password');
  
  // From secret key
  final secretKey = UserSecretKey.generate();
  final signer4 = UserSigner(secretKey);
  
  // Get address from any signer
  final address = await signer1.getAddress();
  print('Address: ${address.bech32}');
}
```

## Batch Signing

Sign multiple transactions efficiently:

```dart
void main() async {
  final account = await Account.fromMnemonic('your mnemonic...');
  
  // Create multiple transactions with incrementing nonces
  final transactions = <Transaction>[];
  var nonce = account.nonce;
  
  for (var i = 0; i < 3; i++) {
    transactions.add(Transaction(
      sender: account.address,
      receiver: recipientAddress,
      value: Balance.fromEgld(0.1),
      nonce: nonce,
      gasLimit: GasLimit(50000),
      gasPrice: GasPrice(1000000000),
      chainId: ChainId('D'),
      version: TransactionVersion(1),
      data: Uint8List(0),
    ));
    nonce = nonce.increment();
  }
  
  // Sign all transactions
  final signedTransactions = <Transaction>[];
  for (final tx in transactions) {
    final signature = await account.signTransaction(tx);
    signedTransactions.add(tx.copyWith(
      newSignature: Signature.fromUint8List(signature),
    ));
  }
  
  // Send all
  for (final signed in signedTransactions) {
    await provider.sendTransaction(signed);
  }
}
```

## Security Considerations

:::caution Protect Your Signing Key
- Never expose `secretKey` in logs or error messages
- Sign on secure devices only
- Consider hardware wallet integration for high-value transactions
:::

```dart
// BAD - Don't log secret keys
print('Secret: ${account.secretKey}'); // NEVER DO THIS

// GOOD - Only log public information
print('Address: ${account.address.bech32}');
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:convert';
import 'dart:typed_data';

void main() async {
  print('=== Transaction Signing Demo ===\n');
  
  final provider = GatewayNetworkProvider.devnet();
  
  // Create account
  final account = await Account.fromMnemonic(
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
  );
  
  print('Sender: ${account.address.bech32}');
  
  // Get network info
  final config = await provider.getNetworkConfig();
  final accountInfo = await provider.getAccount(account.address);
  
  // Create transaction
  final tx = Transaction(
    sender: account.address,
    receiver: Address.fromBech32(
      'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu'
    ),
    value: Balance.zero(),
    nonce: accountInfo.nonce,
    gasLimit: GasLimit(50000),
    gasPrice: GasPrice(1000000000),
    chainId: ChainId(config.chainId),
    version: TransactionVersion(1),
    data: Uint8List.fromList(utf8.encode('Hello, MultiversX!')),
  );
  
  print('  Nonce: ${tx.nonce.value}');
  print('  Value: ${tx.value.value}');
  print('  Signature: ${tx.signature.isEmpty ? "none" : tx.signature.hex}');
  
  // Sign it
  final signature = await account.signTransaction(tx);
  final signed = tx.copyWith(
    newSignature: Signature.fromUint8List(signature),
  );
  
  print('  Signature: ${signed.signature.hex}');
  print('  Signature length: ${signature.length} bytes');
  

}
```

## Next Steps

- [Transactions](/docs/transactions/overview) - Send different transaction types
- [Smart Contracts](/docs/smart-contracts/overview) - Sign contract calls
- [Relayed Transactions](/docs/smart-contracts/relayed-transactions) - Advanced signing
