---
name: network-providers
title: Network Providers
summary: Pick and configure the right MultiversX network provider or entrypoint, and call the chain with the exact method names, parameters and return types.
reads: [03-transactions.md]
verified_against: abidock_mvx 3.1.0 (Dart 3.13)
---

**When to use this**: you need to read chain state, broadcast a transaction, or query a contract, and you must choose between the public API and the Gateway.

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
```

---

## 1. `ApiNetworkProvider` vs `GatewayNetworkProvider`

Both implement `abstract interface class NetworkProvider` (`lib/src/infrastructure/network/network_provider.dart:48`) and both extend `BaseNetworkProvider`, so the common surface is identical. They differ in which host they talk to and therefore in what that host can answer.

| | `ApiNetworkProvider` | `GatewayNetworkProvider` |
|---|---|---|
| Talks to | the public API host (indexer-backed) | the MultiversX Gateway / Proxy (node-backed) |
| Response shape | direct JSON | wrapped in a `data` envelope |
| Parses transactions with | `TransactionOnNetwork.fromApiResponse` (base64 SCR/event payloads) | `TransactionOnNetwork.fromProxyResponse` (plain UTF-8 / hex payloads) |
| Token & NFT metadata | yes | no — throws `UnsupportedError` |
| Market economics (price, APR, market cap) | yes | no — `getNetworkEconomics()` throws |
| `providerName` | `'API'` | `'Gateway'` |

Rule of thumb: **API for anything indexer-shaped** (token definitions, collections, NFT instances, market data, account token lists). **Gateway for raw node access** (`vm-values/query`, protocol fields, the proxy's derived process status).

Constructors are the same on both:

```dart
ApiNetworkProvider({
  required String baseUrl,
  required ChainId chainId,
  Dio? client,
  Logger? logger,
  bool enableCircuitBreaker = false,
  NetworkProviderConfig? config,
})
```

Named network factories take `({Dio? client, Logger? logger, bool enableCircuitBreaker = false, NetworkProviderConfig? config})`:

| Factory | baseUrl | chainId |
|---|---|---|
| `ApiNetworkProvider.mainnet()` | `https://api.multiversx.com` | `ChainId('1')` |
| `ApiNetworkProvider.testnet()` | `https://testnet-api.multiversx.com` | `ChainId('T')` |
| `ApiNetworkProvider.devnet()` | `https://devnet-api.multiversx.com` | `ChainId('D')` |
| `GatewayNetworkProvider.mainnet()` | `https://gateway.multiversx.com` | `ChainId('1')` |
| `GatewayNetworkProvider.testnet()` | `https://testnet-gateway.multiversx.com` | `ChainId('T')` |
| `GatewayNetworkProvider.devnet()` | `https://devnet-gateway.multiversx.com` | `ChainId('D')` |

Base URLs are normalised (trailing `/` stripped) and `config.baseUrl`, when set, **overrides** the `baseUrl` argument (`base_network_provider.dart:57`).

`close()` disposes the HTTP client **only when the provider created it**. If you injected your own `Dio` via `client:`, `close()` is a no-op on it and the provider never touches its default headers or timeouts either (`base_network_provider.dart:65`, `:1264`).

---

## 2. Entrypoints

`lib/src/entrypoints/network_entrypoint.dart`. An entrypoint is a façade that owns **one cached provider** and hands out pre-configured factories/controllers for a chain id. `createNetworkProvider()` returns the same instance every time.

`EntrypointUrls` constants (`network_entrypoint.dart:22`):

| Constant | Value |
|---|---|
| `EntrypointUrls.mainnet` | `https://api.multiversx.com` |
| `EntrypointUrls.testnet` | `https://testnet-api.multiversx.com` |
| `EntrypointUrls.devnet` | `https://devnet-api.multiversx.com` |
| `EntrypointUrls.mainnetGateway` | `https://gateway.multiversx.com` |
| `EntrypointUrls.testnetGateway` | `https://testnet-gateway.multiversx.com` |
| `EntrypointUrls.devnetGateway` | `https://devnet-gateway.multiversx.com` |

