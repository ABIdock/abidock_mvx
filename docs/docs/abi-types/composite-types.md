---
id: composite-types
title: Composite Types
sidebar_position: 4
description: Build complex MultiversX ABI structures using Struct, Tuple, and Enum composite types with fluent builders.
---

# Composite Types

Composite types combine multiple values into structured data.

:::info Field Type Parameters
Field values use native types based on the field type:
- `U32Type.type` fields take `int`
- `U64Type.type` fields take `int` or `BigInt`
- `BigUIntType.type` fields take `int` or `BigInt`
- `StringType.type` fields take `String`
:::

:::note Casting
`createValue` returns the base `TypedValue`; cast to `StructValue`, `TupleValue`, `EnumValue` or
`ExplicitEnumValue` to reach their APIs.
:::

## Wire format

| Type | Top-level | Nested |
|------|-----------|--------|
| struct | fields concatenated, each **nested**-encoded, in declaration order | identical |
| tuple | elements concatenated, each nested-encoded | identical |
| enum | unit variant with discriminant `0` is an **empty buffer**; otherwise `[u8 discriminant]` + nested fields | always `[u8 discriminant]` + nested fields |
| explicit-enum | UTF-8 bytes of the **variant name** | `[u32 length][UTF-8 variant name]` |

Struct and tuple encodings carry no field names, no separators and no length prefix: field order in
the ABI *is* the format. Discriminants must fit in a byte (0-255); anything else throws
`AbiBinaryCodecException`.

## Struct

Named fields with different types:

### Creating Struct Types

```dart
// Define a struct type using StructBuilder
final userType = StructBuilder('User')
    .field('name', StringType.type)
    .field('age', U32Type.type)         // u32 takes int
    .field('balance', BigUIntType.type) // BigUint takes int or BigInt
    .build();

// Create a value from native Dart types
final user = userType.createValue(<String, dynamic>{
  'name': 'Alice',
  'age': 30,                    // int for u32
  'balance': BigInt.from(1000), // BigInt for BigUint
}) as StructValue;

// Access as map
print(user.nativeValue); // {name: Alice, age: 30, balance: 1000}
```

`createValue` also accepts a `List` with the values in field order, which is handy when the source
data is positional.

### Accessing Fields

```dart
// Get a field value (throws ArgumentError if the field does not exist)
final name = user.getFieldValue('name');
print(name.nativeValue); // 'Alice'

final balance = user.getFieldValue('balance');
print(balance.nativeValue); // BigInt 1000

// Ask without throwing
if (user.tryGetFieldValue('email') == null) {
  print('No email field');
}

// Field names and values in declaration order
print(user.fieldNames);  // [name, age, balance]
print(user.fieldValues.length); // 3
```

### Nested Structs

```dart
// Define Address type
final addressType = StructBuilder('Address')
    .field('street', StringType.type)
    .field('city', StringType.type)
    .build();

// Define User with nested Address type
final userType = StructBuilder('UserWithAddress')
    .field('name', StringType.type)
    .field('address', addressType)
    .build();

// Create user with nested address using native values
final userWithAddress = userType.createValue(<String, dynamic>{
  'name': 'Alice',
  'address': <String, dynamic>{
    'street': '123 Main St',
    'city': 'New York',
  },
}) as StructValue;

// Access nested data
final addrStruct = userWithAddress.getFieldValue('address') as StructValue;
final city = addrStruct.getFieldValue('city').nativeValue;
print(city); // 'New York'
```

## Enum

Variants with optional data:

### Simple Enum (No Fields)

```dart
// Define enum type with simple variants
final statusType = EnumBuilder('Status')
    .variant('Pending', 0)
    .variant('Active', 1)
    .variant('Completed', 2)
    .build();

// Create enum values
final pending = statusType.createValue('Pending') as EnumValue;
print(pending.nativeValue);   // 'Pending'
print(pending.discriminant);  // 0

final active = statusType.createValue('Active') as EnumValue;
print(active.nativeValue);    // 'Active'
print(active.discriminant);   // 1
```

`Pending` encodes as an empty buffer at the top level (discriminant 0, no fields) and as `0x00`
when nested; `Active` is `0x01` in both positions.

### Enum with Fields

```dart
// Define enum type where variants carry data
final resultType = EnumBuilder('Result')
    .variantWithFields('Success', 0, <AbiType>[U64Type.type])
    .variantWithFields('Error', 1, <AbiType>[StringType.type])
    .build();

// Create a Success value
final success = resultType.createValue(<String, dynamic>{
  'variant': 'Success',
  'fields': <dynamic>[BigInt.from(42)],
}) as EnumValue;

// Access variant and fields
final data = success.nativeValue as Map<String, dynamic>;
print(data['variant']); // 'Success'
print(data['fields']);  // [42]
```

A variant that carries fields always writes its discriminant, even when it is `0` -- otherwise the
fields would have nothing to hang off.

### Complex Enum Example

