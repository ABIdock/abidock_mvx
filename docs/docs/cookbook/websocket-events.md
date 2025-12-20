---
id: websocket-events
title: WebSocket Events
sidebar_position: 5
description: Real-time blockchain event streaming with WebSocket connections and ABI parsing.
---

# WebSocket Events

Real-time blockchain event streaming for live updates.

## Complete Example

```dart
import 'dart:io';
import 'package:abidock_mvx/abidock_mvx.dart';

Future<void> main() async {
  // 1. Setup logging
  final logger = ConsoleLogger(
    minLevel: LogLevel.debug,
    includeTimestamp: true,
    prettyPrintContext: true,
    showBorders: true,
    useColors: true,
  );

  // 2. Connect to network (for ABI parsing)
  final provider = ApiNetworkProvider.devnet();

  // 3. Load contract ABI
  final abiFile = File('assets/pair.abi.json');
  final abiJsonString = await abiFile.readAsString();
  final abi = SmartContractAbi.fromJson(abiJsonString);

  // 4. Create controller for contract address
  final controller = SmartContractController(
    abi: abi,
    contractAddress: SmartContractAddress.fromBech32(
      'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
    ),
    networkProvider: provider,
    logger: logger,
  );

  // 5. Configure WebSocket stream
  final swapConfig = WebSocketEventStreamConfig.byIdentifiers(
    websocketUrl: 'wss://kepler-api.projectx.mx/devnet/events',
    identifiers: const ['swap'],
    contractAddress: controller.contractAddress,
    headers: {'Api-Key': 'your-api-key-here'},
    abi: abi,
    logger: logger,
  );

  // 6. Create and connect stream
  final swapStream = WebSocketEventStream(swapConfig);
  await swapStream.connect();

  // 7. Listen for events
  swapStream.events.listen((result) {
    final parsed = result.parsedEvent!;
    print('Swap event received!');
    print('Data: ${parsed.toMap()}');
  });

  // Keep running to receive events
  print('Listening for swap events... Press Ctrl+C to exit');
}
```

## Key Concepts

### Event Identifiers

Filter events by identifier (event name):

```dart
identifiers: const ['swap', 'addLiquidity', 'removeLiquidity'],
```

### Contract Address Filter

Only receive events from a specific contract:

```dart
contractAddress: controller.contractAddress,
```

### ABI-Powered Parsing

When you provide an ABI, events are automatically parsed:

```dart
final parsed = result.parsedEvent!;
print(parsed.toMap()); // Structured event data
```

### Without ABI

You can still receive raw events without an ABI:

```dart
final config = WebSocketEventStreamConfig.byIdentifiers(
  websocketUrl: 'wss://...',
  identifiers: const ['swap'],
  // No abi parameter - receive raw events
);
```

## Configuration Options

| Option | Description |
|--------|-------------|
| `websocketUrl` | WebSocket endpoint URL |
| `identifiers` | Event names to filter |
| `contractAddress` | Filter by contract |
| `headers` | Custom headers (API key) |
| `abi` | ABI for event parsing |
| `logger` | Logger instance |

## WebSocket Endpoints

| Network | Endpoint |
|---------|----------|
| Devnet | `wss://kepler-api.projectx.mx/devnet/events` |
| Mainnet | `wss://kepler-api.projectx.mx/events` |

:::note
WebSocket endpoints may require an API key. Check with your provider.
:::

## Connection Management

```dart
// Connect
await swapStream.connect();

// Disconnect when done
await swapStream.disconnect();

// Check connection status
if (swapStream.isConnected) {
  print('Connected');
}
```

## Error Handling

```dart
swapStream.events.listen(
  (result) {
    print('Event: ${result.parsedEvent?.toMap()}');
  },
  onError: (error) {
    print('Stream error: $error');
  },
  onDone: () {
    print('Stream closed');
  },
);
```

## See Also

- [Detailed Breakdown](/docs/advanced/cookbook-breakdown#websocket-events) - Step-by-step explanation
- [Network Configuration](/docs/network/network-configuration) - Network providers
