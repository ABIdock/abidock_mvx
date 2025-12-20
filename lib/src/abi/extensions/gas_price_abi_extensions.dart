/// ABI integration extensions for GasPrice.
import '../../core/transaction/gas_models/gas_price.dart';
import '../types/primitives/u64.dart';

/// ABI integration extensions for GasPrice.
extension GasPriceAbiExtensions on GasPrice {
  /// Converts GasPrice to U64Value for ABI encoding.
  ///
  /// #### Returns
  /// `U64Value` - U64Value representation of the gas price
  U64Value toU64Value() => U64Value(BigInt.from(value));
}

/// Factory methods for creating GasPrice from ABI types.
extension GasPriceFromAbiExtensions on U64Value {
  /// Creates GasPrice from U64Value after ABI decoding.
  ///
  /// #### Returns
  /// `GasPrice` - GasPrice instance
  ///
  /// #### Throws
  /// - `ArgumentError` - If value exceeds maximum int value (2^63-1)
  GasPrice toGasPrice() {
    final BigInt bigInt = asBigInt;
    if (bigInt > BigInt.parse('9223372036854775807')) {
      throw ArgumentError(
        'GasPrice value too large for int type: $bigInt. '
        'Maximum supported value is 9223372036854775807 (2^63-1)',
      );
    }

    return GasPrice(bigInt.toInt());
  }
}
