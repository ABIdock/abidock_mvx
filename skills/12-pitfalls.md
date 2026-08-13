---
name: pitfalls
title: Pitfalls
summary: The API rules and protocol realities in abidock_mvx 3.1.0 that compile but do not do what a newcomer expects, each with the verified correct usage.
reads: [skills/10-errors-and-exceptions.md, skills/11-supernova-and-timestamps.md]
verified_against: abidock_mvx 3.1.0 (Dart 3.13)
---

## When to use this

Read before you write. Every entry is a mistake that compiles, or a rule of the
chain or of this API that you have to know to get the right answer.

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
```

---

## 1. Removed in 3.0.0 — never write these

Each name below **does not exist** in `lib/`. Verified by exhaustive search of
`lib/**/*.dart`: zero occurrences of each, except `relayedVersion`, which
exists with a different type than older material claims.

| Do not write | Write instead |
|---|---|
| `SignableMessage` | `Message` (`lib/src/core/message/base.dart:39`) + `MessageComputer.computeBytesForSigning` (`lib/src/core/message/message_computer.dart:52`) |
| `ValidatorSigner(secretKey)`, `ValidatorSigner.fromPem` | `ValidatorSigner.custom(ValidatorSignFunction signFn)` — the **only** constructor (`lib/src/wallet/validator_signer.dart:37`); `typedef ValidatorSignFunction = Uint8List Function(Uint8List message)` (`:17`) |
| `TransactionStatus.recalled`, `isRecalled` | Nothing — the package treats `'recalled'` as a non-terminal string: `TransactionStatus('recalled').isFinal` is `false` (pinned by `test/core/transaction/transaction_status_supernova_test.dart:245-248`). Use `isFinal` / `isCompleted` / `isNotExecutableInBlock` |
| `NetworkConfig.gasPriceModifierString` | `NetworkConfig.gasPriceModifier`, a `double` (`lib/src/infrastructure/network/network_config.dart:131`, default `0.01`) |
| `functionCallHexParts` on the multisig builders | `functionCall: <TypedValue>[...]` (`lib/src/core/transaction/factories/multisig_transactions_factory.dart:251,285,319`) |
| `RelayedTransactionsFactory.createRelayedTransaction` | `applyRelayer`, then sign (`lib/src/core/transaction/factories/relayed_transactions_factory.dart`) |
| `createTransactionForDelegatingVote` | Nothing — the governance factory exposes `createTransactionForVoting` (`governance_transactions_factory.dart:149`); vote delegation is callable only by a contract |
| `createTransactionForUnsettingBurnRoleForAll` | `createTransactionForUnsettingBurnRoleGlobally` (`token_management_transactions_factory.dart:356`) |
| `Transaction.innerTransactions` | Nothing — the field is not part of the transaction format. Use `relayer` + `relayerSignature` |

**`relayedVersion` is `String?`, not an enum or an int.** It lives on
`TransactionOnNetwork`, is read from the API, and holds `'v1'`, `'v2'` or
`'v3'` — `null` for anything the API does not classify as relayed
(`lib/src/core/transaction/transaction_on_network.dart:659`, parsed at `:317`
and `:493`).

---

## 2. ESDT built-in functions go to the SENDER

The receiver depends on **which kind of call** it is, and the factory already
gets it right — do not override `receiver`.

| Kind | Receiver | Example function names |
|---|---|---|
| ESDT **system-contract endpoint** | The ESDT system contract | `issue`, `issueSemiFungible`, `issueNonFungible`, `registerMetaESDT`, `registerAndSetAllRoles`, `setBurnRoleGlobally`, `unsetBurnRoleGlobally`, `setSpecialRole`, `unSetSpecialRole`, `pause`, `unPause`, `freeze`, `unFreeze`, `wipe`, `changeToDynamic`, `registerDynamic`, `transferOwnership`, `controlChanges`, `stopNFTCreate`, `transferNFTCreateRole`, `registerAndSetAllRolesDynamic`, `changeSFTToMetaESDT`, `updateTokenID` |
| **Built-in function** | The **sender's own address** | `ESDTNFTCreate`, `ESDTLocalMint`, `ESDTLocalBurn`, `ESDTNFTUpdateAttributes`, `ESDTNFTAddQuantity`, `ESDTNFTBurn`, `ESDTModifyRoyalties`, `ESDTSetNewURIs`, `ESDTModifyCreator`, `ESDTNFTUpdate`, `ESDTNFTRecreate`, `ESDTMetaDataUpdate`, `ESDTMetaDataRecreate`, `ESDTNFTAddURI` |

The split is one flag, `receiverIsSender`, applied in `_buildTransaction`:
`receiver: receiverIsSender ? sender : _esdtContractAddress`
(`token_management_transactions_factory.dart:1259`). The ESDT contract address
is pinned at `:10` and decodes to
`erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u`.

Runtime-verified: `createTransactionForLocalMint(...).receiver == sender`;
`createTransactionForFreezing(...).receiver` is the ESDT contract.

The same rule holds for transfers
(`transfer_transactions_factory.dart:355,366-410`):
`ESDTTransfer` (fungible, non-EGLD) is addressed to the real receiver, while
`ESDTNFTTransfer` and `MultiESDTNFTTransfer` are addressed to the **sender**,
with the destination encoded as an argument.

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// The receiver split, made explicit. The factory already applies it —
/// never override the receiver yourself.
void receiverSplit(
  TokenManagementTransactionsFactory factory,
  Address me,
  Address victim,
) {
  /// System-contract endpoint: receiver is the ESDT system contract.
  final Transaction freeze = factory.createTransactionForFreezing(
    sender: me,
    tokenIdentifier: 'FRANK-11ce3e',
    addressToFreeze: victim,
  );

  /// Built-in function: receiver is the SENDER's own account.
  final Transaction mint = factory.createTransactionForLocalMint(
    sender: me,
    tokenIdentifier: 'FRANK-11ce3e',
    supplyToMint: BigInt.from(10),
  );

  print('${freeze.receiver.bech32} / ${mint.receiver.bech32}');
}
```

