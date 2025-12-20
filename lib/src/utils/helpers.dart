/// Helper utilities for generated code
///
/// This file contains shared logic used by all generated contract code
/// to reduce duplication and improve maintainability.
import '../core/core.dart';
import '../infrastructure/network/network_provider.dart';

/// Safely casts a dynamic value to type T with descriptive error messages.
///
/// Use this instead of `as T` casts for better error handling when parsing
/// JSON, API responses, or any dynamic data.
///
/// #### Example
/// ```dart
/// final name = requireAs<String>(json['name'], 'name');
/// final count = requireAs<int>(json['count'], 'count');
/// final items = requireAs<List<dynamic>>(json['items'], 'items');
/// ```
///
/// #### Parameters
/// - `value` - The dynamic value to cast
/// - `field` - Field name for error messages
///
/// #### Returns
/// The value cast to type T
///
/// #### Throws
/// - `FormatException` - If value is not of type T (with descriptive message)
T requireAs<T>(dynamic value, String field) {
  if (value is T) return value;
  throw FormatException('Expected $T for "$field", got ${value.runtimeType}');
}

/// Safely casts a nullable dynamic value to type T? with descriptive error messages.
///
/// Returns null if the value is null, otherwise casts to T.
///
/// #### Example
/// ```dart
/// final name = optionalAs<String>(json['name'], 'name'); // null if missing
/// ```
///
/// #### Parameters
/// - `value` - The dynamic value to cast (can be null)
/// - `field` - Field name for error messages
///
/// #### Returns
/// The value cast to type T, or null if value was null
///
/// #### Throws
/// - `FormatException` - If value is not null and not of type T
T? optionalAs<T>(dynamic value, String field) {
  if (value == null) return null;
  if (value is T) return value;
  throw FormatException(
    'Expected $T or null for "$field", got ${value.runtimeType}',
  );
}

/// Forces compile-time type inference for the given value.
///
/// #### Example
/// ```dart
/// final value = infer<BigInt>(result.nativeValue);
/// ```
///
/// #### Parameters
/// - `value` - The value to type-check and return
///
/// #### Returns
/// The same value, but with type T explicitly verified at compile time
T infer<T>(T value) => value;

/// Executes a transaction creation with standardized error handling
///
/// Wraps the transaction creation in a try-catch block and converts
/// generic exceptions into [TransactionCreationException].
///
/// Rethrows [NetworkException], [ABIException], and [ValidationException]
/// as they already provide detailed error information.
///
/// Example:
/// ```dart
/// return executeTransaction(
///   endpointName: 'acceptGlobalOffer',
///   action: () => controller.createCallTransaction(...),
/// );
/// ```
Future<T> executeTransaction<T>({
  required String endpointName,
  required Future<T> Function() action,
}) async {
  try {
    return await action();
  } catch (e) {
    if (e is NetworkException ||
        e is SerializationException ||
        e is SmartContractException ||
        e is ValidationException ||
        e is TransactionCreationException) {
      rethrow;
    }
    throw TransactionCreationException(
      'Failed to create transaction for $endpointName',
      cause: e,
    );
  }
}

/// Executes a query with standardized error handling
///
/// Wraps the query execution in a try-catch block and converts
/// generic exceptions into [NetworkException].
///
/// Rethrows [NetworkException], [SerializationException], [SmartContractException],
/// and [ValidationException] as they already provide detailed error information.
///
/// Example:
/// ```dart
/// return executeQuery(
///   endpointName: 'getStatus',
///   action: () => controller.query(endpointName: 'getStatus'),
/// );
/// ```
Future<T> executeQuery<T>({
  required String endpointName,
  required Future<T> Function() action,
}) async {
  try {
    return await action();
  } catch (e) {
    if (e is NetworkException ||
        e is SerializationException ||
        e is SmartContractException ||
        e is ValidationException) {
      rethrow;
    }
    throw NetworkException('Failed to query $endpointName', cause: e);
  }
}

/// Safely parses a dynamic value to int with descriptive error messages.
///
/// Handles both int values directly and values that need parsing via toString().
///
/// #### Example
/// ```dart
/// final count = requireInt(json['count'], 'count');
/// ```
///
/// #### Parameters
/// - `value` - The dynamic value to parse (can be int or any toString-able value)
/// - `field` - Field name for error messages
///
/// #### Returns
/// The parsed int value
///
/// #### Throws
/// - `FormatException` - If value is null or cannot be parsed as int
int requireInt(dynamic value, String field) {
  if (value == null) {
    throw FormatException('Expected int for "$field", got null');
  }
  if (value is int) return value;
  try {
    return int.parse(value.toString());
  } catch (e) {
    throw FormatException(
      'Expected int for "$field", got "${value.toString()}" (${value.runtimeType})',
    );
  }
}

/// Safely parses a nullable dynamic value to int? with descriptive error messages.
///
/// Returns null if the value is null, otherwise parses to int.
///
/// #### Example
/// ```dart
/// final count = optionalInt(json['count'], 'count'); // null if missing
/// ```
///
/// #### Parameters
/// - `value` - The dynamic value to parse (can be null)
/// - `field` - Field name for error messages
///
/// #### Returns
/// The parsed int value, or null if value was null
///
/// #### Throws
/// - `FormatException` - If value is not null and cannot be parsed as int
int? optionalInt(dynamic value, String field) {
  if (value == null) return null;
  if (value is int) return value;
  try {
    return int.parse(value.toString());
  } catch (e) {
    throw FormatException(
      'Expected int or null for "$field", got "${value.toString()}" (${value.runtimeType})',
    );
  }
}

/// Estimates gas for a transaction using network simulation.
///
/// Automatically sets maximum gas limit (600M) on the transaction for simulation,
/// then uses `GasEstimator` to determine actual gas consumption with a 1.1x multiplier.
///
/// #### Parameters
/// - `transaction` - Transaction to estimate gas for
/// - `networkProvider` - Network provider to use for simulation
///
/// #### Returns
/// `GasLimit` with the estimated gas (actual * 1.1 buffer)
///
/// #### Throws
/// - `NetworkException` - If simulation fails
///
/// #### Example
/// ```dart
/// // Create transaction (gas limit will be set to max internally)
/// final tx = await controller.call(
///   account: sender,
///   nonce: nonce,
///   endpointName: 'myEndpoint',
///   arguments: [arg1, arg2],
///   options: BaseControllerInput(gasLimit: const GasLimit(600000000)),
/// );
///
/// // Estimate actual gas needed
/// final estimatedGas = await simulateGas(tx, controller.networkProvider);
///
/// // Create final transaction with estimated gas
/// final finalTx = tx.copyWith(newGasLimit: estimatedGas);
/// ```
Future<GasLimit> simulateGas(
  Transaction transaction,
  NetworkProvider networkProvider,
) async {
  final GasEstimator estimator = GasEstimator(
    networkProvider: networkProvider,
    gasMultiplier: 1.1,
  );
  final simulatedTransaction = transaction.copyWith(
    newGasLimit: const GasLimit(600000000),
  );
  final GasLimit estimatedGas = await estimator.estimate(simulatedTransaction);
  return estimatedGas;
}
