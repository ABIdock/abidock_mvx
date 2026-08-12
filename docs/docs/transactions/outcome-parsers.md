---
id: outcome-parsers
title: Outcome Parsers
sidebar_position: 10
description: Parse MultiversX transaction outcomes to extract structured results from smart contract calls and token operations.
---

# Outcome Parsers

Parse transaction outcomes to extract structured results from completed transactions.

## Overview

After a transaction is processed, outcome parsers extract meaningful data from transaction logs and events:

| Parser | Use Case |
|--------|----------|
| `SmartContractOutcomeParser` | Contract deployments and calls |
| `TokenManagementOutcomeParser` | Token issuance, roles, NFT operations |
| `DelegationOutcomeParser` | Delegation contract creation |
| `GovernanceOutcomeParser` | Proposals, votes, proposal closing |

:::info Where the outcome data is found
Parsers do not stop at `transaction.logs`.

`TokenManagementOutcomeParser` searches the transaction's own logs **and** the
logs attached to every one of its smart contract results, in transaction-first
order. This matters for cross-shard operations: several token-management
endpoints -- role assignment, freeze/unfreeze/wipe, the local mint/burn pair --
run as the system contract forwarding a built-in call to the target address.
That call executes on the target's shard, so its event is reported on the
resulting smart contract result rather than on the original transaction. A
parser that only read `transaction.logs` would silently return an empty list.

`SmartContractOutcomeParser.parseExecute` falls back to the smart contract
results themselves when the transaction's own logs carry no direct outcome,
reading `returnCode` and `returnData` off the result addressed back to the
original sender. `parseDeploy` reads `transaction.logs` only, since `SCDeploy`
is emitted there.

`DelegationOutcomeParser` also reads `transaction.logs` only, which is
sufficient for the `SCDeploy` event it needs.
:::

## SmartContractOutcomeParser

Parse smart contract deployment and execution results.

### Setup

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

// Without ABI (returns raw buffers)
final parser = SmartContractOutcomeParser();

// With ABI (returns decoded values)
final parserWithAbi = SmartContractOutcomeParser(abi: myAbi);
```

### Parse Deployment

Extract deployed contract addresses:

```dart
final hash = await provider.sendTransaction(deployTx);

// Wait for transaction to complete
final txOnNetwork = await provider.getTransaction(hash);

final outcome = parser.parseDeploy(txOnNetwork);

print('Return code: ${outcome.returnCode}');
print('Contracts deployed: ${outcome.contracts.length}');

for (final contract in outcome.contracts) {
  print('Address: ${contract.address.bech32}');
  print('Owner: ${contract.ownerAddress.bech32}');
  print('Code hash: ${HexUtils.bytesToHex(contract.codeHash)}');
}
```

### Parse Execution

Extract return values from contract calls:

```dart
// Send transaction
final hash = await provider.sendTransaction(callTx);
final txOnNetwork = await provider.getTransaction(hash);

// Parse with ABI for decoded values
final parserWithAbi = SmartContractOutcomeParser(abi: myAbi);
final outcome = parserWithAbi.parseExecute(
  txOnNetwork,
  function: 'getBalance', // Function name for ABI lookup
);

print('Return code: ${outcome.returnCode}');
print('Return message: ${outcome.returnMessage}');

// Values are decoded according to ABI
for (final value in outcome.values) {
  print('Value: $value (${value.runtimeType})');
}
```

### Without ABI

When no ABI is provided, raw buffers are returned:

```dart
final parser = SmartContractOutcomeParser();
final outcome = parser.parseExecute(txOnNetwork);

// Values are Uint8List buffers
for (final buffer in outcome.values) {
  print('Raw bytes: ${buffer as Uint8List}');
}
```

### Result Types

`SmartContractDeployOutcome` -- returned by `parseDeploy`:

| Field | Type | Description |
|-------|------|-------------|
| `returnCode` | `String` | `'ok'`, or the code taken from the error event |
| `returnMessage` | `String` | Human-readable message; empty when successful |
| `contracts` | `List<DeployedContract>` | One entry per `SCDeploy` event |

`DeployedContract` -- one deployed contract:

| Field | Type | Description |
|-------|------|-------------|
| `address` | `Address` | Contract address |
| `ownerAddress` | `Address` | Deployer address |
| `codeHash` | `Uint8List` | Contract code hash |

`ParsedSmartContractCallOutcome` -- returned by `parseExecute`:

| Field | Type | Description |
|-------|------|-------------|
| `returnCode` | `String` | Return code reported by the VM |
| `returnMessage` | `String` | Error message, or the return code when there is none |
| `values` | `List<dynamic>` | Decoded values when an ABI is supplied, raw `Uint8List` buffers otherwise |

When the transaction has no logs at all, `parseDeploy` returns an outcome with
empty `returnCode`/`returnMessage` and no contracts rather than throwing.

## TokenManagementOutcomeParser

Parse token management operation results.

### Setup

```dart
final parser = TokenManagementOutcomeParser();
```

### Parse Token Issuance

```dart
// After issuing a fungible token
final txOnNetwork = await provider.getTransaction(issueHash);
final results = parser.parseIssueFungible(txOnNetwork);

