---
id: custom-serialization
title: Custom Serialization
sidebar_position: 1
description: Map your own Dart classes onto ABI types, register custom types with the type factory, and drive the binary codec directly.
---

# Custom Serialization

The type system is closed by design: the chain understands a fixed set of encodings, and every value
that goes on the wire must be one of them. "Custom serialization" therefore does not mean inventing
a new encoding -- it means **mapping your own Dart classes onto existing ABI types** and driving the
codec yourself when the controllers are not in the picture.

Three extension points cover everything:

| You want to | Use |
|-------------|-----|
| Describe a type the ABI file does not declare | `StructBuilder` / `EnumBuilder` / `ExplicitEnumType` |
| Have a type name resolve automatically while parsing an ABI | `AbiTypeFactory.registerCustomType` |
| Encode or decode bytes by hand | `BinaryCodec` (values) / `ArgSerializer` (argument lists) |

## The pieces

- **`AbiType`** describes a type (`StructType`, `ListType`, `U64Type`, ...). It is a *description*,
  not a value: it has no `nativeValue` and no `toBytes`.
- **`TypedValue`** is an instance of a type (`StructValue`, `ListValue`, `U64Value`, ...). It has
  `type`, `nativeValue` and `toBytes()`.
- **`BinaryCodec`** turns `TypedValue` into bytes and back, in top-level or nested form.

Subclassing `AbiType` yourself is not a supported extension point -- the codec dispatches on the
known type classes and will reject anything it does not recognise with `AbiBinaryCodecException`.
Model your domain type as a struct, an enum or a primitive instead, exactly as the contract does.

## Mapping a Dart class onto a struct

The pattern is a pair of pure functions: `toAbi` builds a `StructValue`, `fromAbi` reads one back.

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

class TokenInfo {
  TokenInfo({
    required this.identifier,
    required this.decimals,
    required this.supply,
    required this.paused,
  });

  final String identifier;
  final int decimals;
  final BigInt supply;
  final bool paused;
}

class TokenInfoSerializer {
  /// Define the type once - field order must match the contract's struct.
  static final StructType tokenInfoType = StructBuilder('TokenInfo')
      .field('identifier', StringType.type)
      .field('decimals', U8Type.type)
      .field('supply', BigUIntType.type)
      .field('paused', BooleanType.type)
      .build();

  static StructValue toAbi(TokenInfo info) {
    return tokenInfoType.createValue(<String, dynamic>{
      'identifier': info.identifier,
      'decimals': info.decimals,   // u8 takes int
      'supply': info.supply,       // BigUint takes BigInt
      'paused': info.paused,
    }) as StructValue;
  }

  static TokenInfo fromAbi(StructValue struct) {
    return TokenInfo(
      identifier: struct.getFieldValue('identifier').nativeValue as String,
      decimals: struct.getFieldValue('decimals').nativeValue as int,
      supply: struct.getFieldValue('supply').nativeValue as BigInt,
      paused: struct.getFieldValue('paused').nativeValue as bool,
    );
  }
}
```

Two rules make or break this mapping:

1. **Field order is the format.** Names are for your convenience; the wire carries fields in
   declaration order with no names and no separators.
2. **Use the native type each field expects** -- `int` for `u8`-`u32`, `BigInt` for `u64`/`BigUint`,
   `String` for `utf-8 string` and `Address` (bech32), `Map` for a nested struct.

## Mapping a Dart enum

```dart
enum OrderStatus { pending, filled, cancelled }

class OrderStatusSerializer {
  static final EnumType orderStatusType = EnumBuilder('OrderStatus')
      .variant('Pending', 0)
      .variant('Filled', 1)
      .variant('Cancelled', 2)
      .build();

