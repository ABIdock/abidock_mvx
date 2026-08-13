---
name: skills-index
title: Skills Index
summary: After reading this an agent knows what abidock_mvx does, which skill file answers which question, and in what order to read them.
reads: [00-quickstart.md, 01-public-api.md]
verified_against: abidock_mvx 3.1.0 (Dart 3.13)
---

**When to use this** — you have just pulled `abidock_mvx` into a project and
need to orient before writing a line of code.

## What this package is

`abidock_mvx` 3.1.0 — a MultiversX blockchain SDK for Dart and Flutter
(`pubspec.yaml:1-3`).

| Fact | Value | Source |
|---|---|---|
| Package name | `abidock_mvx` | `pubspec.yaml:1` |
| Version these skills were verified against | `3.1.0` | `pubspec.yaml:3` |
| Dart SDK floor | `^3.13.0` | `pubspec.yaml:10` |
| Public entry point | `package:abidock_mvx/abidock_mvx.dart` | `lib/abidock_mvx.dart` |
| Bundled executable | `abidock` (code generator) | `pubspec.yaml:12-13`, `bin/abidock.dart` |

Runtime dependencies, all from `pubspec.yaml:15-29`: `dio`, `pointycastle`,
`bip39_plus`, `cryptography`, `ed25519_hd_key`, `pinenacl`, `convert`,
`unorm_dart`, `web_socket_channel`, `meta`, `path`, `yaml`, `pub_semver`,
`dart_style`. There is no Flutter dependency — it is a plain Dart package usable
from Flutter.

## What an agent can build with it

- **Move value**: sign and broadcast EGLD transfers and ESDT / NFT / SFT /
  MetaESDT transfers, single or multi-leg.
- **Manage tokens**: issue fungible, non-fungible, semi-fungible and dynamic
  tokens; grant and revoke special roles; mint, burn, pause, freeze, wipe;
  create and update NFT metadata, royalties, URIs and creators.
- **Call contracts**: load an ABI, query views, build and sign calls, deploy and
  upgrade, decode return data and events into typed Dart values.
- **Generate a typed client**: run the `abidock` CLI over a contract ABI to get
  controllers, calls, queries, event models and DTOs.
- **Operate the chain**: delegation and staking, validator operations,
  governance proposals and votes, multisig proposals and execution, guarded
  accounts, relayed-v3 fee sponsorship.
- **Read the chain**: accounts, balances, tokens, blocks, hyperblocks, network
  config/status/economics, guardian data, transaction status and logs — over the
  public API (indexer) or a Gateway/Proxy node.
- **Stay resilient**: retries, circuit breaking, throttling, response caching,
  batching, pagination and structured logging are built in.

## The one import

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
```

## Start here — reading order

1. **`00-quickstart.md`** — install line, the single import, the mental model,
   one compiled end-to-end example (entrypoint → account → signed EGLD transfer
   → broadcast → await), and the three things that trip up a first-time caller.
2. **`01-public-api.md`** — the symbol map. Read before naming any type.
3. Then jump straight to the topic file for the job in front of you.

If you are debugging rather than building, go to `10-errors-and-exceptions.md`
first.

## Index

| File | Read it when |
|---|---|
| `00-quickstart.md` — *Quickstart* | You need a working transaction in the shortest possible path. |
| `01-public-api.md` — *Public API Map* | You need the exact name of a class, enum, typedef or constant reachable from the barrel. |
| `02-wallets-and-signing.md` — *Wallets and Signing* | You need a signing identity from a mnemonic, secret key, keystore or PEM, an `Address`, or signature bytes for a transaction or off-chain message. |
| `03-transactions.md` — *Transaction Lifecycle* | You are building, noncing, signing, broadcasting or awaiting a transaction — including relayed v3 and every token-transfer shape. |
| `04-smart-contracts.md` — *Smart Contract Calls and Queries* | You are loading an ABI, querying a view, calling an endpoint, or deploying/upgrading a contract. |
| `05-abi-types-and-codecs.md` — *ABI Types and Wire Codecs* | You need the Dart class for an ABI type name, what a caller passes for it, or the exact top-level/nested bytes the chain expects. |
| `06-codegen.md` — *ABI Code Generation* | You are running the bundled `abidock` CLI on a `.abi.json` and consuming the typed Dart it emits. |
| `07-network-providers.md` — *Network Providers* | You are choosing or configuring a provider/entrypoint and calling the chain. |
| `08-tokens-esdt.md` — *ESDT Tokens* | You are issuing tokens, managing roles, pausing/freezing/wiping, or running an NFT lifecycle operation. |
| `09-events-and-parsers.md` — *Events and Outcome Parsers* | You need to read events off a settled transaction, decode them with an ABI, or parse a typed outcome. |
| `10-errors-and-exceptions.md` — *Errors and Exceptions* | Something threw and you need to catch the right type. |
| `11-supernova-and-timestamps.md` — *Supernova and Timestamps* | You are reading chain time, or sizing polling intervals for sub-second rounds. |
| `12-pitfalls.md` — *Pitfalls* | You want the traps that produce silently wrong transactions or empty results, with the correct alternative. |

The directory holds 14 files: `README.md` plus `00`–`12`, numbered
consecutively with no gaps. Check the directory listing rather than assuming a
number exists.

`AGENTS.md` at the repo root is a short pointer to this directory.

## Non-negotiables

Both are stated in full in `00-quickstart.md` and `01-public-api.md`; the short
form:

- **Removed in 3.0.0 — will not compile**: `SignableMessage`,
  `ValidatorSigner(secretKey)`, `ValidatorSigner.fromPem`,
  `TransactionStatus.recalled` / `isRecalled`,
  `NetworkConfig.gasPriceModifierString`, `functionCallHexParts`,
  `RelayedTransactionsFactory.createRelayedTransaction`,
  `createTransactionForDelegatingVote`,
  `createTransactionForUnsettingBurnRoleForAll`,
  `Transaction.innerTransactions`.
- **Relayed v3 is one flat transaction** carrying `relayer` +
  `relayerSignature`. There is no inner-transaction bundle.

## The code generator

```
dart run abidock_mvx:abidock help
```

Commands, as printed by the CLI itself: `init` (create `abidock.yaml`),
`generate` (generate code from ABIs), `validate` (validate ABI files), `watch`
(auto-regenerate on change), `help`. Dispatch switch at `bin/abidock.dart:21-40`.

Help is checked before dispatch (`bin/abidock.dart:13-16`) and every invocation
form reaches it: no arguments at all, `help` as the first argument, or `-h` /
`--help` anywhere in the argument list, including after a command such as
`generate --help` (`bin/codegen/cli/help.dart:101-111`).

## Running the repo's own tests

```
dart test                  # hermetic; live-network suites are skipped
dart test -P integration   # only the live-network suites
```

Configured in `dart_test.yaml`.

## Not verified

- The one-line descriptions of sibling skill files are taken from their own
  `title:` and `summary:` frontmatter; their content was not independently
  re-verified here.
- The capability list under "What an agent can build with it" is derived from
  the exported factory, controller and provider surface enumerated in
  `01-public-api.md`. No capability was exercised against a live network.
