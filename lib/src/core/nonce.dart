/// Nonce for cryptographic operations.
/// Each transaction from an account must have a unique, incrementing nonce.
///
/// #### Example
/// ```dart
/// // Initial nonce
/// final nonce = Nonce(42);
/// print(nonce.value); // 42
///
/// // Increment for next transaction
/// final nextNonce = nonce.increment();
/// print(nextNonce.value); // 43
///
/// // Zero nonce (account not yet used)
/// const zeroNonce = Nonce.zero();
/// print(zeroNonce.value); // 0
/// ```
final class Nonce {
  /// Creates Nonce with specified value.
  ///
  /// #### Parameters
  /// - `value` - Non-negative integer nonce value
  ///
  /// #### Throws
  /// - `AssertionError` - If value is negative
  const Nonce(this.value) : assert(value >= 0, 'nonce cannot be negative');

  /// Creates Nonce with value of zero.
  const Nonce.zero() : value = 0;

  /// Integer value of nonce.
  final int value;

  /// Returns new Nonce incremented by 1.
  ///
  /// #### Returns
  /// New Nonce with value + 1
  ///
  /// #### Example
  /// ```dart
  /// var nonce = Nonce(5);
  /// nonce = nonce.increment(); // 6
  /// nonce = nonce.increment(); // 7
  /// ```
  Nonce increment() => Nonce(value + 1);

  /// Adds an integer to this nonce.
  ///
  /// #### Example
  /// ```dart
  /// final nonce = Nonce(5);
  /// final later = nonce + 3; // Nonce(8)
  /// ```
  Nonce operator +(int amount) {
    if (amount < 0) {
      return this - (-amount);
    }
    return Nonce(value + amount);
  }

  /// Subtracts an integer from this nonce.
  ///
  /// #### Throws
  /// - `AssertionError` - If result would be negative
  ///
  /// #### Example
  /// ```dart
  /// final nonce = Nonce(5);
  /// final earlier = nonce - 2; // Nonce(3)
  /// ```
  Nonce operator -(int amount) {
    final int result = value - amount;
    if (result < 0) {
      throw ArgumentError(
        'Nonce subtraction would produce negative value: $value - $amount',
      );
    }
    return Nonce(result);
  }

  /// Compares this nonce with another.
  int compareTo(Nonce other) => value.compareTo(other.value);

  /// Whether this nonce is greater than other.
  bool operator >(Nonce other) => value > other.value;

  /// Whether this nonce is greater than or equal to other.
  bool operator >=(Nonce other) => value >= other.value;

  /// Whether this nonce is less than other.
  bool operator <(Nonce other) => value < other.value;

  /// Whether this nonce is less than or equal to other.
  bool operator <=(Nonce other) => value <= other.value;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Nonce && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Nonce{ $value }';
}
