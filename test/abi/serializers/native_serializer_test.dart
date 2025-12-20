import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

EndpointDefinition _endpoint(String name, List<AbiType> types) {
  return EndpointDefinition(
    name: name,
    input: types
        .asMap()
        .entries
        .map((e) => EndpointParameterDefinition('p${e.key}', null, e.value))
        .toList(),
    output: [],
  );
}

List<TypedValue> _convert(List<dynamic> args, List<AbiType> types) {
  return NativeSerializer.nativeToTypedValues(args, _endpoint('test', types));
}

TypedValue _convertSingle(dynamic arg, AbiType type) {
  return _convert([arg], [type]).first;
}

void main() {
  group('NativeSerializer Primitive Types', () {
    group('Unsigned Integers', () {
      test('U8Type', () {
        final result = _convertSingle(255, U8Type.type);
        expect(result, isA<U8Value>());
        expect((result as U8Value).nativeValue, 255);
      });

      test('U8Type from string', () {
        final result = _convertSingle('128', U8Type.type);
        expect((result as U8Value).nativeValue, 128);
      });

      test('U16Type', () {
        final result = _convertSingle(65535, U16Type.type);
        expect(result, isA<U16Value>());
        expect((result as U16Value).nativeValue, 65535);
      });

      test('U32Type', () {
        final result = _convertSingle(4294967295, U32Type.type);
        expect(result, isA<U32Value>());
        expect((result as U32Value).nativeValue, 4294967295);
      });

      test('U64Type', () {
        final result = _convertSingle(
          BigInt.parse('18446744073709551615'),
          U64Type.type,
        );
        expect(result, isA<U64Value>());
        expect(
          (result as U64Value).nativeValue,
          BigInt.parse('18446744073709551615'),
        );
      });

      test('U64Type from int', () {
        final result = _convertSingle(12345678901234, U64Type.type);
        expect((result as U64Value).nativeValue, BigInt.from(12345678901234));
      });

      test('BigUIntType', () {
        final bigVal = BigInt.parse('123456789012345678901234567890');
        final result = _convertSingle(bigVal, BigUIntType.type);
        expect(result, isA<BigUIntValue>());
        expect((result as BigUIntValue).nativeValue, bigVal);
      });

      test('BigUIntType from string', () {
        final result = _convertSingle(
          '999999999999999999999',
          BigUIntType.type,
        );
        expect(
          (result as BigUIntValue).nativeValue,
          BigInt.parse('999999999999999999999'),
        );
      });
    });

    group('Signed Integers', () {
      test('I8Type positive', () {
        final result = _convertSingle(127, I8Type.type);
        expect(result, isA<I8Value>());
        expect((result as I8Value).nativeValue, 127);
      });

      test('I8Type negative', () {
        final result = _convertSingle(-128, I8Type.type);
        expect((result as I8Value).nativeValue, -128);
      });

      test('I16Type', () {
        final result = _convertSingle(-32768, I16Type.type);
        expect(result, isA<I16Value>());
        expect((result as I16Value).nativeValue, -32768);
      });

      test('I32Type', () {
        final result = _convertSingle(-2147483648, I32Type.type);
        expect(result, isA<I32Value>());
        expect((result as I32Value).nativeValue, -2147483648);
      });

      test('I64Type', () {
        final result = _convertSingle(
          BigInt.from(-9223372036854775808),
          I64Type.type,
        );
        expect(result, isA<I64Value>());
        expect(
          (result as I64Value).nativeValue,
          BigInt.from(-9223372036854775808),
        );
      });

      test('BigIntType', () {
        final bigVal = BigInt.parse('-123456789012345678901234567890');
        final result = _convertSingle(bigVal, BigIntType.type);
        expect(result, isA<BigIntValue>());
        expect((result as BigIntValue).nativeValue, bigVal);
      });
    });

    group('Boolean', () {
      test('BooleanType true', () {
        final result = _convertSingle(true, BooleanType.type);
        expect(result, isA<BooleanValue>());
        expect((result as BooleanValue).nativeValue, true);
      });

      test('BooleanType false', () {
        final result = _convertSingle(false, BooleanType.type);
        expect((result as BooleanValue).nativeValue, false);
      });

      test('BooleanType from string true', () {
        final result = _convertSingle('true', BooleanType.type);
        expect((result as BooleanValue).nativeValue, true);
      });

      test('BooleanType from int 1', () {
        final result = _convertSingle(1, BooleanType.type);
        expect((result as BooleanValue).nativeValue, true);
      });

      test('BooleanType from int 0', () {
        final result = _convertSingle(0, BooleanType.type);
        expect((result as BooleanValue).nativeValue, false);
      });
    });

    group('String', () {
      test('StringType', () {
        final result = _convertSingle('hello world', StringType.type);
        expect(result, isA<StringValue>());
        expect((result as StringValue).nativeValue, 'hello world');
      });

      test('StringType empty', () {
        final result = _convertSingle('', StringType.type);
        expect((result as StringValue).nativeValue, '');
      });

      test('StringType from int', () {
        final result = _convertSingle(12345, StringType.type);
        expect((result as StringValue).nativeValue, '12345');
      });
    });

    group('Bytes', () {
      test('BytesType from Uint8List', () {
        final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        final result = _convertSingle(bytes, BytesType.type);
        expect(result, isA<BytesValue>());
        expect((result as BytesValue).nativeValue, [1, 2, 3, 4, 5]);
      });

      test('BytesType from List<int>', () {
        final result = _convertSingle([10, 20, 30], BytesType.type);
        expect((result as BytesValue).nativeValue, [10, 20, 30]);
      });

      test('BytesType from hex string', () {
        final result = _convertSingle('0x0102030405', BytesType.type);
        expect((result as BytesValue).nativeValue, [1, 2, 3, 4, 5]);
      });

      test('BytesType from plain string', () {
        final result = _convertSingle('ABC', BytesType.type);
        expect((result as BytesValue).nativeValue, [65, 66, 67]);
      });
    });

    group('Address', () {
      test('AddressType from bech32', () {
        const bech32 =
            'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu';
        final result = _convertSingle(bech32, AddressType.type);
        expect(result, isA<AddressValue>());
        expect((result as AddressValue).nativeValue, bech32);
      });

      test('AddressType from hex with 0x', () {
        final hex = '0x${'00' * 32}';
        final result = _convertSingle(hex, AddressType.type);
        expect(result, isA<AddressValue>());
      });

      test('AddressType from 64-char hex', () {
        final hex = '00' * 32;
        final result = _convertSingle(hex, AddressType.type);
        expect(result, isA<AddressValue>());
      });

      test('AddressType from Uint8List', () {
        final bytes = Uint8List(32);
        final result = _convertSingle(bytes, AddressType.type);
        expect(result, isA<AddressValue>());
      });
    });

    group('TokenIdentifier', () {
      test('TokenIdentifierType', () {
        final result = _convertSingle('WEGLD-bd4d79', TokenIdentifierType.type);
        expect(result, isA<TokenIdentifierValue>());
        expect((result as TokenIdentifierValue).identifier, 'WEGLD-bd4d79');
      });

      test('EgldOrEsdtTokenIdentifierType with ESDT', () {
        final result = _convertSingle(
          'USDC-c76f1f',
          EgldOrEsdtTokenIdentifierType.type,
        );
        expect(result, isA<EgldOrEsdtTokenIdentifierValue>());
        expect(
          (result as EgldOrEsdtTokenIdentifierValue).identifier,
          'USDC-c76f1f',
        );
      });

      test('EgldOrEsdtTokenIdentifierType with EGLD', () {
        final result = _convertSingle(
          'EGLD',
          EgldOrEsdtTokenIdentifierType.type,
        );
        expect(result, isA<EgldOrEsdtTokenIdentifierValue>());
        expect((result as EgldOrEsdtTokenIdentifierValue).isEgld, true);
      });
    });

    group('H256', () {
      test('H256Type from hex string', () {
        final hex = '1234567890abcdef' * 4;
        final result = _convertSingle(hex, H256Type.type);
        expect(result, isA<H256Value>());
        expect((result as H256Value).toHex(), hex);
      });

      test('H256Type from hex with 0x prefix', () {
        final hex = '0x${'ab' * 32}';
        final result = _convertSingle(hex, H256Type.type);
        expect(result, isA<H256Value>());
      });

      test('H256Type from List<int>', () {
        final bytes = List<int>.filled(32, 0xff);
        final result = _convertSingle(bytes, H256Type.type);
        expect(result, isA<H256Value>());
        expect((result as H256Value).value.length, 32);
      });
    });

    group('CodeMetadata', () {
      test('CodeMetadataType from int', () {
        // Flags per MultiversX spec: upgradeable=0x0100, readable=0x0400, payable=0x0002
        final result = _convertSingle(0x0502, CodeMetadataType.type);
        expect(result, isA<CodeMetadataValue>());
        expect((result as CodeMetadataValue).isUpgradeable, true);
        expect(result.isPayable, true);
        expect(result.isReadable, true);
      });

      test('CodeMetadataType from 2-byte list', () {
        // bytes [0x05, 0x02] = big-endian 0x0502 = upgradeable | readable | payable
        final result = _convertSingle([0x05, 0x02], CodeMetadataType.type);
        expect(result, isA<CodeMetadataValue>());
        expect((result as CodeMetadataValue).flags, 0x0502);
        expect(result.isUpgradeable, true);
        expect(result.isReadable, true);
        expect(result.isPayable, true);
      });
    });

    group('Nothing', () {
      test('NothingType', () {
        final result = _convertSingle(null, NothingType.type);
        expect(result, isA<NothingValue>());
      });

      test('NothingType ignores value', () {
        final result = _convertSingle('ignored', NothingType.type);
        expect(result, isA<NothingValue>());
      });
    });
  });

  group('NativeSerializer Collection Types', () {
    group('List', () {
      test('ListType of U32', () {
        final listType = ListType(U32Type.type);
        final result = _convertSingle([1, 2, 3, 4, 5], listType);
        expect(result, isA<ListValue>());
        final listVal = result as ListValue;
        expect(listVal.length, 5);
        expect((listVal[0] as U32Value).nativeValue, 1);
        expect((listVal[4] as U32Value).nativeValue, 5);
      });

      test('ListType empty', () {
        final listType = ListType(StringType.type);
        final result = _convertSingle(<String>[], listType);
        expect((result as ListValue).length, 0);
      });

      test('ListType nested', () {
        final nestedType = ListType(ListType(U8Type.type));
        final result = _convertSingle([
          [1, 2],
          [3, 4, 5],
        ], nestedType);
        expect(result, isA<ListValue>());
        final outer = result as ListValue;
        expect(outer.length, 2);
        expect((outer[0] as ListValue).length, 2);
        expect((outer[1] as ListValue).length, 3);
      });
    });

    group('Array', () {
      test('ArrayType of U32', () {
        final arrayType = ArrayType(U32Type.type, 3);
        final result = _convertSingle([10, 20, 30], arrayType);
        expect(result, isA<ArrayValue>());
        final arrayVal = result as ArrayValue;
        expect(arrayVal.length, 3);
        expect((arrayVal[0] as U32Value).nativeValue, 10);
        expect((arrayVal[2] as U32Value).nativeValue, 30);
      });

      test('ArrayType wrong length throws', () {
        final arrayType = ArrayType(U32Type.type, 3);
        expect(
          () => _convertSingle([1, 2], arrayType),
          throwsA(isA<AbiNativeSerializationException>()),
        );
      });

      test('ArrayType of Address', () {
        final arrayType = ArrayType(AddressType.type, 2);
        const addr =
            'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu';
        final result = _convertSingle([addr, addr], arrayType);
        expect(result, isA<ArrayValue>());
        expect((result as ArrayValue).length, 2);
      });
    });

    group('Option', () {
      test('OptionType none', () {
        final optType = OptionType(U32Type.type);
        final result = _convertSingle(null, optType);
        expect(result, isA<OptionValue>());
        expect((result as OptionValue).isNone, true);
      });

      test('OptionType some', () {
        final optType = OptionType(U32Type.type);
        final result = _convertSingle(42, optType);
        expect(result, isA<OptionValue>());
        final opt = result as OptionValue;
        expect(opt.isSome, true);
        expect((opt.value as U32Value).nativeValue, 42);
      });

      test('OptionType nested', () {
        final optType = OptionType(OptionType(StringType.type));
        final result = _convertSingle('hello', optType);
        expect(result, isA<OptionValue>());
        final outer = result as OptionValue;
        expect(outer.isSome, true);
        final inner = outer.value as OptionValue;
        expect(inner.isSome, true);
        expect((inner.value as StringValue).nativeValue, 'hello');
      });
    });

    group('Optional', () {
      test('OptionalType missing', () {
        final optType = OptionalType.of(BigUIntType.type);
        final result = _convertSingle(null, optType);
        expect(result, isA<OptionalValue>());
        expect((result as OptionalValue).isMissing, true);
      });

      test('OptionalType provided', () {
        final optType = OptionalType.of(BigUIntType.type);
        final result = _convertSingle(BigInt.from(100), optType);
        expect(result, isA<OptionalValue>());
        final opt = result as OptionalValue;
        expect(opt.isProvided, true);
        expect((opt.value as BigUIntValue).nativeValue, BigInt.from(100));
      });
    });
  });

  group('NativeSerializer Composite Types', () {
    group('Tuple', () {
      test('TupleType simple', () {
        final tupleType = TupleType([
          U32Type.type,
          StringType.type,
          BooleanType.type,
        ]);
        final result = _convertSingle([42, 'hello', true], tupleType);
        expect(result, isA<TupleValue>());
        final tuple = result as TupleValue;
        expect((tuple.fields[0].value as U32Value).nativeValue, 42);
        expect((tuple.fields[1].value as StringValue).nativeValue, 'hello');
        expect((tuple.fields[2].value as BooleanValue).nativeValue, true);
      });

      test('TupleType nested', () {
        final innerTuple = TupleType([U8Type.type, U8Type.type]);
        final outerTuple = TupleType([innerTuple, StringType.type]);
        final result = _convertSingle([
          [1, 2],
          'test',
        ], outerTuple);
        expect(result, isA<TupleValue>());
      });
    });

    group('Struct', () {
      test('StructType simple', () {
        final structType = StructType(
          name: 'Person',
          fieldDefinitions: [
            FieldDefinition(name: 'name', type: StringType.type),
            FieldDefinition(name: 'age', type: U32Type.type),
          ],
        );
        final result = _convertSingle({'name': 'Alice', 'age': 30}, structType);
        expect(result, isA<StructValue>());
        final struct = result as StructValue;
        expect(
          (struct.getFieldValue('name') as StringValue).nativeValue,
          'Alice',
        );
        expect((struct.getFieldValue('age') as U32Value).nativeValue, 30);
      });

      test('StructType missing field throws', () {
        final structType = StructType(
          name: 'Point',
          fieldDefinitions: [
            FieldDefinition(name: 'x', type: I32Type.type),
            FieldDefinition(name: 'y', type: I32Type.type),
          ],
        );
        expect(
          () => _convertSingle({'x': 10}, structType),
          throwsA(isA<AbiNativeSerializationException>()),
        );
      });

      test('StructType nested', () {
        final innerStruct = StructType(
          name: 'Inner',
          fieldDefinitions: [
            FieldDefinition(name: 'value', type: U64Type.type),
          ],
        );
        final outerStruct = StructType(
          name: 'Outer',
          fieldDefinitions: [
            FieldDefinition(name: 'inner', type: innerStruct),
            FieldDefinition(name: 'flag', type: BooleanType.type),
          ],
        );
        final result = _convertSingle({
          'inner': {'value': BigInt.from(999)},
          'flag': true,
        }, outerStruct);
        expect(result, isA<StructValue>());
      });
    });

    group('Enum', () {
      test('EnumType by discriminant', () {
        final enumType = EnumType(
          name: 'Status',
          variants: [
            const EnumVariantDefinition(name: 'Pending', discriminant: 0),
            const EnumVariantDefinition(name: 'Active', discriminant: 1),
            const EnumVariantDefinition(name: 'Done', discriminant: 2),
          ],
        );
        final result = _convertSingle(1, enumType);
        expect(result, isA<EnumValue>());
        expect((result as EnumValue).variant.name, 'Active');
      });

      test('EnumType by name', () {
        final enumType = EnumType(
          name: 'Status',
          variants: [
            const EnumVariantDefinition(name: 'Pending', discriminant: 0),
            const EnumVariantDefinition(name: 'Active', discriminant: 1),
          ],
        );
        final result = _convertSingle('Pending', enumType);
        expect(result, isA<EnumValue>());
        expect((result as EnumValue).variant.name, 'Pending');
      });

      test('EnumType with fields', () {
        final enumType = EnumType(
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
              fields: [StringType.type],
            ),
          ],
        );
        final result = _convertSingle({
          'variant': 'Ok',
          'fields': [42],
        }, enumType);
        expect(result, isA<EnumValue>());
        final enumVal = result as EnumValue;
        expect(enumVal.variant.name, 'Ok');
        expect((enumVal.fields[0] as U32Value).nativeValue, 42);
      });
    });

    group('ExplicitEnum', () {
      test('ExplicitEnumType by name', () {
        final enumType = ExplicitEnumType(
          name: 'Color',
          variants: [
            const ExplicitEnumVariantDefinition(name: 'Red', discriminant: 0),
            const ExplicitEnumVariantDefinition(name: 'Green', discriminant: 1),
            const ExplicitEnumVariantDefinition(name: 'Blue', discriminant: 2),
          ],
        );
        final result = _convertSingle('Blue', enumType);
        expect(result, isA<ExplicitEnumValue>());
        expect((result as ExplicitEnumValue).variant.name, 'Blue');
      });

      test('ExplicitEnumType by discriminant', () {
        final enumType = ExplicitEnumType(
          name: 'Priority',
          variants: [
            const ExplicitEnumVariantDefinition(name: 'Low', discriminant: 0),
            const ExplicitEnumVariantDefinition(name: 'High', discriminant: 10),
          ],
        );
        final result = _convertSingle(10, enumType);
        expect((result as ExplicitEnumValue).variant.name, 'High');
      });
    });

    group('Composite', () {
      test('CompositeType multi', () {
        final compositeType = CompositeType.of([U32Type.type, StringType.type]);
        final result = _convertSingle([100, 'test'], compositeType);
        expect(result, isA<CompositeValue>());
        final comp = result as CompositeValue;
        expect((comp.fields[0] as U32Value).nativeValue, 100);
        expect((comp.fields[1] as StringValue).nativeValue, 'test');
      });
    });

    group('ManagedDecimal', () {
      test('ManagedDecimalType', () {
        final decType = ManagedDecimalType.of(18);
        final result = _convertSingle([
          BigInt.from(1000000000000000000),
          18,
        ], decType);
        expect(result, isA<ManagedDecimalValue>());
      });
    });
  });

  group('NativeSerializer Variadic', () {
    test('VariadicType', () {
      final endpoint = EndpointDefinition(
        name: 'test',
        input: [
          EndpointParameterDefinition('fixed', null, U32Type.type),
          EndpointParameterDefinition(
            'varargs',
            null,
            VariadicType.of(StringType.type),
          ),
        ],
        output: [],
      );
      final cardinality = NativeSerializer.getArgumentsCardinality(
        endpoint.input,
      );
      expect(cardinality.variadic, true);
      expect(cardinality.min, 1);
    });
  });

  group('NativeSerializer Pass-through', () {
    test('TypedValue pass-through', () {
      final existingValue = U32Value(42);
      final result = _convertSingle(existingValue, U32Type.type);
      expect(identical(result, existingValue), true);
    });
  });

  group('NativeSerializer Error Handling', () {
    test('wrong argument count throws', () {
      expect(
        () => _convert([1, 2, 3], [U32Type.type]),
        throwsA(isA<AbiNativeSerializationException>()),
      );
    });

    test('invalid type for List throws', () {
      final listType = ListType(U32Type.type);
      expect(
        () => _convertSingle('not a list', listType),
        throwsA(isA<AbiNativeSerializationException>()),
      );
    });

    test('invalid type for Struct throws', () {
      final structType = StructType(
        name: 'Test',
        fieldDefinitions: [FieldDefinition(name: 'x', type: U32Type.type)],
      );
      expect(
        () => _convertSingle('not a map', structType),
        throwsA(isA<AbiNativeSerializationException>()),
      );
    });

    test('invalid type for Tuple throws', () {
      final tupleType = TupleType([U32Type.type]);
      expect(
        () => _convertSingle('not a list', tupleType),
        throwsA(isA<AbiNativeSerializationException>()),
      );
    });
  });

  group('NativeSerializer Utility Methods', () {
    test('typedValuesToNative', () {
      final typed = [
        U32Value(42),
        BooleanValue(true),
        StringValue('hello'),
        BigUIntValue(BigInt.from(1000)),
      ];
      final native = NativeSerializer.typedValuesToNative(typed);
      expect(native[0], 42);
      expect(native[1], true);
      expect(native[2], 'hello');
      expect(native[3], BigInt.from(1000));
    });

    test('validateValues', () {
      expect(NativeSerializer.validateValues([42], ['u32']), true);
      expect(NativeSerializer.validateValues([true], ['bool']), true);
      expect(NativeSerializer.validateValues(['test'], ['bytes']), true);
      expect(NativeSerializer.validateValues([BigInt.one], ['BigUint']), true);
    });

    test('getArgumentsCardinality fixed', () {
      final params = [
        EndpointParameterDefinition('a', null, U32Type.type),
        EndpointParameterDefinition('b', null, StringType.type),
      ];
      final cardinality = NativeSerializer.getArgumentsCardinality(params);
      expect(cardinality.min, 2);
      expect(cardinality.max, 2);
      expect(cardinality.variadic, false);
    });

    test('getArgumentsCardinality variadic', () {
      final params = [
        EndpointParameterDefinition('fixed', null, U32Type.type),
        EndpointParameterDefinition('var', null, VariadicType.of(U8Type.type)),
      ];
      final cardinality = NativeSerializer.getArgumentsCardinality(params);
      expect(cardinality.min, 1);
      expect(cardinality.max, -1);
      expect(cardinality.variadic, true);
    });
  });
}
