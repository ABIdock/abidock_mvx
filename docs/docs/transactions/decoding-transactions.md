---
id: decoding-transactions
title: Decoding Transactions
sidebar_position: 11
description: Turn a Transaction's data field into a typed, pattern-matchable hierarchy covering EGLD memos, ESDT transfers, NFT transfers, bundled MultiESDTNFT transfers, and plain contract calls.
---

# Decoding Transactions

`TransactionDecoder` turns a [`Transaction`](./overview.md)'s `data`
field into a typed `DecodedTransaction` so you can pattern-match on the
result instead of re-parsing hex-delimited strings.

It is a pure, stateless, zero-I/O decoder — no network round-trip, no ABI
lookup. For full typed return decoding of contract calls, combine it with
[SmartContractController](../smart-contracts/interactions.md).

## Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

final decoded = const TransactionDecoder().decode(tx);

switch (decoded) {
  case NativeEgldTransfer(:final memo):
    print('EGLD memo: ${memo ?? '(none)'}');

  case EsdtTransfer(:final tokenIdentifier, :final amount, :final functionCall):
    print('$amount of $tokenIdentifier'
        '${functionCall == null ? '' : ' → ${functionCall.function}'}');

  case NftTransfer(:final collection, :final nonce, :final destination):
    print('$collection #$nonce → ${destination.bech32}');

  case MultiTransfer(:final transfers):
    print('${transfers.length} tokens bundled');

  case ContractCall(:final call):
    print('call ${call.function}(${call.arguments.length} args)');

  case UnknownTransaction(:final reason):
    print('could not decode: $reason');
}
```

## Shapes recognised

| Outcome | Input shape |
|---|---|
| `NativeEgldTransfer` | empty `data`, or free-form UTF-8 with no `@` separators |
| `EsdtTransfer` | `ESDTTransfer@<tokenHex>@<amountHex>[@<function>@<arg>...]` |
| `NftTransfer` | `ESDTNFTTransfer@<collectionHex>@<nonceHex>@<amountHex>@<destinationHex>[@<function>@<arg>...]` |
| `MultiTransfer` | `MultiESDTNFTTransfer@<destHex>@<countHex>@(<tokenHex>@<nonceHex>@<amountHex>)+[@<function>@<arg>...]` |
| `ContractCall` | any other `<function>@<argHex>...` payload |
| `UnknownTransaction` | invalid UTF-8, truncated transfer list, or malformed argument |

The decoder never throws — anything it doesn't understand becomes
`UnknownTransaction` with a `reason` string explaining what failed.

## Inner contract calls

Token transfers frequently nest a contract call inside the data field (e.g.
"send X WEGLD to router and call `swap`"). The ESDT/NFT/Multi outcomes all
carry an optional `functionCall` that decodes the inner call when present:

```dart
if (decoded case EsdtTransfer(:final functionCall?) ) {
  print('Inner call: ${functionCall.function}');
  for (final arg in functionCall.arguments) {
    print('  arg: 0x${arg.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
  }
}
```
