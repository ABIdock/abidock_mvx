---
id: nonce-manager
title: Nonce Manager
sidebar_position: 10
description: Allocate fresh nonces for back-to-back transactions without a getAccount round-trip per send.
---

# Nonce Manager

`NonceManager` is a stateful, forward-only nonce allocator for a single
address. It keeps a local counter that stays ahead of the network so
back-to-back sends never reuse a nonce, and concurrent callers are
serialized so two async callers cannot grab the same value.

Use it for bulk flows — airdrops, batch mints, multi-step choreographies —
where round-tripping `getAccount` between every transaction would be wasteful
or racy.

## Basic usage

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

final NonceManager nonces = NonceManager(
  address: account.address,
  networkProvider: provider,
);

Future<String> sendOne(Transaction draft, Account account) async {
  final Nonce nonce = await nonces.next();
  try {
    final Transaction withNonce = draft.copyWith(newNonce: nonce);
    final Uint8List signature = await account.signTransaction(withNonce);
    final Transaction signed = withNonce.copyWith(
      newSignature: Signature.fromUint8List(signature),
    );

    final String hash = await provider.sendTransaction(signed);
    nonces.applyNonce(nonce); // record successful broadcast
    return hash;
  } catch (_) {
    nonces.release(nonce); // return the nonce to the pool
    rethrow;
  }
}
```

On first use the manager seeds its counter from `provider.getAccount(address)`;
subsequent `next()` calls stay local and immediately increment.

## Semantics

| Method | Behaviour |
|---|---|
| `next()` | Reserves and returns the next `Nonce`. Calls are serialized. |
| `applyNonce(nonce)` | Records that a nonce was successfully broadcast. Sets a floor for future `resync()` calls. |
| `release(nonce)` | Returns a reserved nonce to the pool. If it was the last-reserved value, the counter rewinds; otherwise it is queued for reuse on the next `next()` call. |
| `resync()` | Forces a fresh `getAccount` call. The counter only moves **forward** — if the network reports a lower nonce than the local counter, the local value stays. |
| `peek` | Current locally-reserved counter as a plain `int?` (not a `Nonce`), or `null` if never synced. |

`applyNonce` also sets a floor for `release`: a nonce at or below the highest
applied value is ignored rather than returned to the pool, so a successfully
broadcast nonce can never be handed out twice.

## Periodic re-sync

The manager periodically re-syncs from the network to pick up nonces that
advanced behind its back (e.g. another signing context on the same
address). The default cadence is 5 minutes; set `resyncInterval` to
`Duration.zero` to disable it.

```dart
final nonces = NonceManager(
  address: account.address,
  networkProvider: provider,
  resyncInterval: const Duration(minutes: 1),
);
```

Background refreshes are silent-fail: if `getAccount` errors, the local
counter keeps being used. The first seeding call always rethrows on
failure.

## What it is not

- Not a shared registry across multiple processes — it is a single
  in-memory counter scoped to one `NonceManager` instance.
- Not a signer or sender — plug it in to the transaction pipeline you
  already have.
- Not a retry/queue framework — failed sends should release their nonce
  and decide whether to retry at a higher level.
