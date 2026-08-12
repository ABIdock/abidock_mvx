---
id: providers
title: Network Providers
sidebar_position: 2
description: Connect to MultiversX blockchain using Gateway or API network providers for transactions and data queries.
---

# Network Providers

Network providers connect your application to the MultiversX blockchain. Two providers are available for different use cases.

:::tip
If you only need "give me Devnet, wired up", an
[entrypoint](/docs/network/entrypoints) builds the provider for you and caches
it alongside matching factories and controllers.
:::

## Provider Comparison

| Feature | GatewayNetworkProvider | ApiNetworkProvider |
|---------|----------------------|-------------------|
| **Best for** | Transaction submission, real-time data | Historical data, token queries, indexing |
| **Base URL** | `gateway.multiversx.com` | `api.multiversx.com` |
| **Response format** | Wrapped in data envelope | Direct JSON responses |
| **Token metadata** | Basic token data | Extended metadata (price, supply, etc.) |
| **Account data** | Core fields | Extended fields (shard, txCount, etc.) |
| **Transaction data** | Core fields | Extended fields (action, operations, etc.) |
| **Economics data** | Chain metrics via `getGatewayEconomics()` | Market data via `getNetworkEconomics()` |
| **Token definitions** | ❌ Not exposed | ✅ `/tokens`, `/collections` |
| **Hyperblocks** | ✅ `getHyperblock()` | ❌ Not exposed |

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
print('Owner: ${nft.owner}  uris: ${nft.uris?.length ?? 0}');
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
`getNetworkEconomics()` is API-only: price, market cap, APR, and circulating
supply are computed by the indexer and have no source on the Gateway, so the
Gateway implementation throws `UnsupportedError`. The Gateway does expose the
metachain's own metrics — supply, fees, inflation, developer rewards, staked
and top-up values, all as `BigInt` atomic amounts:

```dart
final gateway = GatewayNetworkProvider.mainnet();
final chainEconomics = await gateway.getGatewayEconomics();
print('Total supply: ${chainEconomics.totalSupply}');
```
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

Both providers accept the same optional arguments: a `Dio` client, a `Logger`,
a circuit-breaker switch, and a `NetworkProviderConfig`.

### Custom HTTP Client

