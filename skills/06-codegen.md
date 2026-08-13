---
name: codegen
title: ABI Code Generation
summary: Run the bundled `abidock` CLI on a `.abi.json` and use the typed Dart it emits — controller, queries, calls, event streams, models — knowing the exact file tree, symbol names and signatures it produces.
reads: [04-smart-contracts.md, 09-events-and-parsers.md]
verified_against: abidock_mvx 3.1.0 (Dart 3.13)
---

**When to use this**: you have a MultiversX contract's `.abi.json` and want typed
Dart instead of hand-writing `endpointName:` strings and argument lists.

Everything below was produced by actually running the tool in this repo against
`example/cookbook/pair.abi.json` (54 endpoints, 8 types, 4 events).

---

## 1. Getting the CLI

The package declares one executable, `abidock`, backed by `bin/abidock.dart`
(`pubspec.yaml:12-13`).

| How you got the package | Command |
|---|---|
| Installed globally | `dart pub global activate abidock_mvx` then `abidock <args>` |
| Listed as a dependency | `dart run abidock_mvx:abidock <args>` |
| Working inside this repo | `dart run bin/abidock.dart <args>` |

`dart run abidock_mvx:abidock help` was executed and printed the command list, as
did `--help`, `-h` and a bare invocation with no arguments (§2.5).

---

## 2. Commands

Dispatch happens in `bin/abidock.dart:12-43`. A help request is answered first,
before anything else is parsed (`isHelpInvocation`, `bin/codegen/cli/help.dart:101-111`);
otherwise the first argument is treated as a subcommand when it does **not**
start with `-`. Recognised subcommands are `init`, `generate`, `validate` and
`watch`. Anything else falls through to the one-off generator
(`bin/codegen/main.dart`).

### 2.1 `init` — write an `abidock.yaml`

`abidock init [--config|-c <path>] [--name <name>] [--abi <path>] [--output-dir <path>]`

| Flag | Effect | Default |
|---|---|---|
| `--config`, `-c` | Path of the config file to create | `abidock.yaml` (`bin/codegen/cli/commands/init_command.dart:13`) |
| `--name` | `contracts[0].name` written into the file | `MyContract` (`bin/codegen/cli/config/config_loader.dart:164`) |
| `--abi` | `contracts[0].abi` | `assets/contract.abi.json` (`config_loader.dart:165`) |
| `--output-dir` | `contracts[0].output` | `lib/contracts/my_contract` (`config_loader.dart:166`) |

Running it twice fails — verified output:
`❌ Error: Config file already exists: <path>`, exit 1
(`config_loader.dart:159-161`).

### 2.2 `generate` — emit Dart

Two forms:

```bash
abidock generate <abi_file> <output_dir> <contract_name> [--logger] [--autogas] [--transfers] [--full]
abidock generate [--config|-c <path>]
```

| Flag | Effect |
|---|---|
| `--config`, `-c <path>` | Read contracts from that config file |
| `--logger` | Controller gains a `Logger? logger` constructor parameter and a `logger` field |
| `--autogas` | Call helpers estimate gas by simulation instead of taking `gasLimit` |
| `--transfers` | Also emit `transfer_service.dart` + `transfers/` |
| `--full` | All three of the above (`bin/abidock.dart:132-134`, `generate_command.dart:28-30`) |

Which source wins is decided in
`bin/codegen/cli/commands/generate_command.dart:20-40`, most explicit first:

| You passed | What is generated |
|---|---|
| `--config <path>` | That config file |
| `<abi> <output> <name>` | Exactly those three, even if an `abidock.yaml` is present |
| neither | The config discovered in the working directory |
| neither, and no config found | Usage error, exit 1 |

Both forms were run in a directory containing an `abidock.yaml`: with the three
positional arguments the tool wrote the requested output directory and left the
config's target untouched; with no arguments it generated the config's contract.

The bare invocation without the `generate` keyword —
`abidock <abi_file> <output_dir> <contract_name> [flags]` — is equivalent for a
one-off and goes straight to `bin/codegen/main.dart`.

### 2.3 `validate` — check an ABI JSON

```bash
abidock validate --abi <path> --name <name> [--verbose|-v] [--json] [--fail-on-warnings]
abidock validate [--config|-c <path>] [flags]
```

`--abi` and `--name` must be given **together**; with only one of them the
command falls back to the config file, and with neither available it prints a
usage error and exits 1 (`validate_command.dart:18-40`).

| Flag | Effect |
|---|---|
| `--verbose`, `-v` | Also print `info`-severity issues (`validation_models.dart:149`) |
| `--json` | Print the report as JSON |
| `--fail-on-warnings` | Exit 1 when there are warnings but no errors (`validate_command.dart:127`) |

Exit code is 1 when any `error` issue exists — verified: the broken ABI below
exited 1.

