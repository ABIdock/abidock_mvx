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

## Struct

Named fields with different types:

### Creating Struct Types

```dart
// Define a struct type using StructBuilder
final userType = StructBuilder('User')
    .field('name', StringType.type)
    .field('age', U32Type.type)        // U32 takes int
    .field('balance', BigUIntType.type) // BigUInt takes int or BigInt
    .build();

// Create a value from native Dart types
final user = userType.createValue({
  'name': 'Alice',
  'age': 30,                    // int for U32
  'balance': BigInt.from(1000), // BigInt for BigUInt
});

// Access as map
print(user.nativeValue); // {name: 'Alice', age: 30, balance: 1000}
```

### Accessing Fields

```dart
// Get field value
final name = user.getFieldValue('name');
print(name?.nativeValue); // 'Alice'

final balance = user.getFieldValue('balance');
print(balance?.nativeValue); // BigInt(1000)

// Check if field exists
if (user.getFieldValue('email') == null) {
  print('No email field');
}
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
final userWithAddress = userType.createValue({
  'name': 'Alice',
  'address': {
    'street': '123 Main St',
    'city': 'New York',
  },
});

// Access nested data
final userStruct = userWithAddress;
final addrStruct = userStruct.getFieldValue('address') as StructValue;
final city = addrStruct.getFieldValue('city')?.nativeValue;
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
final pending = statusType.createValue('Pending');
print(pending.nativeValue); // 'Pending'
print(pending.discriminant); // 0

final active = statusType.createValue('Active');
print(active.nativeValue); // 'Active' 
print(active.discriminant); // 1
```

### Enum with Fields

```dart
// Define enum type where variants carry data
final resultType = EnumBuilder('Result')
    .variantWithFields('Success', 0, [U64Type.type])
    .variantWithFields('Error', 1, [StringType.type])
    .build();

// Create a Success value
final success = resultType.createValue({
  'variant': 'Success',
  'fields': [BigInt.from(42)],
});

// Access variant and fields
final data = success.nativeValue as Map<String, dynamic>;
print(data['variant']); // 'Success'
print(data['fields']); // [42]
```

### Complex Enum Example

```dart
// Like Rust's Result<T, E>
final resultType = EnumBuilder('Result')
    .variantWithFields('Ok', 0, [StringType.type])
    .variantWithFields('Err', 1, [StringType.type])
    .build();

// Create Ok result
final okResult = resultType.createValue({
  'variant': 'Ok',
  'fields': ['Success!'],
});

// Create Error result
final errResult = resultType.createValue({
  'variant': 'Err',
  'fields': ['Something went wrong'],
});

// Pattern matching
void handleResult(EnumValue result) {
  final data = result.nativeValue;
  if (data is String) {
    // Simple variant (no fields)
    print('Simple: ' + data.toString());
  } else if (data is Map) {
    final variant = data['variant'];
    final fields = data['fields'] as List;
    
    if (variant == 'Ok') {
      print('Success: ' + fields[0].toString());
    } else if (variant == 'Err') {
      print('Error: ' + fields[0].toString());
    }
  }
}
```

## Explicit Enum

An explicit enum is a simpler variant of the standard enum. Unlike regular enums which can have associated data fields, explicit enums only have named variants without any data. They are useful for simple discriminated values like status codes, categories, or modes.

### Defining Explicit Enums

```dart
// Define an explicit enum type
final statusType = ExplicitEnumType(
  name: 'Status',
  variants: [
    ExplicitEnumVariantDefinition(name: 'Pending', discriminant: 0),
    ExplicitEnumVariantDefinition(name: 'Active', discriminant: 1),
    ExplicitEnumVariantDefinition(name: 'Completed', discriminant: 2),
    ExplicitEnumVariantDefinition(name: 'Cancelled', discriminant: 3),
  ],
);
```

### Creating Explicit Enum Values

```dart
// Create by discriminant (index)
final pending = statusType.createValue(0);     // Status::Pending
final active = statusType.createValue(1);      // Status::Active

// Create by variant name (string)
final completed = statusType.createValue('Completed');  // Status::Completed
```

### Accessing Values

```dart
final value = statusType.createValue(1);
final enumValue = value as ExplicitEnumValue;

print(enumValue.discriminant);  // 1
print(enumValue.variantName);   // 'Active'
print(enumValue.nativeValue);   // 1
```

### Explicit Enum vs Regular Enum

| Feature | Explicit Enum | Regular Enum |
|---------|---------------|--------------|
| Fields | None | Optional data fields |
| Encoding | Simple discriminant | Complex with data |
| Use case | Simple states | Data variants |
| ABI type kind | `explicit-enum` | `enum` |

```dart
// Explicit enum: simple variant names only
final statusType = ExplicitEnumType(
  name: 'Status',
  variants: [
    ExplicitEnumVariantDefinition(name: 'Pending', discriminant: 0),
    ExplicitEnumVariantDefinition(name: 'Active', discriminant: 1),
  ],
);

// Regular enum: can have associated data per variant
final resultType = EnumType(
  name: 'Result',
  variants: [
    EnumVariantDefinition(name: 'Ok', discriminant: 0, fields: [
      FieldDefinition(name: 'value', type: BigUIntType.type),
    ]),
    EnumVariantDefinition(name: 'Err', discriminant: 1, fields: [
      FieldDefinition(name: 'message', type: StringType.type),
    ]),
  ],
);
```

## Tuple

Ordered collection of different types (positional access):

### Creating Tuples