for (final result in results) {
  print('Token identifier: ${result.tokenIdentifier}');
  // e.g., "MTK-abc123"
}
```

### Parse NFT Collection

```dart
// After issuing NFT collection
final results = parser.parseIssueNonFungible(txOnNetwork);
print('Collection: ${results.first.tokenIdentifier}');

// After issuing SFT collection
final sftResults = parser.parseIssueSemiFungible(txOnNetwork);
print('SFT Collection: ${sftResults.first.tokenIdentifier}');

// After registering Meta-ESDT
final metaResults = parser.parseRegisterMetaEsdt(txOnNetwork);
print('Meta-ESDT: ${metaResults.first.tokenIdentifier}');
```

### Parse Role Assignment

```dart
final results = parser.parseSetSpecialRole(txOnNetwork);

for (final result in results) {
  print('User: ${result.userAddress.bech32}');
  print('Token: ${result.tokenIdentifier}');
  print('Roles: ${result.roles.join(", ")}');
}
```

### Parse NFT Creation

```dart
final results = parser.parseNftCreate(txOnNetwork);

for (final result in results) {
  print('Token: ${result.tokenIdentifier}');
  print('Nonce: ${result.nonce}'); // NFT ID within collection
  print('Quantity: ${result.initialQuantity}');
}
```

### Parse Mint/Burn

```dart
// Local mint
final mintResults = parser.parseLocalMint(txOnNetwork);
print('Minted: ${mintResults.first.mintedSupply}');

// Local burn
final burnResults = parser.parseLocalBurn(txOnNetwork);
print('Burned: ${burnResults.first.burntSupply}');
```

### Parse Control Operations

```dart
// Pause
final pauseResults = parser.parsePause(txOnNetwork);
print('Paused: ${pauseResults.first.tokenIdentifier}');

// Unpause
final unpauseResults = parser.parseUnpause(txOnNetwork);
print('Unpaused: ${unpauseResults.first.tokenIdentifier}');

// Freeze
final freezeResults = parser.parseFreeze(txOnNetwork);
print('Frozen user: ${freezeResults.first.userAddress}');

// Wipe
final wipeResults = parser.parseWipe(txOnNetwork);
print('Wiped balance: ${wipeResults.first.balance}');
```

### Parse Advanced Token Operations

```dart
// Modify royalties
final royaltiesResults = parser.parseModifyRoyalties(txOnNetwork);
print('New royalties: ${royaltiesResults.first.royalties}'); // basis points

// Set new URIs
final urisResults = parser.parseSetNewUris(txOnNetwork);
print('New URIs: ${urisResults.first.uris}');

// Modify creator
final creatorResults = parser.parseModifyCreator(txOnNetwork);
print('Creator modified for: ${creatorResults.first.tokenIdentifier}');

// Update metadata
final metadataResults = parser.parseUpdateMetadata(txOnNetwork);
print('Metadata updated: ${metadataResults.first.metadata.length} bytes');

// Metadata recreate
final recreateResults = parser.parseMetadataRecreate(txOnNetwork);
print('Metadata recreated for nonce: ${recreateResults.first.nonce}');

// Change token to dynamic
final dynamicResults = parser.parseChangeTokenToDynamic(txOnNetwork);
print('Token type: ${dynamicResults.first.tokenType}');

// Register dynamic token
final registerResults = parser.parseRegisterDynamicToken(txOnNetwork);
print('Registered: ${registerResults.first.tokenIdentifier}');

