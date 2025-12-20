/// ABI integration extensions for Address.
import '../../core/address.dart';
import '../types/primitives/address.dart';

/// ABI integration extensions for Address.
extension AddressAbiExtensions on Address {
  /// Converts Address to AddressValue for ABI encoding.
  ///
  /// #### Returns
  /// `AddressValue` - AddressValue representation with the same 32-byte value
  AddressValue toAddressValue() => AddressValue(bytes);

  /// Creates Address from AddressValue after ABI decoding.
  ///
  /// #### Parameters
  /// - `value` - AddressValue from ABI response or encoding
  ///
  /// #### Returns
  /// `Address` - Address instance with the same 32-byte value
  static Address fromAddressValue(AddressValue value) {
    return Address(value.value.toList());
  }
}

/// ABI integration extensions for AddressValue.
extension AddressValueExtensions on AddressValue {
  /// Converts AddressValue to Address.
  ///
  /// #### Returns
  /// `Address` - Address instance with the same 32-byte value
  Address toAddress() => Address(value.toList());
}