| Class | Provider it builds | url | chainId |
|---|---|---|---|
| `NetworkEntrypoint` | `ApiNetworkProvider` | you supply | you supply |
| `MainnetEntrypoint` | `ApiNetworkProvider` | `EntrypointUrls.mainnet` | `ChainId('1')` |
| `TestnetEntrypoint` | `ApiNetworkProvider` | `EntrypointUrls.testnet` | `ChainId('T')` |
| `DevnetEntrypoint` | `ApiNetworkProvider` | `EntrypointUrls.devnet` | `ChainId('D')` |
| `ProxyNetworkEntrypoint` | `GatewayNetworkProvider` | you supply | you supply |
| `MainnetProxyEntrypoint` | `GatewayNetworkProvider` | `EntrypointUrls.mainnetGateway` | `ChainId('1')` |
| `TestnetProxyEntrypoint` | `GatewayNetworkProvider` | `EntrypointUrls.testnetGateway` | `ChainId('T')` |
| `DevnetProxyEntrypoint` | `GatewayNetworkProvider` | `EntrypointUrls.devnetGateway` | `ChainId('D')` |

`NetworkEntrypoint({required String url, required ChainId chainId, NetworkProviderConfig? networkProviderConfig, String? clientName, IGasLimitEstimator? gasLimitEstimator})`. `ProxyNetworkEntrypoint` takes the same parameters. The pre-named subclasses take only `{networkProviderConfig, clientName, gasLimitEstimator}`.

`ProxyNetworkEntrypoint` is **not** a subclass of `NetworkEntrypoint` — they are two independent classes with the same shape, so a variable typed `NetworkEntrypoint` cannot hold a proxy entrypoint.

Methods present on both (identical names): `createNetworkProvider()`, `createSmartContractController({required SmartContractAbi abi, required Address address})`, `createTransfersFactory()`, `createTokenManagementFactory()`, `createDelegationFactory()`, `createMultisigFactory()`, `createValidatorsFactory()`, `createGovernanceFactory()`, `createMultisigController()`, `createValidatorsController()`, `createGovernanceController()`, `createTransactionWatcher()`. Fields: `url`, `chainId`, `networkProviderConfig`, `gasLimitEstimator`.

```dart
final DevnetEntrypoint devnet = DevnetEntrypoint(clientName: 'my-dapp');
final ApiNetworkProvider provider = devnet.createNetworkProvider();
final TransferTransactionsFactory transfers = devnet.createTransfersFactory();
final TransactionWatcher watcher = devnet.createTransactionWatcher();

final MainnetProxyEntrypoint proxy = MainnetProxyEntrypoint();
final GatewayNetworkProvider gateway = proxy.createNetworkProvider();

final NetworkEntrypoint custom = NetworkEntrypoint(
  url: 'https://my-api.example.com',
  chainId: const ChainId('D'),
  networkProviderConfig: const NetworkProviderConfig(
    requestTimeout: Duration(seconds: 15),
  ),
);
```

Two behaviours to know:

- Both families forward `networkProviderConfig` to the provider they build — `NetworkEntrypoint` to its `ApiNetworkProvider` (`network_entrypoint.dart:102-106`) and `ProxyNetworkEntrypoint` to its `GatewayNetworkProvider` (`:310-314`). Headers, `requestTimeout`, retry, throttle and cache all take effect on a proxy entrypoint exactly as they do on an API one.
- Passing both `networkProviderConfig` and `clientName` merges them: the explicit `clientName` overrides the one on the config, and every other field — `headers`, `requestTimeout`, `baseUrl`, `retryPolicy`, `throttlePolicy`, `cachePolicy` — is carried over unchanged (`_mergeClientName`, `network_entrypoint.dart:199-218`). Passing `clientName` alone builds a config holding just that field; passing neither leaves the provider unconfigured.

