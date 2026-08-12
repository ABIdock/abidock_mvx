/// Regression tests pinning the single surviving counted-variadic convention.
///
/// `counted-variadic<T>` exists only as a multi-argument shape: the count is
/// top-encoded as its own argument and each item follows as a further
/// argument. The former single-buffer form (`[u32 count][items…]`) got both
/// the count width and the framing wrong, and must now throw rather than emit
/// unparseable bytes.
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  late BinaryCodec codec;

  setUp(() {
    codec = BinaryCodec.withDefaults();
  });

  group('counted-variadic argument-list convention', () {
    test('count and items become separate top-level arguments', () {
      final VariadicValue value = VariadicValue.counted(<TypedValue>[
        U32Value(7),
        U32Value(8),
      ], itemType: U32Type.type);

      expect(
        ArgSerializer().valuesToStrings(<TypedValue>[value]),
        equals(<String>['02', '07', '08']),
      );
    });

    test('the count is minimal big-endian, not a fixed-width u32', () {
      final VariadicValue value = VariadicValue.counted(<TypedValue>[
        U32Value(1),
      ], itemType: U32Type.type);

      expect(
        ArgSerializer().valuesToStrings(<TypedValue>[value]),
        equals(<String>['01', '01']),
      );
    });
  });

  group('counted-variadic has no single-buffer form', () {
    test('encodeTopLevel throws', () {
      final VariadicValue value = VariadicValue.counted(<TypedValue>[
        U32Value(7),
        U32Value(8),
      ], itemType: U32Type.type);

      expect(
        () => codec.encodeTopLevel(value),
        throwsA(isA<AbiBinaryCodecException>()),
      );
    });

    test('encodeNested throws', () {
      final VariadicValue value = VariadicValue.counted(<TypedValue>[
        U32Value(7),
      ], itemType: U32Type.type);

      expect(
        () => codec.encodeNested(value),
        throwsA(isA<AbiBinaryCodecException>()),
      );
    });

    test('decodeTopLevel throws instead of eating a count prefix', () {
      expect(
        () => codec.decodeTopLevel(
          Uint8List.fromList(<int>[0, 0, 0, 2, 0, 0, 0, 7, 0, 0, 0, 8]),
          VariadicType.counted(U32Type.type),
        ),
        throwsA(isA<AbiBinaryCodecException>()),
      );
    });

    test('decodeNested throws instead of eating a count prefix', () {
      expect(
        () => codec.decodeNested(
          Uint8List.fromList(<int>[0, 0, 0, 1, 0, 0, 0, 7]),
          VariadicType.counted(U32Type.type),
          0,
        ),
        throwsA(isA<AbiBinaryCodecException>()),
      );
    });
  });

  group('uncounted variadic keeps its single-buffer form', () {
    test('encodeNested concatenates nested item encodings', () {
      final VariadicValue value = VariadicValue(<TypedValue>[
        U32Value(7),
        U32Value(8),
      ], itemType: U32Type.type);

      expect(codec.encodeNested(value), equals(<int>[0, 0, 0, 7, 0, 0, 0, 8]));
    });

    test('decodeTopLevel reads every item', () {
      final VariadicValue decoded =
          codec.decodeTopLevel(
                Uint8List.fromList(<int>[0, 0, 0, 7, 0, 0, 0, 8]),
                VariadicType.of(U32Type.type),
              )
              as VariadicValue;

      expect(decoded.items.length, equals(2));
      expect(decoded.items[0].nativeValue, equals(7));
      expect(decoded.items[1].nativeValue, equals(8));
      expect(decoded.isCounted, isFalse);
    });
  });
}
