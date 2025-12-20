---
id: primitive-types
title: Primitive Types
sidebar_position: 2
description: Work with MultiversX primitive ABI types including unsigned/signed integers, BigInt, Bool, and Bytes.
---

# Primitive Types

Primitive types are the building blocks of MultiversX smart contract data.

## Value Creation Methods

There are three ways to create any type value:

```dart
// Method 1: Static factory - Type.create(value)
final u64_1 = U64Type.create(1000);

// Method 2: Direct constructor - ValueClass(value)
final u64_2 = U64Value(BigInt.from(1000));

// Method 3: Via type singleton - Type.type.createValue(value)
final u64_3 = U64Type.type.createValue(1000);
```

## Unsigned Integers

### Fixed-Size Unsigned

```dart
// U8: 0 to 255 (takes int)
final u8 = U8Type.create(255);
print(u8.nativeValue); // 255

// U16: 0 to 65,535 (takes int)
final u16 = U16Type.create(65535);

// U32: 0 to 4,294,967,295 (takes int)
final u32 = U32Type.create(4294967295);

// U64: 0 to 18,446,744,073,709,551,615 (takes int or BigInt)
final u64 = U64Type.create(BigInt.parse('18446744073709551615'));
final u64_small = U64Type.create(1000); // int also works
```

### All Three Creation Methods

```dart
// U32 example - all equivalent
final u32_1 = U32Type.create(1000);           // Static factory
final u32_2 = U32Value(1000);                  // Direct constructor
final u32_3 = U32Type.type.createValue(1000); // Via type singleton

// U64 example - all equivalent
final u64_1 = U64Type.create(BigInt.from(500));           // Static factory
final u64_2 = U64Value(BigInt.from(500));                  // Direct constructor
final u64_3 = U64Type.type.createValue(BigInt.from(500)); // Via type singleton
```

### BigUInt (Arbitrary Precision)

For values larger than U64, use `BigUInt`:

```dart
// Accepts int or BigInt
final small = BigUIntType.create(42); // int works
final large = BigUIntType.create(
  BigInt.parse('999999999999999999999999999999999999999')
);

// Common use: token amounts (18 decimals)
final oneEgld = BigUIntType.create(
  BigInt.parse('1000000000000000000') // 10^18
);

// Direct constructor requires BigInt
final value = BigUIntValue(BigInt.from(100));
```

## Signed Integers

### Fixed-Size Signed

```dart
// I8: -128 to 127 (takes int)
final i8 = I8Type.create(-128);
print(i8.nativeValue); // -128

// I16: -32,768 to 32,767 (takes int)
final i16 = I16Type.create(-32768);

// I32: -2,147,483,648 to 2,147,483,647 (takes int)
final i32 = I32Type.create(-2147483648);

// I64: full 64-bit signed range (takes int or BigInt)
final i64_small = I64Type.create(1000000); // int works
final i64_large = I64Type.create(BigInt.parse('-5000000000000')); // BigInt for large
```

### BigInt (Arbitrary Precision Signed)

```dart
// Accepts int or BigInt
final small = BigIntType.create(-42); // int works
final large = BigIntType.create(
  BigInt.parse('-999999999999999999999999999999')
);

// Direct constructor requires BigInt
final value = BigIntValue(BigInt.from(-100));
```

## Boolean

```dart
// Using static factory
final trueVal = BooleanType.create(true);
print(trueVal.nativeValue); // true

// Using direct constructor
final falseVal = BooleanValue(false);
print(falseVal.nativeValue); // false

// Via type singleton
final boolVal = BooleanType.type.createValue(true);
```

## Strings

ManagedBuffer strings (UTF-8 encoded):

```dart
// Static factory
final str = StringType.create('Hello, MultiversX!');
print(str.nativeValue); // 'Hello, MultiversX!'

// Direct constructor
final str2 = StringValue('Direct string');

// Via type singleton
final str3 = StringType.type.createValue('Via type');
```

