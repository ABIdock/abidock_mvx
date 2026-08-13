---
name: tokens-esdt
title: ESDT Tokens
summary: Build correct ESDT issuance, role, control and NFT-lifecycle transactions with the right receiver, value, gas and argument order.
reads: [skills/09-events-and-parsers.md]
verified_against: abidock_mvx 3.1.0 (Dart 3.13)
---

## When to use this

You need to issue a token, grant/revoke roles, pause/freeze/wipe, or run any NFT
lifecycle operation, and you must get the receiver, the EGLD value and the
argument order right on the first attempt.

---

## 1. The rule that breaks everything if you get it wrong

An ESDT operation is one of **two different things on the wire**, and they are
addressed to **different receivers**.

| Kind | Receiver | Why |
| --- | --- | --- |
| **System-contract endpoint** (`issue`, `setSpecialRole`, `pause`, `freeze`, `unFreeze`, `wipe`, …) | the ESDT system smart contract | The endpoint is a call *into* the system contract, which owns the token registry. |
| **Built-in function** (`ESDTNFTCreate`, `ESDTLocalMint`, `ESDTNFTAddQuantity`, …) | **the SENDER's own address** | A built-in function executes against the caller's own account state, so the transaction is addressed to the caller. |

The factory encodes this in one place: `receiverIsSender ? sender : _esdtContractAddress`
(`lib/src/core/transaction/factories/token_management_transactions_factory.dart:1259`).
The system-contract address is the constant `esdtContractAddressHex` =
`000000000000000000010000000000000000000000000000000000000002ffff`
(`…/token_management_transactions_factory.dart:10`).

**Do not** send a built-in function to the ESDT system contract. **Do not** send a
system-contract endpoint to the sender. Both are accepted by the node and both fail.

### Definitive split

**Built-in functions — receiver is the SENDER** (every one of these passes
`receiverIsSender: true`):

| Builder | Emitted function |
| --- | --- |
| `createTransactionForCreatingNft` | `ESDTNFTCreate` |
| `createTransactionForLocalMint` | `ESDTLocalMint` |
| `createTransactionForLocalBurn` | `ESDTLocalBurn` |
| `createTransactionForUpdatingAttributes` | `ESDTNFTUpdateAttributes` |
| `createTransactionForAddingQuantity` | `ESDTNFTAddQuantity` |
| `createTransactionForBurningQuantity` | `ESDTNFTBurn` |
| `createTransactionForModifyingRoyalties` | `ESDTModifyRoyalties` |
| `createTransactionForSettingNewUris` | `ESDTSetNewURIs` |
| `createTransactionForAddingNftUri` | `ESDTNFTAddURI` |
| `createTransactionForModifyingCreator` | `ESDTModifyCreator` |
| `createTransactionForNftUpdate` | `ESDTNFTUpdate` |
| `createTransactionForNftRecreate` | `ESDTNFTRecreate` |
| `createTransactionForUpdatingMetadata` | `ESDTMetaDataUpdate` |
| `createTransactionForRecreatingMetadata` | `ESDTMetaDataRecreate` |

**System-contract endpoints — receiver is the ESDT contract** (everything else):
`issue`, `issueSemiFungible`, `issueNonFungible`, `registerMetaESDT`,
`registerAndSetAllRoles`, `registerDynamic`, `registerAndSetAllRolesDynamic`,
`setBurnRoleGlobally`, `unsetBurnRoleGlobally`, `setSpecialRole`,
`unSetSpecialRole`, `pause`, `unPause`, `freeze`, `unFreeze`, `wipe`,
`controlChanges`, `transferOwnership`, `transferNFTCreateRole`, `stopNFTCreate`,
`changeToDynamic`, `changeSFTToMetaESDT`, `updateTokenID`.

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// Verifies the system-contract vs built-in-function receiver split.
void main() {
  final TokenManagementTransactionsFactory factory =
      TokenManagementTransactionsFactory(
        config: const TokenManagementConfig(chainId: ChainId('D')),
      );

  final Address owner = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );

  /// System-contract endpoint: receiver is the ESDT system contract.
  final Transaction issue = factory.createTransactionForIssuingFungible(
    sender: owner,
    tokenName: 'AlphaCoin',
    tokenTicker: 'ALPHA',
    initialSupply: BigInt.from(1000000),
    decimals: 18,
    properties: const TokenProperties(canFreeze: true, canAddSpecialRoles: true),
  );
  assert(issue.receiver.hex == esdtContractAddressHex, 'system contract');

  /// Built-in function: receiver is the SENDER.
  final Transaction mint = factory.createTransactionForLocalMint(
    sender: owner,
    tokenIdentifier: 'ALPHA-abcdef',
    supplyToMint: BigInt.from(10),
  );
  assert(mint.receiver.bech32 == owner.bech32, 'built-in call');
}
```

### `unFreeze`, not `UnFreeze`

The chain endpoint is spelled `unFreeze` with a lower-case `f`
(`…/token_management_transactions_factory.dart:648`). The matching *event*
identifier the chain emits is `ESDTUnFreeze` with an upper-case `F`
(`lib/src/core/transaction/outcome_parsers/token_management_outcome_parser.dart:772`).
They are genuinely different strings; do not normalise one to the other.

---

## 2. Gas and value

Every builder computes:

```
gasLimit = minGasLimit + gasLimitPerByte * data.length   (data-movement gas)
         + executionGasLimit                             (endpoint execution gas)
