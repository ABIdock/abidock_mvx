---
id: interactions
title: Contract Interactions
sidebar_position: 4
description: Execute state-changing smart contract calls on MultiversX with proper gas estimation, signing, and value transfers.
---

# Contract Interactions

Interactions are state-changing calls to smart contract endpoints. They require gas, signing, and are recorded on-chain.

## Basic Interaction Flow

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:io';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('your mnemonic...');
  final networkAccount = await provider.getAccount(account.address);
  
  final abiJson = await File('contract.abi.json').readAsString();
  final abi = SmartContractAbi.fromJson(abiJson);
  
  final controller = SmartContractController(
    contractAddress: SmartContractAddress.fromBech32('erd1qqq...'),
    networkProvider: provider,
    abi: abi,
  );
  
  // 1. Build and sign the transaction
  final tx = await controller.call(
    account: account,
    nonce: networkAccount.nonce,
    endpointName: 'deposit',
    arguments: [],
    options: BaseControllerInput(gasLimit: GasLimit(10000000)),
  );
  
  // 2. Send it
  final txHash = await provider.sendTransaction(tx);
  print('Transaction: $txHash');
  
  // 3. Wait for completion
  final watcher = TransactionWatcher(networkProvider: provider);
  final result = await watcher.awaitCompleted(txHash);
  print('Status: ${result.status.status}');
}
```

## Sending EGLD to Contract

```dart
// Payable endpoint that accepts EGLD
final tx = await controller.call(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'deposit',
  arguments: [],
  value: Balance.fromEgld(1.0),
  options: BaseControllerInput(gasLimit: GasLimit(10000000)),
);
```

## Sending ESDT Tokens

```dart
// Single ESDT payment
final tx = await controller.call(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'stake',
  arguments: [],
  tokenTransfers: [
    TokenTransferValue.fromPrimitives(
      tokenIdentifier: 'USDC-123456',
      amount: BigInt.from(1000000), // 1 USDC (6 decimals)
    ),
  ],
  options: BaseControllerInput(gasLimit: GasLimit(15000000)),
);
```

## Sending NFTs

```dart
// NFT payment
final tx = await controller.call(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'depositNft',
  arguments: [],
  tokenTransfers: [
    TokenTransferValue.fromPrimitives(
      tokenIdentifier: 'MYNFT-abc123',
      nonce: BigInt.from(42),
      amount: BigInt.one,
    ),
  ],
  options: BaseControllerInput(gasLimit: GasLimit(15000000)),
);
```

## Multi-Token Transfers

```dart
// Multiple tokens in one call
final tx = await controller.call(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'addLiquidity',
  arguments: [
    BigInt.from(1000), // slippage
  ],
  tokenTransfers: [
    TokenTransferValue.fromPrimitives(
      tokenIdentifier: 'WEGLD-123456',
      amount: BigInt.parse('500000000000000000'), // 0.5 WEGLD
    ),
    TokenTransferValue.fromPrimitives(
      tokenIdentifier: 'USDC-789012',
      amount: BigInt.from(500000000), // 500 USDC
    ),
  ],
  options: BaseControllerInput(gasLimit: GasLimit(25000000)),
);
```

## With Complex Arguments

Arguments are passed as native Dart values:

```dart
// Struct argument - pass as Map
// Field types determine what native values to use:
// - U32 fields take int
// - U64 fields take int or BigInt
final tx = await controller.call(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'createUser',
  arguments: [
    {
      'name': 'Alice',
      'age': 30, // U32 takes int
    },
  ],
  options: BaseControllerInput(gasLimit: GasLimit(10000000)),
);
```

```dart
// List argument with U64 values
final tx = await controller.call(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'processIds',
  arguments: [
    [BigInt.from(1), BigInt.from(2), BigInt.from(3)], // U64 takes BigInt
  ],
  options: BaseControllerInput(gasLimit: GasLimit(10000000)),
);
```

## Reading Transaction Results

After a transaction completes, parse the results:

```dart
// Wait for transaction
final watcher = TransactionWatcher(networkProvider: provider);
final txOnNetwork = await watcher.awaitCompleted(txHash);

