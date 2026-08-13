/// Route-table and configuration regression tests for
/// [GatewayNetworkProvider] (audit findings F5.1, F5.2, F5.3, F5.4).
///
/// Every path is asserted against a literal string rather than against the
/// expression the provider itself uses, so a future edit to a route fails here
/// instead of on the wire. The wire-level group binds a loopback [HttpServer]
/// and records the exact request line the provider produced.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

/// Surfaces the `protected` route hooks, parsers and owned Dio client.
class _ExposedGateway extends GatewayNetworkProvider {
  _ExposedGateway({
    required super.baseUrl,
    required super.chainId,
    super.config,
  });

  Dio get exposedDio => dio;

  String exposedAccountEndpoint(Address address) => accountEndpoint(address);

  String exposedAccountStorageEndpoint(Address address) =>
      accountStorageEndpoint(address);

  String exposedAccountStorageKeyEndpoint(Address address, String keyHex) =>
      accountStorageKeyEndpoint(address, keyHex);

  String exposedSendTransactionEndpoint() => sendTransactionEndpoint();

  String exposedSendMultipleTransactionsEndpoint() =>
      sendMultipleTransactionsEndpoint();

  String exposedQueryContractEndpoint() => queryContractEndpoint();

  String exposedNetworkStatusEndpoint({int shard = 4294967295}) =>
      networkStatusEndpoint(shard: shard);

  String exposedGetTransactionEndpoint(String txHash) =>
      getTransactionEndpoint(txHash);

  String exposedGetTransactionEndpointWithProcessStatus(String txHash) =>
      getTransactionEndpoint(txHash, withProcessStatus: true);

  String exposedGetTransactionStatusEndpoint(String txHash) =>
      getTransactionStatusEndpoint(txHash);

  String exposedSimulateTransactionEndpoint() => simulateTransactionEndpoint();

  String exposedTokenOfAccountEndpoint(Address address, String identifier) =>
      tokenOfAccountEndpoint(address, identifier);

  String exposedNftOfAccountEndpoint(
    Address address,
    String collection,
    int nonce,
  ) => nftOfAccountEndpoint(address, collection, nonce);

  String exposedFungibleTokensEndpoint(Address address) =>
      fungibleTokensEndpoint(address);

  String exposedNonFungibleTokensEndpoint(Address address) =>
      nonFungibleTokensEndpoint(address);

  String exposedGuardianDataEndpoint(Address address) =>
      guardianDataEndpoint(address);

  String exposedBlockByHashEndpoint(int shard, String hash) =>
      blockByHashEndpoint(shard, hash);

  String exposedLatestBlockEndpoint(int shard) => latestBlockEndpoint(shard);

  String exposedHyperblockByNonceEndpoint(int nonce) =>
      hyperblockByNonceEndpoint(nonce);

  String exposedFungibleTokenDefinitionEndpoint(String identifier) =>
      fungibleTokenDefinitionEndpoint(identifier);

  String exposedTokenCollectionDefinitionEndpoint(String collection) =>
      tokenCollectionDefinitionEndpoint(collection);

  String exposedNonFungibleInstanceEndpoint(String collection, int nonce) =>
      nonFungibleInstanceEndpoint(collection, nonce);

  List<TokenOnNetwork> exposedParseFungibleTokens(dynamic response) =>
      parseFungibleTokens(response);

  List<TokenOnNetwork> exposedParseNonFungibleTokens(dynamic response) =>
      parseNonFungibleTokens(response);
}

const String _bech32 =
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th';

/// Canned `GET /address/{bech32}/esdt` payload: two fungible entries
/// (`nonce == 0`) followed by one non-fungible entry (`nonce == 1`).
const Map<String, dynamic> _esdtsPayload = <String, dynamic>{
  'esdts': <String, dynamic>{
    'TOK-abcdef': <String, dynamic>{
      'tokenIdentifier': 'TOK-abcdef',
      'balance': '1000',
      'nonce': 0,
    },
    'XTOK-123456': <String, dynamic>{
      'tokenIdentifier': 'XTOK-123456',
      'balance': '250',
      'nonce': 0,
    },
    'COLL-123456-01': <String, dynamic>{
      'tokenIdentifier': 'COLL-123456-01',
      'balance': '1',
      'nonce': 1,
    },
  },
};

