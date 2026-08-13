---
id: cli-commands
title: CLI Commands
sidebar_position: 2
description: Use the abidock CLI to generate Dart code from ABI files with interactive, direct, and config-based modes.
---

# CLI Commands

The `abidock` CLI generates type-safe Dart code from MultiversX ABI files. It supports three modes of operation:

1. **Direct Mode** - Quick single-contract generation
2. **Interactive Mode** - Guided prompts for beginners
3. **Config Mode** - YAML-based multi-contract workflows (recommended)

---

## Installation

### Option 1: Global Activation (Recommended)

Activate the CLI globally to use `abidock` from any project:

```bash
dart pub global activate abidock_mvx
```

Now you can run `abidock` from anywhere:

```bash
abidock init
abidock generate
abidock --interactive
```

:::tip
Make sure `~/.pub-cache/bin` (Linux/macOS) or `%LOCALAPPDATA%\Pub\Cache\bin` (Windows) is in your PATH.
:::

### Option 2: Project Dependency

Add to your `pubspec.yaml`:

```yaml
dev_dependencies:
  abidock_mvx: ^3.1.0
```

Then run via:

```bash
dart run abidock_mvx:abidock init
dart run abidock_mvx:abidock generate
```

---

## Quick Start

```bash
# Initialize config (recommended)
abidock init

# Edit abidock.yaml, then generate
abidock generate

# Or generate directly (single contract)
abidock assets/pair.abi.json lib/generated/pair Pair --full
```

---

## Commands Overview

| Command | Description |
|---------|-------------|
| `init` | Create `abidock.yaml` configuration file |
| `generate` | Generate code for configured contracts |
| `validate` | Validate ABIs against rules |
| `watch` | Watch for ABI changes and auto-regenerate |
| `help` | Show help message |
| `--interactive` | Launch guided prompts |

---

## Direct Mode

Generate code for a single contract with positional arguments:

```bash
abidock <abi_file> <output_dir> <contract_name> [flags]
```

The same three positionals work after `generate`, which is handy when a script
always calls the same subcommand:

```bash
abidock generate <abi_file> <output_dir> <contract_name> [flags]
```

### Positional Arguments

| Position | Required | Description |
|----------|----------|-------------|
| 1 | Yes | Path to ABI JSON file |
| 2 | Yes | Output directory |
| 3 | Yes | Contract name (used for controller class) |

### Feature Flags

| Flag | Description |
|------|-------------|
| `--logger` | Auto-inject `ConsoleLogger` in generated controller |
| `--autogas` | Generate automatic gas estimation via `simulateGas` |
| `--transfers` | Generate `TransferService` for EGLD/ESDT/NFT/multi transfers |
| `--full` | Enable ALL features (logger + autogas + transfers) |

### Examples

```bash
# Basic generation
abidock assets/pair.abi.json lib/generated/pair Pair

# With all features
abidock assets/pair.abi.json lib/generated/pair Pair --full

# With specific features
abidock assets/pair.abi.json lib/generated/pair Pair --autogas --logger

# Only auto-gas
abidock assets/pair.abi.json lib/generated/pair Pair --autogas
```

---

## Interactive Mode

Launch guided code generation for beginners:

```bash
abidock --interactive
```

Interactive mode walks you through:
1. Entering the ABI file path
2. Specifying output directory
3. Naming the contract
4. Selecting features (logger, autogas, transfers)
5. Confirming generation

```
Abidock Code Generator

? Enter ABI file path: assets/pair.abi.json
? Enter output directory: lib/generated/pair
? Enter contract name: Pair
? Enable logger? (y/n): y
? Enable auto-gas? (y/n): y
? Enable transfers? (y/n): n

Starting code generation...

Generation complete!
   Files generated: 25
   Lines generated: 1,847
   Time: 234ms
   Output: lib/generated/pair/
```

---

## Config-Based Mode (Recommended)

For projects with multiple contracts, use the YAML-based configuration workflow.

### Step 1: Initialize Configuration

```bash
abidock init
```

This creates an `abidock.yaml` file in your project root.

You can also specify initial values:

```bash
abidock init --name MyContract --abi assets/my.abi.json --output-dir lib/contracts/my
```

### Step 2: Configure `abidock.yaml`

