/// Smart contract execution return codes for query and transaction results.
/// Provides predefined codes and categorization for error handling.

import 'package:meta/meta.dart';

/// Smart contract execution return codes with categorization.
///
/// #### Example
/// ```dart
/// final returnCode = response.returnCode.toReturnCode();
///
/// if (returnCode.isSuccess) {
///   print('Query succeeded');
/// } else {
///   print('Query failed: ${returnCode.message}');
/// }
/// ```
@immutable
final class ReturnCode {
  /// Creates a return code with code string and message.
  ///
  /// #### Parameters
  /// - `code` - Return code string
  /// - `message` - Human-readable message
  const ReturnCode._(this.code, this.message);

  /// Creates custom return code for unknown codes.
  /// Handle non-predefined return codes.
  ///
  /// #### Parameters
  /// - `code` - Custom return code string
  const ReturnCode.custom(this.code) : message = code;

  /// Parses return code string to ReturnCode instance.
  ///
  /// Convert string to typed ReturnCode.
  ///
  /// #### Parameters
  /// - `codeString` - Return code string from API
  ///
  /// #### Returns
  /// `ReturnCode` instance (predefined or custom)

  factory ReturnCode.parse(String? codeString) {
    if (codeString == null || codeString.isEmpty) {
      return none;
    }

    final String normalized = codeString.trim().toLowerCase();

    for (final ReturnCode code in values) {
      if (code.code.toLowerCase() == normalized) {
        return code;
      }
    }
    return ReturnCode.custom(codeString);
  }

  /// Parses return code from bytes.
  factory ReturnCode.fromBytes(List<int> bytes) {
    final String codeString = String.fromCharCodes(bytes);
    return ReturnCode.parse(codeString);
  }

  /// Empty/no return code (treated as success).
  static const ReturnCode none = ReturnCode._('', 'No return code');

  /// Execution succeeded.
  static const ReturnCode ok = ReturnCode._('ok', 'Execution succeeded');

  /// The requested function was not found in the contract.
  static const ReturnCode functionNotFound = ReturnCode._(
    'function not found',
    'Function not found in contract',
  );

  /// The function signature doesn't match the expected parameters.
  static const ReturnCode functionWrongSignature = ReturnCode._(
    'wrong signature for function',
    'Function signature mismatch',
  );

  /// The target contract was not found at the specified address.
  static const ReturnCode contractNotFound = ReturnCode._(
    'contract not found',
    'Contract not found at address',
  );

  /// User-level error (thrown by contract code).
  static const ReturnCode userError = ReturnCode._(
    'user error',
    'User error in contract execution',
  );

  /// Transaction ran out of gas during execution.
  static const ReturnCode outOfGas = ReturnCode._(
    'out of gas',
    'Insufficient gas for execution',
  );

  /// Account collision detected.
  static const ReturnCode accountCollision = ReturnCode._(
    'account collision',
    'Account collision detected',
  );

  /// Insufficient funds for the operation.
  static const ReturnCode outOfFunds = ReturnCode._(
    'out of funds',
    'Insufficient funds',
  );

  /// Call stack overflow (too many nested calls).
  static const ReturnCode callStackOverflow = ReturnCode._(
    'call stack overflow',
    'Call stack overflow',
  );

  /// The contract code is invalid or corrupted.
  static const ReturnCode contractInvalid = ReturnCode._(
    'contract invalid',
    'Invalid or corrupted contract code',
  );

  /// Execution failed for an unspecified reason.
  static const ReturnCode executionFailed = ReturnCode._(
    'execution failed',
    'Execution failed',
  );

  /// Unknown or unrecognized return code.
  static const ReturnCode unknown = ReturnCode._(
    'unknown',
    'Unknown return code',
  );

  /// All predefined return codes.
  static const List<ReturnCode> values = <ReturnCode>[
    none,
    ok,
    functionNotFound,
    functionWrongSignature,
    contractNotFound,
    userError,
    outOfGas,
    accountCollision,
    outOfFunds,
    callStackOverflow,
    contractInvalid,
    executionFailed,
    unknown,
  ];

  /// The raw return code string from the blockchain.
  final String code;

  /// Human-readable message describing this return code.
  final String message;

  /// Whether execution succeeded.
  bool get isSuccess => this == ok || this == none;

  /// Whether execution failed.
  bool get isError => !isSuccess;

  /// Whether this is a function-related error.
  bool get isFunctionError =>
      this == functionNotFound || this == functionWrongSignature;

  /// Whether this is a contract-related error.
  bool get isContractError =>
      this == contractNotFound || this == contractInvalid;

  /// Whether this is a resource-related error (gas, funds).
  bool get isResourceError => this == outOfGas || this == outOfFunds;

  /// Whether this is a user-triggered error from contract code.
  bool get isUserError => this == userError;

  /// Whether this is a system/VM error.
  bool get isSystemError =>
      this == accountCollision ||
      this == callStackOverflow ||
      this == executionFailed;

  /// Returns error category for classification.
  ///
  /// Categorize errors for handling.
  ///
  /// #### Returns
  /// `String` category ('success', 'function', 'contract', 'resource', 'user', 'system', 'unknown')
  String get category {
    if (isSuccess) return 'success';
    if (isFunctionError) return 'function';
    if (isContractError) return 'contract';
    if (isResourceError) return 'resource';
    if (isUserError) return 'user';
    if (isSystemError) return 'system';
    return 'unknown';
  }

  /// Whether this is one of the predefined return codes.
  bool get isPredefined => values.contains(this);

  /// Whether this is a custom (non-predefined) return code.
  bool get isCustom => !isPredefined;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReturnCode &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code.isEmpty ? 'none' : code;

  /// Returns detailed representation.
  String toDetailedString() => '$code: $message';
}

/// Extension methods for converting strings to ReturnCode.
///
/// Convenient parsing from response strings.
extension ReturnCodeStringExtension on String {
  /// Parses string as return code.
  ///
  /// #### Returns
  /// `ReturnCode` instance
  ReturnCode toReturnCode() => ReturnCode.parse(this);
}

/// Extension methods for working with optional return code strings.
extension ReturnCodeNullableStringExtension on String? {
  /// Parses optional string as return code.
  ReturnCode toReturnCode() => ReturnCode.parse(this);
}