```

`…/token_management_transactions_factory.dart:1254-1262`. Defaults in
`TokenManagementConfig`: `minGasLimit = 50000`, `gasLimitPerByte = 1500`
(`:36-37`), `issueCost = '50000000000000000'` (0.05 EGLD, `:59`).

Verified example: `pause@4652414e4b2d313163653365` is 30 bytes, execution gas
`gasLimitPausing = 60000000`, so `50000 + 1500*30 + 60000000 = 60095000` — which
is exactly the `gasLimit` the builder produces.

Builders that add per-byte storage gas on top of their execution gas
(`gasLimitStorePerByte = 10000`, `:50`): NFT create, attribute update, set-new-URIs,
metadata update/recreate, `ESDTNFTUpdate`, `ESDTNFTRecreate` — charged on
`attributes.length + sum(uri.length)`.

**EGLD value**: only the seven registration endpoints carry value — `issue`,
`issueSemiFungible`, `issueNonFungible`, `registerMetaESDT`,
`registerAndSetAllRoles`, `registerDynamic`, `registerAndSetAllRolesDynamic` —
each `Balance.fromString(config.issueCost)` = 0.05 EGLD. Everything else is zero.

---

## 3. Builder reference

`TokenManagementTransactionsFactory({required TokenManagementConfig config})`.
All parameters below are **named**; `sender` is `Address` and required everywhere.
"Payload" is the emitted `data` field; each `@`-separated argument is hex on the wire.

### Registration (receiver = ESDT contract, value = 0.05 EGLD)

| Method | Parameters after `sender` | Payload |
| --- | --- | --- |
| `createTransactionForIssuingFungible` | `tokenName`, `tokenTicker`, `initialSupply` (`BigInt`), `decimals` (`int`), `properties` (`TokenProperties`, optional) | `issue@name@ticker@supply@decimals@<property pairs, no canTransferNFTCreateRole>` |
| `createTransactionForIssuingNonFungible` | `tokenName`, `tokenTicker`, `properties` (optional) | `issueNonFungible@name@ticker@<all property pairs>` |
| `createTransactionForIssuingSemiFungible` | `tokenName`, `tokenTicker`, `properties` (optional) | `issueSemiFungible@name@ticker@<all property pairs>` |
| `createTransactionForRegisteringMetaEsdt` | `tokenName`, `tokenTicker`, `decimals` (`int`), `properties` (optional) | `registerMetaESDT@name@ticker@decimals@<all property pairs>` |
| `createTransactionForRegisteringAndSettingRoles` | `tokenName`, `tokenTicker`, `tokenType` (`String`), `decimals` (`int`) | `registerAndSetAllRoles@name@ticker@type@decimals` |
| `createTransactionForRegisteringDynamic` | `tokenName`, `tokenTicker`, `tokenType`, `numDecimals` (`int?`) | `registerDynamic@name@ticker@type[@decimals]` |
| `createTransactionForRegisteringAndSettingAllRolesDynamic` | `tokenName`, `tokenTicker`, `tokenType`, `numDecimals` (`int?`) | `registerAndSetAllRolesDynamic@name@ticker@type[@decimals]` |

Constraints enforced at build time (`ArgumentError` on violation,
`…/token_management_transactions_factory.dart:1136-1185`):

- `tokenName` must match `^[A-Za-z0-9]{3,20}$`.
- `tokenTicker` must match `^[A-Z0-9]{3,10}$` — lower case is rejected.
- `registerAndSetAllRoles` accepts `tokenType` in `tokenTypes` = `{'NFT','SFT','META','FNG'}`.
- The two dynamic builders accept `dynamicTokenTypes` = `{'NFT','SFT','META'}`;
  `'FNG'` throws.
- Exported constants: `tokenTypeFungible = 'FNG'`, `tokenTypeMeta = 'META'` (`:14`, `:17`).

`registerAndSetAllRoles` emits **exactly four arguments** and no properties
(`:326-331`).

For the two dynamic builders, `numDecimals` is emitted **only when
`tokenType == 'META'`** (`:941-942`, `:1090-1091`). Passing `numDecimals` with
`'NFT'` or `'SFT'` silently drops it. Verified payload for
`tokenType: 'NFT', numDecimals: 18`:
`registerDynamic@416c7068614e667473@414e4654@4e4654` — three arguments.

### Roles and control (receiver = ESDT contract, value = 0)

| Method | Parameters after `sender` | Payload |
| --- | --- | --- |
| `createTransactionForSettingSpecialRoleOnFungibleToken` | `user` (`Address`), `tokenIdentifier`, `roles` (`List<String>`) | `setSpecialRole@token@userPubkey@role…` |
| `createTransactionForUnsettingSpecialRoleOnFungibleToken` | `user`, `tokenIdentifier`, `roles` | `unSetSpecialRole@token@userPubkey@role…` |
| `createTransactionForSettingSpecialRoleOnNonFungibleToken` | `user`, `tokenIdentifier`, `roles` | identical to the fungible variant — it delegates to it (`:411-423`) |
| `createTransactionForUnsettingSpecialRoleOnNonFungibleToken` | `user`, `tokenIdentifier`, `roles` | identical to the fungible unset variant (`:426-438`) |
| `createTransactionForSettingBurnRoleGlobally` | `tokenIdentifier` | `setBurnRoleGlobally@token` |
| `createTransactionForUnsettingBurnRoleGlobally` | `tokenIdentifier` | `unsetBurnRoleGlobally@token` |
| `createTransactionForPausing` | `tokenIdentifier` | `pause@token` |
| `createTransactionForUnpausing` | `tokenIdentifier` | `unPause@token` |
| `createTransactionForFreezing` | `tokenIdentifier`, `addressToFreeze` (`Address`) | `freeze@token@pubkey` |
| `createTransactionForUnfreezing` | `tokenIdentifier`, `addressToUnfreeze` (`Address`) | `unFreeze@token@pubkey` |
| `createTransactionForWiping` | `tokenIdentifier`, `addressToWipe` (`Address`), `nonce` (`int`, default `0`) | `wipe@token[@nonce]@pubkey` — the nonce argument is emitted only when `nonce > 0` (`:663`) |
| `createTransactionForControllingProperties` | `tokenIdentifier`, `properties` (`TokenProperties`, required) | `controlChanges@token@<all property pairs>` |
| `createTransactionForTransferringOwnership` | `tokenIdentifier`, `newOwner` (`Address`) | `transferOwnership@token@pubkey` |
| `createTransactionForTransferringNftCreateRole` | `tokenIdentifier`, `oldCreator`, `newCreator` | `transferNFTCreateRole@token@oldPubkey@newPubkey` |
| `createTransactionForStoppingNftCreate` | `tokenIdentifier` | `stopNFTCreate@token` — irreversible |
| `createTransactionForChangingToDynamic` | `tokenIdentifier` | `changeToDynamic@token` |
| `createTransactionForChangingSftToMetaEsdt` | `tokenIdentifier`, `numDecimals` (`int`) | `changeSFTToMetaESDT@token@decimals` |
| `createTransactionForUpdatingTokenId` | `tokenIdentifier` | `updateTokenID@token` |

Verified payloads (produced by running the builders):

```
unFreeze@414c5048412d616263646566@1e8a8b6b49de5b7be10aaa158a5a6a4abb4b56cc08f524bb5e6cd5f211ad3e13
wipe@5346542d313233343536@03@1e8a8b6b49de5b7be10aaa158a5a6a4abb4b56cc08f524bb5e6cd5f211ad3e13
changeSFTToMetaESDT@5346542d313233343536@12
```

### Built-in functions (receiver = SENDER, value = 0)

| Method | Parameters after `sender` | Payload |
| --- | --- | --- |
| `createTransactionForCreatingNft` | `tokenIdentifier`, `initialQuantity` (`BigInt`), `name` (`String`), `royalties` (`int`), `hash` (`String?`), `attributes` (`Uint8List?`), `uris` (`List<String>?`) | `ESDTNFTCreate@token@quantity@name@royalties@hash@attributes@uri…` |
| `createTransactionForLocalMint` | `tokenIdentifier`, `supplyToMint` (`BigInt`), `nonce` (`int`, default `0`) | `ESDTLocalMint@token[@nonce]@supply` |
| `createTransactionForLocalBurn` | `tokenIdentifier`, `supplyToBurn` (`BigInt`), `nonce` (`int`, default `0`) | `ESDTLocalBurn@token[@nonce]@supply` |
| `createTransactionForAddingQuantity` | `tokenIdentifier`, `nonce` (`int`), `quantityToAdd` (`BigInt`) | `ESDTNFTAddQuantity@token@nonce@quantity` |
| `createTransactionForBurningQuantity` | `tokenIdentifier`, `nonce` (`int`), `quantityToBurn` (`BigInt`) | `ESDTNFTBurn@token@nonce@quantity` |
| `createTransactionForUpdatingAttributes` | `tokenIdentifier`, `nonce` (`int`), `attributes` (`Uint8List`) | `ESDTNFTUpdateAttributes@token@nonce@attributes` |
| `createTransactionForAddingNftUri` | `tokenIdentifier`, `nonce` (`int`), `uris` (`List<String>`) | `ESDTNFTAddURI@token@nonce@uri…` — appends; throws `ArgumentError` when `uris` is empty (`:1003-1005`) |
| `createTransactionForSettingNewUris` | `tokenIdentifier`, `nonce` (`int`), `newUris` (`List<String>`) | `ESDTSetNewURIs@token@nonce@uri…` — replaces the whole URI list |
| `createTransactionForModifyingRoyalties` | `tokenIdentifier`, `nonce` (`int`), `newRoyalties` (`int`) | `ESDTModifyRoyalties@token@nonce@royalties` |
| `createTransactionForModifyingCreator` | `tokenIdentifier`, `nonce` (`int`) | `ESDTModifyCreator@token@nonce` |
| `createTransactionForUpdatingMetadata` | `tokenIdentifier`, `nonce`, `newName`, `newRoyalties` (`int`), `newHash` (`String?`), `newAttributes` (`Uint8List?`), `newUris` (`List<String>?`) | `ESDTMetaDataUpdate@token@nonce@name@royalties@hash@attributes@uri…` |
| `createTransactionForRecreatingMetadata` | same as above | `ESDTMetaDataRecreate@…` |
| `createTransactionForNftUpdate` | same as above | `ESDTNFTUpdate@…` |
| `createTransactionForNftRecreate` | same as above | `ESDTNFTRecreate@…` |

`nonce` on local mint/burn and on `wipe` is `int` and defaults to `0`; the
argument is **omitted entirely** when it is `0`, which is what fungible tokens
need. Pass a positive nonce for SFT/META instances. Verified:
`ESDTLocalMint@5346542d313233343536@07@ff` for `nonce: 7, supplyToMint: 255`.

`hash` / `newHash` are `String?` and are UTF-8 encoded into a bytes argument;
`null` becomes an empty argument (`:456`, `:763`).

---

## 4. Token properties

```
const TokenProperties({
  this.canFreeze = false,
  this.canWipe = false,
  this.canPause = false,
  this.canTransferNFTCreateRole = false,
  this.canChangeOwner = false,
  this.canUpgrade = true,      /// note: true by default
  this.canAddSpecialRoles = false,
});
```
(`…/token_management_transactions_factory.dart:131-139`.)

**Every supported property is emitted, with its literal `true` or `false`
value** (`:1205-1226`). A missing pair does not mean "disabled" — the system
contract keeps its own default for any pair you omit, so omitting is how you
accidentally ship a token with `canUpgrade`/`canAddSpecialRoles` already on.
Emitting every pair is also what makes `controlChanges` able to switch a
property back *off*.

**The fungible `issue` endpoint omits `canTransferNFTCreateRole`** — it is passed
`includeTransferNftCreateRole: false` (`:195`). It is emitted by
`issueNonFungible`, `issueSemiFungible`, `registerMetaESDT` and `controlChanges`.
Setting `canTransferNFTCreateRole: true` on a fungible issue is silently dropped;
that is correct, not a bug.

Verified `issue` payload with every flag on (`AlphaCoin`/`ALPHA`, supply
1 000 000, 18 decimals):

```
issue@416c706861436f696e@414c504841@0f4240@12
@63616e467265657a65@74727565
@63616e57697065@74727565
@63616e5061757365@74727565
@63616e4368616e67654f776e6572@74727565
@63616e55706772616465@74727565
@63616e4164645370656369616c526f6c6573@74727565
```

Six pairs, no `canTransferNFTCreateRole`. The `issueSemiFungible` /
`issueNonFungible` / `registerMetaESDT` payloads carry seven pairs, with
`63616e5472616e736665724e4654437265617465526f6c65` inserted after `canPause`.
(Pinned in `test/core/transaction/factories/token_management_builders_coverage_test.dart:105-217`.)

`controlChanges` takes the **complete desired end state**, not a delta (`:972-992`).

---

## 5. Roles

Role names are plain strings passed through verbatim by the factory. The role
names this SDK constructs from its boolean inputs are exactly
(`lib/src/core/transaction/controllers/token_management_controller.dart:34-71`,
`:266-270`, `:291-294`, `:314-318`, `:338-341`):

| Token kind | Roles the controller can emit |
| --- | --- |
| Fungible (set) | `ESDTRoleLocalMint`, `ESDTRoleLocalBurn`, `ESDTTransferRole` |
| Fungible (unset) | `ESDTRoleLocalMint`, `ESDTRoleLocalBurn`, `ESDTTransferRole` |
| Non-fungible (set) | `ESDTRoleNFTCreate`, `ESDTRoleNFTBurn`, `ESDTRoleNFTUpdateAttributes`, `ESDTRoleNFTAddURI`, `ESDTTransferRole` |
| Non-fungible (unset) | `ESDTRoleNFTBurn`, `ESDTRoleNFTUpdateAttributes`, `ESDTRoleNFTAddURI`, `ESDTTransferRole` — `ESDTRoleNFTCreate` has no unset flag |
| Semi-fungible / Meta (set) | `ESDTRoleNFTCreate`, `ESDTRoleNFTBurn`, `ESDTRoleNFTAddQuantity`, `ESDTTransferRole` |
| Semi-fungible / Meta (unset) | `ESDTRoleNFTBurn`, `ESDTRoleNFTAddQuantity`, `ESDTTransferRole` |

For any role name outside that list, call the **factory** and pass the string
yourself — `roles: List<String>` is emitted verbatim (`:378`, `:399`).

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// Roles and control endpoints. All of these are system-contract endpoints.
void main() {
  final TokenManagementTransactionsFactory factory =
      TokenManagementTransactionsFactory(
        config: const TokenManagementConfig(chainId: ChainId('D')),
      );
  final Address manager = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  final Address user = Address.fromBech32(
    'erd1r69gk66fmedhhcg24g2c5kn2f2a5k4kvpr6jfw67dn2lyydd8cfswy6ede',
  );
  const String fungible = 'ALPHA-abcdef';
  const String collection = 'NFTC-123456';

  final Transaction setFungibleRoles = factory
      .createTransactionForSettingSpecialRoleOnFungibleToken(
        sender: manager,
        user: user,
        tokenIdentifier: fungible,
        roles: const <String>[
          'ESDTRoleLocalMint',
          'ESDTRoleLocalBurn',
          'ESDTTransferRole',
        ],
      );

  final Transaction unsetFungibleRoles = factory
      .createTransactionForUnsettingSpecialRoleOnFungibleToken(
        sender: manager,
        user: user,
        tokenIdentifier: fungible,
        roles: const <String>['ESDTRoleLocalMint'],
      );

  final Transaction setNftRoles = factory
      .createTransactionForSettingSpecialRoleOnNonFungibleToken(
        sender: manager,
        user: user,
        tokenIdentifier: collection,
        roles: const <String>[
          'ESDTRoleNFTCreate',
          'ESDTRoleNFTBurn',
          'ESDTRoleNFTUpdateAttributes',
          'ESDTRoleNFTAddURI',
        ],
      );

  final Transaction pause = factory.createTransactionForPausing(
    sender: manager,
    tokenIdentifier: fungible,
  );
  final Transaction unpause = factory.createTransactionForUnpausing(
    sender: manager,
    tokenIdentifier: fungible,
  );
  final Transaction freeze = factory.createTransactionForFreezing(
    sender: manager,
    tokenIdentifier: fungible,
    addressToFreeze: user,
  );
  final Transaction unfreeze = factory.createTransactionForUnfreezing(
    sender: manager,
    tokenIdentifier: fungible,
    addressToUnfreeze: user,
  );
  final Transaction wipe = factory.createTransactionForWiping(
    sender: manager,
    tokenIdentifier: fungible,
    addressToWipe: user,
  );
  final Transaction transferOwnership = factory
      .createTransactionForTransferringOwnership(
        sender: manager,
        tokenIdentifier: fungible,
        newOwner: user,
      );
  final Transaction control = factory
      .createTransactionForControllingProperties(
        sender: manager,
        tokenIdentifier: fungible,
        properties: const TokenProperties(canPause: true, canUpgrade: true),
      );

  for (final Transaction tx in <Transaction>[
    setFungibleRoles,
    unsetFungibleRoles,
    setNftRoles,
    pause,
    unpause,
    freeze,
    unfreeze,
    wipe,
    transferOwnership,
    control,
  ]) {
    assert(tx.receiver.hex == esdtContractAddressHex, 'system contract');
  }
}
```

