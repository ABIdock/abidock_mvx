import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

String _encode(List<int> bytes) => base64.encode(bytes);

void main() {
  late AbiDeserializer deserializer;

  setUp(() {
    deserializer = const AbiDeserializer();
  });

  group('Unsigned Integer Types', () {
    test('U8 zero', () {
      final result = deserializer.deserializeValue(_encode([0]), U8Type.type);
      expect(result, 0);
    });

    test('U8 max', () {
      final result = deserializer.deserializeValue(_encode([255]), U8Type.type);
      expect(result, 255);
    });

    test('U16 value', () {
      final result = deserializer.deserializeValue(
        _encode([0x01, 0x02]),
        U16Type.type,
      );
      expect(result, 0x0102);
    });

    test('U16 max', () {
      final result = deserializer.deserializeValue(
        _encode([0xFF, 0xFF]),
        U16Type.type,
      );
      expect(result, 65535);
    });

    test('U32 value', () {
      final result = deserializer.deserializeValue(
        _encode([0x01, 0x02, 0x03, 0x04]),
        U32Type.type,
      );
      expect(result, 0x01020304);
    });

    test('U32 max', () {
      final result = deserializer.deserializeValue(
        _encode([0xFF, 0xFF, 0xFF, 0xFF]),
        U32Type.type,
      );
      expect(result, 4294967295);
    });

    test('U64 value', () {
      final result = deserializer.deserializeValue(
        _encode([0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]),
        U64Type.type,
      );
      expect(result, 0x100000000);
    });

    test('U64 large value returns BigInt', () {
      final result = deserializer.deserializeValue(
        _encode([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]),
        U64Type.type,
      );
      expect(result, BigInt.parse('18446744073709551615'));
    });

    test('BigUInt small', () {
      final result = deserializer.deserializeValue(
        _encode([0x2A]),
        BigUIntType.type,
      );
      expect(result, BigInt.from(42));
    });

    test('BigUInt large', () {
      final result = deserializer.deserializeValue(
        _encode([0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
        BigUIntType.type,
      );
      expect(result, BigInt.parse('18446744073709551616'));
    });
  });

  group('Signed Integer Types', () {
    test('I8 positive', () {
      final result = deserializer.deserializeValue(_encode([127]), I8Type.type);
      expect(result, 127);
    });

    test('I8 negative', () {
      final result = deserializer.deserializeValue(
        _encode([0x80]),
        I8Type.type,
      );
      expect(result, -128);
    });

    test('I8 minus one', () {
      final result = deserializer.deserializeValue(
        _encode([0xFF]),
        I8Type.type,
      );
      expect(result, -1);
    });

    test('I16 positive', () {
      final result = deserializer.deserializeValue(
        _encode([0x7F, 0xFF]),
        I16Type.type,
      );
      expect(result, 32767);
    });

    test('I16 negative', () {
      final result = deserializer.deserializeValue(
        _encode([0x80, 0x00]),
        I16Type.type,
      );
      expect(result, -32768);
    });

    test('I32 positive', () {
      final result = deserializer.deserializeValue(
        _encode([0x7F, 0xFF, 0xFF, 0xFF]),
        I32Type.type,
      );
      expect(result, 2147483647);
    });

    test('I32 negative', () {
      final result = deserializer.deserializeValue(
        _encode([0x80, 0x00, 0x00, 0x00]),
        I32Type.type,
      );
      expect(result, -2147483648);
    });

    test('I64 positive', () {
      final result = deserializer.deserializeValue(
        _encode([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]),
        I64Type.type,
      );
      expect(result, 1);
    });

    test('I64 negative', () {
      final result = deserializer.deserializeValue(
        _encode([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]),
        I64Type.type,
      );
      expect(result, -1);
    });

    test('BigInt positive', () {
      final result = deserializer.deserializeValue(
        _encode([0x2A]),
        BigIntType.type,
      );
      expect(result, BigInt.from(42));
    });

    test('BigInt negative', () {
      final result = deserializer.deserializeValue(
        _encode([0xD6]),
        BigIntType.type,
      );
      expect(result, BigInt.from(-42));
    });
  });

  group('Boolean Type', () {
    test('true', () {
      final result = deserializer.deserializeValue(
        _encode([0x01]),
        BooleanType.type,
      );
      expect(result, true);
    });

    test('false', () {
      final result = deserializer.deserializeValue(
        _encode([0x00]),
        BooleanType.type,
      );
      expect(result, false);
    });

    test('false from empty bytes (top-level encoding)', () {
      final result = deserializer.deserializeValue(
        _encode([]),
        BooleanType.type,
      );
      expect(result, false);
    });

    test('non-zero is true', () {
      final result = deserializer.deserializeValue(
        _encode([0xFF]),
        BooleanType.type,
      );
      expect(result, true);
    });

    test('extra bytes are ignored (per ABI spec)', () {
      final result = deserializer.deserializeValue(
        _encode([0x01, 0x02]),
        BooleanType.type,
      );
      expect(result, true);
    });
  });

  group('String Type', () {
    test('empty string', () {
      final result = deserializer.deserializeValue(
        _encode([]),
        StringType.type,
      );
      expect(result, '');
    });

    test('ascii string', () {
      final result = deserializer.deserializeValue(
        _encode('hello'.codeUnits),
        StringType.type,
      );
      expect(result, 'hello');
    });

    test('unicode string', () {
      final result = deserializer.deserializeValue(
        _encode(utf8.encode('Hello 世界')),
        StringType.type,
      );
      expect(result, 'Hello 世界');
    });
  });

  group('Bytes Type', () {
    test('empty bytes', () {
      final result = deserializer.deserializeValue(_encode([]), BytesType.type);
      expect(result, Uint8List(0));
    });

    test('bytes data', () {
      final result = deserializer.deserializeValue(
        _encode([0x01, 0x02, 0x03, 0x04]),
        BytesType.type,
      );
      expect(result, Uint8List.fromList([0x01, 0x02, 0x03, 0x04]));
    });
  });

  group('Address Type', () {
    test('valid address', () {
      final addressBytes = List<int>.filled(32, 0);
      addressBytes[31] = 1;
      final result = deserializer.deserializeValue(
        _encode(addressBytes),
        AddressType.type,
      );
      expect(result, startsWith('erd1'));
    });

    test('invalid length throws', () {
      expect(
        () => deserializer.deserializeValue(
          _encode([0x01, 0x02, 0x03]),
          AddressType.type,
        ),
        throwsA(isA<DeserializationException>()),
      );
    });
  });

  group('TokenIdentifier Type', () {
    test('ESDT token', () {
      final result = deserializer.deserializeValue(
        _encode('WEGLD-bd4d79'.codeUnits),
        TokenIdentifierType.type,
      );
      expect(result, 'WEGLD-bd4d79');
    });

    test('simple identifier', () {
      final result = deserializer.deserializeValue(
        _encode('USDC-c76f1f'.codeUnits),
        TokenIdentifierType.type,
      );
      expect(result, 'USDC-c76f1f');
    });
  });

  group('EgldOrEsdtTokenIdentifier Type', () {
    test('legacy EGLD sentinel canonicalises to EGLD-000000', () {
      final result = deserializer.deserializeValue(
        _encode('EGLD'.codeUnits),
        EgldOrEsdtTokenIdentifierType.type,
      );
      expect(result, 'EGLD-000000');
    });

    test('empty bytes canonicalise to EGLD-000000', () {
      final result = deserializer.deserializeValue(
        _encode(const <int>[]),
        EgldOrEsdtTokenIdentifierType.type,
      );
      expect(result, 'EGLD-000000');
    });

    test('ESDT token', () {
      final result = deserializer.deserializeValue(
        _encode('WEGLD-bd4d79'.codeUnits),
        EgldOrEsdtTokenIdentifierType.type,
      );
      expect(result, 'WEGLD-bd4d79');
    });
  });

  group('H256 Type', () {
    test('valid 32-byte hash', () {
      final hashBytes = List<int>.filled(32, 0xAB);
      final result = deserializer.deserializeValue(
        _encode(hashBytes),
        H256Type.type,
      );
      expect(result, Uint8List.fromList(hashBytes));
    });

    test('invalid length throws', () {
      expect(
        () =>
            deserializer.deserializeValue(_encode([0x01, 0x02]), H256Type.type),
        throwsA(isA<DeserializationException>()),
      );
    });
  });

  group('CodeMetadata Type', () {
    test('all flags false', () {
      final result = deserializer.deserializeValue(
        _encode([0x00, 0x00]),
        CodeMetadataType.type,
      );
      expect(result['upgradeable'], false);
      expect(result['readable'], false);
      expect(result['payable'], false);
      expect(result['payableBySc'], false);
    });

    test('upgradeable flag', () {
      final result = deserializer.deserializeValue(
        _encode([0x01, 0x00]),
        CodeMetadataType.type,
      );
      expect(result['upgradeable'], true);
    });

    test('readable flag', () {
      final result = deserializer.deserializeValue(
        _encode([0x04, 0x00]),
        CodeMetadataType.type,
      );
      expect(result['readable'], true);
    });

    test('payable flag', () {
      final result = deserializer.deserializeValue(
        _encode([0x00, 0x02]),
        CodeMetadataType.type,
      );
      expect(result['payable'], true);
    });

    test('payableBySc flag', () {
      final result = deserializer.deserializeValue(
        _encode([0x00, 0x04]),
        CodeMetadataType.type,
      );
      expect(result['payableBySc'], true);
    });

    test('all flags true', () {
      final result = deserializer.deserializeValue(
        _encode([0x05, 0x06]),
        CodeMetadataType.type,
      );
      expect(result['upgradeable'], true);
      expect(result['readable'], true);
      expect(result['payable'], true);
      expect(result['payableBySc'], true);
    });

    test('invalid length throws', () {
      expect(
        () => deserializer.deserializeValue(
          _encode([0x01]),
          CodeMetadataType.type,
        ),
        throwsA(isA<DeserializationException>()),
      );
    });
  });

  group('Nothing Type', () {
    test('returns null', () {
      final result = deserializer.deserializeValue(
        _encode([]),
        NothingType.type,
      );
      expect(result, isNull);
    });

    test('returns null with data', () {
      final result = deserializer.deserializeValue(
        _encode([0x01, 0x02]),
        NothingType.type,
      );
      expect(result, isNull);
    });
  });

  group('List Type', () {
    test('empty list', () {
      final type = ListType(U32Type.type);
      final result = deserializer.deserializeValue(_encode([]), type);
      expect(result, []);
    });

    test('list of u8', () {
      final type = ListType(U8Type.type);
      final result = deserializer.deserializeValue(_encode([0x0A, 0x14]), type);
      expect(result, [10, 20]);
    });

    test('list of u32', () {
      final type = ListType(U32Type.type);
      final bytes = <int>[0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x02];
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result, [1, 2]);
    });
  });

  group('Array Type', () {
    test('array of u8 length 4', () {
      final type = ArrayType(U8Type.type, 4);
      final result = deserializer.deserializeValue(
        _encode([0x01, 0x02, 0x03, 0x04]),
        type,
      );
      expect(result, [1, 2, 3, 4]);
    });

    test('array of u32 length 2', () {
      final type = ArrayType(U32Type.type, 2);
      final bytes = <int>[0x00, 0x00, 0x00, 0x0A, 0x00, 0x00, 0x00, 0x14];
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result, [10, 20]);
    });

    test('array of BigUInt - variable size elements', () {
      final type = ArrayType(BigUIntType.type, 2);
      final bytes = <int>[
        0x00, 0x00, 0x00, 0x02, // length prefix: 2 bytes
        0x01, 0x00, // value: 256
        0x00, 0x00, 0x00, 0x01, // length prefix: 1 byte
        0x2A, // value: 42
      ];
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result, [BigInt.from(256), BigInt.from(42)]);
    });

    test('insufficient bytes throws', () {
      final type = ArrayType(U8Type.type, 10);
      expect(
        () => deserializer.deserializeValue(_encode([0x01, 0x02]), type),
        throwsA(isA<DeserializationException>()),
      );
    });
  });

  group('Option Type', () {
    test('None empty bytes', () {
      final type = OptionType(U32Type.type);
      final result = deserializer.deserializeValue(_encode([]), type);
      expect(result, isNull);
    });

    test('Some u32 (top-level marker + nested u32)', () {
      final type = OptionType(U32Type.type);
      final bytes = <int>[0x01, 0x00, 0x00, 0x00, 0x2A];
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result, 42);
    });

    test('Some u8 (top-level marker + nested u8)', () {
      final type = OptionType(U8Type.type);
      final bytes = <int>[0x01, 0x2A];
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result, 42);
    });

    test('invalid top-level marker throws', () {
      final type = OptionType(U32Type.type);
      expect(
        () => deserializer.deserializeValue(_encode([0x02]), type),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Optional Type', () {
    test('empty is null', () {
      final type = OptionalType.of(U32Type.type);
      final result = deserializer.deserializeValue(_encode([]), type);
      expect(result, isNull);
    });

    test('provided value', () {
      final type = OptionalType.of(U32Type.type);
      final result = deserializer.deserializeValue(
        _encode([0x00, 0x00, 0x00, 0x2A]),
        type,
      );
      expect(result, 42);
    });
  });

  group('Tuple Type', () {
    test('tuple of u8 and u16', () {
      final type = TupleType([U8Type.type, U16Type.type]);
      final bytes = <int>[0x0A, 0x00, 0x14];
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result, [10, 20]);
    });

    test('tuple of u32 u32 bool', () {
      final type = TupleType([U32Type.type, U32Type.type, BooleanType.type]);
      final bytes = <int>[0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x02, 0x01];
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result, [1, 2, true]);
    });
  });

  group('Struct Type', () {
    test('simple struct', () {
      final type = StructType(
        name: 'Point',
        fieldDefinitions: [
          FieldDefinition(name: 'x', type: U32Type.type),
          FieldDefinition(name: 'y', type: U32Type.type),
        ],
      );
      final bytes = <int>[0x00, 0x00, 0x00, 0x0A, 0x00, 0x00, 0x00, 0x14];
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result, {'x': 10, 'y': 20});
    });

    test('struct with mixed types', () {
      final type = StructType(
        name: 'User',
        fieldDefinitions: [
          FieldDefinition(name: 'id', type: U32Type.type),
          FieldDefinition(name: 'active', type: BooleanType.type),
        ],
      );
      final bytes = <int>[0x00, 0x00, 0x00, 0x01, 0x01];
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result, {'id': 1, 'active': true});
    });
  });

  group('Enum Type', () {
    test('simple enum no fields', () {
      final type = EnumType(
        name: 'Status',
        variants: [
          const EnumVariantDefinition(name: 'Pending', discriminant: 0),
          const EnumVariantDefinition(name: 'Active', discriminant: 1),
          const EnumVariantDefinition(name: 'Done', discriminant: 2),
        ],
      );
      final result = deserializer.deserializeValue(_encode([0x01]), type);
      expect(result['variant'], 'Active');
      expect(result['discriminant'], 1);
    });

    test('enum with fields', () {
      final type = EnumType(
        name: 'Result',
        variants: [
          EnumVariantDefinition(
            name: 'Ok',
            discriminant: 0,
            fields: [U32Type.type],
          ),
          EnumVariantDefinition(
            name: 'Err',
            discriminant: 1,
            fields: [U32Type.type],
          ),
        ],
      );
      final bytes = <int>[0x00, 0x00, 0x00, 0x00, 0x2A];
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result['variant'], 'Ok');
      expect(result['discriminant'], 0);
      expect(result['fields']['field0'], 42);
    });

    test('enum with variable-size field (string)', () {
      final type = EnumType(
        name: 'Message',
        variants: [
          EnumVariantDefinition(
            name: 'Text',
            discriminant: 0,
            fields: [StringType.type],
          ),
          const EnumVariantDefinition(name: 'Empty', discriminant: 1),
        ],
      );
      final bytes = <int>[
        0x00, // discriminant
        0x00, 0x00, 0x00, 0x05, // length prefix
        0x68, 0x65, 0x6C, 0x6C, 0x6F, // "hello"
      ];
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result['variant'], 'Text');
      expect(result['discriminant'], 0);
      expect(result['fields']['field0'], 'hello');
    });

    test('enum with mixed fixed and variable-size fields', () {
      final type = EnumType(
        name: 'Data',
        variants: [
          EnumVariantDefinition(
            name: 'Info',
            discriminant: 0,
            fields: [U32Type.type, StringType.type, U8Type.type],
          ),
        ],
      );
      final bytes = <int>[
        0x00, // discriminant
        0x00, 0x00, 0x00, 0x2A, // U32 = 42
        0x00, 0x00, 0x00, 0x02, // length prefix for "hi"
        0x68, 0x69, // "hi"
        0xFF, // U8 = 255
      ];
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result['variant'], 'Info');
      expect(result['fields']['field0'], 42);
      expect(result['fields']['field1'], 'hi');
      expect(result['fields']['field2'], 255);
    });

    test('unknown discriminant throws', () {
      final type = EnumType(
        name: 'Status',
        variants: [
          const EnumVariantDefinition(name: 'Pending', discriminant: 0),
        ],
      );
      expect(
        () => deserializer.deserializeValue(_encode([0xFF]), type),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('empty bytes returns variant 0 (top-level encoding)', () {
      final type = EnumType(
        name: 'Status',
        variants: [
          const EnumVariantDefinition(name: 'Pending', discriminant: 0),
          const EnumVariantDefinition(name: 'Active', discriminant: 1),
        ],
      );
      final result = deserializer.deserializeValue(_encode([]), type);
      expect(result['variant'], 'Pending');
      expect(result['discriminant'], 0);
      expect(result['fields'], isEmpty);
    });

    test('empty bytes throws if variant 0 has fields', () {
      final type = EnumType(
        name: 'Result',
        variants: [
          EnumVariantDefinition(
            name: 'Ok',
            discriminant: 0,
            fields: [U32Type.type],
          ),
        ],
      );
      expect(
        () => deserializer.deserializeValue(_encode([]), type),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('empty bytes throws if no variant 0 exists', () {
      final type = EnumType(
        name: 'Special',
        variants: [
          const EnumVariantDefinition(name: 'First', discriminant: 1),
          const EnumVariantDefinition(name: 'Second', discriminant: 2),
        ],
      );
      expect(
        () => deserializer.deserializeValue(_encode([]), type),
        throwsA(isA<DeserializationException>()),
      );
    });
  });

  group('ExplicitEnum Type', () {
    test('explicit enum by variant name', () {
      final type = ExplicitEnumType(
        name: 'ErrorCode',
        variants: [
          const ExplicitEnumVariantDefinition(
            name: 'NotFound',
            discriminant: 404,
          ),
          const ExplicitEnumVariantDefinition(
            name: 'ServerError',
            discriminant: 500,
          ),
        ],
      );
      final bytes = 'NotFound'.codeUnits;
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result['variant'], 'NotFound');
      expect(result['discriminant'], 404);
    });

    test('explicit enum ServerError', () {
      final type = ExplicitEnumType(
        name: 'ErrorCode',
        variants: [
          const ExplicitEnumVariantDefinition(
            name: 'NotFound',
            discriminant: 404,
          ),
          const ExplicitEnumVariantDefinition(
            name: 'ServerError',
            discriminant: 500,
          ),
        ],
      );
      final bytes = 'ServerError'.codeUnits;
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result['variant'], 'ServerError');
      expect(result['discriminant'], 500);
    });

    test('unknown variant name throws', () {
      final type = ExplicitEnumType(
        name: 'ErrorCode',
        variants: [
          const ExplicitEnumVariantDefinition(
            name: 'NotFound',
            discriminant: 404,
          ),
        ],
      );
      expect(
        () => deserializer.deserializeValue(_encode('Unknown'.codeUnits), type),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('empty name throws', () {
      final type = ExplicitEnumType(
        name: 'ErrorCode',
        variants: [
          const ExplicitEnumVariantDefinition(
            name: 'NotFound',
            discriminant: 404,
          ),
        ],
      );
      expect(
        () => deserializer.deserializeValue(_encode([]), type),
        throwsA(isA<DeserializationException>()),
      );
    });
  });

  group('Composite Type', () {
    test('composite of two u32', () {
      final type = CompositeType.of([U32Type.type, U32Type.type]);
      final bytes = <int>[0x00, 0x00, 0x00, 0x0A, 0x00, 0x00, 0x00, 0x14];
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result, [10, 20]);
    });

    test('composite of u32 and bool', () {
      final type = CompositeType.of([U32Type.type, BooleanType.type]);
      final bytes = <int>[0x00, 0x00, 0x00, 0x2A, 0x01];
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result, [42, true]);
    });
  });

  group('ManagedDecimal Type', () {
    test('unsigned decimal', () {
      final type = ManagedDecimalType.of(18);
      final result = deserializer.deserializeValue(
        _encode([0x0D, 0xE0, 0xB6, 0xB3, 0xA7, 0x64, 0x00, 0x00]),
        type,
      );
      expect(result['mantissa'], BigInt.parse('1000000000000000000'));
      expect(result['scale'], 18);
    });

    test('signed positive decimal', () {
      final type = ManagedDecimalType.signed(6);
      final result = deserializer.deserializeValue(
        _encode([0x00, 0x0F, 0x42, 0x40]),
        type,
      );
      expect(result['mantissa'], BigInt.from(1000000));
      expect(result['scale'], 6);
    });

    test('signed negative decimal', () {
      final type = ManagedDecimalType.signed(2);
      final result = deserializer.deserializeValue(_encode([0xFF, 0x9C]), type);
      expect(result['mantissa'], BigInt.from(-100));
      expect(result['scale'], 2);
    });

    test('empty bytes returns zero', () {
      final type = ManagedDecimalType.of(8);
      final result = deserializer.deserializeValue(_encode([]), type);
      expect(result['mantissa'], BigInt.zero);
      expect(result['scale'], 8);
    });

    test('variable decimal', () {
      final type = ManagedDecimalType.variable(
        0,
      ); // scale in type is ignored for variable
      final bytes = <int>[
        0x00, 0x00, 0x00, 0x02, // length = 2
        0x03, 0xE8, // value = 1000
        0x00, 0x00, 0x00, 0x03, // scale = 3 (from encoded data)
      ];
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result['mantissa'], BigInt.from(1000));
      expect(result['scale'], 3); // scale comes from the encoded bytes
    });

    test('variable decimal zero value', () {
      final type = ManagedDecimalType.variable(0);
      final bytes = <int>[
        0x00, 0x00, 0x00, 0x00, // length = 0
        0x00, 0x00, 0x00, 0x05, // scale = 5
      ];
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result['mantissa'], BigInt.zero);
      expect(result['scale'], 5);
    });

    test('variable decimal empty bytes returns zero with scale 0', () {
      final type = ManagedDecimalType.variable(0);
      final result = deserializer.deserializeValue(_encode([]), type);
      expect(result['mantissa'], BigInt.zero);
      expect(result['scale'], 0);
    });
  });

  group('Variadic Type', () {
    test('empty variadic', () {
      final type = VariadicType.of(U32Type.type);
      final result = deserializer.deserializeValue(_encode([]), type);
      expect(result, []);
    });

    test('variadic u8', () {
      final type = VariadicType.of(U8Type.type);
      final result = deserializer.deserializeValue(
        _encode([0x01, 0x02, 0x03]),
        type,
      );
      expect(result, [1, 2, 3]);
    });

    test('variadic u32', () {
      final type = VariadicType.of(U32Type.type);
      final bytes = <int>[0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x02];
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result, [1, 2]);
    });

    test('variadic BigUInt - variable size elements', () {
      final type = VariadicType.of(BigUIntType.type);
      final bytes = <int>[
        0x00, 0x00, 0x00, 0x02, // length prefix: 2 bytes
        0x01, 0x00, // value: 256
        0x00, 0x00, 0x00, 0x01, // length prefix: 1 byte
        0x2A, // value: 42
      ];
      final result = deserializer.deserializeValue(_encode(bytes), type);
      expect(result, [BigInt.from(256), BigInt.from(42)]);
    });
  });

  group('Extension Methods', () {
    test('deserializeBigInt', () {
      final result = deserializer.deserializeBigInt(_encode([0x01, 0x00]));
      expect(result, BigInt.from(256));
    });

    test('deserializeInt 8-bit', () {
      final result = deserializer.deserializeInt(_encode([0x2A]), bits: 8);
      expect(result, 42);
    });

    test('deserializeInt 16-bit', () {
      final result = deserializer.deserializeInt(
        _encode([0x01, 0x00]),
        bits: 16,
      );
      expect(result, 256);
    });

    test('deserializeInt 32-bit', () {
      final result = deserializer.deserializeInt(
        _encode([0x00, 0x01, 0x00, 0x00]),
        bits: 32,
      );
      expect(result, 65536);
    });

    test('deserializeInt 64-bit', () {
      final result = deserializer.deserializeInt(
        _encode([0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]),
        bits: 64,
      );
      expect(result, 0x100000000);
    });

    test('deserializeInt invalid bits throws', () {
      expect(
        () => deserializer.deserializeInt(_encode([0x01]), bits: 128),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('deserializeAddress', () {
      final addressBytes = List<int>.filled(32, 0);
      final result = deserializer.deserializeAddress(_encode(addressBytes));
      expect(result, startsWith('erd1'));
    });

    test('deserializeBoolean true', () {
      final result = deserializer.deserializeBoolean(_encode([0x01]));
      expect(result, true);
    });

    test('deserializeBoolean false', () {
      final result = deserializer.deserializeBoolean(_encode([0x00]));
      expect(result, false);
    });

    test('deserializeBytes', () {
      final result = deserializer.deserializeBytes(_encode([0x01, 0x02, 0x03]));
      expect(result, Uint8List.fromList([1, 2, 3]));
    });

    test('deserializeBalance', () {
      final result = deserializer.deserializeBalance(
        _encode([0x0D, 0xE0, 0xB6, 0xB3, 0xA7, 0x64, 0x00, 0x00]),
      );
      expect(result.value, BigInt.parse('1000000000000000000'));
    });
  });

  group('deserializeByTypeNames', () {
    test('multiple values', () {
      final result = deserializer.deserializeByTypeNames(
        [
          _encode([0x00, 0x00, 0x00, 0x2A]),
          _encode([0x01]),
          _encode('hello'.codeUnits),
        ],
        ['u32', 'bool', 'utf-8 string'],
      );
      expect(result, [42, true, 'hello']);
    });

    test('mismatched lengths throws', () {
      expect(
        () => deserializer.deserializeByTypeNames(
          [
            _encode([0x01]),
          ],
          ['u32', 'bool'],
        ),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('invalid type throws', () {
      expect(
        () => deserializer.deserializeByTypeNames(
          [
            _encode([0x01]),
          ],
          ['InvalidType'],
        ),
        throwsException,
      );
    });
  });

  group('Error Cases', () {
    test('empty numeric returns zero', () {
      expect(
        deserializer.deserializeValue(_encode([]), U32Type.type),
        equals(0),
      );
      expect(
        deserializer.deserializeValue(_encode([]), U8Type.type),
        equals(0),
      );
      expect(
        deserializer.deserializeValue(_encode([]), I32Type.type),
        equals(0),
      );
      expect(
        deserializer.deserializeValue(_encode([]), BigUIntType.type),
        equals(BigInt.zero),
      );
    });

    test('invalid base64 throws', () {
      expect(
        () =>
            deserializer.deserializeValue('not_valid_base64!!!', U32Type.type),
        throwsA(isA<DeserializationException>()),
      );
    });
  });
}
