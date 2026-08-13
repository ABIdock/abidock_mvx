---
name: smart-contracts
title: Smart Contract Calls and Queries
summary: Load a contract ABI, query a view, sign and broadcast an endpoint call (with or without token payments), deploy or upgrade a contract, and decode the outcome — using the real abidock_mvx symbol names.
reads: [05-abi-types-and-codecs.md, 03-transactions.md]
verified_against: abidock_mvx 3.1.0 (Dart 3.13)
---

**When to use this**: you have a MultiversX smart contract address and need to read from it, call an endpoint, or deploy/upgrade it.

Imports used by the snippets below:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
```

The package export does **not** re-export `dart:typed_data`, so `Uint8List` needs its own import (verified). `dart:io` is only needed for the `File` read in §1.

For the meaning of each ABI type name and its exact wire bytes, read `05-abi-types-and-codecs.md`.

---

## 1. Load the ABI

The ABI is the JSON file the contract build emits (conventionally `<name>.abi.json`; the bundled `abidock` CLI takes the same file, e.g. `abidock generate assets/pair.abi.json ...`, `bin/abidock.dart:26`). There is **no** loader that takes a file path — you read the file yourself and hand over the string.

| Symbol | Signature | Source |
|---|---|---|
| `SmartContractAbi.fromJson` | `factory SmartContractAbi.fromJson(String jsonString, {AbiTypeFactory? typeFactory})` | `lib/src/abi/abi.dart:114` |
| `SmartContractAbi.fromMap` | `factory SmartContractAbi.fromMap(Map<String, dynamic> data, {AbiTypeFactory? typeFactory})` | `lib/src/abi/abi.dart:134` |
| `SmartContractAbi.empty` | `const SmartContractAbi.empty({String name = '', String version = '1.0'})` | `lib/src/abi/abi.dart:97` |

```dart
Future<SmartContractAbi> loadAbi() async {
  final String json = await File('assets/pair.abi.json').readAsString();
  final SmartContractAbi abi = SmartContractAbi.fromJson(json);
  print('${abi.name} v${abi.version} — ${abi.endpointCount} endpoints');
  return abi;
}
```

`fromJson` wraps **every** failure — malformed JSON *and* a structurally invalid ABI — in `FormatException` (`lib/src/abi/abi.dart:124`). Do not write `on ArgumentError` around it.

Useful members of `SmartContractAbi` (all `lib/src/abi/abi.dart`): `name`, `version`, `constructor`, `upgradeConstructor`, `endpoints`, `events`, `types`, `metadata` (:388-409); `viewEndpoints`, `mutableEndpoints`, `payableEndpoints`, `endpointCount`, `customTypeCount` (:438-488); `getEndpoint(SmartContractFunction)`, `hasEndpoint(SmartContractFunction)` (:412, :417); `getCustomType(String)`, `getEnum(String)`, `getStruct(String)` (:456-480).

`getEndpoint`/`hasEndpoint` on the ABI take a `SmartContractFunction`, **not** a `String`. `abi.endpoints.getByName('x')` takes a `String` and returns `AbiEndpoint?`.

---

## 2. `SmartContractController` — the two constructors

`lib/src/abi/smart_contract/controller/smart_contract_controller.dart:73`, `final class SmartContractController extends BaseController`.

| Constructor | Parameters | Source |
|---|---|---|
| `SmartContractController({...})` | `required Address contractAddress`, `required NetworkProvider networkProvider`, `required SmartContractAbi abi`, `IGasLimitEstimator? gasLimitEstimator`, `Logger? logger` | :81 |
| `SmartContractController.withoutAbi({...})` | `required Address contractAddress`, `required NetworkProvider networkProvider`, `IGasLimitEstimator? gasLimitEstimator`, `Logger? logger` | :146 |

`SmartContractAddress` is a `typedef` for `Address` (`lib/src/abi/core/core_types.dart:9`) — pass a plain `Address.fromBech32(...)`.

Method availability by constructor:

| Method | With ABI | `withoutAbi` |
|---|---|---|
| `query` | yes | throws `StateError` |
| `call` | yes | works, but behaves exactly like `callRaw` — its body is identical (`:587` vs `:667`), so arguments must be `TypedValue`/`Uint8List`. Prefer `callRaw` for clarity. |
| `queryRaw` / `callRaw` | yes | yes |
| `parseQueryResponse`, `hasEndpoint`, `getEndpoint`, `getViewEndpoints`, `getMutableEndpoints` | yes | throws `StateError` (`_requireAbiForEndpoints`, :1094) |
| `queryEvents`, `queryEventsBatch`, `getEventHistory`, `watchTransaction`, `streamEvents`, `streamAllEvents`, `getAllEventDefinitions`, `getEventDefinition`, `hasEvent` | yes | throws `StateError` (`_requireAbiForEvents`, :1083) |
| `createTransactionForDeploy`, `createTransactionForUpgrade`, `parseDeploy`, `parseExecute`, `awaitCompletedDeploy`, `awaitCompletedExecute` | yes | yes |
| `abi` getter | returns the ABI | throws `StateError` (:179) |
| `hasAbi` getter | `true` | `false` |

---

## 3. Query — read-only

```
Future<QueryResult> query({
  required String endpointName,
  List<dynamic> arguments = const <dynamic>[],
  Address? caller,
  Balance? value,
})
```
(`:452`)

```dart
Future<void> queryExample(SmartContractAbi abi) async {
  final ApiNetworkProvider provider = ApiNetworkProvider.devnet();
  final SmartContractController controller = SmartContractController(
    contractAddress: Address.fromBech32(
      'erd1qqqqqqqqqqqqqpgq09vq93grfqy7x5fhgmh44ncqfp3xaw57ys5s7j9fed',
    ),
    networkProvider: provider,
    abi: abi,
  );

  final QueryResult result = await controller.query(
    endpointName: 'getReservesAndTotalSupply',
    arguments: <dynamic>[],
  );

  final BigInt reserve0 = result.values[0] as BigInt;
  final TypedValue typed = result.typedValues[0];
  print('$reserve0 as ${typed.type.name}; success=${result.isSuccess}');
  provider.close();
}
```

`query` only requires that the endpoint **exists** in the ABI (`SmartContractQueryInput.fromAbi`, `lib/src/abi/smart_contract/query/query.dart:155` — throws `EndpointNotFoundException` otherwise). Unlike `call`, it applies **no** `isView` guard, so a mutable endpoint name is accepted by this SDK and forwarded to the node.

A non-`ok` return code from the node raises `SmartContractQueryException` before any parsing (`smart_contract_query_runner.dart:385-396`) — a failed query never comes back as a `QueryResult` with `isSuccess == false`.

---

## 4. Reading query results

`QueryResult` — `lib/src/abi/smart_contract/query/smart_contract_query_runner.dart:31`.

| Member | Type | Source |
|---|---|---|
| `values` | `List<dynamic>` — the decoded **native** values | :47 |
| `typedValues` | `List<TypedValue>` — same values with ABI type metadata | :53 |
| `rawData` | `List<String>` — the **base64** parts exactly as the node returned them | :58 |
| `returnCode` | `ReturnCode` | :61 |
| `isSuccess` | `bool` | :64 |
| `isEmpty` | `bool` | :67 |
| `first` | `dynamic` — first value, or `null` when empty | :77 |
| `operator [](int)` | `dynamic` | :89 |
| `length` | `int` | :92 |

`values[i]` is `typedValues[i].nativeValue`. The mapping from ABI type to Dart runtime type is **not** uniform — cast accordingly:

| ABI output type | `values[i]` runtime type | `nativeValue` source |
|---|---|---|
| `u8` `u16` `u32` `i8` `i16` `i32` | `int` | `lib/src/abi/types/primitives/numerical.dart:204` |
| `u64` `i64` `BigUint` `BigInt` `u128` `i128` | `BigInt` | `numerical.dart:340` |
| `ManagedDecimal<N>` | `BigInt` (the mantissa; the scale lives on the type/value) | `lib/src/abi/types/special/managed_decimal.dart:381` |
| `bool` | `bool` | `boolean.dart:129` |
| `string` / `utf-8 string` | `String` | `string.dart:120` |
| `Address` | **`String`** (bech32) | `address.dart:198` |
| `TokenIdentifier` / `EgldOrEsdtTokenIdentifier` | `String` | `token_identifier.dart:184`, `:386` |
| `bytes` / `H256` / `ManagedByteArray<N>` | `Uint8List` | `bytes.dart:138`, `h256.dart:161`, `managed_byte_array.dart:137` |
| struct | `Map<String, dynamic>` keyed by field name | `struct.dart:221` |
| `List<T>` / `Array<T,N>` / tuple / `MultiArg<...>` | `List<dynamic>` | `list.dart:150`, `array.dart:183`, `tuple.dart:188`, `composite.dart:223` |
| enum, unit variant | `String` (variant name) | `enum.dart:443` |
| enum, variant with fields | `Map<String, Object>`: `{'variant': name, 'fields': [...]}` | `enum.dart:443` |
| explicit-enum | `String` (variant name) | `explicit_enum.dart:349` |
| `Option<T>` / `optional<T>` | the inner native value, or `null` | `option.dart:152`, `optional.dart:158` |
| `variadic<T>` | **`List<TypedValue>`**, not natives — map `.nativeValue` yourself | `variadic.dart:232` |
| `Nothing` | `null` | `nothing.dart:106` |
| `BigFloat` | `double` (local only, never off the wire — see §11) | `big_float.dart:72` |

Do **not** trust the older prose that says `Address` decodes to an `Address` object or that `u32` decodes to `BigInt` — the declarations above are authoritative. (The doc comment on `QueryResult.values`, `smart_contract_query_runner.dart:42-44`, is exactly that stale prose: it claims `u32 → BigInt` and `Address → Address`. Both are wrong.)

An output declared `multi<...>` / `MultiValue2<...>` cannot be read back at all. `ResponseParser` decodes one return-data part per declared output with `decodeTopLevel` (`response_parser.dart:92-110`), and `decodeTopLevel` always throws for a `MultiValueType`: two parts give `ResponseParsingException: Return data count mismatch: expected 1, got 2`, one concatenated part gives `ResponseParsingException: Failed to decode value at index 0 to multi<…>`. Both were reproduced. A `MultiArg<...>` output does work, because the whole composite lives in one part.

To decode a response you fetched yourself, use `parseQueryResponse` (`:368`):

```
List<dynamic> parseQueryResponse({
  required SmartContractQueryResponse response,
  required String endpointName,
})
```

---

## 5. Call — state-changing

```
Future<Transaction> call({
  required IAccount account,
  required Nonce nonce,
  required String endpointName,
  List<dynamic> arguments = const <dynamic>[],
  required BaseControllerInput options,
  List<TokenTransferValue> tokenTransfers = const <TokenTransferValue>[],
  Balance? value,
})
```
(`:562`)

The returned `Transaction` is **already signed** (`setupAndSignTransaction`, `lib/src/core/transaction/controllers/base_controller.dart:181-226`). You broadcast it; you do not sign it again.

```dart
Future<String> callExample(
  SmartContractAbi abi,
  IAccount account,
) async {
  final ApiNetworkProvider provider = ApiNetworkProvider.devnet();
  final SmartContractController controller = SmartContractController(
    contractAddress: Address.fromBech32(
      'erd1qqqqqqqqqqqqqpgq09vq93grfqy7x5fhgmh44ncqfp3xaw57ys5s7j9fed',
    ),
    networkProvider: provider,
    abi: abi,
  );

  final AccountOnNetwork onNetwork = await provider.getAccount(account.address);

  final Transaction signed = await controller.call(
    account: account,
    nonce: onNetwork.nonce,
    endpointName: 'setLpTokenIdentifier',
    arguments: <dynamic>['LPTOK-abcdef'],
    options: const BaseControllerInput(gasLimit: GasLimit(10000000)),
  );

  final String txHash = await provider.sendTransaction(signed);
  provider.close();
  return txHash;
}
```

`BaseControllerInput` — `lib/src/core/transaction/controllers/base_controller.dart:35`:

| Field | Type | Meaning |
|---|---|---|
| `guardian` | `Address?` | co-signer for a guarded account |
| `relayer` | `Address?` | relayer address (flat relayed-v3 field on the same transaction) |
| `gasPrice` | `GasPrice?` | override |
| `gasLimit` | `GasLimit?` | the **execution** budget; required unless the controller carries a `gasLimitEstimator` |

### How the gas limit is resolved

`setTransactionGasOptions` (`lib/src/core/transaction/controllers/base_controller.dart:343-406`) settles the execution budget first, then adds the guarded/relayed allowances on top of whatever it settled on:

1. `options.gasLimit` wins when you pass one (`:369-374`).
2. Otherwise the controller's `IGasLimitEstimator` is consulted (`:375-388`). A throwing estimator is logged and the draft limit is kept — for a call that draft is `GasLimit.forPayload(data:)`, the movement-plus-data cost of the transaction's own payload (`smart_contract_controller.dart:715-725`).
3. `addExtraGasLimitIfRequired` (`:119-150`, called at `:405`) then adds **50 000 gas** for a guardian and **50 000 gas** for a relayer, each counted when the field is set to a non-zero address (`:18-21`, `:123`, `:136`). Both are added when the transaction is guarded *and* relayed.

Step 3 runs on every path, including the one where you pinned `gasLimit` yourself: pass the execution cost and let the allowance be added, rather than budgeting the extra 50 000 into your own number.

`call` and `callRaw` throw a plain `ArgumentError` only when `options.gasLimit` is null **and** the controller has no estimator (`_requireGasLimitOrEstimator`, `:693-700`). Supply one or the other.

---

## 6. Passing arguments

### 6.1 With an ABI: native Dart values

Arguments go through `ArgumentEncoder` → `NativeSerializer` (`lib/src/abi/serializers/argument_encoder.dart:276`), which converts each value against the declared parameter type.

| Declared ABI type | Pass |
|---|---|
| `u8` `u16` `u32` `i8` `i16` `i32` | `int`, `BigInt`, or a numeric `String`. A `double` is accepted and **truncated towards zero** — `42.9` encodes as `2a` |
| `u64` `i64` `BigUint` `BigInt` | `BigInt`, `int`, or a numeric `String` (a `double` is also accepted, truncated the same way) |
| `bool` | `bool`, `num` (non-zero = true), or `'true'`/`'1'` |
| `string` | any non-`null` object — `toString()` is applied; `null` throws |
| `bytes` | `Uint8List`, `List<int>`, `'0x…'` hex, or a plain `String` (UTF-8 encoded) |
| `Address` | bech32 `String`, 64-char hex `String`, `'0x…'`, `Uint8List`(32) or `List<int>`(32) |
| `TokenIdentifier` / `EgldOrEsdtTokenIdentifier` | `String` |
| `H256` | hex `String` or `List<int>` |
| `CodeMetadata` | `int` (0–65535) or a 2-element `List<int>` |
| struct | `Map` keyed by **every** declared field name |
| enum | variant-name `String`; discriminant `int` **only when that variant has no fields** — an `int` naming a variant that carries fields throws; or `{'variant': name, 'fields': [...]}` |
| explicit-enum | variant-name `String`, discriminant `int`, or `{'name': …}` / `{'discriminant': …}` (all four forms verified) |
| `List<T>` | Dart `List` of natives of `T` |
| `Array<T,N>` | Dart `List` of natives, length exactly `N` |
| tuple / `MultiArg<...>` / `MultiResult<...>` | Dart `List` positionally matching the elements |
| `Option<T>` | the inner native, or `null` for `None` |
| `optional<T>` | the inner native, or `null` to omit the argument entirely |
| `ManagedDecimal<...>` | `List` of exactly `[BigInt mantissa, int scale]` |
| `variadic<T>` / `counted-variadic<T>` | flat trailing arguments, one per item, **or** one whole `VariadicValue` — see 6.2 |
| `multi<...>` / `MultiValue2<...>` … | a Dart `List` holding exactly one value per member, **or** a `MultiValueValue` — see 6.2 |

Sources: `lib/src/abi/serializers/native_serializer.dart:626-844` (primitives), `:432-467` (struct), `:470-557` (enum), `:604-623` (ManagedDecimal), `:263-320` (List/Array), `:245-260`/`:322-338` (Option/optional); `lib/src/abi/serializers/argument_encoder.dart:276-322` (variadic grouping), `:385-414` (`multi<...>`).

The shapes below correspond, in order, to an endpoint declared as
`submit(u32, BigUint, bool, Address, Deposit, Status, List<u32>, Option<u64>, variadic<BigUint>)`
where `Deposit` is a struct with fields `amount`/`token` and `Status` is an enum with a variant named `Active` — the last two `BigInt`s are the two variadic items.

```dart
Future<Transaction> argumentShapes(
  SmartContractController controller,
  IAccount account,
  Nonce nonce,
) {
  return controller.call(
    account: account,
    nonce: nonce,
    endpointName: 'submit',
    arguments: <dynamic>[
      42,
      BigInt.from(1000000000000000000),
      true,
      'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
      <String, dynamic>{'amount': BigInt.from(5), 'token': 'WEGLD-bd4d79'},
      'Active',
      <int>[1, 2, 3],
      null,
      BigInt.from(7),
      BigInt.from(8),
    ],
    options: const BaseControllerInput(gasLimit: GasLimit(20000000)),
  );
}
```

### 6.2 Multi-slot parameters

Three ABI shapes occupy more than one top-level argument slot. All three take a native Dart form, and all three also accept the hand-built `TypedValue` if you already have one; the wire result is the same either way. Every data field below was produced by running the encoder against a loaded ABI.

| Declared parameter | Natural call | Slots emitted |
|---|---|---|
| `withVariadic(first: u32, rest: variadic<BigUint>)` | `[1, BigInt.two, BigInt.from(3)]` | `withVariadic@01@02@03` |
| the same, pre-grouped | `[1, VariadicValue([BigUIntValue(two), BigUIntValue(three)], itemType: BigUIntType.type)]` | `withVariadic@01@02@03` |
| the same, no items | `[1]` | `withVariadic@01` |
| `countedCall(items: counted-variadic<u32>)` | `[1, 2]` | `countedCall@02@01@02` — the `u32` count, then the items |
| `multiLast(pair: multi<TokenIdentifier,BigUint>)` | `[['WEGLD-bd4d79', BigInt.from(10)]]` | `multiLast@5745474c442d626434643739@0a` |
| `variadicMulti(pairs: variadic<multi<TokenIdentifier,BigUint>>)` | `[['WEGLD-bd4d79', BigInt.from(10)], ['USDC-c76f1f', BigInt.one]]` | four parts, two per pair |

A trailing variadic swallows every argument past the fixed ones and converts each against the variadic **item** type; a single trailing argument that already *is* a `VariadicValue` is adopted whole (`argument_encoder.dart:276-322`). For a `counted-variadic<T>` the declared type decides the count, so an uncounted `VariadicValue` handed to it is still counted on the wire, and zero items still emit the count slot.

A `multi<A,B>` is an ordinary parameter that happens to occupy `arity` slots — it is not variadic (`_isVariadicParameter`, `:421`), so it works in the last position, in the middle, and as a variadic's item type. Its native form is a `List` of exactly `arity` values; any other length throws `ArgumentEncodingException` (`:392-400`).

### 6.3 Types that need a `TypedValue`

`NativeSerializer` has no native form for these — passing a plain Dart value throws `ArgumentEncodingException` from `call`:

| ABI type | What to do |
|---|---|
| `ManagedByteArray<N>` / `arrayN<u8>` | build `ManagedByteArrayValue(ManagedByteArrayType(n), bytes)` — a native `List<int>` throws `AbiNativeSerializationException: Unsupported primitive type: ManagedByteArrayType`, wrapped in `ArgumentEncodingException` |
| `BigFloat` | nothing works — the type has no wire codec at all; see `05-abi-types-and-codecs.md` §5 |

An explicit `TypedValue` is accepted anywhere a native is (`native_serializer.dart:193-195`) and is passed through unconverted, then type-checked against the endpoint signature.

For an endpoint `submitPairs(MultiValue2<TokenIdentifier,BigUint>, ManagedByteArray*4*, counted-variadic<u32>)`, the natural call and the fully explicit one produce the identical data field
`submitPairs@5745474c442d626434643739@0a@01020304@02@01@02` — two slots for the pair, the fixed blob, the `u32` count, then the two items:

```dart
Future<Transaction> multiSlotArguments(
  SmartContractController controller,
  IAccount account,
  Nonce nonce,
) {
  return controller.call(
    account: account,
    nonce: nonce,
    endpointName: 'submitPairs',
    arguments: <dynamic>[
      /// MultiValue2<TokenIdentifier,BigUint> — one value per member.
      <dynamic>['WEGLD-bd4d79', BigInt.from(10)],
      /// ManagedByteArray*4* — must be a TypedValue.
      ManagedByteArrayValue(ManagedByteArrayType(4), <int>[1, 2, 3, 4]),
      /// counted-variadic<u32> — flat trailing items; the count is added.
      1,
      2,
    ],
    options: const BaseControllerInput(gasLimit: GasLimit(20000000)),
  );
}

