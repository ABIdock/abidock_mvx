---
id: network-configuration
title: Network Configuration
sidebar_position: 2
description: Configure MultiversX network connections for Mainnet, Devnet, Testnet with chain IDs and custom endpoints.
---

# Network Configuration

Configure your application for different MultiversX networks.

## Available Networks

| Network | Chain ID | Purpose |
|---------|----------|---------|
| **Mainnet** | `1` | Production |
| **Devnet** | `D` | Development & Testing |
| **Testnet** | `T` | Testing |

## Quick Configuration

```dart
// Devnet for development
final devnet = GatewayNetworkProvider.devnet();

// Mainnet for production
final mainnet = GatewayNetworkProvider.mainnet();

// Testnet
final testnet = GatewayNetworkProvider.testnet();
```

## Network URLs

### Gateway URLs

| Network | URL |
|---------|-----|
| Mainnet | `https://gateway.multiversx.com` |
| Devnet | `https://devnet-gateway.multiversx.com` |
| Testnet | `https://testnet-gateway.multiversx.com` |

### API URLs

| Network | URL |
|---------|-----|
| Mainnet | `https://api.multiversx.com` |
| Devnet | `https://devnet-api.multiversx.com` |
| Testnet | `https://testnet-api.multiversx.com` |

## Network Configuration Object

Get dynamic network configuration:

```dart
final provider = GatewayNetworkProvider.devnet();
final config = await provider.getNetworkConfig();

print('Chain ID: ${config.chainId}');
print('Min gas price: ${config.minGasPrice}');
print('Min gas limit: ${config.minGasLimit}');
print('Gas per data byte: ${config.gasPerDataByte}');
print('Denomination: ${config.denomination}');
print('Rounds per epoch: ${config.roundsPerEpoch}');
```

### NetworkConfig Fields

| Field | Type | Description |
|-------|------|-------------|
| `chainId` | `String` | Network identifier (1, D, T) |
| `minGasPrice` | `int` | Minimum gas price per unit |
| `minGasLimit` | `int` | Minimum gas limit for transactions |
| `gasPerDataByte` | `int` | Gas cost per byte of data |
| `gasCostPerMovedBalanceByte` | `int` | Gas for balance transfers |
| `numShards` | `int` | Number of shards in the network |
| `roundDuration` | `int` | Duration of a round in milliseconds |
| `roundsPerEpoch` | `int` | Rounds in each epoch |
| `denomination` | `int` | Token denomination (18 for EGLD) |
| `topUpFactor` | `double` | Top-up factor for staking rewards |
| `gasPriceModifier` | `String` | Gas price adjustment modifier |
| `adaptivity` | `bool` | Whether adaptivity is enabled |
| `hysteresis` | `String` | Hysteresis value for consensus |

## Environment-Based Configuration

```dart
enum Environment { development, staging, production }

class AppConfig {
  final Environment environment;
  
  AppConfig(this.environment);
  
  GatewayNetworkProvider get provider {
    switch (environment) {
      case Environment.development:
        return GatewayNetworkProvider.devnet();
      case Environment.staging:
        return GatewayNetworkProvider.testnet();
      case Environment.production:
        return GatewayNetworkProvider.mainnet();
    }
  }
  
  String get explorerUrl {
    switch (environment) {
      case Environment.development:
        return 'https://devnet-explorer.multiversx.com';
      case Environment.staging:
        return 'https://testnet-explorer.multiversx.com';
      case Environment.production:
        return 'https://explorer.multiversx.com';
    }
  }
}

// Usage
final config = AppConfig(Environment.development);
final provider = config.provider;
```

## Configuration from Environment Variables

```dart
import 'dart:io';

GatewayNetworkProvider createProvider() {
  final network = Platform.environment['MVX_NETWORK'] ?? 'devnet';
  
  switch (network.toLowerCase()) {
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

## Gas Configuration

### Default Gas Values

```dart
class GasConfig {
  static const egldTransfer = 50000;
  static const esdtTransfer = 500000;
  static const nftTransfer = 1000000;
  static const multiTransfer = 1100000;
  static const scCallBase = 5000000;
  
