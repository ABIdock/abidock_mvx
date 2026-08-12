/// Regression tests aligning `ExplicitEnumValue.toBytes()` with its codec.
///
/// The framework's only `explicit-enum`, `OperationCompletionStatus`,
/// top-encodes the variant NAME (`output.set_slice_u8(self.output_bytes())`)
/// and its ABI JSON carries no `discriminant` key at all. `toBytes()` used to
/// emit a synthesised discriminant byte, which appears nowhere on the wire and
/// leaked into container encodings such as `OptionValue.toBytes()`.
import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  late ExplicitEnumType status;
  late BinaryCodec codec;

  setUp(() {
    status = ExplicitEnumType(
      name: 'OperationCompletionStatus',
      variants: const <ExplicitEnumVariantDefinition>[
        ExplicitEnumVariantDefinition(name: 'completed', discriminant: 0),
        ExplicitEnumVariantDefinition(name: 'interrupted', discriminant: 1),
      ],
    );
    codec = BinaryCodec.withDefaults();
  });

  group('ExplicitEnumValue.toBytes', () {
    test('emits the UTF-8 variant name', () {
      final ExplicitEnumValue value =
          status.createValue('interrupted') as ExplicitEnumValue;

      expect(
        value.toBytes(),
        equals(<int>[105, 110, 116, 101, 114, 114, 117, 112, 116, 101, 100]),
      );
      expect(value.toBytes(), equals(utf8.encode('interrupted')));
    });

    test('is not the discriminant byte', () {
      final ExplicitEnumValue value =
          status.createValue('interrupted') as ExplicitEnumValue;

      expect(value.discriminant, equals(1));
      expect(value.toBytes(), isNot(equals(<int>[1])));
      expect(value.toBytes().length, equals(11));
    });

    test('agrees byte-for-byte with encodeTopLevel', () {
      for (final String name in <String>['completed', 'interrupted']) {
        final ExplicitEnumValue value =
            status.createValue(name) as ExplicitEnumValue;
        expect(value.toBytes(), equals(codec.encodeTopLevel(value)));
      }
    });

    test('variant 0 does not collapse to an empty buffer', () {
      final ExplicitEnumValue value =
          status.createValue('completed') as ExplicitEnumValue;

      expect(
        value.toBytes(),
        equals(<int>[99, 111, 109, 112, 108, 101, 116, 101, 100]),
      );
    });
  });

  group('ExplicitEnum codec round-trip', () {
    test('decodeTopLevel reads the name back', () {
      final ExplicitEnumValue decoded =
          codec.decodeTopLevel(
                Uint8List.fromList(utf8.encode('completed')),
                status,
              )
              as ExplicitEnumValue;

      expect(decoded.variantName, equals('completed'));
    });

    test('encodeNested prefixes a 4-byte big-endian length', () {
      final ExplicitEnumValue value =
          status.createValue('completed') as ExplicitEnumValue;

      expect(
        codec.encodeNested(value),
        equals(<int>[0, 0, 0, 9, 99, 111, 109, 112, 108, 101, 116, 101, 100]),
      );
    });
  });
}
