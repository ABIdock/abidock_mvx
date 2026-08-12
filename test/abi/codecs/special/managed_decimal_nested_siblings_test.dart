/// Regression test for CR3-1: `ManagedDecimal.decodeNested` for fixed-scale
/// values must consume **exactly** the bytes belonging to the decimal — not
/// greedily eat the rest of the buffer.
///
/// Symptom of the original bug: a fixed-scale `ManagedDecimal<usize|N>` field
/// sitting between two other fields in a struct/array/tuple silently swallowed
/// all sibling fields after it. Tests pinned only the standalone round-trip,
/// so the regression went undetected.
///
/// Nested wire format:
///   * Fixed   `ManagedDecimal<N>` →
///       `[u32 dataLen][magnitude bytes]`
///   * Variable `ManagedDecimal<usize>` →
///       `[u32 dataLen][magnitude bytes][u32 scale]`
///
/// The length prefix on the fixed branch is REQUIRED so siblings decode at the
/// correct offset. Round-2 CR-6 had removed it, which broke every sibling
/// field; round-3 CR3-1 restores it.
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  final BinaryCodec binaryCodec = BinaryCodec.withDefaults();
  final ManagedDecimalBinaryCodec codec = ManagedDecimalBinaryCodec(
    binaryCodec,
  );

  group('ManagedDecimalBinaryCodec.decodeNested (CR3-1 pinning)', () {
    test('fixed-scale nested round-trip preserves SIBLING bytes after it', () {
      final ManagedDecimalType type = ManagedDecimalType.of(8);
      final ManagedDecimalValue middle = ManagedDecimalValue(
        BigInt.from(0x1234),
        scale: 8,
      );
      final Uint8List middleEncoded = codec.encodeNested(middle);

      final Uint8List sibling = Uint8List.fromList(<int>[0xAA, 0xBB, 0xCC]);
      final Uint8List composite = Uint8List.fromList(<int>[
        ...middleEncoded,
        ...sibling,
      ]);

      final (ManagedDecimalValue decoded, int consumed) = codec.decodeNested(
        composite,
        type,
        0,
      );

      expect(decoded.value, equals(BigInt.from(0x1234)));
      expect(decoded.scale, equals(8));
      expect(
        consumed,
        equals(middleEncoded.length),
        reason: 'CR3-1: decodeNested must NOT eat sibling bytes',
      );

      final Uint8List leftover = composite.sublist(consumed);
      expect(
        leftover,
        orderedEquals(sibling),
        reason: 'Sibling bytes must remain intact for the next decoder',
      );
    });

    test(
      'variable-scale nested round-trip preserves SIBLING bytes after it',
      () {
        final ManagedDecimalType type = ManagedDecimalType.variable(4);
        final ManagedDecimalValue middle = ManagedDecimalValue(
          BigInt.from(0xAB),
          scale: 4,
          isVariable: true,
        );
        final Uint8List middleEncoded = codec.encodeNested(middle);

        final Uint8List sibling = Uint8List.fromList(<int>[0x01, 0x02]);
        final Uint8List composite = Uint8List.fromList(<int>[
          ...middleEncoded,
          ...sibling,
        ]);

        final (ManagedDecimalValue decoded, int consumed) = codec.decodeNested(
          composite,
          type,
          0,
        );

        expect(decoded.value, equals(BigInt.from(0xAB)));
        expect(decoded.scale, equals(4));
        expect(consumed, equals(middleEncoded.length));
        expect(composite.sublist(consumed), orderedEquals(sibling));
      },
    );

    test('fixed-scale encodeNested emits the u32 length prefix', () {
      final ManagedDecimalType type = ManagedDecimalType.of(0);
      final ManagedDecimalValue value = ManagedDecimalValue(
        BigInt.from(0xFF),
        scale: 0,
      );
      final Uint8List encoded = codec.encodeNested(value);

      expect(
        encoded.length,
        equals(5),
        reason: 'Expected [u32 length=1][0xff] = 5 bytes',
      );
      expect(encoded.sublist(0, 4), orderedEquals(<int>[0, 0, 0, 1]));
      expect(encoded[4], equals(0xFF));

      final (ManagedDecimalValue decoded, int consumed) = codec.decodeNested(
        encoded,
        type,
        0,
      );
      expect(decoded.value, equals(BigInt.from(0xFF)));
      expect(consumed, equals(5));
    });

    test('decodeNested rejects truncated fixed-scale buffer', () {
      final ManagedDecimalType type = ManagedDecimalType.of(8);
      final Uint8List bad = Uint8List.fromList(<int>[0, 0, 0, 10, 0x01]);
      expect(
        () => codec.decodeNested(bad, type, 0),
        throwsA(isA<AbiBinaryCodecException>()),
      );
    });
  });
}
