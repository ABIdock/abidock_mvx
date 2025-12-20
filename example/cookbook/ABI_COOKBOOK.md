---
id: abi-types-cookbook
title: ABI Types Cookbook
---

[comment]: # (mx-abstract)

[comment]: # (mx-context-auto)

## Overview

This guide walks you through handling all ABI types in the MultiversX Dart SDK, with creation examples and native value conversions.

## Type Categories

| Category | Types | Description |
| -------- | ----- | ----------- |
| **Primitives** | U8, U16, U32, U64, BigUInt, I8, I16, I32, I64, BigInt, Boolean, String, Bytes, Address | Basic scalar and binary types |
| **Collections** | List, Array, Option | Container types with elements |
| **Composite** | Struct, Tuple, Enum | Complex structured types |
| **Special** | TokenIdentifier, EgldOrEsdtTokenIdentifier, H256, Nothing, ManagedDecimal, Optional, Variadic, CodeMetadata | Domain-specific types |

[comment]: # (mx-context-auto)

## Primitive Types

### Unsigned Integers (U8, U16, U32, U64)

Fixed-size unsigned integers with range validation. The native value returns `int` for U8/U16/U32 and `BigInt` for U64.

```dart
// U8: 0 to 255
final u8 = U8Type.create(255);
print(u8.nativeValue);              // 255 (int)
print(u8.toBytes());                // [255]

// U16: 0 to 65535
final u16 = U16Type.create(65535);
print(u16.nativeValue);             // 65535 (int)

// U32: 0 to 4294967295
final u32 = U32Type.create(1000000);
print(u32.nativeValue);             // 1000000 (int)

// U64: 0 to 18446744073709551615
final u64 = U64Type.create(BigInt.parse('18446744073709551615'));
print(u64.nativeValue);             // BigInt
```

### Signed Integers (I8, I16, I32, I64)

Fixed-size signed integers supporting negative values.

```dart
// I8: -128 to 127
final i8 = I8Type.create(-128);
print(i8.nativeValue);              // -128 (int)

// I16: -32768 to 32767
final i16 = I16Type.create(-32768);
print(i16.nativeValue);             // -32768 (int)

// I32: -2147483648 to 2147483647
final i32 = I32Type.create(-42);
print(i32.nativeValue);             // -42 (int)

// I64: full 64-bit signed range
final i64 = I64Type.create(BigInt.from(-9223372036854775808));
print(i64.nativeValue);             // BigInt
```

### Arbitrary Precision (BigUInt, BigInt)

Variable-size integers with no maximum limit.

```dart
// BigUInt: unsigned, any size
final bigUint = BigUIntType.create(BigInt.parse('999999999999999999999999'));
print(bigUint.nativeValue);         // BigInt (positive)
print(bigUint.toBytes());           // Minimal encoding, no leading zeros

// BigInt: signed, any size
final bigInt = BigIntType.create(BigInt.parse('-999999999999999999999999'));
print(bigInt.nativeValue);          // BigInt (negative)
```

:::tip
Use `BigUIntType` for token amounts and balances. Zero encodes to empty bytes.
:::

### Boolean

Single-byte true/false encoding.

```dart
final trueVal = BooleanType.create(true);
final falseVal = BooleanType.create(false);

print(trueVal.nativeValue);         // true (bool)
print(falseVal.nativeValue);        // false (bool)
print(trueVal.toBytes());           // [1]
print(falseVal.toBytes());          // [0]

// Check getters
print(trueVal.isTrue);              // true
print(falseVal.isFalse);            // true
```

### String

UTF-8 encoded text strings.

```dart
final str = StringType.create('Hello MultiversX');
print(str.nativeValue);             // "Hello MultiversX" (String)
print(str.length);                  // 16

// Alternative constructors
final str2 = StringValue.fromUTF8('Test String');
final str3 = StringValue.fromHex('48656c6c6f');  // "Hello"
print(str3.nativeValue);            // "Hello"
```