  static EnumValue toAbi(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return orderStatusType.createValue('Pending') as EnumValue;
      case OrderStatus.filled:
        return orderStatusType.createValue('Filled') as EnumValue;
      case OrderStatus.cancelled:
        return orderStatusType.createValue('Cancelled') as EnumValue;
    }
  }

  static OrderStatus fromAbi(EnumValue value) {
    switch (value.variantName) {
      case 'Pending':
        return OrderStatus.pending;
      case 'Filled':
        return OrderStatus.filled;
      case 'Cancelled':
        return OrderStatus.cancelled;
      default:
        throw ArgumentError('Unknown variant: ${value.variantName}');
    }
  }
}
```

`variantName` is the safe thing to switch on: `nativeValue` is a `String` only for unit variants and
becomes a `Map` as soon as a variant carries fields.

If the contract's type is an `explicit-enum`, build an `ExplicitEnumType` instead -- it travels as
the variant name rather than a discriminant byte.

## Registering a custom type name

`AbiTypeFactory` resolves type names while an ABI is parsed. Register your own type before parsing
and every endpoint that mentions the name resolves to it:

```dart
final AbiTypeFactory factory = AbiTypeFactory();
factory.registerCustomType('TokenInfo', TokenInfoSerializer.tokenInfoType);

// The same factory is then used for the whole ABI.
final SmartContractAbi abi = SmartContractAbi.fromJson(
  abiJson,
  typeFactory: factory,
);
```

Passing your own factory is also how you keep two ABIs with same-named-but-different types from
sharing a registry.

`fromString` accepts full type formulas, so composites work too:

```dart
final AbiType listOfInfos = factory.fromString('List<TokenInfo>');
final AbiType maybeInfo = factory.fromString('Option<TokenInfo>');
```

## Driving the codec directly

`BinaryCodec.withDefaults()` is the whole encoder/decoder. Pick the position deliberately:

```dart
final BinaryCodec codec = BinaryCodec.withDefaults();

final StructValue info = TokenInfoSerializer.toAbi(
  TokenInfo(
    identifier: 'WEGLD-bd4d79',
    decimals: 18,
    supply: BigInt.from(1000),
    paused: false,
  ),
);

// Whole-buffer form: one transaction argument, one return-data part.
final Uint8List topLevel = codec.encodeTopLevel(info);

// Inside-a-buffer form: a field of another struct, an item of a list.
final Uint8List nested = codec.encodeNested(info);

// Decoding needs the type back
final StructValue decoded =
    codec.decodeTopLevel(topLevel, TokenInfoSerializer.tokenInfoType)
        as StructValue;
final TokenInfo roundTripped = TokenInfoSerializer.fromAbi(decoded);
```

For a struct the two encodings happen to be identical -- fields are always nested-encoded -- but for
integers, booleans, strings and options they differ, and using the wrong one produces bytes the
contract silently misreads. See [ABI Types Overview](/docs/abi-types/overview) for the full table.

## Argument lists

A contract call is not one buffer but a list of them. `ArgSerializer` handles that boundary,
including the variadic rules the single-value codec cannot express:

```dart
final ArgSerializer serializer = ArgSerializer();

// Values -> hex parts, ready to join with '@' into a data field.
final List<String> parts = serializer.valuesToStrings(<TypedValue>[
  U64Type.create(42),
  StringType.create('hello'),
]);
print(parts); // [2a, 68656c6c6f]

// Hex parts -> values, given the expected types.
final List<TypedValue> values = serializer.stringToValues(
  parts.join('@'),
  <ParameterDefinition>[
    ParameterDefinition(U64Type.type),
    ParameterDefinition(StringType.type),
  ],
);
```

`counted-variadic<T>` and `MultiValue<...>` exist **only** at this level: they span several
arguments and throw `AbiBinaryCodecException` if you try to encode them into a single buffer.

## Using a custom type in a call

Once a value is a `TypedValue`, every controller accepts it directly -- with or without an ABI:

```dart
// With an ABI: pass the struct as a native map or as the TypedValue
final tx = await controller.call(
  account: account,
  nonce: nonce,
  endpointName: 'registerToken',
  arguments: <dynamic>[TokenInfoSerializer.toAbi(info)],
  options: const BaseControllerInput(gasLimit: GasLimit(10000000)),
);

