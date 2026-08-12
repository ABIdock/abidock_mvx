---
id: special-types
title: Special Types
sidebar_position: 5
description: Handle MultiversX domain-specific ABI types including Address, TokenIdentifier, H256, CodeMetadata and ManagedDecimal.
---

# Special Types

Special types handle domain-specific MultiversX data: addresses, tokens, hashes, contract metadata
and fixed-point decimals.

## Wire format

| Type | Top-level | Nested |
|------|-----------|--------|
| `Address` | exactly 32 bytes | exactly 32 bytes |
| `TokenIdentifier`, `TokenId` | UTF-8 bytes, no prefix | `[u32 length][UTF-8]` |
| `EgldOrEsdtTokenIdentifier` | UTF-8 bytes; native EGLD is a **zero-length** payload | `[u32 length][UTF-8]` |
| `H256` | exactly 32 bytes | exactly 32 bytes |
| `ManagedByteArray<N>` | exactly N bytes | exactly N bytes, no prefix |
| `CodeMetadata` | exactly 2 bytes, big-endian | exactly 2 bytes, big-endian |
| `ManagedDecimal<N>` | magnitude only (scale lives in the type) | `[u32 length][magnitude]` |
| `ManagedDecimal<usize>` | `[u32 length][magnitude][u32 scale]` | `[u32 length][magnitude][u32 scale]` |
| `Nothing` | empty | empty (consumes 0 bytes) |

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

// Bytes and hex are available on the value itself
print(address.toBech32()); // erd1qqq...
print(address.toHex());    // 0000...
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

// Method 3: Via type instance
final addr3 = AddressType.type.createValue(
  'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu'
);

// From hex string
final fromHex = AddressType.create(
  '0000000000000000000000000000000000000000000000000000000000000000'
);

// From bytes
final fromBytes = AddressType.create(List<int>.filled(32, 0));

// Zero address (32 zero bytes, used as the deploy receiver)
final zeroAddr = AddressType.createZero();
```

`AddressType.create` treats a string starting with `erd1` as bech32 and anything else as hex.

## TokenIdentifier

ESDT token identifiers:

```dart
// Standard ESDT
final token = TokenIdentifierType.create('USDC-123456');
print(token.nativeValue); // 'USDC-123456'

// NFT collection
final nft = TokenIdentifierType.create('MYNFT-abc123');
```

`TokenId` in an ABI is the same type with the same wire form.

### Token Identifier Format

```
TICKER-randomhex
└─────┘ └───────┘
 3-10    6 hex
 chars   chars
```

The value class validates this shape: an upper-case ticker of 3-10 alphanumerics starting with a
letter, a dash, exactly 6 lower-case hex characters, and -- for NFT/SFT/MetaESDT instances -- an
optional `-<hexnonce>` suffix. Anything else throws `ArgumentError`.

Examples:
- `WEGLD-bd4d79` - Wrapped EGLD
- `USDC-c76f1f` - USD Coin
- `MEX-455c57` - MEX token
- `MYNFT-abc123-0a` - a single NFT of the `MYNFT-abc123` collection

## EgldOrEsdtTokenIdentifier

Either native EGLD or an ESDT token -- the type payable endpoints use:

```dart
// EGLD
final egld = EgldOrEsdtTokenIdentifierType.create('EGLD');
print(egld.nativeValue); // 'EGLD'
print(egld.isEgld);      // true