### Bytes

Variable-length binary data.

```dart
// From byte array
final bytes = BytesType.create([72, 101, 108, 108, 111]);
print(bytes.nativeValue);           // [72, 101, 108, 108, 111] (List<int>)
print(bytes.toUTF8());              // "Hello"
print(bytes.toHex());               // "48656C6C6F"

// Alternative constructors
final bytes2 = BytesValue.fromUTF8('Hello');
final bytes3 = BytesValue.fromHex('48656c6c6f');
```

### Address

32-byte MultiversX addresses (bech32 or hex).

```dart
// From bech32 string
final addr = AddressType.create(
  'erd1qqqqqqqqqqqqqpgqhe8t5jewej70zupmh44jurgn29psua5l2jps3ntjj3'
);
print(addr.toBech32());             // erd1qqqqqq...
print(addr.toHex());                // hex representation
print(addr.nativeValue);            // "erd1qqqqqq..." (bech32 String)

// From hex string
final addr2 = AddressType.create(
  '0139472eff6886771a982f3083da5d421f24c29181e63888228dc81ca60d69e1'
);

// From bytes
final addr3 = AddressType.create(List<int>.filled(32, 0));
```

[comment]: # (mx-context-auto)

## Collection Types

### List (Variable-Length)

Dynamic-size collection of same-type elements.

```dart
final listType = ListType(U32Type.type);

// Create from native list
final list = listType.createValue([10, 20, 30, 40]);
print(list.nativeValue);            // [10, 20, 30, 40] (List<dynamic>)

// Access elements
final listValue = list as ListValue;
print(listValue.length);            // 4
print(listValue[0].nativeValue);    // 10
print(listValue.isEmpty);           // false

// Nested lists
final nestedType = ListType(ListType(U8Type.type));
final nested = nestedType.createValue([[1, 2], [3, 4, 5]]);
```

### Array (Fixed-Length)

Fixed-size collection with compile-time known length.

```dart
final arrayType = ArrayType(U32Type.type, 3);

// Must provide exactly 3 elements
final array = arrayType.createValue([100, 200, 300]);
print(array.nativeValue);           // [100, 200, 300]

// Access elements
final arrayValue = array as ArrayValue;
print(arrayValue.length);           // 3
print(arrayValue[1].nativeValue);   // 200

// This throws: wrong length
// arrayType.createValue([1, 2]);   // ArgumentError
```

### Option (Nullable)

Rust-style Option with Some/None variants.

```dart
final optionType = OptionType(U32Type.type);

// Some variant (has value)
final some = optionType.createValue(42);
print(some.nativeValue);            // 42

final someVal = some as OptionValue;
print(someVal.isSome);              // true
print(someVal.isNone);              // false
print(someVal.unwrap().nativeValue);// 42

// None variant (no value)
final none = optionType.createValue(null);
print(none.nativeValue);            // null

final noneVal = none as OptionValue;
print(noneVal.isNone);              // true
// noneVal.unwrap();                // throws StateError
```

[comment]: # (mx-context-auto)

## Composite Types

### Struct

Named fields with specific types.

```dart
// Define struct type
final userType = StructType(
  name: 'User',
  fieldDefinitions: [
    FieldDefinition(name: 'name', type: StringType.type),
    FieldDefinition(name: 'age', type: U32Type.type),
    FieldDefinition(name: 'active', type: BooleanType.type),
  ],
);

// Create from Map (preferred)
final user = userType.createValue({
  'name': 'Alice',
  'age': 30,
  'active': true,
});
print(user.nativeValue);            // {name: Alice, age: 30, active: true}

// Create from List (field order must match)
final user2 = userType.createValue(['Bob', 25, false]);

// Access fields
final userVal = user as StructValue;
print(userVal.getFieldValue('name').nativeValue);  // "Alice"
print(userVal.getFieldValue('age').nativeValue);   // 30
```

