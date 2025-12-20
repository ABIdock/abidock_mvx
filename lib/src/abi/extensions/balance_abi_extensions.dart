/// ABI integration extensions for Balance.
import '../../core/balance.dart';
import '../types/primitives/biguint.dart';

/// ABI integration extensions for Balance.
extension BalanceAbiExtensions on Balance {
  /// Converts Balance to BigUIntValue for ABI encoding.
  ///
  /// #### Returns
  /// `BigUIntValue` - BigUIntValue representation in attoEGLD
  BigUIntValue toBigUIntValue() => BigUIntValue(value);
}

/// Factory methods for creating Balance from ABI types.
extension BalanceFromAbiExtensions on BigUIntValue {
  /// Creates Balance from BigUIntValue after ABI decoding.
  ///
  /// #### Returns
  /// `Balance` - Balance instance with denomination support
  Balance toBalance() => Balance(asBigInt);
}

/// Additional utility extensions for Balance-ABI conversions.
extension BalanceAbiUtilityExtensions on Balance {
  /// Converts Balance to ABI format and encodes as bytes.
  ///
  /// #### Returns
  /// `List<int>` - Byte array with minimal encoding (no leading zeros)
  List<int> toAbiBytes() => toBigUIntValue().toBytes();

  /// Creates Balance from ABI byte encoding.
  ///
  /// #### Parameters
  /// - `bytes` - ABI-encoded byte array (big-endian)
  ///
  /// #### Returns
  /// `Balance` - Balance instance
  static Balance fromAbiBytes(List<int> bytes) {
    BigInt value = BigInt.zero;
    for (final byte in bytes) {
      value = (value << 8) | BigInt.from(byte & 0xFF);
    }
    return Balance(value);
  }
}
