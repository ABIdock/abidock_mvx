# AGENTS.md

`abidock_mvx` 3.1.0 — MultiversX blockchain SDK for Dart/Flutter
(`pubspec.yaml:1-3`). Dart SDK floor `^3.13.0` (`pubspec.yaml:10`). Accounts and
signing, the transaction model, factories and controllers (transfers, ESDT,
delegation, governance, multisig, validators, contracts), a full ABI type system
and binary codecs, API and Gateway network providers, outcome parsers, and the
`abidock` code generator in `bin/`.

## Knowledge base

**`skills/`** holds the agent documentation. Start at **`skills/README.md`** for
the current index. Reading order:

1. `skills/README.md` — index, versions, what the package does
2. `skills/00-quickstart.md` — install, the one import, a compiled end-to-end
   example, the first three pitfalls
3. `skills/01-public-api.md` — every symbol reachable from the barrel
4. The numbered topic file for the job in front of you

## The one import

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
```

`lib/abidock_mvx.dart` is the only public entry point. Never import
`package:abidock_mvx/src/...`.

## Do not use — removed in 3.0.0, will not compile

`SignableMessage` (use `Message` + `MessageComputer.computeBytesForSigning`) ·
`ValidatorSigner(secretKey)` and `ValidatorSigner.fromPem` (use
`ValidatorSigner.custom(signFn)`) · `TransactionStatus.recalled` / `isRecalled` ·
`NetworkConfig.gasPriceModifierString` (use `gasPriceModifier`) ·
`functionCallHexParts` (use `functionCall: <TypedValue>[...]`) ·
`RelayedTransactionsFactory.createRelayedTransaction` (use `applyRelayer`, then
sign) · `createTransactionForDelegatingVote` ·
`createTransactionForUnsettingBurnRoleForAll` (use
`createTransactionForUnsettingBurnRoleGlobally`) ·
`Transaction.innerTransactions`. `relayedVersion` survives only as `String?` on
`TransactionOnNetwork`.

## Four facts that are easy to get wrong

- **ESDT built-in functions are addressed to the sender**, not the ESDT system
  contract; system-contract endpoints (`issue`, `setSpecialRole`, `pause`,
  `freeze`, …) go to the ESDT contract
  (`lib/src/core/transaction/factories/token_management_transactions_factory.dart:1259`).
- **Relayed v3 is one flat transaction** carrying `relayer` +
  `relayerSignature`; there is no inner-transaction bundle.
- **Factory gas** = `minGasLimit + gasLimitPerByte * data.length` plus execution
  gas (same file, `:1254-1262`).
- **Timestamps** switch seconds → milliseconds at the Supernova epoch and the
  unit differs per route; read `TransactionOnNetwork.executedAt`
  (`lib/src/core/transaction/transaction_on_network.dart:566`).

## Layout

`lib/abidock_mvx.dart` public entry point · `lib/src/` implementation · `bin/`
the `abidock` CLI (`dart run abidock_mvx:abidock help`) · `test/` (`dart test`;
live-network suites need `dart test -P integration`) · `skills/` this knowledge
base · `CHANGELOG.md` the **Removed** tables.
