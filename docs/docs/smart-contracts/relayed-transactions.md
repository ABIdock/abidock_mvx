---
id: relayed-transactions
title: Relayed Transactions
sidebar_position: 5
description: Let a relayer pay the fee for a user's MultiversX transaction using the flat relayed-v3 format.
---

# Relayed Transactions

A relayed transaction is an ordinary transaction whose fee is paid by somebody else. The user still
authors and signs their own transaction; a second account -- the relayer -- co-signs it and is
charged for the gas.

## The wire format

Relayed v3 is a **single, flat transaction**. There is no outer wrapper and no bundle of inner
transactions: the user's transaction simply carries two extra fields.

| Field | Meaning |
|-------|---------|
| `relayer` | bech32 address of the account that pays the fee |
| `relayerSignature` | that account's signature over the transaction |

Both fields sit next to `sender` / `signature` in the same transaction object:

```json
{
  "nonce": 7,
  "sender": "erd1user...",
  "receiver": "erd1qqq...contract...",
  "data": "Y2xhaW0=",
  "gasLimit": 10050000,
  "chainID": "D",
  "version": 2,
  "relayer": "erd1relayer...",
  "signature": "<user signature>",
  "relayerSignature": "<relayer signature>"
}
```

Consequences worth internalising:

- **The relayer must be set before anybody signs.** `relayer` is part of the signed payload, so
  attaching it afterwards invalidates every signature already on the transaction.
- **Both parties sign exactly the same bytes.** The signing payload excludes `signature`,
  `relayerSignature` and `guardianSignature`, so the two signatures are independent and the order in
  which they are produced does not matter.
- **`version` must be at least 2.** The SDK raises it for you when a relayer is attached.

## Use cases

- **Onboarding** - a new user transacts before ever holding EGLD
- **dApps** - sponsor your users' interactions
- **Gaming** - in-game actions without a fee prompt
- **Airdrops** - recipients claim without paying

## The flow

Three steps, always in this order:

1. Build the user's transaction **unsigned**.
2. `RelayedTransactionsFactory.applyRelayer(tx, relayerAddress)` -- attaches the relayer, raises the
   version and adds the relayed gas.
3. Sign twice: `signWith(senderSigner)` and `signAsRelayer(relayerSigner)`, in either order.

```dart
final relayerSigner = UserSigner.fromPem(relayerPem);
final relayerAddress = await relayerSigner.getAddress();
final userSigner = UserSigner.fromPem(userPem);

// 1. Unsigned smart-contract call.
final callFactory = SmartContractCallFactory(
  contractAddress: contractAddress,
  abi: abi,
  chainId: provider.chainId,
);
final unsigned = callFactory.createCall(
  sender: user.address,
  nonce: userAccount.nonce,
  endpointName: 'claim',
  arguments: <dynamic>[],
  gasLimit: const GasLimit(10000000),
);

// 2. Attach the relayer (adds 50,000 gas, version becomes 2).
final relayedFactory = RelayedTransactionsFactory(
  const RelayedTransactionsConfig(chainId: ChainId.devnet()),
);
final relayed = relayedFactory.applyRelayer(unsigned, relayerAddress);
print(relayed.gasLimit.value); // 10050000

// 3. Both parties sign the same bytes.
final signed = await relayed.signWith(userSigner);
final broadcastable = await signed.signAsRelayer(relayerSigner);

print(broadcastable.isFullySigned);  // true
print(broadcastable.missingSignatures); // []

final txHash = await provider.sendTransaction(broadcastable);
```

`applyRelayer` sets `relayer`, raises `version` to at least 2 (relayed transactions are rejected
below that), and adds `extraGasLimitForRelayedTransactions` (50,000) to the gas limit. Re-applying
the same relayer is a no-op, so the base cost is never charged twice.

### Split across two services

The transaction is a plain object, so the user's device and the relayer service can be different
processes. Serialise with `tx.toJson()` and rebuild with `Transaction.newFromPlainObject(...)`.

```dart
// === User side: relayer address known up-front, e.g. published by the service
final relayed = relayedFactory.applyRelayer(unsigned, relayerAddress);
final userSignedTx = await relayed.signWith(userSigner);
final Map<String, dynamic> payload = userSignedTx.toJson();

// === Relayer service ===
final received = Transaction.newFromPlainObject(payload);
final fullySignedTx = await received.signAsRelayer(relayerSigner);
final txHash = await provider.sendTransaction(fullySignedTx);
```