> `--json` is **not** clean JSON on stdout: the banner `🔍 Validating <name>...`
> and a blank line are printed before the JSON object
> (`validate_command.dart:111-122`). Verified. Parse the last line, not the
> whole stream.

### 2.4 `watch` — regenerate on ABI change

```bash
abidock watch [--config|-c <path>] [--skip-initial]
```

Config-only; there is no positional form (`bin/abidock.dart:157-172`). It
generates every contract once at start unless `--skip-initial` is passed, then
watches each ABI file's **parent directory** and filters events down to that one
file name (`bin/codegen/cli/watcher/abi_watcher.dart:63-93`). Stops on SIGINT
(`watch_command.dart:188`).

Verified end to end: started with `--skip-initial`, touched
`example/cookbook/pair.abi.json`, and the process printed
`📄 Change detected: Pair` → `🔍 Validating...` → `✅ Validation passed` →
`🔨 Generating: Pair` → `✅ Generated successfully (1016ms)`.

### 2.5 `help`

The help page is the single `abidockHelpText` constant in
`bin/codegen/cli/help.dart:12-79`, and every form that asks for it prints that
same page to stdout and exits **0**. All four were run:

| Invocation | Result |
|---|---|
| `abidock help` | help page, exit 0 |
| `abidock --help` / `abidock -h` | help page, exit 0 |
| `abidock` with no arguments | help page, exit 0 |
| `abidock generate --help`, `abidock validate -h`, … | help page, exit 0 — the flag is honoured in **any** argument position, so it documents the tool instead of running the subcommand |

Matching is case-insensitive (`help.dart:101-111`).

### 2.6 Do not use `--interactive` from an agent

`abidock --interactive` starts a prompt-driven wizard
(`bin/codegen/main.dart:8-13`). It requires a terminal and will hang a
non-interactive session.

---

## 3. `abidock.yaml`

Searched for, in order, in the current directory: `abidock.yaml`, `abidock.yml`,
`.abidock.yaml` (`config_loader.dart:8-12`). `${VAR_NAME}` occurrences outside
comments are replaced from the environment, and a missing variable is a hard
error (`config_loader.dart:76-117`). Relative `abi` / `output` paths resolve
against the **config file's directory**, not the working directory
(`config_loader.dart:30-53`).

Minimal working file (this exact shape was generated and consumed successfully):

```yaml
version: 1

defaults:
  generateFull: true
  validateBeforeGen: true

contracts:
  - name: Pair
    abi: ../../example/cookbook/pair.abi.json
    output: lib/generated/pair
```

Every key the loader reads:

| Key | Type | Default | Effect |
|---|---|---|---|
| `version` | int | `1` | Any value other than `1` throws `ConfigException` (`config.dart:16-21`) |
| `defaults.generateFull` | bool | `true` | `true` → logger + autogas + transfers all on (`generate_command.dart:137-139`) |
| `defaults.validateBeforeGen` | bool | `true` | Validate before generating; errors abort with exit 1 (`generate_command.dart:69-82`) |
| `contracts[].name` | String | required | Controller class is `PascalCase(name) + 'Controller'`; barrel file is `snake_case(name).dart` |
| `contracts[].abi` | String | required | Path to the `.abi.json` |
| `contracts[].output` | String | required | Output directory, created if absent |
| `contracts[].overrides.generateFull` | bool | inherits | Per-contract override (`config.dart:68-74`) |
| `contracts[].overrides.validateBeforeGen` | bool | inherits | Per-contract override |
| `watch.debounceMs` | int | `500` | Debounce window before regenerating (`abi_watcher.dart:59-61`) |
| `watch.clearConsole` | bool | `true` | Clear console each cycle (on Windows this prints 50 blank lines, `watch_command.dart:180-181`) |
| `watch.verbose` | bool | `false` | Print each filesystem event and warning counts |
| `watch.excludePatterns` | list | none | Glob-ish (`*`, `?`) match on the **file name**; matches are skipped (`abi_watcher.dart:120-137`) |

**Parsed but with no effect in 3.1.0** — do not rely on these:

| Key | Why it does nothing |
|---|---|
| `watch.includePatterns` | Read into `WatchConfig` (`config.dart:167`) and never referenced anywhere else |
| `validation.level`, `validation.failOnWarnings`, `validation.disabledRules`, `validation.customRules` | The whole `validation:` block is parsed and carried around, but nothing from it ever reaches `AbiValidator`. `generate` and `watch` build it with no arguments at all (`generate_command.dart:71`, `watch_command.dart:110`); `validate` passes only the `--fail-on-warnings` **CLI flag** (`validate_command.dart:67`, `:114`). The rule set is always the default. Use the CLI flag instead. |
| `contracts[].metadata` | Parsed into `ContractConfig` and never read by any generator |

---

## 4. What gets generated

Command actually run:

```bash
dart run bin/abidock.dart generate example/cookbook/pair.abi.json .skills_gen/pair pair --full
```

