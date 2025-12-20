/// Core types and interfaces for smart contract interactions.
import 'package:meta/meta.dart';

import '../../core/core.dart';
import '../abi.dart';

/// Smart contract address type.

typedef SmartContractAddress = Address;

/// Smart contract function with name and arguments.
///
/// Represents a function call to a smart contract endpoint.
@immutable
class SmartContractFunction {
  /// Creates function without validation.
  ///
  /// #### Parameters
  /// - `name` - Function/endpoint name (not validated)
  /// - `arguments` - Optional list of arguments
  const SmartContractFunction(this.name, [this.arguments = const <dynamic>[]]);

  /// Creates function with validation.
  ///
  /// #### Parameters
  /// - `name` - Function name to validate (must start with letter, alphanumeric + underscore only)
  ///
  /// #### Throws
  /// - [ArgumentError] if name is empty, contains whitespace, or invalid format
  factory SmartContractFunction.validated(String name) {
    return SmartContractFunction(_validateFunctionName(name));
  }

  /// Function/endpoint name.
  final String name;

  /// Function arguments (typically encoded strings).
  final List<dynamic> arguments;

  /// Validates function name.
  static String _validateFunctionName(String name) {
    if (name.isEmpty) {
      throw ArgumentError('Function name cannot be empty');
    }
    if (name.contains(RegExp(r'\s'))) {
      throw ArgumentError('Function name cannot contain whitespace: $name');
    }
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(name)) {
      throw ArgumentError(
        'Function name must start with a letter and contain only '
        'letters, numbers, and underscores: $name',
      );
    }
    return name;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmartContractFunction &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          CollectionUtils.listEquals(arguments, other.arguments);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(arguments));

  @override
  String toString() => 'SmartContractFunction($name, ${arguments.length} args)';
}

/// Specification for a batch query operation.
@immutable
class BatchQuerySpec {
  /// Creates batch query specification.
  ///
  /// #### Parameters
  /// - `endpointName` - Endpoint to query (required)
  /// - `arguments` - Native Dart arguments (optional)
  /// - `caller` - Optional caller address
  /// - `value` - Optional value to send (usually zero for queries)
  const BatchQuerySpec({
    required this.endpointName,
    this.arguments = const <dynamic>[],
    this.caller,
    this.value,
  });

  /// Endpoint name to query.
  final String endpointName;

  /// Query arguments (native Dart types).
  final List<dynamic> arguments;

  /// Optional caller address.
  final Address? caller;

  /// Optional value to send (usually zero for views).
  final Balance? value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatchQuerySpec &&
          runtimeType == other.runtimeType &&
          endpointName == other.endpointName &&
          CollectionUtils.listEquals(arguments, other.arguments) &&
          caller == other.caller &&
          value == other.value;

  @override
  int get hashCode =>
      Object.hash(endpointName, Object.hashAll(arguments), caller, value);

  @override
  String toString() =>
      'BatchQuerySpec($endpointName, ${arguments.length} args)';
}

/// Exception for argument encoding failures.
///
/// Thrown when encoding native Dart values to ABI types fails.
class ArgumentEncodingException extends SmartContractException {
  /// Creates argument encoding exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `endpointName` - Optional endpoint name
  /// - `argumentIndex` - Optional 0-based argument position
  /// - `argumentValue` - Optional actual value provided
  /// - `expectedType` - Optional expected ABI type
  /// - `cause` - Optional underlying exception
  /// - `stackTrace` - Optional stack trace
  const ArgumentEncodingException(
    super.message, {
    this.endpointName,
    this.argumentIndex,
    this.argumentValue,
    this.expectedType,
    super.cause,
    super.stackTrace,
  });

  /// Endpoint name.
  final String? endpointName;

  /// Argument index (0-based).
  final int? argumentIndex;

  /// Argument value.
  final dynamic argumentValue;

  /// Expected type from ABI.
  final String? expectedType;

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer(
      'ArgumentEncodingException: $message',
    );
    if (endpointName != null) {
      buffer.write('\n  Endpoint: $endpointName');
    }
    if (argumentIndex != null) {
      buffer.write('\n  Argument index: $argumentIndex');
    }
    if (argumentValue != null) {
      buffer.write('\n  Argument value: $argumentValue');
    }
    if (expectedType != null) {
      buffer.write('\n  Expected type: $expectedType');
    }
    if (cause != null) {
      buffer.write('\n  Caused by: $cause');
    }
    return buffer.toString();
  }
}

