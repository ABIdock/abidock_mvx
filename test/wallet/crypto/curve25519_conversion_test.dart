import 'dart:typed_data';

import 'package:abidock_mvx/src/wallet/crypto/curve25519_conversion.dart';
import 'package:abidock_mvx/src/wallet/crypto/ed25519_crypto.dart';
import 'package:convert/convert.dart' as convert;
import 'package:cryptography/cryptography.dart';
import 'package:pinenacl/tweetnacl.dart' show TweetNaCl;
import 'package:test/test.dart';

Uint8List _hex(String s) => Uint8List.fromList(convert.hex.decode(s));

Uint8List _x25519BaseMult(Uint8List scalar) {
  final Uint8List out = Uint8List(32);
  TweetNaCl.crypto_scalarmult_base(out, Uint8List.fromList(scalar));
  return out;
}

Uint8List _x25519Scalarmult(Uint8List scalar, Uint8List point) {
  final Uint8List out = Uint8List(32);
  TweetNaCl.crypto_scalarmult(
    out,
    Uint8List.fromList(scalar),
    Uint8List.fromList(point),
  );
  return out;
}

void main() {
  group('ed25519SeedToX25519SecretKey', () {
    test('rejects seeds that are not 32 bytes', () async {
      await expectLater(
        ed25519SeedToX25519SecretKey(Uint8List(16)),
        throwsArgumentError,
      );
      await expectLater(
        ed25519SeedToX25519SecretKey(Uint8List(64)),
        throwsArgumentError,
      );
    });

    test('matches SHA-512 + clamp for the all-zero seed', () async {
      final Uint8List seed = Uint8List(32);
      final Uint8List scalar = await ed25519SeedToX25519SecretKey(seed);

      final Hash digest = await Sha512().hash(seed);
      final Uint8List expected = Uint8List.fromList(
        digest.bytes.sublist(0, 32),
      );
      expected[0] &= 0xF8;
      expected[31] &= 0x7F;
      expected[31] |= 0x40;

      expect(scalar, orderedEquals(expected));
    });

    test('always produces a clamped scalar (RFC 7748 §5)', () async {
      final List<Uint8List> seeds = <Uint8List>[
        Uint8List(32),
        _hex(
          '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
        ),
        _hex(
          '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb',
        ),
        _hex(
          'c5aa8df43f9f837bedb7442f31dcb7b166d38535076f094b85ce3a2e0b4458f7',
        ),
        Uint8List.fromList(List<int>.filled(32, 0xFF)),
      ];
      for (final Uint8List seed in seeds) {
        final Uint8List scalar = await ed25519SeedToX25519SecretKey(seed);
        expect(scalar.length, 32);
        expect(scalar[0] & 0x07, 0);
        expect(scalar[31] & 0x80, 0);
        expect(scalar[31] & 0x40, 0x40);
      }
    });
  });

  group('ed25519PublicKeyToX25519', () {
    test('rejects public keys that are not 32 bytes', () {
      expect(
        () => ed25519PublicKeyToX25519(Uint8List(31)),
        throwsArgumentError,
      );
      expect(
        () => ed25519PublicKeyToX25519(Uint8List(33)),
        throwsArgumentError,
      );
    });

    test('ignores the sign bit on byte 31', () {
      final Uint8List edPub = _hex(
        'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
      );
      final Uint8List withSign = Uint8List.fromList(edPub)
        ..[31] = edPub[31] | 0x80;

      expect(
        ed25519PublicKeyToX25519(edPub),
        orderedEquals(ed25519PublicKeyToX25519(withSign)),
      );
    });

    test('throws when the decoded y == 1 (identity point)', () {
      final Uint8List identity = Uint8List(32);
      identity[0] = 1;
      expect(() => ed25519PublicKeyToX25519(identity), throwsStateError);
    });
  });

  group('Ed25519 <-> X25519 self-consistency', () {
    Future<void> check(String description, Uint8List seed) async {
      final Uint8List edPub = await Ed25519Crypto.generatePublicKey(seed);
      final Uint8List xSk = await ed25519SeedToX25519SecretKey(seed);
      final Uint8List xPkFromConversion = ed25519PublicKeyToX25519(edPub);
      final Uint8List xPkFromScalarMult = _x25519BaseMult(xSk);

      expect(
        xPkFromConversion,
        orderedEquals(xPkFromScalarMult),
        reason:
            '$description: Edwards->Montgomery pub must equal '
            'X25519(clamp(SHA512(seed)[0:32]), basepoint)',
      );
    }

    test('RFC 8032 test 1 seed', () async {
      await check(
        'RFC 8032 test 1',
        _hex(
          '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
        ),
      );
    });

    test('RFC 8032 test 2 seed', () async {
      await check(
        'RFC 8032 test 2',
        _hex(
          '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb',
        ),
      );
    });

    test('RFC 8032 test 3 seed', () async {
      await check(
        'RFC 8032 test 3',
        _hex(
          'c5aa8df43f9f837bedb7442f31dcb7b166d38535076f094b85ce3a2e0b4458f7',
        ),
      );
    });

    test('all-zero seed', () async {
      await check('all-zero seed', Uint8List(32));
    });

    test('32 pseudo-random seeds', () async {
      for (int i = 0; i < 32; i++) {
        final Uint8List seed = Uint8List(32);
        for (int j = 0; j < 32; j++) {
          seed[j] = (i * 31 + j * 7 + 1) & 0xFF;
        }
        await check('seed #$i', seed);
      }
    });
  });

  group('Ed25519 -> X25519 ECDH symmetry', () {
    test('Alice and Bob derive the same shared secret', () async {
      final Uint8List aliceSeed = _hex(
        '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
      );
      final Uint8List bobSeed = _hex(
        '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb',
      );

      final Uint8List aliceEdPub = await Ed25519Crypto.generatePublicKey(
        aliceSeed,
      );
      final Uint8List bobEdPub = await Ed25519Crypto.generatePublicKey(bobSeed);

      final Uint8List aliceX25519Sk = await ed25519SeedToX25519SecretKey(
        aliceSeed,
      );
      final Uint8List bobX25519Sk = await ed25519SeedToX25519SecretKey(bobSeed);
      final Uint8List aliceX25519Pk = ed25519PublicKeyToX25519(aliceEdPub);
      final Uint8List bobX25519Pk = ed25519PublicKeyToX25519(bobEdPub);

      final Uint8List aliceShared = _x25519Scalarmult(
        aliceX25519Sk,
        bobX25519Pk,
      );
      final Uint8List bobShared = _x25519Scalarmult(bobX25519Sk, aliceX25519Pk);

      expect(aliceShared, orderedEquals(bobShared));
      expect(aliceShared.every((int b) => b == 0), isFalse);
    });
  });
}
