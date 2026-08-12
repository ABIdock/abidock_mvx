/// Tests for [BigFloatType] / [BigFloatValue].
///
/// `BigFloat` has no portable wire form: the node serialises it as an opaque
/// arbitrary-precision float blob (version byte, packed mode/accuracy/form/sign
/// byte, precision, exponent, mantissa words) inside a managed buffer, and both
/// top-level and nested encoding just emit that buffer. The decimal-string
/// encoding this SDK used to emit produced bytes the chain cannot read, so the
/// gap is now surfaced instead of silently mis-encoded.
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('BigFloatType', () {
    test('exposes a singleton instance via .type', () {
      expect(BigFloatType.type, same(BigFloatType.type));
      expect(BigFloatType.type.name, equals('BigFloat'));
    });

    test('an ABI naming BigFloat still loads', () {
      final AbiTypeFactory factory = AbiTypeFactory();
      final ListType listOfFloats =
          factory.fromString('List<BigFloat>') as ListType;

      expect(
        identical(factory.fromString('BigFloat'), BigFloatType.type),
        isTrue,
      );
      expect(identical(listOfFloats.elementType, BigFloatType.type), isTrue);
    });
  });

  group('BigFloat has no wire codec', () {
    late BinaryCodec codec;

    setUp(() {
      codec = BinaryCodec.withDefaults();
    });

    test('toBytes throws instead of emitting a decimal string', () {
      expect(() => BigFloatValue(1.5).toBytes(), throwsUnimplementedError);
      expect(() => BigFloatValue(0.0).toBytes(), throwsUnimplementedError);
    });

    test('encodeTopLevel throws', () {
      expect(
        () => codec.encodeTopLevel(BigFloatValue(1.5)),
        throwsA(isA<AbiBinaryCodecException>()),
      );
    });

    test('decodeTopLevel throws', () {
      expect(
        () => codec.decodeTopLevel(
          Uint8List.fromList(<int>[1, 2]),
          BigFloatType.type,
        ),
        throwsA(isA<AbiBinaryCodecException>()),
      );
    });
  });

  group('BigFloatValue', () {
    test('round-trips a positive double', () {
      final BigFloatValue v = BigFloatValue(1.5);
      expect(v.value, equals(1.5));
    });

    test('round-trips zero', () {
      final BigFloatValue v = BigFloatValue(0.0);
      expect(v.value, equals(0.0));
    });

    test('round-trips a negative double', () {
      final BigFloatValue v = BigFloatValue(-3.14);
      expect(v.value, equals(-3.14));
    });

    test('value-equality based on numeric value', () {
      expect(BigFloatValue(2.5), equals(BigFloatValue(2.5)));
      expect(BigFloatValue(2.5).hashCode, equals(BigFloatValue(2.5).hashCode));
    });

    test('inequality across different values', () {
      expect(BigFloatValue(1.0), isNot(equals(BigFloatValue(1.1))));
    });
  });
}
