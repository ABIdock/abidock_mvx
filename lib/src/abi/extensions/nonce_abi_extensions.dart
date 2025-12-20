/// ABI integration extensions for Nonce.
import '../../core/nonce.dart';
import '../types/primitives/u64.dart';

/// ABI integration extensions for Nonce.
extension NonceAbiExtensions on Nonce {
  /// Converts Nonce to U64Value for ABI encoding.
  ///
  /// #### Returns
  /// `U64Value` - U64Value representation of the nonce
  U64Value toU64Value() => U64Value(BigInt.from(value));
}

/// Factory methods for creating Nonce from ABI types.
extension NonceFromAbiExtensions on U64Value {
  /// Creates Nonce from U64Value after ABI decoding.
  ///
  /// #### Returns
  /// `Nonce` - Nonce instance
  ///
  /// #### Throws
  /// - `ArgumentError` - If value exceeds maximum int value (2^63-1)
  Nonce toNonce() {
    final BigInt bigInt = asBigInt;
    if (bigInt > BigInt.parse('9223372036854775807')) {
      throw ArgumentError(
        'Nonce value too large for int type: $bigInt. '
        'Maximum supported value is 9223372036854775807 (2^63-1)',
      );
    }

    return Nonce(bigInt.toInt());
  }
}
