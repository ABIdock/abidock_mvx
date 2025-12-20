import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  const aliceAddress =
      'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8';
  const xExchangePool =
      'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g';
  late NetworkProvider provider;
  setUp(() {
    provider = ApiNetworkProvider.devnet();
  });
  group('Network Provider Integration', () {
    test('should fetch network configuration', () async {
      try {
        final config = await provider.getNetworkConfig();
        expect(config.chainId, isNotEmpty);
        expect(config.minGasPrice, greaterThan(0));
        expect(config.minGasLimit, greaterThan(0));
        'Devnet config: ${config.chainId}, gas price: ${config.minGasPrice}';
      } catch (e, stackTrace) {
        fail('Failed to fetch network configuration: $e\n$stackTrace');
      }
    });
    test('should fetch account from devnet', () async {
      final account = await provider.getAccount(
        Address.fromBech32(aliceAddress),
      );
      expect(account.address.bech32, equals(aliceAddress));
      expect(account.balance.value, greaterThan(BigInt.zero));
      expect(account.nonce.value, greaterThanOrEqualTo(0));
      'Alice balance: ${account.balance.value} eGLD, nonce: ${account.nonce.value}';
    });
    test('should fetch smart contract account', () async {
      final contract = await provider.getAccount(
        Address.fromBech32(xExchangePool),
      );
      expect(contract.address.bech32, equals(xExchangePool));
      expect(contract.address.isSmartContract, isTrue);
    });
  });
  group('Address Integration', () {
    test('should work with real devnet addresses', () {
      final alice = Address.fromBech32(aliceAddress);
      expect(alice.bech32, equals(aliceAddress));
      expect(alice.isSmartContract, isFalse);
      final contract = Address.fromBech32(xExchangePool);
      expect(contract.bech32, equals(xExchangePool));
      expect(contract.isSmartContract, isTrue);
    });
  });
  group('Balance Integration', () {
    test('should handle real balance values', () async {
      final account = await provider.getAccount(
        Address.fromBech32(aliceAddress),
      );
      final balance = account.balance;
      expect(balance.value, greaterThan(BigInt.zero));
      final egldValue = balance.toDenominated;
      expect(double.parse(egldValue), greaterThan(0.0));
    });
  });
}
