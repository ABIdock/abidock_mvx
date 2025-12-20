import 'dart:typed_data';

import 'package:abidock_mvx/src/wallet/crypto/bech32_encoder.dart';
import 'package:test/test.dart';

void main() {
  group('Bech32Encoder', () {
    const encoder = Bech32Encoder(hrp: 'erd');

    group('encode', () {
      test('encodes 32-byte address correctly', () {
        final bytes = Uint8List.fromList(List.filled(32, 0));
        final encoded = encoder.encode(bytes);
        expect(encoded, startsWith('erd1'));
        expect(encoded, hasLength(greaterThan(40)));
      });

      test('encodes different addresses uniquely', () {
        final bytes1 = Uint8List.fromList(List.filled(32, 0));
        final bytes2 = Uint8List.fromList(List.filled(32, 1));
        expect(encoder.encode(bytes1), isNot(equals(encoder.encode(bytes2))));
      });

      test('throws on empty data', () {
        expect(() => encoder.encode([]), throwsArgumentError);
      });

      test('handles single byte', () {
        final encoded = encoder.encode([42]);
        expect(encoded, startsWith('erd1'));
      });

      test('handles max byte values', () {
        final bytes = Uint8List.fromList(List.filled(32, 255));
        final encoded = encoder.encode(bytes);
        expect(encoded, isNotEmpty);
      });
    });

    group('decode', () {
      test('decodes valid bech32 address', () {
        final original = Uint8List.fromList(List.generate(32, (i) => i));
        final encoded = encoder.encode(original);
        final decoded = encoder.decode(encoded);
        expect(decoded, equals(original));
      });

      test('round-trip encoding preserves data', () {
        final testCases = [
          List.filled(32, 0),
          List.filled(32, 255),
          List.generate(32, (i) => i),
          List.generate(32, (i) => i * 7 % 256),
        ];

        for (final bytes in testCases) {
          final original = Uint8List.fromList(bytes);
          final encoded = encoder.encode(original);
          final decoded = encoder.decode(encoded);
          expect(decoded, equals(original));
        }
      });

      test('throws on empty string', () {
        expect(() => encoder.decode(''), throwsArgumentError);
      });

      test('throws on missing separator', () {
        expect(() => encoder.decode('erdnodata'), throwsArgumentError);
      });

      test('throws on wrong hrp', () {
        const wrongEncoder = Bech32Encoder(hrp: 'btc');
        final bytes = Uint8List.fromList(List.filled(32, 0));
        final encoded = wrongEncoder.encode(bytes);
        expect(() => encoder.decode(encoded), throwsArgumentError);
      });

      test('throws on invalid checksum', () {
        final bytes = Uint8List.fromList(List.filled(32, 0));
        final encoded = encoder.encode(bytes);
        final corrupted = '${encoded.substring(0, encoded.length - 1)}x';
        expect(() => encoder.decode(corrupted), throwsArgumentError);
      });

      test('throws on invalid character', () {
        expect(() => encoder.decode('erd1b!@#\$%'), throwsArgumentError);
      });

      test('throws on data part too short', () {
        expect(() => encoder.decode('erd1abc'), throwsArgumentError);
      });
    });

    group('different hrp values', () {
      test('works with different hrp prefixes', () {
        const prefixes = ['erd', 'btc', 'tb', 'cosmos'];
        final bytes = Uint8List.fromList(List.filled(32, 42));

        for (final prefix in prefixes) {
          final enc = Bech32Encoder(hrp: prefix);
          final encoded = enc.encode(bytes);
          expect(encoded, startsWith('${prefix}1'));
          expect(enc.decode(encoded), equals(bytes));
        }
      });
    });
  });
}