#### Using StructBuilder

A fluent API for building struct types.

```dart
final personType = StructBuilder('Person')
    .field('name', StringType.type)
    .field('age', U32Type.type)
    .field('address', AddressType.type)
    .build();

final person = personType.createValue({
  'name': 'Charlie',
  'age': 35,
  'address': 'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
});
```

### Tuple

Ordered, unnamed elements accessed by index.

```dart
// Define tuple type
final tupleType = TupleType([
  U32Type.type,
  StringType.type,
  BooleanType.type,
]);

// Create from List
final tuple = tupleType.createValue([42, 'test', true]);
print(tuple.nativeValue);           // [42, test, true]

// Access by index
final tupleVal = tuple as TupleValue;
print(tupleVal.arity);              // 3
print(tupleVal[0].nativeValue);     // 42
print(tupleVal[1].nativeValue);     // "test"
print(tupleVal[2].nativeValue);     // true

// Destructure
final [id, name, flag] = tupleVal.destructure();
```

### Enum

Discriminated unions with variants.

```dart
// Simple enum (no data)
final statusType = EnumType(
  name: 'Status',
  variants: [
    const EnumVariantDefinition(name: 'Pending', discriminant: 0),
    const EnumVariantDefinition(name: 'Active', discriminant: 1),
    const EnumVariantDefinition(name: 'Completed', discriminant: 2),
  ],
);

final pending = statusType.createValue('Pending');
print(pending.nativeValue);         // "Pending" (variant name for simple enums)

// Enum with data fields
final resultType = EnumType(
  name: 'Result',
  variants: [
    const EnumVariantDefinition(name: 'Ok', discriminant: 0),
    EnumVariantDefinition(
      name: 'Error',
      discriminant: 1,
      fields: [U32Type.type, StringType.type],
    ),
  ],
);

// Create simple variant
final ok = resultType.createValue('Ok');

// Create variant with data
final error = resultType.createValue({
  'variant': 'Error',
  'fields': [404, 'Not Found'],
});
print(error.nativeValue);           // {variant: Error, discriminant: 1, fields: [404, Not Found]}
```

#### Using EnumBuilder

A fluent API for building enum types.

```dart
final actionType = EnumBuilder('Action')
    .variant('None', 0)
    .variantWithFields('Transfer', 1, [AddressType.type, BigUIntType.type])
    .variant('Burn', 2)
    .variantWithFields('Mint', 3, [BigUIntType.type])
    .build();

final transfer = actionType.createValue({
  'variant': 'Transfer',
  'fields': [
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
    BigInt.from(1000000),
  ],
});
```

[comment]: # (mx-context-auto)

## Special Types

### TokenIdentifier

ESDT token identifiers (excludes EGLD).

```dart
// From string
final token = TokenIdentifierType.create('WEGLD-bd4d79');
print(token.identifier);            // "WEGLD-bd4d79"
print(token.ticker);                // "WEGLD"
print(token.randomPart);            // "bd4d79"
print(token.nativeValue);           // "WEGLD-bd4d79" (String)

// From bytes
final token2 = TokenIdentifierValue.fromBytes('USDC-c76f1f'.codeUnits);

// Access type singleton
final type = TokenIdentifierType.type;
final value = type.createValue('MEX-455c57');
```

:::caution
`TokenIdentifierType` does NOT accept "EGLD". Use `EgldOrEsdtTokenIdentifierType` for mixed scenarios.
:::

### EgldOrEsdtTokenIdentifier

Token identifier that accepts both EGLD and ESDT tokens.

