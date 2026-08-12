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
}
