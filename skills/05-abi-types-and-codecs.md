---
name: abi-types-and-codecs
title: ABI Types and Wire Codecs
summary: Map every MultiversX ABI type name to its abidock_mvx Dart class, know what a caller passes for it, and produce the exact top-level and nested bytes the chain expects.
reads: [04-smart-contracts.md]
verified_against: abidock_mvx 3.1.0 (Dart 3.13)
---

**When to use this**: you need to know what a type name in an `.abi.json` resolves to, what Dart value to hand it, or exactly which bytes it becomes.

Single import for everything below:

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
```

Add `import 'dart:typed_data';` if you name `Uint8List` yourself — the package export does not re-export it (verified).

The authority for every name in §1 is the switch in `AbiTypeFactory.fromTypeFormula`, `lib/src/abi/core/types.dart:326-627` (with the no-parameter fallback `_fromSimpleTypeName`, `:774-842`). A name that is not in that switch and is not a key of the ABI's `types` map throws `ArgumentError`.

---

## 1. Type-name table

"Pass" is what you give `controller.call` / `controller.query` for a parameter of that type (the `NativeSerializer` path — see `04-smart-contracts.md` §6). "Native out" is `TypedValue.nativeValue`, i.e. what you read back out of `QueryResult.values`.

### 1.1 Numbers

| ABI name(s) | `AbiType` class | `TypedValue` class | Pass | Native out |
|---|---|---|---|---|
| `u8` | `U8Type` | `U8Value` | `int` / `BigInt` / numeric `String` | `int` |
| `u16` | `U16Type` | `U16Value` | same | `int` |
| `u32` | `U32Type` | `U32Value` | same | `int` |
| `u64`, `U64` | `U64Type` | `U64Value` | same | `BigInt` |
| `i8` | `I8Type` | `I8Value` | same | `int` |
| `i16` | `I16Type` | `I16Value` | same | `int` |
| `i32` | `I32Type` | `I32Value` | same | `int` |
| `i64` | `I64Type` | `I64Value` | same | `BigInt` |
| `BigUint`, `NonZeroBigUint`, `u128`, `U128` | `BigUIntType` | `BigUIntValue` | same | `BigInt` |
| `BigInt`, `Bigint`, `i128`, `I128` | `BigIntType` | `BigIntValue` | same | `BigInt` |
| `BigFloat` | `BigFloatType` | `BigFloatValue` | **nothing works** — see §5 | `double` |

Every numeric row also accepts a Dart `double`, and the conversion is a truncation towards zero: `42.9` for a `u32` parameter encodes as `2a` (42) (`native_serializer.dart:678-704`). An ABI integer is an integer, so pass `int`, `BigInt` or a numeric `String` and keep the rounding decision in your own code.

`u128`/`U128` and `NonZeroBigUint` are aliases of `BigUint` and are indistinguishable afterwards: `factory.fromString('NonZeroBigUint')` returns the identical `BigUIntType.type` singleton (verified). Likewise `i128`/`I128` alias `BigInt`. Nothing in the codec enforces the "non-zero" or 128-bit part.

### 1.2 Other primitives

| ABI name(s) | `AbiType` class | `TypedValue` class | Pass | Native out |
|---|---|---|---|---|
| `bool` | `BooleanType` | `BooleanValue` | `bool`, `num` (≠0 ⇒ true), `'true'`/`'1'` | `bool` |
| `bytes` | `BytesType` | `BytesValue` | `Uint8List`, `List<int>`, `'0x…'` hex, or plain `String` (UTF-8) | `Uint8List` |
| `string`, `utf-8 string` | `StringType` | `StringValue` | any non-`null` object (`toString()`) | `String` |
| `Address` | `AddressType` | `AddressValue` | bech32 `String`, 64-char hex, `'0x…'`, 32-byte `Uint8List`/`List<int>` | `String` (bech32) |
| `H256` | `H256Type` | `H256Value` | hex `String` or `List<int>` | `Uint8List` |
| `CodeMetadata` | `CodeMetadataType` | `CodeMetadataValue` | `int` 0–65535, or 2-element `List<int>` | `int` |
| `Nothing`, `nothing`, `AsyncCall` | `NothingType` | `NothingValue` | `null` | `null` |

### 1.3 Collections

| ABI name(s) | `AbiType` class | `TypedValue` class | Pass | Native out |
|---|---|---|---|---|
| `List<T>` | `ListType` | `ListValue` | Dart `List` of `T` natives | `List<dynamic>` |
| `Array<T,N>` | `ArrayType` | `ArrayValue` | Dart `List`, length exactly `N` | `List<dynamic>` |
| `arrayN<T>` where `T` ≠ `u8` (`array2`, `array6`, `array8`, `array16`, `array20`, `array32`, `array46`, `array48`, `array64`, `array128`, `array256`, and in fact any `array<digits>`) | `ArrayType(T, N)` | `ArrayValue` | Dart `List`, length `N` | `List<dynamic>` |
| `arrayN<u8>` | `ManagedByteArrayType(N)` | `ManagedByteArrayValue` | **`TypedValue` only** | `Uint8List` |
| `Option<T>` | `OptionType` | `OptionValue` | inner native, or `null` for `None` | inner native or `null` |

`arrayN<u8>` silently becomes a `ManagedByteArray`, not an `Array` — the size prefix is parsed before the switch (`types.dart:334-344`). Verified: `array32<u8>` → `ManagedByteArrayType`, `array2<u32>` → `ArrayType`.

### 1.4 Composites

| ABI name(s) | `AbiType` class | `TypedValue` class | Pass | Native out |
|---|---|---|---|---|
| any key of the ABI `types` map with `"type": "struct"` | `StructType` | `StructValue` | `Map` with **every** declared field name as a key | `Map<String, dynamic>` |
| any key with `"type": "enum"` | `EnumType` | `EnumValue` | variant-name `String`; discriminant `int` **only for a variant that has no fields** (an `int` naming a variant with fields throws); or `{'variant': name, 'fields': [...]}` | `String`, or `{'variant': …, 'fields': [...]}` when the variant has fields |
| any key with `"type": "explicit-enum"` | `ExplicitEnumType` | `ExplicitEnumValue` | variant-name `String`, discriminant `int`, `{'name': …}`, `{'discriminant': …}` | `String` |
| `tuple`, `Tuple`, `tuple2`…`tuple8` | `TupleType` | `TupleValue` | positional Dart `List` | `List<dynamic>` |

Bare `struct`, `Struct`, `enum`, `Enum`, `ExplicitEnum` as a *type string* throw `ArgumentError` — they carry no field/variant information (`types.dart:595-616`). They only exist as `"type"` discriminators inside the `types` map.

### 1.5 Argument-position (multi-slot) types

These occupy more than one top-level argument slot; see §4.

| ABI name(s) | `AbiType` class | `TypedValue` class | Pass | Native out |
|---|---|---|---|---|
| `variadic<T>`, `Variadic<T>`, `VarArgs<T>`, `MultiResultVec<T>` | `VariadicType` (`isCounted == false`) | `VariadicValue` | flat trailing arguments, one per item — or one whole `VariadicValue` | `List<TypedValue>` |
| `counted-variadic<T>` | `VariadicType` (`isCounted == true`) | `VariadicValue` | the same two forms; the `u32` count is emitted for you | `List<TypedValue>` |
| `optional<T>`, `OptionalArg<T>`, `OptionalResult<T>` | `OptionalType` | `OptionalValue` | inner native, or `null` to omit the slot entirely | inner native or `null` |
| `multi<...>`, `Multi<...>`, `multivalue<...>`, `MultiValue<...>`, `MultiValue2<...>`…`MultiValue8<...>` | `MultiValueType` | `MultiValueValue` | a Dart `List` holding exactly one native per member — or a `MultiValueValue` | `List<dynamic>` |
| `MultiArg<...>`, `MultiResult<...>` | `CompositeType` | `CompositeValue` | positional Dart `List` | `List<dynamic>` |

`variadic<T>` and `MultiValue2<...>` are **not** interchangeable: the first repeats one type an unbounded number of times, the second is a fixed-arity group. `multi<...>` occupies one top-level slot per member; `MultiArg<...>` packs its whole composite into a single slot.

**How these reach the wire from the ABI endpoint path.** `ArgumentEncoder` groups the arguments, then expands each grouped value into one hex part per top-level slot (`lib/src/abi/serializers/argument_encoder.dart:119-146`, `:276-322`). Every line below was produced by running the encoder against a loaded ABI.

- **A trailing variadic takes either shape.** For `variadicCall(fixed: u32, items: variadic<BigUint>)`, both `[1, BigInt.two, BigInt.from(3)]` and `[1, VariadicValue([BigUIntValue(two), BigUIntValue(three)], itemType: BigUIntType.type)]` encode to `01@02@03`. `_buildVariadicValue` collects the trailing run into one `VariadicValue`, and a single trailing argument that *is* already a `VariadicValue` is adopted as-is (`argument_encoder.dart:284-294`). An uncounted variadic given no trailing arguments contributes no slots at all: `[1]` encodes to just `01`.
- **`counted-variadic<T>` emits its `u32` count first.** For `countedCall(items: counted-variadic<u32>)`, both `[1, 2]` and `[VariadicValue.counted([U32Value(1), U32Value(2)], itemType: U32Type.type)]` encode to `02@01@02` — the count, then the two items. The declared type wins over the value: an *uncounted* `VariadicValue` handed to a counted parameter is re-wrapped as counted (`:286-293`). With no items the count slot is still emitted, holding `u32` 0, which top-level-encodes to an empty part.
- **`multi<...>` occupies one slot per member, in any position.** For `multi<TokenIdentifier,BigUint>`, the native form `['WEGLD-bd4d79', BigInt.from(10)]` and the explicit `MultiValueValue(...)` both encode to `5745474c442d626434643739@0a` — two parts, which is what the protocol expects. This holds as the endpoint's last input, in the middle of a parameter list, and as the item type of a `variadic<multi<...>>`, which expands every pair (`variadicMulti` with two pairs → four parts). A native list whose length is not the declared arity throws `ArgumentEncodingException` (`:392-400`).
- **`optional<T>` omits its slot when `null`.** `opt(a: u32, b: optional<u64>)` with `[1, BigInt.from(9)]` encodes to `01@09`; with `[1, null]` it encodes to `01`.

### 1.6 Fixed-point and fixed-length

| ABI name | `AbiType` class | `TypedValue` class | Pass | Native out |
|---|---|---|---|---|
| `ManagedDecimal<N>` (N = digits) | `ManagedDecimalType` (`isVariable == false`, `scale == N`) | `ManagedDecimalValue` | `List` of exactly `[BigInt mantissa, int scale]` | `BigInt` (mantissa) |
| `ManagedDecimal<usize>*S*` | `ManagedDecimalType.variable(S)` (`isVariable == true`) | `ManagedDecimalValue` | same | `BigInt` |
| `ManagedDecimalSigned<N>` / `ManagedDecimalSigned<usize>*S*` | `ManagedDecimalType` with `isSigned == true` (the `runtimeType` is `ManagedDecimalType`, verified) | `ManagedDecimalValue` with `isSigned: true` — the endpoint path never constructs the `ManagedDecimalSignedValue` subclass (`native_serializer.dart:609-617`) | same | `BigInt` |
| `ManagedByteArray*N*` or `ManagedByteArray<N>` | `ManagedByteArrayType(N)` | `ManagedByteArrayValue` | **`TypedValue` only** | `Uint8List` |

`ManagedByteArray` with no length throws `ArgumentError` (`types.dart:358-361`).

---

## 2. Names that resolve without a `types` entry

These are framework types the contract build never writes into the ABI's `types` map, so the factory recognises them intrinsically (`types.dart:311-316`, `:567-588`, `:851-943`). All verified by resolving them from a bare `AbiTypeFactory()` with no ABI loaded.

| Name | Resolves to | Wire form |
|---|---|---|
| `TokenId` | the same `TokenIdentifierType.type` singleton as `TokenIdentifier` | identical to `TokenIdentifier` |
| `EsdtTokenIdentifier` | `TokenIdentifierType.type` | identical to `TokenIdentifier` |
| `NonZeroBigUint` | the same `BigUIntType.type` singleton as `BigUint` | identical to `BigUint` — the non-zero constraint is not enforced here |
| `EgldOrEsdtTokenIdentifier` | `EgldOrEsdtTokenIdentifierType` | like `TokenIdentifier`, except native EGLD (`'EGLD-000000'`) is a **zero-length payload** |
| `Payment` | `StructType` `{token_identifier: TokenIdentifier, token_nonce: u64, amount: BigUint}` | struct: three fields concatenated in that order |
| `FungiblePayment` | `StructType` `{token_identifier: TokenIdentifier, amount: BigUint}` | struct: two fields concatenated |
| `EsdtTokenPayment` | `StructType` `{token_identifier: TokenIdentifier, token_nonce: u64, amount: BigUint}` | as above |
| `EgldOrEsdtTokenPayment` | `StructType` `{token_identifier: EgldOrEsdtTokenIdentifier, token_nonce: u64, amount: BigUint}` | as above |
| `EgldOrMultiEsdtPayment` | `StructType` `{egld_amount: BigUint, multi_esdt: List<EsdtTokenPayment>}` | a struct, so **both** fields are always on the wire — a value with amount 3 and an empty list encodes to `000000010300000000` (verified) |

`Payment` and `FungiblePayment` are declared in the source with `TokenId`/`NonZeroBigUint` field types, which collapse to `TokenIdentifier`/`BigUint` — so `FungiblePayment` nested is `[u32 len][utf8 id][u32 len][magnitude]`.

The built-ins are cached singletons: two lookups of `Payment` return the identical instance (`types.dart:847`).

```dart
void builtInNames() {
  final AbiTypeFactory factory = AbiTypeFactory();

  print(identical(factory.fromString('TokenId'), TokenIdentifierType.type));
  print(identical(factory.fromString('NonZeroBigUint'), BigUIntType.type));

  final StructType payment = factory.fromString('Payment') as StructType;
  final StructType fungible =
      factory.fromString('FungiblePayment') as StructType;
  print(payment.fieldDefinitions
      .map((FieldDefinition f) => '${f.name}:${f.type.name}')
      .toList());
  print(fungible.fieldDefinitions
      .map((FieldDefinition f) => '${f.name}:${f.type.name}')
      .toList());
}
```

Prints `true`, `true`, `[token_identifier:TokenIdentifier, token_nonce:u64, amount:BigUint]`, `[token_identifier:TokenIdentifier, amount:BigUint]`.

---

## 3. Top-level vs nested encoding

Two encodings exist for the same value.

- **Top-level** is used when a value is a whole argument or a whole return-data part. It is self-delimiting because the argument boundary (`@` in the data field, or one array element in the node's `returnData`) tells the decoder where it ends. It is therefore written as compactly as possible.
- **Nested** is used when a value sits *inside* another value — a struct field, a list element, an array slot, an enum payload, the inner of an `Option`. There is no boundary marker, so every dynamically-sized type carries an explicit length and every fixed-width integer is written at full width.

The codec entry points (`lib/src/abi/codecs/binary_codec.dart`):

| Method | Signature | Line |
|---|---|---|
| `encodeTopLevel` | `Uint8List encodeTopLevel(TypedValue value)` | :355 |
| `encodeNested` | `Uint8List encodeNested(TypedValue value, {int depth = 0})` | :433 |
| `decodeTopLevel` | `TypedValue decodeTopLevel(Uint8List buffer, AbiType type)` | :206 |
| `decodeNested` | `(TypedValue, int) decodeNested(Uint8List buffer, AbiType type, int offset, {int depth = 0})` | :276 |

`decodeNested` returns a record of `(value, bytesConsumed)`. Get an instance with `BinaryCodec.withDefaults()` (cached singleton, `:102`).

```dart
void resolveAndEncode() {
  final AbiTypeFactory factory = AbiTypeFactory();
  final BinaryCodec codec = BinaryCodec.withDefaults();

  final AbiType u32 = factory.fromString('u32');
  final TypedValue value = u32.createValue(42);

  print(HexUtils.bytesToHex(codec.encodeTopLevel(value)));
  print(HexUtils.bytesToHex(codec.encodeNested(value)));

  final TypedValue back = codec.decodeTopLevel(
    HexUtils.hexToBytes('2a'),
    u32,
  );
  print(back.nativeValue);
}
```

Prints `2a`, `0000002a`, `42`.

### 3.1 Rule per type family

Every hex column below was produced by running this SDK's codec.

| Type | Top-level | Nested | Example (value → top / nested) |
|---|---|---|---|
| `u8` `u16` `u32` | minimal big-endian, **empty for 0** | fixed 1 / 2 / 4 bytes | `u32 42` → `2a` / `0000002a`; `u32 0` → `` / `00000000` |
| `u64` | minimal big-endian, empty for 0 | fixed 8 bytes | — |
| `i8` `i16` `i32` `i64` | minimal two's complement | fixed 1 / 2 / 4 / 8 bytes | `i64 -1` → `ff`; `i32 -1` nested → `ffffffff` |
| `BigUint` | minimal magnitude, empty for 0 | `[u32 length][magnitude]` | `1000` → `03e8` / `0000000203e8` |
| `BigInt` | minimal two's complement, empty for 0 | `[u32 length][two's complement]` | — |
| `bool` | `01` for true, **empty** for false | always 1 byte `01`/`00` | `false` → `` / `00` |
| `string` / `utf-8 string` | raw UTF-8, no prefix | `[u32 length][UTF-8]` | `'hi'` → `6869` / `000000026869` |
| `bytes` | raw bytes, no prefix | `[u32 length][bytes]` | `[1,2]` → `0102` / `000000020102` |
| `TokenIdentifier` | raw UTF-8, no prefix | `[u32 length][UTF-8]` | `'WEGLD-bd4d79'` → `5745474c442d626434643739` / `0000000c5745474c442d626434643739` |
| `EgldOrEsdtTokenIdentifier` | as `TokenIdentifier`, but `'EGLD-000000'` → **zero bytes** | as `TokenIdentifier`, but `'EGLD-000000'` → `00000000` | verified |
| `Address` | exactly 32 bytes | exactly 32 bytes | — |
| `H256` | exactly 32 bytes | exactly 32 bytes | — |
| `ManagedByteArray<N>` | exactly `N` bytes, no prefix | exactly `N` bytes, no prefix | `[1,2,3,4]` (N=4) → `01020304` / `01020304` |
| `CodeMetadata` | 2 bytes big-endian | 2 bytes big-endian | `0x0506` → `0506` / `0506` |
| `Nothing` | empty | empty (consumes 0 bytes) | — |
| `Option<T>` | `None` → empty; `Some` → `01` + nested(T) | `None` → `00`; `Some` → `01` + nested(T) | `Option<u32>` none → `` / `00`; some(7) → `0100000007` |
| `List<T>` | concatenated **nested** items, no count | `[u32 count]` + concatenated nested items | `[1,2]` of `u32` → `0000000100000002` / `000000020000000100000002` |
| `Array<T,N>` | concatenated nested items, no count | identical to top-level | `[1,2,3]` of `u8` → `010203` / `010203` |
| struct | concatenated **nested** fields, declaration order | identical to top-level | `{u32 1, BigUint 2}` → `000000010000000102` |
| tuple | identical to struct | identical to struct | `(u32 1, bool true)` → `0000000101` |
| enum | unit variant with discriminant 0 → **empty**; otherwise `[u8 discriminant]` + nested fields | always `[u8 discriminant]` + nested fields | disc 0 → `` / `00`; disc 1 → `01` |
| explicit-enum | UTF-8 variant name, no prefix | `[u32 length][UTF-8 variant name]` | `'fast'` → `66617374` / `0000000466617374` |
| `ManagedDecimal<N>` (fixed) | magnitude bytes only — `N` never reaches the wire | `[u32 length][magnitude]` | `12345`, scale 2 → `3039` / `000000023039` |
| `ManagedDecimal<usize>` (variable) | `[u32 length][magnitude][u32 scale]` | identical to top-level | `12345`, scale 2 → `00000002303900000002` |
| `ManagedDecimalSigned<N>` | two's-complement magnitude | `[u32 length][two's complement]` | `-5`, scale 1 → `fb` / `00000001fb` |
| `MultiArg<...>` / `MultiResult<...>` | concatenated nested fields | concatenated nested fields | — |
| `variadic<T>` (not counted) | concatenated nested items | concatenated nested items | — |
| `optional<T>` | missing → empty; provided → **top-level** of inner | **throws** | — |
| `multi<...>` | concatenated top-level encodings of the inner values | **throws** | — |
| `counted-variadic<T>` | **throws** | **throws** | — |

Sources, in order: `codecs/primitives/numerical_codec.dart:170-246`, `codecs/primitives/simple_primitives_codec.dart:32-660`, `codecs/collections/collection_codecs.dart:33-403`, `codecs/composite/composite_codecs.dart:40-473`, `codecs/special/special_codecs.dart:31-708`.

Two things follow that trip agents up:

- **The nested fixed-scale `ManagedDecimal` length prefix is mandatory.** Without it a sibling field in a struct cannot find its offset — the decoder would swallow the rest of the buffer (`special_codecs.dart:301-315`).
- **A struct's own encoding is the same top-level and nested**, because every field is already nested-encoded. Only the *fields* differ from their top-level forms.

```dart
void structLayout() {
  final BinaryCodec codec = BinaryCodec.withDefaults();

  final StructType deposit = StructType(
    name: 'Deposit',
    fieldDefinitions: <FieldDefinition>[
      FieldDefinition(name: 'amount', type: BigUIntType.type),
      FieldDefinition(name: 'token', type: TokenIdentifierType.type),
    ],
  );

  final StructValue value = StructValue(
    deposit,
    Fields(<Field>[
      Field(name: 'amount', value: BigUIntValue(BigInt.from(5))),
      Field(name: 'token', value: TokenIdentifierValue('WEGLD-bd4d79')),
    ]),
  );

  print(HexUtils.bytesToHex(codec.encodeTopLevel(value)));
}
```

Prints `00000001050000000c5745474c442d626434643739` — that is `[u32 1][0x05]` for the `BigUint`, then `[u32 12][WEGLD-bd4d79]` for the identifier.

```dart
void managedDecimal() {
  final AbiTypeFactory factory = AbiTypeFactory();
  final BinaryCodec codec = BinaryCodec.withDefaults();

  final ManagedDecimalType fixed =
      factory.fromString('ManagedDecimal<2>') as ManagedDecimalType;
  final ManagedDecimalType variable =
      factory.fromString('ManagedDecimal<usize>*4*') as ManagedDecimalType;
  print('${fixed.scale} ${fixed.isVariable} ${variable.isVariable}');

  final ManagedDecimalValue price =
      ManagedDecimalValue(BigInt.from(12345), scale: 2);
  print(HexUtils.bytesToHex(codec.encodeTopLevel(price)));
  print(HexUtils.bytesToHex(codec.encodeNested(price)));
}
```

Prints `2 false true`, `3039`, `000000023039`.

---

## 4. Argument slots: one hex part per top-level value

`ArgSerializer` turns a list of `TypedValue`s into the `@`-separated hex parts of a transaction's data field. Most values become exactly one part, but four shapes expand (`lib/src/abi/serializers/arg_serializer.dart:334-358`):

| Value | Parts emitted |
|---|---|
| `OptionalValue` provided | the inner value's parts |
| `OptionalValue` missing | **none** |
| `VariadicValue` not counted | one part per item |
| `VariadicValue` counted | a `u32` count part first, then one part per item |
| `MultiValueValue` | one part per inner value |
| `CompositeValue` | one part per field |
| anything else | one part = `encodeTopLevel(value)` |

```dart
void argumentSlots() {
  final ArgSerializer serializer = ArgSerializer();

  print(
    serializer.valuesToStrings(<TypedValue>[
      VariadicValue(
        <TypedValue>[U32Value(1), U32Value(2)],
        itemType: U32Type.type,
      ),
    ]),
  );

  print(
    serializer.valuesToStrings(<TypedValue>[
      VariadicValue.counted(
        <TypedValue>[U32Value(1), U32Value(2)],
        itemType: U32Type.type,
      ),
    ]),
  );

  print(
    serializer.valuesToStrings(<TypedValue>[
      OptionalValue.missing(OptionalType.of(U32Type.type)),
    ]),
  );

  print(
    serializer
        .createTypedValues(<dynamic>[7, 'hello'], <String>['u32', 'string'])
        .map((TypedValue v) => v.nativeValue)
        .toList(),
  );
}
```

Prints `[01, 02]`, `[02, 01, 02]`, `[]`, `[7, hello]`.

Note the counted form: the count is its own argument (`02`), **not** a prefix inside one buffer. That is why the single-buffer codec refuses to encode it at all.

`ArgumentEncoder._expandAndEncode` (`serializers/argument_encoder.dart:119-146`) — the path `controller.call`/`query` use when the controller has an ABI — applies the same four expansion rules as `ArgSerializer._handleValue` (`arg_serializer.dart:334-357`), in the same order, so the two produce identical parts for the same value. Both were run on each of these:

| Value | `ArgSerializer.valuesToStrings` | `ArgumentEncoder.encodeTypedValues` |
|---|---|---|
| `MultiValueValue(TokenIdentifier 'WEGLD-bd4d79', BigUint 10)` | `[5745474c442d626434643739, 0a]` | `[5745474c442d626434643739, 0a]` |
| `VariadicValue.counted([u32 1, u32 2])` | `[02, 01, 02]` | `[02, 01, 02]` |
| `OptionalValue.missing` | `[]` | `[]` |
| `CompositeValue(u32 1, bytes 0203)` | `[01, 0203]` | `[01, 0203]` |

Expansion is recursive on both paths, so a `MultiValueValue` nested inside a `VariadicValue` yields one part per member per item. `ArgSerializer` is also what the no-ABI `callRaw`/`queryRaw` path uses (`smart_contract/utils/argument_validation.dart:58-59`), so the same value reaches the wire identically with or without an ABI.

Useful `ArgSerializer` members (`arg_serializer.dart`): `valuesToBuffers(List<TypedValue>) → List<Uint8List>` (:324), `valuesToStrings(...) → List<String>` (:313), `valuesToString(...) → ValuesToStringResult` (:293), `stringToValues(String, List<ParameterDefinition>)` (:98), `buffersToValues(List<Uint8List>, List<ParameterDefinition>)` (:134), `createTypedValues(List<dynamic>, List<String>)` (:368). The separator constant is `ArgSerializer.argumentsSeparator == '@'` (:88).

`buffersToValues` throws `AbiArgumentSerializationException` if buffers remain after all parameters are consumed (:160-165).

---

## 5. `BigFloat`

`BigFloat` maps to Dart `double` for local arithmetic and display, and has **no wire codec at all**. The chain serialises it as an opaque arbitrary-precision-float blob (a version byte, a packed mode/accuracy/form/sign byte, precision, exponent, mantissa words) — not a decimal string — so no portable encoding exists (`lib/src/abi/types/primitives/big_float.dart:8-21`).

Consequences, each verified by running them:

| Operation | Result |
|---|---|
| `factory.fromString('BigFloat')` | works — an ABI that merely *mentions* `BigFloat` still loads |
| `BigFloatValue(1.5).nativeValue` | `1.5` (`double`) |
| `BigFloatValue(1.5).toBytes()` | throws `UnimplementedError` (`big_float.dart:85`) |
| `codec.encodeTopLevel(BigFloatValue(1.5))` | throws `AbiBinaryCodecException` |
| `codec.encodeNested(BigFloatValue(1.5))` | throws `AbiBinaryCodecException` |
| `codec.decodeTopLevel(bytes, BigFloatType.type)` | throws `AbiBinaryCodecException` |
| passing a `double` for a `BigFloat` endpoint parameter | throws — no native conversion exists: `AbiNativeSerializationException` from `NativeSerializer` (`_toPrimitiveValue` has no `BigFloatType` case, `native_serializer.dart:626-702`), surfacing as `ArgumentEncodingException` from `controller.call` |

Tests: `test/abi/types/primitives/big_float_test.dart:41-61`.

```dart
void bigFloatIsLocalOnly() {
  final BigFloatValue value = BigFloatValue(1.5);
  final double asDouble = value.nativeValue;
  print(asDouble);

  try {
    BinaryCodec.withDefaults().encodeTopLevel(value);
  } on AbiBinaryCodecException catch (e) {
    print('cannot encode BigFloat: ${e.message}');
  }

  try {
    value.toBytes();
  } on UnimplementedError catch (_) {
    print('toBytes always throws');
  }
}
```

There is no workaround inside this SDK. If a contract really takes a `BigFloat`, you cannot build the argument here.

---

## 6. Type-formula syntax you may have to write

`TypeFormulaParser.parseString` (`lib/src/abi/core/type_formula_parser.dart:314`) accepts:

| Form | Meaning |
|---|---|
| `Name` | plain type |
| `Name<A>` , `Name<A, B>` | type parameters, comma-separated, whitespace ignored |
| `Name<A>*meta*` | a trailing scalar metadatum, e.g. `ManagedDecimal<usize>*8*` → name `ManagedDecimal`, parameter `usize`, metadata `'8'` |
| `ManagedByteArray*48*` | metadata used as the length |

The lexer treats **only** `<`, `>` and `,` as punctuation, so an identifier may contain hyphens, digits and inner spaces — that is how `utf-8 string` and `counted-variadic` parse (`:128-146`).

Concrete formulas that resolve (all verified):

```
List<u32>            Option<Address>          optional<u64>
variadic<BigUint>    counted-variadic<u32>    multi<u32,bool>
MultiValue2<TokenIdentifier,BigUint>          tuple<u32,bool>
Array<u8,4>          array32<u8>              ManagedByteArray*48*
ManagedDecimal<8>    ManagedDecimal<usize>*4* ManagedDecimalSigned<2>
MultiArg<u32,bytes>  Tuple<u32, utf-8 string>
```

**Do not write `u32[5]`.** A `Type[N]` suffix is not accepted: it parses as one identifier named `u32[5]`, which is not a known type, and `fromString` throws `ArgumentError`. Use `Array<u32,5>`.

Unbalanced `<`/`>` or an empty formula throws `AbiTypeFormulaParseException` (`:316-325`). A metadata `*` that is never closed throws the same (`:359-363`).

---

## 7. Building values the serializer cannot infer

These constructors are for the `ArgSerializer` / `BinaryCodec` / no-ABI paths. An ABI-backed `controller.call` accepts them as endpoint arguments too, and encodes them exactly as §1.5 describes — but there only `ManagedByteArray<N>` *requires* a hand-built `TypedValue`: a variadic also takes a flat trailing run and a `multi<...>` also takes a plain Dart `List`. `BigFloatValue` is constructible on every path and encodable on none (§5).

```dart
List<TypedValue> explicitOnlyValues() {
  return <TypedValue>[
    MultiValueValue(
      MultiValueType(2, <AbiType>[TokenIdentifierType.type, BigUIntType.type]),
      <TypedValue>[
        TokenIdentifierValue('WEGLD-bd4d79'),
        BigUIntValue(BigInt.from(10)),
      ],
    ),
    ManagedByteArrayValue(ManagedByteArrayType(32), List<int>.filled(32, 0)),
    VariadicValue.counted(
      <TypedValue>[U32Value(1), U32Value(2)],
      itemType: U32Type.type,
    ),
    BigFloatValue(1.5),
  ];
}
```

Constructor shapes used above:

| Constructor | Signature |
|---|---|
| `MultiValueType` | `MultiValueType(int arity, List<AbiType> types)` |
| `MultiValueValue` | `MultiValueValue(MultiValueType type, List<TypedValue> values)` — throws `ArgumentError` if `values.length != type.arity` (`multi_value.dart:115-119`) |
| `ManagedByteArrayType` | `ManagedByteArrayType(int length)` |
| `ManagedByteArrayValue` | `ManagedByteArrayValue(ManagedByteArrayType type, List<int> bytes)` — throws `ArgumentError` unless `bytes.length == type.length` (`managed_byte_array.dart:109`) |
| `VariadicValue` | `VariadicValue(List<TypedValue> items, {required AbiType itemType, bool isCounted = false})` |
| `VariadicValue.counted` | `VariadicValue.counted(List<TypedValue> items, {required AbiType itemType})` |
| `OptionalValue.provided` / `.missing` | `OptionalValue.provided(OptionalType type, TypedValue value)` / `OptionalValue.missing(OptionalType type)` |
| `OptionValue.some` / `.none` | `OptionValue.some(OptionType type, TypedValue value)` / `OptionValue.none(OptionType type)` |
| `CompositeType.of` / `CompositeValue` | `CompositeType.of(List<AbiType> fieldTypes)` / `CompositeValue(CompositeType type, List<TypedValue> fields)` |
| `StructValue` | `StructValue(StructType type, Fields fields)` with `Fields(List<Field>)` and `Field(name: …, value: …)` |
| `ManagedDecimalValue` | `ManagedDecimalValue(BigInt value, {required int scale, bool isSigned = false, bool isVariable = false})` (`managed_decimal.dart:210-214`) |
| `ManagedDecimalType` | `.of(int scale)` / `.signed(int scale)` / `.variable(int scale, {bool isSigned = false})` |
| `VariadicType` | `.of(AbiType itemType)` / `.counted(AbiType itemType)` |
| `OptionalType.of` | `OptionalType.of(AbiType innerType)` |

`AbiType.createValue(dynamic)` (`lib/src/abi/core/type_system.dart:223`) is a **stricter, separate** path from the endpoint-argument conversion. Verified divergences: `U8Type.type.createValue('5')` throws while an endpoint parameter accepts `'5'`; `BytesType.type.createValue('0x0102')` returns the six UTF-8 bytes of the literal text while an endpoint parameter hex-decodes it to `[1, 2]`; `EnumType.createValue(1)` throws while an endpoint parameter accepts the discriminant; `ManagedDecimalType.of(2).createValue(123.45)` works while an endpoint parameter rejects a bare `double`. Use `createValue` only for hand-built values whose input shape you control.

---

## 8. What throws, and when

`AbiBinaryCodecException` unless noted. Constraints live in `lib/src/abi/codecs/codec_base.dart:14-20`: max buffer 16 MiB, max list length 1 000 000, max recursion depth 32.

| Operation | Throws when |
|---|---|
| `decodeTopLevel` | buffer longer than 16 MiB; the `AbiType` has no codec |
| `decodeNested` | you pass an explicit `depth:` > 32 (see below); offset outside the buffer; a decoder reports negative or over-long `bytesRead` |
| `encodeTopLevel` | result longer than 16 MiB; the `TypedValue` has no codec |
| `encodeNested` | you pass an explicit `depth:` > 32 (see below) |
| `Address` / `H256` top-level decode | buffer is not exactly 32 bytes |
| `CodeMetadata` decode | buffer is not exactly 2 bytes |
| `ManagedByteArray<N>` decode | buffer is not exactly `N` bytes (top-level) or fewer than `N` remain (nested) |
| enum encode | discriminant outside 0–255 |
| enum decode | no variant with that discriminant; empty buffer when discriminant 0 does not exist or carries fields |
| explicit-enum decode | variant name not declared |
| `Option` decode | top-level marker byte is neither empty nor `0x01`; nested marker is neither `0x00` nor `0x01` |
| `List` decode | nested count > 1 000 000; a top-level element consumes 0 bytes |
| `variadic` decode | an item consumes 0 bytes; top-level decode leaves trailing bytes unconsumed |
| `Optional<T>` `encodeNested` / `decodeNested` | **always** — the type is argument-position only |
| `MultiValue` `encodeNested` / `decodeNested` / `decodeTopLevel` | **always** — use `ArgSerializer.buffersToValues`, or `Tuple` for nested grouping |
| `counted-variadic` any codec path | **always** — go through `ArgSerializer` / `ArgumentEncoder` |
| `BigFloat` encode / decode / `toBytes` | **always** (§5) |
| `AbiTypeFactory.fromString` | `ArgumentError` for an unknown name (the message lists near-miss suggestions and the registered custom types), for bare `struct`/`enum`/`ExplicitEnum`, and for `ManagedByteArray` with no length |
| `TypeFormulaParser.parseString` | `AbiTypeFormulaParseException` for empty input, unbalanced `<>`, or an unterminated `*meta` |
| `ArgSerializer.buffersToValues` | `AbiArgumentSerializationException` on decode failure or leftover buffers |
| `NativeSerializer.nativeToTypedValues` | `AbiNativeSerializationException` on argument-count mismatch or an unconvertible value |

Two families of guard fire **earlier and with a different exception** than the codec:

- **Range and shape are enforced by the `TypedValue` constructor, as `ArgumentError`.** `U8Value(300)`, `I8Value(200)`, `U64Value(BigInt.two.pow(64))`, `BigUIntValue(BigInt.from(-1))`, `ArrayValue` with the wrong element count and `StructValue` with a missing field all throw before any codec runs, so the codec's own range check (`numerical_codec.dart:367-431`) is unreachable through the public constructors. Catch `ArgumentError`, not `AbiBinaryCodecException`, when you build values from untrusted input.
- **The depth limit only inspects the argument you pass.** `BinaryCodecConstraints.checkRecursionDepth` is evaluated once against the incoming `depth` (`binary_codec.dart:434`, `:282`), and the sub-codecs each restart from 0, so nesting does not accumulate: a 40-deep `Option<Option<…<u32>>>` encodes and decodes without complaint, while `encodeNested(value, depth: 40)` throws. Do not rely on this limit to stop a hostile buffer.

---

## Not verified

- The exact byte layout the chain uses for `BigFloat` is described in the source only as an opaque blob; nothing here was checked against a node, and this SDK cannot produce or consume it either way.
- Of the nested argument-position types, only `variadic<multi<...>>` was exercised (§1.5). Deeper nestings — `variadic<variadic<...>>`, `optional<multi<...>>` — were not.
- `EgldOrMultiEsdtPayment` encoding was checked only in one direction (a value with an empty `multi_esdt` list encodes to `000000010300000000`); no decode was run and no non-empty list was exercised.
- No buffer produced by a real contract was decoded. Nested offsets were exercised only against buffers this SDK encoded itself (a two-field struct round-tripped field for field), and every hex column in §3 is this SDK's own output, not a capture from a node.
- The `ArgSerializer`/`BinaryCodec` behaviour of custom `AbiType` subclasses written outside this package is undefined here.
