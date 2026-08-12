---
id: loading-abi
title: Loading ABI
sidebar_position: 2
description: Load MultiversX smart contract ABI files from JSON files, strings, or network to enable type-safe contract interactions.
---

# Loading ABI Files

Before interacting with a smart contract, you need to load its ABI definition.

## From JSON File

The most common method - load from a `.abi.json` file:

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:io';

void main() async {
  final jsonContent = await File('assets/my-contract.abi.json').readAsString();
  final abi = SmartContractAbi.fromJson(jsonContent);
  
  print('Contract: ${abi.name}');
  print('Endpoints: ${abi.endpoints.length}');
}
```

## From JSON String

Load from a JSON string (useful for embedded ABIs):

```dart
void main() async {
  final jsonString = '''
  {
    "name": "MyContract",
    "endpoints": [
      {
        "name": "getValue",
        "mutability": "readonly",
        "inputs": [],
        "outputs": [{"type": "u64"}]
      }
    ]
  }
  ''';
  
  final abi = SmartContractAbi.fromJson(jsonString);
  print('Loaded: ${abi.name}');
}
```

## From Map

Load from a decoded JSON map:

```dart
import 'dart:convert';

void main() async {
  final jsonMap = jsonDecode(abiJsonString) as Map<String, dynamic>;
  final abi = SmartContractAbi.fromMap(jsonMap);
}
```

## Inspecting the ABI

Once loaded, explore the contract's interface:

### List All Endpoints

```dart
void main() async {
  final jsonContent = await File('contract.abi.json').readAsString();
  final abi = SmartContractAbi.fromJson(jsonContent);
  
  print('Endpoints:');
  for (final endpoint in abi.endpoints) {
    print('  ${endpoint.name}');
    print('    Is View: ${endpoint.isView}');
    print('    Inputs: ${endpoint.inputs.length}');
    print('    Outputs: ${endpoint.outputs.length}');
  }
}
```

### Find Specific Endpoint

```dart
void main() async {
  final jsonContent = await File('contract.abi.json').readAsString();
  final abi = SmartContractAbi.fromJson(jsonContent);
  
  // Find by name
  final endpoint = abi.endpoints.getByName('deposit');
  
  if (endpoint != null) {
    print('Found: ${endpoint.name}');
    print('Payable: ${endpoint.payableInTokens}');
  }
}
```

### List Custom Types

```dart
void main() async {
  final jsonContent = await File('contract.abi.json').readAsString();
  final abi = SmartContractAbi.fromJson(jsonContent);
  
  print('Custom Types:');
  for (final entry in abi.types.entries) {
    print('  ${entry.key}: ${entry.value}');
  }
}
```

## ABI Structure

A complete ABI contains:

```dart
final class SmartContractAbi {
  final String name;                    // Contract name
  final String version;                 // ABI version
  final AbiEndpoint? constructor;       // Deploy constructor
  final AbiEndpoint? upgradeConstructor; // Upgrade constructor
  final AbiEndpoints endpoints;         // All endpoints
  final EventDefinitions events;        // Event definitions
  final Map<String, AbiType> types;     // Custom types
  final Map<String, dynamic> metadata;  // Raw `buildInfo` / `docs` blocks
}
```

### Endpoint Definition

```dart
class AbiEndpoint {
  final String name;                    // Function name
  final InputParameters inputs;         // Input parameters
  final OutputParameters outputs;       // Return values
  final List<String> payableInTokens;   // Accepted tokens ('*' = any)
  final bool isView;                    // Whether read-only (view)
  final bool isOnlyOwner;               // Whether owner-only
  final bool isOnlyAdmin;               // Whether admin-only
  final String? mutability;             // 'readonly' | 'mutable' | 'pure'
  final List<String> labels;            // Endpoint labels from the ABI
  final String? documentation;          // Optional docs
}
```

`isPayable` is derived (`payableInTokens.isNotEmpty`), and `isReadonly` / `isPure` read the
`mutability` string.

### Collection Types

All collection types (`AbiEndpoints`, `InputParameters`, `OutputParameters`, `EventDefinitions`) extend `Iterable`, enabling clean functional-style operations:

```dart
// Direct iteration
for (final endpoint in abi.endpoints) { ... }

