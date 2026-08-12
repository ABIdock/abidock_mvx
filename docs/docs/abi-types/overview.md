---
id: overview
title: ABI Types Overview
sidebar_position: 1
description: MultiversX ABI type system for encoding and decoding smart contract data in Dart.
---

# ABI Types

MultiversX smart contracts use a rich type system for encoding and decoding data. abidock_mvx
implements the whole of it: every type in a contract's ABI maps to an `AbiType` (the description)
and a `TypedValue` (an instance of it).

## Type Categories

| Category | Types | Description |
|----------|-------|-------------|
| **Primitive** | u8-u64, i8-i64, BigUint, BigInt, bool, bytes, utf-8 string | Basic value types |
| **Collection** | `List<T>`, `array<N>`, `Option<T>` | Container types |
| **Composite** | struct, tuple, enum, explicit-enum | Structured types |
| **Special** | Address, TokenIdentifier, H256, CodeMetadata, ManagedDecimal, ManagedByteArray | Domain-specific types |
| **Argument-shape** | `variadic<T>`, `optional<T>`, `multi<...>`, `MultiArg`/`MultiResult` | Only valid at the argument boundary |

Built-in framework types the contract's ABI never spells out are recognised intrinsically:
`EsdtTokenPayment`, `EgldOrEsdtTokenPayment`, `EgldOrMultiEsdtPayment`, `Payment`,
`FungiblePayment`, `TokenId` (a `TokenIdentifier`) and `NonZeroBigUint` (a `BigUint`).

## Two encodings for every type

The chain encodes each value in one of two ways, and the difference is the single most important
thing to understand about this type system:

- **Top-level** - the value owns a whole buffer (a transaction argument, or one return-data part).
  Its length is implied by the buffer, so lengths and zeroes can be omitted: a zero integer is an
  *empty* buffer, `false` is an *empty* buffer, `None` is an *empty* buffer.
- **Nested** - the value sits inside a larger buffer (a struct field, a list element, a tuple slot).
  Nothing else knows where it ends, so it is written self-delimiting: fixed-width integers, explicit
  4-byte big-endian length prefixes, explicit marker bytes.

| Type | Top-level | Nested |
|------|-----------|--------|
| `u8`/`u16`/`u32`/`u64` | minimal big-endian bytes, zero = empty | fixed 1 / 2 / 4 / 8 bytes, big-endian |
| `i8`/`i16`/`i32`/`i64` | minimal two's-complement, zero = empty | fixed 1 / 2 / 4 / 8 bytes, two's-complement |
| `BigUint` | magnitude bytes, zero = empty | `[u32 length][magnitude]` |
| `BigInt` | two's-complement bytes, zero = empty | `[u32 length][two's-complement]` |
| `bool` | `0x01` for true, empty for false | 1 byte: `0x01` / `0x00` |
| `bytes`, `utf-8 string` | raw bytes | `[u32 length][bytes]` |
| `Address` | 32 bytes | 32 bytes |
| `TokenIdentifier` | UTF-8 bytes | `[u32 length][UTF-8]` |
| `Option<T>` | empty = `None`, else `0x01` + nested `T` | `0x00` = `None`, else `0x01` + nested `T` |
| `List<T>` | items concatenated, nested-encoded | `[u32 count]` + items nested-encoded |
| `array<N,T>` | N items nested-encoded | N items nested-encoded |
| struct / tuple | fields nested-encoded, in declaration order | same |
| enum | empty for unit variant 0, else discriminant byte + nested fields | discriminant byte + nested fields |
| explicit-enum | UTF-8 variant **name** | `[u32 length][UTF-8 variant name]` |

Each type page repeats the rule that matters for it, and the codec doc comments in
`lib/src/abi/codecs/` are the authoritative specification.

## Creating Values

There are three ways to create any value:

```dart
// Method 1: Static factory - Type.create(value)
final value1 = U64Type.create(123); // int or BigInt for U64

// Method 2: Direct constructor - ValueClass(value)
final value2 = U64Value(BigInt.from(123)); // BigInt required

// Method 3: Via type instance - type.createValue(value)
final value3 = U64Type.type.createValue(123);

