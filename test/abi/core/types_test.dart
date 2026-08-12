/// Regression tests for framework types that carry no ABI `types` entry.
///
/// `TokenId`, `NonZeroBigUint`, `Payment` and `FungiblePayment` are built-in
/// framework types, so an ABI may carry `"types": {}` while still naming them
/// in endpoint inputs. Their layouts must be known intrinsically or the whole
/// ABI fails to load.
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

/// Lowercase hex rendering used to pin wire bytes against literals.
String _hex(List<int> bytes) =>
    bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  late AbiTypeFactory factory;
  late BinaryCodec codec;

  setUp(() {
    factory = AbiTypeFactory();
    codec = BinaryCodec.withDefaults();
  });

  group('AbiTypeFactory framework built-ins', () {
    test('TokenId resolves to the TokenIdentifier singleton', () {
      expect(
        identical(factory.fromString('TokenId'), TokenIdentifierType.type),
        isTrue,
      );
      expect(
        identical(
          factory.fromString('TokenId'),
          EgldOrEsdtTokenIdentifierType.type,
        ),
        isFalse,
      );
    });

    test('NonZeroBigUint resolves to the BigUint singleton', () {
      expect(
        identical(factory.fromString('NonZeroBigUint'), BigUIntType.type),
        isTrue,
      );
    });

    test('Payment is a 3-field struct in declaration order', () {
      final StructType payment = factory.fromString('Payment') as StructType;

      expect(payment.name, equals('Payment'));
      expect(
        payment.fieldDefinitions.map((FieldDefinition f) => f.name).toList(),
        equals(<String>['token_identifier', 'token_nonce', 'amount']),
      );
      expect(
        identical(payment.fieldDefinitions[0].type, TokenIdentifierType.type),
        isTrue,
      );
      expect(identical(payment.fieldDefinitions[1].type, U64Type.type), isTrue);
      expect(
        identical(payment.fieldDefinitions[2].type, BigUIntType.type),
        isTrue,
      );
    });

    test('FungiblePayment is a 2-field struct without a nonce', () {
      final StructType payment =
          factory.fromString('FungiblePayment') as StructType;

      expect(payment.name, equals('FungiblePayment'));
      expect(
        payment.fieldDefinitions.map((FieldDefinition f) => f.name).toList(),
        equals(<String>['token_identifier', 'amount']),
      );
      expect(
        identical(payment.fieldDefinitions[0].type, TokenIdentifierType.type),
        isTrue,
      );
      expect(
        identical(payment.fieldDefinitions[1].type, BigUIntType.type),
        isTrue,
      );
    });

    test('built-in structs are cached singletons', () {
      expect(
        identical(factory.fromString('Payment'), factory.fromString('Payment')),
        isTrue,
      );
      expect(
        identical(
          AbiTypeFactory().fromString('FungiblePayment'),
          factory.fromString('FungiblePayment'),
        ),
        isTrue,
      );
    });

    test('an ABI-declared Payment shadows the built-in', () {
      final StructType custom = StructType(
        name: 'Payment',
        fieldDefinitions: <FieldDefinition>[
          FieldDefinition(name: 'only', type: U8Type.type),
        ],
      );
      factory.registerCustomType('Payment', custom);

      expect(identical(factory.fromString('Payment'), custom), isTrue);
    });
  });

  group('Payment wire form', () {
    test('nested encodes [u32 len][utf8][8B nonce][u32 len][magnitude]', () {
      final StructType payment = factory.fromString('Payment') as StructType;
      final TypedValue value = payment.createValue(<String, dynamic>{
        'token_identifier': 'USDC-123456',
        'token_nonce': 0,
        'amount': BigInt.from(100),
      });

      expect(
        _hex(codec.encodeNested(value)),
        equals('0000000b555344432d31323334353600000000000000000000000164'),
      );
    });

    test('top-level equals the nested bytes', () {
      final StructType payment = factory.fromString('Payment') as StructType;
      final TypedValue value = payment.createValue(<String, dynamic>{
        'token_identifier': 'NFT-456789',
        'token_nonce': 42,
        'amount': BigInt.from(1),
      });

      expect(
        _hex(codec.encodeTopLevel(value)),
        equals('0000000a4e46542d343536373839000000000000002a0000000101'),
      );
      expect(
        _hex(codec.encodeTopLevel(value)),
        equals(_hex(codec.encodeNested(value))),
      );
    });

    test('round-trips through decodeTopLevel', () {
      final StructType payment = factory.fromString('Payment') as StructType;
      final TypedValue value = payment.createValue(<String, dynamic>{
        'token_identifier': 'USDC-123456',
        'token_nonce': 7,
        'amount': BigInt.from(250),
      });

      final TypedValue decoded = codec.decodeTopLevel(
        codec.encodeTopLevel(value),
        payment,
      );
      final StructValue struct = decoded as StructValue;

      expect(
        struct.getFieldValue('token_identifier').nativeValue,
        equals('USDC-123456'),
      );
      expect(
        struct.getFieldValue('token_nonce').nativeValue,
        equals(BigInt.from(7)),
      );
      expect(
        struct.getFieldValue('amount').nativeValue,
        equals(BigInt.from(250)),
      );
    });
  });

  group('FungiblePayment wire form', () {
    test('nested drops the nonce field entirely', () {
      final StructType payment =
          factory.fromString('FungiblePayment') as StructType;
      final TypedValue value = payment.createValue(<String, dynamic>{
        'token_identifier': 'USDC-123456',
        'amount': BigInt.from(100),
      });

      expect(
        _hex(codec.encodeNested(value)),
        equals('0000000b555344432d3132333435360000000164'),
      );
      expect(
        _hex(codec.encodeTopLevel(value)),
        equals('0000000b555344432d3132333435360000000164'),
      );
    });
  });

  group('PaymentMultiValue formula', () {
    test('multi<TokenIdentifier,u64,NonZeroBigUint> has arity 3', () {
      final MultiValueType type =
          factory.fromString('multi<TokenIdentifier,u64,NonZeroBigUint>')
              as MultiValueType;

      expect(type.arity, equals(3));
      expect(identical(type.types[0], TokenIdentifierType.type), isTrue);
      expect(identical(type.types[1], U64Type.type), isTrue);
      expect(identical(type.types[2], BigUIntType.type), isTrue);
    });

    test('variadic<multi<...>> resolves without throwing', () {
      final VariadicType type =
          factory.fromString(
                'variadic<multi<TokenIdentifier,u64,NonZeroBigUint>>',
              )
              as VariadicType;

      expect(type.isCounted, isFalse);
      expect((type.itemType as MultiValueType).arity, equals(3));
    });

    test('one payment occupies three separate top-level arguments', () {
      final MultiValueType type =
          factory.fromString('multi<TokenIdentifier,u64,NonZeroBigUint>')
              as MultiValueType;
      final TypedValue value = type.createValue(<dynamic>[
        'USDC-123456',
        0,
        BigInt.from(100),
      ]);

      expect(
        ArgSerializer().valuesToStrings(<TypedValue>[value]),
        equals(<String>['555344432d313233343536', '', '64']),
      );
    });
  });

  group('ABI with empty types map', () {
    const String forwarderBlindAbi = '''
{
  "name": "ForwarderBlind",
  "endpoints": [
    {
      "name": "drain",
      "onlyOwner": true,
      "mutability": "mutable",
      "inputs": [
        { "name": "token", "type": "TokenId" },
        { "name": "token_nonce", "type": "u64" }
      ],
      "outputs": []
    },
    {
      "name": "collect",
      "mutability": "mutable",
      "inputs": [ { "name": "payment", "type": "Payment" } ],
      "outputs": [ { "type": "FungiblePayment" } ]
    }
  ],
  "events": [
    {
      "identifier": "payments_event",
      "inputs": [
        {
          "name": "payments",
          "type": "variadic<multi<TokenIdentifier,u64,NonZeroBigUint>>",
          "indexed": true
        }
      ]
    }
  ],
  "types": {}
}
''';

    test('loads and resolves TokenId inputs', () {
      final SmartContractAbi abi = SmartContractAbi.fromJson(forwarderBlindAbi);
      final AbiEndpoint drain = abi.getEndpoint(
        const SmartContractFunction('drain'),
      )!;

      expect(
        identical(drain.inputs.first.type, TokenIdentifierType.type),
        isTrue,
      );
      expect(identical(drain.inputs[1].type, U64Type.type), isTrue);
    });

    test('resolves Payment and FungiblePayment endpoint signatures', () {
      final SmartContractAbi abi = SmartContractAbi.fromJson(forwarderBlindAbi);
      final AbiEndpoint collect = abi.getEndpoint(
        const SmartContractFunction('collect'),
      )!;

      expect(
        (collect.inputs.first.type as StructType).fieldDefinitions.length,
        equals(3),
      );
      expect(
        (collect.outputs.first.type as StructType).fieldDefinitions.length,
        equals(2),
      );
    });

    test('resolves the variadic multi event input', () {
      final SmartContractAbi abi = SmartContractAbi.fromJson(forwarderBlindAbi);
      final VariadicType payments =
          abi.events.first.inputs.first.type as VariadicType;

      expect((payments.itemType as MultiValueType).arity, equals(3));
    });
  });
}
