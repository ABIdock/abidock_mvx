---
id: overview
title: ABI Types Overview
sidebar_position: 1
description: MultiversX ABI type system for encoding and decoding smart contract data in Dart.
---

# ABI Types

MultiversX smart contracts use a rich type system for encoding and decoding data. abidock_mvx provides complete support for all ABI types.

## Type Categories

| Category | Types | Description |
|----------|-------|-------------|
| **Primitive** | U8-U64, I8-I64, BigUInt, BigInt, Bool, Bytes | Basic value types |
| **Collection** | List, Array, Option | Container types |
| **Composite** | Struct, Tuple, Enum | Complex structured types |
| **Special** | Address, TokenIdentifier, H256, etc. | Domain-specific types |

## Creating Values

There are three ways to create any type value:

```dart
// Method 1: Static factory - Type.create(value)
final value1 = U64Type.create(123); // int or BigInt for U64

// Method 2: Direct constructor - ValueClass(value)
final value2 = U64Value(BigInt.from(123)); // BigInt required

// Method 3: Via type singleton - Type.type.createValue(value)
final value3 = U64Type.type.createValue(123);

// Access the native Dart value
print(value1.nativeValue); // 123 (BigInt)
```

## Type Parameter Reference

| Type | create() accepts | Value constructor |
|------|------------------|-------------------|
| U8, U16, U32 | `int` | `int` |
| I8, I16, I32 | `int` | `int` |
| U64, I64 | `int` or `BigInt` | `BigInt` |
| BigUInt, BigInt | `int` or `BigInt` | `BigInt` |

## Type Singleton Access

Access type definitions via singletons:

```dart
// Using singleton type accessor with createValue
final u64Value = U64Type.type.createValue(42);

// Using static create (shorthand - preferred)
final u64Value = U64Type.create(42);
```

## Native Value Conversion

Every `TypedValue` can convert to native Dart types:

| ABI Type | `.nativeValue` Type |
|----------|---------------------|
| `U8Value` - `U32Value` | `int` |
| `U64Value` | `BigInt` |
| `BigUIntValue` | `BigInt` |
| `BooleanValue` | `bool` |
| `StringValue` | `String` |
| `BytesValue` | `List<int>` |
| `AddressValue` | `String` (bech32) |
| `ListValue` | `List<dynamic>` |
| `OptionValue` | `dynamic?` |
| `StructValue` | `Map<String, dynamic>` |

## Quick Reference

### Integers

```dart
// Unsigned integers (U8/U16/U32 take int)
final u8 = U8Type.create(255);
final u16 = U16Type.create(65535);
final u32 = U32Type.create(4294967295);

// U64 takes int or BigInt
final u64 = U64Type.create(BigInt.parse('18446744073709551615'));
final u64_small = U64Type.create(1000); // int also works

// Big unsigned (arbitrary precision, takes int or BigInt)
final bigUint = BigUIntType.create(BigInt.parse('999999999999999999999'));

// Signed integers (I8/I16/I32 take int)
final i8 = I8Type.create(-128);
final i32 = I32Type.create(-2147483648);

// I64 and BigInt take int or BigInt
final i64 = I64Type.create(BigInt.from(-5000000000000));
final bigInt = BigIntType.create(BigInt.from(-999999));
```

### Boolean & String

```dart
final bool = BooleanType.create(true);
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
final list = listType.createValue([
  BigInt.from(1),
  BigInt.from(2),
  BigInt.from(3),
]);

// Define an option type, then create Some or None
final optionType = OptionType(U64Type.type);
final some = optionType.createValue(BigInt.from(42)); // Some(42)
final none = optionType.createValue(null);            // None
```

### Struct

```dart
// Define a struct type, then create a value
final userType = StructBuilder('User')
    .field('name', StringType.type)
    .field('balance', BigUIntType.type)
    .build();

final user = userType.createValue({
  'name': 'Alice',
  'balance': BigInt.from(1000),
});
```

### Enum

```dart
// Define enum type with simple variants
final statusType = EnumBuilder('Status')
    .variant('Active', 0)
    .variant('Inactive', 1)
    .build();

// Create a value
final status = statusType.createValue('Active');

// Enum with fields
final resultType = EnumBuilder('Result')
    .variantWithFields('Ok', 0, [U64Type.type])
    .variantWithFields('Err', 1, [StringType.type])
    .build();

// Create a value with fields
final result = resultType.createValue({
  'variant': 'Ok',
  'fields': [BigInt.from(42)],
});
```

## Working with Contract Results

When querying contracts, decode the returned values:

```dart
final result = await controller.query(
  endpointName: 'getUser',
  arguments: [],
);

// Access result by index
final user = result.first as StructValue;

// Access fields
final name = user.getFieldValue('name')?.nativeValue as String;
final balance = user.getFieldValue('balance')?.nativeValue as BigInt;
```

## Next Steps

- [Primitive Types](/docs/abi-types/primitive-types) - Numbers, booleans, strings
- [Collection Types](/docs/abi-types/collection-types) - Lists, arrays, options
- [Composite Types](/docs/abi-types/composite-types) - Structs, enums, tuples
- [Special Types](/docs/abi-types/special-types) - Address, tokens, etc.
- [Mixed & Nested Types](/docs/abi-types/mixed-nested-types) - Complex combinations
