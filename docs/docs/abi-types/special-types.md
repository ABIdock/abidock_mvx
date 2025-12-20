---
id: special-types
title: Special Types
sidebar_position: 5
description: Handle MultiversX domain-specific ABI types including Address, TokenIdentifier, H256 hashes, and CodeMetadata.
---

# Special Types

Special types handle domain-specific MultiversX data like addresses, tokens, and hashes.

## Address

32-byte MultiversX addresses:

```dart
// From bech32 string directly
final address = AddressType.create(
  'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu'
);

// nativeValue returns the bech32 string
final bech32 = address.nativeValue; // String: 'erd1qqq...'
print(bech32);

// For bytes or hex representation, use the AddressValue methods
final addressValue = address as AddressValue;
print(addressValue.toBech32()); // erd1qqq...
print(addressValue.toHex());    // 0000...
```

### Creating Address Values

```dart
// Method 1: Static factory - AddressType.create()
final addr1 = AddressType.create(
  'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu'
);

// Method 2: Direct constructor - AddressValue.fromBech32()
final addr2 = AddressValue.fromBech32(
  'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th'
);

// Method 3: Via type singleton
final addr3 = AddressType.type.createValue(
  'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu'
);

// From hex string
final fromHex = AddressType.create(
  '0000000000000000000000000000000000000000000000000000000000000000'
);

// From bytes
final fromBytes = AddressType.create(List<int>.filled(32, 0));

// Zero address (system address)
final zeroAddr = AddressType.createZero();
```

## TokenIdentifier

ESDT token identifiers:

```dart
// Standard ESDT
final token = TokenIdentifierType.create('USDC-123456');
print(token.nativeValue); // 'USDC-123456'

// NFT collection
final nft = TokenIdentifierType.create('MYNFT-abc123');
```

### Token Identifier Format

```
TICKER-randomhex
└─────┘ └───────┘
 3-10    6 hex
 chars   chars
```

Examples:
- `WEGLD-bd4d79` - Wrapped EGLD
- `USDC-c76f1f` - USD Coin
- `MEX-455c57` - MEX token

## EgldOrEsdtTokenIdentifier

Either EGLD or an ESDT token:

```dart
// EGLD
final egld = EgldOrEsdtTokenIdentifierType.create('EGLD');
print(egld.nativeValue); // 'EGLD'

// ESDT
final esdt = EgldOrEsdtTokenIdentifierType.create('USDC-123456');
print(esdt.nativeValue); // 'USDC-123456'
```

This is commonly used in payable endpoints that accept either EGLD or tokens.

## EsdtTokenPayment

Complete token payment information:

```dart
// Define EsdtTokenPayment type
final paymentType = StructBuilder('EsdtTokenPayment')
    .field('token_identifier', TokenIdentifierType.type)
    .field('token_nonce', U64Type.type)
    .field('amount', BigUIntType.type)
    .build();

// Create payment value
final payment = paymentType.createValue({
  'token_identifier': 'USDC-123456',
  'token_nonce': BigInt.zero,  // 0 for fungible
  'amount': BigInt.from(1000000),
});
```

### NFT Payment

```dart
// Define EsdtTokenPayment type
final paymentType = StructBuilder('EsdtTokenPayment')
    .field('token_identifier', TokenIdentifierType.type)
    .field('token_nonce', U64Type.type)
    .field('amount', BigUIntType.type)
    .build();

// NFT with nonce
final nftPayment = paymentType.createValue({
  'token_identifier': 'MYNFT-abc123',
  'token_nonce': BigInt.from(42),  // NFT nonce
  'amount': BigInt.one,
});
```

## H256

32-byte hash values (256 bits):

```dart
import 'dart:typed_data';

// From bytes (must be exactly 32 bytes)
final hash = H256Type.create(List<int>.filled(32, 0));
print(hash.nativeValue); // Uint8List of 32 bytes

// From hex string (64 characters)
final hashHex = H256Type.create(
  '0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20'
);

// Common use: transaction hashes, merkle roots
```

## CodeMetadata

Smart contract deployment metadata stored as 16-bit integer (2 bytes, big-endian):

```dart
// From integer flags
final metadata = CodeMetadataType.create(0x0506); // upgradeable + readable + payable + payableBySc

// Check individual flags on the value
print(metadata.isUpgradeable);  // true
print(metadata.isReadable);     // true
print(metadata.isPayable);      // true
print(metadata.isPayableBySc);  // true

// From byte array (2 bytes, big-endian)
final fromBytes = CodeMetadataType.create([0x05, 0x06]); // All flags set
```

### Metadata Flags (Big-Endian Layout)

CodeMetadata uses a 2-byte big-endian format where flags are split across both bytes:

| Flag | Hex Value | Byte | Bit | Description |
|------|-----------|------|-----|-------------|
| `upgradeable` | `0x0100` | 0 | 0 | Contract can be upgraded |
| `readable` | `0x0400` | 0 | 2 | Other contracts can read storage |
| `payable` | `0x0002` | 1 | 1 | Can receive EGLD |
| `payableBySc` | `0x0004` | 1 | 2 | Can receive from smart contracts |

### Common Flag Combinations

```dart
// Upgradeable only
final upgradeOnly = CodeMetadataType.create(0x0100);

// Upgradeable + readable
final upgradeRead = CodeMetadataType.create(0x0500);

// Upgradeable + payable
final upgradePay = CodeMetadataType.create(0x0102);

// Upgradeable + readable + payable
final standard = CodeMetadataType.create(0x0502);

// All flags (upgradeable + readable + payable + payableBySc)
final allFlags = CodeMetadataType.create(0x0506);
```

## ManagedDecimal

Fixed-point decimal numbers:

```dart
// Decimal with 18 places (like EGLD)
final decimal = ManagedDecimalType.create(
  BigInt.parse('1500000000000000000'), // 1.5 * 10^18
  18, // scale
);

// The value represents 1.5
```

## Nothing

The unit/void type:

```dart
final nothing = NothingType.create();
print(nothing.nativeValue); // null
```

Used for endpoints that don't return a value.

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:typed_data';

void main() {
  print('=== Special Types Demo ===\n');
  
  // === Address ===
  print('Address:');
  final address = AddressType.create(
    'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu'
  );
  final bech32 = address.nativeValue;  // String
  final addressValue = address as AddressValue;
  print('  Bech32: $bech32');
  print('  Hex: ${addressValue.toHex().substring(0, 16)}...');
  
  // === TokenIdentifier ===
  final token = TokenIdentifierType.create('WEGLD-bd4d79');
  print('  Token: ${token.nativeValue}');
  
  // === EgldOrEsdtTokenIdentifier ===
  final egld = EgldOrEsdtTokenIdentifierType.create('EGLD');
  final esdt = EgldOrEsdtTokenIdentifierType.create('MEX-455c57');
  print('  EGLD: ${egld.nativeValue}');
  print('  ESDT: ${esdt.nativeValue}');
  
  // === EsdtTokenPayment ===
  
  // Define the type
  final paymentType = StructBuilder('EsdtTokenPayment')
      .field('token_identifier', TokenIdentifierType.type)
      .field('token_nonce', U64Type.type)
      .field('amount', BigUIntType.type)
      .build();
  
  // Create the value
  final payment = paymentType.createValue({
    'token_identifier': 'USDC-c76f1f',
    'token_nonce': BigInt.zero,
    'amount': BigInt.from(1000000),
  });
  print('  Payment: ${payment.nativeValue}');
  
  // === H256 ===
  final hash = H256Type.create(
    Uint8List.fromList(List.generate(32, (i) => i * 8))
  );
  final hashBytes = hash.nativeValue as Uint8List;
  print('  First 8 bytes: ${hashBytes.take(8).toList()}');
  print('  Length: ${hashBytes.length} bytes');
  
  // === CodeMetadata ===
  final metadata = CodeMetadataType.create(0x0502); // upgradeable + readable + payable
  final metaVal = metadata as CodeMetadataValue;
  print('  Upgradeable: ${metaVal.isUpgradeable}');
  print('  Payable: ${metaVal.isPayable}');
  print('  Metadata: ${metadata.nativeValue}');
  
  // === Nothing ===
  final nothing = NothingType.create();
  print('  Value: ${nothing.nativeValue}'); // null
}
```

## Common Patterns

### Token Amount Formatting

```dart
// Format token amount with decimals
String formatAmount(BigInt amount, int decimals) {
  final divisor = BigInt.from(10).pow(decimals);
  final whole = amount ~/ divisor;
  final fraction = (amount % divisor).toString().padLeft(decimals, '0');
  return '$whole.$fraction';
}

// Usage
final amount = BigInt.parse('1500000000000000000'); // 1.5 EGLD
print(formatAmount(amount, 18)); // '1.500000000000000000'
```

### Working with Token Payments

```dart
// Parse EsdtTokenPayment from query result
void parsePayment(StructValue payment) {
  final tokenId = payment.getFieldValue('token_identifier')?.nativeValue;
  final nonce = payment.getFieldValue('token_nonce')?.nativeValue as BigInt;
  final amount = payment.getFieldValue('amount')?.nativeValue as BigInt;
  
  if (nonce == BigInt.zero) {
    print('Fungible: $tokenId, Amount: $amount');
  } else {
    print('NFT: $tokenId-${nonce.toRadixString(16)}, Amount: $amount');
  }
}
```

## Next Steps

- [Mixed & Nested Types](/docs/abi-types/mixed-nested-types) - Complex combinations
- [Primitive Types](/docs/abi-types/primitive-types) - Basic types
- [Collection Types](/docs/abi-types/collection-types) - Lists, options
- [Composite Types](/docs/abi-types/composite-types) - Structs, enums