  static int forMultiTransfer(int tokenCount) {
    return multiTransfer + (tokenCount * 100000);
  }
  
  static int forScCall({
    required int argumentCount,
    int complexity = 1,
  }) {
    return scCallBase * complexity + (argumentCount * 50000);
  }
}
```

### Dynamic Gas Calculation

```dart
int calculateGas({
  required NetworkConfig config,
  required String data,
  required int baseGas,
}) {
  final dataGas = data.length * config.gasPerDataByte;
  return baseGas + dataGas;
}
```

## Token Identifiers by Network

Wrapped EGLD and common tokens differ per network:

```dart
class Tokens {
  static const mainnet = _MainnetTokens();
  static const devnet = _DevnetTokens();
  
  static TokenConfig forNetwork(String chainId) {
    switch (chainId) {
      case '1':
        return mainnet;
      case 'D':
        return devnet;
      default:
        throw ArgumentError('Unknown network: $chainId');
    }
  }
}

class _MainnetTokens implements TokenConfig {
  const _MainnetTokens();
  
  @override
  String get wegld => 'WEGLD-bd4d79';
  
  @override
  String get usdc => 'USDC-c76f1f';
  
  @override
  String get mex => 'MEX-455c57';
}

class _DevnetTokens implements TokenConfig {
  const _DevnetTokens();
  
  @override
  String get wegld => 'WEGLD-a28c59';
  
  @override  
  String get usdc => 'USDC-8d4068';
  
  @override
  String get mex => 'MEX-dc289c';
}

abstract class TokenConfig {
  String get wegld;
  String get usdc;
  String get mex;
}
```

## Complete Configuration Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:io';

/// Application configuration
class Config {
  final String network;
  final GatewayNetworkProvider provider;
  final String chainId;
  final String explorerUrl;
  final TokenConfig tokens;
  
  Config._({
    required this.network,
    required this.provider,
    required this.chainId,
    required this.explorerUrl,
    required this.tokens,
  });
  
  static Future<Config> load() async {
    final network = Platform.environment['MVX_NETWORK'] ?? 'devnet';
    
    late GatewayNetworkProvider provider;
    late String chainId;
    late String explorerUrl;
    late TokenConfig tokens;
    
    switch (network.toLowerCase()) {
      case 'mainnet':
        provider = GatewayNetworkProvider.mainnet();
        chainId = '1';
        explorerUrl = 'https://explorer.multiversx.com';
        tokens = Tokens.mainnet;
        break;
      case 'testnet':
        provider = GatewayNetworkProvider.testnet();
        chainId = 'T';
        explorerUrl = 'https://testnet-explorer.multiversx.com';
        tokens = Tokens.devnet; // Use devnet tokens
        break;
      case 'devnet':
      default:
        provider = GatewayNetworkProvider.devnet();
        chainId = 'D';
        explorerUrl = 'https://devnet-explorer.multiversx.com';
        tokens = Tokens.devnet;
    }
    
    // Verify connection
    final config = await provider.getNetworkConfig();
    assert(config.chainId == chainId);
    
    return Config._(
      network: network,
      provider: provider,
      chainId: chainId,
      explorerUrl: explorerUrl,
      tokens: tokens,
    );
  }
  
  String txUrl(String hash) => '$explorerUrl/transactions/$hash';
  String addressUrl(String address) => '$explorerUrl/accounts/$address';
}

// Usage
void main() async {
  final config = await Config.load();
  
  print('Network: ${config.network}');
  print('Chain ID: ${config.chainId}');
  print('WEGLD: ${config.tokens.wegld}');
}
```

## Next Steps

- [Network Providers](/docs/network/providers) - Provider setup
- [WebSocket Events](/docs/network/websocket-events) - Real-time updates
- [Transactions](/docs/transactions/overview) - Sending transactions
