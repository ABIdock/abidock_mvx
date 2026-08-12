---
id: example-assets
title: Example Assets
---

[comment]: # (mx-abstract)

Wallet files consumed by the runnable examples. Nothing in this directory is committed except this note and the ignore rule — you supply your own keys.

[comment]: # (mx-context-auto)

## What goes here

| File | Used by | Purpose |
| ---- | ------- | ------- |
| `alice.pem` | `controller_swap.dart`, `controller_swap_without_abi.dart`, `controller_relayed_swap.dart`, `transfer.dart`, `generated_controller_swap.dart`, `generated_transfer.dart` | Sender wallet that signs and pays |
| `bob.pem` | `controller_relayed_swap.dart` | Relayer wallet that pays the fee |

The examples resolve these paths from the repository root, so run them as documented in [`../README.md`](../README.md):

```bash
dart run example/cookbook/manual/transfer.dart
```

[comment]: # (mx-context-auto)

## Creating the wallets

Either export a PEM from a MultiversX wallet tool, or generate a fresh pair with the bundled script:

```bash
dart run example/assets/create_wallets.dart
```

[`create_wallets.dart`](create_wallets.dart) writes `alice.pem` and `bob.pem` here, prints each bech32 address and its mnemonic, and refuses to overwrite a file that already exists. Fund both printed addresses from the devnet faucet before running the swap and transfer examples.

:::note
`controller_relayed_swap.dart` requires alice and bob to sit in the **same shard** — relayed V3 rejects a cross-shard relayer. Re-run the script until the two addresses land together, or check with `Address.getShardOfAddress`.
:::

:::caution
A PEM file contains a private key in clear text. `.gitignore` in this directory blocks `*.pem` so a key can never be committed by accident — do not weaken that rule, and never point an example at a mainnet wallet.
:::

[comment]: # (mx-context-auto)

## Examples that need nothing here

`websocket_events.dart`, `generated_polling_events.dart`, and `generated_websocket_events.dart` are read-only listeners. They run without any wallet; the WebSocket samples only need `ABIDOCK_WS_API_KEY` in the environment.