// Functional operations
final views = abi.endpoints.where((e) => e.isView);
final names = abi.endpoints.map((e) => e.name);
final first = abi.endpoints.first;
final count = abi.endpoints.length;

// Same for parameters
for (final param in endpoint.inputs) { ... }
final paramNames = endpoint.outputs.map((o) => o.name);
```

## Working with Generated Code

For type-safe interactions, generate code from the ABI:

```bash
# First install the CLI (one-time)
dart pub global activate abidock_mvx

# Then generate
abidock assets/my-contract.abi.json lib/generated/my-contract MyContract --full
```

Then use the generated contract class:

```dart
import 'lib/generated/my-contract/my_contract.dart';

void main() async {
  // Type-safe, no manual ABI loading needed
  final contract = MyContractController(
    contractAddress: 'erd1...',
    networkProvider: provider,
  );
  
  final value = await contract.getValue();
}
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:io';

void main() async {
  // Load ABI
  final jsonContent = await File('assets/pair.abi.json').readAsString();
  final abi = SmartContractAbi.fromJson(jsonContent);
  
  print('=== ABI Inspector ===\n');
  print('Contract: ${abi.name}');
  print('');
  
  // List views (readonly)
  final views = abi.endpoints.viewEndpoints;
  print('Views (${views.length}):');
  for (final view in views.take(5)) {
    final outputs = view.outputs.map((o) => o.type).join(', ');
    print('  ${view.name}() -> $outputs');
  }
  if (views.length > 5) {
    print('  ... and ${views.length - 5} more');
  }
  print('');
  
  // List mutable endpoints (non-view endpoints)
  final mutableEndpoints = abi.endpoints
      .where((e) => !e.isView)
      .toList();
  
  print('Mutable Endpoints (${mutableEndpoints.length}):');
  for (final endpoint in mutableEndpoints.take(5)) {
    final inputs = endpoint.inputs.map((i) => '${i.name}: ${i.type}').join(', ');
    print('  ${endpoint.name}($inputs)');
  }
  if (mutableEndpoints.length > 5) {
    print('  ... and ${mutableEndpoints.length - 5} more');
  }
  print('');
  
  // List custom types
  print('Custom Types (${abi.types.length}):');
  for (final entry in abi.types.entries.take(5)) {
    print('  ${entry.key} (${entry.value.runtimeType})');
  }
  if (abi.types.length > 5) {
    print('  ... and ${abi.types.length - 5} more');
  }
}
```

## Working Without ABI

:::tip ABI is Optional
You don't always need an ABI file! The SDK supports interactions without ABI using `TypedValue` arguments and raw byte responses.
:::

```dart
// No ABI needed - use withoutAbi() constructor
final controller = SmartContractController.withoutAbi(
  contractAddress: SmartContractAddress.fromBech32('erd1qqq...'),
  networkProvider: provider,
);

// Query returns raw bytes
final result = await controller.queryRaw(
  endpointName: 'getBalance',
  arguments: [AddressValue.fromBech32('erd1user...')],
);

// Call with TypedValue arguments
final tx = await controller.callRaw(
  account: account,
  nonce: nonce,
  endpointName: 'transfer',
  arguments: [
    AddressValue.fromBech32('erd1recipient...'),
    BigUIntValue(amount),
  ],
  options: BaseControllerInput(gasLimit: GasLimit(10000000)),
);
```

See [Queries](/docs/smart-contracts/queries#raw-queries-without-abi) and [Interactions](/docs/smart-contracts/interactions#interactions-without-abi) for complete details on ABI-less usage.

## Next Steps

- [Queries](/docs/smart-contracts/queries) - Read data using views
- [Interactions](/docs/smart-contracts/interactions) - Call mutable endpoints
- [ABI Types](/docs/abi-types/overview) - Understand the type system
