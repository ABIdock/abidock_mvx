---
id: collection-types
title: Collection Types
sidebar_position: 3
description: Use MultiversX ABI collection types including List, Array, and Option for handling multiple and optional values.
---

# Collection Types

Collection types hold multiple values or represent optional values.

:::info Element Type Parameter
Collection types pass native values to the element type's `createValue` method:
- For `List<U32>` - pass `int` values (U32 takes int)
- For `List<U64>` - pass `int` or `BigInt` values (U64 accepts both)
- For `List<Struct>` - pass `Map<String, dynamic>` values
:::

## List

Dynamic-length sequences of the same type:

```dart
// Define a list type for U64 values
final listType = ListType(U64Type.type);

// Create a list value using native Dart values
final list = listType.createValue([
  BigInt.from(1),
  BigInt.from(2),
  BigInt.from(3),
]);

// Access native value (List<dynamic>)
print(list.nativeValue); // [1, 2, 3] as BigInt values

// Access items
final elements = list.elements; // List<TypedValue>
for (final item in elements) {
  print('Item: ${item.nativeValue}');
}
```

### Empty List

```dart
final listType = ListType(U64Type.type);
final emptyList = listType.createValue([]);
print(emptyList.elements.isEmpty); // true
```

### List of Structs

```dart
// Define User type
final userType = StructBuilder('User')
    .field('name', StringType.type)
    .field('balance', BigUIntType.type)
    .build();

// Create a list type for User values
final userListType = ListType(userType);

// Create list of users using native values
final users = userListType.createValue([
  {
    'name': 'Alice',
    'balance': BigInt.from(1000),
  },
  {
    'name': 'Bob',
    'balance': BigInt.from(2000),
  },
]);
```

## Array

Fixed-length sequences (compile-time known size):

```dart
// Define array type with fixed size of 3 U32 elements
final arrayType = ArrayType(U32Type.type, 3);

// Create array value using native int values (U32 takes int)
final array = arrayType.createValue([100, 200, 300]);

// Access like List
print(array.nativeValue); // [100, 200, 300]
print((array as ArrayValue).elements.length); // 3
```

:::note Array vs List
- **Array**: Fixed size, defined at compile time (`array3<u32>`)
- **List**: Dynamic size, can grow/shrink (`List<u32>`)
:::

## Option

Represents a value that may or may not exist:

### Some (has value)

```dart
// Define option type
final optionType = OptionType(U64Type.type);

// Create Some variant with a value
final some = optionType.createValue(BigInt.from(42));

print(some.isSome); // true
print(some.isNone); // false
print(some.nativeValue); // BigInt(42)

// Unwrap to get the inner value
final inner = some.unwrap();
print(inner.nativeValue); // BigInt(42)
```

### None (no value)

```dart
// Define option type
final optionType = OptionType(U64Type.type);

// Create None variant by passing null
final none = optionType.createValue(null);

print(none.isSome); // false
print(none.isNone); // true
print(none.nativeValue); // null

// Don't unwrap None - check first!
if (none.isSome) {
  final value = none.unwrap();
}
```

### Option of Struct

```dart
// Define User type
final userType = StructBuilder('User')
    .field('name', StringType.type)
    .field('balance', BigUIntType.type)
    .build();

// Define option type for User
final optionalUserType = OptionType(userType);

// Some user - pass native map
final someUser = optionalUserType.createValue({
  'name': 'Alice',
  'balance': BigInt.from(1000),
});

// None user - pass null
final noUser = optionalUserType.createValue(null);
```

### Safe Unwrapping

```dart
// Safe pattern for Option handling
void processUser(OptionValue userOption) {
  if (userOption.isNone) {
    print('No user found');
    return;
  }
  
  final user = userOption.unwrap() as StructValue;
  final name = user.getFieldValue('name')?.nativeValue;
  print('Found user: $name');
}
```

## Variadic

Variable number of arguments (used in function parameters):

```dart
// Define variadic type for addresses
final variadicType = VariadicType.of(AddressType.type);

// Create variadic value from list of bech32 strings
final variadic = variadicType.createValue([
  'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
  'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
]);

// Access items - nativeValue returns bech32 string
for (final addr in variadic.items) {
  print('Address: ${addr.nativeValue}'); // prints bech32 string
}
```

## Optional

Similar to Option, but specifically for optional function parameters:

```dart
// Define optional type
final optionalType = OptionalType.of(U64Type.type);

// Has value - pass the value
final optionalValue = optionalType.createValue(BigInt.from(100));

// No value - pass null
final optionalEmpty = optionalType.createValue(null);
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() {
  print('=== Collection Types Demo ===\n');
  
  // === List ===
  print('List<u64>:');
  final listType = ListType(U64Type.type);
  final list = listType.createValue([
    BigInt.from(10),
    BigInt.from(20),
    BigInt.from(30),
  ]);
  
  print('  Items: ${list.elements.map((i) => i.nativeValue).toList()}');
  print('  Count: ${list.elements.length}');
  
  // === Array (U32 takes int, not BigInt) ===
  final arrayType = ArrayType(U32Type.type, 3);
  final array = arrayType.createValue([1, 2, 3]);
  
  print('  Fixed size: ${(array as ArrayValue).elements.length}');
  print('  Values: ${array.nativeValue}');
  
  // === Option Some ===
  final optionType = OptionType(U64Type.type);
  final some = optionType.createValue(BigInt.from(42));
  print('  isSome: ${some.isSome}');
  print('  value: ${some.unwrap().nativeValue}');
  
  // === Option None ===
  final none = optionType.createValue(null);
  print('  isNone: ${none.isNone}');
  print('  nativeValue: ${none.nativeValue}');
  
  // === List of Options ===
  final listOfOptionsType = ListType(optionType);
  final listOfOptions = listOfOptionsType.createValue([
    BigInt.from(1),  // Some(1)
    null,            // None
    BigInt.from(3),  // Some(3)
  ]);
  
  for (var i = 0; i < listOfOptions.elements.length; i++) {
    final opt = listOfOptions.elements[i] as OptionValue;
    final display = opt.isSome ? opt.unwrap().nativeValue : 'None';
    print('  [$i]: $display');
  }
  

}
```

## Working with Query Results

When a contract returns a collection:

```dart
// Query returns List<User>
final result = await controller.query(
  endpointName: 'getAllUsers',
  arguments: [],
);

final users = result.first as List;
print('Found ${users.length} users');

for (final user in users) {
  final userStruct = user as StructValue;
  final name = userStruct.getFieldValue('name')?.nativeValue;
  print('User: $name');
}
```

```dart
// Query returns Option<User>
final result = await controller.query(
  endpointName: 'findUser',
  arguments: [BigInt.from(123)],
);

final maybeUser = result.first as OptionValue;
if (maybeUser.isSome) {
  final user = maybeUser.unwrap() as StructValue;
  print('Found: ${user.getFieldValue('name')?.nativeValue}');
} else {
  print('User not found');
}
```

## Next Steps

- [Composite Types](/docs/abi-types/composite-types) - Structs, enums, tuples
- [Special Types](/docs/abi-types/special-types) - Address, tokens, etc.
- [Mixed & Nested Types](/docs/abi-types/mixed-nested-types) - Complex combinations
