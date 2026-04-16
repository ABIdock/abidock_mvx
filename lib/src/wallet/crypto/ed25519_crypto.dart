/// Ed25519 cryptographic operations using cryptography package with secure memory handling.
/// Provides signing, verification, and public key generation with automatic key zeroing.
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Ed25519 cryptographic operations with automatic memory zeroing.
/// Wraps cryptography package for secure key material handling.
class Ed25519Crypto {
  /// Ed25519 algorithm instance
  static final _ed25519 = Ed25519();

  /// Generates Ed25519 public key from 32-byte seed.
  ///
  /// #### Parameters
  /// - `seed` - 32-byte Ed25519 seed
  ///
  /// #### Returns
  /// `Uint8List` - 32-byte Ed25519 public key
  ///
  /// #### Throws
  /// - `ArgumentError` - If seed length is not 32 bytes
  static Future<Uint8List> generatePublicKey(Uint8List seed) async {
    if (seed.length != 32) {
      throw ArgumentError('Seed must be 32 bytes, got ${seed.length}');
    }
    final secretKey = SecretKey(seed);
    final Uint8List seedBytes = Uint8List.fromList(
      await secretKey.extractBytes(),
    );
    try {
      final keyPair = await _ed25519.newKeyPairFromSeed(seedBytes);
      final publicKey = await keyPair.extractPublicKey();
      return Uint8List.fromList(publicKey.bytes);
    } finally {
      zeroMemory(seedBytes);
    }
  }

  /// Signs message using Ed25519.
  ///
  /// #### Parameters
  /// - `seed` - 32-byte Ed25519 seed
  /// - `message` - Message bytes to sign
  ///
  /// #### Returns
  /// `Uint8List` - 64-byte Ed25519 signature
  ///
  /// #### Throws
  /// - `ArgumentError` - If seed length is not 32 bytes
  static Future<Uint8List> sign(Uint8List seed, Uint8List message) async {
    if (seed.length != 32) {
      throw ArgumentError('Seed must be 32 bytes, got ${seed.length}');
    }
    final secretKey = SecretKey(seed);
    final extractedBytes = await secretKey.extractBytes();
    final seedBytes = Uint8List.fromList(extractedBytes);
    try {
      final keyPair = await _ed25519.newKeyPairFromSeed(seedBytes);
      final signature = await _ed25519.sign(message, keyPair: keyPair);
      return Uint8List.fromList(signature.bytes);
    } finally {
      for (var i = 0; i < seedBytes.length; i++) {
        seedBytes[i] = 0;
      }
    }
  }

  /// Verifies Ed25519 signature using constant-time comparison.
  ///
  /// #### Parameters
  /// - `publicKey` - 32-byte Ed25519 public key
  /// - `message` - Original message bytes
  /// - `signature` - 64-byte signature to verify
  ///
  /// #### Returns
  /// `bool` - True if signature is valid, false otherwise
  ///
  /// #### Throws
  /// - `ArgumentError` - If publicKey is not 32 bytes or signature is not 64 bytes
  static Future<bool> verify(
    Uint8List publicKey,
    Uint8List message,
    Uint8List signature,
  ) async {
    if (publicKey.length != 32) {
      throw ArgumentError(
        'Public key must be 32 bytes, got ${publicKey.length}',
      );
    }
    if (signature.length != 64) {
      throw ArgumentError(
        'Signature must be 64 bytes, got ${signature.length}',
      );
    }

    try {
      final pubKey = SimplePublicKey(publicKey, type: KeyPairType.ed25519);
      final sig = Signature(signature, publicKey: pubKey);

      return await _ed25519.verify(message, signature: sig);
    } catch (e) {
      return false;
    }
  }

  /// Zeros buffer in memory for security.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer to zero
  static void zeroMemory(Uint8List buffer) {
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }
}
