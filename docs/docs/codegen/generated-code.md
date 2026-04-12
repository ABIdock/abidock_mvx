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
├── models/                    # Structs and enums
│   ├── esdt_token_payment.dart
│   ├── state.dart
│   └── token_pair.dart
├── queries/                   # Query functions (one per file)
│   ├── get_reserve.dart
│   └── get_reserves_and_total_supply.dart
├── calls/                     # Call functions (one per file)
│   └── add_liquidity.dart
├── events/                    # Event streams (optional)
│   ├── polling_events/
│   └── websocket_events/
└── transfers/                 # Token transfer utilities (optional)
```

## Main Controller Class

The controller wraps `SmartContractController` and exposes type-safe methods:

```dart
// controller.dart
class PairController {
  final SmartContractController _controller;
  final ConsoleLogger logger;

  PairController({
    required dynamic contractAddress,
    required NetworkProvider networkProvider,
    ConsoleLogger? logger,
  }) : logger = logger ?? ConsoleLogger(
         minLevel: LogLevel.debug,
         includeTimestamp: true,
         prettyPrintContext: true,
         showBorders: true,
         useColors: true,
       ),
       _controller = SmartContractController(
         abi: abi,
         address: contractAddress is String
             ? SmartContractAddress.fromBech32(contractAddress)
             : contractAddress as Address,
         networkProvider: networkProvider,
         logger: logger ?? ConsoleLogger(...),
       );

  // Query methods delegate to generated query functions
  Future<BigInt> getReserve(String tokenId) =>
      get_reserve_query.getReserve(_controller, tokenId);

  // Call methods delegate to generated call functions
  Future<Transaction> addLiquidity(
    IAccount sender,
    Nonce nonce,
    BigInt firstTokenAmountMin,
    BigInt secondTokenAmountMin, {
    List<TokenTransferValue> tokenTransfers = const [],
    Balance? value,
  }) => add_liquidity_call.addLiquidity(
    _controller,
    sender,
    nonce,
    firstTokenAmountMin,
    secondTokenAmountMin,
    tokenTransfers: tokenTransfers,
    value: value,
  );
}
```

## Query Functions

Each query is generated as a separate file with `executeQuery` wrapper and `infer<T>` for type safety:

```dart
// queries/get_reserve.dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// Queries getReserve endpoint.
Future<BigInt> getReserve(
  SmartContractController controller,
  String tokenId,
) async {
  final tokenIdValue = TokenIdentifierType.type.createValue(tokenId);

  return executeQuery(
    endpointName: 'getReserve',
    action: () async {
      final result = await controller.query(
        endpointName: 'getReserve',
        arguments: [tokenIdValue],
      );

      return infer<BigInt>(result[0]);
    },
  );
}
```

### With Multiple Return Values

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
        infer<BigInt>(result[0]),
        infer<BigInt>(result[1]),
        infer<BigInt>(result[2]),
      );
    },
  );
}
```

### With Struct Return

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
        arguments: [liquidityValue],
      );

      return (
        infer<EsdtTokenPayment>(result[0]),
        infer<EsdtTokenPayment>(result[1]),
      );
    },
  );
}
```

## Call Functions

Each call is generated with `executeTransaction` wrapper and optional unsigned variant:

```dart
// calls/add_liquidity.dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// Calls addLiquidity endpoint.
Future<Transaction> addLiquidity(
  SmartContractController controller,
  IAccount sender,
  Nonce nonce,
  BigInt firstTokenAmountMin,
  BigInt secondTokenAmountMin, {
  List<TokenTransferValue> tokenTransfers = const <TokenTransferValue>[],
  Address? relayer,
  Address? guardian,
  Balance? value,
}) async {
  // Create transaction with max gas for simulation
  final simulationTx = await controller.call(
    account: sender,
    nonce: nonce,
    endpointName: 'addLiquidity',
    arguments: [firstTokenAmountMin, secondTokenAmountMin],
    tokenTransfers: tokenTransfers,
    value: value,
    options: BaseControllerInput(
      gasLimit: const GasLimit(600000000),
      relayer: relayer,
      guardian: guardian,
    ),
  );

  // Estimate gas using simulation
  final gasLimit = await simulateGas(simulationTx, controller.networkProvider);

  // Create final transaction with estimated gas
  return controller.call(
    account: sender,
    nonce: nonce,
    endpointName: 'addLiquidity',
    arguments: [firstTokenAmountMin, secondTokenAmountMin],
    tokenTransfers: tokenTransfers,
    value: value,
    options: BaseControllerInput(
      gasLimit: gasLimit,
      relayer: relayer,
      guardian: guardian,
    ),
  );
}

/// Builds an unsigned transaction for addLiquidity endpoint.
Transaction addLiquidityUnsigned(
  SmartContractCallFactory factory,
  Address sender,
  Nonce nonce,
  BigInt firstTokenAmountMin,
  BigInt secondTokenAmountMin, {
  List<TokenTransferValue> tokenTransfers = const <TokenTransferValue>[],
  required GasLimit gasLimit,
  Balance? value,
}) {
  return factory.createCall(
    sender: sender,
    nonce: nonce,
    endpointName: 'addLiquidity',
    arguments: [firstTokenAmountMin, secondTokenAmountMin],
    tokenTransfers: tokenTransfers,
    gasLimit: gasLimit,
    value: value,
  );
}
```

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

  final String tokenIdentifier;
  final BigInt tokenNonce;
  final BigInt amount;

  static final type = StructType(
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
      tokenIdentifier: infer<String>(
        struct.getFieldValue('token_identifier').nativeValue,
      ),
      tokenNonce: infer<BigInt>(
        struct.getFieldValue('token_nonce').nativeValue,
      ),
      amount: infer<BigInt>(struct.getFieldValue('amount').nativeValue),
    );
  }

  TypedValue toAbi() {
    return type.createValue({
      'token_identifier': tokenIdentifier,
      'token_nonce': tokenNonce,
      'amount': amount,
    });
  }

  Map<String, dynamic> toJson() {
    return {
      'token_identifier': tokenIdentifier,
      'token_nonce': tokenNonce,
      'amount': amount,
    };
  }
}
```

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

The generated code uses helper functions from `helpers.dart`:

```dart
// infer<T> - Forces compile-time type inference
T infer<T>(T value) => value;

// executeQuery - Wraps queries with standardized error handling
Future<T> executeQuery<T>({
  required String endpointName,
  required Future<T> Function() action,
}) async { ... }

// executeTransaction - Wraps transactions with standardized error handling
Future<T> executeTransaction<T>({
  required String endpointName,
  required Future<T> Function() action,
}) async { ... }
```

## Usage Example

```dart
import 'dart:io';
import 'package:abidock_mvx/abidock_mvx.dart';
import 'generated/pair/pair.dart';

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
  
  // Type-safe query
  final reserve = await pair.getReserve('WEGLD-bd4d79');
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
