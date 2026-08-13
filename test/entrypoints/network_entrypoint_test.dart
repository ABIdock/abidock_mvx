/// Tests for [NetworkEntrypoint] / [ProxyNetworkEntrypoint] façades.
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('EntrypointUrls', () {
    test('exposes canonical public API hosts', () {
      expect(
        EntrypointUrls.devnet,
        equals('https://devnet-api.multiversx.com'),
      );
      expect(
        EntrypointUrls.testnet,
        equals('https://testnet-api.multiversx.com'),
      );
      expect(EntrypointUrls.mainnet, equals('https://api.multiversx.com'));
    });

    test('exposes canonical public Gateway hosts', () {
      expect(
        EntrypointUrls.devnetGateway,
        equals('https://devnet-gateway.multiversx.com'),
      );
      expect(
        EntrypointUrls.testnetGateway,
        equals('https://testnet-gateway.multiversx.com'),
      );
      expect(
        EntrypointUrls.mainnetGateway,
        equals('https://gateway.multiversx.com'),
      );
    });
  });

  group('NetworkEntrypoint provider caching', () {
    test(
      'two consecutive createNetworkProvider() calls return the same instance',
      () {
        final NetworkEntrypoint entry = DevnetEntrypoint();
        final ApiNetworkProvider first = entry.createNetworkProvider();
        final ApiNetworkProvider second = entry.createNetworkProvider();
        expect(identical(first, second), isTrue);
      },
    );

    test(
      'createSmartContractController reuses the cached network provider',
      () {
        final NetworkEntrypoint entry = DevnetEntrypoint();
        final ApiNetworkProvider direct = entry.createNetworkProvider();
        expect(identical(entry.createNetworkProvider(), direct), isTrue);
      },
    );
  });

  group('MainnetEntrypoint / DevnetEntrypoint / TestnetEntrypoint', () {
    test('Mainnet entrypoint exposes chainId "1"', () {
      expect(MainnetEntrypoint().chainId.value, equals('1'));
    });

    test('Devnet entrypoint exposes chainId "D"', () {
      expect(DevnetEntrypoint().chainId.value, equals('D'));
    });

    test('Testnet entrypoint exposes chainId "T"', () {
      expect(TestnetEntrypoint().chainId.value, equals('T'));
    });
  });

  group('ProxyNetworkEntrypoint variants', () {
    test('Mainnet proxy points at the public Gateway', () {
      final MainnetProxyEntrypoint entry = MainnetProxyEntrypoint();
      expect(entry.url, equals(EntrypointUrls.mainnetGateway));
      expect(entry.chainId.value, equals('1'));
    });

    test('Devnet proxy points at the devnet Gateway', () {
      final DevnetProxyEntrypoint entry = DevnetProxyEntrypoint();
      expect(entry.url, equals(EntrypointUrls.devnetGateway));
      expect(entry.chainId.value, equals('D'));
    });

    test('Testnet proxy points at the testnet Gateway', () {
      final TestnetProxyEntrypoint entry = TestnetProxyEntrypoint();
      expect(entry.url, equals(EntrypointUrls.testnetGateway));
      expect(entry.chainId.value, equals('T'));
    });

    test(
      'Proxy entrypoint createNetworkProvider returns a GatewayNetworkProvider',
      () {
        final MainnetProxyEntrypoint entry = MainnetProxyEntrypoint();
        expect(entry.createNetworkProvider(), isA<GatewayNetworkProvider>());
      },
    );

    test('Proxy entrypoint also caches its provider', () {
      final MainnetProxyEntrypoint entry = MainnetProxyEntrypoint();
      final GatewayNetworkProvider a = entry.createNetworkProvider();
      final GatewayNetworkProvider b = entry.createNetworkProvider();
      expect(identical(a, b), isTrue);
    });
  });

  group('NetworkEntrypoint clientName forwarding', () {
    test(
      'explicit clientName ends up in the effective NetworkProviderConfig',
      () {
        final MainnetEntrypoint entry = MainnetEntrypoint(
          clientName: 'my-dapp',
        );
        expect(entry.networkProviderConfig, isNotNull);
        expect(entry.networkProviderConfig!.clientName, equals('my-dapp'));
      },
    );

    test(
      'clientName overrides the one inside a supplied networkProviderConfig',
      () {
        final MainnetEntrypoint entry = MainnetEntrypoint(
          networkProviderConfig: const NetworkProviderConfig(
            clientName: 'old-name',
          ),
          clientName: 'new-name',
        );
        expect(entry.networkProviderConfig!.clientName, equals('new-name'));
      },
    );

    test('no clientName + no config leaves networkProviderConfig null', () {
      final DevnetEntrypoint entry = DevnetEntrypoint();
      expect(entry.networkProviderConfig, isNull);
    });
  });

  group('NetworkProviderConfig reaches the constructed provider', () {
    test('API entrypoint forwards the whole config to ApiNetworkProvider', () {
      final MainnetEntrypoint entry = MainnetEntrypoint(
        networkProviderConfig: _fullConfig,
      );
      final ApiNetworkProvider provider = entry.createNetworkProvider();

      expect(provider.config, isNotNull);
      expect(identical(provider.config, _fullConfig), isTrue);
      expect(provider.config!.clientName, equals('cfg-name'));
      expect(
        provider.config!.requestTimeout,
        equals(const Duration(seconds: 11)),
      );
      expect(provider.config!.throttlePolicy.enabled, isTrue);
      expect(provider.config!.throttlePolicy.capacity, equals(2));
      expect(provider.config!.cachePolicy.enabled, isTrue);
    });

    test(
      'Proxy entrypoint forwards the whole config to GatewayNetworkProvider',
      () {
        final MainnetProxyEntrypoint entry = MainnetProxyEntrypoint(
          networkProviderConfig: _fullConfig,
        );
        final GatewayNetworkProvider provider = entry.createNetworkProvider();

        expect(provider.config, isNotNull);
        expect(identical(provider.config, _fullConfig), isTrue);
        expect(provider.config!.clientName, equals('cfg-name'));
        expect(
          provider.config!.requestTimeout,
          equals(const Duration(seconds: 11)),
        );
        expect(provider.config!.headers, equals(<String, String>{'X-T': '1'}));
        expect(provider.config!.retryPolicy.enabled, isTrue);
        expect(provider.config!.throttlePolicy.enabled, isTrue);
        expect(provider.config!.throttlePolicy.capacity, equals(2));
        expect(provider.config!.throttlePolicy.refillPerSecond, equals(2.0));
        expect(provider.config!.cachePolicy.enabled, isTrue);
        expect(
          provider.config!.cachePolicy.defaultConfig!.ttl,
          equals(const Duration(minutes: 30)),
        );
      },
    );

    test('Devnet proxy entrypoint forwards its config too', () {
      final DevnetProxyEntrypoint entry = DevnetProxyEntrypoint(
        networkProviderConfig: _fullConfig,
      );
      expect(entry.createNetworkProvider().config, isNotNull);
      expect(
        entry.createNetworkProvider().config!.throttlePolicy.capacity,
        equals(2),
      );
    });

    test('Testnet proxy entrypoint forwards its config too', () {
      final TestnetProxyEntrypoint entry = TestnetProxyEntrypoint(
        networkProviderConfig: _fullConfig,
      );
      expect(entry.createNetworkProvider().config, isNotNull);
      expect(entry.createNetworkProvider().config!.cachePolicy.enabled, isTrue);
    });

    test('Proxy entrypoint without a config leaves provider.config null', () {
      final MainnetProxyEntrypoint entry = MainnetProxyEntrypoint();
      expect(entry.createNetworkProvider().config, isNull);
    });

    test('Proxy entrypoint clientName alone reaches the provider', () {
      final MainnetProxyEntrypoint entry = MainnetProxyEntrypoint(
        clientName: 'solo-name',
      );
      expect(
        entry.createNetworkProvider().config!.clientName,
        equals('solo-name'),
      );
    });
  });

  group('clientName merge preserves every other config field', () {
    test('API entrypoint: clientName + config keeps all seven fields', () {
      final MainnetEntrypoint entry = MainnetEntrypoint(
        networkProviderConfig: _fullConfig,
        clientName: 'override-name',
      );
      final NetworkProviderConfig merged = entry.networkProviderConfig!;

      expect(merged.clientName, equals('override-name'));
      expect(merged.headers, equals(<String, String>{'X-T': '1'}));
      expect(merged.requestTimeout, equals(const Duration(seconds: 11)));
      expect(merged.baseUrl, equals('https://override.example'));
      expect(merged.retryPolicy.enabled, isTrue);
      expect(merged.throttlePolicy.enabled, isTrue);
      expect(merged.throttlePolicy.capacity, equals(2));
      expect(merged.throttlePolicy.refillPerSecond, equals(2.0));
      expect(merged.cachePolicy.enabled, isTrue);
      expect(
        merged.cachePolicy.defaultConfig!.ttl,
        equals(const Duration(minutes: 30)),
      );
      expect(
        merged.cachePolicy.endpointConfigs['network/config']!.ttl,
        equals(const Duration(minutes: 1)),
      );
    });

    test('Proxy entrypoint: clientName + config keeps all seven fields', () {
      final MainnetProxyEntrypoint entry = MainnetProxyEntrypoint(
        networkProviderConfig: _fullConfig,
        clientName: 'override-name',
      );
      final NetworkProviderConfig merged = entry.networkProviderConfig!;

      expect(merged.clientName, equals('override-name'));
      expect(merged.headers, equals(<String, String>{'X-T': '1'}));
      expect(merged.requestTimeout, equals(const Duration(seconds: 11)));
      expect(merged.baseUrl, equals('https://override.example'));
      expect(merged.retryPolicy.enabled, isTrue);
      expect(merged.throttlePolicy.enabled, isTrue);
      expect(merged.throttlePolicy.capacity, equals(2));
      expect(merged.cachePolicy.enabled, isTrue);
    });

    test('merged config is the one handed to the provider', () {
      final MainnetProxyEntrypoint proxy = MainnetProxyEntrypoint(
        networkProviderConfig: const NetworkProviderConfig(
          clientName: 'old-name',
          throttlePolicy: ThrottlePolicy.gateway(),
          cachePolicy: ResponseCachePolicy.enabled(),
        ),
        clientName: 'new-name',
      );
      final NetworkProviderConfig onProvider = proxy
          .createNetworkProvider()
          .config!;

      expect(onProvider.clientName, equals('new-name'));
      expect(onProvider.throttlePolicy.enabled, isTrue);
      expect(onProvider.throttlePolicy.capacity, equals(50));
      expect(onProvider.throttlePolicy.refillPerSecond, equals(50.0));
      expect(onProvider.cachePolicy.enabled, isTrue);
    });

    test('merging a disabled-policy config keeps the policies disabled', () {
      final DevnetEntrypoint entry = DevnetEntrypoint(
        networkProviderConfig: const NetworkProviderConfig(
          headers: <String, String>{'A': 'B'},
        ),
        clientName: 'name',
      );
      final NetworkProviderConfig merged = entry.networkProviderConfig!;

      expect(merged.clientName, equals('name'));
      expect(merged.headers, equals(<String, String>{'A': 'B'}));
      expect(merged.retryPolicy.enabled, isFalse);
      expect(merged.throttlePolicy.enabled, isFalse);
      expect(merged.cachePolicy.enabled, isFalse);
    });
  });
}

/// Config exercising every field of `NetworkProviderConfig`, so a merge or a
/// forward that drops one is caught by an exact-value assertion.
const NetworkProviderConfig _fullConfig = NetworkProviderConfig(
  clientName: 'cfg-name',
  headers: <String, String>{'X-T': '1'},
  requestTimeout: Duration(seconds: 11),
  baseUrl: 'https://override.example',
  retryPolicy: RetryPolicy.enabled(),
  throttlePolicy: ThrottlePolicy.api(),
  cachePolicy: ResponseCachePolicy.enabled(
    defaultConfig: CacheConfig.long,
    endpointConfigs: <String, CacheConfig>{'network/config': CacheConfig.short},
  ),
);