```dart
// EGLD native token
final egld = EgldOrEsdtTokenIdentifierType.create('EGLD');
print(egld.isEgld);                 // true
print(egld.isEsdt);                 // false
print(egld.ticker);                 // "EGLD"
print(egld.nativeValue);            // "EGLD"

// ESDT token
final esdt = EgldOrEsdtTokenIdentifierType.create('WEGLD-bd4d79');
print(esdt.isEgld);                 // false
print(esdt.isEsdt);                 // true
print(esdt.ticker);                 // "WEGLD"
print(esdt.randomPart);             // "bd4d79"

// Empty identifier (special case)
final empty = EgldOrEsdtTokenIdentifierType.create('');
print(empty.isEgld);                // false
print(empty.isEsdt);                // false
```

### H256

256-bit cryptographic hashes (32 bytes).

```dart
// From 32-byte array
final hash = H256Type.create(List<int>.filled(32, 0));
print(hash.toHex());                // "0000000000..."
print(hash.nativeValue);            // Uint8List (32 bytes)

// From hex string (64 characters)
final txHash = H256Type.create(
  '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'
);
print(txHash.toHex());
print(txHash.toHexWithPrefix());    // "0x1234..."

// Direct value creation
final blockHash = H256Value.fromHex(
  'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890'
);
```

### Nothing

Void/empty type for functions with no return value.

```dart
final nothing = NothingType.create(null);
print(nothing.nativeValue);         // null
print(nothing.toBytes());           // [] (empty)
print(NothingType.type.sizeInBytes);// 0

// Also accepts any value (ignores it)
final nothing2 = NothingType.create("ignored");
print(nothing2.nativeValue);        // null
```

### ManagedDecimal

Fixed-point decimals with scale metadata.

```dart
// Token amounts (18 decimals like EGLD)
final tokenType = ManagedDecimalType.of(18);
final amount = tokenType.createValue(1.5) as ManagedDecimalValue;
print(amount.nativeValue);          // BigInt (raw scaled value)
print(amount.toDecimalString());    // "1.5"
print(amount.scale);                // 18

// Price (2 decimals)
final priceType = ManagedDecimalType.of(2);
final price = priceType.createValue(19.99) as ManagedDecimalValue;
print(price.toDecimalString());     // "19.99"
print(price.nativeValue);           // BigInt.from(1999)

// From string
final parsed = ManagedDecimalValue.fromString('123.456789', scale: 6);
print(parsed.toDecimalString());    // "123.456789"

// From double
final converted = ManagedDecimalValue.fromDouble(42.195, scale: 3);
print(converted.toDecimalString()); // "42.195"

// Signed decimals (negative values)
final signedType = ManagedDecimalSignedType(scale: 2);
final loss = signedType.createValue(-75.50) as ManagedDecimalValue;
print(loss.toDecimalString());      // "-75.5"

// Variable scale (runtime-determined)
final varType = ManagedDecimalType.variable(0);
print(varType.isVariable);          // true
```

### Optional (Algebraic)

Function arguments that can be omitted.

```dart
final optType = OptionalType.of(U32Type.type);

// Provided variant
final provided = optType.createValue(42) as OptionalValue;
print(provided.isProvided);         // true
print(provided.isMissing);          // false
print(provided.nativeValue);        // 42
print(provided.unwrap().nativeValue);// 42

// Missing variant
final missing = optType.createValue(null) as OptionalValue;
print(missing.isProvided);          // false
print(missing.isMissing);           // true
print(missing.nativeValue);         // null
// missing.unwrap();                // throws StateError

// Factory methods
final direct = OptionalValue.provided(optType, U32Type.create(100));
final empty = OptionalValue.missing(optType);
```

:::tip
Use `OptionalType` for contract endpoint parameters that can be omitted. Use `OptionType` for Rust Option<T> return values.
:::

### Variadic

Variable number of arguments of the same type.

```dart
// Basic variadic
final varType = VariadicType.of(U32Type.type);
final values = varType.createValue([10, 20, 30, 40]) as VariadicValue;
print(values.length);               // 4
print(values[0].nativeValue);       // 10
print(values.nativeValue);          // [10, 20, 30, 40]

// Empty variadic
final empty = varType.createValue([]) as VariadicValue;
print(empty.length);                // 0

// Counted variadic (with length prefix)
final countedType = VariadicType.counted(U64Type.type);
final counted = countedType.createValue([100, 200, 300]) as VariadicValue;
print(counted.isCounted);           // true

// Variadic of strings
final strType = VariadicType.of(StringType.type);
final strings = strType.createValue(['hello', 'world']) as VariadicValue;
```

