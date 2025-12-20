---
id: customization
title: Customization
sidebar_position: 4
description: Configure code generation with abidock.yaml for multi-contract projects, custom settings, and batch processing.
---

# Customization

Configure code generation to match your project's needs.

## Configuration File

Create an `abidock.yaml` in your project root for multi-contract generation:

```yaml
# abidock.yaml
version: 1

# Default settings applied to all contracts
defaults:
  generateFull: true        # Generate with all features (logger, autogas, transfers)
  validateBeforeGen: true   # Validate ABI before code generation

# Contracts to process
contracts:
  - name: Pair
    abi: assets/pair.abi.json
    output: lib/contracts/pair
    
  - name: Router
    abi: assets/router.abi.json
    output: lib/contracts/router
    
  - name: Farm
    abi: assets/farm.abi.json
    output: lib/contracts/farm
    # Override defaults for this contract
    overrides:
      generateFull: false

# Watch mode configuration (optional)
watch:
  debounceMs: 500        # Debounce time in milliseconds
  clearConsole: true     # Clear console on each regeneration
  verbose: false         # Show verbose output

# Validation configuration (optional)
validation:
  level: standard        # minimal, standard, or strict
  failOnWarnings: false  # Treat warnings as errors
  disabledRules: []      # Disable specific validation rules
```

:::note
The config-based CLI is a separate command interface from the direct `main.dart` mode. Config-based generation uses the CLI commands in `bin/codegen/cli/commands/`.
:::

## Feature Flags

The generator supports these feature flags:

| Flag | Description |
|------|-------------|
| `--logger` | Inject `ConsoleLogger` into controller |
| `--autogas` | Generate automatic gas estimation via `simulateGas` |
| `--transfers` | Generate transfer controller for EGLD/ESDT/NFT |
| `--full` | Enable all features |

### Logger Feature

When enabled, the controller accepts an optional logger:

```dart
class PairController {
  final ConsoleLogger logger;

  PairController({
    required dynamic contractAddress,
    required NetworkProvider networkProvider,
    ConsoleLogger? logger,  // Optional logger parameter
  }) : logger = logger ?? ConsoleLogger(
         minLevel: LogLevel.debug,
         includeTimestamp: true,
         prettyPrintContext: true,
         showBorders: true,
         useColors: true,
       ),
       // ...
```

### Auto-Gas Feature

When enabled, calls use automatic gas estimation via `simulateGas`:

```dart
// Create transaction with max gas for simulation
final simulationTx = await controller.call(
  account: sender,
  nonce: nonce,
  endpointName: 'addLiquidity',
  arguments: [firstTokenAmountMin, secondTokenAmountMin],
  options: BaseControllerInput(gasLimit: const GasLimit(600000000)),
);

// Estimate gas using simulation
final gasLimit = await simulateGas(simulationTx, controller.networkProvider);

// Create final transaction with estimated gas
return controller.call(
  account: sender,
  nonce: nonce,
  endpointName: 'addLiquidity',
  arguments: [firstTokenAmountMin, secondTokenAmountMin],
  options: BaseControllerInput(gasLimit: gasLimit),
);
```

### Transfers Feature

When enabled, a transfer controller is generated:

```dart
class TransferController {
  Future<Transaction> sendEgld(
    IAccount sender,
    Nonce nonce,
    Address recipient,
    Balance value,
  ) async { ... }

  Future<Transaction> sendEsdt(
    IAccount sender,
    Nonce nonce,
    Address recipient,
    String tokenId,
    BigInt amount,
  ) async { ... }

  Future<Transaction> sendNft(
    IAccount sender,
    Nonce nonce,
    Address recipient,
    String tokenId,
    BigInt nonce,
    BigInt quantity,
  ) async { ... }
}
```

## Generated File Structure

The generator creates a nested folder structure:

```
pair/
├── abi.dart                   # ABI constant
├── controller.dart            # Main PairController class  
├── pair.dart                  # Barrel export file
├── models/                    # Structs and enums (one per file)
│   ├── esdt_token_payment.dart
│   ├── state.dart
│   └── token_pair.dart
├── queries/                   # Query functions (one per file)
│   ├── get_reserve.dart
│   └── get_reserves_and_total_supply.dart
├── calls/                     # Call functions (one per file)
│   └── add_liquidity.dart
├── events/                    # Event streams
│   ├── polling_events/
│   └── websocket_events/
└── transfers/                 # Token transfers (with --transfers)
```

## Type Mappings

ABI types are automatically mapped to Dart types:

| ABI Type | Dart Type |
|----------|-----------|
| `BigUint`, `BigInt` | `BigInt` |
| `u8`, `u16`, `u32`, `u64` | `int` / `BigInt` |
| `Address` | `Address` |
| `TokenIdentifier` | `String` |
| `bool` | `bool` |
| `bytes` | `Uint8List` |
| `optional<T>` | `T?` |
| `variadic<T>` | `List<T>` |
| `multi<A,B,C>` | `(A, B, C)` (Dart 3 records) |

## Custom Types

### Structs

Generated structs include:
- Constructor with required fields
- Static `type` field for ABI type definition
- `fromAbi(TypedValue)` factory
- `toAbi()` method
- `toJson()` method

```dart
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

  factory EsdtTokenPayment.fromAbi(TypedValue value) { ... }
  TypedValue toAbi() { ... }
  Map<String, dynamic> toJson() { ... }
}
```

### Enums

Generated enums include:
- Static `type` field for ABI type definition
- `fromAbi(TypedValue)` factory
- `toAbi()` method

```dart
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

  factory State.fromAbi(TypedValue value) { ... }
  TypedValue toAbi() { ... }
}
```

## Environment Variables

Config files support environment variable substitution:

```yaml
# abidock.yaml
contracts:
  - name: MyContract
    abi: ${PROJECT_ROOT}/assets/contract.abi.json
    output: ${PROJECT_ROOT}/lib/contracts/my_contract
```

## Extending Generated Code

Extend generated classes with Dart extensions:

```dart
// lib/extensions/pair_extensions.dart
extension PairControllerExtensions on PairController {
  /// Get total liquidity value in first token terms
  Future<BigInt> getTotalLiquidityValue() async {
    final (res1, res2, total) = await getReservesAndTotalSupply();
    return res1 + res2;
  }
  
  /// Swap with slippage protection
  Future<Transaction> swapWithSlippage(
    IAccount sender,
    Nonce nonce,
    String tokenIn,
    BigInt amountIn,
    double maxSlippagePercent, {
    List<TokenTransferValue> tokenTransfers = const [],
  }) async {
    final expectedOut = await getAmountOut(tokenIn, amountIn);
    final minOut = (expectedOut * BigInt.from((100 - maxSlippagePercent).toInt())) ~/ BigInt.from(100);
    
    return swapTokensFixedInput(
      sender,
      nonce,
      tokenIn,
      amountIn,
      minOut,
      tokenTransfers: tokenTransfers,
    );
  }
}
```

## Next Steps

- [CLI Commands](/docs/codegen/cli-commands) - Command reference
- [Generated Code](/docs/codegen/generated-code) - Output structure
- [Smart Contracts](/docs/smart-contracts/overview) - Use generated code
