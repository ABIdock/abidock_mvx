---
id: websocket-events
title: WebSocket Events
sidebar_position: 3
description: Subscribe to real-time MultiversX blockchain events using WebSocket connections with automatic ABI parsing.
---

# WebSocket Events

Subscribe to real-time blockchain events using WebSocket connections.

## Overview

WebSocket events allow you to:
- Monitor smart contract events in real-time
- Track specific event identifiers
- Build reactive applications with live data
- Parse events automatically with ABI

## Basic Connection

```dart
import 'dart:io';
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  // Load ABI for automatic event parsing
  final abiJson = await File('contract.abi.json').readAsString();
  final abi = SmartContractAbi.fromJson(abiJson);
  
  // Create WebSocket config
  final config = WebSocketEventStreamConfig.byIdentifiers(
    websocketUrl: 'wss://devnet-notifier.multiversx.com',
    identifiers: ['swap', 'addLiquidity'],  // Event names to subscribe to
    contractAddress: SmartContractAddress.fromBech32('erd1qqq...'),
    abi: abi,  // Optional: enables automatic event parsing
  );
  
  // Create stream and connect
  final stream = WebSocketEventStream(config);
  await stream.connect();
  
  // Listen to events
  stream.events.listen((result) {

    print('TX Hash: \${result.txHash}');
    
    // If ABI was provided, events are parsed automatically
    if (result.parsedEvent != null) {
      print('Parsed data: \${result.parsedEvent!.toMap()}');
    }
  });
  
  // Listen to status changes
  stream.statusChanges.listen((status) {
    print('Status: \${status.status}');
  });
  
  // Listen to errors
  stream.errors.listen((error) {
    print('Error: \${error.message}');
  });
}
```

## WebSocket URLs

| Network | URL |
|---------|-----|
| Mainnet | `wss://notifier.multiversx.com` |
| Devnet | `wss://devnet-notifier.multiversx.com` |
| Testnet | `wss://testnet-notifier.multiversx.com` |

## Configuration Options

### Subscribe by Event Identifiers (Recommended)

The cleanest approach with server-side filtering:

```dart
final config = WebSocketEventStreamConfig.byIdentifiers(
  websocketUrl: 'wss://devnet-notifier.multiversx.com',
  identifiers: ['swap', 'deposit', 'withdraw'],
  contractAddress: SmartContractAddress.fromBech32('erd1qqq...'),
  abi: abi,
  autoReconnect: true,
);
```

### Full Configuration

```dart
final config = WebSocketEventStreamConfig(
  websocketUrl: 'wss://devnet-notifier.multiversx.com',
  eventType: WebSocketEventType.byIdentifier,
  eventIdentifiers: ['swap'],
  contractAddress: SmartContractAddress.fromBech32('erd1qqq...'),
  abi: abi,
  headers: {'Api-Key': 'your-api-key'},  // Optional auth headers
  autoReconnect: true,
  reconnectDelay: Duration(milliseconds: 300),
  connectionTimeout: Duration(seconds: 5),
  pingInterval: Duration(seconds: 10),
  enableDeduplication: false,
);
```

## Event Result Structure

Each event includes:

```dart
stream.events.listen((result) {
  // Transaction hash
  print('TX Hash: \${result.txHash}');
  
  // Raw event data
  print('Identifier: \${result.rawEvent.identifier}');
  print('Topics: \${result.rawEvent.topics}');
  print('Data: \${result.rawEvent.data}');
  
  // Parsed event (if ABI provided)
  if (result.parsedEvent != null) {
    final event = result.parsedEvent!;
    print('Event name: \${event.name}');
    print('Fields: \${event.toMap()}');
  }
});
```

## Connection Status

Monitor connection state:

```dart
stream.statusChanges.listen((change) {
  switch (change.status) {
    case WebSocketStatus.idle:
      print('Not connected');
      break;
    case WebSocketStatus.connecting:
      print('Connecting...');
      break;
    case WebSocketStatus.connected:
      print('Connected');
      break;
    case WebSocketStatus.listening:
      print('Listening for events');
      break;
    case WebSocketStatus.disconnected:
      print('Disconnected');
      break;
    case WebSocketStatus.error:
      print('Error occurred');
      break;
  }
});
```

## Error Handling

Handle connection and streaming errors:

```dart
stream.errors.listen((error) {
  print('Error: \${error.message}');
  print('Details: \${error.error}');
});
```

## Reconnection

Auto-reconnect is enabled by default:

```dart
final config = WebSocketEventStreamConfig.byIdentifiers(
  websocketUrl: 'wss://devnet-notifier.multiversx.com',
  identifiers: ['swap'],
  autoReconnect: true,  // default
  reconnectDelay: Duration(milliseconds: 300),
);

final stream = WebSocketEventStream(config);
await stream.connect();

// Stream will automatically reconnect on disconnection
```

## Complete Example

```dart
import 'dart:io';
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  print('=== WebSocket Events Demo ===\n');
  
  // Setup
  final provider = GatewayNetworkProvider.devnet();
  final abiJson = await File('pair.abi.json').readAsString();
  final abi = SmartContractAbi.fromJson(abiJson);
  
  final contractAddress = SmartContractAddress.fromBech32(
    'erd1qqqqqqqqqqqqqpgq...',
  );
  
  // Create WebSocket config
  final config = WebSocketEventStreamConfig.byIdentifiers(
    websocketUrl: 'wss://devnet-notifier.multiversx.com',
    identifiers: ['swap', 'addLiquidity', 'removeLiquidity'],
    contractAddress: contractAddress,
    abi: abi,
    autoReconnect: true,
  );
  
  // Create stream
  final stream = WebSocketEventStream(config);
  
  // Monitor status
  stream.statusChanges.listen((change) {
    print('Status: \${change.status}');
  });
  
  // Handle errors
  stream.errors.listen((error) {
    print('Error: \${error.message}');
  });
  
  // Listen for events
  stream.events.listen((result) {

    print('TX: \${result.txHash}');
    
    if (result.parsedEvent != null) {
      final event = result.parsedEvent!;
      print('Event: \${event.name}');
      
      // Access parsed fields
      final data = event.toMap();
      for (final entry in data.entries) {
        print('  \${entry.key}: \${entry.value}');
      }
    }
  });
  
  // Connect
  print('Connecting to WebSocket...');
  await stream.connect();
  print('Connected! Listening for events...\n');
  
  // Keep running
  await Future.delayed(Duration(minutes: 5));
  
  // Cleanup
  await stream.disconnect();

}
```

## Statistics

Access connection statistics:

```dart
print('Connected at: \${stream.connectedAt}');
print('Events received: \${stream.eventsReceived}');
print('Duplicates filtered: \${stream.duplicatesFiltered}');
print('Last event: \${stream.lastEventTime}');
print('Reconnect attempts: \${stream.reconnectAttempts}');
```

## Closing the Connection

```dart
// Close the WebSocket connection
await stream.disconnect();
```

## Best Practices

- Use `byIdentifiers` to filter events server-side (more efficient)
- Provide the ABI for automatic event parsing into typed Dart objects
- Always call `disconnect()` when done
- Handle errors to prevent crashes
- Auto-reconnect handles temporary disconnections

## Next Steps

- [Network Providers](/docs/network/providers) - REST API access
- [Transaction Tracking](/docs/transactions/transaction-tracking) - Await transactions
- [Smart Contracts](/docs/smart-contracts/overview) - Contract interactions
