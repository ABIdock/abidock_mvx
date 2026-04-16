/// Gas price modifier for transaction fee calculations.
/// Used to compute the effective gas price for processing gas.
///
/// #### Example
/// ```dart
/// final modifier = GasPriceModifier(0.01); // 1% modifier
/// final computer = TransactionComputer();
/// final fee = computer.computeTransactionFee(tx, networkConfig);
/// ```
class GasPriceModifier {
  /// Creates gas price modifier with validation.
  ///
  /// #### Parameters
  /// - `value` - Modifier value (must be: 0 < value < 1)
  ///
  /// #### Throws
  /// - `AssertionError` - If value is not between 0 and 1
  const GasPriceModifier(this.value)
    : assert(
        value > 0 && value <= 1,
        'value must be in (0, 1]; use 1.0 to disable the processing discount',
      );

  /// Modifier value (0.0 to 1.0, exclusive).
  final double value;
}
