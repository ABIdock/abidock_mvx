import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

import '../../fixtures/test_fixtures.dart';

void main() {
  group('SmartContractAbi', () {
    test('loads from JSON string', () async {
      final abi = SmartContractAbi.fromJson(mockPairAbiJson);
      expect(abi, isNotNull);
    });
    test('parses contract name', () async {
      final abi = SmartContractAbi.fromJson(mockPairAbiJson);
      expect(abi.name, 'Pair');
    });
    test('has endpoints', () async {
      final abi = SmartContractAbi.fromJson(mockPairAbiJson);
      expect(abi.endpoints, isNotEmpty);
    });
    test('has constructor', () async {
      final abi = SmartContractAbi.fromJson(mockPairAbiJson);
      expect(abi.constructor, isNotNull);
    });
    test('has custom types', () async {
      final abi = SmartContractAbi.fromJson(mockPairAbiJson);
      expect(abi.types, isNotEmpty);
    });
  });
  group('AbiDefinition', () {
    late SmartContractAbi abi;
    setUp(() async {
      abi = SmartContractAbi.fromJson(mockPairAbiJson);
    });
    test('has custom type', () {
      final type = abi.types['EsdtTokenPayment'];
      expect(type, isNotNull);
    });
    test('struct type has fields', () {
      final type = abi.types['EsdtTokenPayment'] as StructType?;
      expect(type, isNotNull);
      expect(type?.fieldDefinitions, isNotEmpty);
      expect(type?.fieldDefinitions.length, 3);
    });
    test('enum type has variants', () {
      final type = abi.types['State'] as EnumType?;
      expect(type, isNotNull);
      expect(type?.variants, isNotEmpty);
      expect(type?.variants.length, 3);
    });
    test('has events', () {
      expect(abi.events.length, 4);
    });
  });
}