// Check status
if (!txOnNetwork.isSuccessful) {
  print('Failed: ${txOnNetwork.status.status}');
  return;
}

// Parse return values from smart contract results
final scResults = txOnNetwork.smartContractResults;
if (scResults != null) {
  for (final result in scResults) {
    print('Result data: ${result['data']}');
  }
}
```

## Gas Estimation

### Manual Gas Setting

```dart
final tx = await controller.call(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'myFunction',
  arguments: [],
  options: BaseControllerInput(gasLimit: GasLimit(15000000)),
);
```

### Auto Gas Estimation with simulateGas

Use the `simulateGas` helper to estimate gas via network simulation:

```dart
// Step 1: Create transaction with max gas for simulation
final simulationTx = await controller.call(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'myFunction',
  arguments: [],
  options: BaseControllerInput(gasLimit: const GasLimit(600000000)),
);

// Step 2: Estimate gas using simulation
final gasLimit = await simulateGas(simulationTx, provider);

// Step 3: Create final transaction with estimated gas
final tx = await controller.call(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'myFunction',
  arguments: [],
  options: BaseControllerInput(gasLimit: gasLimit),
);
```

:::tip Generated Code
When using `--autogas` with the code generator, this simulation pattern is handled automatically in the generated call functions.
:::

### Common Gas Values

| Operation | Typical Gas |
|-----------|-------------|
| Simple call | 5,000,000 - 10,000,000 |
| Token transfer + call | 10,000,000 - 20,000,000 |
| Complex computation | 20,000,000 - 50,000,000 |
| Multi-transfer call | 20,000,000 - 30,000,000 |

:::tip Gas Buffer
Add 20-30% buffer to estimated gas to handle variations:
```dart
final estimatedGas = 10000000;
final gasWithBuffer = (estimatedGas * 1.3).toInt();
```
:::

## Error Handling

```dart
try {
  final tx = await controller.call(
    account: account,
    nonce: networkAccount.nonce,
    endpointName: 'myFunction',
    arguments: [],
    options: BaseControllerInput(gasLimit: GasLimit(10000000)),
  );
  
  final txHash = await provider.sendTransaction(tx);
  
  final watcher = TransactionWatcher(networkProvider: provider);
  final result = await watcher.awaitCompleted(txHash);
  
  if (!result.isSuccessful) {
    // Parse error from results
    print('Transaction failed: ${result.status.status}');
  }
} on SmartContractException catch (e) {
  print('Contract error: ${e.message}');
} on NetworkException catch (e) {
  print('Network error: ${e.message}');
} on TransactionException catch (e) {
  print('Transaction error: ${e.message}');
}
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:io';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  
  // Load account
  final account = await Account.fromMnemonic('your mnemonic phrase here...');
  final networkAccount = await provider.getAccount(account.address);
  
  print('Sender: ${account.address.bech32}');
  
  // Load ABI
  final abiJson = await File('assets/adder.abi.json').readAsString();
  final abi = SmartContractAbi.fromJson(abiJson);
  
  final controller = SmartContractController(
    contractAddress: SmartContractAddress.fromBech32('erd1qqq...'),
    networkProvider: provider,
    abi: abi,
  );
  
  // Build transaction to call "add" function
  final tx = await controller.call(
    account: account,
    nonce: networkAccount.nonce,
    endpointName: 'add',
    arguments: [BigInt.from(100)],
    options: BaseControllerInput(gasLimit: GasLimit(10000000)),
  );
  
  print('  Function: add');
  print('  Argument: 100');
  print('  Gas: ${tx.gasLimit.value}');
  
  // Send
  final txHash = await provider.sendTransaction(tx);
  print('Sent: $txHash');
  
  // Wait
  final watcher = TransactionWatcher(networkProvider: provider);
  final result = await watcher.awaitCompleted(txHash);
  

  print('Status: ${result.status.status}');
  
  // Query new value
  final newValue = await controller.query(
    endpointName: 'getSum',
    arguments: [],
  );
  
  print('New sum: ${newValue.first}');
}
```

## Next Steps

- [Relayed Transactions](/docs/smart-contracts/relayed-transactions) - Sponsor user gas
- [Transactions](/docs/transactions/overview) - Direct transfers
- [ABI Types](/docs/abi-types/overview) - Type encoding details

## Interactions Without ABI

When you don't have an ABI or prefer manual encoding, use `callRaw()`:

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  
  // Create controller WITHOUT ABI
  final controller = SmartContractController.withoutAbi(
    contractAddress: SmartContractAddress.fromBech32('erd1qqq...'),
    networkProvider: provider,
  );
  
  // Load account
  final account = await Account.fromMnemonic('your mnemonic...');
  final networkAccount = await provider.getAccount(account.address);
  
  // Create transaction with TypedValue arguments
  final tx = await controller.callRaw(
    account: account,
    nonce: networkAccount.nonce,
    endpointName: 'swap',
    arguments: [
      TokenIdentifierValue('WEGLD-abc123'),
      BigUIntValue(BigInt.from(1000000000000000000)),
    ],
    options: BaseControllerInput(gasLimit: GasLimit(15000000)),
  );
  
  // Send transaction
  final txHash = await provider.sendTransaction(tx);
  print('Sent: $txHash');
}
```