## Bytes

Raw byte arrays:

```dart
// From list of ints
final bytes = BytesType.create([0x48, 0x65, 0x6c, 0x6c, 0x6f]);
print(bytes.nativeValue); // [72, 101, 108, 108, 111]

// Direct constructor
final bytes2 = BytesValue([1, 2, 3, 4]);

// From UTF-8 string
final bytes3 = BytesValue.fromUTF8('Hello');

// From hex string
final bytes4 = BytesValue.fromHex('48656c6c6f');

// Convert back
print(bytes3.toUTF8()); // 'Hello'
print(bytes4.toHex()); // '48656C6C6F'
```

## Type Ranges Reference

| Type | Min | Max | Bytes |
|------|-----|-----|-------|
| U8 | 0 | 255 | 1 |
| U16 | 0 | 65,535 | 2 |
| U32 | 0 | 4,294,967,295 | 4 |
| U64 | 0 | ~1.8 × 10^19 | 8 |
| BigUInt | 0 | Unlimited | Variable |
| I8 | -128 | 127 | 1 |
| I16 | -32,768 | 32,767 | 2 |
| I32 | -2.1 × 10^9 | 2.1 × 10^9 | 4 |
| I64 | -9.2 × 10^18 | 9.2 × 10^18 | 8 |
| BigInt | Unlimited | Unlimited | Variable |

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() {
  // === Unsigned integers (U8/U16/U32 take int) ===
  final u8 = U8Type.create(255);
  final u16 = U16Type.create(65535);
  final u32 = U32Type.create(4294967295);
  
  // U64 accepts int or BigInt
  final u64_small = U64Type.create(1000000);
  final u64_large = U64Type.create(BigInt.parse('18446744073709551615'));
  
  // BigUInt accepts int or BigInt
  final oneEgld = BigUIntType.create(BigInt.parse('1000000000000000000'));
  
  // === Signed integers (I8/I16/I32 take int) ===
  final i8 = I8Type.create(-128);
  final i16 = I16Type.create(-32768);
  final i32 = I32Type.create(-2147483648);
  
  // I64 accepts int or BigInt
  final i64 = I64Type.create(BigInt.parse('-9223372036854775808'));
  
  // === Three creation methods ===
  // Method 1: Static factory
  final val1 = U32Type.create(100);
  
  // Method 2: Direct constructor
  final val2 = U32Value(200);
  
  // Method 3: Via type singleton
  final val3 = U32Type.type.createValue(300);
  
  // === Other primitives ===
  final boolVal = BooleanType.create(true);
  final strVal = StringType.create('Hello');
  final bytesVal = BytesType.create([1, 2, 3]);
  
  print('U32: ${val1.nativeValue}, ${val2.nativeValue}, ${val3.nativeValue}');
}
```

## Best Practices

:::tip Choose the Right Type
- Use fixed-size types (U32, U64) when values fit - more efficient
- Use BigUInt for token amounts (they use 18 decimals)
- Use BigInt only when negative arbitrary precision is needed
:::

:::caution Overflow
Fixed-size types will throw if values exceed their range:
```dart
// This will throw ArgumentError
// final u8 = U8Type.create(256); // Max is 255!

// Use appropriate type
final u16 = U16Type.create(256); // OK - fits in U16
```
:::

:::info Type Parameter Reference
| Type | Parameter Type | Notes |
|------|---------------|-------|
| U8, U16, U32 | `int` | Native Dart int |
| I8, I16, I32 | `int` | Native Dart int |
| U64, I64 | `int` or `BigInt` | Auto-converts int to BigInt |
| BigUInt, BigInt | `int` or `BigInt` | Auto-converts int to BigInt |
:::

## Next Steps

- [Collection Types](/docs/abi-types/collection-types) - Lists, arrays, options
- [Composite Types](/docs/abi-types/composite-types) - Structs, enums, tuples
- [Special Types](/docs/abi-types/special-types) - Address, tokens, etc.