Reported: `Files: 85`, `Lines: 6882`. Resulting tree (`<out>` = `.skills_gen/pair`,
contract name `pair`):

```
<out>/
  abi.dart                       # const String abiJson + final SmartContractAbi abi
  controller.dart                # PairController + PairEvents
  pair.dart                      # barrel: snake_case(contractName).dart
  transfer_service.dart          # only with --transfers / --full
  models/                        # 8 ABI types + 4 event models = 12 files
  queries/                       # 1 file per readonly/pure endpoint = 26
  calls/                         # 1 file per mutable endpoint = 28, plus deploy.dart
  events/
    polling_events/              # 1 file per event = 4
    websocket_events/            # 1 file per event = 4
    multi_event_polling_stream.dart
    multi_event_websocket_stream.dart
  transfers/                     # egld / esdt / nft / multi, only with --transfers
```

Which generator produces what, and when (`bin/codegen/codegen.dart:50-212`):

| Output | Emitted when |
|---|---|
| `abi.dart`, `controller.dart`, barrel | always |
| `models/` | `types` is non-empty / events exist |
| `queries/` | there is ≥1 endpoint with `mutability` `readonly` or `pure` |
| `calls/` | there is ≥1 other endpoint |
| `calls/deploy.dart` | ABI has `constructor` or `upgradeConstructor` |
| `events/polling_events/`, `events/websocket_events/`, `multi_event_websocket_stream.dart` | ABI has ≥1 event |
| `events/multi_event_polling_stream.dart` | ABI has **≥2** events (`bin/codegen/generators/events_generator.dart:33`) |
| `transfer_service.dart`, `transfers/` | `--transfers` or `--full` |

`models/`, `queries/`, `calls/`, `events/polling_events/` and
`events/websocket_events/` are created up front regardless
(`codegen.dart:237-250`), so a directory with nothing to emit is left behind
empty — verified: an ABI with no `readonly` endpoint produced an empty
`queries/`.

### 4.1 Naming rules

| Thing | Rule | Example |
|---|---|---|
| Controller class | `PascalCase(contractName) + 'Controller'` (`controller_generator.dart:27-28`) | `pair` → `PairController` |
| Events accessor class | `PascalCase(contractName) + 'Events'` (`controller_generator.dart:31-32`) | `PairEvents` |
| Barrel file | `snake_case(contractName).dart` (`barrel_generator.dart:24`) | `pair.dart` |
| Query / call function + file | `camelCase(endpoint)` / `snake_case(endpoint).dart` | `getReserve` → `queries/get_reserve.dart` |
| Model class + file | `PascalCase(typeName)` / `snake_case(typeName).dart` | `TokenPair` → `models/token_pair.dart` |
| Event model class | `PascalCase(identifier minus trailing `_event`) + 'Event'`; if a type in `types` already produces that class name, `'Data'` is appended (`events_generator.dart:40-70`) | `ping_event` → `PingEvent`; `swap` → `SwapEventData`, because the ABI also defines a struct `SwapEvent` |
| Stream classes | `PascalCase(identifier) + 'PollingStream' / 'WebSocketStream'` — the `_event` suffix is **kept** here | `ping_event` → `PingEventPollingStream` |

Contract name casing does not matter: `pair` and `Pair` produced byte-identical
trees.

### 4.2 Identifier sanitising

`bin/codegen/core/name_sanitizer.dart`:

| Situation | Transform | Verified example |
|---|---|---|
| Field / parameter name | `snake_case` → `camelCase` | `first_token_amount_min` → `firstTokenAmountMin` |
| Name starts with a digit | prefix `field` (`:95-97`) | `1st_arg` → `field1stArg`, struct field `2nd` → `field2nd` |
| Name is a Dart keyword | suffix `Value` (`:99-101`) | struct field `final` → `finalValue`, param `class` → `classValue` |
| Parameter collides with a scaffold name — `sender`, `nonce`, `gasLimit`, `value`, `controller`, `relayer`, `guardian`, `factory` (`:76-85`) | suffix `Param` | input `value` → `valueParam` |
| Enum variant is a keyword | suffix `Value` (`:120-126`) | variant `default` → `defaultValue` |
| Type name is a keyword | suffix `Type` (`:129-135`) | — |

The **wire** names are never renamed: the sanitised Dart field maps back to the
original string in the emitted `StructType`, e.g.
`FieldDefinition(name: 'final', type: U32Type.type)` for `finalValue`.

If a generated model class name collides with a symbol exported by
`package:abidock_mvx/abidock_mvx.dart`, the generator emits
`import 'package:abidock_mvx/abidock_mvx.dart' hide <Symbol>;`
(`bin/codegen/core/import_manager.dart:41-53`, symbol list in
`bin/codegen/core/known_package_symbols.dart`). The generated `controller.dart`
for the pair ABI contains exactly
`import 'package:abidock_mvx/abidock_mvx.dart' hide EsdtTokenPayment;`, because
the ABI defines its own `EsdtTokenPayment` struct.

