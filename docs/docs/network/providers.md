---
id: providers
title: Network Providers
sidebar_position: 1
description: Connect to MultiversX blockchain using Gateway or API network providers for transactions and data queries.
---

# Network Providers

Network providers connect your application to the MultiversX blockchain. Two providers are available for different use cases.

## Provider Comparison

| Feature | GatewayNetworkProvider | ApiNetworkProvider |
|---------|----------------------|-------------------|
| **Best for** | Transaction submission, real-time data | Historical data, token queries, indexing |
| **Base URL** | `gateway.multiversx.com` | `api.multiversx.com` |
| **Response format** | Wrapped in data envelope | Direct JSON responses |
| **Token metadata** | Basic token data | Extended metadata (price, supply, etc.) |
| **Account data** | Core fields | Extended fields (shard, txCount, etc.) |
| **Transaction data** | Core fields | Extended fields (action, operations, etc.) |
| **Economics data** | ❌ Not supported | ✅ Full support |

## GatewayNetworkProvider

The gateway provider connects to MultiversX Gateway nodes:

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

final mainnet = GatewayNetworkProvider.mainnet();
final devnet = GatewayNetworkProvider.devnet();
final testnet = GatewayNetworkProvider.testnet();

final custom = GatewayNetworkProvider(
  baseUrl: 'https://gateway.multiversx.com',
  chainId: ChainId('1'),
);
```

## ApiNetworkProvider

The API provider connects to the MultiversX API (indexer):

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

final mainnet = ApiNetworkProvider.mainnet();
final devnet = ApiNetworkProvider.devnet();
final testnet = ApiNetworkProvider.testnet();

final custom = ApiNetworkProvider(
  baseUrl: 'https://api.multiversx.com',
  chainId: ChainId('1'),
);
```

**When to use ApiNetworkProvider:**
- Querying token prices and market data
- Getting detailed account statistics (transaction count, shard)
- Fetching historical transaction data with full details
- Building explorer-style applications

## Available Operations

### Account Operations

```dart
final provider = GatewayNetworkProvider.devnet();

// Get account info
final account = await provider.getAccount(address);
print('Balance: ${account.balance.toDenominatedTrimmed} EGLD');
print('Nonce: ${account.nonce.value}');

// Get ESDT tokens
final tokens = await provider.getFungibleTokensOfAccount(address);

// Get specific token
final token = await provider.getTokenOfAccount(address, 'WEGLD-bd4d79');

// Get NFTs
final nfts = await provider.getNonFungibleTokensOfAccount(address);
```

### Account Storage

Read smart contract storage directly:

```dart
// Get all storage entries
final storage = await provider.getAccountStorage(contractAddress);
for (final entry in storage.entries) {
  print('${entry.key}: ${entry.value}');
}

// Get specific storage entry
final entry = await provider.getAccountStorageEntry(
  contractAddress,
  'storage_key_hex',
);
print('Value: ${entry.value}');

// Check if key exists
if (storage.hasKey('some_key')) {
  final value = storage.getEntry('some_key')?.value;
}
```

### Transaction Operations

```dart
// Send transaction
final hash = await provider.sendTransaction(signedTx);

// Get transaction details
final tx = await provider.getTransaction(hash);

// Get transaction status
final status = await provider.getTransactionStatus(hash);
```

`tx.smartContractResults` is a typed `List<SmartContractResult>?`. Each entry
eagerly decodes its `@<returnCode>@<returnData>...` payload — pattern-match on
`returnCode.isSuccess` / `returnData` rather than re-parsing hex by hand.

### Token Metadata

```dart
// API provider only — Gateway throws UnsupportedError.
final api = ApiNetworkProvider.mainnet();

final usdc = await api.getDefinitionOfFungibleToken('USDC-c76f1f');
print('Ticker: ${usdc.ticker}  decimals: ${usdc.decimals}');

final collection = await api.getDefinitionOfTokenCollection('APES-abcdef');
print('Type: ${collection.type}  owner: ${collection.owner}');

final nft = await api.getNonFungibleToken('APES-abcdef', 42);
print('Owner: ${nft.owner}  uris: ${nft.uris.length}');
```

### Block Queries

