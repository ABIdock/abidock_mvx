/// Regression tests for data-carrying enum variants parsed from ABI JSON.
///
/// The ABI-JSON `variants[].fields` array is the wire payload that follows the
/// discriminant byte. Dropping it made `decodeNested` report 1 consumed byte
/// for a multi-byte variant, silently misaligning every sibling field.
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

/// Lowercase hex rendering used to pin wire bytes against literals.
String _hex(List<int> bytes) =>
    bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Verbatim shape emitted by `multiversx-sc` for `AbiEnum`, plus a wrapper
/// struct that places the enum ahead of a fixed-width sibling field.
const String _abiJson = '''
{
  "name": "AbiTester",
  "endpoints": [],
  "types": {
    "OnlyShowsUpAsNested08": {
      "type": "struct",
      "fields": [ { "name": "q", "type": "u32" } ]
    },
    "AbiEnum": {
      "type": "enum",
      "variants": [
        { "name": "Nothing", "discriminant": 0 },
        { "name": "Something", "discriminant": 1,
          "fields": [ { "name": "0", "type": "i32" } ] },
        { "name": "SomethingMore", "discriminant": 2,
          "fields": [ { "name": "0", "type": "u8" },
                      { "name": "1", "type": "OnlyShowsUpAsNested08" } ] },
        { "name": "SomeStruct", "discriminant": 3,
          "fields": [ { "name": "a", "type": "u16" } ] }
      ]
    },
    "Wrapper": {
      "type": "struct",
      "fields": [
        { "name": "e", "type": "AbiEnum" },
        { "name": "tail", "type": "u32" }
      ]
    }
  }
}
''';

void main() {
  late SmartContractAbi abi;
  late EnumType abiEnum;
  late BinaryCodec codec;

  setUp(() {
    abi = SmartContractAbi.fromJson(_abiJson);
    abiEnum = abi.types['AbiEnum']! as EnumType;
    codec = BinaryCodec.withDefaults();
  });

  group('enum variant fields parsing', () {
    test('fieldless variant keeps a null fields list', () {
      final EnumVariantDefinition nothing = abiEnum.getVariant('Nothing');

      expect(nothing.discriminant, equals(0));
      expect(nothing.fields, isNull);
      expect(nothing.hasFields, isFalse);
    });

    test('single-field variant carries its payload type', () {
      final EnumVariantDefinition something = abiEnum.getVariant('Something');

      expect(something.discriminant, equals(1));
      expect(something.fieldCount, equals(1));
      expect(identical(something.fields![0], I32Type.type), isTrue);
    });

    test('multi-field variant preserves declaration order', () {
      final EnumVariantDefinition more = abiEnum.getVariant('SomethingMore');

      expect(more.fieldCount, equals(2));
      expect(identical(more.fields![0], U8Type.type), isTrue);
      expect(more.fields![1], isA<StructType>());
      expect(
        (more.fields![1] as StructType).name,
        equals('OnlyShowsUpAsNested08'),
      );
    });
  });

  group('enum variant fields codec', () {
    test('decodeNested consumes discriminant plus payload', () {
      final (TypedValue value, int consumed) = codec.decodeNested(
        Uint8List.fromList(<int>[1, 0, 0, 0, 42]),
        abiEnum,
        0,
      );
      final EnumValue decoded = value as EnumValue;

      expect(consumed, equals(5));
      expect(decoded.variantName, equals('Something'));
      expect(decoded.getField(0).nativeValue, equals(42));
    });

    test('decodeNested walks a nested struct payload', () {
      final (TypedValue value, int consumed) = codec.decodeNested(
        Uint8List.fromList(<int>[2, 7, 0, 0, 0, 9]),
        abiEnum,
        0,
      );
      final EnumValue decoded = value as EnumValue;

      expect(consumed, equals(6));
      expect(decoded.variantName, equals('SomethingMore'));
      expect(decoded.getField(0).nativeValue, equals(7));
      expect(
        (decoded.getField(1) as StructValue).getFieldValue('q').nativeValue,
        equals(9),
      );
    });

    test('encodeNested emits [discriminant][dep-encoded fields]', () {
      final TypedValue value = abiEnum.createValue(<String, dynamic>{
        'variant': 'Something',
        'fields': <dynamic>[42],
      });

      expect(_hex(codec.encodeNested(value)), equals('010000002a'));
      expect(_hex(codec.encodeTopLevel(value)), equals('010000002a'));
    });

    test('encodeNested round-trips the decoded bytes', () {
      final Uint8List bytes = Uint8List.fromList(<int>[2, 7, 0, 0, 0, 9]);
      final (TypedValue value, _) = codec.decodeNested(bytes, abiEnum, 0);

      expect(_hex(codec.encodeNested(value)), equals('020700000009'));
    });

    test('fieldless variant 0 still top-encodes to an empty buffer', () {
      final TypedValue value = abiEnum.createValue('Nothing');

      expect(codec.encodeTopLevel(value), isEmpty);
      expect(_hex(codec.encodeNested(value)), equals('00'));
    });

    test('fieldless non-zero variant top-encodes to its discriminant', () {
      final TypedValue value = abiEnum.createValue(<String, dynamic>{
        'variant': 'SomeStruct',
        'fields': <dynamic>[513],
      });

      expect(_hex(codec.encodeTopLevel(value)), equals('030201'));
    });

    test(
      'a sibling field after a fielded enum decodes at the right offset',
      () {
        final StructType wrapper = abi.types['Wrapper']! as StructType;
        final (TypedValue value, int consumed) = codec.decodeNested(
          Uint8List.fromList(<int>[1, 0, 0, 0, 42, 0, 0, 0, 7]),
          wrapper,
          0,
        );
        final StructValue decoded = value as StructValue;

        expect(consumed, equals(9));
        expect(
          (decoded.getFieldValue('e') as EnumValue).getField(0).nativeValue,
          equals(42),
        );
        expect(decoded.getFieldValue('tail').nativeValue, equals(7));
      },
    );
  });
}