### What `applyRelayer` rejects

Everything is checked locally, before anything reaches the network:

| Condition | Error |
|-----------|-------|
| The transaction already carries any signature | `ArgumentError` |
| The transaction's chain id differs from the factory's | `ArgumentError` |
| The relayer equals the guardian | `ArgumentError` |
| Relayer and sender live in different shards | `ArgumentError` |
| A *different* relayer is already set | `StateError` |

:::caution `BaseControllerInput.relayer` and `controller.call`
`BaseControllerInput` carries a `relayer` field, and the controller does write it onto the
transaction before signing -- but `SmartContractCallFactory.createCall` emits `version: 1` for an
unguarded call, and a relayed transaction requires version 2 or higher. Signing therefore fails with
*"Relayed v3 transactions require transaction version >= 2"*.

Build the call with the factory and go through `applyRelayer`, as shown above, which sets the
version for you. A call that also has a **guardian** is unaffected: the guardian already forces
version 2.
:::

## Signing extensions

`Transaction` gets these methods from the SDK:

```dart
// Sign as the sender.
final signedTx = await tx.signWith(userSigner);

// Sign as relayer (`relayer` must already be set).
final relayedTx = await signedTx.signAsRelayer(relayerSigner);

// Sign as guardian (`guardian` must already be set).
final guardedTx = await signedTx.signAsGuardian(guardianSigner);

// Inspect what is still missing.
print(tx.isRelayedTransaction); // true when `relayer` is set
print(tx.isGuardedTransaction); // true when `guardian` is set
print(tx.isFullySigned);        // all required signatures present
print(tx.missingSignatures);    // e.g. ['relayer']
```

`signAsRelayer` re-checks the shard rule and throws `TransactionException` if the relayer field is
empty or the two addresses are in different shards.

## Complete example

```dart
import 'dart:io';
import 'package:abidock_mvx/abidock_mvx.dart';

Future<void> main() async {
  final provider = GatewayNetworkProvider.devnet();

  // === User ===
  final userPem = File('user.pem').readAsStringSync();
  final user = await Account.fromPem(userPem);
  final userAccount = await provider.getAccount(user.address);
  print('User: ${user.address.bech32}');
  print('User balance: ${userAccount.balance} (may be zero)');

  // === Relayer ===
  final relayerPem = File('relayer.pem').readAsStringSync();
  final relayerSigner = UserSigner.fromPem(relayerPem);
  final relayerAddress = await relayerSigner.getAddress();
  print('Relayer: ${relayerAddress.bech32}');

  // === Contract ===
  final abiJson = File('contract.abi.json').readAsStringSync();
  final abi = SmartContractAbi.fromJson(abiJson);
  final contractAddress = SmartContractAddress.fromBech32('erd1qqq...');

  // === Unsigned call ===
  final callFactory = SmartContractCallFactory(
    contractAddress: contractAddress,
    abi: abi,
    chainId: provider.chainId,
  );
  final unsigned = callFactory.createCall(
    sender: user.address,
    nonce: userAccount.nonce,
    endpointName: 'claim',
    arguments: <dynamic>[],
    gasLimit: const GasLimit(10000000),
  );

  // === Attach the relayer, then sign twice ===
  final relayedFactory = RelayedTransactionsFactory(
    const RelayedTransactionsConfig(chainId: ChainId.devnet()),
  );
  final relayed = relayedFactory.applyRelayer(unsigned, relayerAddress);
  print('Gas with relayed base cost: ${relayed.gasLimit.value}'); // 10050000

  final userSigner = UserSigner.fromPem(userPem);
  final userSignedTx = await relayed.signWith(userSigner);
  print('Missing signatures: ${userSignedTx.missingSignatures}'); // ['relayer']

  final fullySignedTx = await userSignedTx.signAsRelayer(relayerSigner);
  print('Fully signed: ${fullySignedTx.isFullySigned}'); // true

  final txHash = await provider.sendTransaction(fullySignedTx);

  final watcher = TransactionWatcher(networkProvider: provider);
  final result = await watcher.awaitCompleted(txHash);
  print('Status: ${result.status.status}');
  print('Fee paid by: ${result.relayer ?? 'sender'}'); // bech32 string
  print('Relayed version: ${result.relayedVersion}'); // 'v3'
}
```