```yaml
# abidock Configuration File
version: 1

# Default settings applied to all contracts
defaults:
  generateFull: true        # Generate queries + mutations + transfers
  validateBeforeGen: true   # Validate ABI before code generation

# Contracts to process
contracts:
  - name: PairContract
    abi: assets/pair.abi.json
    output: lib/contracts/pair

  - name: RouterContract
    abi: assets/router.abi.json
    output: lib/contracts/router

  - name: FarmContract
    abi: assets/farm.abi.json
    output: lib/contracts/farm
    # Override defaults per-contract
    overrides:
      generateFull: false
      validateBeforeGen: false

# Watch mode configuration (optional)
watch:
  debounceMs: 500          # Wait time before regenerating
  clearConsole: true       # Clear console on each regeneration
  verbose: false           # Show detailed output

# Validation configuration (optional)
validation:
  level: standard          # minimal, standard, or strict
  failOnWarnings: false    # Treat warnings as errors
  disabledRules: []        # Disable specific validation rules

# Environment variables can be used with ${VAR_NAME} syntax
# Example:
#   abi: ${PROJECT_ROOT}/assets/contract.abi.json
```

### Step 3: Generate Code

```bash
# Generate all contracts from abidock.yaml
abidock generate

# Generate from a specific config file
abidock generate --config custom.yaml
```

Output:
```
📖 Loading configuration...
🔨 Generating 3 contract(s)...

🔍 Validating: PairContract...
🔨 Generating: PairContract...
✅ Generated PairContract (156ms)

🔍 Validating: RouterContract...
🔨 Generating: RouterContract...
✅ Generated RouterContract (203ms)

🔍 Validating: FarmContract...
🔨 Generating: FarmContract...
✅ Generated FarmContract (178ms)

🎉 All contracts generated successfully!
```

---

## Validate Command

Validate ABI files before generation to catch issues early.

### Validate from Config

```bash
abidock validate
```

### Validate Single ABI

```bash
abidock validate --abi assets/pair.abi.json --name Pair
```

### Validation Options

| Flag | Description |
|------|-------------|
| `--config <path>` | Path to config file |
| `--abi <path>` | Path to single ABI file |
| `--name <name>` | Contract name (required with --abi) |
| `--fail-on-warnings` | Treat warnings as errors |
| `--verbose` | Show detailed validation info |
| `--json` | Output results as JSON |

### Examples

```bash
# Validate all contracts in config
abidock validate

# Validate with strict mode
abidock validate --fail-on-warnings

# Validate single ABI with verbose output
abidock validate --abi assets/pair.abi.json --name Pair --verbose

# Output validation as JSON (useful for CI/CD)
abidock validate --json
```

---

## Watch Command

Automatically regenerate code when ABI files change.

```bash
abidock watch
```

### Watch Options

| Flag | Description |
|------|-------------|
| `--config <path>` | Path to config file |
| `--skip-initial` | Skip initial generation on start |

### Example Output

```
📖 Loading configuration...
👁️  Watch mode enabled for 3 contract(s)

🔨 Initial generation...
✅ Generated PairContract (156ms)
✅ Generated RouterContract (203ms)
✅ Generated FarmContract (178ms)

👁️  Watching 3 contract(s) for changes...
   Press Ctrl+C to stop

12:34:56 | 📄 Change detected: PairContract
🔨 Regenerating: PairContract...
✅ Generated PairContract (142ms)
```

### Watch Configuration

Configure watch behavior in `abidock.yaml`:

```yaml
watch:
  debounceMs: 500        # Wait 500ms after change before regenerating
  clearConsole: true     # Clear console on each regeneration
  verbose: false         # Show detailed output
```

---

## Generated Output

The CLI writes into the output directory you named:

```
pair/
├── abi.dart                   # ABI constant
├── controller.dart            # Main PairController class
├── pair.dart                  # Barrel export file
├── transfer_service.dart      # TransferService (with --transfers)
├── models/                    # Structs, enums, event models
├── queries/                   # Query functions (one per view endpoint)
├── calls/                     # Call functions, plus deploy.dart / upgrade.dart
├── events/                    # Event streams (when the ABI declares events)
│   ├── multi_event_polling_stream.dart
│   ├── multi_event_websocket_stream.dart
│   ├── polling_events/
│   └── websocket_events/
└── transfers/                 # egld / esdt / nft / multi (with --transfers)
```

