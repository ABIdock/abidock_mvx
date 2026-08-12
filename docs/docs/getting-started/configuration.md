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

:::tip
To configure a provider **and** the factories and controllers that go with it
in one step, use an [entrypoint](/docs/network/entrypoints):
`DevnetEntrypoint()`, `MainnetEntrypoint()`, `TestnetEntrypoint()`, or their
`*ProxyEntrypoint` Gateway counterparts.
:::

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

Use `simulateGas` helper to estimate gas. Build an **unsigned** probe so the
final signed transaction is signed exactly once -- mutating `gasLimit` on a
signed transaction invalidates its signature.

```dart
// Build an unsigned probe via the factory.
final factory = SmartContractCallFactory(
  contractAddress: controller.contractAddress,
  abi: controller.abi,
  chainId: controller.networkProvider.chainId,
);
final probeTx = factory.createCall(
  sender: account.address,
  nonce: networkAccount.nonce,
  endpointName: 'myFunction',
  arguments: [arg1, arg2],
  gasLimit: const GasLimit(600000000),
);

// Estimate gas using simulation.
final gasLimit = await simulateGas(probeTx, provider);

// Sign once with the final gas limit.
final transaction = await controller.call(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'myFunction',
  arguments: [arg1, arg2],
  options: BaseControllerInput(gasLimit: gasLimit),
);
```

### Gas Constants

Transfer factories compute the limit as
`minGasLimit + gasLimitPerByte * data.length + execution gas`, using the
defaults on `TransactionsFactoryConfig`:

| Component | Default | Applies to |
|-----------|---------|------------|
| `minGasLimit` | 50,000 | Every transaction |
| `gasLimitPerByte` | 1,500 | Each byte of the `data` field |
| `gasLimitEsdtTransfer` | 200,000 | `ESDTTransfer` |
| `gasLimitEsdtNftTransfer` | 200,000 | `ESDTNFTTransfer` |
| `gasLimitMultiEsdtNftTransfer` | 200,000 | `MultiESDTNFTTransfer` |

So a plain EGLD transfer with no data costs 50,000, and an ESDT transfer with
a 60-byte data field costs `50,000 + 1,500 * 60 + 200,000`.

Contract calls have no fixed number — estimate them with `simulateGas`, or set
a limit you know covers the endpoint.

## Timeout Configuration

The short path is `NetworkProviderConfig.requestTimeout`, which maps onto the
Dio connect, receive, and send timeouts at once:

```dart
final provider = GatewayNetworkProvider(
  baseUrl: 'https://devnet-gateway.multiversx.com',
  chainId: const ChainId('D'),
  config: const NetworkProviderConfig(
    requestTimeout: Duration(seconds: 30),
  ),
);
```

Need finer control (interceptors, proxies, a custom adapter)? Pass your own
`Dio` client instead:

```dart
import 'package:dio/dio.dart';

final dio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 30),
  receiveTimeout: const Duration(seconds: 30),
));

final provider = GatewayNetworkProvider(
  baseUrl: 'https://devnet-gateway.multiversx.com',
  chainId: const ChainId('D'),
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