### CodeMetadata

Smart contract deployment flags (2 bytes, big-endian format).

```dart
// From integer flags (big-endian 2-byte format)
final metadata = CodeMetadataType.create(0x0506);
print(metadata.isUpgradeable);      // true
print(metadata.isReadable);         // true
print(metadata.isPayable);          // true
print(metadata.isPayableBySC);      // true
print(metadata.nativeValue);        // 1286 (0x0506)

// From byte array
final fromBytes = CodeMetadataType.create([0x05, 0x02]);
print(fromBytes.flags);             // 1282 (0x0502)

// To bytes (for deployment)
final bytes = metadata.toBytes();   // [5, 6]

// Flag constants (big-endian layout)
print(CodeMetadataValue.upgradeableFlag);  // 0x0100 (byte 0, bit 0)
print(CodeMetadataValue.readableFlag);     // 0x0400 (byte 0, bit 2)
print(CodeMetadataValue.payableFlag);      // 0x0002 (byte 1, bit 1)
print(CodeMetadataValue.payableBySCFlag);  // 0x0004 (byte 1, bit 2)

// Combined flags
final upAndPay = CodeMetadataValue(
  CodeMetadataValue.upgradeableFlag | CodeMetadataValue.payableFlag
);
print(upAndPay.isUpgradeable);      // true
print(upAndPay.isPayable);          // true
```

[comment]: # (mx-context-auto)

## Mixed & Nested Types

Real-world smart contracts often combine multiple type categories. This section demonstrates common patterns for nested and mixed type compositions.

### List of Structs

A collection of complex objects, common for returning multiple records.

```dart
// Define the item struct
final tokenInfoType = StructBuilder('TokenInfo')
    .field('identifier', TokenIdentifierType.type)
    .field('balance', BigUIntType.type)
    .field('frozen', BooleanType.type)
    .build();

// Create a list type containing structs
final tokenListType = ListType(tokenInfoType);

// Create list with multiple token info structs
final tokens = tokenListType.createValue([
  {'identifier': 'WEGLD-bd4d79', 'balance': BigInt.from(10).pow(18), 'frozen': false},
  {'identifier': 'USDC-c76f1f', 'balance': BigInt.from(5000) * BigInt.from(10).pow(6), 'frozen': false},
  {'identifier': 'MEX-455c57', 'balance': BigInt.from(1000000) * BigInt.from(10).pow(18), 'frozen': true},
]);

// Access elements
final listVal = tokens as ListValue;
print(listVal.length);                                    // 3
print((listVal[0] as StructValue).getFieldValue('identifier').nativeValue);  // "WEGLD-bd4d79"
```

### Struct with Nested Struct

Hierarchical data structures with embedded objects.

```dart
// Inner struct: Token payment
final paymentType = StructBuilder('EsdtTokenPayment')
    .field('token_identifier', TokenIdentifierType.type)
    .field('token_nonce', U64Type.type)
    .field('amount', BigUIntType.type)
    .build();

// Outer struct: Swap operation
final swapType = StructBuilder('SwapOperation')
    .field('sender', AddressType.type)
    .field('input', paymentType)           // nested struct
    .field('output', paymentType)          // nested struct
    .field('timestamp', U64Type.type)
    .build();

// Create with nested data
final swap = swapType.createValue({
  'sender': 'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  'input': {
    'token_identifier': 'WEGLD-bd4d79',
    'token_nonce': BigInt.zero,
    'amount': BigInt.from(10).pow(18),
  },
  'output': {
    'token_identifier': 'USDC-c76f1f',
    'token_nonce': BigInt.zero,
    'amount': BigInt.from(1850) * BigInt.from(10).pow(6),
  },
  'timestamp': BigInt.from(1701792000),
});

// Access nested fields
final swapVal = swap as StructValue;
final inputPayment = swapVal.getFieldValue('input') as StructValue;
print(inputPayment.getFieldValue('token_identifier').nativeValue);  // "WEGLD-bd4d79"
```

