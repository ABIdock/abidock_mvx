import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  late ArgumentEncoder encoder;
  late SmartContractAbi abi;

  setUp(() {
    const String abiJson = '''
    {
      "name": "TestContract",
      "endpoints": [
        {
          "name": "simpleCall",
          "inputs": [{"name": "value", "type": "u32"}],
          "outputs": []
        },
        {
          "name": "transferTokens",
          "inputs": [
            {"name": "recipient", "type": "Address"},
            {"name": "amount", "type": "BigUint"}
          ],
          "outputs": []
        },
        {
          "name": "variadicCall",
          "inputs": [
            {"name": "fixed", "type": "u32"},
            {"name": "items", "type": "variadic<u32>"}
          ],
          "outputs": []
        }
      ]
    }
    ''';
    abi = SmartContractAbi.fromJson(abiJson);
    encoder = ArgumentEncoder(
      serializer: ArgSerializer(),
      resolver: EndpointResolver(abi),
    );
  });

  group('ArgumentEncoder', () {
    test('encodeForEndpoint_basic', () {
      final endpoint = abi.getEndpoint(
        const SmartContractFunction('simpleCall'),
      );
      final encoded = encoder.encodeForEndpoint(
        endpoint: endpoint!,
        arguments: [42],
      );
      expect(encoded, hasLength(1));
      expect(encoded[0], equals('2a'));
    });

    test('encodeForEndpoint_multiple_args', () {
      final endpoint = abi.getEndpoint(
        const SmartContractFunction('transferTokens'),
      );
      const addressBech32 =
          'erd1qqqqqqqqqqqqqpgqp699jngundfqw07d8jzkepucvpzush6k3wvqyc44rx';
      final encoded = encoder.encodeForEndpoint(
        endpoint: endpoint!,
        arguments: [addressBech32, BigInt.from(1000)],
      );
      expect(encoded, hasLength(2));
      expect(encoded[0].length, equals(64));
      expect(encoded[1], equals('03e8'));
    });

    test('encodeForEndpoint_variadic', () {
      final endpoint = abi.getEndpoint(
        const SmartContractFunction('variadicCall'),
      );
      final encoded = encoder.encodeForEndpoint(
        endpoint: endpoint!,
        arguments: [42, 10, 20],
      );
      expect(encoded, hasLength(3));
      expect(encoded[0], equals('2a'));
      expect(encoded[1], equals('0a'));
      expect(encoded[2], equals('14'));
    });

    test('encodeTypedValues', () {
      final values = [
        U32Value(42),
        BytesValue.fromUTF8('test'),
        BooleanValue(true),
      ];
      final encoded = encoder.encodeTypedValues(values);
      expect(encoded[0], equals('2a'));
      expect(encoded[1], equals('74657374'));
      expect(encoded[2], equals('01'));
    });

    test('encodeSingleArgument', () {
      final param = AbiParameter(name: 'value', type: U32Type.type);
      final encoded = encoder.encodeSingleArgument(paramType: param, value: 42);
      expect(encoded, equals('2a'));
    });

    test('encodeWithTypes', () {
      final params = [
        AbiParameter(name: 'a', type: U32Type.type),
        AbiParameter(name: 'b', type: BytesType.type),
      ];
      final encoded = encoder.encodeWithTypes(
        paramTypes: params,
        arguments: [42, 'test'],
      );
      expect(encoded[0], equals('2a'));
      expect(encoded[1], equals('74657374'));
    });

    test('validation_error_handling', () {
      final endpoint = abi.getEndpoint(
        const SmartContractFunction('simpleCall'),
      );
      expect(
        () => encoder.encodeForEndpoint(endpoint: endpoint!, arguments: []),
        throwsA(isA<SmartContractException>()),
      );
    });
  });
}
