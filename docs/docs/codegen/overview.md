---
id: overview
title: Code Generation Overview
sidebar_position: 1
description: Generate type-safe Dart code from MultiversX ABI files with compile-time checks and IDE autocomplete.
---

# Code Generation

abidock_mvx includes a CLI to generate type-safe Dart code from ABI files.

## Why Generate Code?

| Manual Approach | Generated Code |
|-----------------|----------------|
| Type casting required | Type-safe methods |
| Error-prone string literals | Compile-time checks |
| Runtime errors | IDE autocomplete |
| Repetitive boilerplate | Clean, minimal code |

### Before (Manual)

```dart
// Manual: error-prone, requires type knowledge
final tokenIdValue = TokenIdentifierType.type.createValue(tokenId);
final result = await controller.query(
  endpointName: 'getReserve',
  arguments: [tokenIdValue],
);
final reserve = infer<BigInt>(result[0]);
```

### After (Generated)

```dart
// Generated: type-safe, IDE-supported
final reserve = await pair.getReserve(tokenId);
```

## Quick Start

First, install the CLI globally:

```bash
dart pub global activate abidock_mvx
```

Then generate code from your ABI:

```bash
# Generate from ABI (positional arguments)
abidock assets/pair.abi.json lib/generated/pair Pair

# With all features enabled
abidock assets/pair.abi.json lib/generated/pair Pair --full

# Interactive mode
abidock --interactive
```

## Generated Structure

For an ABI file, the generator creates a modular directory structure:

```
lib/generated/pair/
├── pair.dart              # Barrel export (import this)
├── abi.dart               # ABI constant
├── controller.dart        # Main controller class
├── models/                # Custom types (structs, enums)
│   ├── state.dart
│   └── esdt_token_payment.dart
├── queries/               # View endpoints (one file per endpoint)
│   ├── get_reserve.dart
│   └── get_reserves_and_total_supply.dart
├── calls/                 # Mutable endpoints (one file per endpoint)
│   ├── add_liquidity.dart
│   └── swap_tokens_fixed_input.dart
├── events/                # Event streaming
│   ├── polling_events/
│   └── websocket_events/
└── transfers/             # Transfer helpers (with --transfers flag)
```

## Example Usage

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'generated/pair/pair.dart';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('...');
  final accountInfo = await provider.getAccount(account.address);
  
  // Create controller with contract address
  final pair = PairController(
    contractAddress: 'erd1qqq...pairaddress...',
    networkProvider: provider,
  );
  
  // Type-safe queries - returns native Dart types
  final reserve = await pair.getReserve('WEGLD-abcdef');
  print('Reserve: $reserve');
  
  // Multiple return values use Dart records
  final (reserveA, reserveB, totalSupply) = await pair.getReservesAndTotalSupply();
  print('Reserves: $reserveA / $reserveB, Total: $totalSupply');
  
  // Type-safe transaction builders
  final tx = await pair.addLiquidity(
    account,
    accountInfo.nonce,
    BigInt.from(1000),  // firstTokenAmountMin
    BigInt.from(1000),  // secondTokenAmountMin
    tokenTransfers: [
      TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'WEGLD-abcdef',
        amount: BigInt.from(1000000),
      ),
      TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'USDC-123456',
        amount: BigInt.from(1000000),
      ),
    ],
  );
  
  final hash = await provider.sendTransaction(tx);
  print('Transaction: $hash');
}
```

## CLI Flags

| Flag | Description |
|------|-------------|
| `--logger` | Include ConsoleLogger in generated controller |
| `--autogas` | Generate automatic gas estimation via `simulateGas` |
| `--transfers` | Generate transfer service for EGLD/ESDT/NFT |
| `--full` | Enable ALL features (logger + autogas + transfers) |

## Features

- All ABI types supported (primitives, structs, enums, options, lists)
- Custom struct and enum generation with Dart classes
- Query methods with proper return types
- Transaction builders with auto gas estimation
- ESDT/NFT token payment support
- Multi-value returns using Dart records `(BigInt, BigInt)`
- Optional/variadic argument handling
- Event streaming (polling and WebSocket)
- Unsigned transaction builders for batch signing
- Relayer and guardian support built-in

## Next Steps

- [CLI Commands](/docs/codegen/cli-commands) - Full command reference
- [Generated Code](/docs/codegen/generated-code) - Understand the output
- [Customization](/docs/codegen/customization) - Configure generation