### 4.3 ABI type → Dart type

`bin/codegen/core/type_mapper.dart:6-72`:

| ABI type | Dart type |
|---|---|
| `u8`, `u16`, `u32`, `i8`, `i16`, `i32` | `int` |
| `u64`, `i64`, `BigUint`, `BigInt`, `ManagedDecimal<..>` | `BigInt` |
| `BigFloat` | `double` |
| `Address` | `Address` |
| `bool` | `bool` |
| `bytes`, `H256`, `ManagedByteArray<N>` | `Uint8List` |
| `string` / `utf-8 string` | `String` |
| `TokenIdentifier`, `EsdtTokenIdentifier` | `TokenIdentifier` |
| `EgldOrEsdtTokenIdentifier` | `EgldOrEsdtTokenIdentifier` |
| `CodeMetadata` | `List<int>` |
| `Nothing` | `void` |
| `Option<T>`, `optional<T>` | `T?` |
| `List<T>`, `array<N,T>`, `variadic<T>`, `counted-variadic<T>` | `List<T>` |
| `tuple<A,B>`, `multi<A,B>`, `MultiValue2<A,B>` | Dart record `(A, B)` |
| struct / enum / explicit-enum | the generated class |

Anything else throws `UnimplementedError: Unsupported ABI type: ...` during
generation (`type_mapper.dart:69-71`).

> `BigFloat` maps to `double` for local arithmetic only. It has **no wire
> codec**: `BigFloatValue.toBytes()` always throws `UnimplementedError`
> (`lib/src/abi/types/primitives/big_float.dart:85-90`). Never put a `BigFloat`
> on the wire.

---

## 5. Using the generated code

All snippets below were compiled clean with `dart analyze` against the committed
output in `example/cookbook/generated/pair/` (generated with `--full`). The only
thing changed for readability is the barrel import path — point
`import 'generated/pair/pair.dart';` at wherever your `output` directory is.

### 5.1 Controller and queries

`PairController` constructor (`example/cookbook/generated/pair/controller.dart:124-152`):

```
PairController({
  required dynamic contractAddress,   /// String bech32 or Address instance
  required NetworkProvider networkProvider,
  Logger? logger,                     /// only present with --logger / --full
})
```

`contractAddress` is `dynamic` on purpose: a `String` is converted with
`SmartContractAddress.fromBech32`, anything else is cast to `Address`. There is
also `PairController.withController(SmartContractController)`, and the getters
`controller`, `networkProvider`, `factory`.

Every `readonly` / `pure` endpoint becomes a method with the ABI's input list,
returning the mapped Dart type:

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

import 'generated/pair/pair.dart';

Future<void> main() async {
  final provider = ApiNetworkProvider.devnet();

  final controller = PairController(
    contractAddress:
        'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
    networkProvider: provider,
  );

  const wegld = TokenIdentifier('WEGLD-a28c59');
  final BigInt reserve = await controller.getReserve(wegld);
  final TokenIdentifier lpToken = await controller.getLpTokenIdentifier();
  final (BigInt first, BigInt second, BigInt supply) = await controller
      .getReservesAndTotalSupply();

  print('$reserve $lpToken $first $second $supply');
}
```

Note the multi-output endpoint returns a Dart **record**, not a list.

Under each controller method sits a free function that takes the
`SmartContractController` as its first argument, e.g.
`Future<BigInt> getReserve(SmartContractController controller, TokenIdentifier tokenId)`
in `queries/get_reserve.dart`. Import the file directly if you do not want the
controller.

### 5.2 Calls

Signature template (`bin/codegen/generators/calls_generator.dart:122-147`):

```
Future<Transaction> <endpointCamelCase>(
  SmartContractController controller,
  IAccount sender,
  Nonce nonce,
  <one positional parameter per ABI input, in ABI order>, {
  List<TokenTransferValue> tokenTransfers = const <TokenTransferValue>[],  /// payable endpoints only
  required GasLimit gasLimit,                                              /// only WITHOUT --autogas
  Address? relayer,
  Address? guardian,
  Balance? value,
})
```

The controller method is the same minus the leading `controller` argument.

```dart
import 'dart:io';

import 'package:abidock_mvx/abidock_mvx.dart';

import 'generated/pair/pair.dart';

