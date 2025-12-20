---
id: examples
title: Examples
---

[comment]: # (mx-abstract)

Runnable code samples demonstrating the MultiversX SDK and the abidock code generator. Treat these as executable documentation—run every file directly with `dart run`.

[comment]: # (mx-context-auto)

## Overview

The examples directory contains production-style code samples. Each sample demonstrates real-world usage patterns you can adapt for your applications.

[comment]: # (mx-context-auto)

## Implementation Guides

| Guide | Description |
| ----- | ----------- |
| [COOKBOOK.md](cookbook/manual/COOKBOOK.md) | End-to-end manual SDK walkthroughs |
| [CODEGEN_COOKBOOK.md](cookbook/generated/CODEGEN_COOKBOOK.md) | Generated controller workflows and best practices |
| [ABI_COOKBOOK.md](cookbook/ABI_COOKBOOK.md) | Complete ABI types reference |

Each guide links to exact Dart files so you can move from narrative explanations to runnable code without guesswork.

[comment]: # (mx-context-auto)

## Directory Structure

| Directory | Purpose |
| --------- | ------- |
| `cookbook/manual/` | Manual SDK examples: swaps, transfers, WebSocket listeners |
| `cookbook/generated/` | Generated controller examples |

[comment]: # (mx-context-auto)

## Running Examples

### Prerequisites

```bash
dart pub get
```

### Manual SDK flows

```bash
dart run example/cookbook/manual/controller_swap.dart          # [1]
dart run example/cookbook/manual/controller_relayed_swap.dart  # [2]
dart run example/cookbook/manual/transfer.dart                 # [3]
dart run example/cookbook/manual/websocket_events.dart         # [4]
```

Where:
- **[1]** Smart contract interaction with manual ABI handling
- **[2]** Relayed transaction flow
- **[3]** Native EGLD transfers using `TransfersController`
- **[4]** WebSocket event streaming

### Generated controllers

```bash
abidock example/cookbook/pair.abi.json example/cookbook/generated/pair Pair --full  # [1]
dart run example/cookbook/generated/generated_controller_swap.dart        # [2]
dart run example/cookbook/generated/generated_transfer.dart               # [3]
dart run example/cookbook/generated/generated_polling_events.dart         # [4]
dart run example/cookbook/generated/generated_websocket_events.dart       # [5]
```

Where:
- **[1]** Generate type-safe controller from ABI
- **[2]** DEX swap using generated methods
- **[3]** Token transfers with generated helpers
- **[4]** Polling event streams
- **[5]** WebSocket event streams

[comment]: # (mx-context-auto)

## Additional Resources

| Resource | Description |
| -------- | ----------- |
| [Documentation](https://docs-abidock-mvx.netlify.app/) | Full online documentation |
| [README.md](../README.md) | Root documentation |
| [bin/README.md](../bin/README.md) | CLI usage |
| [API Reference](https://pub.dev/documentation/abidock_mvx/latest/) | Generated API docs |
| [MultiversX Docs](https://docs.multiversx.com/) | Protocol documentation |

:::tip
Check `test/` for additional usage patterns and edge case handling.
:::

[comment]: # (mx-context-auto)

## Support

Questions or issues? Open a ticket at https://github.com/ABIdock/abidock_mvx/issues.
