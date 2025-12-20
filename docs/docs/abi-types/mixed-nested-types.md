---
id: mixed-nested-types
title: Mixed & Nested Types
sidebar_position: 6
description: Work with complex nested MultiversX ABI structures like lists of structs, optional tuples, and enum variants.
---

# Mixed & Nested Types

Real-world smart contracts often use complex nested type structures. This guide covers common patterns.

## List of Structs

```dart
// Define User type
final userType = StructBuilder('User')
    .field('id', U64Type.type)
    .field('name', StringType.type)
    .field('balance', BigUIntType.type)
    .build();

// Create the ListType for users
final usersListType = ListType(userType);

// Create a list of User values - using native Dart maps
final users = usersListType.createValue([
  {
    'id': BigInt.from(1),
    'name': 'Alice',
    'balance': BigInt.from(1000),
  },
  {
    'id': BigInt.from(2),
    'name': 'Bob',
    'balance': BigInt.from(2000),
  },
]);

// Access users
for (final userValue in users.elements) {
  final user = userValue as StructValue;
  final name = user.getFieldValue('name')?.nativeValue;
  final balance = user.getFieldValue('balance')?.nativeValue;
  print('$name: $balance');
}
```

## Nested Structs

```dart
// Define Address type
final addressType = StructBuilder('Address')
    .field('street', StringType.type)
    .field('city', StringType.type)
    .field('zip', StringType.type)
    .build();

// Define UserProfile with nested Address type
final userProfileType = StructBuilder('UserProfile')
    .field('name', StringType.type)
    .field('email', StringType.type)
    .field('shipping_address', addressType)
    .build();

// Create value with nested data using native Dart types
final userProfile = userProfileType.createValue({
  'name': 'Alice',
  'email': 'alice@example.com',
  'shipping_address': {
    'street': '123 Main St',
    'city': 'New York',
    'zip': '10001',
  },
});

// Access nested data
final profile = userProfile;
final shippingAddr = profile.getFieldValue('shipping_address') as StructValue;
final city = shippingAddr.getFieldValue('city')?.nativeValue;
print('Ships to: $city'); // 'New York'
```

## Option of Struct

```dart
// Define User type
final userType = StructBuilder('User')
    .field('id', U64Type.type)
    .field('name', StringType.type)
    .build();

// Create the OptionType for User
final optionalUserType = OptionType(userType);

// Some - user found (pass native map, will be converted)
final foundUser = optionalUserType.createValue({
  'id': BigInt.from(42),
  'name': 'Alice',
});

// None - user not found (pass null)
final notFound = optionalUserType.createValue(null);

// Safe access pattern
void displayUser(OptionValue maybeUser) {
  if (maybeUser.isNone) {
    print('User not found');
    return;
  }
  
  final user = maybeUser.unwrap() as StructValue;
  final name = user.getFieldValue('name')?.nativeValue;
  print('Found user: $name');
}
```

## Enum with Struct Variants

```dart
// Define action enum type with different variants
final actionType = EnumBuilder('Action')
    .variantWithFields('Transfer', 0, [AddressType.type, BigUIntType.type])
    .variantWithFields('Stake', 1, [AddressType.type, BigUIntType.type, U64Type.type])
    .variant('Withdraw', 2)
    .build();

// Create a Transfer action
final transferAction = actionType.createValue({
  'variant': 'Transfer',
  'fields': [
    'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',  // bech32 string
    BigInt.from(1000),
  ],
});

// Create a Stake action
final stakeAction = actionType.createValue({
  'variant': 'Stake',
  'fields': [
    'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',  // bech32 string
    BigInt.from(5000),
    BigInt.from(365),
  ],
});

// Process action
void processAction(EnumValue action) {
  final data = action.nativeValue;
  if (data is! Map) return;
  
  final variant = data['variant'];
  final fields = data['fields'] as List;
  
  switch (variant) {
    case 'Transfer':
      print('Transfer ${fields[1]} to ${fields[0]}');
      break;
    case 'Stake':
      print('Stake ${fields[1]} for ${fields[2]} days');
      break;
  }
}
```