Future<void> main() async {
  final provider = ApiNetworkProvider.devnet();
  final controller = PairController(
    contractAddress:
        'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
    networkProvider: provider,
  );

  final account = await Account.fromPem(
    File('assets/alice.pem').readAsStringSync(),
  );
  final Nonce nonce = (await provider.getAccount(account.address)).nonce;

  const wegld = TokenIdentifier('WEGLD-a28c59');
  const mex = TokenIdentifier('MEX-a659d0');
  final BigInt amountIn = BigInt.from(10).pow(18);
  final BigInt amountOut = await controller.getAmountOut(wegld, amountIn);
  final BigInt minOut = (amountOut * BigInt.from(9900)) ~/ BigInt.from(10000);

  final Transaction tx = await controller.swapTokensFixedInput(
    account,
    nonce,
    mex,
    minOut,
    tokenTransfers: <TokenTransferValue>[
      TokenTransferValue.fromPrimitives(
        tokenIdentifier: wegld.value,
        amount: amountIn,
      ),
    ],
  );

  final String hash = await provider.sendTransaction(tx);
  final receipt = await TransactionWatcher(
    networkProvider: provider,
  ).awaitCompleted(hash);
  print(receipt.status);
}
```

`tokenTransfers` exists only when the endpoint declares `payableInTokens`
(`calls_generator.dart:136-140`). `value`, `relayer` and `guardian` are always
there.

**`--autogas` costs a network round-trip per call.** The generated body builds a
probe transaction at `GasLimit(600000000)` and calls
`simulateGas(probeTx, controller.networkProvider)`, which re-simulates and
returns the estimate multiplied by 1.1 (`lib/src/utils/helpers.dart:241-254`).
Without `--autogas` you must pass `gasLimit:` yourself and no simulation happens.

### 5.3 Unsigned transactions and deploy

Each call also gets a `<name>Unsigned` variant. With `--autogas` it is
`Future<Transaction>` and takes `(SmartContractCallFactory factory, NetworkProvider networkProvider, Address sender, Nonce nonce, ...)`;
without it, it is a synchronous `Transaction` taking
`(SmartContractCallFactory factory, Address sender, Nonce nonce, ..., {required GasLimit gasLimit})`.
The controller wrapper hides the first one or two arguments.

`calls/deploy.dart` is generated from the ABI `constructor` but is **not**
exported by the barrel (`barrel_generator.dart:26-80`) — import it directly.

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';

import 'generated/pair/calls/deploy.dart';
import 'generated/pair/pair.dart';

Future<void> main() async {
  final provider = ApiNetworkProvider.devnet();
  final account = await Account.fromPem(
    File('assets/alice.pem').readAsStringSync(),
  );
  final Nonce nonce = (await provider.getAccount(account.address)).nonce;

  final controller = PairController(
    contractAddress:
        'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
    networkProvider: provider,
  );

  final Transaction unsigned = await controller.swapTokensFixedInputUnsigned(
    account.address,
    nonce,
    const TokenIdentifier('MEX-a659d0'),
    BigInt.from(1),
  );
  final List<Uint8List> signatures = await account.signTransactions(<Transaction>[
    unsigned,
  ]);
  final Transaction signed = unsigned.copyWith(
    newSignature: Signature.fromUint8List(signatures[0]),
  );
  await provider.sendTransactions(<Transaction>[signed]);

  final Transaction deployTx = deploy(
    provider,
    account.address,
    nonce,
    File('assets/pair.wasm').readAsBytesSync(),
    const GasLimit(120000000),
    const TokenIdentifier('WEGLD-a28c59'),
    const TokenIdentifier('MEX-a659d0'),
    account.address,
    account.address,
    BigInt.from(300),
    BigInt.from(50),
    account.address,
    <Address>[account.address],
  );
  print(deployTx.data);
}
```

`deploy` is synchronous and returns an unsigned `Transaction`; its positional
order is `networkProvider, sender, nonce, bytecode, gasLimit, <constructor inputs…>`
with optional `codeMetadata` and `vmType` (default `'0500'`).

### 5.4 Events

`controller.events` is a `PairEvents` instance (`controller.dart:1190`). It
offers:

| Member | Returns | Notes |
|---|---|---|
| `pollingStream({Duration pollingInterval = 10s, String? startFrom})` | `MultiEventPollingStream` | Only generated when the ABI has ≥2 events |
| `websocketStream({required String websocketUrl, Map<String,String> headers = const {}, bool autoReconnect = true, Duration reconnectDelay = 1s, Duration connectionTimeout = 5s, Duration pingInterval = 10s})` | `MultiEventWebSocketStream` | |
| `<event>Polling()` | e.g. `SwapPollingStream` | The class is **callable**: `swapPolling()(pollingInterval: …)` returns the `Stream` |
| `<event>WebSocket({required String websocketUrl, …})` | e.g. `SwapWebSocketStream` | Defaults here differ: `reconnectDelay` 5s, `connectionTimeout` 15s, `pingInterval` 30s |

`MultiEventPollingStream` exposes one typed getter per event plus
`all` (`Stream<dynamic>`) and `only(List<Type>)`. One polling loop feeds all of
them (`multi_event_polling_stream.dart:21-23`).

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

import 'generated/pair/pair.dart';