## Guardian transactions (2FA)

A guarded transaction follows the same shape with `guardian` / `guardianSignature`, and the guarded
option bit is set on `options` by the controller.

```dart
final tx = await controller.call(
  account: user,
  nonce: userAccount.nonce,
  endpointName: 'transfer',
  arguments: <dynamic>[
    'erd1...recipient...', // Address as bech32 string
    BigInt.from(1000),     // amount
  ],
  options: BaseControllerInput(
    gasLimit: const GasLimit(10050000),
    guardian: guardianAddress,
  ),
);

final guardedTx = await tx.signAsGuardian(guardianSigner);
final txHash = await provider.sendTransaction(guardedTx);
```

## Relayer and guardian together

Both roles can co-sign the same flat transaction -- but they must be **different accounts**;
`applyRelayer` rejects a relayer that equals the guardian, and the chain rejects such a transaction
with `ErrRelayedByGuardianNotAllowed`.

This combination works straight through the controller: a guardian already forces `version` to 2 and
sets the guarded option bit, which is exactly what the relayer field also needs.

```dart
final tx = await controller.call(
  account: user,
  nonce: userAccount.nonce,
  endpointName: 'highValueTransfer',
  arguments: <dynamic>[
    'erd1...recipient...',
    BigInt.from(1000000),
  ],
  options: BaseControllerInput(
    gasLimit: const GasLimit(15100000),
    relayer: relayerAddress,
    guardian: guardianAddress,
  ),
);

// Order is irrelevant: both signatures cover the same bytes.
final withRelayer = await tx.signAsRelayer(relayerSigner);
final fullySignedTx = await withRelayer.signAsGuardian(guardianSigner);

print(fullySignedTx.isFullySigned); // true
final txHash = await provider.sendTransaction(fullySignedTx);
```

## Same-shard requirement

:::caution Sender and relayer share a shard
The protocol executes a relayed transaction in a single shard, so the relayer must live in the same
shard as the sender. Both `applyRelayer` and `signAsRelayer` check this locally and throw before the
transaction ever reaches the network.

```dart
// Throws TransactionException when the two addresses are in different shards.
final relayedTx = await tx.signAsRelayer(relayerSigner);
```
:::

## Running a relayer service

A relayer signs somebody else's transaction, so validate it before adding the signature. The
transaction is flat -- everything you need is on the object itself.

```dart
import 'dart:convert';

bool validateRelayedTransaction(Transaction tx) {
  const List<String> allowedFunctions = <String>['claim', 'stake', 'unstake'];

  // `data` is raw bytes: "function@arg1@arg2".
  final String data = utf8.decode(tx.data);
  final String function = data.split('@').first;
  if (!allowedFunctions.contains(function)) {
    return false;
  }

  // Cap what you are willing to pay for.
  if (tx.gasLimit > const GasLimit(50000000)) {
    return false;
  }

  // The user must have signed first, and the relayer field must be yours.
  if (tx.signature.isEmpty || tx.relayer == null) {
    return false;
  }

  return true;
}
```

## Error handling

```dart
try {
  final fullySignedTx = await tx.signAsRelayer(relayerSigner);
  final txHash = await provider.sendTransaction(fullySignedTx);
  print('Sent: $txHash');
} on TransactionException catch (e) {
  // Relayer field missing, or sender and relayer in different shards.
  print('Cannot relay: ${e.message}');
} on NetworkException catch (e) {
  print('Network error: ${e.message}');
} on SignerException catch (e) {
  print('Signing error: ${e.message}');
}
```

`applyRelayer` reports its own problems as `ArgumentError` / `StateError` -- those are programming
errors (signing too early, wrong chain id, relayer equal to guardian), not runtime conditions to
catch.

## Next Steps

- [Transactions](/docs/transactions/overview) - Standard transfers
- [Smart Contracts](/docs/smart-contracts/overview) - Contract interactions
- [Code Generation](/docs/codegen/overview) - Type-safe generated code