---

## 3. `unFreeze`, not `UnFreeze`

The factory emits the literal `'unFreeze'`
(`token_management_transactions_factory.dart:648`). Runtime-verified data
payload:

```
unFreeze@4652414e4b2d313163653365@8049d639e5a6980d1cd2392abcce41029cda74a1563523a202f09641cc2618f8
```

The Dart method is `createTransactionForUnfreezing` (lower-case `f` in
`Unfreezing` too) and takes `addressToUnfreeze:` — not `user:`.

The casing is inconsistent across neighbouring endpoints and there is no rule
to derive it from — copy these verbatim from the factory, all confirmed at the
`functionName:` literal: `unFreeze` (`:648`), `unPause` (`:610`),
`unSetSpecialRole` (`:404`) capitalise the second word, while
`unsetBurnRoleGlobally` (`:362`) does not.

---

## 4. Relayed v3 has no inner transactions

A relayed-v3 transaction is a **single, flat transaction**: the user's own
transaction with `relayer` set and co-signed by that relayer. There is no outer
wrapper and no inner-transaction bundle
(`relayed_transactions_factory.dart:1-6`). `Transaction` carries exactly two
extra fields: `Address? relayer` and `Signature relayerSignature`
(`lib/src/core/transaction/transaction.dart:154-155`), emitted as `relayer`
and `relayerSignature` in the payload
(`lib/src/core/transaction/transaction_computer.dart:237-254`).