Future<void> main() async {
  final controller = PairController(
    contractAddress:
        'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
    networkProvider: ApiNetworkProvider.devnet(),
  );

  final MultiEventPollingStream polling = controller.events.pollingStream(
    pollingInterval: const Duration(seconds: 10),
  );

  polling.swap.listen((SwapEventData event) {
    print('${event.caller.bech32} ${event.tokenIn.value} ${event.epoch}');
  });

  polling.all.listen((dynamic event) {
    if (event is AddLiquidityEventData) {
      print(event.addLiquidityEvent.toJson());
    }
  });

  final Stream<SwapEventData> single = controller.events.swapPolling()(
    pollingInterval: const Duration(seconds: 6),
  );
  single.listen((SwapEventData event) => print(event.swapEvent.toJson()));
}
```

> The element type of `all` is the **event model** class, which for this ABI is
> `SwapEventData` — not the struct `SwapEvent` that appears as one of its
> fields. Type-testing `event is SwapEvent` never matches. Check the generated
> `models/` directory for the exact class name before writing `is` tests.

WebSocket streams are lifecycle objects — nothing arrives before `connect()`:

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

import 'generated/pair/pair.dart';

Future<void> main() async {
  final controller = PairController(
    contractAddress:
        'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
    networkProvider: ApiNetworkProvider.devnet(),
  );

  final MultiEventWebSocketStream ws = controller.events.websocketStream(
    websocketUrl: 'wss://example.invalid/events',
    headers: const <String, String>{'Api-Key': 'key'},
  );

  ws.statusChanges.listen((WebSocketStatusChange change) => print(change));
  ws.swap.listen((SwapEventData event) => print(event.tokenOut.value));

  await ws.connect();
  await ws.disconnect();
  await ws.dispose();
}
```

Also available on the WebSocket wrappers: `errors`, `pause()`, `resume()`.

### 5.5 Transfers (`--transfers` / `--full`)

`TransferService` wraps four free functions and needs only a `NetworkProvider` —
it is contract-independent, so generating it once is enough.

```dart
import 'dart:io';

import 'package:abidock_mvx/abidock_mvx.dart';

import 'generated/pair/pair.dart';

Future<void> main() async {
  final provider = ApiNetworkProvider.devnet();
  final account = await Account.fromPem(
    File('assets/alice.pem').readAsStringSync(),
  );
  final Nonce nonce = (await provider.getAccount(account.address)).nonce;

  final TransferService transfers = TransferService(provider);

  final Transaction egldTx = await transfers.egld(
    account,
    nonce,
    Address.fromBech32('erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th'),
    Balance.fromEgld(1),
  );

  final Transaction esdtTx = await transfers.esdt(
    account,
    nonce,
    Address.fromBech32('erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th'),
    'WEGLD-a28c59',
    BigInt.from(10).pow(18),
  );

  print('${egldTx.data} ${esdtTx.data}');
}
```

All four methods, from the generated `transfer_service.dart`:

| Method | Positional parameters | Named parameters |
|---|---|---|
| `egld` | `IAccount sender, Nonce nonce, Address receiver, Balance amount` | `Address? relayer, Address? guardian, Uint8List? data, GasLimit? gasLimit` |
| `esdt` | `IAccount sender, Nonce nonce, Address receiver, String tokenId, BigInt amount` | `Address? relayer, Address? guardian, GasLimit? gasLimit` |
| `nft` | `IAccount sender, Nonce nonce, Address receiver, String tokenId, int tokenNonce, BigInt amount` | `Address? relayer, Address? guardian, GasLimit? gasLimit` |
| `multi` | `IAccount sender, Nonce nonce, Address receiver, List<TokenTransfer> transfers` | `Address? relayer, Address? guardian, GasLimit? gasLimit` |

### 5.6 The generated `abi.dart`

Two top-level symbols: `const String abiJson` (the ABI file inlined verbatim)
and `final SmartContractAbi abi = SmartContractAbi.fromJson(abiJson);`. The
controller passes `abi` to `SmartContractController`, so the generated package
has no runtime file dependency on the `.abi.json`.

---

## 6. What the validator checks

`abidock validate` parses the JSON itself; it does **not** build the type graph.
Rules from `bin/codegen/cli/validation/abi_validator.dart`:

| Severity | Rule | Trigger |
|---|---|---|
| error | `FILE_NOT_FOUND` | ABI path does not exist |
| error | `INVALID_JSON` | file is not parseable JSON |
| error | `MISSING_FIELD` | root `name` missing or empty; type definition without `type`; struct field without `name`/`type`; enum with no `variants`; variant without `name`; endpoint without `name`; endpoint input/output without `type` |
| error | `INVALID_TYPE` | a type definition, struct field, enum variant or endpoint is not a JSON object |
| error | `DUPLICATE_ENDPOINT` / `DUPLICATE_VARIANT` | repeated endpoint or variant name |
| error | `INVALID_MUTABILITY` | `mutability` not one of `mutable`, `readonly`, `pure` |
| error | `CIRCULAR_DEPENDENCY` | cycle among `types` entries (only when `types` is an object) |
| warning | `MISSING_FIELD` | `buildInfo` present but missing `contractCrate` / `framework` |
| warning | `INVALID_TYPE` | `buildInfo`, `constructor`, `upgradeConstructor` or `types` is the wrong JSON shape |
| warning | `MISSING_PAYABLE` | `readonly` endpoint with a non-empty `payableInTokens` |
| info | `MISSING_FIELD` | no `buildInfo` — optional build provenance, unused by generation |
| info | `NO_ENDPOINTS` | `endpoints` absent or empty |
| info | `UNKNOWN_TYPE` | `types.<X>.type` is not `struct`, `enum`, `explicit-enum` or `not-specified` |
| error | `VALIDATION_ERROR` | catch-all: the validator itself threw (`abi_validator.dart:64-70`) |

Real output for a file with no `name`, a duplicate endpoint, `mutability: "view"`
and an empty enum:

```
Summary:
  4 error(s)
  0 warning(s)
  1 info message(s)

❌ ERROR [MISSING_FIELD]: Missing or empty "name" field
❌ ERROR [MISSING_FIELD]: Enum has no variants
❌ ERROR [DUPLICATE_ENDPOINT]: Duplicate endpoint name: dup
❌ ERROR [INVALID_MUTABILITY]: Invalid mutability: view
```

> **A passing validation does not mean generation will succeed.** The validator
> never resolves type *references*. An ABI whose endpoint takes an undefined
> type `Foo` validated clean (0 errors) and then failed generation with
> `FormatException: Invalid JSON format: Invalid argument(s): Unknown type: Foo`.
> Both were verified.

### ABI JSON keys the generator reads

`SmartContractAbi.fromMap` (`lib/src/abi/abi.dart:134`) reads `name`,
`version`, `types`, `constructor`, `upgradeConstructor`, `endpoints`, `events`;
every other root key is kept in `metadata` and ignored by codegen. Per endpoint
(`lib/src/abi/core/endpoint.dart:56-127`): `name`, `inputs`, `outputs`,
`payableInTokens`, `payable`, `mutability`, `onlyOwner`, `onlyAdmin`, `title`,
`labels`, `allowMultipleVarArgs`, `docs`, `documentation`. Per
parameter (`lib/src/abi/core/parameter.dart:68-87`): `name`, `type`,
`multi_result`, `specificType`, `docs`. Per event
(`lib/src/abi/core/event.dart:42-198`): `identifier`, `inputs`, `docs`, and per
input `name`, `type`, `indexed`.

Endpoint classification: `mutability` of `readonly` or `pure` makes it a query,
everything else (including a missing `mutability`) makes it a call
(`lib/src/abi/core/endpoint.dart:90`).

> **`types` must be a JSON object, keyed by type name.** `SmartContractAbi`
> only reads it when `data['types'] is Map<String, dynamic>`
> (`lib/src/abi/abi.dart:144`). Verified: an ABI with `types` as an *array*
> validated clean and then failed generation with `Unknown type: Holder`.

Accepted type strings (`lib/src/abi/core/types.dart:335-626`) include `u8`,
`u16`, `u32`, `u64`/`U64`, `u128`/`U128`, `BigUint`, `NonZeroBigUint`, `i8`,
`i16`, `i32`, `i64`, `i128`/`I128`, `BigInt`, `BigFloat`, `Address`, `bool`,
`bytes`, `string`, `utf-8 string`, `H256`, `CodeMetadata`, `Nothing`,
`AsyncCall`, `TokenIdentifier`, `EsdtTokenIdentifier`, `TokenId`,
`EgldOrEsdtTokenIdentifier`, `EsdtTokenPayment`, `EgldOrEsdtTokenPayment`,
`EgldOrMultiEsdtPayment`, `Payment`, `FungiblePayment`, `List<T>`, `Array<T,N>`,
`array2/6/8/16/20/32/46/48/64/128/256<T>`, `ManagedByteArray<N>`, `Option<T>`,
`optional<T>` (`OptionalArg`, `OptionalResult`), `tuple`…`tuple8`,
`MultiValue`…`MultiValue8`, `multi`/`Multi`/`multivalue`, `MultiArg`,
`MultiResult`, `variadic`/`Variadic`/`VarArgs`/`MultiResultVec`,
`counted-variadic`, `ManagedDecimal<N|usize>`, `ManagedDecimalSigned<N|usize>`,
plus any name declared in `types`.

---

## 7. Formatting and regeneration

Generated Dart is formatted before it is written, using the language version of
the SDK running the generator, capped at the bundled formatter's newest
supported version (`bin/codegen/utils/file_writer.dart:14-41`). Output therefore
survives `dart format --set-exit-if-changed` in your CI. If a file fails to
parse it is written unformatted so the analyzer can point at the real error
(`file_writer.dart:57-66`).