Requests go through [Dio](https://pub.dev/packages/dio), so any pre-configured
client (interceptors, proxies, custom adapters) can be injected:

```dart
import 'package:dio/dio.dart';

final client = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 30),
  receiveTimeout: const Duration(seconds: 30),
));

final provider = GatewayNetworkProvider(
  baseUrl: 'https://devnet-gateway.multiversx.com',
  chainId: const ChainId('D'),
  client: client,
);
```

### NetworkProviderConfig

`NetworkProviderConfig` covers the behaviour the SDK layers on top of the HTTP
client: headers, per-request timeout, retries, throttling, and response caching.

```dart
final provider = ApiNetworkProvider(
  baseUrl: 'https://api.multiversx.com',
  chainId: const ChainId('1'),
  config: const NetworkProviderConfig(
    clientName: 'my-dapp',
    requestTimeout: Duration(seconds: 20),
    headers: {'X-Trace': 'checkout-flow'},
  ),
);
```

| Field | Type | Description |
|-------|------|-------------|
| `clientName` | `String?` | Suffix added to the `User-Agent` header |
| `headers` | `Map<String, String>?` | Extra headers sent with every request |
| `requestTimeout` | `Duration?` | Maps onto the Dio connect/receive/send timeouts |
| `baseUrl` | `String?` | Overrides the base URL passed to the constructor |
| `retryPolicy` | `RetryPolicy` | Automatic retries; disabled by default |
| `throttlePolicy` | `ThrottlePolicy` | Client-side rate limiting; disabled by default |
| `cachePolicy` | `ResponseCachePolicy` | In-process `GET` cache; disabled by default |

### Circuit Breaker

Both providers can trip a circuit breaker after repeated failures instead of
hammering an unhealthy host:

```dart
final provider = GatewayNetworkProvider(
  baseUrl: 'https://gateway.multiversx.com',
  chainId: const ChainId('1'),
  enableCircuitBreaker: true,
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
| Get account storage | `/address/{address}/keys` |
| Get tokens | `/address/{address}/esdt` |
| Get NFTs | `/address/{address}/esdt` |
| Get one NFT | `/address/{address}/nft/{collection}/nonce/{nonce}` |
| Guardian data | `/address/{address}/guardian-data` |
| Send transaction | `/transaction/send` |
| Send many | `/transaction/send-multiple` |
| Get transaction | `/transaction/{hash}?withResults=true` |
| Transaction status | `/transaction/{hash}/process-status` |
| Network config | `/network/config` |
| Network status | `/network/status/{shard}` |
| Network economics | `/network/economics` |
| Block by nonce | `/block/{shard}/by-nonce/{nonce}` |
| Hyperblock | `/hyperblock/by-nonce/{nonce}` |
| VM query | `/vm-values/query` |

### API Endpoints

| Operation | Endpoint |
|-----------|----------|
| Get account | `/accounts/{address}?withGuardianInfo=true` |
| Get tokens | `/accounts/{address}/tokens` |
| Get NFTs | `/accounts/{address}/nfts` |
| Send transaction | `/transactions` |
| Get transaction | `/transactions/{hash}` |
| Transaction status | `/transactions/{hash}?fields=status` |
| Network config | `/network/config` |
| Network status | `/network/status/{shard}` |
| Network economics | `/economics` |
| Token definition | `/tokens/{identifier}` |
| Collection definition | `/collections/{collection}` |
| Block by hash | `/blocks/{hash}` |
| VM query | `/query` |

:::note
The Gateway lists both fungible and non-fungible holdings from
`/address/{address}/esdt`; the split into `getFungibleTokensOfAccount()` and
`getNonFungibleTokensOfAccount()` happens client-side.
:::

## Response Models

### AccountOnNetwork

Account information returned by `getAccount()`:

| Field | Type | Description |
|-------|------|-------------|
| `address` | `Address` | Account address |
| `nonce` | `Nonce` | Transaction counter |
| `balance` | `Balance` | EGLD balance |
| `shard` | `int?` | Account's shard (API only) |
| `username` | `String` | Herotag, empty when unset |
| `code` | `String?` | Deployed contract code |
| `codeHash` | `String?` | Hash of the deployed code |
| `codeMetadata` | `String?` | Upgradeable / readable / payable flags |
| `rootHash` | `String?` | Account trie root hash |
| `ownerAddress` | `Address?` | Contract owner (for smart contracts) |
| `developerReward` | `Balance?` | Accrued developer rewards |
| `activeGuardian` | `AccountGuardian?` | Guardian currently enforcing 2FA |
| `pendingGuardian` | `AccountGuardian?` | Guardian awaiting activation |
| `txCount` | `int?` | Total transaction count (API only) |
| `scrCount` | `int?` | Smart contract result count (API only) |
| `deployTxHash` | `String?` | Deployment transaction (for smart contracts) |
| `deployedAt` | `int?` | Deployment timestamp (for smart contracts) |
| `assets` | `Map<String, dynamic>?` | Account assets/metadata (API only) |

### TransactionOnNetwork

Transaction information returned by `getTransaction()`:

| Field | Type | Description |
|-------|------|-------------|
| `txHash` | `String` | Transaction hash |
| `transaction` | `Transaction` | Original transaction details |
| `status` | `TransactionStatus` | Current status |
| `timestamp` | `int?` | Unix timestamp (seconds) |
| `timestampMs` | `int?` | Unix timestamp (milliseconds) |
| `gasUsed` | `int?` | Gas consumed |
| `fee` | `String?` | Total fee paid |
| `initiallyPaidFee` | `String?` | Fee locked before execution |
| `senderShard` | `int?` | Sender's shard |
| `receiverShard` | `int?` | Receiver's shard |
| `blockNonce` | `int?` | Nonce of the including block |
| `blockHash` | `String?` | Hash of the including block |
| `hyperblockNonce` | `int?` | Hyperblock nonce |
| `hyperblockHash` | `String?` | Hyperblock hash |
| `logs` | `TransactionLogs?` | Event logs |
| `smartContractResults` | `List<SmartContractResult>?` | SC execution results |
| `function` | `String?` | Called endpoint name |
| `isRelayed` | `bool?` | Whether the transaction was relayed |
| `relayer` | `String?` | Relayer address |
| `relayerSignature` | `String?` | Relayer signature |
| `relayedVersion` | `String?` | Relayed protocol version reported by the network |
| `guardianAddress` | `String?` | Guardian that co-signed |
| `guardianSignature` | `String?` | Guardian signature |
| `action` | `Map<String, dynamic>?` | Parsed action details (API only) |
| `operations` | `List<Map<String, dynamic>>?` | Token operations (API only) |
| `price` | `double?` | EGLD price at execution time (API only) |

### TokenOnNetwork

Token information returned by `getFungibleTokensOfAccount()`. The three fields
are always present; the rest are convenience getters that read the untouched
`raw` payload, so anything the host returned is still reachable.

| Member | Type | Description |
|--------|------|-------------|
| `identifier` | `String` | Token identifier |
| `balance` | `String` | Token balance, atomic units |
| `nonce` | `int` | Token nonce (`0` for fungible tokens) |
| `raw` | `Map<String, dynamic>` | Full untouched payload |
| `name` | `String?` | Token name |
| `ticker` | `String?` | Token ticker |
| `decimals` | `int` | Token decimals, defaults to `18` |
| `type` | `String?` | Token type (`FungibleESDT`, `NonFungibleESDT`, ...) |
| `owner` | `String?` | Token owner address |
| `collection` | `String?` | Parent collection (NFT/SFT) |
| `timestamp` | `int?` | Creation timestamp (seconds) |
| `timestampMs` | `int?` | Creation timestamp (milliseconds) |

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

- [Entrypoints](/docs/network/entrypoints) - Provider, factories, and controllers in one object
- [Network Configuration](/docs/network/network-configuration) - Detailed config
- [WebSocket Events](/docs/network/websocket-events) - Real-time updates
- [Transactions](/docs/transactions/overview) - Sending transactions
