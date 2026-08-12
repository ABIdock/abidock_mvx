---
id: collection-types
title: Collection Types
sidebar_position: 3
description: Use MultiversX ABI collection types including List, Array, and Option for handling multiple and optional values.
---

# Collection Types

Collection types hold multiple values or represent an optional value.

:::info Element Type Parameter
Collection types pass native values straight to the element type's `createValue`:
- `List<u32>` - pass `int` values (u32 takes int)
- `List<u64>` - pass `int` or `BigInt` values
- `List<MyStruct>` - pass `Map<String, dynamic>` values
:::

:::note Casting
`createValue` is declared on `AbiType` and returns the base `TypedValue`. Cast to the concrete class
(`as ListValue`, `as OptionValue`, ...) when you need `elements`, `isSome`, `items` and friends.
:::

## Wire format

| Type | Top-level | Nested |
|------|-----------|--------|
| `List<T>` | items concatenated, each **nested**-encoded | `[u32 count]` then the items, nested-encoded |
| `array<N,T>` | N items nested-encoded, no count | identical -- the length lives in the type |
| `Option<T>` | empty buffer = `None`; otherwise `0x01` + nested `T` | `0x00` = `None`; `0x01` + nested `T` = `Some` |

Because a top-level `List<T>` has no count, it decodes by consuming the buffer until it runs out;
each item still uses its self-delimiting nested form. This is why `List<BigUint>` items carry a
4-byte length prefix even at the top level.

## List

Dynamic-length sequences of the same type:

```dart
// Define a list type for u64 values
final listType = ListType(U64Type.type);

// Create a list value using native Dart values
final list = listType.createValue(<BigInt>[
  BigInt.from(1),
  BigInt.from(2),
  BigInt.from(3),
]) as ListValue;

// Access native values (List<dynamic> of BigInt)
print(list.nativeValue); // [1, 2, 3]

// Access items as typed values
for (final TypedValue item in list.elements) {
  print('Item: ${item.nativeValue}');
}
```

### Empty List

```dart
final listType = ListType(U64Type.type);
final emptyList = listType.createValue(<BigInt>[]) as ListValue;
print(emptyList.elements.isEmpty); // true
```

An empty list is an empty buffer at the top level, and `00 00 00 00` when nested.

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
final users = userListType.createValue(<Map<String, dynamic>>[
  <String, dynamic>{
    'name': 'Alice',
    'balance': BigInt.from(1000),
  },
  <String, dynamic>{
    'name': 'Bob',
    'balance': BigInt.from(2000),
  },
]) as ListValue;
```

## Array

Fixed-length sequences (size known from the type):

```dart
// Define array type with fixed size of 3 u32 elements
final arrayType = ArrayType(U32Type.type, 3);

// Create array value using native int values (u32 takes int)
final array = arrayType.createValue(<int>[100, 200, 300]) as ArrayValue;

// Access like a list
print(array.nativeValue);        // [100, 200, 300]
print(array.elements.length);    // 3
```

:::note Array vs List
- **Array**: fixed size carried by the type (`array3<u32>`), never written on the wire
- **List**: dynamic size (`List<u32>`), counted when nested
:::

`arrayN<u8>` is special-cased to `ManagedByteArray<N>` when a type formula is parsed, since that is
how contracts express fixed-size byte buffers.

## Option

A value that may or may not exist:

### Some (has value)

```dart
// Define option type
final optionType = OptionType(U64Type.type);

// Create Some variant with a value
final some = optionType.createValue(BigInt.from(42)) as OptionValue;

print(some.isSome);      // true
print(some.isNone);      // false
print(some.nativeValue); // BigInt 42

// Unwrap to get the inner typed value
final inner = some.unwrap();
print(inner.nativeValue); // BigInt 42
```

### None (no value)

```dart
// Define option type
final optionType = OptionType(U64Type.type);

// Create None variant by passing null
final none = optionType.createValue(null) as OptionValue;

print(none.isSome);      // false
print(none.isNone);      // true
print(none.nativeValue); // null

// unwrap() on None throws StateError - check first
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

// Some user - pass a native map
final someUser = optionalUserType.createValue(<String, dynamic>{
  'name': 'Alice',
  'balance': BigInt.from(1000),
}) as OptionValue;

// None user - pass null
final noUser = optionalUserType.createValue(null) as OptionValue;
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
  final name = user.getFieldValue('name').nativeValue;
  print('Found user: $name');
}
```

## Variadic

`variadic<T>` is an **argument shape**, not a container: it means "zero or more further arguments of
type T", each occupying its own top-level buffer.

```dart
// Define variadic type for addresses
final variadicType = VariadicType.of(AddressType.type);

// Create variadic value from a list of bech32 strings
final variadic = variadicType.createValue(<String>[
  'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
  'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
]) as VariadicValue;