Order of operations is not optional: `applyRelayer` **must** run before anyone
signs, because `relayer` is part of the signed payload. `applyRelayer` throws
`ArgumentError` if any signature is already present, if the chain ids differ,
if the relayer equals the guardian, or if relayer and sender are in different
shards; it throws `StateError` if a *different* relayer is already set
(`relayed_transactions_factory.dart:87` onward).

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// Relayed v3 is one flat transaction: `relayer` + `relayerSignature` on the
/// user's own transaction. There is no inner-transaction bundle.
Future<Transaction> relayV3(
  RelayedTransactionsFactory factory,
  Transaction unsigned,
  Address relayerAddress,
  UserSigner sender,
  UserSigner relayer,
) async {
  final Transaction prepared = factory.applyRelayer(unsigned, relayerAddress);
  final Transaction signed = await prepared.signWith(sender);
  return signed.signAsRelayer(relayer);
}
```

Re-applying the **same** relayer is idempotent for gas — the base cost is not
charged twice (`:151-155`).

---

## 5. `BigFloat` has no wire codec

`BigFloatType` exists only so an ABI that *mentions* `BigFloat` still loads.
Codegen maps it to Dart `double` (`bin/codegen/core/type_mapper.dart:11`), but
there is no encoder and no decoder.

| Call | Result | Verified |
|---|---|---|
| `BigFloatValue(1.5).toBytes()` | throws `UnimplementedError` | runtime; `lib/src/abi/types/primitives/big_float.dart:86` |
| `BinaryCodec.withDefaults().encodeTopLevel(BigFloatValue(1.5))` | throws `AbiBinaryCodecException` | runtime; `test/abi/types/primitives/big_float_test.dart:46-51` |
| `codec.decodeTopLevel(bytes, BigFloatType.type)` | throws `AbiBinaryCodecException` | `test/abi/types/primitives/big_float_test.dart:53-61` |

The package documents the reason as an opaque arbitrary-precision-float blob
(version byte, packed mode/accuracy/form/sign byte, precision, exponent,
mantissa words) whose layout is an implementation detail rather than part of
the ABI specification, and therefore not reproducible portably
(`big_float.dart:9-21` — doc comment, not something this repository's code
demonstrates). What *is* demonstrated is the table above: every path throws.
Do not design an interface around a `BigFloat` argument or return value.

---

## 6. Reading a raw `timestamp` as seconds

`TransactionOnNetwork.timestamp` is in **whatever unit the provider reported**,
and the unit differs per route and per epoch
(`transaction_on_network.dart:536-543`). Multiplying it by 1000, or feeding it
to `DateTime.fromMillisecondsSinceEpoch`, mis-dates the transaction by a factor
of 1000 on the other side.

Use `tx.executedAt` (`:566`). Full accessor table and the magnitude rule:
`skills/11-supernova-and-timestamps.md`.

The same applies to `NetworkStatus.blockTimestampMs`: **the `_ms` suffix is
not a guarantee of milliseconds.** `fromApiResponse` reads
`erd_block_timestamp_ms` with a plain `optionalInt` and stores it verbatim —
no unit conversion (`network_status.dart:131-138`). `blockTime` then re-decides
the unit by magnitude rather than trusting the name:
`ChainTimestamp.toDateTime(blockTimestampMs ?? blockTimestamp)`
(`network_status.dart:263`). Use `status.blockTime`.

---

## 7. Outcome parsers need the smart-contract results, not just the logs

Cross-account token operations do not report on the transaction itself.
`freeze`, `unFreeze`, `wipe`, `setSpecialRole`, `unSetSpecialRole` and the
local mint/burn pair are executed by the system contract forwarding a
**built-in call to the target address**. That call runs on the target's shard,
so its events land on the resulting smart-contract result, not on the original
transaction. The parsers are written for exactly that:

| Parser behaviour | Site |
|---|---|
| `TokenManagementOutcomeParser` searches `transaction.logs` **plus** `result.logs` of every entry in `transaction.smartContractResults` — `_allLogs` collects both, `_findEvents` searches the union | `token_management_outcome_parser.dart:1037`, `:1062` |
| `_ensureNoError` scans that same union for `signalError`, and throws `TokenManagementParseException` when logs are entirely absent | `:1081-1104` |
| `SmartContractOutcomeParser.parseExecute` reads `transaction.smartContractResults` first (`:271`), then falls back to `signalError` and `writeLog` events (`:336`) | `smart_contract_outcome_parser.dart:164,243` |
| `SmartContractOutcomeParser.parseDeploy` reads **only** `transaction.logs` (`SCDeploy` and error events) | `smart_contract_outcome_parser.dart:119-152` |

Consequence for you: if you hand a parser a `TransactionOnNetwork` whose
`smartContractResults` is `null`, cross-account outcomes come back **empty**
and a `signalError` that only appears on a result is missed — a failed
transaction reads as a silent success. The field is populated straight from the
response body — `data['results'] ?? data['smartContractResults']` on the API
side (`transaction_on_network.dart:259-263`), `data['smartContractResults']` on
the proxy side (`:435-439`) — so parse a transaction you fetched whole, not one
you rebuilt from a status or a hand-made map. Pinned by
`test/core/transaction/outcome_parsers/token_management_scr_logs_test.dart:1-11`.

---

## 8. A final transaction is not always a completed one

Two predicates, two questions. Both spellings agree with their
`TransactionStatus` counterpart — `TransactionOnNetwork` forwards to it
unchanged.

| Getter | Question it answers | True for | Declared |
|---|---|---|---|
| `tx.isCompleted` → `status.isCompleted` | Did the chain execute this and produce an outcome? | success or failure | `transaction_on_network.dart:703`, `transaction_status.dart:189` |
| `tx.isFinal` → `status.isFinal` | Will the status change again? | success, failure, **or** `not-executable-in-block` | `transaction_on_network.dart:723`, `transaction_status.dart:175` |

`TransactionWatcher.awaitCompleted` stops on `status.isFinal`
(`transaction_watcher.dart:186-195`, predicate at `:192`), which is the right
stop condition for a poll — but it means a returned transaction can be
`not-executable-in-block`: final, not completed, and carrying no logs and no
smart-contract results. Branch on `tx.isNotExecutableInBlock`
(`transaction_on_network.dart:741`) or on `tx.isCompleted` before you parse an
outcome from it.

Runtime-verified: `TransactionStatus('not-executable-in-block').isFinal` is
`true`, `.isCompleted` is `false`. Pinned by
`test/core/transaction/transaction_status_supernova_test.dart:221-243`.

---

## 9. Mutating `tx.data` does nothing

`Uint8List get data => Uint8List.fromList(_data);` — a fresh **copy** on every
read (`transaction.dart:176`). Runtime-verified:
`identical(tx.data, tx.data)` is `false`, and writing into the returned list
leaves the transaction unchanged.

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';

/// `Transaction.data` returns a fresh copy on every read, so mutating it is a
/// no-op. Rebuild through `copyWith(newData: ...)` instead.
Transaction replaceData(Transaction tx, String newPayload) {
  return tx.copyWith(newData: Uint8List.fromList(utf8.encode(newPayload)));
}
```

