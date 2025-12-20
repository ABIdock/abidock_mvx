---
id: configuration
title: Configuration
sidebar_position: 3
description: Configure abidock_mvx for Mainnet, Devnet, Testnet, or custom MultiversX networks with built-in providers.
---

# Configuration

Configure abidock_mvx for your application.

## Network Configuration

### Built-in Networks

abidock_mvx provides pre-configured providers for all MultiversX networks:

```dart
// Mainnet (production)
final mainnet = GatewayNetworkProvider.mainnet();

// Devnet (development)
final devnet = GatewayNetworkProvider.devnet();

// Testnet (testing)
final testnet = GatewayNetworkProvider.testnet();
```

### Custom Network

Connect to a custom gateway:

```dart
final provider = GatewayNetworkProvider(
  baseUrl: 'https://my-gateway.example.com',
  chainId: ChainId('D'),  // Required: specify the chain
);
```

### API Provider

Use the MultiversX API instead of the Gateway:

```dart
final apiProvider = ApiNetworkProvider.devnet();

// Or custom URL
final customApi = ApiNetworkProvider(
  baseUrl: 'https://api.multiversx.com',
  chainId: ChainId('1'),  // Required: specify the chain
);
```

## Network Parameters

Get network configuration for transactions:

```dart
final provider = GatewayNetworkProvider.devnet();
final config = await provider.getNetworkConfig();

print('Chain ID: ${config.chainId}');
print('Min Gas Limit: ${config.minGasLimit}');
print('Min Gas Price: ${config.minGasPrice}');
print('Gas Per Data Byte: ${config.gasPerDataByte}');
```

## Gas Configuration

### Manual Gas Setting

Set gas directly:

```dart
final controller = SmartContractController(
  contractAddress: contractAddress,
  abi: abi,
  networkProvider: provider,
);

// Set gas limit directly
final transaction = await controller.call(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'myFunction',
  arguments: [arg1, arg2],
  options: BaseControllerInput(gasLimit: GasLimit(15000000)),
);
```

### Automatic Gas Estimation

Use `simulateGas` helper to estimate gas:

```dart
// Create transaction with max gas for simulation
final simulationTx = await controller.call(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'myFunction',
  arguments: [arg1, arg2],
  options: BaseControllerInput(gasLimit: const GasLimit(600000000)),
);

// Estimate gas using simulation
final gasLimit = await simulateGas(simulationTx, provider);

// Create final transaction with estimated gas
final transaction = await controller.call(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'myFunction',
  arguments: [arg1, arg2],
  options: BaseControllerInput(gasLimit: gasLimit),
);
```

### Gas Constants

Common gas values:

| Operation | Typical Gas |
|-----------|-------------|
| EGLD Transfer | 50,000 |
| ESDT Transfer | 500,000 |
| NFT Transfer | 1,000,000 |
| Simple Contract Call | 5,000,000 - 10,000,000 |
| Complex Contract Call | 10,000,000 - 50,000,000 |

## Timeout Configuration

Configure request timeouts via the Dio client:

```dart
import 'package:dio/dio.dart';

final dio = Dio(BaseOptions(
  connectTimeout: Duration(seconds: 30),
  receiveTimeout: Duration(seconds: 30),
));

final provider = GatewayNetworkProvider(
  baseUrl: 'https://devnet-gateway.multiversx.com',
  chainId: ChainId('D'),
  client: dio,
);
```

## Transaction Watcher Configuration

Configure transaction monitoring:

```dart
final watcher = TransactionWatcher(networkProvider: provider);

// Wait with custom options
const options = TransactionAwaitingOptions(
  timeout: Duration(minutes: 5),
  pollingInterval: Duration(seconds: 3),
);

final result = await watcher.awaitCompleted(txHash, options: options);

// Always close when done
watcher.close();
```

## Environment-Based Configuration

Example of environment-based setup:

```dart
GatewayNetworkProvider getProvider() {
  final env = Platform.environment['NETWORK'] ?? 'devnet';
  
  switch (env) {
    case 'mainnet':
      return GatewayNetworkProvider.mainnet();
    case 'testnet':
      return GatewayNetworkProvider.testnet();
    case 'devnet':
    default:
      return GatewayNetworkProvider.devnet();
  }
}
```

## Flutter Configuration

For Flutter apps, consider using a provider pattern:

```dart
class MultiversXService {
  late final GatewayNetworkProvider provider;
  late final NetworkConfig networkConfig;
  
  Future<void> initialize({bool isProduction = false}) async {
    provider = isProduction
        ? GatewayNetworkProvider.mainnet()
        : GatewayNetworkProvider.devnet();
    
    networkConfig = await provider.getNetworkConfig();
  }
  
  // Use throughout your app
  String get chainId => networkConfig.chainId;
}
```

## Next Steps

- [Wallet Management](/docs/wallet/overview) - Set up wallets
- [Transactions](/docs/transactions/overview) - Send transactions
- [Network Providers](/docs/network/providers) - Advanced provider configuration