```dart
// A Result-shaped enum
final resultType = EnumBuilder('Result')
    .variantWithFields('Ok', 0, <AbiType>[StringType.type])
    .variantWithFields('Err', 1, <AbiType>[StringType.type])
    .build();

// Create Ok result
final okResult = resultType.createValue(<String, dynamic>{
  'variant': 'Ok',
  'fields': <dynamic>['Success!'],
}) as EnumValue;

// Create Error result
final errResult = resultType.createValue(<String, dynamic>{
  'variant': 'Err',
  'fields': <dynamic>['Something went wrong'],
}) as EnumValue;

// Handling either shape
void handleResult(EnumValue result) {
  final dynamic data = result.nativeValue;
  if (data is String) {
    // Unit variant (no fields)
    print('Simple: $data');
  } else if (data is Map) {
    final dynamic variant = data['variant'];
    final List<dynamic> fields = data['fields'] as List<dynamic>;

    if (variant == 'Ok') {
      print('Success: ${fields[0]}');
    } else if (variant == 'Err') {
      print('Error: ${fields[0]}');
    }
  }
}
```

## Explicit Enum

An explicit enum has named variants and never carries data. The decisive difference is the wire
format: it travels as the **variant name**, not as a discriminant byte, which is what lets a
contract evolve the variant order without breaking clients.

### Defining Explicit Enums

```dart
// Define an explicit enum type
final statusType = ExplicitEnumType(
  name: 'Status',
  variants: <ExplicitEnumVariantDefinition>[
    ExplicitEnumVariantDefinition(name: 'Pending', discriminant: 0),
    ExplicitEnumVariantDefinition(name: 'Active', discriminant: 1),
    ExplicitEnumVariantDefinition(name: 'Completed', discriminant: 2),
    ExplicitEnumVariantDefinition(name: 'Cancelled', discriminant: 3),
  ],
);
```

### Creating Explicit Enum Values

```dart
// Create by discriminant (the number declared in the ABI, not a position)
final pending = statusType.createValue(0) as ExplicitEnumValue;   // Status::Pending
final active = statusType.createValue(1) as ExplicitEnumValue;    // Status::Active

// Create by variant name (string)
final completed = statusType.createValue('Completed') as ExplicitEnumValue;
```

### Accessing Values

```dart
final enumValue = statusType.createValue(1) as ExplicitEnumValue;

print(enumValue.discriminant); // 1
print(enumValue.variantName);  // 'Active'
print(enumValue.nativeValue);  // 'Active' (variant name as String)
```

The discriminant is local bookkeeping: it never reaches the wire. Decoding an unknown variant name
throws `AbiBinaryCodecException`.

### Explicit Enum vs Regular Enum

| Feature | Explicit Enum | Regular Enum |
|---------|---------------|--------------|
| Fields | None | Optional data fields per variant |
| Wire form | UTF-8 variant name (length-prefixed when nested) | 1-byte discriminant + nested fields |
| Order sensitivity | Names are the contract | Discriminants are the contract |
| ABI type kind | `explicit-enum` | `enum` |

```dart
// Explicit enum: simple variant names only
final statusType = ExplicitEnumType(
  name: 'Status',
  variants: <ExplicitEnumVariantDefinition>[
    ExplicitEnumVariantDefinition(name: 'Pending', discriminant: 0),
    ExplicitEnumVariantDefinition(name: 'Active', discriminant: 1),
  ],
);

// Regular enum: variants can carry data (field types, in order)
final resultType = EnumType(
  name: 'Result',
  variants: <EnumVariantDefinition>[
    EnumVariantDefinition(
      name: 'Ok',
      discriminant: 0,
      fields: <AbiType>[BigUIntType.type],
    ),
    EnumVariantDefinition(
      name: 'Err',
      discriminant: 1,
      fields: <AbiType>[StringType.type],
    ),
  ],
);
```

## Tuple

Ordered collection of different types (positional access):

### Creating Tuples

```dart
// Define tuple type with (u64, bool, utf-8 string) elements
final tupleType = TupleType(<AbiType>[
  U64Type.type,
  BooleanType.type,
  StringType.type,
]);

// Create tuple value using native values
final tuple = tupleType.createValue(<dynamic>[
  BigInt.from(123),
  true,
  'hello',
]) as TupleValue;

// Access as list
print(tuple.nativeValue); // [123, true, hello]
```

### Accessing Tuple Elements

```dart
final first = tuple.elements[0].nativeValue;  // BigInt 123
final second = tuple.elements[1].nativeValue; // true
final third = tuple.elements[2].nativeValue;  // 'hello'

// Index operator does the same
final alsoFirst = tuple[0].nativeValue;
```

### Tuple vs Struct

| Feature | Tuple | Struct |
|---------|-------|--------|
| Access | By index | By name |
| Fields | Unnamed | Named |
| Wire form | Identical | Identical |

