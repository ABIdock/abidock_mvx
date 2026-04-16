---
id: deploy-upgrade
title: Deploy, Upgrade, Change Owner
sidebar_position: 6
description: Smart-contract lifecycle transactions -- deploy new contracts, upgrade existing ones, change ownership, and claim developer rewards -- via SmartContractTransactionsFactory.
---

# Smart-contract lifecycle

`SmartContractCallFactory` / `SmartContractController` cover calling an already-deployed contract. For the contract's lifecycle itself -- deploy, upgrade, change owner, claim developer rewards -- use `SmartContractTransactionsFactory`.

These four operations are ABI-free: they don't touch the endpoint list. They're plain data-field patterns the chain recognises on its own.

## Setup

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

final factory = SmartContractTransactionsFactory(
  SmartContractTransactionsConfig(chainId: const ChainId.devnet()),
);
```

`SmartContractTransactionsConfig` carries the usual gas floors (`minGasLimit`, `gasLimitPerByte`, `defaultGasPrice`) plus per-operation caps for `claimDeveloperRewards` and `changeOwnerAddress`. Defaults match mainnet; override per-field when the chain tunes them.

## Deploy

```dart
final Uint8List bytecode = await File('my-contract.wasm').readAsBytes();

final Transaction deployTx = factory.createTransactionForDeploy(
  sender: deployer.address,
  bytecode: bytecode,
  gasLimit: const GasLimit(60_000_000),
  arguments: <Uint8List>[
    Uint8List.fromList('hello'.codeUnits), // constructor arg
  ],
  // codeMetadata defaults to [0x05, 0x06] -- upgradeable + readable + payable + payableBySC.
  // Pass a `CodeMetadataValue.toBytes()` result here to customise.
);
```

The receiver is set to `Address.zero()` (the convention for deploys). `vmType` defaults to `'0500'` (WASM). Data-field shape:

```
<codeHex>@<vmTypeHex>@<codeMetadataHex>[@<argHex>...]
```

After signing and broadcasting, compute the contract address locally with `AddressComputer.computeContractAddress(deployer, nonce)` -- the same nonce used on the tx.

## Upgrade

```dart
final Transaction upgradeTx = factory.createTransactionForUpgrade(
  sender: owner.address,
  contract: existingContractAddress,
  bytecode: newBytecode,
  gasLimit: const GasLimit(60_000_000),
  arguments: <Uint8List>[/* args to the new init function, if any */],
);
```

Receiver is the contract itself. Data-field shape: `upgradeContract@<codeHex>@<metadataHex>[@<argHex>...]`. Only the current owner can upgrade; the chain rejects any other sender.

## Change owner

```dart
final Transaction tx = factory.createTransactionForChangeOwnerAddress(
  sender: currentOwner.address,
  contract: contractAddress,
  newOwner: newOwner.address,
);
```

Data-field: `ChangeOwnerAddress@<newOwnerHex>`. Gas floor is computed automatically from `gasLimitChangeOwnerAddress` (6M default) plus the move-balance portion; no explicit `gasLimit` parameter.

## Claim developer rewards

```dart
final Transaction tx = factory.createTransactionForClaimDeveloperRewards(
  sender: owner.address,
  contract: contractAddress,
);
```

Data-field: `ClaimDeveloperRewards` (no args). Must be sent by the current contract owner.

## Signing and broadcast

Each of the four transactions is a plain `Transaction` -- sign with `UserSigner.sign(tx.serializeForSigning())` (or via `Account.signTransaction(tx)` if you have an `Account` wrapper), then broadcast through the network provider.

```dart
final sigBytes = await account.signTransaction(deployTx);
final signedTx = deployTx.copyWith(newSignature: Signature.fromBytes(sigBytes));
final hash = await provider.sendTransaction(signedTx);
print('deploy tx: $hash');

final contractAddress = AddressComputer.computeContractAddress(
  account.address,
  deployTx.nonce,
);
print('deployed to: ${contractAddress.bech32}');
```

## Decoding lifecycle transactions

`TransactionDecoder` understands all four patterns as of 1.0.2. Pattern-match on the sealed subclasses:

```dart
switch (const TransactionDecoder().decode(tx)) {
  case ContractDeploy(:final bytecode, :final arguments):
    ...
  case ContractUpgrade(:final bytecode, :final codeMetadata):
    ...
  case ContractChangeOwner(:final newOwner):
    ...
  case ClaimDeveloperRewards():
    ...
  default:
    // not a lifecycle tx
}
```

See [Decoding Transactions](../transactions/decoding-transactions.md) for the full variant list.
