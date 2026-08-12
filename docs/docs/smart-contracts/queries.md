---
id: queries
title: Contract Queries
sidebar_position: 3
description: Perform free read-only queries to MultiversX smart contract views without gas or transaction signing.
---

# Contract Queries

Queries are free read-only calls to smart contract views. They don't require gas or signing.

## Basic Query

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:io';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final abiJson = await File('contract.abi.json').readAsString();
  final abi = SmartContractAbi.fromJson(abiJson);
  
  final controller = SmartContractController(
    contractAddress: SmartContractAddress.fromBech32('erd1qqq...'),
    networkProvider: provider,
    abi: abi,
  );
  
  // Query a view function - returns native Dart values
  final result = await controller.query(
    endpointName: 'getTotalSupply',
    arguments: [],
  );
  
  // Get the return value (already converted to native type)
  final totalSupply = result.first;
  print('Total Supply: $totalSupply');
}
```

## Passing Arguments

Pass native Dart values - the controller handles type conversion:

```dart
// ABI: getBalance(address: Address) -> BigUint
final result = await controller.query(
  endpointName: 'getBalance',
  arguments: [
    'erd1user...',  // bech32 string (controller converts to Address internally)
  ],
);
```

### Multiple Arguments

```dart
// ABI: getUserInfo(id: u64, includeHistory: bool) -> UserInfo
final result = await controller.query(
  endpointName: 'getUserInfo',
  arguments: [
    BigInt.from(123),  // u64
    true,              // bool
  ],
);
```

## Reading Results

Results are automatically converted to native Dart types.

### Single Value

```dart
// ABI: getValue() -> u64
final result = await controller.query(
  endpointName: 'getValue',
  arguments: [],
);

// Use infer<T>() for type-safe access
final value = infer<BigInt>(result.first);
print('Value: $value');
```

### Multiple Return Values

```dart
// ABI: getStats() -> multi<u64, u64, BigUint>
final result = await controller.query(
  endpointName: 'getStats',
  arguments: [],
);

// Results are returned as a list - use infer<T>() for type safety
final count = infer<BigInt>(result[0]);
final max = infer<BigInt>(result[1]);
final total = infer<BigInt>(result[2]);
```

### Struct Results

```dart
// ABI: getUser(id: u64) -> User (struct)
final result = await controller.query(
  endpointName: 'getUser',
  arguments: [BigInt.from(1)],
);

// Struct returned as Map
final user = result.first as Map<String, dynamic>;
final name = user['name'] as String;
final balance = user['balance'] as BigInt;

print('User: $name, Balance: $balance');
```

### List Results

```dart
// ABI: getAllUsers() -> List<User>
final result = await controller.query(
  endpointName: 'getAllUsers',
  arguments: [],
);

// List of structs
final users = result.first as List;
for (final user in users) {
  final userMap = user as Map<String, dynamic>;
  print('User: ${userMap['name']}');
}
```

### Option Results

```dart
// ABI: findUser(id: u64) -> Option<User>
final result = await controller.query(
  endpointName: 'findUser',
  arguments: [BigInt.from(999)],
);

