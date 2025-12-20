---
id: token-management
title: Token Management
sidebar_position: 7
description: Create, issue, and manage ESDT tokens including fungible, NFT, SFT, and Meta-ESDT with role management and minting.
---

# Token Management

Create, issue, and manage ESDT tokens including fungible, semi-fungible, non-fungible, and Meta-ESDT tokens.

## Overview

The `TokenManagementController` provides a complete API for ESDT token lifecycle management:

- **Issue tokens** - Create new fungible, NFT, SFT, or Meta-ESDT collections
- **Manage roles** - Assign minting, burning, and transfer roles
- **NFT operations** - Create, mint, burn NFTs with attributes
- **Token control** - Pause, freeze, wipe, and change ownership

## TokenManagementController

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

final controller = TokenManagementController(
  chainId: const ChainId.devnet(),
  gasLimitEstimator: GasEstimator(networkProvider: provider),
);
```

## Issuing Tokens

### Fungible Token

Create a standard fungible ESDT token:

```dart
final account = await Account.fromPem('wallet.pem');
final accountInfo = await provider.getAccount(account.address);

final input = IssueFungibleInput(
  tokenName: 'MyToken',
  tokenTicker: 'MTK',
  initialSupply: BigInt.from(1000000000000000000), // 1 billion
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
print('Issue transaction: $hash');
```

### Non-Fungible Token (NFT)

Create an NFT collection:

```dart
final input = IssueNonFungibleInput(
  tokenName: 'MyNFTCollection',
  tokenTicker: 'MNFT',
  canFreeze: true,
  canWipe: true,
  canPause: false,
  canChangeOwner: true,
  canUpgrade: true,
  canAddSpecialRoles: true,
  canTransferNFTCreateRole: true,
);

final tx = await controller.createTransactionForIssuingNonFungible(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);
```

### Semi-Fungible Token (SFT)

Create an SFT collection (NFTs with quantity):

```dart
final input = IssueSemiFungibleInput(
  tokenName: 'MySFTCollection',
  tokenTicker: 'MSFT',
  canFreeze: true,
  canWipe: true,
  canPause: false,
  canChangeOwner: true,
  canUpgrade: true,
  canAddSpecialRoles: true,
  canTransferNFTCreateRole: true,
);

final tx = await controller.createTransactionForIssuingSemiFungible(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);
```

### Meta-ESDT

Create a Meta-ESDT token (fungible with NFT properties):

```dart
final input = RegisterMetaESDTInput(
  tokenName: 'MyMetaToken',
  tokenTicker: 'MMETA',
  numDecimals: BigInt.from(18),
  canFreeze: true,
  canWipe: true,
  canPause: true,
  canChangeOwner: true,
  canUpgrade: true,
  canAddSpecialRoles: true,
  canTransferNFTCreateRole: true,
);

final tx = await controller.createTransactionForRegisteringMetaEsdt(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);
```

## Managing Roles

### Set Fungible Token Roles

```dart
final input = FungibleSpecialRoleInput(
  tokenIdentifier: 'MTK-abc123',
  user: Address.fromBech32('erd1...'),
  addRoleLocalMint: true,
  addRoleLocalBurn: true,
  addRoleESDTTransferRole: false,
);

final tx = await controller.createTransactionForSettingSpecialRoleOnFungibleToken(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);
```

### Set NFT/SFT Roles

```dart
final input = SpecialRoleInput(
  tokenIdentifier: 'MNFT-abc123',
  user: Address.fromBech32('erd1...'),
  addRoleNFTCreate: true,
  addRoleNFTBurn: true,
  addRoleNFTUpdateAttributes: true,
  addRoleNFTAddURI: true,
  addRoleESDTTransferRole: false,
);

final tx = await controller.createTransactionForSettingSpecialRoleOnNonFungibleToken(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);
```

### Unset Roles

```dart
final input = UnsetFungibleSpecialRoleInput(
  tokenIdentifier: 'MTK-abc123',
  user: Address.fromBech32('erd1...'),
  removeRoleLocalMint: true,
  removeRoleLocalBurn: false,
  removeRoleESDTTransferRole: false,
);

final tx = await controller.createTransactionForUnsettingSpecialRoleOnFungibleToken(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);
```

### Set SFT/Meta-ESDT Roles

```dart
final input = SemiFungibleSpecialRoleInput(
  tokenIdentifier: 'MSFT-abc123',
  user: Address.fromBech32('erd1...'),
  addRoleNFTCreate: true,
  addRoleNFTBurn: true,
  addRoleNFTAddQuantity: true,
  addRoleESDTTransferRole: false,
);

// For SFT
final sftTx = await controller.createTransactionForSettingSpecialRoleOnSemiFungibleToken(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);

// For Meta-ESDT (same input type)
final metaTx = await controller.createTransactionForSettingSpecialRoleOnMetaESDT(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);
```

## NFT Operations

### Create NFT

```dart
final input = MintInput(
  tokenIdentifier: 'MNFT-abc123',
  initialQuantity: BigInt.one,
  name: 'My First NFT',
  royalties: 500, // 5% (max 10000 = 100%)
  hash: '', // Optional content hash
  attributes: Uint8List.fromList(utf8.encode('metadata:ipfs://...')),
  uris: ['https://example.com/nft/1.json'],
);

final tx = await controller.createTransactionForCreatingNft(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);
```

### Add NFT Quantity (SFT)

```dart
final input = UpdateQuantityInput(
  tokenIdentifier: 'MSFT-abc123',
  tokenNonce: BigInt.from(1),
  quantity: BigInt.from(100),
);

final tx = await controller.createTransactionForAddingQuantity(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);
```

### Burn NFT Quantity

```dart
final input = UpdateQuantityInput(
  tokenIdentifier: 'MSFT-abc123',
  tokenNonce: BigInt.from(1),
  quantity: BigInt.from(50),
);

final tx = await controller.createTransactionForBurningQuantity(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);
```

## Token Control

### Pause/Unpause Token

```dart
// Pause token transfers
final pauseInput = PausingInput(tokenIdentifier: 'MTK-abc123');
final pauseTx = await controller.createTransactionForPausing(
  account,
  accountInfo.nonce,
  pauseInput,
  const BaseControllerInput(),
);

// Unpause token transfers
final unpauseInput = PausingInput(tokenIdentifier: 'MTK-abc123');
final unpauseTx = await controller.createTransactionForUnpausing(
  account,
  accountInfo.nonce,
  unpauseInput,
  const BaseControllerInput(),
);
```

### Freeze/Unfreeze Account

```dart
// Freeze specific account
final freezeInput = ManagementInput(
  tokenIdentifier: 'MTK-abc123',
  user: Address.fromBech32('erd1...'),
);
final freezeTx = await controller.createTransactionForFreezing(
  account,
  accountInfo.nonce,
  freezeInput,
  const BaseControllerInput(),
);

// Unfreeze account
final unfreezeInput = ManagementInput(
  tokenIdentifier: 'MTK-abc123',
  user: Address.fromBech32('erd1...'),
);
final unfreezeTx = await controller.createTransactionForUnfreezing(
  account,
  accountInfo.nonce,
  unfreezeInput,
  const BaseControllerInput(),
);
```

### Wipe Frozen Account

```dart
final input = ManagementInput(
  tokenIdentifier: 'MTK-abc123',
  user: Address.fromBech32('erd1...'),
);

final tx = await controller.createTransactionForWiping(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);
```

## Minting & Burning

### Local Mint

```dart
final input = LocalMintInput(
  tokenIdentifier: 'MTK-abc123',
  supplyToMint: BigInt.from(1000000000000000000), // 1 token
);

final tx = await controller.createTransactionForLocalMinting(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);
```

### Local Burn

```dart
final input = LocalBurnInput(
  tokenIdentifier: 'MTK-abc123',
  supplyToBurn: BigInt.from(1000000000000000000), // 1 token
);

final tx = await controller.createTransactionForLocalBurning(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);
```

## Advanced Token Operations

### Modify Royalties

```dart
final input = ModifyRoyaltiesInput(
  tokenIdentifier: 'MNFT-abc123',
  tokenNonce: BigInt.from(1),
  newRoyalties: BigInt.from(750), // 7.5%
);

final tx = await controller.createTransactionForModifyingRoyalties(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);
```

### Set New URIs

```dart
final input = SetNewUriInput(
  tokenIdentifier: 'MNFT-abc123',
  tokenNonce: BigInt.from(1),
  newUris: ['https://new-uri.com/metadata.json'],
);

final tx = await controller.createTransactionForSettingNewUris(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);
```

### Modify Creator

```dart
final input = ModifyCreatorInput(
  tokenIdentifier: 'MNFT-abc123',
  tokenNonce: BigInt.from(1),
);

final tx = await controller.createTransactionForModifyingCreator(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);
```

### Update Metadata

```dart
final input = ManageMetadataInput(
  tokenIdentifier: 'MNFT-abc123',
  tokenNonce: BigInt.from(1),
  newTokenName: 'Updated NFT Name',
  newRoyalties: BigInt.from(500),
  newAttributes: Uint8List.fromList(utf8.encode('new:attributes')),
  newUris: ['https://example.com/new-metadata.json'],
);

final tx = await controller.createTransactionForUpdatingMetadata(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);
```

### Change Token to Dynamic

```dart
final input = ChangeTokenToDynamicInput(tokenIdentifier: 'MNFT-abc123');

final tx = await controller.createTransactionForChangingTokenToDynamic(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);
```

### Global Burn Role

```dart
final input = BurnRoleGloballyInput(tokenIdentifier: 'MTK-abc123');

// Set global burn role
final setTx = await controller.createTransactionForSettingBurnRoleGlobally(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);

// Unset global burn role
final unsetTx = await controller.createTransactionForUnsettingBurnRoleGlobally(
  account,
  accountInfo.nonce,
  input,
  const BaseControllerInput(),
);
```

## Parsing Outcomes

Use `TokenManagementOutcomeParser` to extract results from completed transactions:

```dart
final parser = TokenManagementOutcomeParser();

// After transaction is processed
final tx = await provider.getTransaction(hash);

// Parse issue result
final issueResult = parser.parseIssueFungible(tx);
print('Token identifier: ${issueResult.first.tokenIdentifier}');

// Parse NFT creation
final nftResult = parser.parseNftCreate(tx);
print('NFT nonce: ${nftResult.first.nonce}');

// Parse role assignment
final roleResult = parser.parseSetSpecialRole(tx);
print('Assigned roles: ${roleResult.first.roles}');
```

### Available Parsers

| Method | Result Type |
|--------|-------------|
| `parseIssueFungible` | `IssueFungibleResult` |
| `parseIssueNonFungible` | `IssueNonFungibleResult` |
| `parseIssueSemiFungible` | `IssueSemiFungibleResult` |
| `parseRegisterMetaEsdt` | `RegisterMetaEsdtResult` |
| `parseRegisterAndSetAllRoles` | `RegisterAndSetAllRolesResult` |
| `parseSetSpecialRole` | `SetSpecialRoleResult` |
| `parseSetBurnRoleGlobally` | `void` |
| `parseUnsetBurnRoleGlobally` | `void` |
| `parseNftCreate` | `NftCreateResult` |
| `parseLocalMint` | `LocalMintResult` |
| `parseLocalBurn` | `LocalBurnResult` |
| `parsePause` | `PauseResult` |
| `parseUnpause` | `UnpauseResult` |
| `parseFreeze` | `FreezeResult` |
| `parseUnfreeze` | `UnfreezeResult` |
| `parseWipe` | `WipeResult` |
| `parseUpdateAttributes` | `UpdateAttributesResult` |
| `parseAddQuantity` | `AddQuantityResult` |
| `parseBurnQuantity` | `BurnQuantityResult` |
| `parseModifyRoyalties` | `ModifyRoyaltiesResult` |
| `parseSetNewUris` | `SetNewUrisResult` |
| `parseModifyCreator` | `ModifyCreatorResult` |
| `parseUpdateMetadata` | `UpdateMetadataResult` |
| `parseMetadataRecreate` | `MetadataRecreateResult` |
| `parseChangeTokenToDynamic` | `ChangeToDynamicResult` |
| `parseRegisterDynamicToken` | `RegisterDynamicResult` |
| `parseRegisterDynamicTokenAndSettingRoles` | `RegisterDynamicResult` |

## Token Properties Reference

| Property | Description |
|----------|-------------|
| `canFreeze` | Owner can freeze accounts |
| `canWipe` | Owner can wipe frozen accounts |
| `canPause` | Owner can pause all transfers |
| `canChangeOwner` | Ownership can be transferred |
| `canUpgrade` | Properties can be modified |
| `canAddSpecialRoles` | Roles can be assigned to accounts |
| `canTransferNFTCreateRole` | NFT create role can be transferred |

## Role Reference

### Fungible Token Roles

| Role | Description |
|------|-------------|
| `ESDTRoleLocalMint` | Mint new tokens |
| `ESDTRoleLocalBurn` | Burn tokens |
| `ESDTTransferRole` | Transfer when restricted |

### NFT/SFT Roles

| Role | Description |
|------|-------------|
| `ESDTRoleNFTCreate` | Create new NFTs |
| `ESDTRoleNFTBurn` | Burn NFTs |
| `ESDTRoleNFTUpdateAttributes` | Modify NFT attributes |
| `ESDTRoleNFTAddURI` | Add URIs to NFTs |
| `ESDTRoleNFTAddQuantity` | Add quantity to SFTs |
| `ESDTTransferRole` | Transfer when restricted |

## Best Practices

1. **Always check properties** - Set `canAddSpecialRoles: true` if you need to assign roles later
2. **Use appropriate decimals** - Standard is 18 for fungible tokens
3. **Store token identifiers** - Parse and save the identifier from issue transactions
4. **Wait for finalization** - Token operations require finalization before roles work
5. **Test on devnet first** - Issue costs 0.05 EGLD on mainnet
