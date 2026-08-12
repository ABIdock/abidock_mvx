/// Tests for the opt-in `NetworkProviderConfig` policies wired into
/// [BaseNetworkProvider] — request throttling, `GET` response caching — plus
/// the account-listing pagination the API hosts require and the Gateway's
/// process-status overlay.
///
/// Every route, query string and policy value is asserted against a literal,
/// never against the constant the provider itself reads, so a regression in
/// either cannot make the assertions agree with themselves.
import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

/// Bech32 address reused across the assertions.
const String _alice =
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th';

/// Contract address used as the receiver in transaction fixtures.
const String _contract =
    'erd1qqqqqqqqqqqqqpgq6wegs2xkypfpync8mn2sa5cmpqjlvrhwz5nqgepyg8';

/// Dio adapter that records every request and replays a per-path body.
class _RoutedAdapter implements HttpClientAdapter {
  /// Creates an adapter replaying `bodies[path]` for each request path.
  _RoutedAdapter(this.bodies);

  /// JSON-encodable payload per request path, e.g. `'/network/config'`.
  final Map<String, Object> bodies;

  /// Absolute request URIs seen, in order.
  final List<String> uris = <String>[];

  /// HTTP methods seen, in order.
  final List<String> methods = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    uris.add(options.uri.toString());
    methods.add(options.method);
    return ResponseBody.fromString(
      jsonEncode(bodies[options.uri.path] ?? <String, dynamic>{}),
      200,
      headers: const <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Builds an API provider whose HTTP traffic is captured by `adapter`.
ApiNetworkProvider _apiWith(
  _RoutedAdapter adapter, {
  NetworkProviderConfig? config,
}) {
  final Dio dio = Dio();
  dio.httpClientAdapter = adapter;
  return ApiNetworkProvider(
    baseUrl: 'https://api.example.test',
    chainId: const ChainId('D'),
    client: dio,
    config: config,
  );
}

/// Builds a Gateway provider whose HTTP traffic is captured by `adapter`.
GatewayNetworkProvider _gatewayWith(
  _RoutedAdapter adapter, {
  NetworkProviderConfig? config,
}) {
  final Dio dio = Dio();
  dio.httpClientAdapter = adapter;
  return GatewayNetworkProvider(
    baseUrl: 'https://gw.example.test',
    chainId: const ChainId('D'),
    client: dio,
    config: config,
  );
}

/// Canned `GET /accounts/{bech32}` body.
const Map<String, dynamic> _accountBody = <String, dynamic>{
  'address': _alice,
  'nonce': 7,
  'balance': '1000000000000000000',
};

/// Builds a minimal transaction for the POST routes.
Transaction _sampleTransaction() {
  return Transaction(
    nonce: const Nonce(7),
    sender: Address.fromBech32(_alice),
    receiver: Address.fromBech32(_contract),
    value: Balance.fromString('0'),
    gasLimit: const GasLimit(60000000),
    gasPrice: const GasPrice(1000000000),
    chainId: const ChainId('D'),
    version: const TransactionVersion(1),
    data: Uint8List(0),
  );
}

void main() {
  final Address alice = Address.fromBech32(_alice);

  group('NetworkProviderConfig policy defaults', () {
    test('every resilience policy is off on the bare constructor', () {
      const NetworkProviderConfig config = NetworkProviderConfig();

      expect(config.retryPolicy.enabled, isFalse);
      expect(config.throttlePolicy.enabled, isFalse);
      expect(config.throttlePolicy.capacity, isNull);
      expect(config.throttlePolicy.refillPerSecond, isNull);
      expect(config.cachePolicy.enabled, isFalse);
      expect(config.cachePolicy.defaultConfig, isNull);
      expect(config.cachePolicy.endpointConfigs, isEmpty);
    });

    test('ThrottlePolicy.gateway carries 50 requests per second', () {
      const ThrottlePolicy policy = ThrottlePolicy.gateway();

      expect(policy.enabled, isTrue);
      expect(policy.capacity, 50);
      expect(policy.refillPerSecond, 50.0);
    });

    test('ThrottlePolicy.api carries 2 requests per second', () {
      const ThrottlePolicy policy = ThrottlePolicy.api();

      expect(policy.enabled, isTrue);
      expect(policy.capacity, 2);
      expect(policy.refillPerSecond, 2.0);
    });

    test('ThrottlePolicy.enabled keeps the supplied numbers verbatim', () {
      const ThrottlePolicy policy = ThrottlePolicy.enabled(
        capacity: 7,
        refillPerSecond: 3.5,
      );

      expect(policy.capacity, 7);
      expect(policy.refillPerSecond, 3.5);
    });

    test('ResponseCachePolicy.enabled defaults to a one-minute TTL', () {
      const ResponseCachePolicy policy = ResponseCachePolicy.enabled();

      expect(policy.enabled, isTrue);
      expect(policy.defaultConfig!.ttl, const Duration(minutes: 1));
      expect(policy.endpointConfigs, isEmpty);
    });
  });

  group('default construction path is unchanged', () {
    test('a provider built without a config caches nothing', () async {
      final _RoutedAdapter adapter = _RoutedAdapter(<String, Object>{
        '/accounts/$_alice': _accountBody,
      });
      final ApiNetworkProvider provider = _apiWith(adapter);

      await provider.getAccount(alice);
      await provider.getAccount(alice);

      expect(adapter.uris, <String>[
        'https://api.example.test/accounts/'
            'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th'
            '?withGuardianInfo=true',
        'https://api.example.test/accounts/'
            'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th'
            '?withGuardianInfo=true',
      ]);
    });

    test('a provider built without a config throttles nothing', () async {
      final _RoutedAdapter adapter = _RoutedAdapter(<String, Object>{
        '/accounts/$_alice': _accountBody,
      });
      final ApiNetworkProvider provider = _apiWith(adapter);

      final Stopwatch watch = Stopwatch()..start();
      for (int i = 0; i < 6; i++) {
        await provider.getAccount(alice);
      }
      watch.stop();

      expect(adapter.uris, hasLength(6));
      expect(watch.elapsedMilliseconds, lessThan(200));
    });

    test('an explicit all-default config behaves like no config', () async {
      final _RoutedAdapter adapter = _RoutedAdapter(<String, Object>{
        '/accounts/$_alice': _accountBody,
      });
      final ApiNetworkProvider provider = _apiWith(
        adapter,
        config: const NetworkProviderConfig(clientName: 'my-dapp'),
      );

      await provider.getAccount(alice);
      await provider.getAccount(alice);

      expect(adapter.uris, hasLength(2));
    });
  });

  group('opt-in response cache', () {
    test('a second identical GET never reaches the wire', () async {
      final _RoutedAdapter adapter = _RoutedAdapter(<String, Object>{
        '/accounts/$_alice': _accountBody,
      });
      final ApiNetworkProvider provider = _apiWith(
        adapter,
        config: const NetworkProviderConfig(
          cachePolicy: ResponseCachePolicy.enabled(),
        ),
      );

      final AccountOnNetwork first = await provider.getAccount(alice);
      final AccountOnNetwork second = await provider.getAccount(alice);

      expect(adapter.uris, <String>[
        'https://api.example.test/accounts/'
            'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th'
            '?withGuardianInfo=true',
      ]);
      expect(first.nonce.value, 7);
      expect(second.nonce.value, 7);
    });

    test('a successful POST drops the cache', () async {
      final _RoutedAdapter adapter = _RoutedAdapter(<String, Object>{
        '/accounts/$_alice': _accountBody,
        '/transactions': <String, dynamic>{'txHash': 'aabbcc'},
      });
      final ApiNetworkProvider provider = _apiWith(
        adapter,
        config: const NetworkProviderConfig(
          cachePolicy: ResponseCachePolicy.enabled(),
        ),
      );

      await provider.getAccount(alice);
      await provider.getAccount(alice);
      final String txHash = await provider.sendTransaction(
        _sampleTransaction(),
      );
      await provider.getAccount(alice);

      expect(txHash, 'aabbcc');
      expect(adapter.methods, <String>['GET', 'POST', 'GET']);
      expect(adapter.uris.last, endsWith('?withGuardianInfo=true'));
    });

    test('clearResponseCache forces the next GET back onto the wire', () async {
      final _RoutedAdapter adapter = _RoutedAdapter(<String, Object>{
        '/accounts/$_alice': _accountBody,
      });
      final ApiNetworkProvider provider = _apiWith(
        adapter,
        config: const NetworkProviderConfig(
          cachePolicy: ResponseCachePolicy.enabled(),
        ),
      );

      await provider.getAccount(alice);
      await provider.getAccount(alice);
      provider.clearResponseCache();
      await provider.getAccount(alice);

      expect(adapter.uris, hasLength(2));
    });

    test('a disabled cache policy leaves every GET on the wire', () async {
      final _RoutedAdapter adapter = _RoutedAdapter(<String, Object>{
        '/accounts/$_alice': _accountBody,
      });
      final ApiNetworkProvider provider = _apiWith(
        adapter,
        config: const NetworkProviderConfig(
          cachePolicy: ResponseCachePolicy.disabled(),
        ),
      );

      await provider.getAccount(alice);
      await provider.getAccount(alice);

      expect(adapter.uris, hasLength(2));
    });
  });

  group('opt-in request throttle', () {
    test('a one-token bucket spaces requests by the refill period', () async {
      final _RoutedAdapter adapter = _RoutedAdapter(<String, Object>{
        '/accounts/$_alice': _accountBody,
      });
      final ApiNetworkProvider provider = _apiWith(
        adapter,
        config: const NetworkProviderConfig(
          throttlePolicy: ThrottlePolicy.enabled(
            capacity: 1,
            refillPerSecond: 5,
          ),
        ),
      );

      final Stopwatch watch = Stopwatch()..start();
      await provider.getAccount(alice);
      await provider.getAccount(alice);
      watch.stop();

      expect(adapter.uris, hasLength(2));
      expect(
        watch.elapsedMilliseconds,
        greaterThanOrEqualTo(150),
        reason:
            'The second request must wait for the bucket to refill at '
            '5 tokens per second',
      );
    });

    test('the throttle also gates POST traffic', () async {
      final _RoutedAdapter adapter = _RoutedAdapter(<String, Object>{
        '/accounts/$_alice': _accountBody,
        '/transactions': <String, dynamic>{'txHash': 'aabbcc'},
      });
      final ApiNetworkProvider provider = _apiWith(
        adapter,
        config: const NetworkProviderConfig(
          throttlePolicy: ThrottlePolicy.enabled(
            capacity: 1,
            refillPerSecond: 5,
          ),
        ),
      );

      final Stopwatch watch = Stopwatch()..start();
      await provider.getAccount(alice);
      await provider.sendTransaction(_sampleTransaction());
      watch.stop();

      expect(adapter.methods, <String>['GET', 'POST']);
      expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(150));
    });

    test('a burst within capacity is not delayed', () async {
      final _RoutedAdapter adapter = _RoutedAdapter(<String, Object>{
        '/accounts/$_alice': _accountBody,
      });
      final ApiNetworkProvider provider = _apiWith(
        adapter,
        config: const NetworkProviderConfig(
          throttlePolicy: ThrottlePolicy.gateway(),
        ),
      );

      final Stopwatch watch = Stopwatch()..start();
      for (int i = 0; i < 10; i++) {
        await provider.getAccount(alice);
      }
      watch.stop();

      expect(adapter.uris, hasLength(10));
      expect(watch.elapsedMilliseconds, lessThan(200));
    });
  });

  group('account listing pagination', () {
    test('the API listing routes always carry from=0 and size=100', () async {
      final _RoutedAdapter adapter = _RoutedAdapter(<String, Object>{
        '/accounts/$_alice/tokens': <Map<String, dynamic>>[],
        '/accounts/$_alice/nfts': <Map<String, dynamic>>[],
      });
      final ApiNetworkProvider provider = _apiWith(adapter);

      await provider.getFungibleTokensOfAccount(alice);
      await provider.getNonFungibleTokensOfAccount(alice);

      expect(adapter.uris, <String>[
        'https://api.example.test/accounts/'
            'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th'
            '/tokens?from=0&size=100',
        'https://api.example.test/accounts/'
            'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th'
            '/nfts?from=0&size=100',
      ]);
    });

    test('caller-supplied pagination wins over the default page', () async {
      final _RoutedAdapter adapter = _RoutedAdapter(<String, Object>{
        '/accounts/$_alice/tokens': <Map<String, dynamic>>[],
      });
      final ApiNetworkProvider provider = _apiWith(adapter);

      await provider.getFungibleTokensOfAccount(alice, from: 25, size: 10);
      await provider.getFungibleTokensOfAccount(alice, size: 5);

      expect(adapter.uris, <String>[
        'https://api.example.test/accounts/'
            'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th'
            '/tokens?from=25&size=10',
        'https://api.example.test/accounts/'
            'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th'
            '/tokens?from=0&size=5',
      ]);
    });

    test('the Gateway listing route stays free of query strings', () async {
      final _RoutedAdapter adapter = _RoutedAdapter(<String, Object>{
        '/address/$_alice/esdt': <String, dynamic>{
          'data': <String, dynamic>{'esdts': <String, dynamic>{}},
          'code': 'successful',
        },
      });
      final GatewayNetworkProvider provider = _gatewayWith(adapter);

      await provider.getFungibleTokensOfAccount(alice);
      await provider.getNonFungibleTokensOfAccount(alice);

      expect(adapter.uris, <String>[
        'https://gw.example.test/address/'
            'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th'
            '/esdt',
        'https://gw.example.test/address/'
            'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th'
            '/esdt',
      ]);
    });
  });

  group('Gateway process-status overlay', () {
    late _RoutedAdapter adapter;

    setUp(() {
      adapter = _RoutedAdapter(<String, Object>{
        '/transaction/abc123': <String, dynamic>{
          'data': <String, dynamic>{
            'transaction': <String, dynamic>{
              'sender': _alice,
              'receiver': _contract,
              'value': '0',
              'nonce': 1,
              'gasLimit': 50000000,
              'gasPrice': 1000000000,
              'chainID': 'D',
              'version': 1,
              'status': 'success',
            },
          },
          'code': 'successful',
        },
        '/transaction/abc123/process-status': <String, dynamic>{
          'data': <String, dynamic>{'status': 'fail', 'reason': 'signalError'},
          'code': 'successful',
        },
      });
    });

    test('getTransaction alone keeps the node status', () async {
      final GatewayNetworkProvider provider = _gatewayWith(adapter);

      final TransactionOnNetwork tx = await provider.getTransaction('abc123');

      expect(adapter.uris, <String>[
        'https://gw.example.test/transaction/abc123?withResults=true',
      ]);
      expect(tx.status.status, 'success');
      expect(tx.status.isSuccessful, isTrue);
    });

    test('the overlay replaces success with the proxy verdict', () async {
      final GatewayNetworkProvider provider = _gatewayWith(adapter);

      final TransactionOnNetwork tx = await provider
          .getTransactionWithProcessStatus('abc123');

      expect(adapter.uris, <String>[
        'https://gw.example.test/transaction/abc123?withResults=true',
        'https://gw.example.test/transaction/abc123/process-status',
      ]);
      expect(tx.status.status, 'fail');
      expect(tx.status.isFailed, isTrue);
      expect(tx.status.isSuccessful, isFalse);
      expect(tx.status.isFinal, isTrue);
      expect(tx.txHash, 'abc123');
      expect(tx.sender.bech32, _alice);
    });
  });
}
