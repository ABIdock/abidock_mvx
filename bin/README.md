---
id: cli-reference
title: abidock CLI Reference
---

[comment]: # (mx-abstract)

Reference for the abidock command-line interface. Install the CLI, use all available commands, and integrate code generation into your development workflow.

[comment]: # (mx-context-auto)

## Overview

`abidock` converts MultiversX ABI files into strongly typed Dart controllers, models, and helpers. This guide documents installation, core commands, and recommended workflows for both solo contracts and complex dApps.

[comment]: # (mx-context-auto)

## Installation

### From pub.dev (recommended)

```bash
dart pub global activate abidock_mvx
```

### From Git repository

```bash
dart pub global activate --source git https://github.com/ABIdock/abidock_mvx.git
```

### From local checkout

```bash
dart pub global activate --source path .
```

:::important
Ensure the pub cache bin directory is on your `PATH`:
- **Windows**: `%LOCALAPPDATA%\Pub\Cache\bin`
- **Linux/macOS**: `~/.pub-cache/bin`
:::

[comment]: # (mx-context-auto)

## Command Reference

### Available commands

```bash
abidock init [--output abidock.yaml] [--name MyDapp]
abidock validate [--config abidock.yaml] [--fail-on-warnings]
abidock generate [--config abidock.yaml]
abidock watch [--config abidock.yaml] [--skip-initial]
abidock <abi> <outDir> <contractName> [--full|--logger|--autogas|--transfers]
abidock help
```

### Command details

| Command | Description |
| ------- | ----------- |
| `init` | Create `abidock.yaml` configuration interactively or via flags |
| `validate` | Lint ABIs for errors and warnings |
| `generate` | Produce controllers from config file |
| `watch` | Regenerate automatically when ABIs change |
| `<abi> <outDir> <name>` | One-off generation for quick iteration |
| `help` | Show usage information |

### Flags

| Flag | Description |
| ---- | ----------- |
| `--logger` | Inject `ConsoleLogger` into generated controllers |
| `--autogas` | Enable automatic gas estimation for calls |
| `--transfers` | Scaffold transfer helpers for EGLD/ESDT/NFT/SFT |
| `--full` | Enable logger + autogas + transfers |

:::important
Relayer and guardian parameters are always available in generated code, regardless of flags.
:::

[comment]: # (mx-context-auto)

## Workflows

### One-off generation (fast validation)

```bash
sc-meta all build                                # [1]
abidock example/cookbook/pair.abi.json lib/generated/pair Pair --full  # [2]
```

Where:
- **[1]** Build ABI from your contract source
- **[2]** Generate type-safe controller

Import the generated barrel file and instantiate:

```dart
import 'generated/pair/pair.dart';

final controller = Controller(
  contractAddress: 'erd1...',
  networkProvider: ApiNetworkProvider.devnet(),
);
```

### Config-driven workflow (team-friendly)

```bash
abidock init           # Create abidock.yaml
# Edit contracts list
abidock validate       # Sanity check
abidock generate       # Deterministic build
abidock watch          # Rebuild on changes
```

### Example configuration

```yaml title="abidock.yaml"
name: MyDapp
version: 1.2.0
contracts:
  - name: Pair
    abi: example/cookbook/pair.abi.json
    output: lib/generated/pair
    generation:
      full: true
  - name: Farm
    abi: example/cookbook/farm.abi.json
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

### CI/CD integration

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

[comment]: # (mx-context-auto)

## Generated Output Structure

```
lib/generated/pair/
├─ pair.dart                 # Barrel export
├─ controller.dart           # High-level API
├─ abi.dart                  # Parsed ABI snapshot
├─ calls/                    # One file per call endpoint
├─ queries/                  # One file per query endpoint
├─ models/                   # Structs and enums
├─ events/                   # Polling and WebSocket streams
└─ transfers/                # Present when --transfers is enabled
```

Every call/query is a dedicated file, making diffs easier to review and dependency injection straightforward.

[comment]: # (mx-context-auto)

## Feature Highlights

| Feature | Description |
| ------- | ----------- |
| Type-safe codecs | Primitives, composite structures, and special MultiversX types |
| Auto-generated controllers | Optional logger, auto-gas, transfer helpers, relayed transaction support |
| Event decoders | Polling and WebSocket flows with typed events |
| Watch mode | Configurable debounce and console behavior |

[comment]: # (mx-context-auto)

## Troubleshooting

| Issue | Resolution |
| ----- | ---------- |
| `abidock` not found | Add pub cache `bin` directory to `PATH` or run `dart pub global run abidock_mvx:abidock` |
| Permission denied (Unix) | `chmod +x ~/.pub-cache/bin/abidock` |
| Validation fails | Inspect reported ABI path; run `abidock validate --verbose` for deeper logs |
| Generated code drifts | Delete output directory and regenerate to avoid stale files |

[comment]: # (mx-context-auto)

## Local Development

When working on the CLI itself:

```bash
dart run bin/codegen/main.dart <abi> <outDir> <contractName> [flags]
dart test
dart analyze
```

[comment]: # (mx-context-auto)

## Support

| Resource | Link |
| -------- | ---- |
| Issues | https://github.com/ABIdock/abidock_mvx/issues |
| Documentation | See `README.md` and cookbooks |
| License | MIT (see `LICENSE`) |
