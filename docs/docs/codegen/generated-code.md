---
id: generated-code
title: Generated Code
sidebar_position: 3
description: Understand the structure of generated Dart code including controllers, models, queries, and events.
---

# Generated Code Structure

Understanding the code generated from your ABI files.

## File Structure

For a contract named `pair`, the generator creates a nested folder structure:

```
pair/
├── abi.dart                   # ABI constant
├── controller.dart            # Main PairController class
├── pair.dart                  # Barrel export file
├── transfer_service.dart      # TransferService (with --transfers)
├── models/                    # Structs, enums, and event models
│   ├── esdt_token_payment.dart
│   ├── state.dart
│   ├── swap_event.dart
│   └── swap_event_data.dart
├── queries/                   # Query functions (one per view endpoint)
│   ├── get_reserve.dart
│   └── get_reserves_and_total_supply.dart
├── calls/                     # Call functions (one per mutable endpoint)
│   ├── add_liquidity.dart
│   ├── deploy.dart            # when the ABI declares a constructor
│   └── upgrade.dart           # when the ABI declares an upgrade constructor
├── events/                    # Event streams (when the ABI declares events)
│   ├── multi_event_polling_stream.dart
│   ├── multi_event_websocket_stream.dart
│   ├── polling_events/
│   └── websocket_events/
└── transfers/                 # egld / esdt / nft / multi (with --transfers)
```

## Main Controller Class

The controller wraps `SmartContractController` and exposes type-safe methods:

```dart
// controller.dart
class PairController {
  final SmartContractController _controller;
  final Logger logger;

  PairController({
    required dynamic contractAddress,
    required NetworkProvider networkProvider,
    Logger? logger,
  }) : logger = logger ?? ConsoleLogger(
         minLevel: LogLevel.debug,
         includeTimestamp: true,
         prettyPrintContext: true,
         showBorders: true,
         useColors: true,
       ),
       _controller = SmartContractController(
         abi: abi,
         contractAddress: contractAddress is String
             ? SmartContractAddress.fromBech32(contractAddress)
             : contractAddress as Address,
         networkProvider: networkProvider,
         logger: logger ?? ConsoleLogger(/* same defaults */),
       );

  // Wrap a controller you already built (custom estimator, shared provider)
  PairController.withController(this._controller)
    : logger = _controller.logger ?? ConsoleLogger(minLevel: LogLevel.debug);

  SmartContractController get controller => _controller;

  NetworkProvider get networkProvider => _controller.networkProvider;

  // Ready-made factory for unsigned transactions
  SmartContractCallFactory get factory => SmartContractCallFactory(
    contractAddress: _controller.contractAddress,
    abi: _controller.abi,
    chainId: _controller.networkProvider.chainId,
    logger: _controller.logger,
  );

  // Query methods delegate to generated query functions
  Future<BigInt> getReserve(TokenIdentifier tokenId) =>
      get_reserve_query.getReserve(_controller, tokenId);

  // Call methods delegate to generated call functions
  Future<Transaction> addLiquidity(
    IAccount sender,
    Nonce nonce,
    BigInt firstTokenAmountMin,
    BigInt secondTokenAmountMin, {
    List<TokenTransferValue> tokenTransfers = const <TokenTransferValue>[],
    Address? relayer,
    Address? guardian,
    Balance? value,
  }) => add_liquidity_call.addLiquidity(
    _controller,
    sender,
    nonce,
    firstTokenAmountMin,
    secondTokenAmountMin,
    tokenTransfers: tokenTransfers,
    relayer: relayer,
    guardian: guardian,
    value: value,
  );
}
```

`logger` is typed as the abstract `Logger`, so any implementation you pass in
flows through to `SmartContractController` unchanged. `ConsoleLogger` is only
the default when `--logger` was used and you supply nothing.

## Query Functions

Each query is generated as a separate file, wrapped in `executeQuery` for
uniform error reporting. Results are decoded off `result.typedValues`, which
keeps the ABI type information all the way to the cast:

```dart
// queries/get_reserve.dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// Queries getReserve endpoint.
Future<BigInt> getReserve(
  SmartContractController controller,
  TokenIdentifier tokenId,
) async {
  final tokenIdValue = TokenIdentifierType.type.createValue(tokenId.value);

  return executeQuery(
    endpointName: 'getReserve',
    action: () async {
      final result = await controller.query(
        endpointName: 'getReserve',
        arguments: [
          tokenIdValue,
        ],
      );

      return result.typedValues[0].nativeValue as BigInt;
    },
  );
}
```

