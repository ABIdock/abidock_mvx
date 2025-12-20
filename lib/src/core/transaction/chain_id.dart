/// Chain ID for a transaction.
/// Prevents transactions from being replayed on different networks. Values: '1' (Mainnet), 'D' (Devnet), 'T' (Testnet).
///
/// #### Example
/// ```dart
/// // Using constants
/// final mainnetChain = ChainId.mainnet();
/// final devnetChain = ChainId.devnet();
/// final testnetChain = ChainId.testnet();
///
/// // Direct construction
/// final chain = ChainId('D');
///
/// // In transaction
/// final tx = Transaction(
///   chainId: ChainId.mainnet(),
///   // ... other fields
/// );
///
/// // Check network
/// if (tx.chainId.isMainnet) {
///   print('Transaction for mainnet');
/// }
/// ```
class ChainId {
  /// Creates chain ID.
  ///
  /// #### Parameters
  /// - `value` - Chain identifier: '1' (Mainnet), 'D' (Devnet), 'T' (Testnet)
  ///
  /// #### Throws
  /// - `AssertionError` - If value is not '1', 'D', or 'T'
  ///
  /// #### Example
  /// ```dart
  /// final mainnet = ChainId('1');
  /// final devnet = ChainId('D');
  /// final testnet = ChainId('T');
  ///
  /// // Invalid - throws AssertionError
  /// // final invalid = ChainId('X');
  /// ```
  const ChainId(this.value)
    : assert(
        value == '1' || value == 'D' || value == 'T',
        'Chain ID must be "1" (Mainnet), "D" (Devnet), or "T" (Testnet)',
      );

  /// Creates Mainnet chain ID.
  const ChainId.mainnet() : value = '1';

  /// Creates Devnet chain ID.
  const ChainId.devnet() : value = 'D';

  /// Creates Testnet chain ID.
  const ChainId.testnet() : value = 'T';

  /// Creates chain ID without validation (for parsing API responses).
  /// Use this when parsing transactions from the blockchain where chain ID might be empty or have non-standard values.
  ///
  /// #### Parameters
  /// - `value` - Chain ID string (can be any value)
  ///
  /// #### Returns
  /// `ChainId` - ChainId instance (defaults to 'D' if empty)
  ///
  /// #### Example
  /// ```dart
  /// // From API response
  /// final chainId = ChainId.fromApiResponse(apiData['chainID']);
  ///
  /// // Handles empty or null values
  /// final unknownChain = ChainId.fromApiResponse(''); // defaults to 'D'
  /// ```
  factory ChainId.fromApiResponse(String? value) {
    if (value == null || value.isEmpty) {
      return const ChainId.devnet(); // Default to devnet for safety
    }

    return ChainId._internal(value);
  }

  /// Internal constructor without validation.
  const ChainId._internal(this.value);

  /// Chain ID value.
  final String value;

  /// Checks if Mainnet.
  ///
  /// #### Returns
  /// `bool` - True if value is '1' (Mainnet)
  bool get isMainnet => value == '1';

  /// Checks if Devnet.
  ///
  /// #### Returns
  /// `bool` - True if value is 'D' (Devnet)
  bool get isDevnet => value == 'D';

  /// Checks if Testnet.
  ///
  /// #### Returns
  /// `bool` - True if value is 'T' (Testnet)
  bool get isTestnet => value == 'T';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChainId &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ChainId($value)';
}