```dart
// Define tuple type with (u64, bool, String) elements
final tupleType = TupleType([
  U64Type.type,
  BooleanType.type,
  StringType.type,
]);

// Create tuple value using native values
final tuple = tupleType.createValue([
  BigInt.from(123),
  true,
  'hello',
]);

// Access as list
print(tuple.nativeValue); // [123, true, 'hello']
```

### Accessing Tuple Elements

```dart
final tupleVal = tuple as TupleValue;
final first = tupleVal.elements[0].nativeValue;  // 123 (BigInt)
final second = tupleVal.elements[1].nativeValue; // true
final third = tupleVal.elements[2].nativeValue;  // 'hello'
```

### Tuple vs Struct

| Feature | Tuple | Struct |
|---------|-------|--------|
| Access | By index | By name |
| Fields | Unnamed | Named |
| Use case | Simple pairs | Complex data |

```dart
// Tuple: position matters (I32 takes int)
final pointTupleType = TupleType([I32Type.type, I32Type.type]);
final point = pointTupleType.createValue([10, 20]); // int values

// Struct: names matter (I32 takes int)
final pointType = StructBuilder('Point')
    .field('x', I32Type.type)
    .field('y', I32Type.type)
    .build();
    
final pointStruct = pointType.createValue({
  'x': 10,  // int for I32
  'y': 20,  // int for I32
});
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() {
  print('=== Composite Types Demo ===\n');
  
  // === Struct ===
  print('Struct (User):');
  
  // Define the User type
  final userType = StructBuilder('User')
      .field('id', U64Type.type)
      .field('name', StringType.type)
      .field('balance', BigUIntType.type)
      .field('active', BooleanType.type)
      .build();
  
  // Create a user value
  final user = userType.createValue({
    'id': BigInt.from(1),
    'name': 'Alice',
    'balance': BigInt.parse('1000000000000000000'),
    'active': true,
  });
  
  print('Full struct: ' + user.nativeValue.toString());
  print('Name: ' + (user.getFieldValue('name')?.nativeValue?.toString() ?? 'null'));
  print('Balance: ' + (user.getFieldValue('balance')?.nativeValue?.toString() ?? 'null'));
  
  // === Nested Struct ===
  
  // Define Settings type
  final settingsType = StructBuilder('Settings')
      .field('theme', StringType.type)
      .field('notifications', BooleanType.type)
      .build();
  
  // Define UserProfile with nested User and Settings
  final profileType = StructBuilder('UserProfile')
      .field('user', userType)
      .field('settings', settingsType)
      .build();
  
  // Create profile with nested values
  final profile = profileType.createValue({
    'user': {
      'id': BigInt.from(1),
      'name': 'Alice',
      'balance': BigInt.parse('1000000000000000000'),
      'active': true,
    },
    'settings': {
      'theme': 'dark',
      'notifications': true,
    },
  });
  
  final innerUser = profile.getFieldValue('user') as StructValue;
  final innerSettings = profile.getFieldValue('settings') as StructValue;
  print('User name: ' + (innerUser.getFieldValue('name')?.nativeValue?.toString() ?? 'null'));
  print('Theme: ' + (innerSettings.getFieldValue('theme')?.nativeValue?.toString() ?? 'null'));
  
  // === Simple Enum ===
  final statusType = EnumBuilder('Status')
      .variant('Pending', 0)
      .variant('Active', 1)
      .variant('Completed', 2)
      .build();
  
  final status = statusType.createValue('Active');
  print('Variant: ' + status.nativeValue.toString());
  print('Discriminant: ' + status.discriminant.toString());
  
  // === Enum with Fields ===
  final actionType = EnumBuilder('Action')
      .variantWithFields('Transfer', 0, [AddressType.type, BigUIntType.type])
      .variant('Withdraw', 1)
      .build();
  
  final action = actionType.createValue({
    'variant': 'Transfer',
    'fields': [
      'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',  // bech32 string
      BigInt.from(1000),
    ],
  });
  
  final actionData = action.nativeValue as Map;
  print('Variant: ' + actionData['variant'].toString());
  print('Fields: ' + actionData['fields'].toString());
  
  // === Tuple ===
  final tupleType = TupleType([U64Type.type, BooleanType.type, StringType.type]);
  final tuple = tupleType.createValue([
    BigInt.from(42),
    true,
    'data',
  ]);
  
  print('Values: ' + tuple.nativeValue.toString());
  print('First: ' + tuple.elements[0].nativeValue.toString());
  print('Second: ' + tuple.elements[1].nativeValue.toString());
  print('Third: ' + tuple.elements[2].nativeValue.toString());
  

}
```

## Working with Contract Results

### Struct from Query

```dart
final result = await controller.query(
  endpointName: 'getUser',
  arguments: [BigInt.from(1)],
);

final user = result.first as StructValue;
final name = user.getFieldValue('name')?.nativeValue;
final balance = user.getFieldValue('balance')?.nativeValue;
```

### Enum from Query

```dart
final result = await controller.query(
  endpointName: 'getStatus',
  arguments: [],
);

final status = result.first as EnumValue;

// Check variant
if (status.nativeValue == 'Active') {
  print('Contract is active');
}

// Or for enum with fields
final enumData = status.nativeValue;
if (enumData is Map) {
  final variant = enumData['variant'];
  final fields = enumData['fields'];
  // Process based on variant
}
```

## Next Steps

- [Special Types](/docs/abi-types/special-types) - Address, tokens, etc.
- [Mixed & Nested Types](/docs/abi-types/mixed-nested-types) - Complex combinations
- [Primitive Types](/docs/abi-types/primitive-types) - Basic types reference
