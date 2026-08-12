import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('ValidatorSecretKey', () {
    test('round-trips through PEM (single entry)', () {
      final Uint8List secretBytes = Uint8List.fromList(
        List<int>.generate(32, (int i) => i + 1),
      );
      final Uint8List publicBytes = Uint8List.fromList(
        List<int>.generate(96, (int i) => (i * 7 + 3) & 0xff),
      );
      final ValidatorSecretKey secret = ValidatorSecretKey(secretBytes);
      final ValidatorPublicKey public = ValidatorPublicKey(publicBytes);

      final String pem = secret.toPem(public);

      expect(pem, contains('-----BEGIN PRIVATE KEY for ${public.hex}-----'));
      expect(pem, contains('-----END PRIVATE KEY for ${public.hex}-----'));

      final ValidatorSecretKey reparsed = ValidatorSecretKey.fromPem(pem);
      expect(reparsed.hex, equals(secret.hex));
      expect(reparsed.bytes, equals(secret.bytes));
    });

    test('parses multi-entry validator PEM', () {
      final Uint8List sk1 = Uint8List.fromList(
        List<int>.generate(32, (int i) => i + 1),
      );
      final Uint8List sk2 = Uint8List.fromList(
        List<int>.generate(32, (int i) => 255 - i),
      );
      final Uint8List pk1 = Uint8List.fromList(
        List<int>.generate(96, (int i) => (i * 11) & 0xff),
      );
      final Uint8List pk2 = Uint8List.fromList(
        List<int>.generate(96, (int i) => (i * 13 + 1) & 0xff),
      );

      final String pem = <String>[
        ValidatorSecretKey(sk1).toPem(ValidatorPublicKey(pk1)),
        ValidatorSecretKey(sk2).toPem(ValidatorPublicKey(pk2)),
      ].join('\n');

      final List<ValidatorSecretKey> keys = parseValidatorKeys(pem);
      expect(keys, hasLength(2));
      expect(keys[0].bytes, equals(sk1));
      expect(keys[1].bytes, equals(sk2));
    });

    test('throws on empty or malformed PEM', () {
      expect(() => parseValidatorKeys(''), throwsA(isA<PemException>()));
      expect(
        () => parseValidatorKeys('not a pem'),
        throwsA(isA<PemException>()),
      );
    });

    test('sign() throws UnimplementedError until BLS backend lands', () {
      final ValidatorSecretKey secret = ValidatorSecretKey(
        Uint8List.fromList(List<int>.generate(32, (int i) => i + 1)),
      );
      expect(
        () => secret.sign(Uint8List.fromList(<int>[1, 2, 3])),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('a key parsed from PEM can be signed with a custom backend', () {
      final Uint8List sk = Uint8List.fromList(
        List<int>.generate(32, (int i) => i + 1),
      );
      final Uint8List pk = Uint8List.fromList(
        List<int>.generate(96, (int i) => (i * 7 + 3) & 0xff),
      );
      final String pem = ValidatorSecretKey(sk).toPem(ValidatorPublicKey(pk));

      final ValidatorSecretKey parsed = ValidatorSecretKey.fromPem(pem);
      expect(parsed.hex, equals(ValidatorSecretKey(sk).hex));

      final Uint8List expected = Uint8List.fromList(
        List<int>.generate(96, (int i) => (i * 3 + 1) & 0xff),
      );
      final ValidatorSigner signer = ValidatorSigner.custom(
        (Uint8List _) => expected,
      );
      expect(signer.sign(Uint8List.fromList(<int>[42])), equals(expected));
    });
  });
}
