---
id: entrypoints
title: Entrypoints
sidebar_position: 1
description: One-line access to a network provider, transaction factories, and controllers for Mainnet, Devnet, and Testnet.
---

# Entrypoints

An entrypoint binds a **base URL** and a **chain ID** together, builds one
network provider, and hands out the SDK's factories and controllers already
configured for that network. It is the shortest path from "I want to talk to
Devnet" to a working provider, factory, or controller.

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

Future<void> main() async {
  final entrypoint = DevnetEntrypoint();

  final provider = entrypoint.createNetworkProvider();
  final transfers = entrypoint.createTransfersFactory();

  final config = await provider.getNetworkConfig();
  print('Connected to ${config.chainId}');
}
```

Entrypoints add no behaviour of their own. Every object they return is the same
class you can construct by hand — the entrypoint just fills in the URL, the
chain ID, and the shared factory configuration for you.

## Choosing a family

There are two independent families, one per provider type.

| Family | Provider built | Reach for it when |
|--------|----------------|-------------------|
| `NetworkEntrypoint` | `ApiNetworkProvider` | Indexer-backed data: token lists, NFT metadata, economics, account statistics |
| `ProxyNetworkEntrypoint` | `GatewayNetworkProvider` | Direct node access: raw protocol fields, hyperblocks, gateway-shaped responses |

`ProxyNetworkEntrypoint` is a sibling class, not a subclass — it exposes the
same method names but its `createNetworkProvider()` returns a
`GatewayNetworkProvider`.

## Preset entrypoints

Six ready-made subclasses cover the public networks. Each one fills in the URL
and the chain ID; you only pass the optional arguments you care about.

| Class | Base URL | Chain ID |
|-------|----------|----------|
| `MainnetEntrypoint` | `https://api.multiversx.com` | `1` |
| `DevnetEntrypoint` | `https://devnet-api.multiversx.com` | `D` |
| `TestnetEntrypoint` | `https://testnet-api.multiversx.com` | `T` |
| `MainnetProxyEntrypoint` | `https://gateway.multiversx.com` | `1` |
| `DevnetProxyEntrypoint` | `https://devnet-gateway.multiversx.com` | `D` |
| `TestnetProxyEntrypoint` | `https://testnet-gateway.multiversx.com` | `T` |

```dart
final mainnet = MainnetEntrypoint();
final devnet = DevnetEntrypoint();
final testnet = TestnetEntrypoint();

final mainnetProxy = MainnetProxyEntrypoint();
final devnetProxy = DevnetProxyEntrypoint();
final testnetProxy = TestnetProxyEntrypoint();
```

### EntrypointUrls

The same hosts are available as constants, which is what you want when you
build a `NetworkEntrypoint` by hand or need the URL for something else.

| Constant | Value |
|----------|-------|
| `EntrypointUrls.mainnet` | `https://api.multiversx.com` |
| `EntrypointUrls.devnet` | `https://devnet-api.multiversx.com` |
| `EntrypointUrls.testnet` | `https://testnet-api.multiversx.com` |
| `EntrypointUrls.mainnetGateway` | `https://gateway.multiversx.com` |
| `EntrypointUrls.devnetGateway` | `https://devnet-gateway.multiversx.com` |
| `EntrypointUrls.testnetGateway` | `https://testnet-gateway.multiversx.com` |

## Custom networks

Use the base classes for a private node, a local chain simulator, or any host
that is not one of the six presets. `ChainId` accepts `1`, `D`, and `T`, so a
private network is addressed by pointing a URL at the chain ID it signs with:

```dart
final entrypoint = NetworkEntrypoint(
  url: 'https://my-api.example.com',
  chainId: const ChainId.devnet(),
  clientName: 'my-dapp',
);

final proxy = ProxyNetworkEntrypoint(
  url: 'http://localhost:8085',
  chainId: const ChainId.devnet(),
);
```

### Constructor parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `url` | `String` | Base URL of the API host (or Gateway host for the proxy family). Required on the base classes, pre-filled on the presets. |
| `chainId` | `ChainId` | Chain ID stamped onto every transaction the factories build. Required on the base classes, pre-filled on the presets. |
| `networkProviderConfig` | `NetworkProviderConfig?` | HTTP behaviour: headers, request timeout, retry / throttle / cache policies. |
| `clientName` | `String?` | Shortcut that sets only the `User-Agent` suffix. When both are given, this value wins over `networkProviderConfig.clientName`. |
| `gasLimitEstimator` | `IGasLimitEstimator?` | Shared with every controller the entrypoint creates. |

`clientName` and `networkProviderConfig` are merged into a single effective
config exposed as `entrypoint.networkProviderConfig`:

```dart
final entrypoint = DevnetEntrypoint(
  networkProviderConfig: const NetworkProviderConfig(
    requestTimeout: Duration(seconds: 20),
    headers: {'X-Trace': 'checkout-flow'},
  ),
  clientName: 'my-dapp',
);

print(entrypoint.networkProviderConfig?.clientName); // my-dapp
```

Passing neither leaves `networkProviderConfig` null and the provider falls back
to its own defaults.

:::note
`ProxyNetworkEntrypoint` currently builds its `GatewayNetworkProvider` from the
URL and chain ID only. If you need custom headers, timeouts, or retry policies
against a Gateway, construct `GatewayNetworkProvider` directly and pass its
`config` argument.
:::

## The provider is cached

`createNetworkProvider()` builds the provider once, on first use, and returns
that same instance for the lifetime of the entrypoint. Every `create*` method
below shares it, so controllers created from one entrypoint share one HTTP
client, one circuit breaker, and one response cache.

