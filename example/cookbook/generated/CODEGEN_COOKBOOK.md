---
id: codegen-cookbook
title: Code Generation Cookbook
---

[comment]: # (mx-abstract)

Implementation guide for using the abidock CLI to generate type-safe Dart controllers from MultiversX ABI files. Learn how to configure the generator, interpret the output, and integrate generated code into your applications.

[comment]: # (mx-context-auto)

## Overview

The `abidock` CLI turns MultiversX ABIs into type-safe Dart packages. This guide explains how to configure the generator, interpret the output, and integrate the generated controllers into your applications and pipelines.

### Why generate code?

| Benefit | Description |
| ------- | ----------- |
| Type safety | Queries, calls, events, and models expose real Dart types—mistakes are caught at compile time |
| IDE support | Inline docs, auto-complete, and discoverable APIs per contract |
| Consistency | Everyone on the team works with the same controller surface |
| Regeneration | When an ABI changes, re-run the generator and review the diff |

### What you get from a single ABI

- Controller with query/call methods and logger hooks
- Generated files for every endpoint and event
- Model classes for structs/enums with serialization helpers
- Transfer service and event streams (polling + WebSocket) when enabled

[comment]: # (mx-context-auto)

## Running the Generator

### Direct invocation

```bash
abidock assets/pair.abi.json lib/generated/pair Pair --full
```

| Argument | Description |
| -------- | ----------- |
| `<abi>` | Path to the ABI JSON file |
| `<output>` | Destination folder for generated code |
| `<name>` | PascalCase prefix for classes (e.g., `PairController`) |

| Flag | Description |
| ---- | ----------- |
| `--logger` | Inject `ConsoleLogger` plumbing |
| `--autogas` | Enable automatic gas estimation via simulation |
| `--transfers` | Add transfer helpers |
| `--full` | Enable all of the above |

:::important
When `--autogas` is enabled, generated call methods automatically simulate the transaction to estimate gas. You don't need to provide a `gasLimit` parameter.
:::

:::important
Relayer and guardian parameters are always available in generated code.
:::

### Config-driven workflow

```bash
abidock init                    # [1]
# edit abidock.yaml
abidock validate --fail-on-warnings  # [2]
abidock generate                # [3]
abidock watch                   # [4]
```

Where:
- **[1]** Create `abidock.yaml` configuration file
- **[2]** Validate ABIs before generation
- **[3]** Generate controllers for all configured contracts
- **[4]** Watch for ABI changes and regenerate

### Example configuration

```yaml title="abidock.yaml"
name: MyDapp
version: 1.2.0
contracts:
  - name: Pair
    abi: assets/pair.abi.json
    output: lib/generated/pair
    generation:
      full: true
  - name: Farm
    abi: assets/farm.abi.json
    output: lib/generated/farm
defaults:
  generation:
    validateBeforeGen: true
    logger: true
    transfers: true
watch:
  debounceMs: 500
  verbose: true
```

:::tip
Keep the config file in version control so everyone regenerates the same targets.
:::

[comment]: # (mx-context-auto)

## Generated Folder Structure

```
lib/generated/pair/
├─ pair.dart                 # Barrel export
├─ controller.dart           # High-level API
├─ abi.dart                  # Parsed ABI snapshot
├─ transfer_service.dart     # Optional helper
├─ calls/                    # One file per call endpoint
├─ queries/                  # One file per query endpoint
├─ models/                   # Structs and enums
└─ events/
   ├─ polling_events/        # HTTP polling streams
   └─ websocket_events/      # WebSocket streams
```

- `pair.dart` exports everything for convenient `import 'generated/pair/pair.dart';`
- `calls/` and `queries/` contain one file per endpoint to keep diffs small
- `events/` surfaces dedicated polling and WebSocket stream wrappers

[comment]: # (mx-context-auto)

## Working with Controllers

### Initialization

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'generated/pair/pair.dart';

final controller = PairController(
  contractAddress: 'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g', // [1]
  networkProvider: ApiNetworkProvider.devnet(),  // [2]
  logger: ConsoleLogger(minLevel: LogLevel.info), // [3]
);
```

Where:
- **[1]** Contract address (String or `SmartContractAddress`)
- **[2]** Any network provider
- **[3]** Optional logger for debugging

### Executing queries

```dart
final reserve = await controller.getReserve('WEGLD-a28c59');                      // [1]
final amountOut = await controller.getAmountOut('WEGLD-a28c59', BigInt.from(1e17)); // [2]
final state = await controller.getState();                                         // [3]
```

Where:
- **[1]** Get token reserve (returns `BigInt`)
- **[2]** Calculate swap output amount
- **[3]** Get contract state enum

Return types mirror the ABI definitions. No manual decoding required.

### Building transactions

```dart
final pem = File('example/assets/alice.pem').readAsStringSync();
final account = await Account.fromPem(pem);