### With Multiple Return Values

Multi-value endpoints return a Dart record, one positional field per output:

```dart
// queries/get_reserves_and_total_supply.dart
Future<(BigInt, BigInt, BigInt)> getReservesAndTotalSupply(
  SmartContractController controller,
) async {
  return executeQuery(
    endpointName: 'getReservesAndTotalSupply',
    action: () async {
      final result = await controller.query(
        endpointName: 'getReservesAndTotalSupply',
      );

      return (
        result.typedValues[0].nativeValue as BigInt,
        result.typedValues[1].nativeValue as BigInt,
        result.typedValues[2].nativeValue as BigInt
      );
    },
  );
}
```

### With Struct Return

Custom types are rebuilt through the generated `fromAbi` factory:

```dart
// queries/get_tokens_for_given_position.dart
import '../models/esdt_token_payment.dart';

Future<(EsdtTokenPayment, EsdtTokenPayment)> getTokensForGivenPosition(
  SmartContractController controller,
  BigInt liquidity,
) async {
  final liquidityValue = BigUIntType.type.createValue(liquidity);

  return executeQuery(
    endpointName: 'getTokensForGivenPosition',
    action: () async {
      final result = await controller.query(
        endpointName: 'getTokensForGivenPosition',
        arguments: [
          liquidityValue,
        ],
      );

      return (
        EsdtTokenPayment.fromAbi(result.typedValues[0]),
        EsdtTokenPayment.fromAbi(result.typedValues[1])
      );
    },
  );
}
```

Endpoints with more than one output also get a guard that fails loudly when the
contract returns fewer values than the ABI promised, instead of throwing a
range error deep inside the decode.

## Call Functions

Each mutable endpoint gets a signing function plus an unsigned variant. The
`tokenTransfers` parameter appears only for payable endpoints; `relayer` and
`guardian` are always available.

With `--autogas`, the call builds an unsigned probe, simulates it, and then
signs **once** with the resulting gas limit:

```dart
// calls/add_liquidity.dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// Calls addLiquidity endpoint.
Future<Transaction> addLiquidity(
  SmartContractController controller,
  IAccount sender,
  Nonce nonce,
  BigInt firstTokenAmountMin,
  BigInt secondTokenAmountMin,
  {
    List<TokenTransferValue> tokenTransfers = const <TokenTransferValue>[],
    Address? relayer,
    Address? guardian,
    Balance? value,
  }
) async {
  final factory = SmartContractCallFactory(
    contractAddress: controller.contractAddress,
    abi: controller.abi,
    chainId: controller.networkProvider.chainId,
  );
  final probeTx = factory.createCall(
    sender: sender.address,
    nonce: nonce,
    endpointName: 'addLiquidity',
    arguments: <dynamic>[firstTokenAmountMin, secondTokenAmountMin],
    tokenTransfers: tokenTransfers,
    gasLimit: const GasLimit(600000000),
    value: value,
  );
  final gasLimit = await simulateGas(probeTx, controller.networkProvider);

  return controller.call(
    account: sender,
    nonce: nonce,
    endpointName: 'addLiquidity',
    arguments: <dynamic>[firstTokenAmountMin, secondTokenAmountMin],
    tokenTransfers: tokenTransfers,
    value: value,
    options: BaseControllerInput(
      gasLimit: gasLimit,
      relayer: relayer,
      guardian: guardian,
    ),
  );
}
```

The probe is deliberately unsigned: mutating `gasLimit` on a signed
transaction would invalidate the signature, so the signature is only produced
after the final gas limit is known.

Without `--autogas` the probe and the simulation disappear, and `gasLimit`
becomes a required named parameter:

```dart
Future<Transaction> addLiquidity(
  SmartContractController controller,
  IAccount sender,
  Nonce nonce,
  BigInt firstTokenAmountMin,
  BigInt secondTokenAmountMin,
  {
    List<TokenTransferValue> tokenTransfers = const <TokenTransferValue>[],
    required GasLimit gasLimit,
    Address? relayer,
    Address? guardian,
    Balance? value,
  }
) async {
  return controller.call(/* ... */);
}
```

### Unsigned Variant

Every call file also emits a `<name>Unsigned` function for batch signing. With
`--autogas` it takes the network provider, estimates gas, and returns a
`Future<Transaction>`:

```dart
/// Builds an unsigned transaction for addLiquidity endpoint.
Future<Transaction> addLiquidityUnsigned(
  SmartContractCallFactory factory,
  NetworkProvider networkProvider,
  Address sender,
  Nonce nonce,
  BigInt firstTokenAmountMin,
  BigInt secondTokenAmountMin,
  {
    List<TokenTransferValue> tokenTransfers = const <TokenTransferValue>[],
    Balance? value,
  }
) async {
  final tx = factory.createCall(
    sender: sender,
    nonce: nonce,
    endpointName: 'addLiquidity',
    arguments: <dynamic>[firstTokenAmountMin, secondTokenAmountMin],
    tokenTransfers: tokenTransfers,
    gasLimit: const GasLimit(600000000),
    value: value,
  );

  final gasLimit = await simulateGas(tx, networkProvider);

  return tx.copyWith(newGasLimit: gasLimit);
}
```

Without `--autogas` it is synchronous, drops the provider parameter, and takes
the gas limit from the caller. Either way the returned transaction carries no
signature, so several of them can be signed in one batch:

```dart
final sigs = await account.signTransactions([tx1, tx2]);
final signed1 = tx1.copyWith(newSignature: Signature.fromUint8List(sigs[0]));
final signed2 = tx2.copyWith(newSignature: Signature.fromUint8List(sigs[1]));
await provider.sendTransactions([signed1, signed2]);
```

### Deploy and Upgrade

When the ABI declares a constructor, `calls/deploy.dart` is generated with the
same shape; an upgrade constructor produces `calls/upgrade.dart`.

## Generated Types

### Structs

```dart
// models/esdt_token_payment.dart
import 'package:abidock_mvx/abidock_mvx.dart';

class EsdtTokenPayment {
  const EsdtTokenPayment({
    required this.tokenIdentifier,
    required this.tokenNonce,
    required this.amount,
  });

  final TokenIdentifier tokenIdentifier;
  final BigInt tokenNonce;
  final BigInt amount;

  static final StructType type = StructType(
    name: 'EsdtTokenPayment',
    fieldDefinitions: [
      FieldDefinition(name: 'token_identifier', type: TokenIdentifierType.type),
      FieldDefinition(name: 'token_nonce', type: U64Type.type),
      FieldDefinition(name: 'amount', type: BigUIntType.type),
    ],
  );

  factory EsdtTokenPayment.fromAbi(TypedValue value) {
    final struct = value as StructValue;
    return EsdtTokenPayment(
      tokenIdentifier: TokenIdentifier(
        struct.getFieldValue('token_identifier').nativeValue as String,
      ),
      tokenNonce: struct.getFieldValue('token_nonce').nativeValue as BigInt,
      amount: struct.getFieldValue('amount').nativeValue as BigInt,
    );
  }

  TypedValue toAbi() {
    return type.createValue({
      'token_identifier': tokenIdentifier.value,
      'token_nonce': tokenNonce,
      'amount': amount,
    });
  }

  Map<String, dynamic> toJson() {
    return {
      'token_identifier': tokenIdentifier.value,
      'token_nonce': tokenNonce.toString(),
      'amount': amount.toString(),
    };
  }
}
```

`toAbi()` unwraps wrapper types such as `TokenIdentifier` back to their
primitive form, and `toJson()` renders `BigInt` fields as strings so the map
survives `jsonEncode` untouched.

### Enums

```dart
// models/state.dart
import 'package:abidock_mvx/abidock_mvx.dart';

enum State {
  inactive,
  active,
  partialActive;

  static final type = EnumType(
    name: 'State',
    variants: [
      const EnumVariantDefinition(name: 'Inactive', discriminant: 0),
      const EnumVariantDefinition(name: 'Active', discriminant: 1),
      const EnumVariantDefinition(name: 'PartialActive', discriminant: 2),
    ],
  );

  factory State.fromAbi(TypedValue value) {
    final nativeValue = value.nativeValue;

    // Handle int discriminant (supports non-sequential discriminants)
    if (nativeValue is int) {
      final discriminants = <int>[0, 1, 2];
      final idx = discriminants.indexOf(nativeValue);
      if (idx < 0) throw ArgumentError('Unknown State discriminant: $nativeValue');
      return State.values[idx];
    }

    // Handle String variant name (from event parsing)
    if (nativeValue is String) {
      return State.values.firstWhere(
        (v) => v.name.toLowerCase() == nativeValue.toLowerCase(),
        orElse: () =>
            throw ArgumentError('Unknown State variant: $nativeValue'),
      );
    }

    throw ArgumentError('Invalid State value: $nativeValue');
  }

  TypedValue toAbi() {
    return type.createValue(index);
  }
}
```

