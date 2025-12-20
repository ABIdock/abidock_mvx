---
id: relayed-transactions
title: Relayed Transactions
sidebar_position: 5
description: Implement gas-free user experiences on MultiversX using relayed transactions where a third party pays the fees.
---

# Relayed Transactions

Relayed transactions allow a third party (relayer) to pay the gas fees for a user's transaction. This enables gas-free user experiences.

## How It Works

```
┌──────────┐         ┌──────────┐         ┌──────────┐
│   User   │  signs  │  Relayer │  pays   │ Blockchain│
│          │ ──────► │          │ ──────► │          │
│ (no gas) │  inner  │ (has gas)│   gas   │          │
└──────────┘   tx    └──────────┘         └──────────┘
```

1. **User** creates and signs the transaction with relayer field set
2. **Relayer** adds their signature using `signAsRelayer()` extension
3. **Blockchain** executes the transaction, charging gas to relayer

## Use Cases

- **Onboarding** - New users don't need EGLD to start
- **DApps** - Sponsor user interactions
- **Gaming** - In-game transactions without gas popups
- **Airdrops** - Recipients claim without gas

## Creating Relayed Transactions (V3)

:::info Relayed V3
abidock_mvx supports **Relayed Transactions V3**, the current and recommended version on MultiversX.
The relayer field is set in `BaseControllerInput` and the `signAsRelayer()` extension handles the signature.
:::

### Simple Approach (Recommended)

When the user account is available to the relayer service:

```dart
// Both user and relayer signers available
final user = await Account.fromMnemonic('user mnemonic...');
final relayerSigner = UserSigner.fromPem(relayerPem);
final relayerAddress = await relayerSigner.getAddress();

final userAccount = await provider.getAccount(user.address);

// Create transaction with relayer - auto-signs as user
final tx = await controller.call(
  account: user,                    // IAccount signs the transaction
  nonce: userAccount.nonce,
  endpointName: 'claim',
  arguments: [],
  options: BaseControllerInput(
    gasLimit: GasLimit(10000000),
    relayer: relayerAddress,
  ),
);

// Add relayer signature and send
final fullySignedTx = await tx.signAsRelayer(relayerSigner);
final txHash = await provider.sendTransaction(fullySignedTx);
```

### Separate User/Relayer Flow

When user signs on their device and sends to relayer service:

```dart
// === User side (frontend/mobile app) ===
final user = await Account.fromMnemonic('user mnemonic...');
final userAccount = await provider.getAccount(user.address);

// Create transaction with relayer field using controller.call()
// The transaction will be signed by the user automatically
final userSignedTx = await controller.call(
  account: user,
  nonce: userAccount.nonce,
  endpointName: 'claim',
  arguments: [],
  options: BaseControllerInput(
    gasLimit: GasLimit(10000000),
    relayer: relayerAddress,
  ),
);

// Send to relayer service (serialize/deserialize as needed)

// === Relayer side (backend service) ===
final relayerSigner = UserSigner.fromPem(relayerPem);

// Add relayer signature and send
final fullySignedTx = await userSignedTx.signAsRelayer(relayerSigner);
final txHash = await provider.sendTransaction(fullySignedTx);
```

## Transaction Signing Extensions

The SDK provides convenient extension methods on `Transaction`:

```dart
// Sign as the main user
final signedTx = await tx.signWith(userSigner);

// Sign as relayer (transaction must have relayer field set)
final relayedTx = await signedTx.signAsRelayer(relayerSigner);

// Sign as guardian (transaction must have guardian field set)
final guardedTx = await signedTx.signAsGuardian(guardianSigner);

// Check signature status
print(tx.isRelayedTransaction);  // true if relayer is set
print(tx.isGuardedTransaction);  // true if guardian is set
print(tx.isFullySigned);         // true if all required signatures present
print(tx.missingSignatures);     // ['relayer'] if relayer sig missing
```

## Complete Example