/// Exception for response parsing failures.
///
/// Thrown when decoding contract response to native Dart fails.
class ResponseParsingException extends SmartContractException {
  /// Creates response parsing exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `endpointName` - Optional endpoint name
  /// - `returnIndex` - Optional 0-based return value position
  /// - `rawData` - Optional hex string of raw response
  /// - `expectedType` - Optional expected ABI type
  /// - `cause` - Optional underlying exception
  /// - `stackTrace` - Optional stack trace
  const ResponseParsingException(
    super.message, {
    this.endpointName,
    this.returnIndex,
    this.rawData,
    this.expectedType,
    super.cause,
    super.stackTrace,
  });

  /// Endpoint name.
  final String? endpointName;

  /// Return value index (0-based).
  final int? returnIndex;

  /// Raw response data.
  final String? rawData;

  /// Expected type from ABI.
  final String? expectedType;

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer(
      'ResponseParsingException: $message',
    );
    if (endpointName != null) {
      buffer.write('\n  Endpoint: $endpointName');
    }
    if (returnIndex != null) {
      buffer.write('\n  Return index: $returnIndex');
    }
    if (rawData != null) {
      buffer.write('\n  Raw data: $rawData');
    }
    if (expectedType != null) {
      buffer.write('\n  Expected type: $expectedType');
    }
    if (cause != null) {
      buffer.write('\n  Caused by: $cause');
    }
    return buffer.toString();
  }
}

/// Exception when ABI definition is not provided but required.
///
/// Thrown when operations requiring ABI are attempted without one.
class AbiNotFoundException extends SmartContractException {
  /// Creates ABI not found exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `operation` - Operation that requires ABI (required)
  /// - `cause` - Optional underlying exception
  /// - `stackTrace` - Optional stack trace
  const AbiNotFoundException(
    super.message, {
    required this.operation,
    super.cause,
    super.stackTrace,
  });

  /// Creates exception with default message.
  ///
  /// #### Parameters
  /// - `operation` - Operation name requiring ABI
  ///
  /// #### Returns
  /// `AbiNotFoundException` - Exception with standard message
  factory AbiNotFoundException.forOperation(String operation) {
    return AbiNotFoundException(
      'ABI definition is required for operation "$operation" but was not provided. '
      'Please provide an ABI definition when creating the SmartContractController.',
      operation: operation,
    );
  }

  /// Operation that required the ABI.
  final String operation;

  @override
  String toString() {
    return 'AbiNotFoundException: $message\n  Operation: $operation';
  }
}

/// Exception when endpoint is not found in ABI.
///
/// Thrown when calling non-existent endpoint with suggestions.
class EndpointNotFoundException extends SmartContractException {
  /// Creates endpoint not found exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `endpointName` - Name that was not found (required)
  /// - `abi` - Optional ABI searched
  /// - `availableEndpoints` - Optional list of valid names
  /// - `cause` - Optional underlying exception
  /// - `stackTrace` - Optional stack trace
  const EndpointNotFoundException(
    super.message, {
    required this.endpointName,
    this.abi,
    this.availableEndpoints,
    super.cause,
    super.stackTrace,
  });

  /// Creates exception with suggestions using Levenshtein distance.
  ///
  /// #### Parameters
  /// - `endpointName` - Endpoint name that was not found
  /// - `abi` - ABI to search for similar names
  ///
  /// #### Returns
  /// `EndpointNotFoundException` - Exception with helpful suggestions
  factory EndpointNotFoundException.withSuggestions({
    required String endpointName,
    required SmartContractAbi abi,
  }) {
    final List<String> available = abi.endpoints
        .map((AbiEndpoint e) => e.name)
        .toList();
    final List<String> suggestions = _findSimilarEndpoints(
      endpointName,
      available,
    );

    final StringBuffer buffer = StringBuffer(
      'Endpoint "$endpointName" not found in ABI.',
    );

    if (suggestions.isNotEmpty) {
      buffer.write('\n\nDid you mean one of these?');
      for (final String suggestion in suggestions) {
        buffer.write('\n  - $suggestion');
      }
    } else if (available.isNotEmpty) {
      buffer.write('\n\nAvailable endpoints:');
      for (final String endpoint in available.take(10)) {
        buffer.write('\n  - $endpoint');
      }
      if (available.length > 10) {
        buffer.write('\n  ... and ${available.length - 10} more');
      }
    }

    return EndpointNotFoundException(
      buffer.toString(),
      endpointName: endpointName,
      abi: abi,
      availableEndpoints: available,
    );
  }