Regenerating is safe and expected — output is deterministic and files are
overwritten in place. Verified twice: a fresh `--full` run into a scratch
directory was byte-identical (`diff -rq`) to the committed
`example/cookbook/generated/pair/`, and a config-driven run produced an
identical tree to the flag-driven one. Never hand-edit files under the output
directory; every one starts with
`// GENERATED CODE - DO NOT MODIFY BY HAND`.

Stale files are **not** pruned. Verified: generating the 85-file pair output and
then generating a 14-file single-endpoint ABI into the same directory left 90
files — the five genuinely new ones were added, the shared ones (`abi.dart`,
`controller.dart`, `transfer_service.dart`, `transfers/`) were overwritten, and
every obsolete `queries/get_*.dart` plus the old `pair.dart` barrel survived
next to the new `solo.dart`. Delete the output directory before regenerating
after you rename or remove an endpoint.

---

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `❌ Error: FormatException: Invalid JSON format: Invalid argument(s): Unknown type: Foo` (exit 1) | An endpoint/event/field references a type that is neither a built-in name nor a key of `types` | Add `Foo` to the `types` object, or correct the spelling — the error lists the accepted primitives |
| Same error, but `Foo` *is* in the file | `types` was written as a JSON **array**; only an object keyed by type name is read | Convert to `{"Foo": {"type": "struct", …}}` |
| `abidock validate` passes but `generate` fails | The validator does not resolve type references | Treat `generate` as the real check; run it in CI |
| `generate <abi> <out> <name>` produced nothing at `<out>` | An `abidock.yaml` in the working directory takes priority and the positionals were dropped | Use the bare form `abidock <abi> <out> <name>`, or add the contract to the config |
| `❌ Config error: Config file not found. Searched for: abidock.yaml, abidock.yml, .abidock.yaml` | Raised by `watch`, which is config-only, when there is no config in the current directory | `abidock init`, or pass `-c <path>` |
| `❌ Config error: Config file not found: <path>` | `-c <path>` points at a file that does not exist | Fix the path |
| `❌ Error: Either provide --config, or <abi> <output> <name>` (exit 1) | `abidock generate` with no config in the current directory and fewer than three positionals. `validate` prints the analogous `…or both --abi and --name` | Add the three positionals, `abidock init`, or pass `-c <path>` |
| `❌ Config error: Environment variable not found: X` | `${X}` used in the config and not exported | Export it, or hard-code the path |
| `❌ Config error: Failed to parse config: ConfigException: Unsupported config version: N (only version 1 is supported)` | `version:` is not `1` — the `ConfigException` is re-wrapped by the loader's parse guard, hence the doubled prefix | Set `version: 1` |
| Generated parameter is `valueParam`, field is `finalValue`, `field1stArg` | Dart keyword / scaffold-name / leading-digit collision was renamed (§4.2) | Use the sanitised name; the wire name is unchanged |
| `Undefined name 'MultiEventPollingStream'` | The ABI has exactly one event, so the multi-event *polling* stream is not generated | Use the per-event stream, e.g. `controller.events.pingEventPolling()` |
| `Undefined name 'deploy'` after importing the barrel | `calls/deploy.dart` is not exported by the barrel | `import '<out>/calls/deploy.dart';` directly |
| `is SwapEvent` branch never fires on an event stream | The stream element type is the event model (`SwapEventData` here), and `SwapEvent` is a struct field inside it | Test against the class in `models/<event>_event*.dart` |
| Every call does an extra network round-trip | `--autogas` / `generateFull: true` simulates gas per call | Generate without `--autogas` and pass `gasLimit:` yourself |
| `dart format --set-exit-if-changed` fails on generated files | Generator ran on a different Dart SDK than CI | Regenerate with the same SDK version CI uses |

---

## Not verified

- `dart pub global activate abidock_mvx` was not executed (it would install from
  the package registry); the `abidock` executable name comes from
  `pubspec.yaml:12-13` and was exercised as `dart run abidock_mvx:abidock` and
  `dart run bin/abidock.dart`.
- `abidock --interactive` was not run — it requires a terminal.
- `watch.debounceMs`, `watch.clearConsole`, `watch.verbose` and
  `watch.excludePatterns` are documented from `abi_watcher.dart` /
  `watch_command.dart`; only the default configuration (no `watch:` block) was
  exercised live.
- `TransferService.nft` / `.multi` and the `--logger`-injected `logger` field
  were read from the generated source but not compiled in a sample; `.egld` and
  `.esdt` were.
- Runtime behaviour of the generated event streams against a live node
  (reconnect, `startFrom`) was not exercised; only compilation and the generated
  wiring were checked.
- The `upgradeConstructor` branch of `calls/deploy.dart` was not exercised — the
  pair ABI declares only `constructor`.
