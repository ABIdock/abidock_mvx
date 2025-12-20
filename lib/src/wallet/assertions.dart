/// Wallet validation assertions and error types for data integrity checks.
/// Provides validation functions and custom exceptions to detect programming errors early.

import '../utils/sdk_exceptions.dart';

/// Guards that a buffer or string has the expected length.
///
/// #### Parameters
/// - `withLength` - Value to check (List, String, or null)
/// - `expectedLength` - Expected length
///
/// #### Throws
/// - `ArgumentError` - If withLength type is not List, String, or null
/// - `WalletLengthException` - If actual length doesn't match expectedLength
void guardLength(dynamic withLength, int expectedLength) {
  final int actualLength;

  if (withLength is List) {
    actualLength = withLength.length;
  } else if (withLength is String) {
    actualLength = withLength.length;
  } else if (withLength == null) {
    actualLength = 0;
  } else {
    throw ArgumentError('Cannot determine length of ${withLength.runtimeType}');
  }

  if (actualLength != expectedLength) {
    throw WalletLengthException(
      'wrong length, expected: $expectedLength, actual: $actualLength',
    );
  }
}
