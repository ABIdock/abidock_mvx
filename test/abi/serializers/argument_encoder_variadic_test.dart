/// Regression tests for variadic and `multi<...>` endpoint arguments.
///
/// Three wire-level defects are pinned here:
///
/// 1. A whole `VariadicValue` handed to the trailing parameter was rejected,
///    because every trailing argument was compared against the variadic *item*
///    type instead of the variadic type itself.
/// 2. `counted-variadic<T>` dropped its leading `u32` item count when the items
///    arrived flattened, so the contract read the first item as the count.
/// 3. `multi<A,B>` was mistaken for a variadic, and the text between its angle
///    brackets was re-parsed as one type name.
///
/// [ArgSerializer] always produced the correct buffers, so every expectation
/// below is also cross-checked against it.
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

/// ABI exercising every shape the encoder has to group into wire slots.
const String _abiJson = '''
{
  "name": "VariadicContract",
  "endpoints": [
    {
      "name": "variadicCall",
      "inputs": [
        {"name": "fixed", "type": "u32"},
        {"name": "items", "type": "variadic<u32>"}
      ],
      "outputs": []
    },
    {
      "name": "countedCall",
      "inputs": [{"name": "items", "type": "counted-variadic<u32>"}],
      "outputs": []
    },
    {
      "name": "multiLast",
      "inputs": [{"name": "pair", "type": "multi<TokenIdentifier,BigUint>"}],
      "outputs": []
    },
    {
      "name": "multiFirst",
      "inputs": [
        {"name": "pair", "type": "multi<TokenIdentifier,BigUint>"},
        {"name": "tail", "type": "u32"}
      ],
      "outputs": []
    },
    {
      "name": "variadicMulti",
      "inputs": [
        {"name": "pairs", "type": "variadic<multi<TokenIdentifier,BigUint>>"}
      ],
      "outputs": []
    }
  ]
}
''';

/// `WEGLD-bd4d79` as ASCII hex.
const String wegldHex = '5745474c442d626434643739';

/// `USDC-c76f1f` as ASCII hex.
const String usdcHex = '555344432d633736663166';