`copyWith` parameters are all prefixed `new*`: `newNonce`, `newData`,
`newGasLimit`, `newSignature`, `newRelayer`, `newRelayerSignature`, …
(`transaction.dart:221-238`).

---

## 10. Values that have no single-buffer wire form

Calling `toBytes()` on these throws instead of returning bytes. They exist to
be expanded into **separate top-level arguments**, and the serializer does that
for you.

| Value | `toBytes()` throws | Site |
|---|---|---|
| `CompositeValue` | `UnsupportedError` — use `ArgSerializer` to encode the fields as separate arguments | `lib/src/abi/types/special/composite.dart:242` |
| `MultiValueValue` | `UnsupportedError` — each inner value occupies its own top-level buffer | `lib/src/abi/types/special/multi_value.dart:152` |
| `TokenTransferValue` | `UnsupportedError` — use `ArgumentEncoder.encodeForEndpointWithTokens()` | `lib/src/abi/types/special/token_transfer_value.dart:187` |
| `BigFloatValue` | `UnimplementedError` — see §5 | `lib/src/abi/types/primitives/big_float.dart:86` |

Runtime-verified for `CompositeValue.fromFields(<TypedValue>[U32Value(1)])`.

`BigUIntValue` additionally has no bitwise-not: `operator ~` throws
`UnsupportedError` (`lib/src/abi/types/primitives/biguint.dart:383`).

---

## 11. Top-level and nested encodings are different bytes

Not a bug — the ABI encodes numbers differently by position. Runtime-verified
with `BinaryCodec.withDefaults()`:

| Expression | Bytes |
|---|---|
| `codec.encodeNested(U32Value(5))` | `[0, 0, 0, 5]` |
| `codec.encodeTopLevel(U32Value(5))` | `[5]` |
| `codec.encodeTopLevel(U32Value(0))` | `[]` |

Do not compare a nested encoding against a top-level one, and do not expect a
zero argument to occupy a byte on the wire — a top-level zero is the **empty**
buffer. This is why `decimals: 0` produces a bare `@` in an `issue` payload.

---

## 12. The Gateway provider cannot do everything the API can

Four `NetworkProvider` methods compile against a `GatewayNetworkProvider` and
throw `UnsupportedError` unconditionally — the Gateway has no route for them:

| Call that fails on the Gateway | Throwing hook | Use instead |
|---|---|---|
| `getDefinitionOfFungibleToken(identifier)` | `fungibleTokenDefinitionEndpoint` `gateway_network_provider.dart:308`; `parseFungibleTokenDefinition` `:611` | `ApiNetworkProvider.getDefinitionOfFungibleToken` |
| `getDefinitionOfTokenCollection(collection)` | `tokenCollectionDefinitionEndpoint` `:320`; `parseTokenCollectionDefinition` `:621` | `ApiNetworkProvider.getDefinitionOfTokenCollection` |
| `getNonFungibleToken(collection, nonce)` | `nonFungibleInstanceEndpoint` `:330`; `parseNonFungibleInstance` `:632` | `ApiNetworkProvider.getNonFungibleToken` |
| `getNetworkEconomics()` | `:381` | `GatewayNetworkProvider.getGatewayEconomics()` for chain metrics, `ApiNetworkProvider.getNetworkEconomics()` for market data |

`BaseNetworkProvider.estimateTransactionCost` also throws `UnsupportedError`
when `estimateTransactionCostEndpoint()` returns `null`
(`base_network_provider.dart:696`).

---

## 13. A failed contract query raises `NetworkException`

Not `SmartContractException`. When the query returns a non-`ok` return code the
provider throws
`NetworkException('Query failed: <returnMessage> (<returnCode>)')`
(`base_network_provider.dart:814`). Catch `NetworkException` around
`queryContract`, and read the return code out of the message.

---

## 14. A failing gas estimator falls back to the existing gas limit

Estimation is best-effort on both paths, by design — the transaction is still
produced with the gas limit it already had.

| Path | Behaviour on estimator failure | Site |
|---|---|---|
| `BaseFactory.setGasLimit` | catches everything and returns the transaction unchanged, with no log | `lib/src/core/transaction/factories/base_factory.dart:59-77` (`catch (_)` at `:73`) |
| `BaseController.setTransactionGasOptions` | logs a warning (`'Gas estimation failed, using current gas limit'`) and keeps the current limit | `lib/src/core/transaction/controllers/base_controller.dart:375-397` |

An explicit gas limit always wins over the estimator on both paths
(`base_factory.dart:64-65`, `base_controller.dart:369-374`), so pass one when
the value must be exact.

Factory gas without an estimator is
`minGasLimit + gasLimitPerByte * data.length + <execution gas>`
(`token_management_transactions_factory.dart:1254-1262`). Runtime-verified for
a fungible `issue`: 233 data bytes → `50000 + 1500 * 233 + 60000000 =
60399500`, matching `tx.gasLimit.value`. Pinned by
`test/core/transaction/factories/factory_data_movement_gas_test.dart:40`.

---

## 15. A smart-contract call needs a gas limit or an estimator

`SmartContractController.createTransactionForExecute` (and its `withoutAbi`
twin) calls `_requireGasLimitOrEstimator`, which throws `ArgumentError` when
`options.gasLimit` is null **and** the controller was built without a
`gasLimitEstimator` (`smart_contract_controller.dart:693-700`, called at `:571`
and `:653`). Supply one or the other:

- pass `BaseControllerInput(gasLimit: GasLimit(...))`, or
- construct the controller with `gasLimitEstimator:`, and omit `gasLimit` — the
  estimator is then consulted for the call
  (`base_controller.dart:375-397`).