### Option of Struct

Optional complex data, common for nullable return values.

```dart
// Define struct
final rewardType = StructBuilder('RewardInfo')
    .field('token', TokenIdentifierType.type)
    .field('amount', BigUIntType.type)
    .field('epoch', U64Type.type)
    .build();

// Option containing struct
final optionalRewardType = OptionType(rewardType);

// Some: has reward
final hasReward = optionalRewardType.createValue({
  'token': 'MEX-455c57',
  'amount': BigInt.from(1000) * BigInt.from(10).pow(18),
  'epoch': BigInt.from(1500),
});
print((hasReward as OptionValue).isSome);  // true

// None: no reward
final noReward = optionalRewardType.createValue(null);
print((noReward as OptionValue).isNone);   // true
```

### Enum with Struct Variants

Discriminated unions where variants carry complex data.

```dart
// Define struct for success data
final successDataType = StructBuilder('SuccessData')
    .field('tx_hash', H256Type.type)
    .field('gas_used', U64Type.type)
    .build();

// Define struct for error data
final errorDataType = StructBuilder('ErrorData')
    .field('code', U32Type.type)
    .field('message', StringType.type)
    .build();

// Enum with struct variants
final resultType = EnumType(
  name: 'TransactionResult',
  variants: [
    EnumVariantDefinition(
      name: 'Success',
      discriminant: 0,
      fields: [successDataType],
    ),
    EnumVariantDefinition(
      name: 'Error',
      discriminant: 1,
      fields: [errorDataType],
    ),
    const EnumVariantDefinition(name: 'Pending', discriminant: 2),
  ],
);

// Create success variant
final success = resultType.createValue({
  'variant': 'Success',
  'fields': [{
    'tx_hash': '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
    'gas_used': BigInt.from(5000000),
  }],
});

// Create error variant
final error = resultType.createValue({
  'variant': 'Error',
  'fields': [{
    'code': 404,
    'message': 'Token not found',
  }],
});

// Create simple variant
final pending = resultType.createValue('Pending');
```

### Tuple with Mixed Types

Fixed-size heterogeneous collections.

```dart
// Tuple: (Address, TokenIdentifier, BigUInt, Option<U64>)
final transferTupleType = TupleType([
  AddressType.type,
  TokenIdentifierType.type,
  BigUIntType.type,
  OptionType(U64Type.type),
]);

// With optional value present
final transfer1 = transferTupleType.createValue([
  'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  'WEGLD-bd4d79',
  BigInt.from(10).pow(18),
  BigInt.from(12345),  // nonce present
]);

// With optional value absent
final transfer2 = transferTupleType.createValue([
  'erd1spyavw0956vq68xj8y4tenjpq2wd5a9p2c6j8gsz7ztyrnpxrruqzu66jx',
  'USDC-c76f1f',
  BigInt.from(1000) * BigInt.from(10).pow(6),
  null,  // no nonce
]);

// Access tuple elements
final tupleVal = transfer1 as TupleValue;
print((tupleVal[0] as AddressValue).toBech32());
print((tupleVal[3] as OptionValue).unwrap().nativeValue);  // 12345
```

### Variadic of Structs

Variable-length function arguments with complex types.