```dart
import 'dart:io';
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  
  // === User Setup ===
  final userPem = File('user.pem').readAsStringSync();
  final user = await Account.fromPem(userPem);
  final userAccount = await provider.getAccount(user.address);
  
  print('User: ${user.address.bech32}');
  print('User balance: ${userAccount.balance} (can be 0)');
  
  // === Relayer Setup ===
  final relayerPem = File('relayer.pem').readAsStringSync();
  final relayerSigner = UserSigner.fromPem(relayerPem);
  final relayerAddress = await relayerSigner.getAddress();
  
  print('Relayer: ${relayerAddress.bech32}');
  
  // === Load Contract ===
  final abiJson = File('contract.abi.json').readAsStringSync();
  final abi = SmartContractAbi.fromJson(abiJson);
  final contractAddress = SmartContractAddress.fromBech32('erd1qqq...');
  final controller = SmartContractController(
    contractAddress: contractAddress,
    abi: abi,
    networkProvider: provider,
  );
  
  // === Create Transaction with Relayer ===
  // User's transaction is auto-signed, relayer field is set
  final tx = await controller.call(
    account: user,
    nonce: userAccount.nonce,
    endpointName: 'claim',
    arguments: [],
    options: BaseControllerInput(
      gasLimit: GasLimit(10000000),
      relayer: relayerAddress,
    ),
  );
  
  print('Missing signatures: ${tx.missingSignatures}');  // ['relayer']
  
  // === Relayer Signs and Sends ===
  final fullySignedTx = await tx.signAsRelayer(relayerSigner);
  print('Fully signed: ${fullySignedTx.isFullySigned}');  // true
  
  final txHash = await provider.sendTransaction(fullySignedTx);
  
  // === Wait for Completion ===
  final watcher = TransactionWatcher(networkProvider: provider);
  final result = await watcher.awaitCompleted(txHash);
  

  print('Status: ${result.status.status}');
  print('User paid: 0 EGLD');
  print('Relayer paid gas');
}
```

## Guardian Transactions (2FA)

Similar pattern for guardian-protected accounts:

```dart
// Create transaction with guardian
final tx = await controller.call(
  account: user,
  nonce: userAccount.nonce,
  endpointName: 'transfer',
  arguments: [
    'erd1...recipient...',  // Address as bech32 string
    BigInt.from(1000),      // amount
  ],
  options: BaseControllerInput(
    gasLimit: GasLimit(10000000),
    guardian: guardianAddress,
  ),
);

// Guardian adds their signature
final guardedTx = await tx.signAsGuardian(guardianSigner);
final txHash = await provider.sendTransaction(guardedTx);
```

## Combined: Relayer + Guardian

```dart
// Both relayer and guardian
final tx = await controller.call(
  account: user,
  nonce: userAccount.nonce,
  endpointName: 'highValueTransfer',
  arguments: [
    'erd1...recipient...',  // Address as bech32 string
    BigInt.from(1000000),   // amount
  ],
  options: BaseControllerInput(
    gasLimit: GasLimit(15000000),
    relayer: relayerAddress,
    guardian: guardianAddress,
  ),
);

// Add both signatures
final withRelayer = await tx.signAsRelayer(relayerSigner);
final fullySignedTx = await withRelayer.signAsGuardian(guardianSigner);

print(fullySignedTx.isFullySigned);  // true
final txHash = await provider.sendTransaction(fullySignedTx);
```

## Shard Requirement

:::caution Same Shard Requirement
For Relayed V3, the **sender and relayer must be in the same shard**. The SDK validates this automatically:

```dart
// This will throw if sender and relayer are in different shards
final relayedTx = await tx.signAsRelayer(relayerSigner);
// Exception: sender and relayer must be in the same shard for Relayed V3 transactions
```
:::

## Security Considerations

:::caution Inner Transaction Validation
When running a relayer service, always validate transactions before signing:
- Check sender address is expected/whitelisted
- Verify function and arguments are allowed
- Confirm gas limit is reasonable
:::

```dart
// Validate before adding relayer signature
bool validateTransaction(Transaction tx) {
  // Check allowed functions
  final allowedFunctions = ['claim', 'stake', 'unstake'];
  final data = tx.data;
  final function = data.split('@').first;
  
  if (!allowedFunctions.contains(function)) {
    return false;
  }
  
  // Check gas limit
  if (tx.gasLimit > GasLimit(50000000)) {
    return false;
  }
  
  // Verify user signature is present
  if (tx.signature.isEmpty) {
    return false;
  }
  
  return true;
}
```

## Error Handling

```dart
try {
  // Sign as relayer - validates shard match
  final fullySignedTx = await tx.signAsRelayer(relayerSigner);
  final txHash = await provider.sendTransaction(fullySignedTx);
  // ...
} on TransactionCreationException catch (e) {
  // Relayer validation errors
  print('Transaction creation error: ${e.message}');
  if (e.message.contains('same shard')) {
    print('Sender and relayer must be in the same shard');
  } else if (e.message.contains('relayer address is not set')) {
    print('Relayer field not set in transaction');
  }
} on NetworkException catch (e) {
  print('Network error: ${e.message}');
} on SignerException catch (e) {
  print('Signing error: ${e.message}');
}
```

## Next Steps

- [Transactions](/docs/transactions/overview) - Standard transfers
- [Smart Contracts](/docs/smart-contracts/overview) - Contract interactions
- [Code Generation](/docs/codegen/overview) - Type-safe generated code