Either way the guarded/relayed allowance is applied afterwards:
`setTransactionGasOptions` ends with `addExtraGasLimitIfRequired`
(`base_controller.dart:405`), which adds **+50 000** when a guardian is set and
another **+50 000** when a relayer is set (`base_controller.dart:18,21`, logic
at `:119-150`). You do not add those yourself.

---

## 16. `TokenProperties.canUpgrade` defaults to `true`

Every other flag defaults to `false`
(`token_management_transactions_factory.dart` `TokenProperties` constructor).
If you pass `const TokenProperties()` you are issuing an **upgradeable** token.

Every supported property is emitted with its literal `true`/`false` value —
properties are never omitted for being false. The fungible `issue` endpoint is
the one exception in the other direction: it omits `canTransferNFTCreateRole`
entirely, because that property belongs to the collection endpoints
(`:1205-1226`; `includeTransferNftCreateRole: false` at `:195`, and `true` at
`:233`, `:258`, `:285`, `:984`).

Runtime-verified `issue` payload for `tokenName: 'FRANK'`,
`tokenTicker: 'FRANK'`, `initialSupply: 100`, `decimals: 0`,
`properties: const TokenProperties()` — verbatim:

```
issue@4652414e4b@4652414e4b@64@@63616e467265657a65@66616c7365@63616e57697065@66616c7365@63616e5061757365@66616c7365@63616e4368616e67654f776e6572@66616c7365@63616e55706772616465@74727565@63616e4164645370656369616c526f6c6573@66616c7365
```

Reading the property pairs back as ASCII: `canFreeze=false`, `canWipe=false`,
`canPause=false`, `canChangeOwner=false`, `canUpgrade=true`,
`canAddSpecialRoles=false`. `canTransferNFTCreateRole` is absent. The `64` is
the supply (100) and the empty part after it is `decimals: 0` — see §11.

---

## 17. `NetworkConfig.roundDuration` is an `int` of milliseconds

Not a `Duration`, not seconds (`network_config.dart:19,107`; parsed from
`erd_round_duration` with fallback `6000` at `:202`). Wrap it as
`Duration(milliseconds: config.roundDuration)` before handing it to
`TransactionAwaitingOptions.roundDuration`, which **is** a `Duration`
(`transaction_watcher.dart:91`).

---

## 18. `watcher.close()` closes the shared provider

`TransactionWatcher.close()` calls `_networkProvider.close()`
(`transaction_watcher.dart:342-344`), and
`NetworkEntrypoint.createTransactionWatcher()` binds the watcher to the
entrypoint's **single cached provider**
(`lib/src/entrypoints/network_entrypoint.dart:102,110,181-182`; same for
`ProxyNetworkEntrypoint` at `:310,318,389-390`). Closing that watcher therefore
kills the HTTP client every other object from that entrypoint is using.

Close the watcher only when you are done with the entrypoint, or build a
watcher over a provider you own.

---

## 19. Not every request failure is a `NetworkException`

Each provider request is raced against `requestTimeout` with `Future.timeout`
(`base_network_provider.dart:762,1108,1204`) while the surrounding handler
catches only `DioException` (`:1154`, `:1251`). A `TimeoutException` from that
race — and from `RetryHelper` when every retry attempt timed out
(`lib/src/infrastructure/resilience/retry_helper.dart:104-124`) — escapes
unwrapped. Catch `TimeoutException` from `dart:async` alongside
`NetworkException`.

---

## 20. An injected `Dio` keeps its own settings

`BaseNetworkProvider` applies `requestTimeout`, the `User-Agent` and header
config **only when it owns the client**
(`base_network_provider.dart:50-67`, `_ownsClient = client == null` at `:60`).
Pass your own `Dio` via `client:` and none of `NetworkProviderConfig`'s
transport settings reach it; the SDK falls back to per-request `Options`.
Likewise `close()` only closes a client the provider created (`:1262-1267`).

When you let the provider own its client — including the providers the
entrypoints build for you — the whole `NetworkProviderConfig` applies:
`clientName`, `headers`, `requestTimeout`, `retryPolicy`, `throttlePolicy` and
`cachePolicy`.