// Register dynamic token with roles
final registerRolesResults = parser.parseRegisterDynamicTokenAndSettingRoles(txOnNetwork);
print('Registered with roles: ${registerRolesResults.first.tokenIdentifier}');
```

### Parse Global Burn Role

```dart
// These methods validate that the operation succeeded but don't return data
parser.parseSetBurnRoleGlobally(txOnNetwork);  // throws on error
parser.parseUnsetBurnRoleGlobally(txOnNetwork);  // throws on error
```

### All Token Management Results

| Method | Result Type | Fields |
|--------|-------------|--------|
| `parseIssueFungible` | `IssueFungibleResult` | `tokenIdentifier` |
| `parseIssueNonFungible` | `IssueNonFungibleResult` | `tokenIdentifier` |
| `parseIssueSemiFungible` | `IssueSemiFungibleResult` | `tokenIdentifier` |
| `parseRegisterMetaEsdt` | `RegisterMetaEsdtResult` | `tokenIdentifier` |
| `parseRegisterAndSetAllRoles` | `RegisterAndSetAllRolesResult` | `tokenIdentifier`, `roles` |
| `parseSetSpecialRole` | `SetSpecialRoleResult` | `userAddress`, `tokenIdentifier`, `roles` |
| `parseSetBurnRoleGlobally` | `void` | - |
| `parseUnsetBurnRoleGlobally` | `void` | - |
| `parseNftCreate` | `NftCreateResult` | `tokenIdentifier`, `nonce`, `initialQuantity` |
| `parseLocalMint` | `LocalMintResult` | `userAddress`, `tokenIdentifier`, `nonce`, `mintedSupply` |
| `parseLocalBurn` | `LocalBurnResult` | `userAddress`, `tokenIdentifier`, `nonce`, `burntSupply` |
| `parsePause` | `PauseResult` | `tokenIdentifier` |
| `parseUnpause` | `UnpauseResult` | `tokenIdentifier` |
| `parseFreeze` | `FreezeResult` | `userAddress`, `tokenIdentifier`, `nonce`, `balance` |
| `parseUnfreeze` | `UnfreezeResult` | `userAddress`, `tokenIdentifier`, `nonce`, `balance` |
| `parseWipe` | `WipeResult` | `userAddress`, `tokenIdentifier`, `nonce`, `balance` |
| `parseUpdateAttributes` | `UpdateAttributesResult` | `tokenIdentifier`, `nonce`, `attributes` |
| `parseAddQuantity` | `AddQuantityResult` | `tokenIdentifier`, `nonce`, `addedQuantity` |
| `parseBurnQuantity` | `BurnQuantityResult` | `tokenIdentifier`, `nonce`, `burntQuantity` |
| `parseModifyRoyalties` | `ModifyRoyaltiesResult` | `tokenIdentifier`, `nonce`, `royalties` |
| `parseSetNewUris` | `SetNewUrisResult` | `tokenIdentifier`, `nonce`, `uris` |
| `parseModifyCreator` | `ModifyCreatorResult` | `tokenIdentifier`, `nonce` |
| `parseUpdateMetadata` | `UpdateMetadataResult` | `tokenIdentifier`, `nonce`, `metadata` |
| `parseMetadataRecreate` | `MetadataRecreateResult` | `tokenIdentifier`, `nonce`, `metadata` |
| `parseChangeTokenToDynamic` | `ChangeToDynamicResult` | `tokenIdentifier`, `tokenName`, `tickerName`, `tokenType` |
| `parseRegisterDynamicToken` | `RegisterDynamicResult` | `tokenIdentifier`, `tokenName`, `tokenTicker`, `tokenType`, `numOfDecimals` |
| `parseRegisterDynamicTokenAndSettingRoles` | `RegisterDynamicResult` | `tokenIdentifier`, `tokenName`, `tokenTicker`, `tokenType`, `numOfDecimals` |

## DelegationOutcomeParser

Parse delegation contract creation results.

### Setup

```dart
final parser = DelegationOutcomeParser();
```

### Parse Contract Creation

```dart
final txOnNetwork = await provider.getTransaction(delegationHash);
final results = parser.parseCreateNewDelegationContract(txOnNetwork);

for (final result in results) {
  print('Delegation contract: ${result.contractAddress}');
}
```

## Error Handling

Parsers throw exceptions when transactions contain errors:

```dart
try {
  final results = parser.parseIssueFungible(txOnNetwork);
  print('Success: ${results.first.tokenIdentifier}');
} on TokenManagementParseException catch (e) {
  print('Token operation failed: ${e.message}');
  if (e.cause != null) {
    print('Caused by: ${e.cause}');
  }
} on SmartContractParseException catch (e) {
  print('Contract operation failed: ${e.message}');
} on DelegationParseException catch (e) {
  print('Delegation operation failed: ${e.message}');
}
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('your mnemonic...');
  
  final controller = TokenManagementController(
    chainId: const ChainId.devnet(),
    gasLimitEstimator: GasEstimator(networkProvider: provider),
  );
  
  final accountInfo = await provider.getAccount(account.address);
  
  // 1. Issue token
  final input = IssueFungibleInput(
    tokenName: 'MyToken',
    tokenTicker: 'MTK',
    initialSupply: BigInt.from(1000000000000000000),
    numDecimals: BigInt.from(18),
    canFreeze: true,
    canWipe: true,
    canPause: true,
    canChangeOwner: true,
    canUpgrade: true,
    canAddSpecialRoles: true,
  );
  
  final tx = await controller.createTransactionForIssuingFungible(
    account,
    accountInfo.nonce,
    input,
    const BaseControllerInput(),
  );
  
  final hash = await provider.sendTransaction(tx);
  print('Sent: $hash');
  
  // 2. Wait for completion
  final watcher = TransactionWatcher(networkProvider: provider);
  await watcher.awaitCompleted(hash);
  
  // 3. Parse outcome
  final txOnNetwork = await provider.getTransaction(hash);
  final parser = TokenManagementOutcomeParser();
  
  try {
    final results = parser.parseIssueFungible(txOnNetwork);
    final tokenId = results.first.tokenIdentifier;
    print('Token created: $tokenId');
    
    // Save token identifier for future use
    // e.g., store in database or config
    
  } on TokenManagementParseException catch (e) {
    print('Failed to issue token: ${e.message}');
  }
}
```

## Best Practices

1. **Always wait for finalization** - Parse only after transaction is finalized
2. **Handle errors** - Wrap parsing in try-catch for graceful error handling
3. **Use ABI when available** - Provides typed return values instead of raw bytes
4. **Store identifiers** - Save token identifiers and contract addresses from outcomes
5. **Check return codes** - Verify `returnCode == 'ok'` before using results
