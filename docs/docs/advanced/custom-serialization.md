---
id: custom-serialization
title: Custom Serialization
sidebar_position: 1
description: Extend abidock_mvx with custom type serializers and codecs for non-standard types and encoding schemes.
---

# Custom Serialization

Extend abidock_mvx with custom type serializers and codecs.

## When You Need Custom Serialization

- Working with non-standard types
- Optimizing serialization for specific use cases
- Integrating with external systems
- Custom encoding schemes

## Type System Architecture

```
┌─────────────────┐
│   AbiType       │  Abstract base type
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
┌───▼───┐ ┌───▼───┐
│Primitive│ │Complex│
│ U8..BigInt│ │Struct,Enum│
└─────────┘ └─────────┘
```

## Creating Custom Types

### Basic Custom Type

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// Custom percentage type (0-100)
class PercentageType extends AbiType {
  final int value;
  
  const PercentageType._(this.value);
  
  static PercentageType create(int value) {
    if (value < 0 || value > 100) {
      throw ArgumentError('Percentage must be 0-100');
    }
    return PercentageType._(value);
  }
  
  @override
  String get typeSignature => 'u8'; // Encoded as u8
  
  @override
  dynamic get nativeValue => value;
  
  @override
  Uint8List toBytes() {
    return Uint8List.fromList([value]);
  }
  
  static PercentageType fromBytes(Uint8List bytes) {
    return create(bytes[0]);
  }
}
```

### Complex Custom Type

```dart
/// Custom money amount with currency
class MoneyType extends AbiType {
  final BigInt amount;
  final String currency;
  
  const MoneyType._({
    required this.amount,
    required this.currency,
  });
  
  static MoneyType create({
    required BigInt amount,
    required String currency,
  }) {
    if (currency.length > 10) {
      throw ArgumentError('Currency code too long');
    }
    return MoneyType._(amount: amount, currency: currency);
  }
  
  @override
  String get typeSignature => 'tuple<BigUint,bytes>'; // Composite
  
  @override
  dynamic get nativeValue => {
    'amount': amount,
    'currency': currency,
  };
  
  @override
  Uint8List toBytes() {
    // Encode as: [amount length][amount bytes][currency bytes]
    final amountBytes = bigIntToBytes(amount);
    final currencyBytes = utf8.encode(currency);
    
    return Uint8List.fromList([
      ...encodeLength(amountBytes.length),
      ...amountBytes,
      ...encodeLength(currencyBytes.length),
      ...currencyBytes,
    ]);
  }
  
  static MoneyType fromBytes(Uint8List bytes) {
    var offset = 0;
    
    // Read amount
    final amountLength = decodeLength(bytes, offset);
    offset += getLengthSize(amountLength);
    final amountBytes = bytes.sublist(offset, offset + amountLength);
    offset += amountLength;
    final amount = bytesToBigInt(amountBytes);
    
    // Read currency
    final currencyLength = decodeLength(bytes, offset);
    offset += getLengthSize(currencyLength);
    final currencyBytes = bytes.sublist(offset, offset + currencyLength);
    final currency = utf8.decode(currencyBytes);
    
    return MoneyType.create(amount: amount, currency: currency);
  }
}
```

## Custom Codec

Create a codec for encoding/decoding:

```dart
class PercentageCodec implements AbiCodec<PercentageType, int> {
  const PercentageCodec();
  
  @override
  PercentageType encode(int value) {
    return PercentageType.create(value);
  }
  
  @override
  int decode(PercentageType abiType) {
    return abiType.value;
  }
  
  @override
  PercentageType fromBytes(Uint8List bytes) {
    return PercentageType.fromBytes(bytes);
  }
  
  @override
  Uint8List toBytes(PercentageType value) {
    return value.toBytes();
  }
}
```

## Registering Custom Types

Register for automatic type resolution:

```dart
class CustomTypeRegistry {
  static final _types = <String, AbiTypeFactory>{};
  
  static void register<T extends AbiType>(
    String signature,
    AbiTypeFactory<T> factory,
  ) {
    _types[signature] = factory;
  }
  
  static AbiType? create(String signature, dynamic value) {
    final factory = _types[signature];
    return factory?.call(value);
  }
}

typedef AbiTypeFactory<T> = T Function(dynamic value);

// Usage
CustomTypeRegistry.register(
  'Percentage',
  (value) => PercentageType.create(value as int),
);
```

## Custom Struct Serializer

```dart
/// Serialize a Dart class to/from ABI struct
class TokenInfoSerializer {
  // Define the type once
  static final tokenInfoType = StructBuilder('TokenInfo')
      .field('identifier', StringType.type)
      .field('decimals', U8Type.type)
      .field('supply', BigUIntType.type)
      .field('paused', BooleanType.type)
      .build();
  
  static StructValue toAbi(TokenInfo info) {
    return tokenInfoType.createValue({
      'identifier': info.identifier,
      'decimals': BigInt.from(info.decimals),
      'supply': info.supply,
      'paused': info.paused,
    });
  }
  
  static TokenInfo fromAbi(StructValue struct) {
    return TokenInfo(
      identifier: struct.getFieldValue('identifier')?.nativeValue as String,
      decimals: (struct.getFieldValue('decimals')?.nativeValue as BigInt).toInt(),
      supply: struct.getFieldValue('supply')?.nativeValue as BigInt,
      paused: struct.getFieldValue('paused')?.nativeValue as bool,
    );
  }
}

