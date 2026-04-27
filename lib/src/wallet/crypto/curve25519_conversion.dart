/// Ed25519 -> X25519 key conversion primitives.
///
/// MultiversX identities live on the Ed25519 curve (signing), but the
/// library's public-key encryption (`PubkeyEncryptor`) performs ECDH on the
/// Montgomery curve X25519. The two curves are birationally equivalent; the
/// mapping between them is standard and deterministic, but it must be done
/// explicitly — the raw byte representations are NOT interchangeable.
///
/// References:
///   - RFC 7748 (X25519 / Curve25519) §4.1 and §5
///   - RFC 8032 (Ed25519) §5.1
///   - D. J. Bernstein, "Curve25519: new Diffie-Hellman speed records"
///     §3, eq. (4): u = (1 + y) / (1 - y) mod p.
///   - libsodium: `crypto_sign_ed25519_pk_to_curve25519`,
///     `crypto_sign_ed25519_sk_to_curve25519`.
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// The prime defining the Curve25519 / Ed25519 base field: 2^255 - 19.
final BigInt _p = (BigInt.one << 255) - BigInt.from(19);

/// Decodes the y-coordinate from a 32-byte compressed Ed25519 public key.
///
/// Per RFC 8032 §5.1.2, an Ed25519 public key is a 255-bit little-endian
/// y-coordinate with the sign of x stored in the MSB of byte 31. This
/// function discards the sign bit and reduces the result modulo p.
BigInt _decodeEdY(Uint8List edPub) {
  if (edPub.length != 32) {
    throw ArgumentError.value(
      edPub.length,
      'edPub.length',
      'Ed25519 public key must be 32 bytes',
    );
  }
  final Uint8List yBytes = Uint8List.fromList(edPub);
  yBytes[31] &= 0x7F;
  BigInt y = BigInt.zero;
  for (int i = 31; i >= 0; i--) {
    y = (y << 8) | BigInt.from(yBytes[i]);
  }
  return y % _p;
}

/// Encodes a field element as a 32-byte little-endian buffer.
Uint8List _encodeLe32(BigInt value) {
  BigInt v = value % _p;
  if (v.isNegative) v += _p;
  final Uint8List out = Uint8List(32);
  for (int i = 0; i < 32; i++) {
    out[i] = (v & BigInt.from(0xFF)).toInt();
    v >>= 8;
  }
  return out;
}

/// Multiplicative inverse in GF(p) via Fermat's little theorem.
BigInt _fieldInverse(BigInt a) => a.modPow(_p - BigInt.two, _p);

/// Converts an Ed25519 public key into its X25519 (Montgomery u-coordinate)
/// equivalent.
///
/// Applies the Bernstein/RFC-7748 birational map
/// `u = (1 + y) / (1 - y) mod (2^255 - 19)`.
///
/// Throws [ArgumentError] if [edPub] is not 32 bytes and [StateError] if the
/// decoded y equals 1 (the identity / point-at-infinity, which has no
/// Montgomery image).
Uint8List ed25519PublicKeyToX25519(Uint8List edPub) {
  final BigInt y = _decodeEdY(edPub);

  final BigInt oneMinusY = (_p + BigInt.one - y) % _p;
  if (oneMinusY == BigInt.zero) {
    throw StateError(
      'Ed25519 public key decodes to y == 1; no Montgomery image exists',
    );
  }

  final BigInt onePlusY = (BigInt.one + y) % _p;
  final BigInt u = (onePlusY * _fieldInverse(oneMinusY)) % _p;
  return _encodeLe32(u);
}

/// Converts an Ed25519 seed (the 32-byte secret scalar from which the Ed25519
/// keypair is derived) into the X25519 scalar that performs ECDH on the
/// Montgomery representation of the same curve.
///
/// Matches libsodium's `crypto_sign_ed25519_sk_to_curve25519`:
///   1. SHA-512 the seed.
///   2. Take the first 32 bytes.
///   3. Apply the RFC 7748 clamping:
///        `s[0]  &= 0xF8`
///        `s[31] &= 0x7F`
///        `s[31] |= 0x40`
///
/// Throws [ArgumentError] if [seed] is not 32 bytes.
Future<Uint8List> ed25519SeedToX25519SecretKey(Uint8List seed) async {
  if (seed.length != 32) {
    throw ArgumentError.value(
      seed.length,
      'seed.length',
      'Ed25519 seed must be 32 bytes',
    );
  }
  final Hash digest = await Sha512().hash(seed);
  final Uint8List scalar = Uint8List.fromList(digest.bytes.sublist(0, 32));
  scalar[0] &= 0xF8;
  scalar[31] &= 0x7F;
  scalar[31] |= 0x40;
  return scalar;
}