// Option is null if None, or the value if Some
final maybeUser = result.first;
if (maybeUser != null) {
  final userMap = maybeUser as Map<String, dynamic>;
  print('Found: ${userMap['name']}');
} else {
  print('User not found');
}
```

## Query with Caller

Some views check the caller address:

```dart
final result = await controller.query(
  endpointName: 'getMyBalance',
  arguments: [],
  caller: myAddress, // Set caller context
);
```

## Error Handling

```dart
try {
  final result = await controller.query(
    endpointName: 'getValue',
    arguments: [],
  );
  
  print('Value: ${result.first}');
} on SmartContractQueryException catch (e) {
  print('Contract query error: ${e.message}');
  print('Return code: ${e.code}');  // e.g. 'user error', 'network_error'
} on NetworkException catch (e) {
  print('Network error: ${e.message}');
} on ArgumentEncodingException catch (e) {
  print('ABI encoding error: ${e.message}');
} on ResponseParsingException catch (e) {
  print('ABI parsing error: ${e.message}');
}
```

## Complete Example

```dart
import 'dart:io';
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  
  // Load a DEX pair ABI
  final abiJson = File('assets/pair.abi.json').readAsStringSync();
  final abi = SmartContractAbi.fromJson(abiJson);
  
  // A real pair contract on devnet
  final pairAddress = SmartContractAddress.fromBech32(
    'erd1qqqqqqqqqqqqqpgqeel2kumf0r8ffyhth7pqdujjat9nx0862jpsg2pqaq'
  );
  
  final controller = SmartContractController(
    contractAddress: pairAddress,
    abi: abi,
    networkProvider: provider,
  );
  
  print('=== DEX Pair Query Demo ===\n');
  
  // Query reserves
  final reserves = await controller.query(
    endpointName: 'getReservesAndTotalSupply',
    arguments: [],
  );
  
  print('First Token Reserve: ${reserves[0]}');
  print('Second Token Reserve: ${reserves[1]}');
  print('Total LP Supply: ${reserves[2]}');
  
  // Query token identifiers
  final firstToken = await controller.query(
    endpointName: 'getFirstTokenId',
    arguments: [],
  );
  
  final secondToken = await controller.query(
    endpointName: 'getSecondTokenId',
    arguments: [],
  );
  
  print('  First: ${firstToken.first}');
  print('  Second: ${secondToken.first}');
}
```

## Performance Tips

:::tip Batch Queries
For multiple queries, consider using `Future.wait`:
```dart
final results = await Future.wait([
  controller.query(endpointName: 'getValue1', arguments: []),
  controller.query(endpointName: 'getValue2', arguments: []),
  controller.query(endpointName: 'getValue3', arguments: []),
]);
```
:::

## Raw Queries Without ABI

When you don't have an ABI or prefer to work with raw bytes, use `queryRaw()`:

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  
  // Create controller WITHOUT ABI
  final controller = SmartContractController.withoutAbi(
    contractAddress: SmartContractAddress.fromBech32('erd1qqq...'),
    networkProvider: provider,
  );
  
  // Query with TypedValue arguments
  final result = await controller.queryRaw(
    endpointName: 'getBalance',
    arguments: [
      AddressValue.fromBech32('erd1user...'),
    ],
  );
  
  // Access raw bytes
  if (result.isSuccess && !result.isEmpty) {
    final balanceBytes = result.first!;
    
    // Decode manually using BinaryCodec
    final codec = BinaryCodec.withDefaults();
    final balanceValue = codec.decodeTopLevel(
      balanceBytes,
      BigUIntType.type,
    ) as BigUIntValue;
    print('Balance: ${balanceValue.value}');
  }
}
```

### RawQueryResult Structure

The `RawQueryResult` provides access to raw response data:

```dart
final result = await controller.queryRaw(
  endpointName: 'getData',
  arguments: [],
);

// Check status
if (result.isSuccess) {
  // Number of return values
  print('Parts: ${result.length}');
  
  // Access by index
  final firstPart = result[0]; // Uint8List
  
  // Iterate all parts
  for (final bytes in result.returnDataParts) {
    print('Bytes: ${HexUtils.bytesToHex(bytes)}');
  }
}

// Access return code and message
print('Code: ${result.returnCode}');
print('Message: ${result.returnMessage}');
```

### When to Use Raw Queries

| Scenario | Approach |
|----------|----------|
| Have ABI file | Use `query()` with native values |
| No ABI available | Use `queryRaw()` with TypedValue |
| Custom decoding needed | Use `queryRaw()` |
| Working with unknown contracts | Use `queryRaw()` |
| Performance-critical batch ops | Use `queryRaw()` to skip parsing |

:::tip TypedValue Types
Common TypedValue types for arguments:
- `BigUIntValue(BigInt.from(100))` - unsigned integers
- `AddressValue.fromBech32('erd1...')` - addresses
- `TokenIdentifierValue('TOKEN-abc123')` - token identifiers
- `BooleanValue(true)` - booleans
- `U8Value(42)`, `U32Value(1000)` - specific integer sizes
:::

## Parsing Nested Types Without ABI

When contract endpoints return complex nested types (structs, lists of structs, options), you need to manually define the type structure and decode the raw bytes.

### Decoding a Struct

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  
  final controller = SmartContractController.withoutAbi(
    contractAddress: SmartContractAddress.fromBech32('erd1qqq...'),
    networkProvider: provider,
  );
  
  // Define the struct type manually (matching contract's struct definition)
  // Example: EsdtTokenPayment { token_identifier, token_nonce, amount }
  final tokenPaymentType = StructBuilder('EsdtTokenPayment')
      .field('token_identifier', TokenIdentifierType.type)
      .field('token_nonce', U64Type.type)
      .field('amount', BigUIntType.type)
      .build();
  
  // Query the contract
  final result = await controller.queryRaw(
    endpointName: 'getLastPayment',
    arguments: [],
  );
  
  if (result.isSuccess && !result.isEmpty) {
    final codec = BinaryCodec.withDefaults();
    final paymentValue = codec.decodeTopLevel(
      result.first!,
      tokenPaymentType,
    ) as StructValue;
    
    // Access struct fields (getFieldValue returns the TypedValue)
    final tokenId =
        paymentValue.getFieldValue('token_identifier').nativeValue as String;
    final nonce = paymentValue.getFieldValue('token_nonce').nativeValue as BigInt;
    final amount = paymentValue.getFieldValue('amount').nativeValue as BigInt;
    
    print('Token: $tokenId, Nonce: $nonce, Amount: $amount');
  }
}
```

### Decoding a List of Structs

```dart
// Define the element type (struct)
final tokenPaymentType = StructBuilder('EsdtTokenPayment')
    .field('token_identifier', TokenIdentifierType.type)
    .field('token_nonce', U64Type.type)
    .field('amount', BigUIntType.type)
    .build();