---

## 6. NFT lifecycle

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';

/// NFT lifecycle through the factory. Every one of these is a built-in
/// function addressed to the sender.
void main() {
  final TokenManagementTransactionsFactory factory =
      TokenManagementTransactionsFactory(
        config: const TokenManagementConfig(chainId: ChainId('D')),
      );
  final Address creator = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  const String collection = 'NFTC-123456';
  final Uint8List attributes = Uint8List.fromList(
    utf8.encode('tags:rare;set:1'),
  );

  final Transaction create = factory.createTransactionForCreatingNft(
    sender: creator,
    tokenIdentifier: collection,
    initialQuantity: BigInt.one,
    name: 'Sword #1',
    royalties: 750,
    hash: 'abba',
    attributes: attributes,
    uris: const <String>['https://example.com/1.png'],
  );

  final Transaction addQuantity = factory.createTransactionForAddingQuantity(
    sender: creator,
    tokenIdentifier: collection,
    nonce: 1,
    quantityToAdd: BigInt.from(5),
  );

  final Transaction burn = factory.createTransactionForBurningQuantity(
    sender: creator,
    tokenIdentifier: collection,
    nonce: 1,
    quantityToBurn: BigInt.from(2),
  );

  final Transaction updateAttributes = factory
      .createTransactionForUpdatingAttributes(
        sender: creator,
        tokenIdentifier: collection,
        nonce: 1,
        attributes: attributes,
      );

  final Transaction addUri = factory.createTransactionForAddingNftUri(
    sender: creator,
    tokenIdentifier: collection,
    nonce: 1,
    uris: const <String>['https://example.com/1-hd.png'],
  );

  final Transaction setUris = factory.createTransactionForSettingNewUris(
    sender: creator,
    tokenIdentifier: collection,
    nonce: 1,
    newUris: const <String>['https://example.com/only.png'],
  );

  final Transaction royalties = factory.createTransactionForModifyingRoyalties(
    sender: creator,
    tokenIdentifier: collection,
    nonce: 1,
    newRoyalties: 250,
  );

  final Transaction modifyCreator = factory
      .createTransactionForModifyingCreator(
        sender: creator,
        tokenIdentifier: collection,
        nonce: 1,
      );

  final Transaction metadataUpdate = factory
      .createTransactionForUpdatingMetadata(
        sender: creator,
        tokenIdentifier: collection,
        nonce: 1,
        newName: 'Sword #1 (v2)',
        newRoyalties: 250,
        newHash: 'abba',
        newAttributes: attributes,
        newUris: const <String>['https://example.com/v2.png'],
      );

  final Transaction metadataRecreate = factory
      .createTransactionForRecreatingMetadata(
        sender: creator,
        tokenIdentifier: collection,
        nonce: 1,
        newName: 'Sword #1 (v3)',
        newRoyalties: 250,
        newHash: 'abba',
        newAttributes: attributes,
        newUris: const <String>['https://example.com/v3.png'],
      );

  final Transaction nftUpdate = factory.createTransactionForNftUpdate(
    sender: creator,
    tokenIdentifier: collection,
    nonce: 1,
    newName: 'Sword #1 (v4)',
    newRoyalties: 250,
  );

  final Transaction nftRecreate = factory.createTransactionForNftRecreate(
    sender: creator,
    tokenIdentifier: collection,
    nonce: 1,
    newName: 'Sword #1 (v5)',
    newRoyalties: 250,
  );

  for (final Transaction tx in <Transaction>[
    create,
    addQuantity,
    burn,
    updateAttributes,
    addUri,
    setUris,
    royalties,
    modifyCreator,
    metadataUpdate,
    metadataRecreate,
    nftUpdate,
    nftRecreate,
  ]) {
    assert(tx.receiver.bech32 == creator.bech32, 'built-in function');
  }
}
```

Four builders share one payload shape (`token@nonce@name@royalties@hash@attributes@uris…`)
and differ only in the function name and the gas budget:

| Builder | Function | Execution gas field |
| --- | --- | --- |
| `createTransactionForUpdatingMetadata` | `ESDTMetaDataUpdate` | `gasLimitEsdtMetadataUpdate` |
| `createTransactionForRecreatingMetadata` | `ESDTMetaDataRecreate` | `gasLimitNftMetadataRecreate` |
| `createTransactionForNftUpdate` | `ESDTNFTUpdate` | `gasLimitEsdtMetadataUpdate` |
| `createTransactionForNftRecreate` | `ESDTNFTRecreate` | `gasLimitNftMetadataRecreate` |

---

## 7. Token identifier types

`lib/src/core/tokens/token.dart`.

| Symbol | Shape | Notes |
| --- | --- | --- |
| `const String egldIdentifier` | `'EGLD-000000'` | `:10`. The native sentinel used in multi-transfer payloads. The bare 4-byte `EGLD` short form is **not** a valid identifier there. |
| `TokenIdentifier(String value)` | const, unvalidated | `:21` |
| `TokenIdentifier.parse(String value)` | throws `ValidationException` on empty | `:27-37` |
| `TokenIdentifier.value` / `.isEgld` | `String` / `bool` | `:40`, `:43` |
| `EgldOrEsdtTokenIdentifier(String value)` | extends `TokenIdentifier` | `:63` |
| `EgldOrEsdtTokenIdentifier.egld()` | yields `EGLD-000000` | `:66` |
| `EgldOrEsdtTokenIdentifier.parse(String value)` | canonicalises `''` **and** `'EGLD'` to `EGLD-000000` | `:71-76` |
| `Token({required String identifier, BigInt? nonce})` | nonce defaults to zero; negative throws `ValidationException` | `:85-95` |
| `EsdtTokenPayment({required TokenIdentifier tokenIdentifier, BigInt? tokenNonce, required BigInt amount})` | negative nonce/amount throw | `:123-144` |
| `EgldOrEsdtTokenPayment.egld(BigInt amount)` | EGLD payment | `:211` |
| `TokenComputer()` | `isFungible`, `computeExtendedIdentifier`, `extractNonceFromExtendedIdentifier`, `extractIdentifierFromExtendedIdentifier`, `extractTickerFromExtendedIdentifier` | `lib/src/core/tokens/token_computer.dart` |

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// Token identifier types and the native EGLD sentinel.
void main() {
  const TokenIdentifier esdt = TokenIdentifier('ALPHA-abcdef');
  final TokenIdentifier validated = TokenIdentifier.parse('ALPHA-abcdef');
  assert(esdt == validated, 'value equality');
  assert(!esdt.isEgld, 'not the native token');

  final EgldOrEsdtTokenIdentifier native = EgldOrEsdtTokenIdentifier.egld();
  assert(native.value == egldIdentifier, 'EGLD-000000');
  assert(EgldOrEsdtTokenIdentifier.parse('EGLD').isEgld, 'short form');
  assert(EgldOrEsdtTokenIdentifier.parse('').isEgld, 'empty form');

  final Token fungible = Token(identifier: 'ALPHA-abcdef');
  final Token nft = Token(
    identifier: 'NFTC-123456',
    nonce: BigInt.from(7),
  );
  assert(fungible.nonce == BigInt.zero, 'fungible nonce');

  const TokenComputer computer = TokenComputer();
  assert(computer.isFungible(fungible), 'fungible');
  assert(
    computer.computeExtendedIdentifier(nft) == 'NFTC-123456-07',
    'extended identifier',
  );

  final EsdtTokenPayment payment = EsdtTokenPayment(
    tokenIdentifier: esdt,
    amount: BigInt.from(1000),
  );
  final EgldOrEsdtTokenPayment egldPayment = EgldOrEsdtTokenPayment.egld(
    BigInt.from(1),
  );
  assert(payment.tokenNonce == BigInt.zero, 'default nonce');
  assert(egldPayment.isEgld, 'EGLD payment');
}
```

