---
id: overview
title: abidock_mvx
---

[comment]: # (mx-abstract)

MultiversX SDK for Dart/Flutter that provides wallets, smart-contract controllers, ABI codecs, and a CLI for generating type-safe Dart code from contract ABIs.

[![pub package](https://img.shields.io/pub/v/abidock_mvx.svg)](https://pub.dev/packages/abidock_mvx)
[![Build](https://github.com/ABIdock/abidock_mvx/workflows/Dart/badge.svg)](https://github.com/ABIdock/abidock_mvx/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-online-blue.svg)](https://docs-abidock-mvx.netlify.app/)

[comment]: # (mx-context-auto)

## Overview

**abidock_mvx** is a Dart/Flutter SDK for the MultiversX blockchain:

| Capability | Description |
| ---------- | ----------- |
| Entrypoints | `DevnetEntrypoint` / `TestnetEntrypoint` / `MainnetEntrypoint` (plus Gateway variants) hand you a cached provider, factories, and controllers for a network in one line |
| Wallet & Key Management | Mnemonic, PEM, keystore, guardian, and relayed-transaction flows |
| Transactions | Gas estimation by simulation, nonce management, token transfers (EGLD/ESDT/NFT/SFT) |
| Smart Contracts | Unified `SmartContractController` with typed queries, calls, and event streaming; `SmartContractTransactionsFactory` for deploy / upgrade / change-owner / claim-developer-rewards |
| ABI System | Full MultiversX ABI coverage (primitives, collections, structs, enums, special types) |
| CLI & Codegen | Config-driven or one-off generation, ABI validation, watch mode, transfer services |
| Tooling | 1,690+ hermetic tests plus live-network integration suites, ready-to-run examples, GitHub Actions workflows |

[comment]: # (mx-context-auto)

## Installation

### Step 1: Add the dependency

Add `abidock_mvx` to your `pubspec.yaml`:

```yaml title="pubspec.yaml"
dependencies:
  abidock_mvx: ^2.0.0
```

### Step 2: Install packages

```bash
dart pub get
```

### Step 3: Install the CLI (optional)

```bash
dart pub global activate abidock_mvx
```

:::important
Ensure `~/.pub-cache/bin` (Linux/macOS) or `%LOCALAPPDATA%\Pub\Cache\bin` (Windows) is on your `PATH` so the `abidock` command resolves globally.
:::

[comment]: # (mx-context-auto)

## Quick Start

### Creating an account

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

final mnemonic = Mnemonic.generate();                      // [1]
final words = mnemonic.getWords().join(' ');               // [2]
final account = await Account.fromMnemonic(words);         // [3]
print('Address: ${account.address.bech32}');               // [4]
```

Where:
- **[1]** Generate a new 24-word mnemonic phrase
- **[2]** Get the mnemonic as a space-separated string
- **[3]** Derive the first account (index 0) from the mnemonic
- **[4]** Print the bech32 address (e.g., `erd1...`)

### Connecting to a network

```dart
final entrypoint = DevnetEntrypoint();                     // [1]
final provider = entrypoint.createNetworkProvider();       // [2]
final transfers = entrypoint.createTransfersFactory();     // [3]
```

Where:
- **[1]** Bind the devnet URL and chain id in one object (`MainnetEntrypoint`, `TestnetEntrypoint`, and the `*ProxyEntrypoint` Gateway variants are the siblings)
- **[2]** The provider is built once and cached for the entrypoint's lifetime
- **[3]** Factories and controllers come pre-configured with the same chain id

### Calling a smart contract

```dart
final provider = ApiNetworkProvider.devnet();              // [1]
final abiJson = await File('example/cookbook/pair.abi.json').readAsString();
final controller = SmartContractController(
  contractAddress: SmartContractAddress.fromBech32('erd1...'),  // [2]
  abi: SmartContractAbi.fromJson(abiJson),                 // [3]
  networkProvider: provider,
);

final accountOnNetwork = await provider.getAccount(account.address);
final tx = await controller.call(                          // [4]
  account: account,
  nonce: accountOnNetwork.nonce,
  endpointName: 'swapTokensFixedInput',
  arguments: [TokenIdentifierValue('MEX-a659d0'), BigInt.from(1000000)],
  tokenTransfers: [
    TokenTransferValue.fromPrimitives(
      tokenIdentifier: 'WEGLD-a28c59',
      amount: BigInt.from(10).pow(17),
    ),
  ],
  options: BaseControllerInput(gasLimit: GasLimit(25000000)),
);
final hash = await provider.sendTransaction(tx);           // [5]
print('Submitted: $hash');
```

Where:
- **[1]** Connect to the devnet API
- **[2]** Specify the contract address
- **[3]** Parse the ABI JSON
- **[4]** Build and sign a transaction
- **[5]** Broadcast the signed transaction to the network

### Generating type-safe controllers

```bash
abidock example/cookbook/pair.abi.json lib/generated/pair Pair --full
```

:::tip
Generated controllers expose typed queries, calls, event streams, and dedicated transfer helpers. See `example/cookbook/generated/` for complete runnable samples.
:::

[comment]: # (mx-context-auto)

## CLI Commands

| Command | Purpose |
| ------- | ------- |
| `abidock init` | Scaffold `abidock.yaml` interactively or via flags |
| `abidock validate` | Lint ABIs (single file or entire config) with optional JSON output |
| `abidock generate` | Produce controllers for every contract defined in the config |
| `abidock watch` | Re-run validation + generation whenever ABI files change |
| `abidock <abi> <output> <name> [flags]` | One-off generation for quick iteration |

Common flags: `--full`, `--logger`, `--transfers`, `--autogas`, `--interactive`, `--config <path>`.

:::important
Relayer and guardian parameters are always available in generated code.
:::

[comment]: # (mx-context-auto)

## Repository Structure

```
lib/                 Core SDK (abi, core, entrypoints, infrastructure, utils, wallet)
bin/abidock.dart     CLI entrypoint (config + direct modes)
example/             Manual & generated cookbook scenarios with reference ABIs
test/                Unit and regression suites; test/integration/ hits live networks
scripts/             Release and automation scripts
```

Run `dart test` for the hermetic suites, and `dart test -P integration` for the
live-network ones.

[comment]: # (mx-context-auto)

## Documentation

| Resource | Description |
| -------- | ----------- |
| [example/README.md](example/README.md) | Guide to all runnable samples |
| [COOKBOOK.md](example/cookbook/manual/COOKBOOK.md) | Manual SDK playbook |
| [ABI_COOKBOOK.md](example/cookbook/ABI_COOKBOOK.md) | Complete ABI types guide |
| [CODEGEN_COOKBOOK.md](example/cookbook/generated/CODEGEN_COOKBOOK.md) | Generated-code guide |
| [bin/README.md](bin/README.md) | CLI reference manual |

[comment]: # (mx-context-auto)

## Contributing

We welcome issues, feature requests, and pull requests. Please read [CONTRIBUTING.md](CONTRIBUTING.md) for workflow expectations, coding standards, and how to run tests locally before opening a PR.

[comment]: # (mx-context-auto)

## License

abidock_mvx is available under the [MIT License](LICENSE).
