import 'dart:convert';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

import '../../../fixtures/test_fixtures.dart';

void main() {
  late ResponseParser parser;
  late ArgSerializer serializer;
  late SmartContractAbi testAbi;

  setUp(() async {
    serializer = ArgSerializer();
    parser = ResponseParser(serializer: serializer);
    testAbi = SmartContractAbi.fromJson(mockPairAbiJson);
  });

  group('ResponseParser - Basic', () {
    test('creates with serializer', () {
      expect(parser.serializer, equals(serializer));
      expect(parser.resolver, isNull);
    });

    test('creates with serializer and resolver', () {
      final resolver = EndpointResolver(testAbi);
      final parserWithResolver = ResponseParser(
        serializer: serializer,
        resolver: resolver,
      );
      expect(parserWithResolver.resolver, equals(resolver));
    });
  });

  group('ResponseParser - Type Parsing', () {
    test('parses single U32 return value', () {
      final outputTypes = [AbiParameter(name: 'value', type: U32Type.type)];
      final value = U32Type.create(42);
      final encoded = serializer.codec.encodeTopLevel(value);
      final results = parser.parseWithTypes(
        outputTypes: outputTypes,
        returnData: [base64.encode(encoded)],
      );
      expect(results.length, 1);
      expect(results[0].nativeValue, 42);
    });

    test('parses multiple return values', () {
      final outputTypes = [
        AbiParameter(name: 'count', type: U32Type.type),
        AbiParameter(name: 'name', type: StringType.type),
        AbiParameter(name: 'active', type: BooleanType.type),
      ];
      final count = U32Type.create(100);
      final name = StringType.create('Test');
      final active = BooleanType.create(true);
      final results = parser.parseWithTypes(
        outputTypes: outputTypes,
        returnData: [
          base64.encode(serializer.codec.encodeTopLevel(count)),
          base64.encode(serializer.codec.encodeTopLevel(name)),
          base64.encode(serializer.codec.encodeTopLevel(active)),
        ],
      );
      expect(results.length, 3);
      expect(results[0].nativeValue, 100);
      expect(results[1].nativeValue, 'Test');
      expect(results[2].nativeValue, true);
    });

    test('parses List<U32> return value', () {
      final outputTypes = [
        AbiParameter(name: 'numbers', type: ListType(U32Type.type)),
      ];
      final list = ListType(U32Type.type).createValue([1, 2, 3, 4, 5]);
      final encoded = serializer.codec.encodeTopLevel(list);
      final results = parser.parseWithTypes(
        outputTypes: outputTypes,
        returnData: [base64.encode(encoded)],
      );
      expect(results.length, 1);
      final nativeList = results[0].nativeValue as List;
      expect(nativeList, [1, 2, 3, 4, 5]);
    });

    test('parses Option<String> with Some', () {
      final outputTypes = [
        AbiParameter(name: 'name', type: OptionType(StringType.type)),
      ];
      final option = OptionType(StringType.type).createValue('Alice');
      final encoded = serializer.codec.encodeTopLevel(option);
      final results = parser.parseWithTypes(
        outputTypes: outputTypes,
        returnData: [base64.encode(encoded)],
      );
      expect(results.length, 1);
      expect(results[0].nativeValue, 'Alice');
    });

    test('parses Option<String> with None', () {
      final outputTypes = [
        AbiParameter(name: 'name', type: OptionType(StringType.type)),
      ];
      final option = OptionType(StringType.type).createValue(null);
      final encoded = serializer.codec.encodeTopLevel(option);
      final results = parser.parseWithTypes(
        outputTypes: outputTypes,
        returnData: [base64.encode(encoded)],
      );
      expect(results.length, 1);
      expect(results[0].nativeValue, isNull);
    });

    test('parses BigUint value', () {
      final outputTypes = [
        AbiParameter(name: 'balance', type: BigUIntType.type),
      ];
      final balance = BigUIntType.create(BigInt.parse('1000000000000000000'));
      final encoded = serializer.codec.encodeTopLevel(balance);
      final results = parser.parseWithTypes(
        outputTypes: outputTypes,
        returnData: [base64.encode(encoded)],
      );
      expect(results.length, 1);
      expect(results[0].nativeValue, BigInt.parse('1000000000000000000'));
    });

    test('throws on return data count mismatch', () {
      final outputTypes = [AbiParameter(name: 'value', type: U32Type.type)];
      expect(
        () => parser.parseWithTypes(outputTypes: outputTypes, returnData: []),
        throwsA(isA<ResponseParsingException>()),
      );
    });
  });

  group('ResponseParser - Single Values', () {
    test('parses single value with type', () {
      final value = U32Type.create(999);
      final encoded = serializer.codec.encodeTopLevel(value);
      final result = parser.parseSingleValue(
        outputType: AbiParameter(name: 'result', type: U32Type.type),
        returnData: base64.encode(encoded),
      );
      expect(result.nativeValue, 999);
    });

    test('converts typed values to native values', () {
      final typedValues = [
        U32Type.create(42),
        StringType.create('Test'),
        BooleanType.create(true),
      ];
      final nativeValues = parser.toNativeValues(typedValues);
      expect(nativeValues.length, 3);
      expect(nativeValues[0], 42);
      expect(nativeValues[1], 'Test');
      expect(nativeValues[2], true);
    });
  });
}