// Access items - nativeValue of an address is its bech32 string
for (final TypedValue addr in variadic.items) {
  print('Address: ${addr.nativeValue}');
}
```

Rules the codec enforces:

- `variadic<T>` may only appear as the **last** input or output of an endpoint.
- `counted-variadic<T>` (`VariadicType.counted`) has **no single-buffer form at all**: the count is
  one top-level argument (`2` -> `0x02`, `0` -> empty) and every item is a further argument. Encoding
  it into one buffer throws `AbiBinaryCodecException`; go through `ArgSerializer` /
  `ArgumentEncoder` -- which is what the controllers and generated code do.
- `variadic<ManagedDecimal>` with more than one item is rejected: the items would have no
  discoverable boundaries.

## Optional

`optional<T>` is the "argument may simply be absent" shape:

```dart
// Define optional type
final optionalType = OptionalType.of(U64Type.type);

// Has value - pass the value
final provided = optionalType.createValue(BigInt.from(100)) as OptionalValue;
print(provided.isProvided); // true

// No value - pass null
final missing = optionalType.createValue(null) as OptionalValue;
print(missing.isMissing);   // true
```

On the wire, a missing `optional<T>` is simply an argument that was never sent, and a provided one
is the top-level encoding of `T`. It has **no nested form** -- putting `optional<T>` inside a struct
or list throws `AbiBinaryCodecException`. Use `Option<T>` there instead.

| Shape | Where it is legal | Missing value |
|-------|-------------------|---------------|
| `Option<T>` | anywhere, including nested | `0x00` nested, empty buffer top-level |
| `optional<T>` | last endpoint argument only | argument omitted entirely |
| `variadic<T>` | last endpoint argument only | zero further arguments |

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() {
  print('=== Collection Types Demo ===\n');

  // === List ===
  final listType = ListType(U64Type.type);
  final list = listType.createValue(<BigInt>[
    BigInt.from(10),
    BigInt.from(20),
    BigInt.from(30),
  ]) as ListValue;

  print('  Items: ${list.elements.map((TypedValue i) => i.nativeValue).toList()}');
  print('  Count: ${list.elements.length}');

  // === Array (u32 takes int, not BigInt) ===
  final arrayType = ArrayType(U32Type.type, 3);
  final array = arrayType.createValue(<int>[1, 2, 3]) as ArrayValue;

  print('  Fixed size: ${array.elements.length}');
  print('  Values: ${array.nativeValue}');

  // === Option Some ===
  final optionType = OptionType(U64Type.type);
  final some = optionType.createValue(BigInt.from(42)) as OptionValue;
  print('  isSome: ${some.isSome}');
  print('  value: ${some.unwrap().nativeValue}');

  // === Option None ===
  final none = optionType.createValue(null) as OptionValue;
  print('  isNone: ${none.isNone}');
  print('  nativeValue: ${none.nativeValue}');

  // === List of Options ===
  final listOfOptionsType = ListType(optionType);
  final listOfOptions = listOfOptionsType.createValue(<dynamic>[
    BigInt.from(1), // Some(1)
    null,           // None
    BigInt.from(3), // Some(3)
  ]) as ListValue;

  for (int i = 0; i < listOfOptions.elements.length; i++) {
    final opt = listOfOptions.elements[i] as OptionValue;
    final Object? display = opt.isSome ? opt.unwrap().nativeValue : 'None';
    print('  [$i]: $display');
  }
}
```

## Working with Query Results

`QueryResult.values` (and `first`) hold **native** Dart values, so a returned `List<User>` arrives as
a `List` of `Map`s:

```dart
// Query returns List<User>
final result = await controller.query(
  endpointName: 'getAllUsers',
  arguments: <dynamic>[],
);

final users = result.first as List<dynamic>;
print('Found ${users.length} users');

for (final dynamic user in users) {
  final userMap = user as Map<String, dynamic>;
  print('User: ${userMap['name']}');
}
```

`Option<T>` collapses to the inner value or `null`:

```dart
// Query returns Option<User>
final result = await controller.query(
  endpointName: 'findUser',
  arguments: <dynamic>[BigInt.from(123)],
);

final dynamic maybeUser = result.first;
if (maybeUser != null) {
  final userMap = maybeUser as Map<String, dynamic>;
  print('Found: ${userMap['name']}');
} else {
  print('User not found');
}
```

Reach for `result.typedValues` when you want `ListValue` / `OptionValue` with their ABI types
instead of the flattened native values.

## Next Steps

- [Composite Types](/docs/abi-types/composite-types) - Structs, enums, tuples
- [Special Types](/docs/abi-types/special-types) - Address, tokens, etc.
- [Mixed & Nested Types](/docs/abi-types/mixed-nested-types) - Complex combinations