## Tuple with Mixed Types

```dart
// Define Config type
final configType = StructBuilder('Config')
    .field('name', StringType.type)
    .field('value', U32Type.type)
    .build();

// Define tuple type with different element types
final mixedTupleType = TupleType([
  U64Type.type,
  AddressType.type,
  configType,
]);

// Create tuple value using native values
final mixed = mixedTupleType.createValue([
  BigInt.from(123),
  'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',  // bech32 string
  {
    'name': 'Config',
    'value': 100,
  },
]);

// Access tuple elements - nativeValue returns bech32 string for addresses
final id = mixed[0].nativeValue;
final addr = mixed[1].nativeValue;  // String (bech32)
final config = mixed[2] as StructValue;

print('ID: $id');
print('Address: $addr');
print('Config: ${config.getFieldValue('name')?.nativeValue}');
```

## Variadic of Structs

```dart
// Define Payment type
final paymentType = StructBuilder('Payment')
    .field('token', TokenIdentifierType.type)
    .field('amount', BigUIntType.type)
    .build();

// Define variadic type for payments
final variadicPaymentType = VariadicType.of(paymentType);

// Create variadic with native values
final payments = variadicPaymentType.createValue([
  {
    'token': 'USDC-123456',
    'amount': BigInt.from(100),
  },
  {
    'token': 'WEGLD-bd4d79',
    'amount': BigInt.from(200),
  },
]);

// Process all payments
for (final paymentValue in payments.items) {
  final payment = paymentValue as StructValue;
  final token = payment.getFieldValue('token')?.nativeValue;
  final amount = payment.getFieldValue('amount')?.nativeValue;
  print('$token: $amount');
}
```

## List of Options

```dart
// Define option type and list type
final optionType = OptionType(U64Type.type);
final listOfOptionsType = ListType(optionType);

// Create list where each element might be present or not
// pass value for Some, null for None
final maybeValues = listOfOptionsType.createValue([
  BigInt.from(1),  // Some(1)
  null,            // None
  BigInt.from(3),  // Some(3)
  null,            // None
  BigInt.from(5),  // Some(5)
]);

// Process with null-safety
final values = maybeValues.elements.map((item) {
  final opt = item as OptionValue;
  return opt.isSome ? opt.unwrap().nativeValue : null;
}).toList();

print(values); // [1, null, 3, null, 5]
```

## Deeply Nested Structure

```dart
// Real-world example: DEX pool with nested types

// Define TokenInfo type
final tokenInfoType = StructBuilder('TokenInfo')
    .field('identifier', TokenIdentifierType.type)
    .field('reserve', BigUIntType.type)
    .build();

// Define LpInfo type
final lpInfoType = StructBuilder('LpInfo')
    .field('identifier', TokenIdentifierType.type)
    .field('supply', BigUIntType.type)
    .build();

// Define PoolInfo type with nested types
final poolInfoType = StructBuilder('PoolInfo')
    .field('pool_id', U64Type.type)
    .field('tokens', ListType(tokenInfoType))
    .field('lp_token', OptionType(lpInfoType))
    .build();

// Create pool info with nested values
final poolInfo = poolInfoType.createValue({
  'pool_id': BigInt.from(1),
  'tokens': [
    {
      'identifier': 'WEGLD-bd4d79',
      'reserve': BigInt.parse('1000000000000000000000'),
    },
    {
      'identifier': 'USDC-c76f1f',
      'reserve': BigInt.parse('2000000000'),
    },
  ],
  'lp_token': {
    'identifier': 'LPTOKEN-abc123',
    'supply': BigInt.parse('500000000000000000000'),
  },
});

// Navigate the structure
final pool = poolInfo;

// Get pool ID
final poolId = pool.getFieldValue('pool_id')?.nativeValue;
print('Pool ID: $poolId');

// Get tokens
final tokens = pool.getFieldValue('tokens') as ListValue;
for (final tokenValue in tokens.elements) {
  final token = tokenValue as StructValue;
  final id = token.getFieldValue('identifier')?.nativeValue;
  final reserve = token.getFieldValue('reserve')?.nativeValue;
  print('Token: $id, Reserve: $reserve');
}

// Get LP token (if exists)
final lpOption = pool.getFieldValue('lp_token') as OptionValue;
if (lpOption.isSome) {
  final lp = lpOption.unwrap() as StructValue;
  print('LP Token: ${lp.getFieldValue('identifier')?.nativeValue}');
}
```