// Access the native Dart value
print(value1.nativeValue); // BigInt 123
```

:::note `createValue` returns `TypedValue`
`AbiType.createValue` is declared to return the base `TypedValue`, because a type instance is only
known at runtime. Cast when you need the concrete API (`as StructValue`, `as ListValue`, ...). The
static `Type.create(...)` factories return the concrete value class directly, so they need no cast.
:::

## Type Parameter Reference

| Type | `create()` accepts | Value constructor |
|------|------------------|-------------------|
| u8, u16, u32 | `int` | `int` |
| i8, i16, i32 | `int` | `int` |
| u64, i64 | `int` or `BigInt` | `BigInt` |
| BigUint, BigInt | `int` or `BigInt` | `BigInt` |

## Native Value Conversion

Every `TypedValue` exposes `.nativeValue`:

| ABI value | `.nativeValue` type |
|-----------|---------------------|
| `U8Value` - `U32Value`, `I8Value` - `I32Value` | `int` |
| `U64Value`, `I64Value`, `BigUIntValue`, `BigIntValue` | `BigInt` |
| `BooleanValue` | `bool` |
| `StringValue` | `String` |
| `BytesValue`, `H256Value`, `ManagedByteArrayValue` | `Uint8List` |
| `AddressValue` | `String` (bech32) |
| `TokenIdentifierValue` | `String` |
| `CodeMetadataValue` | `int` (16-bit flags) |
| `ManagedDecimalValue` | `BigInt` (raw, unscaled) |
| `ListValue`, `ArrayValue`, `TupleValue` | `List<dynamic>` |
| `OptionValue`, `OptionalValue` | inner native value, or `null` |
| `StructValue` | `Map<String, dynamic>` |
| `EnumValue` | `String` (unit variant) or `Map<String, dynamic>` |
| `ExplicitEnumValue` | `String` (variant name) |
| `VariadicValue` | `List<TypedValue>` (items keep their types) |

## Quick Reference

### Integers

```dart
// Unsigned integers (u8/u16/u32 take int)
final u8 = U8Type.create(255);
final u16 = U16Type.create(65535);
final u32 = U32Type.create(4294967295);

// u64 takes int or BigInt
final u64 = U64Type.create(BigInt.parse('18446744073709551615'));
final u64Small = U64Type.create(1000); // int also works

// Big unsigned (arbitrary precision, takes int or BigInt)
final bigUint = BigUIntType.create(BigInt.parse('999999999999999999999'));

// Signed integers (i8/i16/i32 take int)
final i8 = I8Type.create(-128);
final i32 = I32Type.create(-2147483648);

// i64 and BigInt take int or BigInt
final i64 = I64Type.create(BigInt.from(-5000000000000));
final bigInt = BigIntType.create(BigInt.from(-999999));
```

### Boolean & String

```dart
final flag = BooleanType.create(true);
final str = StringType.create('Hello, MultiversX!');
```

### Address

```dart
// From bech32 string directly
final address = AddressType.create('erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu');

// Or from hex string
final addressHex = AddressType.create('0000000000000000000000000000000000000000000000000000000000000000');

// Or from bytes
final addressBytes = AddressType.create(List<int>.filled(32, 0));
```

### Collections

```dart
// Define a list type, then create a value
final listType = ListType(U64Type.type);
final list = listType.createValue(<BigInt>[
  BigInt.from(1),
  BigInt.from(2),
  BigInt.from(3),
]) as ListValue;

// Define an option type, then create Some or None
final optionType = OptionType(U64Type.type);
final some = optionType.createValue(BigInt.from(42)) as OptionValue; // Some(42)
final none = optionType.createValue(null) as OptionValue;            // None
```

### Struct

```dart
// Define a struct type, then create a value
final userType = StructBuilder('User')
    .field('name', StringType.type)
    .field('balance', BigUIntType.type)
    .build();

final user = userType.createValue(<String, dynamic>{
  'name': 'Alice',
  'balance': BigInt.from(1000),
}) as StructValue;
```

### Enum

```dart
// Define enum type with simple variants
final statusType = EnumBuilder('Status')
    .variant('Active', 0)
    .variant('Inactive', 1)
    .build();

// Create a value
final status = statusType.createValue('Active') as EnumValue;

// Enum with fields
final resultType = EnumBuilder('Result')
    .variantWithFields('Ok', 0, <AbiType>[U64Type.type])
    .variantWithFields('Err', 1, <AbiType>[StringType.type])
    .build();

// Create a value with fields
final result = resultType.createValue(<String, dynamic>{
  'variant': 'Ok',
  'fields': <dynamic>[BigInt.from(42)],
}) as EnumValue;
```

## Working with Contract Results

`controller.query()` returns a `QueryResult` that carries both representations:

```dart
final result = await controller.query(
  endpointName: 'getUser',
  arguments: <dynamic>[],
);

// `values` / `first` are native Dart values: a struct arrives as a Map.
final userMap = result.first as Map<String, dynamic>;
print(userMap['name']);

// `typedValues` keeps the ABI types, for when you need the type metadata.
final user = result.typedValues.first as StructValue;
final name = user.getFieldValue('name').nativeValue as String;
final balance = user.getFieldValue('balance').nativeValue as BigInt;
```

`getFieldValue` throws `ArgumentError` for an unknown field name; use `tryGetFieldValue` when the
field may be absent.

## Next Steps

- [Primitive Types](/docs/abi-types/primitive-types) - Numbers, booleans, strings
- [Collection Types](/docs/abi-types/collection-types) - Lists, arrays, options
- [Composite Types](/docs/abi-types/composite-types) - Structs, enums, tuples
- [Special Types](/docs/abi-types/special-types) - Address, tokens, etc.
- [Mixed & Nested Types](/docs/abi-types/mixed-nested-types) - Complex combinations