### Explicit Enums

Explicit enums are simpler enums without associated data fields:

```dart
// models/payment_status.dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// PaymentStatus explicit enum.
enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  refunded;

  static final type = ExplicitEnumType(
    name: 'PaymentStatus',
    variants: [
      const ExplicitEnumVariantDefinition(name: 'Pending', discriminant: 0),
      const ExplicitEnumVariantDefinition(name: 'Processing', discriminant: 1),
      const ExplicitEnumVariantDefinition(name: 'Completed', discriminant: 2),
      const ExplicitEnumVariantDefinition(name: 'Failed', discriminant: 3),
      const ExplicitEnumVariantDefinition(name: 'Refunded', discriminant: 4),
    ],
  );

  factory PaymentStatus.fromAbi(TypedValue value) {
    final nativeValue = value.nativeValue;

    // Handle int discriminant (supports non-sequential discriminants)
    if (nativeValue is int) {
      final discriminants = <int>[0, 1, 2, 3, 4];
      final idx = discriminants.indexOf(nativeValue);
      if (idx < 0) throw ArgumentError('Unknown PaymentStatus discriminant: $nativeValue');
      return PaymentStatus.values[idx];
    }

    // Handle String variant name
    if (nativeValue is String) {
      return PaymentStatus.values.firstWhere(
        (v) => v.name.toLowerCase() == nativeValue.toLowerCase(),
        orElse: () =>
            throw ArgumentError('Unknown PaymentStatus variant: $nativeValue'),
      );
    }

    throw ArgumentError('Invalid PaymentStatus value: $nativeValue');
  }

  TypedValue toAbi() {
    return type.createValue(index);
  }
}
```

## Helper Functions

Generated code leans on two public helpers that ship with the SDK:

| Helper | Used by | Purpose |
|--------|---------|---------|
| `executeQuery<T>` | every generated query | Wraps the call so ABI and network failures surface with the endpoint name attached |
| `simulateGas` | calls generated with `--autogas` | Simulates an unsigned transaction and returns the estimated `GasLimit` |

```dart
Future<T> executeQuery<T>({
  required String endpointName,
  required Future<T> Function() action,
});

Future<GasLimit> simulateGas(
  Transaction transaction,
  NetworkProvider networkProvider,
);
```

`executeTransaction<T>` exists with the same shape as `executeQuery<T>` and is
available for your own code; generated calls do not wrap themselves in it,
because the controller already reports failures with full context.

## Usage Example

```dart
import 'dart:io';
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:my_app/generated/pair/pair.dart';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final pemContent = await File('wallet.pem').readAsString();
  final account = await Account.fromPem(pemContent);
  final accountOnNetwork = await provider.getAccount(account.address);
  
  // Create controller with contract address
  final pair = PairController(
    contractAddress: 'erd1qqqqqqqqqqqqqpgq...',
    networkProvider: provider,
  );
  
  // Type-safe query - the ABI's TokenIdentifier maps to a TokenIdentifier
  final reserve = await pair.getReserve(TokenIdentifier('WEGLD-bd4d79'));
  print('Reserve: $reserve');
  
  // Type-safe query with multiple returns
  final (reserve1, reserve2, totalSupply) = await pair.getReservesAndTotalSupply();
  print('Reserves: $reserve1, $reserve2, Total: $totalSupply');
  
  // Type-safe transaction
  final tx = await pair.addLiquidity(
    account,
    accountOnNetwork.nonce,
    BigInt.from(1000000),  // firstTokenAmountMin
    BigInt.from(1000000),  // secondTokenAmountMin
    tokenTransfers: [
      TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'WEGLD-bd4d79', 
        amount: BigInt.parse('1000000000000000000'),
      ),
    ],
  );
  
  final hash = await provider.sendTransaction(tx);
  print('Transaction: $hash');
}
```

## Next Steps

- [CLI Commands](/docs/codegen/cli-commands) - Full command reference
- [Customization](/docs/codegen/customization) - Configure generation
- [Smart Contracts](/docs/smart-contracts/overview) - Contract interactions