Future<Transaction> explicitTypedValues(
  SmartContractController controller,
  IAccount account,
  Nonce nonce,
) {
  final MultiValueType pair = MultiValueType(
    2,
    <AbiType>[TokenIdentifierType.type, BigUIntType.type],
  );

  return controller.call(
    account: account,
    nonce: nonce,
    endpointName: 'submitPairs',
    arguments: <dynamic>[
      MultiValueValue(pair, <TypedValue>[
        TokenIdentifierValue('WEGLD-bd4d79'),
        BigUIntValue(BigInt.from(10)),
      ]),
      ManagedByteArrayValue(ManagedByteArrayType(4), <int>[1, 2, 3, 4]),
      VariadicValue.counted(
        <TypedValue>[U32Value(1), U32Value(2)],
        itemType: U32Type.type,
      ),
    ],
    options: const BaseControllerInput(gasLimit: GasLimit(20000000)),
  );
}
```

### 6.4 `AbiType.createValue` is a different, stricter path

`AbiType.createValue(native)` (`lib/src/abi/core/type_system.dart:223`) is **not** what `call`/`query` use, and it accepts less. Verified differences: `U8Type.type.createValue('5')` throws while the endpoint path accepts `'5'`; `BytesType.type.createValue('0x0102')` yields the six UTF-8 bytes of the literal text while the endpoint path hex-decodes it to `[1, 2]`; `EnumType.createValue(1)` throws while the endpoint path accepts the discriminant. Use `createValue` only when you are building a `TypedValue` by hand and know the exact input shape.

---

## 7. Token payments

Payments are **never** arguments — they are the separate `tokenTransfers` parameter. Putting a `TokenTransferValue` in `arguments` always fails, but with a different exception per path (both verified by running the factory): with an ABI it throws `ArgumentValidationException` (the value's type does not match the declared parameter); without an ABI it throws `ArgumentEncodingException` whose message names `tokenTransfers` (test: `test/abi/smart_contract/optional_abi_test.dart:103-131`).

```dart
Future<Transaction> callWithEsdt(
  SmartContractController controller,
  IAccount account,
  Nonce nonce,
) {
  return controller.call(
    account: account,
    nonce: nonce,
    endpointName: 'swapTokensFixedInput',
    arguments: <dynamic>['USDC-c76f1f', BigInt.one],
    tokenTransfers: <TokenTransferValue>[
      TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'WEGLD-bd4d79',
        amount: BigInt.from(1000000000000000000),
      ),
    ],
    options: const BaseControllerInput(gasLimit: GasLimit(30000000)),
  );
}
```

`TokenTransferValue.fromPrimitives({required String tokenIdentifier, required BigInt amount, BigInt? nonce})` — `lib/src/abi/types/special/token_transfer_value.dart:101`. `nonce` must be `null` for fungible tokens; passing `BigInt.zero` throws `ArgumentError` (:118-124). The identifier is validated on construction: it must be `EGLD` or `TICKER-hexrandom` with a 3–10 upper-case alphanumeric ticker and 6 hex chars, else `ArgumentError` (`token_identifier.dart:359`).

The transfer shape rewrites the receiver and the data field (`lib/src/abi/smart_contract/factory/smart_contract_call_factory.dart:286-318`). Verified by running the factory with endpoint `pay` and argument `u32 1`:

| Transfers | `receiver` | data field |
|---|---|---|
| one fungible ESDT | the contract | `ESDTTransfer@<tokenHex>@<amountHex>@<fnNameHex>@<argHex>…` |
| one NFT/SFT (nonce set) | **the sender** | `ESDTNFTTransfer@<tokenHex>@<nonceHex>@<qtyHex>@<contractHex>@<fnNameHex>@<argHex>…` |
| two or more | **the sender** | `MultiESDTNFTTransfer@<contractHex>@<countHex>@<tokenHex>@<nonceHex>@<amountHex>…@<fnNameHex>@<argHex>…` |
| none | the contract | `<fnName>@<argHex>…` (function name in plain text, not hex) |

The `receiver == sender` cases are the protocol shape, not a bug: the contract address rides inside the data field. A zero nonce top-level-encodes to an **empty** part, so a fungible token inside `MultiESDTNFTTransfer` shows as `…@<tokenHex>@@<amountHex>…` — the empty slot is correct, not a missing field.

If the ABI marks the endpoint non-payable-in-tokens, or the token is outside `payableInTokens`, the call throws `ArgumentEncodingException` before any network I/O (:368-417). `payableInTokens` supports `*` and `PREFIX-*` patterns.

EGLD is sent with the `value:` parameter (`Balance`), not through `tokenTransfers`.

---

## 8. Deploy and upgrade

Both live on the controller and return an **unsigned** `Transaction` — you sign and broadcast it yourself.

```
Transaction createTransactionForDeploy({
  required Address sender,
  required Nonce nonce,
  required Uint8List bytecode,
  required GasLimit gasLimit,
  Uint8List? codeMetadata,
  String vmType = '0500',
  List<Uint8List> arguments = const <Uint8List>[],
})
```
(`:232`)

```
Transaction createTransactionForUpgrade({
  required Address sender,
  required Nonce nonce,
  required Uint8List bytecode,
  required GasLimit gasLimit,
  Uint8List? codeMetadata,
  List<Uint8List> arguments = const <Uint8List>[],
})
```
(`:278`)

Note `arguments` here is `List<Uint8List>` — **already top-level-encoded bytes**, not native values. Encode them with `BinaryCodec.withDefaults().encodeTopLevel(...)`.

Data-field shapes (`lib/src/core/transaction/factories/smart_contract_transactions_factory.dart:49-66`, `:83-99`):

- deploy: `<codeHex>@<vmTypeHex>@<metadataHex>[@<argHex>…]`, receiver = the zero address, `vmType` default `'0500'`.
- upgrade: `upgradeContract@<codeHex>@<metadataHex>[@<argHex>…]`, receiver = the contract.

When `codeMetadata` is omitted, both default to the bytes `0x05 0x06` (:63, :96).

### `CodeMetadata`

Two distinct classes — do not mix them up:

| Class | Purpose | Source |
|---|---|---|
| `CodeMetadata` | plain flag holder; `toBytes()` gives the 2-byte field for deploy/upgrade | `lib/src/core/account/code_metadata.dart:29` |
| `CodeMetadataValue` | the ABI `TypedValue` for a `CodeMetadata` endpoint parameter | `lib/src/abi/types/special/code_metadata.dart:117` |

`const CodeMetadata({bool isUpgradeable = false, bool isReadable = false, bool isPayable = false, bool isPayableBySmartContract = false})` (:37). The 2-byte big-endian bitmap (:45-54):

| Flag | Mask |
|---|---|
| upgradeable | `0x0100` |
| readable | `0x0400` |
| payable | `0x0002` |
| payable-by-smart-contract | `0x0004` |

So all four flags set = `0x0506`, which is exactly the default the factory writes. `CodeMetadata.fromBytes(Uint8List)` accepts 0, 1 or 2 bytes and throws `ArgumentError` beyond that (:81-88); `CodeMetadata.tryParseBase64(String?)` returns `null` for missing/empty input (:110).

```dart
Future<void> deployAndUpgrade(
  SmartContractController controller,
  IAccount account,
  ApiNetworkProvider provider,
  Uint8List wasm,
  Nonce nonce,
) async {
  const CodeMetadata metadata = CodeMetadata(
    isUpgradeable: true,
    isReadable: true,
    isPayable: false,
    isPayableBySmartContract: true,
  );

  final Transaction deploy = controller.createTransactionForDeploy(
    sender: account.address,
    nonce: nonce,
    bytecode: wasm,
    gasLimit: const GasLimit(60000000),
    codeMetadata: metadata.toBytes(),
    arguments: <Uint8List>[
      BinaryCodec.withDefaults().encodeTopLevel(BigUIntValue(BigInt.from(500))),
    ],
  );

  final Uint8List signature = await account.signTransaction(deploy);
  final Transaction signedDeploy = deploy.copyWith(
    newSignature: Signature.fromUint8List(signature),
  );
  final String hash = await provider.sendTransaction(signedDeploy);

  final SmartContractDeployOutcome outcome =
      await controller.awaitCompletedDeploy(hash);
  print(outcome.contracts.first.address.bech32);

  final Transaction upgrade = controller.createTransactionForUpgrade(
    sender: account.address,
    nonce: const Nonce(9),
    bytecode: wasm,
    gasLimit: const GasLimit(60000000),
    codeMetadata: metadata.toBytes(),
  );
  print(upgrade.receiver.bech32);
}
```

### Gas for deploy/upgrade

`createTransactionForDeploy`/`createTransactionForUpgrade` require an explicit `gasLimit` and use it verbatim. The other two lifecycle transactions on `SmartContractTransactionsFactory` compute gas additively as data-movement plus execution:

`gas = executionAllowance + minGasLimit + data.length * gasLimitPerByte`

with `minGasLimit = 50000` and `gasLimitPerByte = 1500` (`smart_contract_transactions_factory.dart:24-25`, applied at `:126-129` for `ChangeOwnerAddress` and `:155-158` for `ClaimDeveloperRewards`).

---

## 9. Outcome parsing

| Method | Signature | Source |
|---|---|---|
| `parseDeploy` | `SmartContractDeployOutcome parseDeploy(TransactionOnNetwork transaction)` | :316 |
| `parseExecute` | `ParsedSmartContractCallOutcome parseExecute({required TransactionOnNetwork transaction, String? function})` | :338 |
| `awaitCompletedDeploy` | `Future<SmartContractDeployOutcome> awaitCompletedDeploy(String txHash)` | :400 |
| `awaitCompletedExecute` | `Future<ParsedSmartContractCallOutcome> awaitCompletedExecute(String txHash, {String? function})` | :421 |

`SmartContractDeployOutcome` — `returnCode` (`String`), `returnMessage` (`String`), `contracts` (`List<DeployedContract>`); each `DeployedContract` has `address`, `ownerAddress`, `codeHash` (`lib/src/core/transaction/outcome_parsers/smart_contract_outcome_parser.dart:31-60`).

`ParsedSmartContractCallOutcome` — `returnCode` (`String`), `returnMessage` (`String`), `values` (`List<dynamic>`) (:69-79).

The endpoint used for decoding is `function ?? transaction.function` (`smart_contract_outcome_parser.dart:170`). When that resolves to a name **and** the controller has an ABI, `values` holds decoded natives; otherwise `values` holds the raw return-data `Uint8List` parts (:172-178). Pass `function:` explicitly whenever the transaction's own function field may be absent or may name a transfer wrapper rather than the endpoint.

```dart
Future<void> parseOutcome(
  SmartContractController controller,
  ApiNetworkProvider provider,
  String txHash,
) async {
  final ParsedSmartContractCallOutcome outcome =
      await controller.awaitCompletedExecute(txHash, function: 'getAmountOut');
  print('${outcome.returnCode} ${outcome.returnMessage} ${outcome.values}');

  final TransactionOnNetwork tx = await provider.getTransaction(txHash);
  final ParsedSmartContractCallOutcome again = controller.parseExecute(
    transaction: tx,
    function: 'getAmountOut',
  );
  print(again.values);
}
```

---

## 10. Without an ABI

`SmartContractController.withoutAbi` + `queryRaw` / `callRaw`. Signatures mirror `query`/`call` (`:494`, `:644`).

Argument rule (`RawArgumentValidator.encodeRawArguments`, `lib/src/abi/smart_contract/utils/argument_validation.dart:48-73`): the list must be **uniformly** `TypedValue` **or** uniformly `Uint8List`. Anything else — a native `int`, a `String`, or a mix — throws `ArgumentEncodingException` (tests: `test/abi/smart_contract/optional_abi_test.dart:77` mixed, `:90` native).

That rule is not symmetric between the two `…Raw` methods, and it does not depend on the method name alone:

- `queryRaw` **always** applies it — the query runner encodes through the raw validator whether or not an ABI is present (`smart_contract_query_runner.dart:550-552`).
- `callRaw` applies it only when the controller has **no** ABI. On an ABI-carrying controller `callRaw` runs the same `_factory.createCall` body as `call` (`:587` vs `:667`), so it takes native values, enforces the `isView` guard and validates `payableInTokens` exactly like `call`.

```dart
Future<void> withoutAbi(IAccount account) async {
  final ApiNetworkProvider provider = ApiNetworkProvider.devnet();
  final SmartContractController controller =
      SmartContractController.withoutAbi(
    contractAddress: Address.fromBech32(
      'erd1qqqqqqqqqqqqqpgq09vq93grfqy7x5fhgmh44ncqfp3xaw57ys5s7j9fed',
    ),
    networkProvider: provider,
  );

  final RawQueryResult raw = await controller.queryRaw(
    endpointName: 'getBalanceOf',
    arguments: <dynamic>[
      AddressValue.fromBech32(
        'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
      ),
    ],
  );

  final BinaryCodec codec = BinaryCodec.withDefaults();
  final BigUIntValue balance = codec.decodeTopLevel(
    raw.returnDataParts[0],
    BigUIntType.type,
  ) as BigUIntValue;
  print(balance.value);

  final Transaction signed = await controller.callRaw(
    account: account,
    nonce: const Nonce(42),
    endpointName: 'deposit',
    arguments: <dynamic>[BigUIntValue(BigInt.from(1000))],
    options: const BaseControllerInput(gasLimit: GasLimit(10000000)),
  );
  await provider.sendTransaction(signed);
  provider.close();
}
```

`RawQueryResult` (`smart_contract_query_runner.dart:116`): `returnDataParts` is `List<Uint8List>` — **already base64-decoded** (:517-519), unlike `QueryResult.rawData` which is still base64. Also `returnCode`, `returnMessage`, `isSuccess`, `isEmpty`, `first`, `operator []`, `length`.

---

## 11. Endpoint introspection

```dart
void introspect(SmartContractController controller) {
  for (final AbiEndpoint endpoint in controller.getViewEndpoints()) {
    print('view ${endpoint.name}');
  }
  for (final AbiEndpoint endpoint in controller.getMutableEndpoints()) {
    print('call ${endpoint.name} payableIn=${endpoint.payableInTokens}');
  }
  if (controller.hasEndpoint('swapTokensFixedInput')) {
    final AbiEndpoint endpoint =
        controller.getEndpoint('swapTokensFixedInput');
    for (final AbiParameter input in endpoint.inputs) {
      print('${input.name}: ${input.type.name}');
    }
  }
}
```

`AbiEndpoint` fields (`lib/src/abi/core/endpoint.dart:29-43`): `name`, `inputs` (`InputParameters`), `outputs` (`OutputParameters`), `payableInTokens` (`List<String>`), `isView`, `isOnlyOwner`, `isOnlyAdmin`, `title`, `labels`, `allowMultipleVarArgs`, `documentation`, `mutability`, `internalMethodName`.

`isView` is derived from the ABI's `"mutability"` being `readonly` or `pure` (:90). `"payable": true` with no `payableInTokens` list is normalised to `['EGLD']` (:83-86).

---

## 12. Failure modes

| Situation | Exception | Where |
|---|---|---|
| endpoint name absent from the ABI | `EndpointNotFoundException` | `lib/src/abi/core/core_types.dart:243`, built at `:270` |
| wrong argument count, or a `TypedValue` whose type does not match the parameter | `ArgumentValidationException` | `core_types.dart:354`, thrown at `endpoint_resolver.dart:291`/`:318` |
| a native value that cannot be converted to the declared type | `ArgumentEncodingException` | `core_types.dart:123` |
| a `multi<...>` argument whose list length is not the declared arity | `ArgumentEncodingException` | `argument_encoder.dart:392-400` |
| `arguments` contains a `TokenTransferValue`, ABI path | `ArgumentValidationException` | `endpoint_resolver.dart:318` |
| `arguments` contains a `TokenTransferValue`, no-ABI path | `ArgumentEncodingException` | `argument_validation.dart:114` |
| no-ABI call with native or mixed arguments | `ArgumentEncodingException` | `argument_validation.dart:68` |
| `call` on an endpoint whose `mutability` is `readonly`/`pure` | `ArgumentError` | `smart_contract_call_factory.dart:257-262` |
| `options.gasLimit == null` **and** the controller has no `gasLimitEstimator` | `ArgumentError` | controller `:693-700` |
| ABI-only method used on a `withoutAbi` controller | `StateError` | controller `:1083`, `:1094`, `:179` |
| node returned a non-`ok` return code for a query | `SmartContractQueryException` | `lib/src/abi/smart_contract/query/query.dart:19` |
| return-data count does not match the declared outputs | `ResponseParsingException` | `core_types.dart:183` |
| invalid ABI JSON or invalid ABI structure | `FormatException` | `lib/src/abi/abi.dart:124` |

---

## 13. Do not do

- Do **not** re-sign the `Transaction` returned by `call`/`callRaw` — it already carries a signature.
- Do **not** pass token payments inside `arguments`; use `tokenTransfers`.
- Do **not** wrap variadic items in a plain nested `List` — flatten them as trailing arguments, or group them in a `VariadicValue` (§6.2). A bare `List` is read as one item and converted against the item type.
- Do **not** pass native Dart values to `queryRaw`, or to `callRaw` on a `withoutAbi` controller; only `TypedValue`s or `Uint8List`s, and never mixed.
- Do **not** pass a native `List<int>` for `ManagedByteArray<N>`; build the `ManagedByteArrayValue` (§6.3).
- Do **not** cast `QueryResult.values[i]` for an `Address` output to `Address` — it is a bech32 `String`.
- Do **not** treat `QueryResult.rawData` as bytes — it is base64 text. `RawQueryResult.returnDataParts` is the decoded-bytes one.
- Do **not** call `createTransactionForDeploy(arguments: …)` with native values — that parameter takes already-encoded `Uint8List` parts.
- Do **not** add the guardian or relayer allowance into the `gasLimit` you pass — `options.gasLimit` is the execution budget and the 50 000-gas allowances are added on top of it (§5).

---

## Not verified

- No end-to-end network round trip was executed. The data fields, receivers and exception types in §4, §6, §7, §8 and §12 were produced by running the call factory, the response parser and the codec offline against a loaded ABI; nothing was broadcast to a chain, and no return data from a real contract was decoded.
- The deploy/upgrade snippet in §8 was executed only as far as the unsigned transaction (data field and receiver); the signing, broadcast and `awaitCompletedDeploy` half of it is compile-verified only.
- The gas resolution order in §5 was read from `base_controller.dart`; the estimator branch was not exercised with a live `IGasLimitEstimator` implementation, and the guardian/relayer allowance was not checked against a node's own accounting.
- The event methods (`queryEvents`, `streamEvents`, `watchTransaction`, …) are listed only for availability-by-constructor; their behaviour and payloads are out of scope for this file.
- `controller.query(value: …)` is accepted by the signature; the effect of a non-zero `value` on a node-side query was not exercised.