// Get fresh nonce
final accountOnNetwork = await controller.networkProvider.getAccount(account.address);
final nonce = accountOnNetwork.nonce;

// Create payment
final payment = TokenTransferValue.fromPrimitives(
  tokenIdentifier: 'WEGLD-a28c59',
  amount: BigInt.from(1e17),
);

// Build transaction (type-safe!)
final tx = await controller.swapTokensFixedInput(  // [1]
  account,
  nonce,
  'MEX-a659d0',
  BigInt.from(1000000),
  tokenTransfers: [payment],
);

final hash = await controller.networkProvider.sendTransaction(tx);
```

Where:
- **[1]** Type-safe method call—IDE autocomplete shows all parameters

With `--autogas` enabled, gas is automatically estimated via network simulation. Override options when needed:

```dart
final tx = await controller.swapTokensFixedInput(
  account,
  nonce,
  'MEX-a659d0',
  BigInt.from(1000000),
  tokenTransfers: [payment],
  value: Balance.fromEgld('0.1'),   // [1]
  relayer: relayerAddress,          // [2]
  guardian: guardianAddress,        // [3]
);
```

Where:
- **[1]** Optional EGLD value to send
- **[2]** Optional relayer address for meta-transactions
- **[3]** Optional guardian address for guarded accounts

### Using generated models

Structs and enums are emitted with:
- Immutable fields and constructors
- `toJson`/`fromJson` helpers
- ABI conversion helpers for interop with manual code
- Enum discriminant lookups and friendly names

[comment]: # (mx-context-auto)

## Event Streams

### Polling events

```dart
final polling = controller.events.pollingStream(
  pollingInterval: const Duration(seconds: 2),
  fromTimestamp: DateTime.now().subtract(const Duration(hours: 1)),
);

polling.swap.listen((SwapEvent event) {     // [1]
  print('Swap volume in: ${event.amountIn}');
});

polling.all.listen((dynamic event) {        // [2]
  // Handle SwapEvent, AddLiquidityEvent, etc.
});
```

Where:
- **[1]** Type-safe event stream for specific event type
- **[2]** Combined stream for all events

Ideal for dashboards or historical analytics where short delay is acceptable.

### WebSocket events

```dart
final ws = controller.events.websocketStream(
  websocketUrl: 'wss://kepler-api.projectx.mx/devnet/events',
  headers: {'Api-Key': 'your-api-key'},
);

await ws.connect();

ws.swap.listen((SwapEvent event) => print(event.toJson()));
```

Use for low-latency trading bots or live monitoring. Remember to close the stream to free resources.

### Event stream comparison

| Feature | Polling | WebSocket |
| ------- | ------- | --------- |
| Latency | 6+ seconds | ~1 second |
| Resource usage | Lower | Higher |
| Connection | Stateless | Stateful |
| Historical events | Yes | No |
| Best for | Background jobs | Real-time UIs |

[comment]: # (mx-context-auto)

## Transfer Services

Generated when `--transfers` or `--full` is enabled:

```dart
final transferService = TransferService(controller.networkProvider);

// EGLD transfer
final tx1 = await transferService.egld(
  account,
  nonce,
  Address.fromBech32('erd1...'),
  Balance.fromEgld(0.5),
);

// ESDT transfer
final tx2 = await transferService.esdt(
  account,
  nonce,
  Address.fromBech32('erd1...'),
  'WEGLD-a28c59',
  BigInt.from(1e18),
);

// NFT transfer
final tx3 = await transferService.nft(
  account,
  nonce,
  Address.fromBech32('erd1...'),
  'COLLECTION-abcdef',
  42,          // Token nonce (int)
  BigInt.one,  // Amount
);

// Multi-transfer
final tx4 = await transferService.multi(
  account,
  nonce,
  Address.fromBech32('erd1...'),
  [
    TokenTransfer.fungible(tokenIdentifier: 'WEGLD-a28c59', amount: BigInt.from(1e6)),
    TokenTransfer.fungible(tokenIdentifier: 'MEX-a659d0', amount: BigInt.from(5e6)),
  ],
);
```

[comment]: # (mx-context-auto)

## Complete Example: Type-Safe DEX Swap

```dart title="example/cookbook/generated/generated_controller_swap.dart"
import 'dart:io';
import 'package:abidock_mvx/abidock_mvx.dart';
import 'pair/pair.dart';