---

## 21. Pure-Dart BLS validator signing is not implemented

`ValidatorSecretKey.sign` throws `UnimplementedError` unconditionally
(`lib/src/wallet/validator_keys.dart:250`). The only working path is
`ValidatorSigner.custom(signFn)` with a signer you supply
(`lib/src/wallet/validator_signer.dart:37`). Do not build a flow that assumes
validator signatures can be produced in-process.

---

## 22. `data` and token transfers are mutually exclusive

`TransferTransactionsFactory.createTransactionForTransfer` builds one of two
shapes and cannot build both at once
(`lib/src/core/transaction/factories/transfer_transactions_factory.dart:263-298`):

| Arguments | Result |
|---|---|
| `tokenTransfers` (with or without `nativeAmount`) | An ESDT transfer — `ESDTTransfer`, `ESDTNFTTransfer` or `MultiESDTNFTTransfer` (`:288-297`) |
| `nativeAmount` and/or non-empty `data`, no transfers | A native EGLD transfer carrying your payload (`:278-286`) |
| non-empty `data` **and** `tokenTransfers` | `ArgumentError('Cannot set data field when sending ESDT tokens')` (`:275-277`) |

An empty `data` is normalised to "no data" before either test —
`final Uint8List? payload = (data == null || data.isEmpty) ? null : data;`
(`:273`) — so `data: Uint8List(0)` alongside token transfers is treated exactly
like omitting `data`, and the token transfer is built. Put the payload in a
contract call instead when you need both.

---

## 23. Pick the `Balance` constructor that matches the input you hold

Both are exact; they differ in what they accept.

| Constructor | Takes | Notes |
|---|---|---|
| `Balance.fromEgldString('0.1')` | a `String` | Parses the digits directly (`lib/src/core/balance.dart:97-125`). More than 18 decimal places are **truncated**. Throws `FormatException` on an empty string or a second `.` |
| `Balance.fromEgld(0.1)` | a `num` | Converts the literal you wrote to attoEGLD exactly — `Balance.fromEgld(0.1).value` is `100000000000000000` (`:159-173`, conversion at `:318-361`). Throws `ArgumentError` for a non-finite value, or for one needing more than 18 decimal places |
| `Balance(BigInt.parse('100000000000000000'))` | attoEGLD | The raw wire value, no scaling |

The one thing a `num` cannot do is carry a value that Dart never computed:
`0.1 + 0.2` evaluates to the double `0.30000000000000004` *before* the factory
sees it, so that is the amount you get. Take amounts from a string when they
arrive as text (user input, JSON, config) and use `fromEgld` when you are
writing the number in source.

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// Three ways to state 0.1 EGLD. All three produce the same attoEGLD value.
void amounts() {
  final Balance fromLiteral = Balance.fromEgld(0.1);
  final Balance fromText = Balance.fromEgldString('0.1');
  final Balance fromAtto = Balance(BigInt.parse('100000000000000000'));

  print(fromLiteral.value == fromText.value); /// true
  print(fromText.value == fromAtto.value); /// true

  /// Sum the amounts, not the doubles.
  final Balance total = fromLiteral + fromText;
  print(total.toDenominatedTrimmed); /// 0.2
}
```

---

## Not verified

- Whether the chain currently rejects any of the removed API shapes at the
  node; the claims above are verified only against this package's source, which
  no longer contains them.
- The exact list of statuses each public host returns, and the wire behaviour
  of `relayedVersion` on non-API hosts.
- Runtime behaviour of §12's Gateway gaps against a live Gateway; verified only
  from the unconditional `throw UnsupportedError` in the source.
- §19's race outcome in practice: Dio's own connect/receive/send timeouts are
  configured with the same duration as the outer `Future.timeout`
  (`_applyConfigToDio`, `base_network_provider.dart:215-219`), so which one
  fires first is timing-dependent.
- §5's account of how `BigFloat` is laid out on the wire, and the per-route
  timestamp units described in
  `skills/11-supernova-and-timestamps.md`. Both appear in this package only as
  doc comments.
