/// Tests for [CodeMetadata] bitmap encode/decode + base64 helpers.
///
/// Bitmap layout:
///   byte 0 high: `Upgradeable=0x01_00`, `Readable=0x04_00`
///   byte 1     : `Payable=0x00_02`, `PayableBySc=0x00_04`
import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/src/core/account/code_metadata.dart';
import 'package:test/test.dart';

void main() {
  group('CodeMetadata bitmap constants', () {
    test('mask values match Rust spec', () {
      expect(CodeMetadata.upgradeableMask, equals(0x0100));
      expect(CodeMetadata.readableMask, equals(0x0400));
      expect(CodeMetadata.payableMask, equals(0x0002));
      expect(CodeMetadata.payableBySmartContractMask, equals(0x0004));
    });
  });

  group('CodeMetadata.fromBytes', () {
    test('decodes Upgradeable + Readable from [0x05, 0x00]', () {
      final CodeMetadata md = CodeMetadata.fromBytes(
        Uint8List.fromList(<int>[0x05, 0x00]),
      );
      expect(md.isUpgradeable, isTrue);
      expect(md.isReadable, isTrue);
      expect(md.isPayable, isFalse);
      expect(md.isPayableBySmartContract, isFalse);
    });

    test('decodes Payable + PayableBySc from [0x00, 0x06]', () {
      final CodeMetadata md = CodeMetadata.fromBytes(
        Uint8List.fromList(<int>[0x00, 0x06]),
      );
      expect(md.isUpgradeable, isFalse);
      expect(md.isReadable, isFalse);
      expect(md.isPayable, isTrue);
      expect(md.isPayableBySmartContract, isTrue);
    });

    test('decodes all four flags from [0x05, 0x06]', () {
      final CodeMetadata md = CodeMetadata.fromBytes(
        Uint8List.fromList(<int>[0x05, 0x06]),
      );
      expect(md.isUpgradeable, isTrue);
      expect(md.isReadable, isTrue);
      expect(md.isPayable, isTrue);
      expect(md.isPayableBySmartContract, isTrue);
    });

    test('decodes empty bitmap from [0x00, 0x00]', () {
      final CodeMetadata md = CodeMetadata.fromBytes(
        Uint8List.fromList(<int>[0x00, 0x00]),
      );
      expect(md.isUpgradeable, isFalse);
      expect(md.isReadable, isFalse);
      expect(md.isPayable, isFalse);
      expect(md.isPayableBySmartContract, isFalse);
    });
  });

  group('CodeMetadata.tryParseBase64', () {
    test('decodes base64 `BQA=` to Upgradeable + Readable', () {
      final CodeMetadata? md = CodeMetadata.tryParseBase64('BQA=');
      expect(md, isNotNull);
      expect(md!.isUpgradeable, isTrue);
      expect(md.isReadable, isTrue);
      expect(md.isPayable, isFalse);
    });

    test('returns null for null input', () {
      expect(CodeMetadata.tryParseBase64(null), isNull);
    });

    test('returns null for empty input', () {
      expect(CodeMetadata.tryParseBase64(''), isNull);
    });
  });

  group('CodeMetadata round-trip', () {
    test('fromBytes -> toBytes is identity for every VALID flag combo', () {
      const List<int> byte0Bits = <int>[0x00, 0x01, 0x04, 0x05];
      const List<int> byte1Bits = <int>[0x00, 0x02, 0x04, 0x06];
      for (final int byte0 in byte0Bits) {
        for (final int byte1 in byte1Bits) {
          final Uint8List input = Uint8List.fromList(<int>[byte0, byte1]);
          final Uint8List back = CodeMetadata.fromBytes(input).toBytes();
          expect(
            back,
            orderedEquals(input),
            reason: 'Round-trip failed for [$byte0, $byte1]',
          );
        }
      }
    });

    test('fromBytes ignores bits outside the canonical mask set', () {
      final Uint8List unknownBits = Uint8List.fromList(<int>[0xF8, 0xF8]);
      final Uint8List back = CodeMetadata.fromBytes(unknownBits).toBytes();
      expect(back, orderedEquals(<int>[0x00, 0x00]));
    });
  });

  group('CodeMetadata + Base64 helper', () {
    test('base64 decoding matches manual base64 decode', () {
      final String b64 = base64Encode(<int>[0x05, 0x06]);
      final CodeMetadata md = CodeMetadata.tryParseBase64(b64)!;
      expect(md.isUpgradeable, isTrue);
      expect(md.isReadable, isTrue);
      expect(md.isPayable, isTrue);
      expect(md.isPayableBySmartContract, isTrue);
    });
  });
}