---

## 3. `NetworkProviderConfig`

`lib/src/infrastructure/network/network_provider_config.dart:171` (const constructor at `:193`). **Every resilience feature is opt-in and off by default.** A provider built without a config performs exactly one unthrottled, uncached, unretried HTTP request per call.

| Field | Type | Default | Effect |
|---|---|---|---|
| `clientName` | `String?` | `null` | Becomes the `User-Agent` suffix |
| `headers` | `Map<String, String>?` | `null` | Extra headers on every request |
| `requestTimeout` | `Duration?` | `null` → `Duration(seconds: 30)` | Dio connect/receive/send timeout and the per-call race |
| `baseUrl` | `String?` | `null` | Overrides the constructor's `baseUrl` |
| `retryPolicy` | `RetryPolicy` | `const RetryPolicy.disabled()` | Automatic retries in `doGetGeneric` / `doPostGeneric` |
| `throttlePolicy` | `ThrottlePolicy` | `const ThrottlePolicy.disabled()` | Client-side token bucket on every request |
| `cachePolicy` | `ResponseCachePolicy` | `const ResponseCachePolicy.disabled()` | In-process cache of `GET` bodies |

`enableCircuitBreaker` is a separate **constructor** argument, also `false` by default; when `true` it opens after 5 failures with a 1-minute retry delay (`base_network_provider.dart:70`).

### User agent

`UserAgent.build({String? clientName})` returns `'multiversx-sdk-dart/<clientName>'`, or `'multiversx-sdk-dart/unknown'` when the name is null or empty. Constants: `UserAgent.prefix`, `UserAgent.unknownClient`.

### Retry

- `const RetryPolicy.disabled()` — default.
- `const RetryPolicy.enabled([RetryConfig config = const RetryConfig()])`.

`RetryConfig({int maxRetries = 3, Duration initialDelay = const Duration(seconds: 1), Duration maxDelay = const Duration(seconds: 30), double backoffMultiplier = 2.0, Duration timeout = const Duration(seconds: 30), double jitterFactor = 0.1})`. Only transient errors are retried, decided by `RetryHelper.isTransientError`.

### Throttle

A per-provider-instance token bucket; it bounds only this provider's traffic, not the process's.

- `const ThrottlePolicy.disabled()` — default.
- `const ThrottlePolicy.enabled({required int capacity, required double refillPerSecond})`.
- `const ThrottlePolicy.gateway()` — capacity 50, refill 50/s.
- `const ThrottlePolicy.api()` — capacity 2, refill 2/s.

Those presets match the published per-IP ceilings documented on the policy: the Gateway hosts allow 50 req/IP/s on mainnet and devnet; the API hosts allow 2 on mainnet and 5 on devnet — for devnet API use `ThrottlePolicy.enabled(capacity: 5, refillPerSecond: 5)` (`network_provider_config.dart:32-38`; the presets themselves are at `:80` and `:87`).

### Response cache

- `const ResponseCachePolicy.disabled()` — default, and the right default: chain state changes every round, so a cached account hands back a stale nonce.
- `const ResponseCachePolicy.enabled({CacheConfig defaultConfig = CacheConfig.short, Map<String, CacheConfig> endpointConfigs = const {}})`.

Only `GET` bodies are cached, keyed by the resource path **including its query string**, and the whole cache is dropped after every successful `POST` (`base_network_provider.dart:1177`). `clearResponseCache()` on the provider clears it manually (no-op when disabled).

`CacheConfig({bool enabled = true, Duration ttl = const Duration(minutes: 5), int maxSize = 100, bool cacheErrors = false})`; presets `CacheConfig.disabled`, `CacheConfig.short` (1 min), `CacheConfig.medium` (5 min), `CacheConfig.long` (30 min).