```dart
// Payment struct for multi-transfer
final paymentType = StructBuilder('Payment')
    .field('token', EgldOrEsdtTokenIdentifierType.type)
    .field('nonce', U64Type.type)
    .field('amount', BigUIntType.type)
    .build();

// Variadic payments
final multiPaymentType = VariadicType.of(paymentType);

final payments = multiPaymentType.createValue([
  {'token': 'EGLD', 'nonce': BigInt.zero, 'amount': BigInt.from(10).pow(18)},
  {'token': 'WEGLD-bd4d79', 'nonce': BigInt.zero, 'amount': BigInt.from(5) * BigInt.from(10).pow(18)},
  {'token': 'LKMEX-aab910', 'nonce': BigInt.from(12345), 'amount': BigInt.from(1000) * BigInt.from(10).pow(18)},
]);

final varVal = payments as VariadicValue;
print(varVal.length);  // 3
for (var i = 0; i < varVal.length; i++) {
  final payment = varVal[i] as StructValue;
  print('${payment.getFieldValue("token").nativeValue}: ${payment.getFieldValue("amount").nativeValue}');
}
```

### List of Options

Sparse arrays where elements can be missing.

```dart
// List of optional prices (some tokens may not have a price)
final priceListType = ListType(OptionType(BigUIntType.type));

final prices = priceListType.createValue([
  BigInt.from(1850) * BigInt.from(10).pow(6),  // WEGLD price: $1850
  null,                                          // Unknown token
  BigInt.from(1) * BigInt.from(10).pow(6),      // USDC price: $1
  null,                                          // Unknown token
  BigInt.from(42) * BigInt.from(10).pow(4),     // MEX price: $0.0042
]);

final listVal = prices as ListValue;
for (var i = 0; i < listVal.length; i++) {
  final opt = listVal[i] as OptionValue;
  if (opt.isSome) {
    print('Token $i price: ${opt.unwrap().nativeValue}');
  } else {
    print('Token $i: no price available');
  }
}
```

### Deeply Nested: List of Struct with List Field

Complex hierarchical data typical of DeFi protocols.

```dart
// Route step
final routeStepType = StructBuilder('RouteStep')
    .field('pool', AddressType.type)
    .field('token_in', TokenIdentifierType.type)
    .field('token_out', TokenIdentifierType.type)
    .build();

// Swap route with multiple steps
final swapRouteType = StructBuilder('SwapRoute')
    .field('steps', ListType(routeStepType))    // List of structs
    .field('expected_output', BigUIntType.type)
    .field('slippage_percent', U32Type.type)
    .build();

// Multiple routes for aggregator
final routesListType = ListType(swapRouteType);

final routes = routesListType.createValue([
  {
    'steps': [
      {
        'pool': 'erd1qqqqqqqqqqqqqpgqhe8t5jewej70zupmh44jurgn29psua5l2jps3ntjj3',
        'token_in': 'WEGLD-bd4d79',
        'token_out': 'USDC-c76f1f',
      },
    ],
    'expected_output': BigInt.from(1850) * BigInt.from(10).pow(6),
    'slippage_percent': 100,  // 1%
  },
  {
    'steps': [
      {
        'pool': 'erd1qqqqqqqqqqqqqpgqhe8t5jewej70zupmh44jurgn29psua5l2jps3ntjj3',
        'token_in': 'WEGLD-bd4d79',
        'token_out': 'MEX-455c57',
      },
      {
        'pool': 'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
        'token_in': 'MEX-455c57',
        'token_out': 'USDC-c76f1f',
      },
    ],
    'expected_output': BigInt.from(1855) * BigInt.from(10).pow(6),
    'slippage_percent': 150,  // 1.5%
  },
]);

// Navigate the nested structure
final routesList = routes as ListValue;
final firstRoute = routesList[0] as StructValue;
final steps = firstRoute.getFieldValue('steps') as ListValue;
print('Route 1 has ${steps.length} step(s)');
```

[comment]: # (mx-context-auto)

## Native Value Conversion Summary

