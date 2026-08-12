import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('MultiValueType', () {
    test('name is multi<u8,u32>', () {
      final MultiValueType type = MultiValueType(2, <AbiType>[
        U8Type.type,
        U32Type.type,
      ]);
      expect(type.name, 'multi<u8,u32>');
      expect(type.arity, 2);
    });

    test('type-string "multi<u8, u32>" resolves to MultiValueType', () {
      final AbiTypeFactory factory = AbiTypeFactory();
      final AbiType resolved = factory.fromTypeFormula(
        TypeFormulaParser.parseString('multi<u8, u32>'),
      );
      expect(resolved, isA<MultiValueType>());
      expect(resolved, isNot(isA<TupleType>()));
      final MultiValueType multi = resolved as MultiValueType;
      expect(multi.arity, 2);
      expect(multi.types[0], isA<U8Type>());
      expect(multi.types[1], isA<U32Type>());
    });

    test('type-string "tuple<u8, u32>" still resolves to TupleType', () {
      final AbiTypeFactory factory = AbiTypeFactory();
      final AbiType resolved = factory.fromTypeFormula(
        TypeFormulaParser.parseString('tuple<u8, u32>'),
      );
      expect(resolved, isA<TupleType>());
      expect(resolved, isNot(isA<MultiValueType>()));
    });

    test('MultiValue2<u8, u32> resolves to MultiValueType', () {
      final AbiTypeFactory factory = AbiTypeFactory();
      final AbiType resolved = factory.fromTypeFormula(
        TypeFormulaParser.parseString('MultiValue2<u8, u32>'),
      );
      expect(resolved, isA<MultiValueType>());
    });
  });

  group('MultiValueBinaryCodec', () {
    test('encodeTopLevel concatenates inner top-level encodings', () {
      final BinaryCodec codec = BinaryCodec.withDefaults();
      final MultiValueType type = MultiValueType(2, <AbiType>[
        U8Type.type,
        U32Type.type,
      ]);
      final MultiValueValue value = MultiValueValue(type, <TypedValue>[
        U8Value(7),
        U32Value(258),
      ]);

      final Uint8List bytes = codec.encodeTopLevel(value);
      expect(bytes, equals(<int>[0x07, 0x01, 0x02]));
    });

    test('encodeNested throws AbiBinaryCodecException', () {
      final MultiValueBinaryCodec codec = MultiValueBinaryCodec(
        BinaryCodec.withDefaults(),
      );
      final MultiValueType type = MultiValueType(1, <AbiType>[U8Type.type]);
      final MultiValueValue value = MultiValueValue(type, <TypedValue>[
        U8Value(1),
      ]);
      expect(() => codec.encodeNested(value), throwsA(isA<Object>()));
    });

    test('decodeTopLevel from single buffer throws', () {
      final MultiValueBinaryCodec codec = MultiValueBinaryCodec(
        BinaryCodec.withDefaults(),
      );
      final MultiValueType type = MultiValueType(1, <AbiType>[U8Type.type]);
      expect(
        () => codec.decodeTopLevel(Uint8List.fromList(<int>[0x01]), type),
        throwsA(isA<Object>()),
      );
    });
  });

  group('ArgSerializer.buffersToValues with MultiValueType', () {
    test('decodes two buffers into MultiValueValue(2, [u8, u32])', () {
      final ArgSerializer serializer = ArgSerializer();
      final MultiValueType type = MultiValueType(2, <AbiType>[
        U8Type.type,
        U32Type.type,
      ]);
      final List<Uint8List> buffers = <Uint8List>[
        Uint8List.fromList(<int>[0x2A]),
        Uint8List.fromList(<int>[0x00, 0x00, 0x01, 0x00]),
      ];

      final List<TypedValue> result = serializer.buffersToValues(
        buffers,
        <ParameterDefinition>[ParameterDefinition(type)],
      );

      expect(result.length, 1);
      final MultiValueValue mv = result.first as MultiValueValue;
      expect(mv.values.length, 2);
      expect((mv.values[0] as U8Value).nativeValue, 42);
      expect((mv.values[1] as U32Value).nativeValue, 256);
    });
  });
}
