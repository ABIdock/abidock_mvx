---
id: quick-start
title: Quick Start
sidebar_position: 2
description: Create accounts, connect to networks, query balances, and send transactions.
---

# Quick Start

Basic examples to get up and running.

## Create an Account

The most common way to create an account is from a mnemonic phrase:

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  // Generate a new mnemonic
  final mnemonic = Mnemonic.generate();
  final words = mnemonic.getWords();
  print('Save this mnemonic securely: ${words.join(' ')}');
  
  // Create account from mnemonic
  final account = await Account.fromMnemonic(words.join(' '));
  
  print('Address: ${account.address.bech32}');
  
  // Clean up
  mnemonic.dispose();
}
```

:::caution Important
Never share your mnemonic phrase or commit it to source control. Anyone with your mnemonic can access your funds.
:::

## Check Account Balance

Connect to a network and check your balance:

```dart
void main() async {
  // Create provider for devnet
  final provider = GatewayNetworkProvider.devnet();
  
  // Get account info
  final accountInfo = await provider.getAccount(
    Address.fromBech32('erd1...your-address...'),
  );
  
  print('Balance: ${accountInfo.balance.value}');
  print('Nonce: ${accountInfo.nonce.value}');
}
```

## Send EGLD

Send EGLD to another address:

```dart
import 'dart:typed_data';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('your mnemonic...');
  
  // Get network config for chain ID
  final networkConfig = await provider.getNetworkConfig();
  
  // Get current nonce
  final accountInfo = await provider.getAccount(account.address);
  
  // Create transfer transaction
  final transaction = Transaction(
    sender: account.address,
    receiver: Address.fromBech32('erd1...recipient...'),
    value: Balance.fromEgld(1.0),
    nonce: accountInfo.nonce,
    gasLimit: GasLimit(50000),
    gasPrice: GasPrice(1000000000),
    chainId: ChainId(networkConfig.chainId),
    version: TransactionVersion(1),
    data: Uint8List(0),
  );
  
  // Sign the transaction
  final signature = await account.signTransaction(transaction);
  final signedTx = transaction.copyWith(
    newSignature: Signature.fromUint8List(signature),
  );
  
  // Send it!
  final txHash = await provider.sendTransaction(signedTx);
  print('Transaction sent: $txHash');
}
```

## Query a Smart Contract

Read data from a smart contract:

```dart
import 'dart:io';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  
  // Load the contract ABI
  final abiJson = await File('my-contract.abi.json').readAsString();
  final abi = SmartContractAbi.fromJson(abiJson);
  
  // Create controller
  final controller = SmartContractController(
    contractAddress: SmartContractAddress.fromBech32('erd1qqq...contract...'),
    networkProvider: provider,
    abi: abi,
  );
  
  // Query a view function
  final result = await controller.query(
    endpointName: 'getTotalSupply',
    arguments: [],
  );
  
  // Parse the result
  final totalSupply = result.first;
  print('Total Supply: $totalSupply');
}
```

## Call a Smart Contract

Execute a state-changing function:

```dart
import 'dart:io';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('your mnemonic...');
  final networkAccount = await provider.getAccount(account.address);
  
  final abiJson = await File('my-contract.abi.json').readAsString();
  final abi = SmartContractAbi.fromJson(abiJson);
  
  final controller = SmartContractController(
    contractAddress: SmartContractAddress.fromBech32('erd1qqq...contract...'),
    networkProvider: provider,
    abi: abi,
  );
  
  // Build the transaction
  final transaction = await controller.call(
    account: account,
    nonce: networkAccount.nonce,
    endpointName: 'deposit',
    arguments: [],
    value: Balance.fromEgld(1.0),
    options: BaseControllerInput(gasLimit: GasLimit(10000000)),
  );
  
  // Send the signed transaction
  final txHash = await provider.sendTransaction(transaction);
  print('Transaction: $txHash');
  
  // Wait for completion
  final watcher = TransactionWatcher(networkProvider: provider);
  final txOnNetwork = await watcher.awaitCompleted(txHash);
  
  print('Status: ${txOnNetwork.status.status}');
}
```

## Use Generated Code

For type-safe interactions, use the code generator:

```bash
# First install the CLI (one-time)
dart pub global activate abidock_mvx

# Generate code from ABI
abidock assets/my-contract.abi.json lib/generated/my-contract MyContract --full
```

Then use the generated code:

```dart
import 'package:my_app/generated/my_contract/my_contract.dart';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  
  // Generated controller takes contract address in constructor
  final contract = MyContractController(
    contractAddress: 'erd1qqq...',
    networkProvider: provider,
  );
  
  // Type-safe query with proper return types
  final totalSupply = await contract.getTotalSupply();
  
  print('Total Supply: $totalSupply');
}
```

## Next Steps

Now that you have the basics, explore more:

- [Wallet Management](/docs/wallet/overview) - Advanced wallet features
- [Transactions](/docs/transactions/overview) - ESDT, NFT, and multi-transfers
- [Smart Contracts](/docs/smart-contracts/overview) - Contract interactions
- [ABI Types](/docs/abi-types/overview) - Understanding the type system
- [Code Generation](/docs/codegen/overview) - Generate type-safe code