// Without an ABI: TypedValue arguments are mandatory
final rawTx = await rawController.callRaw(
  account: account,
  nonce: nonce,
  endpointName: 'registerToken',
  arguments: <dynamic>[TokenInfoSerializer.toAbi(info)],
  options: const BaseControllerInput(gasLimit: GasLimit(10000000)),
);
```

Decoding a result works the same way in reverse: take `result.typedValues.first as StructValue` and
hand it to your `fromAbi`.

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// A DEX order as this application models it.
class DexOrder {
  DexOrder({
    required this.tokenIn,
    required this.tokenOut,
    required this.amountIn,
    required this.minAmountOut,
    required this.slippagePercent,
    required this.deadline,
  });

  final String tokenIn;
  final String tokenOut;
  final BigInt amountIn;
  final BigInt minAmountOut;
  final int slippagePercent;
  final DateTime deadline;
}

class DexOrderSerializer {
  static final StructType dexOrderType = StructBuilder('DexOrder')
      .field('token_in', TokenIdentifierType.type)
      .field('token_out', TokenIdentifierType.type)
      .field('amount_in', BigUIntType.type)
      .field('min_amount_out', BigUIntType.type)
      .field('slippage', U8Type.type)
      .field('deadline', U64Type.type)
      .build();

  static StructValue toAbi(DexOrder order) {
    return dexOrderType.createValue(<String, dynamic>{
      'token_in': order.tokenIn,
      'token_out': order.tokenOut,
      'amount_in': order.amountIn,
      'min_amount_out': order.minAmountOut,
      'slippage': order.slippagePercent, // u8 takes int
      'deadline': BigInt.from(
        order.deadline.millisecondsSinceEpoch ~/ 1000,
      ), // u64 takes BigInt
    }) as StructValue;
  }

  static DexOrder fromAbi(StructValue struct) {
    return DexOrder(
      tokenIn: struct.getFieldValue('token_in').nativeValue as String,
      tokenOut: struct.getFieldValue('token_out').nativeValue as String,
      amountIn: struct.getFieldValue('amount_in').nativeValue as BigInt,
      minAmountOut:
          struct.getFieldValue('min_amount_out').nativeValue as BigInt,
      slippagePercent: struct.getFieldValue('slippage').nativeValue as int,
      deadline: DateTime.fromMillisecondsSinceEpoch(
        (struct.getFieldValue('deadline').nativeValue as BigInt).toInt() * 1000,
      ),
    );
  }
}

void main() {
  final order = DexOrder(
    tokenIn: 'WEGLD-bd4d79',
    tokenOut: 'USDC-c76f1f',
    amountIn: BigInt.parse('1000000000000000000'),
    minAmountOut: BigInt.from(950000000),
    slippagePercent: 5,
    deadline: DateTime.now().add(const Duration(minutes: 30)),
  );

  // Convert to an ABI value
  final StructValue abiOrder = DexOrderSerializer.toAbi(order);

  // Encode it exactly as a contract argument would be encoded
  final BinaryCodec codec = BinaryCodec.withDefaults();
  final Uint8List bytes = codec.encodeTopLevel(abiOrder);
  print('Encoded ${bytes.length} bytes');

  // ... and back
  final StructValue decodedValue =
      codec.decodeTopLevel(bytes, DexOrderSerializer.dexOrderType)
          as StructValue;
  final DexOrder decoded = DexOrderSerializer.fromAbi(decodedValue);
  print('Token In: ${decoded.tokenIn}');
}
```

## Next Steps

- [ABI Types Overview](/docs/abi-types/overview) - The encodings you are mapping onto
- [Error Handling](/docs/advanced/error-handling) - Handle errors properly
- [Best Practices](/docs/advanced/best-practices) - Production tips
