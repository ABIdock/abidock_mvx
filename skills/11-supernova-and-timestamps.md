---
name: supernova-and-timestamps
title: Supernova and Timestamps
summary: Read chain time correctly across the Supernova unit change, and size polling for sub-second rounds, using the exact accessors this package provides.
reads: [skills/12-pitfalls.md, skills/03-transactions.md]
verified_against: abidock_mvx 3.1.0 (Dart 3.13)
---

## When to use this

You are about to read a `timestamp` field, compute an age or a duration from
chain data, or tune how long you poll for a transaction.

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
```

## 1. The one rule

**Never read a raw `timestamp` / `blockTimestamp` field.** Use the normalised
accessor for the object you hold. The raw fields are faithful echoes of the
wire and their unit is not stable.

| Class | Raw fields (do not use) | Normalised accessor | Declared |
|---|---|---|---|
| `TransactionOnNetwork` | `timestamp`, `timestampMs` | `DateTime? get executedAt` | `lib/src/core/transaction/transaction_on_network.dart:566` |
| `AccountOnNetwork` | `timestamp`, `timestampMs` | `DateTime? get indexedAt` | `lib/src/core/account/account_on_network.dart:392` |
| `TokenOnNetwork` | `timestamp`, `timestampMs` | `DateTime? get createdAt` | `lib/src/core/token_on_network.dart:142` |
| `BlockOnNetwork` | `timestamp`, `timestampMs` | `DateTime? get producedAt` | `lib/src/infrastructure/network/block_on_network.dart:204` |
| `HyperblockOnNetwork` | `timestamp`, `timestampMs` | `DateTime? get producedAt` | `lib/src/infrastructure/network/block_on_network.dart:366` |
| `NetworkStatus` | `blockTimestamp`, `blockTimestampMs` | `DateTime? get blockTime` | `lib/src/infrastructure/network/network_status.dart:263` |

Every one of them is `timestampMs ?? timestamp` (or
`blockTimestampMs ?? blockTimestamp`) passed through `ChainTimestamp`. All
return UTC. All return `null` when the provider reported neither value.

## 2. Why the raw field is unsafe

Read this as a statement about **this package's parsing**, which is what the
code shows. Two facts, both verified against the declarations:

1. **No timestamp field is normalised on ingest.** `NetworkStatus.fromApiResponse`
   reads `erd_block_timestamp` and `erd_block_timestamp_ms` with plain
   `optionalInt` and stores both verbatim — no unit conversion, no
   reconciliation between the two (`network_status.dart:131-138`). The same
   holds for `timestamp` / `timestampMs` on `TransactionOnNetwork`. Whatever
   unit the provider sent is the unit sitting in the field.
2. **The package does not trust the field name.** Every normalised accessor
   discards the naming and re-decides the unit from the value's magnitude via
   `ChainTimestamp` (§3). A codebase that believed `_ms` meant milliseconds
   would not need a magnitude test at all — the presence of one is the design
   admitting the suffix is not evidence.

So: the unit of a raw field is not knowable from its name, and this package
does not resolve it for you until you call the accessor. Call the accessor.

Why the unit moves at all: at the Supernova activation epoch several chain
timestamp fields switch from seconds to milliseconds without being renamed
(`network_status.dart:3-12`, `transaction_on_network.dart:536-543`). The
per-route and per-field specifics are recorded in this package's own
documentation only — see "Not verified".

## 3. `ChainTimestamp` — the magnitude rule

Declared `lib/src/infrastructure/network/network_status.dart:13`. Private
constructor; static members only.

| Member | Signature | Behaviour |
|---|---|---|
| `ChainTimestamp.millisecondThreshold` | `static const int` = `100000000000` | Smallest raw value read as milliseconds rather than seconds |
| `ChainTimestamp.toMilliseconds` | `static int? toMilliseconds(int? value)` | `null` for `null` or `0`; `value` when `value >= millisecondThreshold`; `value * 1000` otherwise (`:37-40`) |
| `ChainTimestamp.toDateTime` | `static DateTime? toDateTime(int? value)` | `toMilliseconds`, then `DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)` (`:54-58`) |

Why the threshold is unambiguous: `100000000000` is 1973-03-03 read as
milliseconds and the year 5138 read as seconds, so no chain timestamp of
either unit falls in the overlap (`:16-19`).

`0` and `null` both mean "not reported": a round that cannot be dated is
reported as `0`, and the key is omitted entirely otherwise (`:28-30`).

Runtime-verified values:

| Input | `toMilliseconds` |
|---|---|
| `1766062438` | `1766062438000` |
| `1766062438000` | `1766062438000` |
| `0` | `null` |
| `null` | `null` |

Boundary behaviour is pinned in
`test/infrastructure/network/network_status_test.dart:28,32`:
`100000000000` stays as-is, `99999999999` is multiplied by 1000. Both were
also re-run directly: `toMilliseconds(100000000000)` → `100000000000`,
`toMilliseconds(99999999999)` → `99999999999000`.

## 4. Compiled sample

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// Reading chain time safely: never divide or multiply a raw `timestamp`.
Future<void> readChainTime(ApiNetworkProvider provider, String txHash) async {
  final TransactionOnNetwork tx = await provider.getTransaction(txHash);

  /// Normalised, unit-agnostic, UTC. `null` when the provider reported
  /// neither `timestamp` nor `timestampMs`.
  final DateTime? executedAt = tx.executedAt;
  print('executed at $executedAt');

  /// Chain tip freshness from the same normalisation.
  final NetworkStatus status = await provider.getNetworkStatus();
  final DateTime? tip = status.blockTime;
  if (tip != null) {
    final Duration staleness = DateTime.now().toUtc().difference(tip);
    print('tip is ${staleness.inMilliseconds} ms old');
  }

  /// Normalising a raw value yourself, when you hold one from elsewhere.
  final int? asMillis = ChainTimestamp.toMilliseconds(tx.timestamp);
  final DateTime? asDateTime = ChainTimestamp.toDateTime(tx.timestamp);
  print('$asMillis / $asDateTime');
}
```