class TokenInfo {
  final String identifier;
  final int decimals;
  final BigInt supply;
  final bool paused;
  
  TokenInfo({
    required this.identifier,
    required this.decimals,
    required this.supply,
    required this.paused,
  });
}
```

## Custom Enum Serializer

```dart
enum OrderStatus { pending, filled, cancelled }

class OrderStatusSerializer {
  // Define the enum type once
  static final orderStatusType = EnumBuilder('OrderStatus')
      .variant('Pending', 0)
      .variant('Filled', 1)
      .variant('Cancelled', 2)
      .build();
  
  static EnumValue toAbi(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return orderStatusType.createValue('Pending');
      case OrderStatus.filled:
        return orderStatusType.createValue('Filled');
      case OrderStatus.cancelled:
        return orderStatusType.createValue('Cancelled');
    }
  }
  
  static OrderStatus fromAbi(EnumValue enumValue) {
    switch (enumValue.nativeValue) {
      case 'Pending':
        return OrderStatus.pending;
      case 'Filled':
        return OrderStatus.filled;
      case 'Cancelled':
        return OrderStatus.cancelled;
      default:
        throw ArgumentError('Unknown variant: ${enumValue.nativeValue}');
    }
  }
}
```

## Binary Encoding Helpers

```dart
/// Encode BigInt to minimal bytes
Uint8List bigIntToBytes(BigInt value) {
  if (value == BigInt.zero) {
    return Uint8List(0);
  }
  
  final bytes = <int>[];
  var remaining = value;
  
  while (remaining > BigInt.zero) {
    bytes.insert(0, (remaining & BigInt.from(0xFF)).toInt());
    remaining = remaining >> 8;
  }
  
  return Uint8List.fromList(bytes);
}

/// Decode BigInt from bytes
BigInt bytesToBigInt(Uint8List bytes) {
  var result = BigInt.zero;
  
  for (final byte in bytes) {
    result = (result << 8) | BigInt.from(byte);
  }
  
  return result;
}

/// Encode length as variable-length integer
Uint8List encodeLength(int length) {
  if (length < 128) {
    return Uint8List.fromList([length]);
  } else if (length < 16384) {
    return Uint8List.fromList([
      0x80 | (length >> 8),
      length & 0xFF,
    ]);
  } else {
    return Uint8List.fromList([
      0xC0 | (length >> 24),
      (length >> 16) & 0xFF,
      (length >> 8) & 0xFF,
      length & 0xFF,
    ]);
  }
}
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:typed_data';
import 'dart:convert';

/// Custom order type for DEX
class DexOrder {
  final String tokenIn;
  final String tokenOut;
  final BigInt amountIn;
  final BigInt minAmountOut;
  final int slippagePercent;
  final DateTime deadline;
  
  DexOrder({
    required this.tokenIn,
    required this.tokenOut,
    required this.amountIn,
    required this.minAmountOut,
    required this.slippagePercent,
    required this.deadline,
  });
}

class DexOrderSerializer {
  // Define the type once
  static final dexOrderType = StructBuilder('DexOrder')
      .field('token_in', TokenIdentifierType.type)
      .field('token_out', TokenIdentifierType.type)
      .field('amount_in', BigUIntType.type)
      .field('min_amount_out', BigUIntType.type)
      .field('slippage', U8Type.type)
      .field('deadline', U64Type.type)
      .build();
  
  static StructValue toAbi(DexOrder order) {
    return dexOrderType.createValue({
      'token_in': order.tokenIn,
      'token_out': order.tokenOut,
      'amount_in': order.amountIn,
      'min_amount_out': order.minAmountOut,
      'slippage': BigInt.from(order.slippagePercent),
      'deadline': BigInt.from(order.deadline.millisecondsSinceEpoch ~/ 1000),
    });
  }
  
  static DexOrder fromAbi(StructValue struct) {
    return DexOrder(
      tokenIn: struct.getFieldValue('token_in')?.nativeValue as String,
      tokenOut: struct.getFieldValue('token_out')?.nativeValue as String,
      amountIn: struct.getFieldValue('amount_in')?.nativeValue as BigInt,
      minAmountOut: struct.getFieldValue('min_amount_out')?.nativeValue as BigInt,
      slippagePercent: (struct.getFieldValue('slippage')?.nativeValue as BigInt).toInt(),
      deadline: DateTime.fromMillisecondsSinceEpoch(
        (struct.getFieldValue('deadline')?.nativeValue as BigInt).toInt() * 1000,
      ),
    );
  }
}

// Usage
void main() {
  final order = DexOrder(
    tokenIn: 'WEGLD-bd4d79',
    tokenOut: 'USDC-c76f1f',
    amountIn: BigInt.parse('1000000000000000000'),
    minAmountOut: BigInt.from(950000000),
    slippagePercent: 5,
    deadline: DateTime.now().add(Duration(minutes: 30)),
  );
  
  // Convert to ABI type
  final abiOrder = DexOrderSerializer.toAbi(order);
  
  // Use in contract call
  final args = [abiOrder];
  
  // Convert back from ABI
  final decoded = DexOrderSerializer.fromAbi(abiOrder);
  print('Token In: ${decoded.tokenIn}');
}
```

## Next Steps

- [Error Handling](/docs/advanced/error-handling) - Handle errors properly
- [Best Practices](/docs/advanced/best-practices) - Production tips
- [ABI Types Overview](/docs/abi-types/overview) - Type system basics
