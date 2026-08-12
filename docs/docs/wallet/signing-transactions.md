---
id: signing-transactions
title: Signing Transactions
sidebar_position: 5
description: Sign MultiversX transactions and off-chain messages with Account, UserSigner, TransactionComputer, and MessageComputer.
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

`serializeForSigning()` picks the right payload for you: it returns the
Keccak-256 hash of the signing JSON when the transaction has the hash-signing
option bit set, and the raw signing JSON otherwise. The two underlying
routines are also available directly:

```dart
const computer = TransactionComputer();

final json = computer.computeBytesForSigning(transaction);   // raw JSON bytes
final hash = computer.computeHashForSigning(transaction);    // Keccak-256 of it
final usesHashSigning = computer.hasOptionsSetForHashSigning(transaction);
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

Off-chain messages -- dApp logins, proofs of ownership, anything that is not a
transaction -- are represented by `Message` and signed through
`MessageComputer`.

### The message envelope

A raw message payload is never signed directly. The chain, xPortal, the Web
Wallet and the Ledger app all sign the Keccak-256 digest of a fixed envelope:

```
keccak256( "\x17Elrond Signed Message:\n" + decimalLength(data) + data )
```

The leading `0x17` byte is the length (23) of the ASCII text that follows, and
`decimalLength(data)` is the byte length of the payload rendered as ASCII
decimal digits. The spelling is part of the hashed bytes and is fixed by the
protocol -- a signature produced over any other envelope will not verify.

`MessageComputer.computeBytesForSigning` builds those 32 bytes for you; the
constant itself is exported as `canonicalMessagePrefix` if you need it.

```dart
import 'dart:convert';
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  final Account account = await Account.fromMnemonic('your mnemonic...');

  final Message message = Message(utf8.encode('Hello, MultiversX!'));

  // Account.signMessage applies the canonical envelope for you.
  final Uint8List signature = await account.signMessage(message);

  // ...and verifies against the same envelope.
  final bool isValid = await account.verifyMessageSignature(
    message,
    signature,
  );

  print('Signature: ${Signature.fromUint8List(signature).hex}');
  print('Valid: $isValid');
}
```

### Signing with a `UserSigner`

`UserSigner.sign` takes raw bytes, so compute the envelope explicitly:

```dart
void main() async {
  final Account account = await Account.fromMnemonic('your mnemonic...');
  final UserSigner signer = UserSigner(account.secretKey);

  const MessageComputer computer = MessageComputer();
  final Message message = Message(utf8.encode('Login to MyDApp'));

  final Uint8List toSign = computer.computeBytesForSigning(message);
  final Uint8List signature = await signer.sign(toSign);

  // Verification uses the identical bytes.
  final UserVerifier verifier = UserVerifier.fromAddress(account.address);
  final bool ok = await verifier.verify(
    computer.computeBytesForVerifying(message),
    signature,
  );
  print('Valid: $ok');
}
```

### Binary payloads

`Message` carries bytes, not text, so any binary payload works unchanged:

```dart
final Message binaryMessage = Message(<int>[0x01, 0x02, 0x03, 0x04]);
final Uint8List binarySignature = await account.signMessage(binaryMessage);
```

### Handing a message to another party

`packMessage` produces the JSON-friendly map wallets exchange when a message
travels between a dApp and a signer; `unpackMessage` reverses it. The payload
and signature are hex-encoded and the address is rendered as bech32.

```dart
const MessageComputer computer = MessageComputer();

final Message signed = Message(
  utf8.encode('Login to MyDApp'),
  address: account.address,
  signature: signature,
);

final Map<String, dynamic> packed = computer.packMessage(signed);
// {'message': '4c6f67696e...', 'version': 1, 'signature': '...',
//  'address': 'erd1...'}

// On the receiving side:
final Message received = computer.unpackMessage(packed);
```

`unpackMessage` decodes the `message` field strictly as hex. Pass
`acceptBase64: true` only if you must accept producers that emit base64.

### Replay protection is yours to add

The envelope binds nothing but the payload -- no timestamp, no chain ID, no
recipient. If a signature must not be replayable, put those fields **inside**
the payload you sign and check them on the verifying side:

```dart
final Map<String, Object> claims = <String, Object>{
  'statement': 'Login to MyDApp',
  'chainId': 'D',
  'recipient': 'https://mydapp.example',
  'issuedAt': DateTime.now().toUtc().toIso8601String(),
  'nonce': 'unique-session-id-123',
};

final Message message = Message(utf8.encode(jsonEncode(claims)));
final Uint8List signature = await account.signMessage(message);
```

Because the claims are part of the hashed bytes, a backend that re-serializes
the same map and verifies the signature knows the signer agreed to exactly
those values.

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