## 5. Sub-second rounds: polling defaults

The package's awaiter defaults are sized for a 600 ms round. Before Supernova a
round lasted 6 seconds, which is why older defaults were an order of magnitude
larger (`lib/src/infrastructure/network/account_awaiter.dart:12-15`).

| Option class | `timeout` | `pollingInterval` | `patience` | `maxConsecutiveErrors` |
|---|---|---|---|---|
| `TransactionAwaitingOptions` (`transaction_watcher.dart:54-58`) | `Duration(seconds: 9)` | `Duration(milliseconds: 600)` | `Duration.zero` | `5` |
| `AccountAwaitingOptions` (`account_awaiter.dart:24-29`) | `Duration(seconds: 9)` | `Duration(milliseconds: 600)` | `Duration.zero` | `5` |

9 s is exactly 15 polling intervals; the values are pinned by
`test/core/transaction/transaction_watcher_defaults_test.dart:22-40`.

`TransactionAwaitingOptions` has three extra fields
(`transaction_watcher.dart:59-91`):

| Field | Type | Effect |
|---|---|---|
| `awaitCrossShardCompletion` | `bool` (default `false`) | `awaitCompleted` keeps polling until a `completedTxEvent`, `SCDeploy` or `signalError` event appears (`:329-339`) |
| `numShards` | `int?` | With `roundDuration`, raises the effective timeout |
| `roundDuration` | `Duration?` | With `numShards`, raises the effective timeout |