```dart
// Both providers.
final block = await provider.getBlock(someBlockHash);
final latestShard1 = await provider.getLatestBlock(shard: 1);
print('Shard ${block.shard} · nonce ${block.nonce} · ${block.numTxs} txs');

// Gateway-only: hyperblocks (cross-shard finalized blocks).
final gateway = GatewayNetworkProvider.mainnet();
final hb = await gateway.getHyperblock(12345);
for (final tx in hb.transactionHashes) {
  // ...
}
```

### Network Operations

```dart
// Network configuration
final config = await provider.getNetworkConfig();
print('Chain ID: ${config.chainId}');
print('Min gas price: ${config.minGasPrice}');
print('Gas per byte: ${config.gasPerDataByte}');

// Network status
final status = await provider.getNetworkStatus();
print('Current round: ${status.currentRound}');
print('Epoch: ${status.epochNumber}');
print('Nonce: ${status.nonce}');

// Network economics (API provider only)
final economics = await apiProvider.getNetworkEconomics();
print('Total Supply: ${economics.totalSupply} EGLD');
print('Staked: ${economics.staked} EGLD');
print('Price: \$${economics.price}');
print('APR: ${(economics.apr * 100).toStringAsFixed(2)}%');
```

:::note
The `getNetworkEconomics()` method is only available on `ApiNetworkProvider`. 
Gateway does not support this endpoint and will throw `UnsupportedError`.
:::

### Smart Contract Queries

For smart contract queries, use `SmartContractController` instead:

```dart
// Use SmartContractController for type-safe queries
final controller = SmartContractController(
  contractAddress: SmartContractAddress.fromBech32('erd1qqq...'),
  networkProvider: provider,
  abi: abi,
);

final result = await controller.query(
  endpointName: 'getTokenPrice',
  arguments: ['WEGLD-bd4d79'],
);
```

## Provider Configuration

### Custom HTTP Client

```dart
import 'package:http/http.dart' as http;

final customClient = http.Client();

final provider = GatewayNetworkProvider(
  baseUrl: 'https://devnet-gateway.multiversx.com',
  chainId: ChainId('D'),
);
```

### Timeout Configuration

```dart
final provider = GatewayNetworkProvider(
  baseUrl: 'https://gateway.multiversx.com',
  chainId: ChainId('1'),
);
```

## Multiple Providers

Use different providers for different purposes:

```dart
class MultiProvider {
  final GatewayNetworkProvider primary;
  final GatewayNetworkProvider fallback;
  
  MultiProvider({
    required this.primary,
    required this.fallback,
  });
  
  Future<T> query<T>(Future<T> Function(GatewayNetworkProvider) fn) async {
    try {
      return await fn(primary);
    } catch (e) {
      print('Primary failed, trying fallback...');
      return await fn(fallback);
    }
  }
}

// Usage
final multi = MultiProvider(
  primary: GatewayNetworkProvider(
    baseUrl: 'https://gateway.multiversx.com',
    chainId: ChainId('1'),
  ),
  fallback: GatewayNetworkProvider(
    baseUrl: 'https://backup-gateway.example.com',
    chainId: ChainId('1'),
  ),
);

final account = await multi.query((p) => p.getAccount(address));
```

## API Endpoints

### Gateway Endpoints

| Operation | Endpoint |
|-----------|----------|
| Get account | `/address/{address}` |
| Get tokens | `/address/{address}/esdt` |
| Get NFTs | `/address/{address}/nft` |
| Send transaction | `/transaction/send` |
| Get transaction | `/transaction/{hash}` |
| Network config | `/network/config` |
| VM query | `/vm-values/query` |

### API Endpoints

| Operation | Endpoint |
|-----------|----------|
| Get account | `/accounts/{address}` |
| Get tokens | `/accounts/{address}/tokens` |
| Get NFTs | `/accounts/{address}/nfts` |
| Send transaction | `/transactions` |
| Get transaction | `/transactions/{hash}` |
| Network config | `/economics` + `/constants` |
| Network economics | `/economics` |

## Response Models

### AccountOnNetwork

Account information returned by `getAccount()`:

