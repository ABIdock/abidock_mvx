@Tags(<String>['integration'])
library;

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

import '../fixtures/test_fixtures.dart';

void main() {
  const poolAddress =
      'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g';
  late ApiNetworkProvider provider;
  late SmartContractAbi abi;
  setUp(() async {
    provider = ApiNetworkProvider.devnet();
    abi = SmartContractAbi.fromJson(mockPairAbiJson);
  });
  group('Smart Contract Query Integration', () {
    test('should query contract state', () async {
      final contract = await provider.getAccount(
        Address.fromBech32(poolAddress),
      );
      expect(contract.address.isSmartContract, isTrue);
      expect(contract.address.bech32, equals(poolAddress));
    });
    test('should load xExchange ABI', () {
      expect(abi.name, isNotEmpty);
      final endpoints = abi.endpoints;
      expect(endpoints, isNotEmpty);
    });
    test('should parse endpoint signatures', () {
      final endpoints = abi.endpoints;
      final endpoint = endpoints.first;
      expect(endpoint.name, isNotEmpty);
    });
  });
}