Future<void> main() async {
  // Load account
  final pem = File('example/assets/alice.pem').readAsStringSync();
  final account = await Account.fromPem(pem);

  // Initialize network
  final provider = ApiNetworkProvider.devnet();
  final accountOnNetwork = await provider.getAccount(account.address);
  final nonce = accountOnNetwork.nonce;

  // Create type-safe controller
  final controller = PairController(
    contractAddress: 'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
    networkProvider: provider,
  );

  // Define swap parameters
  final wegldAmount = BigInt.from(1) * BigInt.from(10).pow(18);
  const wegldIdentifier = 'WEGLD-a28c59';
  const mexIdentifier = 'MEX-a659d0';

  // Query expected output (type-safe!)
  final amountOut = await controller.getAmountOut(wegldIdentifier, wegldAmount);

  // Calculate slippage tolerance (1%)
  final minAmountOut = (amountOut * BigInt.from(9900)) ~/ BigInt.from(10000);

  // Create payment
  final wegldTransfer = TokenTransferValue.fromPrimitives(
    tokenIdentifier: wegldIdentifier,
    amount: wegldAmount,
  );

  // Build transaction (type-safe!)
  final tx = await controller.swapTokensFixedInput(
    account,
    nonce,
    mexIdentifier,
    minAmountOut,
    tokenTransfers: [wegldTransfer],
  );

  // Send and wait
  final txHash = await provider.sendTransaction(tx);
  print('Swap transaction: $txHash');

  final watcher = TransactionWatcher(networkProvider: provider);
  final result = await watcher.awaitCompleted(txHash);

  if (result.status == TransactionStatus.success) {
    print('Swap successful!');
  } else {
    print('Swap failed: ${result.status}');
  }
}
```

### Improvements over manual approach

| Aspect | Manual | Generated |
| ------ | ------ | --------- |
| ABI handling | Load and parse JSON | Built-in |
| Method calls | String-based endpoint names | Type-safe methods |
| Arguments | Manual TypedValue construction | Native Dart types |
| Gas estimation | Manual calculation | Automatic (with `--autogas`) |
| Errors | Runtime | Compile-time |
| IDE support | Limited | Full autocomplete |

[comment]: # (mx-context-auto)

## CI/CD Integration

```yaml title=".github/workflows/build.yml"
name: build
on: [push, pull_request]
jobs:
  sdk:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable
      - run: dart pub global activate abidock_mvx
      - run: abidock validate --fail-on-warnings
      - run: abidock generate
      - run: dart analyze lib/generated
      - run: dart test
```

This keeps generated code fresh and validated on every push.

[comment]: # (mx-context-auto)

## Migration from Manual SDK

### Before (manual)

```dart
final result = await controller.query(
  endpointName: 'getAmountOut',
  arguments: [TokenIdentifierValue('WEGLD-a28c59'), amount],
);
final BigInt amountOut = result.first;

final tx = await controller.call(
  account: sender,
  nonce: nonce,
  endpointName: 'swapTokensFixedInput',
  arguments: [TokenIdentifierValue('MEX-a659d0'), BigUIntValue(minOut)],
  options: BaseControllerInput(
    gasLimit: GasLimit(50000000),
    tokenTransfers: [payment],
  ),
);
```

### After (generated)

```dart
final amountOut = await controller.getAmountOut('WEGLD-a28c59', amount);

final tx = await controller.swapTokensFixedInput(
  sender,
  nonce,
  'MEX-a659d0',
  minOut,
  tokenTransfers: [payment],
);
```

Call sites shrink dramatically and type mismatches become compile-time errors.

[comment]: # (mx-context-auto)

## Best Practices

:::tip
Regenerate whenever a contract changes and review the diff like any other code change.
:::

| Practice | Recommendation |
| -------- | -------------- |
| Version control | Decide whether generated directories live in VCS. If excluded, add generation steps to build pipeline |
| Error handling | Wrap controller calls in `try/catch` |
| Logging | Enable during development; reduce level for production |
| Updates | Regenerate when on-chain ABI changes |

[comment]: # (mx-context-auto)

## Troubleshooting

| Issue | Resolution |
| ----- | ---------- |
| `Could not parse ABI file` | Rebuild the ABI and confirm the path passed to `abidock` |
| Name collisions | Use a unique `--name` per contract or adjust output paths |
| Runtime type mismatch | Regenerate to match the latest on-chain ABI |
| WebSocket connection failures | Verify endpoint, credentials, and network reachability |

[comment]: # (mx-context-auto)

## Next Steps

Need manual control? Jump back to [COOKBOOK.md](../manual/COOKBOOK.md). Otherwise, continue extending your generated controllers and examples under `example/cookbook/generated/`.