void main() {
  late SmartContractAbi abi;
  late ArgumentEncoder encoder;

  AbiEndpoint endpoint(String name) =>
      abi.getEndpoint(SmartContractFunction(name))!;

  setUp(() {
    abi = SmartContractAbi.fromJson(_abiJson);
    encoder = ArgumentEncoder(
      serializer: ArgSerializer(),
      resolver: EndpointResolver(abi),
    );
  });

  group('variadic trailing parameter accepts both call shapes', () {
    test('flat trailing items produce one slot per item', () {
      final List<String> encoded = encoder.encodeForEndpoint(
        endpoint: endpoint('variadicCall'),
        arguments: <dynamic>[42, 10, 20],
      );

      expect(encoded, equals(<String>['2a', '0a', '14']));
    });

    test('a whole VariadicValue is accepted and encodes identically', () {
      final List<String> encoded = encoder.encodeForEndpoint(
        endpoint: endpoint('variadicCall'),
        arguments: <dynamic>[
          42,
          VariadicValue(<TypedValue>[
            U32Value(10),
            U32Value(20),
          ], itemType: U32Type.type),
        ],
      );

      expect(encoded, equals(<String>['2a', '0a', '14']));
    });

    test('a whole VariadicValue does not raise a validation error', () {
      expect(
        () => encoder.encodeForEndpoint(
          endpoint: endpoint('variadicCall'),
          arguments: <dynamic>[
            42,
            VariadicValue(<TypedValue>[U32Value(10)], itemType: U32Type.type),
          ],
        ),
        returnsNormally,
      );
    });

    test('an empty uncounted variadic contributes no slots', () {
      final List<String> encoded = encoder.encodeForEndpoint(
        endpoint: endpoint('variadicCall'),
        arguments: <dynamic>[42],
      );

      expect(encoded, equals(<String>['2a']));
    });

    test('an item of the wrong type is still rejected', () {
      expect(
        () => encoder.encodeForEndpoint(
          endpoint: endpoint('variadicCall'),
          arguments: <dynamic>[
            42,
            VariadicValue(<TypedValue>[
              BytesValue.fromUTF8('nope'),
            ], itemType: BytesType.type),
          ],
        ),
        throwsA(isA<ArgumentValidationException>()),
      );
    });
  });

  group('counted-variadic emits its u32 item count first', () {
    test('flat items are prefixed with the count', () {
      final List<String> encoded = encoder.encodeForEndpoint(
        endpoint: endpoint('countedCall'),
        arguments: <dynamic>[1, 2],
      );

      expect(encoded, equals(<String>['02', '01', '02']));
    });

    test('a whole counted VariadicValue is prefixed with the count', () {
      final List<String> encoded = encoder.encodeForEndpoint(
        endpoint: endpoint('countedCall'),
        arguments: <dynamic>[
          VariadicValue.counted(<TypedValue>[
            U32Value(1),
            U32Value(2),
          ], itemType: U32Type.type),
        ],
      );

      expect(encoded, equals(<String>['02', '01', '02']));
    });

    test('an uncounted VariadicValue still gets the declared count', () {
      final List<String> encoded = encoder.encodeForEndpoint(
        endpoint: endpoint('countedCall'),
        arguments: <dynamic>[
          VariadicValue(<TypedValue>[
            U32Value(1),
            U32Value(2),
          ], itemType: U32Type.type),
        ],
      );

      expect(encoded, equals(<String>['02', '01', '02']));
    });

    test('no items still emits the count slot, holding zero', () {
      final List<String> encoded = encoder.encodeForEndpoint(
        endpoint: endpoint('countedCall'),
        arguments: <dynamic>[],
      );

      expect(encoded, equals(<String>['']));
    });

    test('matches ArgSerializer for the same value', () {
      final List<String> viaSerializer = ArgSerializer().valuesToStrings(
        <TypedValue>[
          VariadicValue.counted(<TypedValue>[
            U32Value(1),
            U32Value(2),
          ], itemType: U32Type.type),
        ],
      );
      final List<String> viaEncoder = encoder.encodeForEndpoint(
        endpoint: endpoint('countedCall'),
        arguments: <dynamic>[1, 2],
      );

      expect(viaEncoder, equals(viaSerializer));
      expect(viaSerializer, equals(<String>['02', '01', '02']));
    });
  });

  group('multi<...> occupies one slot per member', () {
    test('as the last input it encodes both members', () {
      final List<String> encoded = encoder.encodeForEndpoint(
        endpoint: endpoint('multiLast'),
        arguments: <dynamic>[
          <dynamic>['WEGLD-bd4d79', BigInt.from(10)],
        ],
      );

      expect(encoded, equals(<String>[wegldHex, '0a']));
    });

    test('as the last input it accepts an explicit MultiValueValue', () {
      final MultiValueType type = MultiValueType(2, <AbiType>[
        TokenIdentifierType.type,
        BigUIntType.type,
      ]);
      final List<String> encoded = encoder.encodeForEndpoint(
        endpoint: endpoint('multiLast'),
        arguments: <dynamic>[
          MultiValueValue(type, <TypedValue>[
            TokenIdentifierValue('WEGLD-bd4d79'),
            BigUIntValue(BigInt.from(10)),
          ]),
        ],
      );

      expect(encoded, equals(<String>[wegldHex, '0a']));
    });

    test('in a non-last position the following argument keeps its slot', () {
      final List<String> encoded = encoder.encodeForEndpoint(
        endpoint: endpoint('multiFirst'),
        arguments: <dynamic>[
          <dynamic>['WEGLD-bd4d79', BigInt.from(10)],
          7,
        ],
      );

      expect(encoded, equals(<String>[wegldHex, '0a', '07']));
    });

    test('a variadic of multi expands every pair', () {
      final List<String> encoded = encoder.encodeForEndpoint(
        endpoint: endpoint('variadicMulti'),
        arguments: <dynamic>[
          <dynamic>['WEGLD-bd4d79', BigInt.from(10)],
          <dynamic>['USDC-c76f1f', BigInt.from(1)],
        ],
      );

      expect(encoded, equals(<String>[wegldHex, '0a', usdcHex, '01']));
    });

    test('a member count other than the declared arity is rejected', () {
      expect(
        () => encoder.encodeForEndpoint(
          endpoint: endpoint('multiLast'),
          arguments: <dynamic>[
            <dynamic>['WEGLD-bd4d79'],
          ],
        ),
        throwsA(isA<ArgumentEncodingException>()),
      );
    });
  });
}