---

## 8. Controller layer

`TokenManagementController({required ChainId chainId, IGasLimitEstimator? gasLimitEstimator})`
(`lib/src/core/transaction/controllers/token_management_controller.dart:26`).
It exposes `factory` (the `TokenManagementTransactionsFactory`) and wraps each
builder as:

```
Future<Transaction> method(IAccount sender, Nonce nonce, <XxxInput> options,
                           BaseControllerInput baseOptions)
```

— four **positional** arguments, in that order. It sets the nonce, applies
`baseOptions` and signs.

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// Controller path: builds, sets the nonce and signs in one call.
Future<Transaction> issueWithController(IAccount sender, Nonce nonce) async {
  final TokenManagementController controller = TokenManagementController(
    chainId: const ChainId('D'),
  );

  return controller.createTransactionForIssuingFungible(
    sender,
    nonce,
    IssueFungibleInput(
      tokenName: 'AlphaCoin',
      tokenTicker: 'ALPHA',
      initialSupply: BigInt.from(1000000),
      numDecimals: BigInt.from(18),
      canFreeze: true,
      canUpgrade: true,
      canAddSpecialRoles: true,
    ),
    const BaseControllerInput(),
  );
}

/// Role helper inputs are boolean flags; the controller turns them into the
/// role-name strings the system contract expects.
Future<Transaction> grantMintRole(
  IAccount sender,
  Nonce nonce,
  Address user,
) async {
  final TokenManagementController controller = TokenManagementController(
    chainId: const ChainId('D'),
  );

  return controller.createTransactionForSettingSpecialRoleOnFungibleToken(
    sender,
    nonce,
    FungibleSpecialRoleInput(
      user: user,
      tokenIdentifier: 'ALPHA-abcdef',
      addRoleLocalMint: true,
      addRoleLocalBurn: true,
    ),
    const BaseControllerInput(),
  );
}
```

Controller traps to know about:

- `IssueInput.canUpgrade` defaults to **`false`**
  (`…/token_management_resources.dart:44`), while `TokenProperties.canUpgrade`
  defaults to **`true`** (`…/token_management_transactions_factory.dart:137`).
  The same "default" issue call produces different tokens through the two layers.
  Set the flag explicitly.
- `IssueFungibleInput` has no `canTransferNFTCreateRole` field at all — correct,
  see §4.
- `createTransactionForLocalMinting`, `createTransactionForLocalBurning` and
  `createTransactionForWiping` never forward a token nonce (`:419-423`,
  `:435-439`, `:564-568`), so they always build the fungible form. Use the
  factory directly for SFT/META nonces.
- The controller has **no** wrapper for `controlChanges`, `transferOwnership`,
  `transferNFTCreateRole`, `stopNFTCreate`, `ESDTNFTAddURI`, `ESDTNFTUpdate`,
  `ESDTNFTRecreate`, `changeSFTToMetaESDT`, `updateTokenID` or
  `registerAndSetAllRolesDynamic`. Use `controller.factory` or the factory
  directly, then sign yourself.
- Four role inputs declare extra `bool?` flags, and the spellings differ per
  class — check the declaration before you type one:
  `SpecialRoleInput` / `UnsetSpecialRoleInput` have
  `addRoleESDTModifyCreator`, `addRoleNFTRecreate`, `addRoleESDTSetNewURI`,
  `addRoleESDTModifyRoyalties` (`…/token_management_resources.dart:281-284`,
  `:309-312`); `SemiFungibleSpecialRoleInput` /
  `UnsetSemiFungibleSpecialRoleInput` have `addRoleNFTUpdate`,
  `addRoleESDTModifyRoyalties`, `addRoleESDTSetNewUri` (lower-case `ri`, unlike
  the non-fungible pair), `addRoleESDTModifyCreator`, `addRoleNFTRecreate`
  (`:224-228`, `:252-256`) — plus the `remove…` twins on the unset variants.
  The controller's role builders never read any of them
  (`…/token_management_controller.dart:50-71`, `:266-270`, `:291-294`,
  `:314-318`, `:338-341`), so setting them emits nothing. Pass the role strings
  through the factory instead.

---

## 9. Reading the outcome

Parse the result with `TokenManagementOutcomeParser` — and note that
cross-account operations report their events on the transaction's
**smart-contract results**, not on its own logs. See `skills/09-events-and-parsers.md`.

---

## Not verified

- The exact role-name strings for the newer NFT roles (update / recreate /
  set-URI / modify-creator / modify-royalties). No such literal exists in
  `lib/`; the SDK only forwards whatever strings you pass to `roles`.
- Whether the chain accepts `registerAndSetAllRoles` with `tokenType: 'FNG'` and
  a non-zero `decimals` — only the client-side argument list was verified.
- The chain-side rationale for the two fixed argument shapes above. The source's
  doc comments state that the system contract rejects `registerAndSetAllRoles`
  with any argument count other than four
  (`…/token_management_transactions_factory.dart:298-301`) and that it reads
  everything past a dynamic registration's token type as property pairs, so an
  odd count fails (`:908-911`, `:1057-1060`). Only the emitted argument lists
  were checked here; the node's acceptance was not.
- Live behaviour of any endpoint against a running network. Everything above was
  verified against the builders' output (payload, receiver, value, gas) and the
  repository's pinning tests, not against a node.