// ESDT
final esdt = EgldOrEsdtTokenIdentifierType.create('USDC-123456');
print(esdt.nativeValue); // 'USDC-123456'
print(esdt.isEsdt);      // true
```

Native EGLD has two accepted spellings: the canonical `EGLD-000000`, which encodes as a
**zero-length** payload, and the legacy `EGLD` sentinel, which encodes as its 4 ASCII bytes.
Decoding always canonicalises -- an empty payload and `EGLD` both come back as `EGLD-000000`.

## Token payment structs

`EsdtTokenPayment`, `EgldOrEsdtTokenPayment`, `EgldOrMultiEsdtPayment`, `Payment` and
`FungiblePayment` are built into the framework: contracts use them without ever listing them in the
ABI's `types` map, and the SDK recognises the names intrinsically.

| Struct | Fields, in wire order |
|--------|----------------------|
| `EsdtTokenPayment` | `token_identifier: TokenIdentifier`, `token_nonce: u64`, `amount: BigUint` |
| `EgldOrEsdtTokenPayment` | `token_identifier: EgldOrEsdtTokenIdentifier`, `token_nonce: u64`, `amount: BigUint` |
| `Payment` | `token_identifier: TokenId`, `token_nonce: u64`, `amount: NonZeroBigUint` |
| `FungiblePayment` | `token_identifier: TokenId`, `amount: NonZeroBigUint` |
| `EgldOrMultiEsdtPayment` | `egld_amount: BigUint`, `multi_esdt: List<EsdtTokenPayment>` |

`TokenId` shares the wire form of `TokenIdentifier` and `NonZeroBigUint` that of `BigUint`, so a
`Payment` is `[u32 len][utf8 id][8-byte BE nonce][u32 len][magnitude]` when nested, and a
`FungiblePayment` is `[u32 len][utf8 id][u32 len][magnitude]` in both positions.

Define an equivalent struct yourself when you want to build one by hand:

```dart
// Define EsdtTokenPayment type
final paymentType = StructBuilder('EsdtTokenPayment')
    .field('token_identifier', TokenIdentifierType.type)
    .field('token_nonce', U64Type.type)
    .field('amount', BigUIntType.type)
    .build();

// Create payment value
final payment = paymentType.createValue(<String, dynamic>{
  'token_identifier': 'USDC-123456',
  'token_nonce': BigInt.zero, // 0 for fungible
  'amount': BigInt.from(1000000),
}) as StructValue;
```

### NFT Payment

```dart
// NFT with nonce
final nftPayment = paymentType.createValue(<String, dynamic>{
  'token_identifier': 'MYNFT-abc123',
  'token_nonce': BigInt.from(42), // NFT nonce
  'amount': BigInt.one,
}) as StructValue;
```

For *sending* tokens with a contract call, use `TokenTransferValue.fromPrimitives(...)` and the
`tokenTransfers` parameter instead -- the controller builds the `ESDTTransfer` /
`MultiESDTNFTTransfer` data field for you.

## H256

32-byte hash values (256 bits):

```dart
// From bytes (must be exactly 32 bytes)
final hash = H256Type.create(List<int>.filled(32, 0));
print(hash.nativeValue); // Uint8List of 32 bytes

// From hex string (64 characters)
final hashHex = H256Type.create(
  '0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20'
);

// Common use: transaction hashes, merkle roots
```

## ManagedByteArray

A fixed-size byte buffer whose length is part of the type. `arrayN<u8>` in an ABI parses to
`ManagedByteArray<N>`:

```dart
final keyType = ManagedByteArrayType(32);
final key = ManagedByteArrayValue(keyType, Uint8List(32));
print(key.value.length); // 32
```

It is written as exactly N raw bytes in both positions -- no length prefix anywhere, because the
length is already known from the type.

## CodeMetadata

Smart contract deployment metadata, a 16-bit value stored as 2 big-endian bytes:

```dart
// From integer flags
final metadata = CodeMetadataType.create(0x0506); // upgradeable + readable + payable + payableBySC

// Check individual flags on the value
print(metadata.isUpgradeable); // true
print(metadata.isReadable);    // true
print(metadata.isPayable);     // true
print(metadata.isPayableBySC); // true

// From byte array (2 bytes, big-endian)
final fromBytes = CodeMetadataType.create(<int>[0x05, 0x06]);
```

### Metadata Flags (Big-Endian Layout)

| Flag | Hex value | Byte | Bit | Description |
|------|-----------|------|-----|-------------|
| `upgradeable` | `0x0100` | 0 | 0 | Contract can be upgraded |
| `readable` | `0x0400` | 0 | 2 | Other contracts can read storage |
| `payable` | `0x0002` | 1 | 1 | Can receive EGLD |
| `payableBySC` | `0x0004` | 1 | 2 | Can receive from smart contracts |

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

// All flags (upgradeable + readable + payable + payableBySC)
final allFlags = CodeMetadataType.create(0x0506);
```

`0x0506` is also the default metadata used by `createTransactionForDeploy`.

## ManagedDecimal

Fixed-point decimals. The **raw** value is an integer; the scale says where the decimal point sits.

```dart
// ManagedDecimalType.create(scale, value)
final decimal = ManagedDecimalType.create(
  18,                                     // scale: 18 decimal places
  BigInt.parse('1500000000000000000'),    // raw value = 1.5 * 10^18
);

print(decimal.toDecimalString()); // '1.500000000000000000'
print(decimal.nativeValue);       // BigInt 1500000000000000000 (raw)
```