```dart
final ApiNetworkProvider api = ApiNetworkProvider(
  baseUrl: 'https://devnet-api.multiversx.com',
  chainId: const ChainId('D'),
  enableCircuitBreaker: true,
  config: const NetworkProviderConfig(
    clientName: 'my-dapp',
    requestTimeout: Duration(seconds: 10),
    headers: <String, String>{'X-Request-Id': 'abc'},
    retryPolicy: RetryPolicy.enabled(),
    throttlePolicy: ThrottlePolicy.api(),
    cachePolicy: ResponseCachePolicy.enabled(
      defaultConfig: CacheConfig.short,
      endpointConfigs: <String, CacheConfig>{'network/config': CacheConfig.long},
    ),
  ),
);
api.clearResponseCache();
api.close();

final GatewayNetworkProvider gateway = GatewayNetworkProvider.devnet(
  config: const NetworkProviderConfig(
    throttlePolicy: ThrottlePolicy.gateway(),
  ),
);
gateway.close();
```

---

## 4. The methods you will actually use

This is the common surface, not the whole interface. Everything here is declared on `NetworkProvider` and implemented in `BaseNetworkProvider`, so it exists on **both** providers unless the last column says otherwise. `4294967295` is the metachain shard id and the default everywhere a `shard` parameter appears.

| Method | Returns | Notes |
|---|---|---|
| `getNetworkConfig()` | `NetworkConfig` | `chainId`, `minGasLimit`, `gasPerDataByte`, `minGasPrice`, `numShards`, `roundDuration`, `gasPriceModifier`, … |
| `getNetworkStatus({int shard = 4294967295})` | `NetworkStatus` | `currentRound`, `epochNumber`, `nonce` are `int`; `highestFinalNonce` is `int?`; `blockTime` is a `DateTime?` **getter**, not a raw timestamp (`network_status.dart:263`) |
| `getNetworkEconomics()` | `NetworkEconomics` | **API only** — throws `UnsupportedError` on Gateway |
| `getAccount(Address)` | `AccountOnNetwork` | `balance`, `nonce`, … |
| `getAccountStorage(Address)` | `AccountStorage` | |
| `getAccountStorageEntry(Address, String key)` | `AccountStorageEntry` | pass the **plain** key; the provider hex-encodes it (`base_network_provider.dart:552`) |
| `sendTransaction(Transaction)` | `String` | the transaction hash |
| `sendTransactions(List<Transaction>)` | `SendTransactionsResult` | `numSent`, `txHashes`, `outcomes` |
| `getTransaction(String txHash, {bool withProcessStatus = false})` | `TransactionOnNetwork` | `withProcessStatus` changes no path on either provider |
| `getTransactionStatus(String txHash)` | `TransactionStatus` | |
| `simulateTransaction(Transaction)` | `TransactionOnNetwork` | |
| `estimateTransactionCost(Transaction)` | `Map<String, dynamic>` | keys `gasLimit`, `returnMessage`, `status` |
| `queryContract(SmartContractQuery)` | `SmartContractQueryResponse` | |
| `getTokenOfAccount(Address, String tokenIdentifier)` | `TokenOnNetwork` | |
| `getFungibleTokensOfAccount(Address, {int? from, int? size})` | `List<TokenOnNetwork>` | |
| `getNonFungibleTokensOfAccount(Address, {int? from, int? size})` | `List<TokenOnNetwork>` | |
| `getGuardianData(Address)` | `GuardianData` | `guarded` + active/pending guardians |
| `getDefinitionOfFungibleToken(String identifier)` | `TokenOnNetwork` | **API only** |
| `getDefinitionOfTokenCollection(String collection)` | `TokenOnNetwork` | **API only** |
| `getNonFungibleToken(String collection, int nonce)` | `TokenOnNetwork` | **API only** |
| `getBlock(String hash, {int shard = 4294967295})` | `BlockOnNetwork` | `shard` required by the Gateway URL, ignored by the API |
| `getLatestBlock({int shard = 4294967295})` | `BlockOnNetwork` | |
| `getHyperblock(int nonce)` | `HyperblockOnNetwork` | |
| `doGetGeneric(String resourceUrl)` | `dynamic` | escape hatch, path relative to `baseUrl` |
| `doPostGeneric(String resourceUrl, dynamic payload)` | `dynamic` | escape hatch; clears the response cache on success |
| `close()` | `void` | |