Tuples and structs are byte-for-byte the same on the wire; the difference is purely in the API.

```dart
// Tuple: position matters (i32 takes int)
final pointTupleType = TupleType(<AbiType>[I32Type.type, I32Type.type]);
final point = pointTupleType.createValue(<int>[10, 20]) as TupleValue;

// Struct: names matter (i32 takes int)
final pointType = StructBuilder('Point')
    .field('x', I32Type.type)
    .field('y', I32Type.type)
    .build();

final pointStruct = pointType.createValue(<String, dynamic>{
  'x': 10, // int for i32
  'y': 20,
}) as StructValue;
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() {
  print('=== Composite Types Demo ===\n');

  // === Struct ===
  final userType = StructBuilder('User')
      .field('id', U64Type.type)
      .field('name', StringType.type)
      .field('balance', BigUIntType.type)
      .field('active', BooleanType.type)
      .build();

  final user = userType.createValue(<String, dynamic>{
    'id': BigInt.from(1),
    'name': 'Alice',
    'balance': BigInt.parse('1000000000000000000'),
    'active': true,
  }) as StructValue;

  print('Full struct: ${user.nativeValue}');
  print('Name: ${user.getFieldValue('name').nativeValue}');
  print('Balance: ${user.getFieldValue('balance').nativeValue}');

  // === Nested Struct ===
  final settingsType = StructBuilder('Settings')
      .field('theme', StringType.type)
      .field('notifications', BooleanType.type)
      .build();

  final profileType = StructBuilder('UserProfile')
      .field('user', userType)
      .field('settings', settingsType)
      .build();

  final profile = profileType.createValue(<String, dynamic>{
    'user': <String, dynamic>{
      'id': BigInt.from(1),
      'name': 'Alice',
      'balance': BigInt.parse('1000000000000000000'),
      'active': true,
    },
    'settings': <String, dynamic>{
      'theme': 'dark',
      'notifications': true,
    },
  }) as StructValue;

  final innerUser = profile.getFieldValue('user') as StructValue;
  final innerSettings = profile.getFieldValue('settings') as StructValue;
  print('User name: ${innerUser.getFieldValue('name').nativeValue}');
  print('Theme: ${innerSettings.getFieldValue('theme').nativeValue}');

  // === Simple Enum ===
  final statusType = EnumBuilder('Status')
      .variant('Pending', 0)
      .variant('Active', 1)
      .variant('Completed', 2)
      .build();

  final status = statusType.createValue('Active') as EnumValue;
  print('Variant: ${status.nativeValue}');
  print('Discriminant: ${status.discriminant}');

  // === Enum with Fields ===
  final actionType = EnumBuilder('Action')
      .variantWithFields('Transfer', 0, <AbiType>[
        AddressType.type,
        BigUIntType.type,
      ])
      .variant('Withdraw', 1)
      .build();

  final action = actionType.createValue(<String, dynamic>{
    'variant': 'Transfer',
    'fields': <dynamic>[
      'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu', // bech32
      BigInt.from(1000),
    ],
  }) as EnumValue;

  final actionData = action.nativeValue as Map<String, dynamic>;
  print('Variant: ${actionData['variant']}');
  print('Fields: ${actionData['fields']}');

  // === Tuple ===
  final tupleType = TupleType(<AbiType>[
    U64Type.type,
    BooleanType.type,
    StringType.type,
  ]);
  final tuple = tupleType.createValue(<dynamic>[
    BigInt.from(42),
    true,
    'data',
  ]) as TupleValue;

  print('Values: ${tuple.nativeValue}');
  print('First: ${tuple.elements[0].nativeValue}');
  print('Second: ${tuple.elements[1].nativeValue}');
  print('Third: ${tuple.elements[2].nativeValue}');
}
```

## Working with Contract Results

### Struct from Query

```dart
final result = await controller.query(
  endpointName: 'getUser',
  arguments: <dynamic>[BigInt.from(1)],
);

// Native form: a Map keyed by field name
final userMap = result.first as Map<String, dynamic>;
final name = userMap['name'] as String;
final balance = userMap['balance'] as BigInt;

// Typed form, when you want the ABI metadata
final user = result.typedValues.first as StructValue;
print(user.type.name); // 'User'
```

### Enum from Query

```dart
final result = await controller.query(
  endpointName: 'getStatus',
  arguments: <dynamic>[],
);

// A unit variant decodes to its name; a variant with fields to a Map.
final dynamic status = result.first;
if (status == 'Active') {
  print('Contract is active');
} else if (status is Map<String, dynamic>) {
  final dynamic variant = status['variant'];
  final dynamic fields = status['fields'];
  print('$variant with $fields');
}
```

## Next Steps

- [Special Types](/docs/abi-types/special-types) - Address, tokens, etc.
- [Mixed & Nested Types](/docs/abi-types/mixed-nested-types) - Complex combinations
- [Primitive Types](/docs/abi-types/primitive-types) - Basic types reference