Scale comes **first**. The type carries the scale, the value carries the digits:

```dart
final priceType = ManagedDecimalType.of(2);             // ManagedDecimal<2>
final price = priceType.createValue(19.99) as ManagedDecimalValue;   // from double
final same = priceType.createValue('19.99') as ManagedDecimalValue;  // from string
final raw = priceType.createValue(BigInt.from(1999)) as ManagedDecimalValue; // raw digits

// Signed and runtime-scaled variants
final signedType = ManagedDecimalType.signed(4);        // ManagedDecimalSigned<4>
final variableType = ManagedDecimalType.variable(2);    // ManagedDecimal<usize>
```

Wire rules worth remembering:

- **Fixed scale** (`ManagedDecimal<N>`): only the magnitude travels; `N` is never written. Nested,
  it is still length-prefixed (`[u32 length][magnitude]`) so the following field can be found.
- **Variable scale** (`ManagedDecimal<usize>`): the scale follows the magnitude as a 4-byte
  big-endian integer, in both positions.
- A `variadic<ManagedDecimal>` with more than one item is rejected, because the items' boundaries
  would be ambiguous.

## Nothing

The unit/void type:

```dart
final nothing = NothingType.create();
print(nothing.nativeValue); // null
```

Used for endpoints that return no value; it encodes to nothing and consumes no bytes.

## Complete Example

```dart
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';

void main() {
  print('=== Special Types Demo ===\n');

  // === Address ===
  final address = AddressType.create(
    'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu'
  );
  print('  Bech32: ${address.nativeValue}');
  print('  Hex: ${address.toHex().substring(0, 16)}...');

  // === TokenIdentifier ===
  final token = TokenIdentifierType.create('WEGLD-bd4d79');
  print('  Token: ${token.nativeValue}');

  // === EgldOrEsdtTokenIdentifier ===
  final egld = EgldOrEsdtTokenIdentifierType.create('EGLD');
  final esdt = EgldOrEsdtTokenIdentifierType.create('MEX-455c57');
  print('  EGLD: ${egld.nativeValue} (isEgld: ${egld.isEgld})');
  print('  ESDT: ${esdt.nativeValue}');

  // === EsdtTokenPayment ===
  final paymentType = StructBuilder('EsdtTokenPayment')
      .field('token_identifier', TokenIdentifierType.type)
      .field('token_nonce', U64Type.type)
      .field('amount', BigUIntType.type)
      .build();

  final payment = paymentType.createValue(<String, dynamic>{
    'token_identifier': 'USDC-c76f1f',
    'token_nonce': BigInt.zero,
    'amount': BigInt.from(1000000),
  }) as StructValue;
  print('  Payment: ${payment.nativeValue}');

  // === H256 ===
  final hash = H256Type.create(
    Uint8List.fromList(List<int>.generate(32, (int i) => i * 8))
  );
  print('  First 8 bytes: ${hash.nativeValue.take(8).toList()}');
  print('  Length: ${hash.nativeValue.length} bytes');

  // === CodeMetadata ===
  final metadata = CodeMetadataType.create(0x0502);
  print('  Upgradeable: ${metadata.isUpgradeable}');
  print('  Payable: ${metadata.isPayable}');
  print('  Metadata: ${metadata.nativeValue}');

  // === ManagedDecimal ===
  final price = ManagedDecimalType.create(2, 19.99);
  print('  Price: ${price.toDecimalString()}');

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
  final BigInt divisor = BigInt.from(10).pow(decimals);
  final BigInt whole = amount ~/ divisor;
  final String fraction = (amount % divisor).toString().padLeft(decimals, '0');
  return '$whole.$fraction';
}

// Usage
final amount = BigInt.parse('1500000000000000000'); // 1.5 EGLD
print(formatAmount(amount, 18)); // '1.500000000000000000'
```

`Balance.toDenominated` / `toDenominatedTrimmed` do the same for EGLD amounts, and
`ManagedDecimalValue.toDecimalString()` for decimals that carry their own scale.

### Working with Token Payments

```dart
// Parse an EsdtTokenPayment-shaped struct from a query result
void parsePayment(StructValue payment) {
  final tokenId =
      payment.getFieldValue('token_identifier').nativeValue as String;
  final nonce = payment.getFieldValue('token_nonce').nativeValue as BigInt;
  final amount = payment.getFieldValue('amount').nativeValue as BigInt;

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