Read-only members: `String get baseUrl`, `ChainId get chainId`, plus `NetworkProviderConfig? get config`, `Logger? logger`, `bool enableCircuitBreaker` and `void clearResponseCache()` on `BaseNetworkProvider`.

Pagination note: on the API provider `getFungibleTokensOfAccount` / `getNonFungibleTokensOfAccount` default to `from = 0`, `size = 100` (`api_network_provider.dart:232`, `:242`). The route's own server-side default is 25, which truncates silently, so do not pass `size: null` and assume you got everything — page explicitly for large holders. The Gateway provider sends no pagination at all (base defaults are `null`) because it returns the whole ESDT map in one body.

Given `provider` (either provider), an `Address address` and a `String contractBech32`:

```dart
final NetworkConfig config = await provider.getNetworkConfig();
print(config.chainId);
print(config.minGasLimit);
print(config.gasPerDataByte);
print(config.numShards);

final NetworkStatus shard0 = await provider.getNetworkStatus(shard: 0);
print(shard0.currentRound);
print(shard0.blockTime);

final AccountOnNetwork account = await provider.getAccount(address);
print(account.balance.value);
print(account.nonce.value);

final SmartContractQueryResponse response = await provider.queryContract(
  SmartContractQuery.view(
    contract: Address.fromBech32(contractBech32),
    function: const SmartContractFunction('getSum'),
  ),
);
print(response.returnCode);
print(response.returnDataParts);
print(response.isSuccess);

final List<TokenOnNetwork> fungible = await provider
    .getFungibleTokensOfAccount(address, from: 0, size: 100);

final BlockOnNetwork block = await provider.getLatestBlock(shard: 0);
final BlockOnNetwork byHash = await provider.getBlock(block.hash, shard: 0);

final dynamic raw = await provider.doGetGeneric('economics');
provider.close();
```

`SmartContractQuery.view({required SmartContractAddress contract, required SmartContractFunction function, List<dynamic> arguments = const [], Address? caller})` — `SmartContractAddress` is a typedef for `Address`. The response exposes `function`, `returnCode` (`String`), `returnMessage`, `returnDataParts` (`List<String>`, base64), `isSuccess`, `isFailure`, `parsedReturnCode`, `hasReturnData`, `returnDataCount`.

### Routes each provider hits

Useful when debugging a 404. API left, Gateway right.

| Operation | API path | Gateway path |
|---|---|---|
| account | `accounts/{bech32}?withGuardianInfo=true` | `address/{bech32}` |
| account storage | `address/{bech32}/keys` | `address/{bech32}/keys` |
| send one | `transactions` | `transaction/send` |
| send many | `transaction/send-multiple` | `transaction/send-multiple` |
| get transaction | `transactions/{hash}` | `transaction/{hash}?withResults=true` |
| transaction status | `transactions/{hash}?fields=status` | `transaction/{hash}/process-status` |
| simulate | `transaction/simulate?checkSignature=false` | `transaction/simulate?checkSignature=false` |
| estimate cost | `transaction/cost` | `transaction/cost` |
| contract query | `query` | `vm-values/query` |
| network status | `network/status/{shard}` | `network/status/{shard}` |
| guardian data | `address/{bech32}/guardian-data` | `address/{bech32}/guardian-data` |
| fungible list | `accounts/{bech32}/tokens` | `address/{bech32}/esdt` |
| NFT list | `accounts/{bech32}/nfts` | `address/{bech32}/esdt` (filtered locally by nonce) |
| block by hash | `blocks/{hash}` | `block/{shard}/by-hash/{hash}` |
| hyperblock | `hyperblock/by-nonce/{nonce}` | `hyperblock/by-nonce/{nonce}` |