```dart
final entrypoint = DevnetEntrypoint();

final a = entrypoint.createNetworkProvider();
final b = entrypoint.createNetworkProvider();

print(identical(a, b)); // true
```

Create a second entrypoint when you deliberately want a second, isolated
provider.

## Transaction factories

Factories build **unsigned** transactions with the entrypoint's chain ID
already applied. They never touch the network.

| Method | Returns |
|--------|---------|
| `createTransfersFactory()` | `TransferTransactionsFactory` |
| `createTokenManagementFactory()` | `TokenManagementTransactionsFactory` |
| `createDelegationFactory()` | `DelegationTransactionsFactory` |
| `createMultisigFactory()` | `MultisigTransactionsFactory` |
| `createValidatorsFactory()` | `ValidatorsTransactionsFactory` |
| `createGovernanceFactory()` | `GovernanceTransactionsFactory` |

All six share one `TransactionsFactoryConfig`, built once per entrypoint from
`chainId`, so gas constants and chain ID stay consistent across them.

```dart
final entrypoint = DevnetEntrypoint();
final transfers = entrypoint.createTransfersFactory();

final unsigned = transfers.createTransactionForNativeTokenTransfer(
  sender: alice.address,
  receiver: bob,
  nativeAmount: Balance.fromEgld(0.5),
);
```

## Controllers

Controllers wrap a factory plus the cached provider: they sign, and some of
them broadcast or await.

| Method | Returns |
|--------|---------|
| `createSmartContractController({abi, address})` | `SmartContractController` |
| `createMultisigController()` | `MultisigController` |
| `createValidatorsController()` | `ValidatorsController` |
| `createGovernanceController()` | `GovernanceController` |
| `createTransactionWatcher()` | `TransactionWatcher` |

```dart
final entrypoint = DevnetEntrypoint();

final controller = entrypoint.createSmartContractController(
  abi: SmartContractAbi.fromJson(abiJson),
  address: SmartContractAddress.fromBech32(
    'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
  ),
);

final result = await controller.query(
  endpointName: 'getReservesAndTotalSupply',
);
```

`createSmartContractController` always takes an ABI. For raw, ABI-less calls,
build `SmartContractController.withoutAbi(...)` yourself with
`entrypoint.createNetworkProvider()`.

`createTransactionWatcher()` returns a `TransactionWatcher` bound to the same
cached provider, so you can await a hash you just broadcast:

```dart
final provider = entrypoint.createNetworkProvider();
final watcher = entrypoint.createTransactionWatcher();

final hash = await provider.sendTransaction(signed);
final completed = await watcher.awaitCompleted(hash);
print(completed.status.status);
```

## Injecting a gas-limit estimator

`gasLimitEstimator` is handed to every controller the entrypoint creates —
`SmartContractController`, `MultisigController`, `ValidatorsController`, and
`GovernanceController`. Transaction factories do not take one; they compute gas
from the network's static gas schedule instead.

Any implementation of `IGasLimitEstimator` works. `GasEstimator` is the
built-in one and estimates by simulating the transaction:

```dart
final provider = ApiNetworkProvider.devnet();

final entrypoint = DevnetEntrypoint(
  gasLimitEstimator: GasEstimator(
    networkProvider: provider,
    gasMultiplier: 1.2,
  ),
);
```

Write your own for fixed budgets or a service-side estimator:

```dart
class FixedGasEstimator implements IGasLimitEstimator {
  const FixedGasEstimator(this.gasLimit);

  final int gasLimit;

  @override
  Future<int> estimateGasLimit({required Transaction transaction}) async =>
      gasLimit;
}

final entrypoint = DevnetEntrypoint(
  gasLimitEstimator: const FixedGasEstimator(25000000),
);
```

## End-to-end: EGLD transfer

```dart
import 'dart:io';
import 'package:abidock_mvx/abidock_mvx.dart';

Future<void> main() async {
  final entrypoint = DevnetEntrypoint(clientName: 'transfer-demo');
  final provider = entrypoint.createNetworkProvider();

  final alice = await Account.fromPem(
    File('assets/alice.pem').readAsStringSync(),
  );
  final aliceOnNetwork = await provider.getAccount(alice.address);

  final unsigned = entrypoint.createTransfersFactory()
      .createTransactionForNativeTokenTransfer(
        sender: alice.address,
        receiver: Address.fromBech32(
          'erd12m6dwylyqvz3282j857mldsdrfln476ww7k3kmpq0f0h7pvhl8qs4ucen5',
        ),
        nativeAmount: Balance.fromEgld(0.1),
      );

  final withNonce = unsigned.copyWith(newNonce: aliceOnNetwork.nonce);
  final signature = await alice.signTransaction(withNonce);
  final signed = withNonce.copyWith(
    newSignature: Signature.fromUint8List(signature),
  );

  final hash = await provider.sendTransaction(signed);
  final completed = await entrypoint.createTransactionWatcher()
      .awaitCompleted(hash);

  print('$hash -> ${completed.status.status}');
}
```

## What entrypoints do not do

- They do not sign. Signing stays with `Account`, `UserSigner`, or a controller.
- They do not broadcast. Use the provider's `sendTransaction`.
- They do not fetch nonces. Read the account first, then stamp the nonce.
- They hold no per-account state, so one entrypoint can serve many wallets.
- They expose no relayed factory. Build `RelayedTransactionsFactory` directly
  when you need `applyRelayer`.

## Next Steps

- [Network Providers](/docs/network/providers) - The provider surface in full
- [Network Configuration](/docs/network/network-configuration) - Chain IDs and URLs
- [Transactions](/docs/transactions/overview) - Factories and controllers in depth
