/// Crypto utility functions for MAC computation and secure comparison.
///
/// Provides reusable cryptographic operations used throughout the wallet module.
import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/pointycastle.dart';

/// Static utility class for cryptographic operations.
///
/// Provides methods for MAC computation and secure byte comparison.
class CryptoUtils {
  /// Private constructor to prevent instantiation.
  CryptoUtils._();

  /// Computes HMAC-SHA256 MAC for data using provided key.
  ///
  /// Used for message authentication in wallet encryption/decryption.
  ///
  /// #### Parameters
  /// - `key` - HMAC key (typically derived key second half)
  /// - `data` - Data to compute MAC over (typically ciphertext)
  ///
  /// #### Returns
  /// `Uint8List` - 32-byte HMAC-SHA256 MAC
  ///
  /// #### Example
  /// ```dart
  /// final mac = CryptoUtils.computeHmacSha256(key, ciphertext);
  /// ```
  static Uint8List computeHmacSha256(Uint8List key, Uint8List data) {
    final HMac hmac = HMac(SHA256Digest(), 64);
    hmac.init(KeyParameter(key));
    return hmac.process(data);
  }

  /// Performs constant-time comparison of two byte arrays.
  ///
  /// Prevents timing attacks by ensuring comparison takes the same time
  /// regardless of where the first difference occurs.
  ///
  /// #### Parameters
  /// - `a` - First byte array
  /// - `b` - Second byte array
  ///
  /// #### Returns
  /// `bool` - True if arrays are equal in length and content
  ///
  /// #### Example
  /// ```dart
  /// final isValid = CryptoUtils.constantTimeCompare(computedMac, expectedMac);
  /// ```
  static bool constantTimeCompare(Uint8List a, Uint8List b) {
    final int maxLen = a.length > b.length ? a.length : b.length;
    final int lengthDiff = a.length ^ b.length;
    int diff = 0;
    for (int i = 0; i < maxLen; i++) {
      final int aByte = i < a.length ? a[i] : 0;
      final int bByte = i < b.length ? b[i] : 0;
      diff |= aByte ^ bByte;
    }
    return (diff | lengthDiff) == 0;
  }
}
