import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('BinaryCodec - Basic Encoding', () {
    late BinaryCodec codec;

    setUp(() {
      codec = BinaryCodec.withDefaults();
    });

    test('encodes U32Value with minimal bytes', () {
      final value = U32Value(42);
      final bytes = codec.encodeTopLevel(value);
      expect(bytes, [0x2a]);
    });

    test('encodes U32Value max', () {
      final value = U32Value(4294967295);
      final bytes = codec.encodeTopLevel(value);
      expect(bytes, [0xff, 0xff, 0xff, 0xff]);
    });

    test('encodes I32Value negative', () {
      final value = I32Value(-1);
      final bytes = codec.encodeTopLevel(value);
      expect(bytes, [0xff]);
    });

    test('encodes BigUIntValue', () {
      final value = BigUIntValue(BigInt.from(1000));
      final bytes = codec.encodeTopLevel(value);
      expect(bytes, [0x03, 0xe8]);
    });

    test('encodes zero as empty buffer', () {
      final value = U32Value(0);
      final bytes = codec.encodeTopLevel(value);
      expect(bytes, isEmpty);
    });

    test('encodes BooleanValue true', () {
      final value = BooleanValue(true);
      final bytes = codec.encodeTopLevel(value);
      expect(bytes, [0x01]);
    });

    test('encodes BooleanValue false as empty', () {
      final value = BooleanValue(false);
      final bytes = codec.encodeTopLevel(value);
      expect(bytes, isEmpty);
    });

    test('encodes StringValue', () {
      final value = StringValue('hello');
      final bytes = codec.encodeTopLevel(value);
      expect(bytes, [0x68, 0x65, 0x6c, 0x6c, 0x6f]);
    });

    test('encodes BytesValue', () {
      final value = BytesValue(Uint8List.fromList([1, 2, 3]));
      final bytes = codec.encodeTopLevel(value);
      expect(bytes, [1, 2, 3]);
    });
  });

  group('BinaryCodec - Nested Encoding', () {
    late BinaryCodec codec;

    setUp(() {
      codec = BinaryCodec.withDefaults();
    });

    test('encodes nested U32Value with fixed size', () {
      final value = U32Value(42);
      final bytes = codec.encodeNested(value);
      expect(bytes, [0, 0, 0, 42]);
    });

    test('encodes nested zero with fixed size', () {
      final value = U32Value(0);
      final bytes = codec.encodeNested(value);
      expect(bytes, [0, 0, 0, 0]);
    });

    test('encodes nested BooleanValue with fixed size', () {
      final value = BooleanValue(true);
      final bytes = codec.encodeNested(value);
      expect(bytes, [1]);
    });
  });

  group('BinaryCodec - Various Types', () {
    late BinaryCodec codec;

    setUp(() {
      codec = BinaryCodec.withDefaults();
    });

    test('encodes U8Value', () {
      final value = U8Value(255);
      final bytes = codec.encodeTopLevel(value);
      expect(bytes, [0xff]);
    });

    test('encodes U16Value', () {
      final value = U16Value(1000);
      final bytes = codec.encodeTopLevel(value);
      expect(bytes, [0x03, 0xe8]);
    });

    test('singleton pattern works', () {
      final codec1 = BinaryCodec.withDefaults();
      final codec2 = BinaryCodec.withDefaults();
      expect(identical(codec1, codec2), isTrue);
    });
  });

  group('BinaryCodec - Enum with Explicit Discriminants', () {
    late BinaryCodec codec;

    setUp(() {
      codec = BinaryCodec.withDefaults();
    });

    test('decodes enum with non-sequential discriminants', () {
      final enumType = EnumType(
        name: 'Status',
        variants: [
          const EnumVariantDefinition(name: 'Unknown', discriminant: 0),
          const EnumVariantDefinition(name: 'Active', discriminant: 10),
          const EnumVariantDefinition(name: 'Inactive', discriminant: 20),
        ],
      );

      final bytes = Uint8List.fromList([10]);
      final value = codec.decodeTopLevel(bytes, enumType) as EnumValue;
      expect(value.variant.name, 'Active');
      expect(value.variant.discriminant, 10);
    });

    test('decodes enum with high discriminant value', () {
      final enumType = EnumType(
        name: 'Status',
        variants: [
          const EnumVariantDefinition(name: 'A', discriminant: 0),
          const EnumVariantDefinition(name: 'B', discriminant: 100),
          const EnumVariantDefinition(name: 'C', discriminant: 200),
        ],
      );

      final bytes = Uint8List.fromList([200]);
      final value = codec.decodeTopLevel(bytes, enumType) as EnumValue;
      expect(value.variant.name, 'C');
      expect(value.variant.discriminant, 200);
    });

    test('throws on invalid discriminant', () {
      final enumType = EnumType(
        name: 'Status',
        variants: [
          const EnumVariantDefinition(name: 'A', discriminant: 0),
          const EnumVariantDefinition(name: 'B', discriminant: 10),
        ],
      );

      final bytes = Uint8List.fromList([5]);
      expect(
        () => codec.decodeTopLevel(bytes, enumType),
        throwsA(isA<AbiBinaryCodecException>()),
      );
    });

    test('encodes enum with explicit discriminant', () {
      final enumType = EnumType(
        name: 'Status',
        variants: [
          const EnumVariantDefinition(name: 'Unknown', discriminant: 0),
          const EnumVariantDefinition(name: 'Active', discriminant: 10),
        ],
      );

      final variant = enumType.getVariant('Active');
      final value = EnumValue(enumType, variant, const []);
      final bytes = codec.encodeTopLevel(value);
      expect(bytes, [10]);
    });

    test('empty buffer decodes to variant with discriminant 0', () {
      final enumType = EnumType(
        name: 'Status',
        variants: [
          const EnumVariantDefinition(name: 'Unknown', discriminant: 0),
          const EnumVariantDefinition(name: 'Active', discriminant: 10),
        ],
      );

      final bytes = Uint8List(0);
      final value = codec.decodeTopLevel(bytes, enumType) as EnumValue;
      expect(value.variant.name, 'Unknown');
      expect(value.variant.discriminant, 0);
    });

    test('empty buffer throws if no variant with discriminant 0', () {
      final enumType = EnumType(
        name: 'Status',
        variants: [
          const EnumVariantDefinition(name: 'Active', discriminant: 10),
          const EnumVariantDefinition(name: 'Inactive', discriminant: 20),
        ],
      );

      final bytes = Uint8List(0);
      expect(
        () => codec.decodeTopLevel(bytes, enumType),
        throwsA(isA<AbiBinaryCodecException>()),
      );
    });
  });
}