---

## 5. What is unavailable where

### Not on `GatewayNetworkProvider`

| Call | What happens | Use instead |
|---|---|---|
| `getNetworkEconomics()` | throws `UnsupportedError` (`gateway_network_provider.dart:380`) | `GatewayNetworkProvider.getGatewayEconomics()` for chain metrics, or `ApiNetworkProvider.getNetworkEconomics()` for price / market cap / APR |
| `getDefinitionOfFungibleToken(id)` | throws `UnsupportedError` (`:307`) | `ApiNetworkProvider.getDefinitionOfFungibleToken`, or `queryContract` against the ESDT system contract |
| `getDefinitionOfTokenCollection(c)` | throws `UnsupportedError` (`:319`) | `ApiNetworkProvider.getDefinitionOfTokenCollection` |
| `getNonFungibleToken(c, nonce)` | throws `UnsupportedError` (`:329`) | `ApiNetworkProvider.getNonFungibleToken` |
| `awaitTransactionCompleted` / `awaitTransactionOnCondition` | do not exist | `TransactionWatcher(networkProvider: gateway).awaitCompleted(...)` |

The Gateway's NFT-list route reads `address/{bech32}/esdt` and keeps the entries whose nonce is non-zero — there is no node route that lists only an account's NFTs.

### Gateway-only extras

| Member | Signature |
|---|---|
| `getGatewayEconomics()` | `Future<GatewayEconomics>` — `totalSupply`, `totalFees`, `devRewards`, `inflation`, `totalBaseStakedValue`, `totalTopUpValue` are `BigInt` atomic `1e-18` amounts; `epochForEconomicsData` is an `int`; `raw` is the untouched `Map<String, dynamic>`. No price / market cap / APR |
| `getTransactionWithProcessStatus(String txHash)` | `Future<TransactionOnNetwork>` — costs **two** requests; overlays the proxy's `process-status` verdict, which catches failures raised by smart-contract results in other shards that `getTransaction` reports as `success` |
| `getNftOfAccount(Address, String collection, int nonce)` | `Future<TokenOnNetwork>` — the Gateway splits balance lookups by nonce, and `getTokenOfAccount` cannot express one |

Given a `String txHash` and an `Address address`:

```dart
final GatewayNetworkProvider gateway = GatewayNetworkProvider.devnet();

final GatewayEconomics economics = await gateway.getGatewayEconomics();
print(economics.totalSupply);

final TransactionOnNetwork tx = await gateway.getTransactionWithProcessStatus(
  txHash,
);
print(tx.status.isFailed);

final TokenOnNetwork nft = await gateway.getNftOfAccount(
  address,
  'EROBOT-527a29',
  42,
);
gateway.close();
```

### API-only extras

`awaitTransactionCompleted(String txHash)` and `awaitTransactionOnCondition(String txHash, bool Function(TransactionStatus) condition)` — both build a `TransactionWatcher` with default options (9 s timeout, 600 ms polling). See `skills/03-transactions.md` §5 before relying on that timeout.

---

## Not verified

- No call in this file was executed against a live host; every signature, default, route string and `UnsupportedError` was read from the declaration, and the samples were compiled, not run.
- Which method the deprecated-vs-current split favours for `NetworkConfig` fields beyond the ones listed; the class has ~25 fields and only the common ones are documented here.
- The remaining `NetworkProvider` members not in the table above (`getAccountStorage` shapes, `HyperblockOnNetwork` field list, `BlockOnNetwork` field list beyond `nonce`/`hash`/`round`).
- The real-world accuracy of the per-IP rate ceilings quoted by `ThrottlePolicy`; they are reproduced from the policy's own documentation, not measured.