  /// Endpoint name that was not found.
  final String endpointName;

  /// ABI definition searched.
  final SmartContractAbi? abi;

  /// Available endpoint names.
  final List<String>? availableEndpoints;

  static List<String> _findSimilarEndpoints(
    String target,
    List<String> candidates, {
    int maxDistance = 3,
    int maxSuggestions = 3,
  }) {
    final List<(int, String)> suggestions = <(int, String)>[];

    for (final String candidate in candidates) {
      final int distance = StringUtils.levenshteinDistance(
        target.toLowerCase(),
        candidate.toLowerCase(),
      );
      if (distance <= maxDistance) {
        suggestions.add((distance, candidate));
      }
    }

    suggestions.sort(
      ((int, String) a, (int, String) b) => a.$1.compareTo(b.$1),
    );
    return suggestions
        .take(maxSuggestions)
        .map(((int, String) s) => s.$2)
        .toList();
  }

  @override
  String toString() {
    return 'EndpointNotFoundException: $message\n  Endpoint: $endpointName';
  }
}

/// Exception for argument validation failures.
///
/// Thrown when argument count or types don't match ABI.
class ArgumentValidationException extends SmartContractException {
  /// Creates argument validation exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `endpointName` - Endpoint being called (required)
  /// - `expectedCount` - Expected argument count from ABI (required)
  /// - `actualCount` - Actual argument count provided (required)
  /// - `validationErrors` - Optional list of per-argument errors
  /// - `cause` - Optional underlying exception
  /// - `stackTrace` - Optional stack trace
  const ArgumentValidationException(
    super.message, {
    required this.endpointName,
    required this.expectedCount,
    required this.actualCount,
    this.validationErrors,
    super.cause,
    super.stackTrace,
  });

  /// Creates exception for argument count mismatch.
  ///
  /// #### Parameters
  /// - `endpointName` - Endpoint name
  /// - `expected` - Expected count
  /// - `actual` - Actual count
  ///
  /// #### Returns
  /// `ArgumentValidationException` - Exception with count mismatch message
  factory ArgumentValidationException.countMismatch({
    required String endpointName,
    required int expected,
    required int actual,
  }) {
    return ArgumentValidationException(
      'Argument count mismatch for endpoint "$endpointName": '
      'expected $expected but got $actual',
      endpointName: endpointName,
      expectedCount: expected,
      actualCount: actual,
    );
  }

  /// Creates exception for type mismatches.
  ///
  /// #### Parameters
  /// - `endpointName` - Endpoint name
  /// - `expectedCount` - Expected argument count
  /// - `actualCount` - Actual argument count
  /// - `errors` - List of validation error messages
  ///
  /// #### Returns
  /// `ArgumentValidationException` - Exception with detailed errors
  factory ArgumentValidationException.typeErrors({
    required String endpointName,
    required int expectedCount,
    required int actualCount,
    required List<String> errors,
  }) {
    final StringBuffer buffer = StringBuffer(
      'Argument validation failed for endpoint "$endpointName":\n',
    );
    for (int i = 0; i < errors.length; i++) {
      buffer.write('  ${i + 1}. ${errors[i]}\n');
    }

    return ArgumentValidationException(
      buffer.toString().trim(),
      endpointName: endpointName,
      expectedCount: expectedCount,
      actualCount: actualCount,
      validationErrors: errors,
    );
  }

  /// Endpoint name.
  final String endpointName;

  /// Expected argument count from ABI.
  final int expectedCount;

  /// Provided argument count.
  final int actualCount;

  /// Validation errors per argument.
  final List<String>? validationErrors;

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer(
      'ArgumentValidationException: $message',
    );
    if (validationErrors != null && validationErrors!.isNotEmpty) {
      buffer.write('\n  Validation errors:');
      for (final String error in validationErrors!) {
        buffer.write('\n    - $error');
      }
    }
    return buffer.toString();
  }
}

/// Exception for response validation failures.
///
/// Thrown when return value count doesn't match ABI.
class ResponseValidationException extends SmartContractException {
  /// Creates response validation exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `endpointName` - Endpoint being called (required)
  /// - `expectedCount` - Expected return value count from ABI (required)
  /// - `actualCount` - Actual return value count (required)
  /// - `cause` - Optional underlying exception
  /// - `stackTrace` - Optional stack trace
  const ResponseValidationException(
    super.message, {
    required this.endpointName,
    required this.expectedCount,
    required this.actualCount,
    super.cause,
    super.stackTrace,
  });

