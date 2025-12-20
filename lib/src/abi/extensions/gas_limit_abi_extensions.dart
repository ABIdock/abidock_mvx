/// ABI integration extensions for GasLimit.
import '../../core/transaction/gas_models/gas_limit.dart';
import '../types/primitives/u64.dart';

/// ABI integration extensions for GasLimit.
extension GasLimitAbiExtensions on GasLimit {
  /// Converts GasLimit to U64Value for ABI encoding.
  ///
  /// #### Returns
  /// `U64Value` - U64Value representation of the gas limit
  U64Value toU64Value() => U64Value(BigInt.from(value));
}

/// Factory methods for creating GasLimit from ABI types.
extension GasLimitFromAbiExtensions on U64Value {
  /// Creates GasLimit from U64Value after ABI decoding.
  ///
  /// #### Returns
  /// `GasLimit` - GasLimit instance
  ///
  /// #### Throws
  /// - `ArgumentError` - If value exceeds maximum int value (2^63-1)
  GasLimit toGasLimit() {
    final BigInt bigInt = asBigInt;
    if (bigInt > BigInt.parse('9223372036854775807')) {
      throw ArgumentError(
        'GasLimit value too large for int type: $bigInt. '
        'Maximum supported value is 9223372036854775807 (2^63-1)',
      );
    }

    return GasLimit(bigInt.toInt());
  }
}
