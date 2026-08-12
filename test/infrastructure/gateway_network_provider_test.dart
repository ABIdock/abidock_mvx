import 'dart:convert';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

/// Exposes `protected` endpoint hooks so tests can pin the exact URL shape
/// without bringing up an HTTP server.
class _ExposedGateway extends GatewayNetworkProvider {
  _ExposedGateway({required super.baseUrl, required super.chainId});

  String exposedNetworkStatusEndpoint({int shard = 4294967295}) =>
      networkStatusEndpoint(shard: shard);

  String exposedBlockByHashEndpoint(int shard, String hash) =>
      blockByHashEndpoint(shard, hash);
}

class _ExposedApi extends ApiNetworkProvider {
  _ExposedApi({required super.baseUrl, required super.chainId});

  String exposedNetworkStatusEndpoint({int shard = 4294967295}) =>
      networkStatusEndpoint(shard: shard);

  String exposedBlockByHashEndpoint(int shard, String hash) =>
      blockByHashEndpoint(shard, hash);
}

void main() {
  group('Provider Creation & Configuration', () {
    test('creates mainnet provider', () {
      final gateway = GatewayNetworkProvider.mainnet();
      expect(gateway.baseUrl, 'https://gateway.multiversx.com');
      expect(gateway.chainId.value, '1');
      gateway.close();
    });

    test('creates testnet provider', () {
      final gateway = GatewayNetworkProvider.testnet();
      expect(gateway.baseUrl, 'https://testnet-gateway.multiversx.com');
      expect(gateway.chainId.value, 'T');
      gateway.close();
    });

    test('creates devnet provider', () {
      final gateway = GatewayNetworkProvider.devnet();
      expect(gateway.baseUrl, 'https://devnet-gateway.multiversx.com');
      expect(gateway.chainId.value, 'D');
      gateway.close();
    });

    test('creates custom provider', () {
      final customDio = Dio();
      final gateway = GatewayNetworkProvider(
        baseUrl: 'https://custom.gateway.com',
        chainId: const ChainId('T'),
        client: customDio,
        enableCircuitBreaker: true,
      );
      expect(gateway.baseUrl, 'https://custom.gateway.com');
      expect(gateway.chainId.value, 'T');
      expect(gateway.enableCircuitBreaker, true);
      gateway.close();
    });
  });

  group('Interface & Network Operations', () {
    test('implements NetworkProvider interface', () {
      final gateway = GatewayNetworkProvider.devnet();
      expect(gateway, isA<NetworkProvider>());
      gateway.close();
    });

    test('exposes standard methods', () {
      final gateway = GatewayNetworkProvider.devnet();

      expect(gateway.getNetworkConfig, isA<Function>());
      expect(gateway.getAccount, isA<Function>());
      expect(gateway.sendTransaction, isA<Function>());

      gateway.close();
    });
  });

  group('Advanced Features', () {
    test('supports circuit breaker', () {
      final gateway = GatewayNetworkProvider(
        baseUrl: 'https://gateway.multiversx.com',
        chainId: const ChainId('1'),
        enableCircuitBreaker: true,
      );
      expect(gateway.enableCircuitBreaker, true);
      gateway.close();
    });

    test('handles multiple instances', () {
      final gateway1 = GatewayNetworkProvider.mainnet();
      final gateway2 = GatewayNetworkProvider.testnet();
      expect(gateway1.chainId.value, '1');
      expect(gateway2.chainId.value, 'T');
      gateway1.close();
      gateway2.close();
    });
  });

  group('Compatibility & Integration', () {
    test('is compatible with ApiNetworkProvider interface', () {
      final gateway = GatewayNetworkProvider.devnet();
      expect(gateway, isA<NetworkProvider>());
      expect(gateway.baseUrl, contains('devnet'));
      gateway.close();
    });
  });

  group('Endpoint shape (C-9)', () {
    test(
      'Gateway networkStatusEndpoint threads the shard parameter into the URL',
      () {
        final gateway = _ExposedGateway(
          baseUrl: 'https://devnet-gateway.multiversx.com',
          chainId: const ChainId('D'),
        );

        expect(
          gateway.exposedNetworkStatusEndpoint(),
          'network/status/4294967295',
          reason: 'Default shard must be the metashard sentinel',
        );
        expect(
          gateway.exposedNetworkStatusEndpoint(shard: 0),
          'network/status/0',
        );
        expect(
          gateway.exposedNetworkStatusEndpoint(shard: 1),
          'network/status/1',
        );
        expect(
          gateway.exposedNetworkStatusEndpoint(shard: 2),
          'network/status/2',
        );

        gateway.close();
      },
    );

    test(
      'API networkStatusEndpoint threads the shard parameter into the URL',
      () {
        final api = _ExposedApi(
          baseUrl: 'https://devnet-api.multiversx.com',
          chainId: const ChainId('D'),
        );

        expect(api.exposedNetworkStatusEndpoint(), 'network/status/4294967295');
        expect(api.exposedNetworkStatusEndpoint(shard: 1), 'network/status/1');

        api.close();
      },
    );

    test('Gateway blockByHashEndpoint includes the shard '
        '(block/{shard}/by-hash/{hash})', () {
      final gateway = _ExposedGateway(
        baseUrl: 'https://devnet-gateway.multiversx.com',
        chainId: const ChainId('D'),
      );

      const String hash =
          'ded535cc0afb2dc1bbe6e9d9bf36e8e2a78b97e1cc4ad9b1c6f9d3f2b1a0c987';

      expect(
        gateway.exposedBlockByHashEndpoint(4294967295, hash),
        'block/4294967295/by-hash/$hash',
      );
      expect(
        gateway.exposedBlockByHashEndpoint(0, hash),
        'block/0/by-hash/$hash',
      );
      expect(
        gateway.exposedBlockByHashEndpoint(2, hash),
        'block/2/by-hash/$hash',
      );

      gateway.close();
    });

    test('API blockByHashEndpoint stays shard-agnostic (blocks/{hash})', () {
      final api = _ExposedApi(
        baseUrl: 'https://devnet-api.multiversx.com',
        chainId: const ChainId('D'),
      );

      const String hash = 'abc123';
      expect(api.exposedBlockByHashEndpoint(4294967295, hash), 'blocks/$hash');
      expect(api.exposedBlockByHashEndpoint(0, hash), 'blocks/$hash');

      api.close();
    });
  });

  group('SCR data decoding (Gateway UTF-8 vs API base64)', () {
    /// Both providers should resolve the SCR payload to the same return code
    /// (`ok`) and return-data parts even though the outer encoding differs:
    /// Gateway sends the raw `@6f6b@01` UTF-8 string while the API sends
    /// the base64-encoded equivalent.
    test(
      'Gateway decodes SCR data as UTF-8 and API decodes the same payload as base64',
      () {
        const String sender =
            'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th';
        const String receiver =
            'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th';

        const String rawScrData = '@6f6b@2a';
        final String base64ScrData = base64.encode(utf8.encode(rawScrData));

        Map<String, dynamic> buildTx(String scrDataField) {
          return <String, dynamic>{
            'sender': sender,
            'receiver': receiver,
            'value': '0',
            'nonce': 1,
            'gasLimit': 50000000,
            'gasPrice': 1000000000,
            'chainID': 'T',
            'version': 1,
            'status': 'success',
            'smartContractResults': <Map<String, dynamic>>[
              <String, dynamic>{
                'hash': 'scrhash',
                'nonce': 0,
                'value': '0',
                'sender': sender,
                'receiver': receiver,
                'data': scrDataField,
                'gasLimit': 0,
                'gasPrice': 1000000000,
                'callType': 0,
              },
            ],
          };
        }

        final TransactionOnNetwork fromGateway =
            TransactionOnNetwork.fromProxyResponse(
              buildTx(rawScrData),
              txHash: 'h1',
            );
        final TransactionOnNetwork fromApi =
            TransactionOnNetwork.fromApiResponse(
              buildTx(base64ScrData),
              txHash: 'h1',
            );

        final SmartContractResult gatewayScr =
            fromGateway.smartContractResults!.single;
        final SmartContractResult apiScr = fromApi.smartContractResults!.single;

        expect(gatewayScr.returnCode.isSuccess, isTrue);
        expect(apiScr.returnCode.isSuccess, isTrue);
        expect(gatewayScr.returnCode.code, equals('ok'));
        expect(apiScr.returnCode.code, equals('ok'));

        expect(gatewayScr.returnData.length, equals(1));
        expect(apiScr.returnData.length, equals(1));
        expect(gatewayScr.returnData.single, equals(<int>[0x2a]));
        expect(apiScr.returnData.single, equals(<int>[0x2a]));
      },
    );
  });
}
