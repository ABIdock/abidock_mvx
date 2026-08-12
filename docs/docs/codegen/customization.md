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

When enabled, the controller accepts an optional logger and falls back to a
fully configured `ConsoleLogger`. The field is typed as the abstract `Logger`,
so your own implementation passes straight through:

```dart
class PairController {
  final Logger logger;

  PairController({
    required dynamic contractAddress,
    required NetworkProvider networkProvider,
    Logger? logger,  // Optional logger parameter
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
// Build an unsigned probe transaction for simulation.
final factory = SmartContractCallFactory(
  contractAddress: controller.contractAddress,
  abi: controller.abi,
  chainId: controller.networkProvider.chainId,
);
final probeTx = factory.createCall(
  sender: sender.address,
  nonce: nonce,
  endpointName: 'addLiquidity',
  arguments: [firstTokenAmountMin, secondTokenAmountMin],
  gasLimit: const GasLimit(600000000),
);

// Estimate gas using simulation.
final gasLimit = await simulateGas(probeTx, controller.networkProvider);

// Sign once with the final gas limit so the signature matches.
return controller.call(
  account: sender,
  nonce: nonce,
  endpointName: 'addLiquidity',
  arguments: [firstTokenAmountMin, secondTokenAmountMin],
  options: BaseControllerInput(gasLimit: gasLimit),
);
```

### Transfers Feature

When enabled, a stateless `TransferService` is generated in
`transfer_service.dart`, backed by one file per transfer kind under
`transfers/`. It is contract-independent: it takes a `NetworkProvider` and
moves tokens directly.

```dart
class TransferService {
  const TransferService(this._provider);

  Future<Transaction> egld(
    IAccount sender,
    Nonce nonce,
    Address receiver,
    Balance amount, {
    Address? relayer,
    Address? guardian,
    Uint8List? data,
    GasLimit? gasLimit,
  });

  Future<Transaction> esdt(
    IAccount sender,
    Nonce nonce,
    Address receiver,
    String tokenId,
    BigInt amount, {
    Address? relayer,
    Address? guardian,
    GasLimit? gasLimit,
  });

  Future<Transaction> nft(
    IAccount sender,
    Nonce nonce,
    Address receiver,
    String tokenId,
    int tokenNonce,
    BigInt amount, {
    Address? relayer,
    Address? guardian,
    GasLimit? gasLimit,
  });

  Future<Transaction> multi(
    IAccount sender,
    Nonce nonce,
    Address receiver,
    List<TokenTransfer> transfers, {
    Address? relayer,
    Address? guardian,
    GasLimit? gasLimit,
  });

  // Raw factory exposed for custom batching
  TransferTransactionsFactory get transferFactory;
}
```

Usage:

```dart
final transfers = TransferService(provider);

final tx = await transfers.egld(
  account,
  networkAccount.nonce,
  Address.fromBech32('erd1...'),
  Balance.fromEgld(0.5),
);
```

## Generated File Structure

The generator creates a nested folder structure:

```
pair/
├── abi.dart                   # ABI constant
├── controller.dart            # Main PairController class
├── pair.dart                  # Barrel export file
├── transfer_service.dart      # TransferService (with --transfers)
├── models/                    # Structs, enums, event models (one per file)
│   ├── esdt_token_payment.dart
│   ├── state.dart
│   └── token_pair.dart
├── queries/                   # Query functions (one per view endpoint)
│   ├── get_reserve.dart
│   └── get_reserves_and_total_supply.dart
├── calls/                     # Call functions (one per mutable endpoint)
│   ├── add_liquidity.dart
│   └── deploy.dart            # when the ABI declares a constructor
├── events/                    # Event streams (when the ABI declares events)
│   ├── multi_event_polling_stream.dart
│   ├── multi_event_websocket_stream.dart
│   ├── polling_events/
│   └── websocket_events/
└── transfers/                 # egld / esdt / nft / multi (with --transfers)
```

## Type Mappings

ABI types are automatically mapped to Dart types:

| ABI Type | Dart Type |
|----------|-----------|
| `u8`, `u16`, `u32` | `int` |
| `i8`, `i16`, `i32` | `int` |
| `u64`, `BigUint` | `BigInt` |
| `i64`, `BigInt` | `BigInt` |
| `ManagedDecimal` | `BigInt` |
| `BigFloat` | `double` |
| `bool` | `bool` |
| `bytes`, `H256`, `ManagedByteArray<N>` | `Uint8List` |
| `utf-8 string` | `String` |
| `Address` | `Address` |
| `TokenIdentifier`, `EsdtTokenIdentifier` | `TokenIdentifier` |
| `EgldOrEsdtTokenIdentifier` | `EgldOrEsdtTokenIdentifier` |
| `EsdtTokenPayment` (transfer type) | `TokenTransferValue` |
| `CodeMetadata` | `List<int>` |
| `Option<T>`, `optional<T>` | `T?` |
| `List<T>`, `array<N,T>` | `List<T>` |
| `variadic<T>` | `List<T>` |
| `tuple<A,B>`, `multi<A,B,C>` | `(A, B)` / `(A, B, C)` (Dart 3 records) |
| struct / enum | Generated class or Dart `enum` of the same name |

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

  final TokenIdentifier tokenIdentifier;
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
    TokenIdentifier tokenIn,
    TokenIdentifier tokenOut,
    BigInt amountIn,
    int maxSlippageBps, {
    List<TokenTransferValue> tokenTransfers = const <TokenTransferValue>[],
  }) async {
    final expectedOut = await getAmountOut(tokenIn, amountIn);
    final minOut =
        (expectedOut * BigInt.from(10000 - maxSlippageBps)) ~/
            BigInt.from(10000);

    return swapTokensFixedInput(
      sender,
      nonce,
      tokenOut,
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