void main() {
  final Address address = Address.fromBech32(_bech32);

  group('Gateway route table', () {
    late _ExposedGateway gateway;

    setUp(() {
      gateway = _ExposedGateway(
        baseUrl: 'https://devnet-gateway.multiversx.com',
        chainId: const ChainId('D'),
      );
    });

    tearDown(() => gateway.close());

    test('account routes match the proxy accounts group', () {
      expect(
        gateway.exposedAccountEndpoint(address),
        'address/erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
      );
      expect(
        gateway.exposedAccountStorageEndpoint(address),
        'address/erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th/keys',
      );
      expect(
        gateway.exposedAccountStorageKeyEndpoint(address, 'a1b2c3'),
        'address/erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th/key/a1b2c3',
      );
      expect(
        gateway.exposedGuardianDataEndpoint(address),
        'address/erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th/guardian-data',
      );
    });

    test('nonFungibleTokensEndpoint uses /esdt, never the 404 /nft leaf', () {
      expect(
        gateway.exposedNonFungibleTokensEndpoint(address),
        'address/erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th/esdt',
        reason:
            'The proxy registers no /address/:address/nft leaf route; '
            'listing NFTs reads the same /esdt payload as fungible tokens',
      );
      expect(
        gateway.exposedNonFungibleTokensEndpoint(address),
        isNot(contains('/nft')),
      );
      expect(
        gateway.exposedFungibleTokensEndpoint(address),
        'address/erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th/esdt',
      );
    });

    test('token balance routes split fungible and nonce-bearing lookups', () {
      expect(
        gateway.exposedTokenOfAccountEndpoint(address, 'TOK-abcdef'),
        'address/erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th/esdt/TOK-abcdef',
      );
      expect(
        gateway.exposedNftOfAccountEndpoint(address, 'COLL-123456', 3),
        'address/erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th/nft/COLL-123456/nonce/3',
      );
      expect(
        gateway.exposedNftOfAccountEndpoint(address, 'COLL-123456', 255),
        'address/erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th/nft/COLL-123456/nonce/255',
      );
    });

    test('transaction routes always request the full result set', () {
      expect(
        gateway.exposedGetTransactionEndpoint('abc123'),
        'transaction/abc123?withResults=true',
        reason:
            'Without withResults the proxy omits logs and '
            'smartContractResults, which TransactionWatcher needs',
      );
      expect(
        gateway.exposedGetTransactionEndpointWithProcessStatus('abc123'),
        'transaction/abc123?withResults=true',
      );
      expect(
        gateway.exposedGetTransactionStatusEndpoint('abc123'),
        'transaction/abc123/process-status',
      );
      expect(gateway.exposedSendTransactionEndpoint(), 'transaction/send');
      expect(
        gateway.exposedSendMultipleTransactionsEndpoint(),
        'transaction/send-multiple',
      );
      expect(
        gateway.exposedSimulateTransactionEndpoint(),
        'transaction/simulate?checkSignature=false',
      );
    });

    test('network, block and vm routes match the proxy groups', () {
      expect(gateway.exposedQueryContractEndpoint(), 'vm-values/query');
      expect(
        gateway.exposedNetworkStatusEndpoint(),
        'network/status/4294967295',
      );
      expect(
        gateway.exposedNetworkStatusEndpoint(shard: 2),
        'network/status/2',
      );
      expect(gateway.exposedLatestBlockEndpoint(1), 'network/status/1');
      expect(
        gateway.exposedBlockByHashEndpoint(0, 'deadbeef'),
        'block/0/by-hash/deadbeef',
      );
      expect(
        gateway.exposedHyperblockByNonceEndpoint(42),
        'hyperblock/by-nonce/42',
      );
    });

    test('routes absent from the proxy still throw UnsupportedError', () {
      expect(
        () => gateway.exposedFungibleTokenDefinitionEndpoint('TOK-abcdef'),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => gateway.exposedTokenCollectionDefinitionEndpoint('COLL-123456'),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => gateway.exposedNonFungibleInstanceEndpoint('COLL-123456', 1),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('the shared /esdt payload is split by nonce', () {
      final List<TokenOnNetwork> fungible = gateway.exposedParseFungibleTokens(
        _esdtsPayload,
      );
      final List<TokenOnNetwork> nonFungible = gateway
          .exposedParseNonFungibleTokens(_esdtsPayload);

      expect(
        fungible.map((TokenOnNetwork t) => t.identifier).toList(),
        <String>['TOK-abcdef', 'XTOK-123456'],
      );
      expect(fungible.first.balance, '1000');
      expect(
        nonFungible.map((TokenOnNetwork t) => t.identifier).toList(),
        <String>['COLL-123456-01'],
      );
      expect(nonFungible.single.nonce, 1);
      expect(nonFungible.single.balance, '1');
    });
  });

  group('Gateway economics', () {
    test('getNetworkEconomics still refuses the market-data contract', () {
      final GatewayNetworkProvider gateway = GatewayNetworkProvider.devnet();
      expect(gateway.getNetworkEconomics, throwsA(isA<UnsupportedError>()));
      gateway.close();
    });

    test('fromProxyResponse keeps atomic supply as BigInt', () {
      final GatewayEconomics economics = GatewayEconomics.fromProxyResponse(
        <String, dynamic>{
          'metrics': <String, dynamic>{
            'erd_total_supply': '20000000000000000000000000',
            'erd_total_fees': '123',
            'erd_inflation': '456',
            'erd_dev_rewards': '789',
            'erd_epoch_for_economics_data': 263,
            'erd_total_base_staked_value': '1',
            'erd_total_top_up_value': '2',
          },
        },
      );

      expect(
        economics.totalSupply,
        BigInt.parse('20000000000000000000000000'),
        reason: '2e25 atomic units overflow a 64-bit int',
      );
      expect(economics.totalFees, BigInt.from(123));
      expect(economics.inflation, BigInt.from(456));
      expect(economics.devRewards, BigInt.from(789));
      expect(economics.epochForEconomicsData, 263);
      expect(economics.totalBaseStakedValue, BigInt.one);
      expect(economics.totalTopUpValue, BigInt.two);
      expect(economics.raw['erd_total_fees'], '123');
    });

    test('fromProxyResponse accepts a bare metrics map and missing keys', () {
      final GatewayEconomics economics = GatewayEconomics.fromProxyResponse(
        <String, dynamic>{'erd_total_supply': '7'},
      );

      expect(economics.totalSupply, BigInt.from(7));
      expect(economics.totalFees, BigInt.zero);
      expect(economics.epochForEconomicsData, 0);
    });
  });

  group('Gateway NetworkProviderConfig forwarding', () {
    test('owned Dio receives the user agent, timeout and custom headers', () {
      final _ExposedGateway gateway = _ExposedGateway(
        baseUrl: 'https://devnet-gateway.multiversx.com',
        chainId: const ChainId('D'),
        config: const NetworkProviderConfig(
          clientName: 'my-dapp',
          requestTimeout: Duration(seconds: 7),
          headers: <String, String>{'X-T': '1'},
        ),
      );

      expect(
        gateway.exposedDio.options.headers['User-Agent'],
        'multiversx-sdk-dart/my-dapp',
      );
      expect(
        gateway.exposedDio.options.connectTimeout,
        const Duration(seconds: 7),
      );
      expect(
        gateway.exposedDio.options.receiveTimeout,
        const Duration(seconds: 7),
      );
      expect(
        gateway.exposedDio.options.sendTimeout,
        const Duration(seconds: 7),
      );
      expect(gateway.exposedDio.options.headers['X-T'], '1');
      expect(gateway.config?.clientName, 'my-dapp');

      gateway.close();
    });

    test('mainnet, testnet and devnet factories forward the config', () {
      const NetworkProviderConfig config = NetworkProviderConfig(
        clientName: 'my-dapp',
        retryPolicy: RetryPolicy.enabled(),
      );

      final GatewayNetworkProvider mainnet = GatewayNetworkProvider.mainnet(
        config: config,
      );
      final GatewayNetworkProvider testnet = GatewayNetworkProvider.testnet(
        config: config,
      );
      final GatewayNetworkProvider devnet = GatewayNetworkProvider.devnet(
        config: config,
      );

      expect(mainnet.config?.clientName, 'my-dapp');
      expect(mainnet.config?.retryPolicy.enabled, isTrue);
      expect(testnet.config?.clientName, 'my-dapp');
      expect(devnet.config?.clientName, 'my-dapp');
      expect(devnet.baseUrl, 'https://devnet-gateway.multiversx.com');

      mainnet.close();
      testnet.close();
      devnet.close();
    });

    test('config.baseUrl overrides the factory endpoint', () {
      final GatewayNetworkProvider gateway = GatewayNetworkProvider.mainnet(
        config: const NetworkProviderConfig(
          baseUrl: 'https://my-proxy.example.com/',
        ),
      );

      expect(gateway.baseUrl, 'https://my-proxy.example.com');
      gateway.close();
    });
  });

  group('Gateway requests on the wire', () {
    late HttpServer server;
    late List<String> requestLines;
    late List<String> userAgents;
    late List<String> customHeaders;
    late String baseUrl;

    String bodyFor(String path) {
      Map<String, dynamic> data;
      if (path.endsWith('/esdt')) {
        data = _esdtsPayload;
      } else if (path.contains('/nft/')) {
        data = <String, dynamic>{
          'tokenData': <String, dynamic>{
            'tokenIdentifier': 'COLL-123456',
            'balance': '7',
            'nonce': 3,
            'creator': _bech32,
          },
        };
      } else if (path == '/network/economics') {
        data = <String, dynamic>{
          'metrics': <String, dynamic>{
            'erd_total_supply': '20000000000000000000000000',
            'erd_total_fees': '123',
            'erd_epoch_for_economics_data': 263,
          },
        };
      } else if (path.startsWith('/transaction/')) {
        data = <String, dynamic>{
          'transaction': <String, dynamic>{
            'sender': _bech32,
            'receiver': _bech32,
            'value': '0',
            'nonce': 1,
            'gasLimit': 50000000,
            'gasPrice': 1000000000,
            'chainID': 'D',
            'version': 1,
            'status': 'success',
            'smartContractResults': <Map<String, dynamic>>[
              <String, dynamic>{
                'hash': 'scrhash',
                'nonce': 0,
                'value': '0',
                'sender': _bech32,
                'receiver': _bech32,
                'data': '@6f6b@2a',
                'gasLimit': 0,
                'gasPrice': 1000000000,
                'callType': 0,
              },
            ],
          },
        };
      } else {
        data = <String, dynamic>{};
      }
      return jsonEncode(<String, dynamic>{
        'data': data,
        'error': '',
        'code': 'successful',
      });
    }

    setUp(() async {
      requestLines = <String>[];
      userAgents = <String>[];
      customHeaders = <String>[];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUrl = 'http://127.0.0.1:${server.port}';
      server.listen((HttpRequest request) {
        requestLines.add(request.uri.toString());
        userAgents.add(
          request.headers.value(HttpHeaders.userAgentHeader) ?? '',
        );
        customHeaders.add(request.headers.value('x-t') ?? '');
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(bodyFor(request.uri.path));
        unawaited(request.response.close());
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test(
      'listing NFTs hits /address/{bech32}/esdt and filters by nonce',
      () async {
        final GatewayNetworkProvider gateway = GatewayNetworkProvider(
          baseUrl: baseUrl,
          chainId: const ChainId('D'),
        );

        final List<TokenOnNetwork> nfts = await gateway
            .getNonFungibleTokensOfAccount(address);

        expect(requestLines, <String>[
          '/address/erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th/esdt',
        ]);
        expect(nfts.single.identifier, 'COLL-123456-01');
        expect(nfts.single.balance, '1');
        expect(nfts.single.nonce, 1);

        gateway.close();
      },
    );

    test(
      'pagination is applied client-side, never as a query string',
      () async {
        final GatewayNetworkProvider gateway = GatewayNetworkProvider(
          baseUrl: baseUrl,
          chainId: const ChainId('D'),
        );

        final List<TokenOnNetwork> all = await gateway
            .getFungibleTokensOfAccount(address);
        final List<TokenOnNetwork> firstOnly = await gateway
            .getFungibleTokensOfAccount(address, size: 1);
        final List<TokenOnNetwork> secondOnly = await gateway
            .getFungibleTokensOfAccount(address, from: 1);
        final List<TokenOnNetwork> beyondEnd = await gateway
            .getFungibleTokensOfAccount(address, from: 9, size: 5);

        expect(all.map((TokenOnNetwork t) => t.identifier).toList(), <String>[
          'TOK-abcdef',
          'XTOK-123456',
        ]);
        expect(firstOnly.single.identifier, 'TOK-abcdef');
        expect(firstOnly.single.balance, '1000');
        expect(secondOnly.single.identifier, 'XTOK-123456');
        expect(secondOnly.single.balance, '250');
        expect(beyondEnd, isEmpty);
        expect(
          requestLines,
          everyElement(
            '/address/erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th/esdt',
          ),
          reason:
              'The proxy ignores unknown query params, so from/size must not '
              'reach the wire',
        );
        expect(requestLines.length, 4);

        gateway.close();
      },
    );

    test(
      'getNftOfAccount reads the nonce route and normalises the id',
      () async {
        final GatewayNetworkProvider gateway = GatewayNetworkProvider(
          baseUrl: baseUrl,
          chainId: const ChainId('D'),
        );

        final TokenOnNetwork nft = await gateway.getNftOfAccount(
          address,
          'COLL-123456',
          3,
        );

        expect(requestLines, <String>[
          '/address/erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th/nft/COLL-123456/nonce/3',
        ]);
        expect(nft.identifier, 'COLL-123456-03');
        expect(nft.balance, '7');
        expect(nft.nonce, 3);

        gateway.close();
      },
    );

    test(
      'getTransaction requests withResults=true without being asked',
      () async {
        final GatewayNetworkProvider gateway = GatewayNetworkProvider(
          baseUrl: baseUrl,
          chainId: const ChainId('D'),
        );

        final TransactionOnNetwork tx = await gateway.getTransaction('abc123');

        expect(requestLines, <String>['/transaction/abc123?withResults=true']);
        expect(tx.smartContractResults, hasLength(1));
        expect(tx.smartContractResults!.single.returnCode.code, 'ok');

        gateway.close();
      },
    );

    test('getGatewayEconomics reads /network/economics as BigInt', () async {
      final GatewayNetworkProvider gateway = GatewayNetworkProvider(
        baseUrl: baseUrl,
        chainId: const ChainId('D'),
      );

      final GatewayEconomics economics = await gateway.getGatewayEconomics();

      expect(requestLines, <String>['/network/economics']);
      expect(economics.totalSupply, BigInt.parse('20000000000000000000000000'));
      expect(economics.totalFees, BigInt.from(123));
      expect(economics.epochForEconomicsData, 263);

      gateway.close();
    });

    test('NetworkProviderConfig headers reach the gateway request', () async {
      final GatewayNetworkProvider gateway = GatewayNetworkProvider(
        baseUrl: baseUrl,
        chainId: const ChainId('D'),
        config: const NetworkProviderConfig(
          clientName: 'my-dapp',
          requestTimeout: Duration(seconds: 7),
          headers: <String, String>{'X-T': '1'},
        ),
      );

      await gateway.getFungibleTokensOfAccount(address);

      expect(userAgents, <String>['multiversx-sdk-dart/my-dapp']);
      expect(customHeaders, <String>['1']);

      gateway.close();
    });

    test(
      'without a config the request carries the unknown-client agent',
      () async {
        final GatewayNetworkProvider gateway = GatewayNetworkProvider(
          baseUrl: baseUrl,
          chainId: const ChainId('D'),
        );

        await gateway.getFungibleTokensOfAccount(address);

        expect(userAgents, <String>['multiversx-sdk-dart/unknown']);
        expect(customHeaders, <String>['']);

        gateway.close();
      },
    );
  });
}