When both are set, the effective timeout becomes
`max(timeout, roundDuration * (numShards + 1) * 3)` (`:245-251`).

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// Polling defaults are sized for sub-second rounds. Widen the timeout for
/// cross-shard work instead of widening the interval.
///
/// `NetworkConfig.roundDuration` is an `int` of MILLISECONDS, so it must be
/// wrapped in `Duration(milliseconds: ...)`, never `Duration(seconds: ...)`.
TransactionAwaitingOptions crossShardOptions(NetworkConfig config) {
  return TransactionAwaitingOptions(
    awaitCrossShardCompletion: true,
    numShards: config.numShards,
    roundDuration: Duration(milliseconds: config.roundDuration),
  );
}
```

`NetworkConfig.roundDuration` is `final int` in **milliseconds**, parsed from
`erd_round_duration` with a fallback of `6000`
(`lib/src/infrastructure/network/network_config.dart:19,107,202`).
`NetworkConfig.numShards` is `final int`, from `erd_num_shards_without_meta`,
fallback `3` (`:122,216`).

## 6. Other Supernova-era wire changes this package models

| Change | Symbol | Declared |
|---|---|---|
| New terminal status string `not-executable-in-block` | `TransactionStatus.notExecutableInBlock`, `bool get isNotExecutableInBlock` | `lib/src/core/transaction/transaction_status.dart:89,162` |
| Nullable `int` field the package surfaces from `searchOrder` | `TransactionOnNetwork.searchOrder` | `transaction_on_network.dart:676` |
| Nullable `String` field read from `miniblockType`, falling back to `miniBlockType` if the first key is absent — `data['miniblockType'] ?? data['miniBlockType']` at both ingest sites | `TransactionOnNetwork.miniBlockType` | `transaction_on_network.dart:683`, ingest at `:333`, `:509` |

What the package's own documentation says these mean — `searchOrder` is a
total-ordering index for stable cross-shard sorting, and
`not-executable-in-block` marks a transaction that appeared in a proposed
block but was absent from that block's execution result — is doc-comment
material, not something this repository's code can demonstrate. The mechanical
behaviour below is code, and that is what you should build on.

`not-executable-in-block` is **final but not completed** — two predicates
answering two different questions:

```
bool get isFinal     => isExecuted || isFailed || isNotExecutableInBlock;
bool get isCompleted => isExecuted || isFailed;
```

(`transaction_status.dart:175` and `:189`.) `isFinal` asks "will the status
change again"; `isCompleted` asks "did the chain execute this and produce an
outcome". So for this status `isFinal` is `true` — a watcher stops polling —
while `isCompleted` is `false`. Runtime-checked:
`TransactionStatus('not-executable-in-block').isFinal == true`,
`.isCompleted == false`, `.isNotExecutableInBlock == true`. Pinned by
`test/core/transaction/transaction_status_supernova_test.dart:221-243`.

`TransactionOnNetwork` forwards both spellings to the status unchanged —
`isCompleted` → `status.isCompleted` (`transaction_on_network.dart:703`),
`isFinal` → `status.isFinal` (`:723`), `isNotExecutableInBlock` →
`status.isNotExecutableInBlock` (`:741`) — so `tx.isCompleted` and
`tx.status.isCompleted` always answer the same.

Because `TransactionWatcher.awaitCompleted` polls on `status.isFinal`
(`transaction_watcher.dart:192`), it **returns** on this status rather than
timing out. Test `tx.isCompleted` (or `tx.isNotExecutableInBlock`) before
treating a returned transaction as executed: such a transaction carries no logs
and no smart-contract results, so there is no outcome to parse from it.

## Not verified

Everything below appears in this package only as **doc-comment prose**. No
executable code in this repository demonstrates it, and doc comments in this
repository have been stale before. Treat these as unconfirmed background, not
as rules to build on — the normalised accessors in §1 are correct regardless
of which of these turn out to be true.

- **Per-route unit divergence.** `transaction_on_network.dart:536-543` states
  that the Gateway `/transaction/:hash` route reports `timestamp` in
  milliseconds once Supernova is active while its block routes and the public
  API keep reporting seconds. Not observable from this repository.
- **`erd_block_timestamp` and `erd_block_timestamp_ms` carrying the identical
  value.** `network_status.dart:8-10` and `:235-243` state this, and conclude
  that exactly one of the two is correct on each side of the activation. The
  code neither relies on nor contradicts it; it stores both fields verbatim
  and re-decides by magnitude at read time.
- **The meaning of `not-executable-in-block` on the chain**, and the claim
  that such a transaction carries no logs and no smart contract results
  (`transaction_status.dart:179-183`). What is verified is only the predicate
  arithmetic in §6.
- The epoch number at which Supernova activates on any network, and whether it
  is already active on mainnet, devnet or testnet. Nothing in this repository
  pins an activation epoch, so treat both units as reachable at all times and
  always go through the normalised accessors.
- The actual post-Supernova round duration on any live network. The 600 ms
  figure appears in this package only as the rationale for its polling
  defaults (`account_awaiter.dart:12-15`), and the runtime value comes from
  `NetworkConfig.roundDuration` on the network you are talking to.
- Which routes emit `timestampMs` / `erd_block_timestamp_ms` on which hosts
  today. The package reads both spellings and normalises whichever arrives.