## Map-like Patterns

MultiversX doesn't have a native Map type, but List of tuples achieves the same:

```dart
// Define tuple type for (Address, BigUint) pairs
final entryTupleType = TupleType([AddressType.type, BigUIntType.type]);

// Define list type for the map entries
final balancesListType = ListType(entryTupleType);

// Create list of tuples as Map<Address, BigUint>
final balances = balancesListType.createValue([
  [
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',  // bech32 string
    BigInt.from(1000),
  ],
  [
    'erd1spyavw0956vq68xj8y4tenjpq2wd5a9p2c6j8gsz7ztyrnpxrruqzu66jx',  // bech32 string
    BigInt.from(2000),
  ],
]);

// Convert to Dart Map - nativeValue returns bech32 string for addresses
final balanceMap = <String, BigInt>{};
for (final entry in balances.elements) {
  final tuple = entry as TupleValue;
  final address = tuple[0].nativeValue as String;  // bech32 string
  final balance = tuple[1].nativeValue as BigInt;
  balanceMap[address] = balance;
}
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() {
  print('=== Mixed & Nested Types Demo ===\n');
  
  // Define types first
  final fillType = StructBuilder('Fill')
      .field('fill_price', BigUIntType.type)
      .field('fill_amount', BigUIntType.type)
      .field('timestamp', U64Type.type)
      .build();
  
  final orderType = StructBuilder('Order')
      .field('order_id', U64Type.type)
      .field('trader', AddressType.type)
      .field('fills', ListType(fillType))
      .field('expiry', OptionType(U64Type.type))
      .build();
  
  // Build a complex order using native values
  final order = orderType.createValue({
    'order_id': BigInt.from(12345),
    'trader': 'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',  // bech32 string
    'fills': [
      {
        'fill_price': BigInt.from(999),
        'fill_amount': BigInt.from(100),
        'timestamp': BigInt.from(1699999999),
      },
      {
        'fill_price': BigInt.from(1001),
        'fill_amount': BigInt.from(200),
        'timestamp': BigInt.from(1700000000),
      },
    ],
    'expiry': BigInt.from(1700100000),
  });
  
  // Navigate and display
  print('Order ID: ${order.getFieldValue('order_id')?.nativeValue}');
  
  final trader = order.getFieldValue('trader')?.nativeValue as String;  // bech32 string
  print('Trader: ${trader.substring(0, 20)}...');
  
  final fills = order.getFieldValue('fills') as ListValue;
  print('Fills (${fills.elements.length}):');
  for (final fillValue in fills.elements) {
    final fill = fillValue as StructValue;
    final price = fill.getFieldValue('fill_price')?.nativeValue;
    final amount = fill.getFieldValue('fill_amount')?.nativeValue;
    print('  - $amount @ $price');
  }
  
  final expiry = order.getFieldValue('expiry') as OptionValue;
  if (expiry.isSome) {
    print('Expiry: ${expiry.unwrap().nativeValue}');
  }
  

}
```

## Next Steps

- [Smart Contracts](/docs/smart-contracts/overview) - Use these types with contracts
- [Code Generation](/docs/codegen/overview) - Auto-generate type-safe code
- [Queries](/docs/smart-contracts/queries) - Parse returned types