---

## Feature Flags Details

### --logger

Injects a `ConsoleLogger` into the generated controller with detailed
formatting. The parameter is typed as the abstract `Logger`, so you can pass
any implementation instead:

```dart
PairController({
  required dynamic contractAddress,
  required NetworkProvider networkProvider,
  Logger? logger,  // Optional logger parameter added
}) : logger = logger ?? ConsoleLogger(
       minLevel: LogLevel.debug,
       includeTimestamp: true,
       prettyPrintContext: true,
       showBorders: true,
       useColors: true,
     ),
     // ...
```

### --autogas

Generated calls use `simulateGas` to automatically estimate gas. Without the
flag, each call takes a `required GasLimit gasLimit` instead:

```dart
Future<Transaction> addLiquidity(
  SmartContractController controller,
  IAccount sender,
  Nonce nonce,
  BigInt firstTokenAmountMin,
  BigInt secondTokenAmountMin,
  // ...
) async {
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
    arguments: <dynamic>[firstTokenAmountMin, secondTokenAmountMin],
    gasLimit: const GasLimit(600000000),
    value: value,
  );

  // Estimate gas using simulation.
  final gasLimit = await simulateGas(probeTx, controller.networkProvider);

  // Sign once with the final gas limit. copyWith on a signed tx would
  // invalidate the signature, so we never mutate gas after signing.
  return controller.call(
    account: sender,
    nonce: nonce,
    endpointName: 'addLiquidity',
    arguments: <dynamic>[firstTokenAmountMin, secondTokenAmountMin],
    options: BaseControllerInput(gasLimit: gasLimit),
    // ...
  );
}
```

### --transfers

Generates `transfer_service.dart` with a stateless `TransferService` for
sending EGLD, ESDT tokens, NFTs, and multi-token batches. It is built from a
`NetworkProvider`, not from the contract controller:

```dart
// Generated TransferService
class TransferService {
  const TransferService(this._provider);

  Future<Transaction> egld(...);
  Future<Transaction> esdt(...);
  Future<Transaction> nft(...);
  Future<Transaction> multi(...);

  TransferTransactionsFactory get transferFactory;
}
```

### --full

Shortcut to enable all features. Equivalent to `--logger --autogas --transfers`.

---

## Environment Variables

You can use environment variables in your `abidock.yaml` config using the `${VAR_NAME}` syntax:

```yaml
contracts:
  - name: MyContract
    abi: ${PROJECT_ROOT}/assets/contract.abi.json
    output: ${OUTPUT_DIR}/my_contract
```

Set them before running:

```bash
# PowerShell
$env:PROJECT_ROOT = "C:\projects\my-app"
abidock generate

# Bash
export PROJECT_ROOT=/home/user/projects/my-app
abidock generate
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Generate Contract Code

on:
  push:
    paths:
      - 'assets/*.abi.json'

jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable
          
      - run: dart pub global activate abidock_mvx
        
      - name: Validate ABIs
        run: abidock validate --fail-on-warnings
        
      - name: Generate Code
        run: abidock generate
        
      - name: Commit generated code
        run: |
          git config user.name github-actions
          git config user.email github-actions@github.com
          git add lib/contracts/
          git diff --staged --quiet || git commit -m "chore: regenerate contract code"
          git push
```

---

## Usage After Generation

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:my_app/generated/pair/pair.dart';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  
  // Generated controller takes contract address in constructor
  final pair = PairController(
    contractAddress: 'erd1qqqqqqqqqqqqqpgq...',
    networkProvider: provider,
  );
  
  // Type-safe queries
  final reserve = await pair.getReserve(TokenIdentifier('WEGLD-bd4d79'));
  final (res1, res2, total) = await pair.getReservesAndTotalSupply();
  
  print('Reserve: $reserve');
  print('Reserves: $res1, $res2, Total: $total');
}
```

## Next Steps

- [Generated Code](/docs/codegen/generated-code) - Understand output structure
- [Customization](/docs/codegen/customization) - Configure generation
- [Smart Contracts](/docs/smart-contracts/overview) - Use generated code