### Raw Calls with Token Transfers

Token transfers work the same way with raw calls:

```dart
// ESDT transfer with raw call
final tx = await controller.callRaw(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'stake',
  arguments: [],
  tokenTransfers: [
    TokenTransferValue.fromPrimitives(
      tokenIdentifier: 'STAKE-abc123',
      amount: BigInt.from(1000000),
    ),
  ],
  options: BaseControllerInput(gasLimit: GasLimit(15000000)),
);
```

### When to Use Raw Calls

| Scenario | Approach |
|----------|----------|
| Have ABI file | Use `call()` with native values |
| No ABI available | Use `callRaw()` with TypedValue |
| Working with unknown contracts | Use `callRaw()` |
| Custom argument encoding | Use `callRaw()` |
| Raw bytes as arguments | Use `Uint8List` directly |

### Combining Query and Call Without ABI

```dart
// Controller without ABI
final controller = SmartContractController.withoutAbi(
  contractAddress: pairAddress,
  networkProvider: provider,
);

// Query current state (raw)
final reserves = await controller.queryRaw(
  endpointName: 'getReservesAndTotalSupply',
  arguments: [],
);

// Decode reserves manually
final codec = BinaryCodec.withDefaults();
final firstReserve = codec.decodeTopLevel(
  reserves[0],
  BigUIntType(),
) as BigUIntValue;
print('First reserve: ${firstReserve.value}');

// Execute swap (raw)
final tx = await controller.callRaw(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'swapTokensFixedInput',
  arguments: [
    TokenIdentifierValue('USDC-123456'),
    BigUIntValue(BigInt.one), // minimum amount out
  ],
  tokenTransfers: [
    TokenTransferValue.fromPrimitives(
      tokenIdentifier: 'WEGLD-abc123',
      amount: BigInt.from(1000000000000000000),
    ),
  ],
  options: BaseControllerInput(gasLimit: GasLimit(30000000)),
);
```

:::tip TypedValue Types
Common TypedValue types for raw calls:
- `BigUIntValue(BigInt.from(100))` - unsigned big integers
- `AddressValue.fromBech32('erd1...')` - addresses
- `TokenIdentifierValue('TOKEN-abc123')` - token identifiers
- `BooleanValue(true)` - booleans
- `U64Value(BigInt.from(1000))` - u64 integers
- `BytesValue(Uint8List.fromList([...]))` - raw bytes
:::