| Type | Native Value Type | Example |
| ---- | ----------------- | ------- |
| U8, U16, U32 | `int` | `255`, `1000000` |
| U64, I64 | `BigInt` | `BigInt.from(...)` |
| I8, I16, I32 | `int` | `-42` |
| BigUInt, BigInt | `BigInt` | `BigInt.parse('...')` |
| Boolean | `bool` | `true`, `false` |
| String | `String` | `"Hello"` |
| Bytes | `List<int>` | `[72, 101, 108, 108, 111]` |
| Address | `String` (bech32) | `"erd1qqqqqq..."` |
| List | `List<dynamic>` | `[10, 20, 30]` |
| Array | `List<dynamic>` | `[100, 200, 300]` |
| Option | `T?` | `42` or `null` |
| Struct | `Map<String, dynamic>` | `{name: 'Alice', age: 30}` |
| Tuple | `List<dynamic>` | `[42, 'test', true]` |
| Enum (simple) | `String` | `"Pending"` (variant name) |
| Enum (with fields) | `Map` | `{variant: 'Error', fields: [...]}` |
| TokenIdentifier | `String` | `"WEGLD-bd4d79"` |
| H256 | `Uint8List` | 32-byte array, via `.toHex()` |
| Nothing | `null` | always `null` |
| ManagedDecimal | `BigInt` | via `.toDecimalString()` |
| Optional | `T?` | `42` or `null` |
| Variadic | `List<TypedValue>` | via `[i].nativeValue` |
| CodeMetadata | `int` (flags) | `7` |

[comment]: # (mx-context-auto)

## Type Singleton Access

All primitive and special types expose a singleton via `.type`:

```dart
// Primitives
U8Type.type
U16Type.type
U32Type.type
U64Type.type
I8Type.type
I16Type.type
I32Type.type
I64Type.type
BigUIntType.type
BigIntType.type
BooleanType.type
StringType.type
BytesType.type
AddressType.type

// Special
TokenIdentifierType.type
EgldOrEsdtTokenIdentifierType.type
H256Type.type
NothingType.type
CodeMetadataType.type
```

[comment]: # (mx-context-auto)

## Complete Example

Building a complex DeFi position type:

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() {
  // Define position struct
  final positionType = StructType(
    name: 'LiquidityPosition',
    fieldDefinitions: [
      FieldDefinition(name: 'owner', type: AddressType.type),
      FieldDefinition(name: 'tokenA', type: TokenIdentifierType.type),
      FieldDefinition(name: 'tokenB', type: TokenIdentifierType.type),
      FieldDefinition(name: 'amountA', type: BigUIntType.type),
      FieldDefinition(name: 'amountB', type: BigUIntType.type),
      FieldDefinition(name: 'lpTokens', type: BigUIntType.type),
      FieldDefinition(name: 'active', type: BooleanType.type),
    ],
  );

  // Create position
  final position = positionType.createValue({
    'owner': 'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
    'tokenA': 'WEGLD-bd4d79',
    'tokenB': 'USDC-c76f1f',
    'amountA': BigInt.from(10) * BigInt.from(10).pow(18),  // 10 WEGLD
    'amountB': BigInt.from(20000) * BigInt.from(10).pow(6), // 20000 USDC
    'lpTokens': BigInt.from(1414) * BigInt.from(10).pow(18),
    'active': true,
  });

  // Access fields
  final structVal = position as StructValue;
  print('Owner: ${(structVal.getFieldValue("owner") as AddressValue).toBech32()}');
  print('Token A: ${(structVal.getFieldValue("tokenA") as TokenIdentifierValue).ticker}');
  print('Active: ${structVal.getFieldValue("active").nativeValue}');
  
  // Convert to native
  print('Native: ${position.nativeValue}');
}
```

[comment]: # (mx-context-auto)

## See Also

- [COOKBOOK.md](./manual/COOKBOOK.md) - Transaction and controller examples
- [CODEGEN_COOKBOOK.md](./generated/CODEGEN_COOKBOOK.md) - Code generation from ABI files
- Example files in `example/abi/types/`
