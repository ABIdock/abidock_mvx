import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

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
}
