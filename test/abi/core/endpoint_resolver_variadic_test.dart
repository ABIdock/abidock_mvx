/// Regression tests for variadic argument validation in [EndpointResolver].
///
/// When the last input of an endpoint is variadic, every trailing argument used
/// to be compared against the variadic *item* type. A caller handing the whole
/// run over as one `VariadicValue` therefore always failed, with a message that
/// printed the same type on both sides of the comparison.
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

/// ABI with a fixed input followed by a variadic run.
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
    }
  ]
}
''';

void main() {
  late EndpointResolver resolver;

  setUp(() {
    resolver = EndpointResolver(SmartContractAbi.fromJson(_abiJson));
  });

  group('EndpointResolver validates variadic trailing arguments', () {
    test('accepts the trailing run supplied as one VariadicValue', () {
      expect(
        () => resolver.validateArgumentTypes('variadicCall', <TypedValue>[
          U32Value(42),
          VariadicValue(<TypedValue>[
            U32Value(10),
            U32Value(20),
          ], itemType: U32Type.type),
        ]),
        returnsNormally,
      );
    });

    test('accepts the trailing run supplied as flat items', () {
      expect(
        () => resolver.validateArgumentTypes('variadicCall', <TypedValue>[
          U32Value(42),
          U32Value(10),
          U32Value(20),
        ]),
        returnsNormally,
      );
    });

    test('accepts a counted VariadicValue for an uncounted parameter', () {
      expect(
        () => resolver.validateArgumentTypes('variadicCall', <TypedValue>[
          U32Value(42),
          VariadicValue.counted(<TypedValue>[
            U32Value(10),
          ], itemType: U32Type.type),
        ]),
        returnsNormally,
      );
    });

    test('reports the offending item inside a VariadicValue', () {
      expect(
        () => resolver.validateArgumentTypes('variadicCall', <TypedValue>[
          U32Value(42),
          VariadicValue(<TypedValue>[
            BytesValue.fromUTF8('nope'),
          ], itemType: BytesType.type),
        ]),
        throwsA(
          isA<ArgumentValidationException>().having(
            (ArgumentValidationException e) => e.toString(),
            'message',
            contains('Argument 1 (variadic item 0)'),
          ),
        ),
      );
    });

    test('still rejects a flat item of the wrong type', () {
      expect(
        () => resolver.validateArgumentTypes('variadicCall', <TypedValue>[
          U32Value(42),
          BytesValue.fromUTF8('nope'),
        ]),
        throwsA(
          isA<ArgumentValidationException>().having(
            (ArgumentValidationException e) => e.toString(),
            'message',
            contains('Argument 1 (variadic)'),
          ),
        ),
      );
    });
  });
}
