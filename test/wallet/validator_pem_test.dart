/// Tests for [parseValidatorPem] / [parseValidatorKey] helpers.
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  final Uint8List sk1 = Uint8List.fromList(
    List<int>.generate(32, (int i) => i + 1),
  );
  final Uint8List pk1 = Uint8List.fromList(
    List<int>.generate(96, (int i) => (i * 3 + 7) & 0xff),
  );
  final Uint8List sk2 = Uint8List.fromList(
    List<int>.generate(32, (int i) => 32 - i),
  );
  final Uint8List pk2 = Uint8List.fromList(
    List<int>.generate(96, (int i) => (i * 5 + 1) & 0xff),
  );

  group('parseValidatorPem', () {
    test('parses a single entry', () {
      final String pem = ValidatorSecretKey(sk1).toPem(ValidatorPublicKey(pk1));
      final List<ValidatorSecretKey> keys = parseValidatorPem(pem);
      expect(keys, hasLength(1));
      expect(keys.first.hex, equals(ValidatorSecretKey(sk1).hex));
    });

    test('parses multiple concatenated entries in file order', () {
      final String pem1 = ValidatorSecretKey(sk1)
          .toPem(ValidatorPublicKey(pk1));
      final String pem2 = ValidatorSecretKey(sk2)
          .toPem(ValidatorPublicKey(pk2));
      final List<ValidatorSecretKey> keys = parseValidatorPem('$pem1\n$pem2');
      expect(keys, hasLength(2));
      expect(keys[0].hex, equals(ValidatorSecretKey(sk1).hex));
      expect(keys[1].hex, equals(ValidatorSecretKey(sk2).hex));
    });

    test('empty input throws PemException', () {
      expect(() => parseValidatorPem(''), throwsA(isA<PemException>()));
    });
  });

  group('parseValidatorKey (single-entry helper)', () {
    test('returns the first entry when index is not supplied', () {
      final String pem = ValidatorSecretKey(sk1).toPem(ValidatorPublicKey(pk1));
      final ValidatorSecretKey key = parseValidatorKey(pem);
      expect(key.hex, equals(ValidatorSecretKey(sk1).hex));
    });

    test('returns the requested entry by index for multi-key PEM', () {
      final String pem1 = ValidatorSecretKey(sk1)
          .toPem(ValidatorPublicKey(pk1));
      final String pem2 = ValidatorSecretKey(sk2)
          .toPem(ValidatorPublicKey(pk2));
      final ValidatorSecretKey second = parseValidatorKey(
        '$pem1\n$pem2',
        index: 1,
      );
      expect(second.hex, equals(ValidatorSecretKey(sk2).hex));
    });

    test('out-of-range index throws', () {
      final String pem = ValidatorSecretKey(sk1).toPem(ValidatorPublicKey(pk1));
      expect(() => parseValidatorKey(pem, index: 5), throwsA(anything));
    });
  });
}