  /// Creates exception for return value count mismatch.
  ///
  /// #### Parameters
  /// - `endpointName` - Endpoint name
  /// - `expected` - Expected count
  /// - `actual` - Actual count
  ///
  /// #### Returns
  /// `ResponseValidationException` - Exception with count mismatch message
  factory ResponseValidationException.countMismatch({
    required String endpointName,
    required int expected,
    required int actual,
  }) {
    return ResponseValidationException(
      'Return value count mismatch for endpoint "$endpointName": '
      'expected $expected but got $actual',
      endpointName: endpointName,
      expectedCount: expected,
      actualCount: actual,
    );
  }

  /// Endpoint name.
  final String endpointName;

  /// Expected return value count from ABI.
  final int expectedCount;

  /// Actual return value count.
  final int actualCount;

  @override
  String toString() {
    return 'ResponseValidationException: $message\n'
        '  Endpoint: $endpointName\n'
        '  Expected: $expectedCount return values\n'
        '  Actual: $actualCount return values';
  }
}

/// Exception for gas estimation failures.
class GasEstimationException extends SmartContractException {
  /// Thrown when automatic gas estimation fails.
  /// Exception thrown when gas estimation fails due to transaction simulation failure.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `endpointName` - Optional endpoint name
  /// - `transactionType` - Transaction type: 'call', 'deploy', or 'upgrade' (required)
  /// - `cause` - Optional underlying exception
  /// - `stackTrace` - Optional stack trace
  /// - `reason` - Error message from blockchain (optional)
  /// - `status` - Simulation status from API (optional)
  /// - `rawResponse` - Complete API response for debugging (optional)
  /// - `contract` - Contract address where simulation failed (optional)
  /// - `hint` - User-friendly hint for fixing the issue (optional)
  const GasEstimationException(
    super.message, {
    this.endpointName,
    required this.transactionType,
    super.cause,
    super.stackTrace,
    this.reason,
    this.status,
    this.rawResponse,
    this.contract,
    this.hint,
  });

  /// Endpoint name.
  final String? endpointName;

  /// Transaction type
  final String transactionType;

  /// Reason from blockchain response.
  final String? reason;

  /// Status from blockchain response.
  final String? status;

  /// Complete raw API response.
  final Map<String, dynamic>? rawResponse;

  /// Contract address where simulation failed.
  final String? contract;

  /// User-friendly hint for resolving the issue.
  final String? hint;

  /// Decodes reason if it's hex-encoded.
  String get decodedReason {
    final r = reason ?? message;
    if (r.startsWith('@')) {
      try {
        final hex = r.substring(1);
        final bytes = HexUtils.hexToBytes(hex);
        return String.fromCharCodes(bytes);
      } catch (_) {
        return r;
      }
    }
    return r;
  }

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer(
      'GasEstimationException: $message',
    );
    buffer.write('\n  Transaction type: $transactionType');
    if (endpointName != null) {
      buffer.write('\n  Endpoint: $endpointName');
    }
    if (contract != null) {
      buffer.write('\n  Contract: $contract');
    }
    if (reason != null && reason != message) {
      buffer.write('\n  Reason: $decodedReason');
    }
    if (status != null) {
      buffer.write('\n  Status: $status');
    }
    if (hint != null) {
      buffer.write('\n  Hint: $hint');
    }
    if (cause != null) {
      buffer.write('\n  Caused by: $cause');
    }
    return buffer.toString();
  }

  /// Creates exception from API response.
  factory GasEstimationException.fromApiResponse(
    Map<String, dynamic> response, {
    required String transactionType,
    String? contract,
    String? endpointName,
  }) {
    final reason =
        optionalAs<String>(response['returnMessage'], 'returnMessage') ??
        'Unknown error';
    final status = optionalAs<String>(response['status'], 'status') ?? 'fail';

    String? hint;
    if (reason.toLowerCase().contains('insufficient funds') ||
        reason.toLowerCase().contains('insufficient balance')) {
      hint = 'Check account has sufficient balance for transaction';
    } else if (reason.toLowerCase().contains('paused')) {
      hint = 'Contract or function is currently paused';
    } else if (reason.toLowerCase().contains('wrong number of arguments') ||
        reason.toLowerCase().contains('invalid argument')) {
      hint = 'Verify function signature matches ABI definition';
    }

    return GasEstimationException(
      'Transaction simulation failed - $reason',
      transactionType: transactionType,
      reason: reason,
      status: status,
      rawResponse: response,
      contract: contract,
      endpointName: endpointName,
      hint: hint,
    );
  }
}