| Field | Type | Description |
|-------|------|-------------|
| `address` | `Address` | Account address |
| `balance` | `Balance` | EGLD balance |
| `nonce` | `Nonce` | Transaction counter |
| `shard` | `int` | Account's shard (API only) |
| `txCount` | `int?` | Total transaction count (API only) |
| `scrCount` | `int?` | Smart contract result count (API only) |
| `ownerAddress` | `String?` | Contract owner (for smart contracts) |
| `deployedAt` | `int?` | Deployment timestamp (for smart contracts) |
| `assets` | `Map?` | Account assets/metadata (API only) |

### TransactionOnNetwork

Transaction information returned by `getTransaction()`:

| Field | Type | Description |
|-------|------|-------------|
| `txHash` | `String` | Transaction hash |
| `transaction` | `Transaction` | Original transaction details |
| `status` | `TransactionStatus` | Current status |
| `timestamp` | `int` | Unix timestamp |
| `gasUsed` | `int` | Gas consumed |
| `fee` | `String` | Total fee paid |
| `senderShard` | `int?` | Sender's shard |
| `receiverShard` | `int?` | Receiver's shard |
| `logs` | `TransactionLogs?` | Event logs |
| `smartContractResults` | `List?` | SC execution results |
| `action` | `Map?` | Parsed action details (API only) |
| `operations` | `List?` | Token operations (API only) |
| `hyperblockNonce` | `int?` | Hyperblock nonce |
| `hyperblockHash` | `String?` | Hyperblock hash |

### TokenOnNetwork

Token information returned by `getFungibleTokensOfAccount()`:

| Field | Type | Description |
|-------|------|-------------|
| `identifier` | `String` | Token identifier |
| `balance` | `String` | Token balance |
| `decimals` | `int` | Token decimals |
| `type` | `String?` | Token type (FungibleESDT, etc.) |
| `name` | `String?` | Token name |
| `ticker` | `String?` | Token ticker |
| `owner` | `String?` | Token owner address |
| `price` | `double?` | Current price USD (API only) |
| `marketCap` | `double?` | Market capitalization (API only) |
| `supply` | `String?` | Total supply (API only) |

### NetworkEconomics

Network economics data returned by `getNetworkEconomics()` (API provider only):

| Field | Type | Description |
|-------|------|-------------|
| `totalSupply` | `int` | Total EGLD supply |
| `circulatingSupply` | `int` | Circulating EGLD supply |
| `staked` | `int` | Total EGLD staked |
| `price` | `double` | Current EGLD price (USD) |
| `marketCap` | `int` | EGLD market capitalization (USD) |
| `apr` | `double` | Total staking APR |
| `topUpApr` | `double` | Top-up APR component |
| `baseApr` | `double` | Base APR component |
| `tokenMarketCap` | `int` | Total token market cap (USD) |

## Error Handling

```dart
try {
  final account = await provider.getAccount(address);
} on NetworkException catch (e) {
  print('Network error: ${e.message}');
  // Check for specific errors
  if (e.statusCode == 404) {
    print('Resource not found');
  } else if (e.statusCode == 400) {
    print('Invalid request (e.g., invalid address format)');
  }
}
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  print('=== Network Provider Demo ===\n');
  
  final provider = GatewayNetworkProvider.devnet();
  
  // 1. Network configuration
  print('Network Config:');
  final config = await provider.getNetworkConfig();
  print('  Chain ID: ${config.chainId}');
  print('  Gas price: ${config.minGasPrice}');
  print('  Gas/byte: ${config.gasPerDataByte}');
  
  // 2. Network status
  final status = await provider.getNetworkStatus();
  print('  Epoch: ${status.epochNumber}');
  print('  Round: ${status.currentRound}');
  
  // 3. Account info
  final address = Address.fromBech32(
    'erd1qqqqqqqqqqqqqpgq6wegs2xkypfpync8mn2sa5cmpqjlvrhwz5nqgepyg8'
  );
  
  final account = await provider.getAccount(address);
  print('  Balance: ${account.balance.toDenominatedTrimmed} EGLD');
  print('  Nonce: ${account.nonce.value}');
  
  // 4. Token balances
  final tokens = await provider.getFungibleTokensOfAccount(address);
  for (final token in tokens.take(3)) {
    print('  ${token.identifier}: ${token.balance}');
  }
  

}
```

## Next Steps

- [Network Configuration](/docs/network/network-configuration) - Detailed config
- [WebSocket Events](/docs/network/websocket-events) - Real-time updates
- [Transactions](/docs/transactions/overview) - Sending transactions