// Define the list type
final paymentsListType = ListType(tokenPaymentType);

final result = await controller.queryRaw(
  endpointName: 'getAllPayments',
  arguments: [],
);

if (result.isSuccess && !result.isEmpty) {
  final codec = BinaryCodec.withDefaults();
  final listValue = codec.decodeTopLevel(
    result.first!,
    paymentsListType,
  ) as ListValue;
  
  // Iterate over the list
  for (final item in listValue.elements) {
    final payment = item as StructValue;
    final tokenId = payment.getFieldValue('token_identifier').nativeValue;
    final amount = payment.getFieldValue('amount').nativeValue;
    print('Token: $tokenId, Amount: $amount');
  }
}
```

### Decoding an Option (Nullable Result)

```dart
// Option<EsdtTokenPayment>
final optionPaymentType = OptionType(tokenPaymentType);

final result = await controller.queryRaw(
  endpointName: 'getMaybePayment',
  arguments: [U64Value(BigInt.from(123))],
);

if (result.isSuccess && !result.isEmpty) {
  final codec = BinaryCodec.withDefaults();
  final optionValue = codec.decodeTopLevel(
    result.first!,
    optionPaymentType,
  ) as OptionValue;
  
  if (optionValue.isNone) {
    print('No payment found');
  } else {
    final payment = optionValue.unwrap() as StructValue;
    print('Found: ${payment.getFieldValue('amount').nativeValue}');
  }
}
```

### Nested Structs (Struct within Struct)

```dart
// Define the inner struct
final tokenPaymentType = StructBuilder('EsdtTokenPayment')
    .field('token_identifier', TokenIdentifierType.type)
    .field('token_nonce', U64Type.type)
    .field('amount', BigUIntType.type)
    .build();

// Define the outer struct containing the inner struct
final userInfoType = StructBuilder('UserInfo')
    .field('user_address', AddressType.type)
    .field('user_id', U64Type.type)
    .field('last_payment', tokenPaymentType) // Nested struct!
    .build();

final result = await controller.queryRaw(
  endpointName: 'getUserInfo',
  arguments: [AddressValue.fromBech32('erd1user...')],
);

if (result.isSuccess && !result.isEmpty) {
  final codec = BinaryCodec.withDefaults();
  final userValue = codec.decodeTopLevel(
    result.first!,
    userInfoType,
  ) as StructValue;
  
  // Access outer struct fields
  final userAddress = userValue.getFieldValue('user_address').nativeValue;
  final userId = userValue.getFieldValue('user_id').nativeValue;
  
  // Access nested struct
  final lastPayment = userValue.getFieldValue('last_payment') as StructValue;
  final paymentAmount = lastPayment.getFieldValue('amount').nativeValue;
  
  print('User: $userAddress, Last payment: $paymentAmount');
}
```

### Tuples

```dart
// Tuple: (Address, BigUint, u64)
final tupleType = TupleType([
  AddressType.type,
  BigUIntType.type,
  U64Type.type,
]);

final result = await controller.queryRaw(
  endpointName: 'getStats',
  arguments: [],
);

if (result.isSuccess && !result.isEmpty) {
  final codec = BinaryCodec.withDefaults();
  final tupleValue = codec.decodeTopLevel(
    result.first!,
    tupleType,
  ) as TupleValue;
  
  // Access by index
  final address = tupleValue[0].nativeValue;
  final amount = tupleValue[1].nativeValue;
  final count = tupleValue[2].nativeValue;
}
```

### StructBuilder Convenience Methods

`StructBuilder` provides shorthand methods for common field types:

```dart
final userType = StructBuilder('User')
    .addressField('address')       // AddressType
    .u64Field('id')                // U64Type
    .stringField('name')           // StringType
    .boolField('is_active')        // BooleanType
    .bigUIntField('balance')       // BigUIntType
    .field('custom', ListType(U32Type.type)) // Any type
    .build();
```

:::tip Type Matching
The struct field order and types must exactly match the contract's struct definition. Field names don't need to match (they're for your convenience), but the order and types must be correct for decoding to work.
:::

## Next Steps

- [Interactions](/docs/smart-contracts/interactions) - Execute state-changing calls
- [ABI Types](/docs/abi-types/overview) - Understand type encoding
- [Relayed Transactions](/docs/smart-contracts/relayed-transactions) - Gas-free calls
