/// Unified exception hierarchy for the Abidock MultiversX SDK.
///
/// All SDK exceptions inherit from [AbidockException], organized into categories:
/// - [WalletException] - Key management, signing, encryption errors
/// - [SmartContractException] - ABI encoding/decoding, contract interaction errors
/// - [TransactionException] - Transaction creation, validation, execution errors
/// - [NetworkException] - Network communication, HTTP errors
/// - [SerializationException] - Data encoding/decoding errors
///
/// #### Example
/// ```dart
/// try {
///   await provider.sendTransaction(tx);
/// } on NetworkException catch (e) {
///   // Handle network-specific error
///   print('Network error: ${e.message}');
/// } on TransactionException catch (e) {
///   // Handle transaction-specific error
///   print('Transaction error: ${e.message}');
/// } on AbidockException catch (e) {
///   // Catch any SDK exception
///   print('SDK error: ${e.message}');
/// }
/// ```

/// Base exception for all Abidock SDK errors.
///
/// All SDK exceptions inherit from this class, enabling unified error handling.
/// Use specific subclasses for precise error handling or catch [AbidockException]
/// for general SDK error handling.
///
/// #### Parameters
/// - `message` - Human-readable error description
/// - `cause` - Optional underlying exception that triggered this error
/// - `stackTrace` - Optional stack trace for debugging
///
/// #### Example
/// ```dart
/// // Catch any SDK exception
/// try {
///   await controller.sendTransaction(tx);
/// } on AbidockException catch (e) {
///   print('SDK error: ${e.message}');
///   if (e.cause != null) print('Caused by: ${e.cause}');
/// }
/// ```
abstract class AbidockException implements Exception {
  /// Creates a new SDK exception.
  ///
  /// #### Parameters
  /// - `message` - Human-readable error description
  /// - `cause` - Optional underlying exception
  /// - `stackTrace` - Optional stack trace
  const AbidockException(this.message, {this.cause, this.stackTrace});

  /// Human-readable error message.
  final String message;

  /// Underlying cause of the exception (if any).
  final Object? cause;

  /// Stack trace when the exception was created.
  final StackTrace? stackTrace;

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

/// Base exception for wallet and cryptographic operations.
///
/// Covers key management, signing, encryption, and mnemonic operations.
///
/// #### Example
/// ```dart
/// try {
///   final signer = UserSigner.fromPem(invalidPem);
/// } on WalletException catch (e) {
///   print('Wallet error: ${e.message}');
/// }
/// ```
class WalletException extends AbidockException {
  /// Creates a wallet exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `cause` - Optional underlying exception
  /// - `stackTrace` - Optional stack trace
  const WalletException(super.message, {super.cause, super.stackTrace});
}

/// Exception thrown when PEM parsing fails.
///
/// #### Example
/// ```dart
/// try {
///   final key = parseUserKey(invalidPem);
/// } on PemException catch (e) {
///   print('PEM parsing failed: ${e.message}');
/// }
/// ```
class PemException extends WalletException {
  /// Creates a PEM parsing exception.
  const PemException(super.message, {super.cause, super.stackTrace});
}

/// Exception thrown when mnemonic operations fail.
///
/// #### Example
/// ```dart
/// try {
///   final mnemonic = Mnemonic.fromString(invalidWords);
/// } on MnemonicException catch (e) {
///   print('Invalid mnemonic: ${e.message}');
/// }
/// ```
class MnemonicException extends WalletException {
  /// Creates a mnemonic exception.
  const MnemonicException(super.message, {super.cause, super.stackTrace});
}

/// Exception thrown during signing operations.
///
/// #### Example
/// ```dart
/// try {
///   final signature = await signer.sign(messageBytes);
/// } on SignerException catch (e) {
///   print('Signing failed: ${e.message}');
/// }
/// ```
class SignerException extends WalletException {
  /// Creates a signer exception.
  const SignerException(super.message, {super.cause, super.stackTrace});
}

/// Exception thrown when wallet decryption fails.
///
/// #### Example
/// ```dart
/// try {
///   final wallet = UserWallet.fromJson(keystoreJson, 'password');
/// } on DecryptorException catch (e) {
///   print('Decryption failed: ${e.message}');
/// }
/// ```
class DecryptorException extends WalletException {
  /// Creates a decryptor exception.
  const DecryptorException(super.message, {super.cause, super.stackTrace});
}

/// Exception thrown when buffer/key length validation fails.
///
/// #### Example
/// ```dart
/// try {
///   guardLength(keyBytes, 32);
/// } on WalletLengthException catch (e) {
///   print('Invalid key length: ${e.message}');
/// }
/// ```
class WalletLengthException extends WalletException {
  /// Creates a length validation exception.
  const WalletLengthException(super.message, {super.cause, super.stackTrace});
}

/// Base exception for network operations.
///
/// Covers HTTP requests, API calls, and gateway communication.
///
/// #### Example
/// ```dart
/// try {
///   await provider.getAccount(address);
/// } on NetworkException catch (e) {
///   print('Network error: ${e.message}');
///   if (e.statusCode != null) print('HTTP ${e.statusCode}');
///   if (e.endpoint != null) print('Endpoint: ${e.endpoint}');
/// }
/// ```
class NetworkException extends AbidockException {
  /// Creates a network exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `statusCode` - Optional HTTP status code
  /// - `endpoint` - Optional endpoint that failed
  const NetworkException(
    super.message, {
    this.statusCode,
    this.endpoint,
    super.cause,
    super.stackTrace,
  });

  /// HTTP status code (if applicable).
  final int? statusCode;

  /// The endpoint that failed (if applicable).
  final String? endpoint;

  @override
  String toString() {
    final buffer = StringBuffer('NetworkException: $message');
    if (statusCode != null) buffer.write(' (HTTP $statusCode)');
    if (endpoint != null) buffer.write(' at $endpoint');
    if (cause != null) buffer.write('\nCaused by: $cause');
    return buffer.toString();
  }
}

/// Exception thrown when account awaiter times out.
///
/// #### Example
/// ```dart
/// try {
///   await awaiter.awaitOnAddress(address, predicate);
/// } on AccountAwaiterTimeoutException catch (e) {
///   print('Timeout waiting for ${e.address}: ${e.message}');
/// }
/// ```
class AccountAwaiterTimeoutException extends NetworkException {
  /// Creates an account awaiter timeout exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `address` - Optional address being awaited
  /// - `timeout` - Optional timeout duration
  const AccountAwaiterTimeoutException(
    super.message, {
    this.address,
    this.timeout,
    super.cause,
    super.stackTrace,
  });

  /// The address being awaited.
  final String? address;

  /// The timeout duration.
  final Duration? timeout;

  @override
  String toString() {
    final buffer = StringBuffer('AccountAwaiterTimeoutException: $message');
    if (address != null) buffer.write('\n  Address: $address');
    if (timeout != null) buffer.write('\n  Timeout: ${timeout!.inSeconds}s');
    if (cause != null) buffer.write('\n  Caused by: $cause');
    return buffer.toString();
  }
}

/// Exception thrown when account awaiter fails.
///
/// #### Example
/// ```dart
/// try {
///   await awaiter.awaitOnAddress(address, predicate);
/// } on AccountAwaiterException catch (e) {
///   print('Awaiter error: ${e.message}');
/// }
/// ```
class AccountAwaiterException extends NetworkException {
  /// Creates an account awaiter exception.
  const AccountAwaiterException(
    super.message, {
    super.statusCode,
    super.endpoint,
    super.cause,
    super.stackTrace,
  });
}

/// Base exception for transaction operations.
///
/// Covers transaction creation, validation, signing, and execution.
///
/// #### Example
/// ```dart
/// try {
///   await controller.sendTransaction(tx);
/// } on TransactionException catch (e) {
///   print('Transaction error: ${e.message}');
/// }
/// ```
class TransactionException extends AbidockException {
  /// Creates a transaction exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `cause` - Optional underlying exception
  /// - `stackTrace` - Optional stack trace
  const TransactionException(super.message, {super.cause, super.stackTrace});
}

/// Exception thrown when transaction creation or signing fails.
///
/// #### Example
/// ```dart
/// try {
///   final tx = await controller.createCallTransaction(...);
/// } on TransactionCreationException catch (e) {
///   print('Failed to create tx: ${e.message}');
///   if (e.transactionHash != null) {
///     print('Partial tx: ${e.transactionHash}');
///   }
/// }
/// ```
class TransactionCreationException extends TransactionException {
  /// Creates a transaction creation exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `transactionHash` - Optional hash if tx was partially created
  const TransactionCreationException(
    super.message, {
    this.transactionHash,
    super.cause,
    super.stackTrace,
  });

  /// The transaction hash (if the transaction was created).
  final String? transactionHash;

  @override
  String toString() {
    final buffer = StringBuffer('TransactionCreationException: $message');
    if (transactionHash != null) buffer.write(' (tx: $transactionHash)');
    if (cause != null) buffer.write('\nCaused by: $cause');
    return buffer.toString();
  }
}

/// Exception thrown when transaction watcher times out.
///
/// #### Example
/// ```dart
/// try {
///   await watcher.awaitCompleted(txHash);
/// } on TransactionWatcherTimeoutException catch (e) {
///   print('Timeout waiting for ${e.transactionHash}');
/// }
/// ```
class TransactionWatcherTimeoutException extends TransactionException {
  /// Creates a transaction watcher timeout exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `transactionHash` - Optional tx hash being watched
  /// - `timeout` - Optional timeout duration
  const TransactionWatcherTimeoutException(
    super.message, {
    this.transactionHash,
    this.timeout,
    super.cause,
    super.stackTrace,
  });

  /// The transaction hash being watched.
  final String? transactionHash;

  /// The timeout duration.
  final Duration? timeout;

  @override
  String toString() {
    final buffer = StringBuffer('TransactionWatcherTimeoutException: $message');
    if (transactionHash != null) {
      buffer.write('\n  Transaction: $transactionHash');
    }
    if (timeout != null) buffer.write('\n  Timeout: ${timeout!.inSeconds}s');
    if (cause != null) buffer.write('\n  Caused by: $cause');
    return buffer.toString();
  }
}

/// Exception thrown when transaction watcher fails.
///
/// #### Example
/// ```dart
/// try {
///   await watcher.awaitCompleted(txHash);
/// } on TransactionWatcherException catch (e) {
///   print('Watch failed for ${e.transactionHash}: ${e.message}');
/// }
/// ```
class TransactionWatcherException extends TransactionException {
  /// Creates a transaction watcher exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `transactionHash` - Optional tx hash being watched
  const TransactionWatcherException(
    super.message, {
    this.transactionHash,
    super.cause,
    super.stackTrace,
  });

  /// The transaction hash being watched.
  final String? transactionHash;

  @override
  String toString() {
    final buffer = StringBuffer('TransactionWatcherException: $message');
    if (transactionHash != null) {
      buffer.write('\n  Transaction: $transactionHash');
    }
    if (cause != null) buffer.write('\n  Caused by: $cause');
    return buffer.toString();
  }
}

/// Exception thrown when transaction event parsing fails.
///
/// #### Example
/// ```dart
/// try {
///   final event = parser.parseEvent(rawEvent);
/// } on EventParsingException catch (e) {
///   print('Failed to parse ${e.eventIdentifier}: ${e.message}');
/// }
/// ```
class EventParsingException extends TransactionException {
  /// Creates an event parsing exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `eventIdentifier` - Optional event identifier being parsed
  const EventParsingException(
    super.message, {
    this.eventIdentifier,
    super.cause,
    super.stackTrace,
  });

  /// The event identifier being parsed.
  final String? eventIdentifier;

  @override
  String toString() {
    final buffer = StringBuffer('EventParsingException: $message');
    if (eventIdentifier != null) buffer.write('\n  Event: $eventIdentifier');
    if (cause != null) buffer.write('\n  Caused by: $cause');
    return buffer.toString();
  }
}

/// Base exception for smart contract operations.
///
/// Covers ABI encoding/decoding, contract queries, and execution.
/// Detailed subclasses are defined in `abi/core/core_types.dart`.
///
/// #### Example
/// ```dart
/// try {
///   await controller.query(endpointName: 'getStatus');
/// } on SmartContractException catch (e) {
///   print('Contract error: ${e.message}');
/// }
/// ```
class SmartContractException extends AbidockException {
  /// Creates a smart contract exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `cause` - Optional underlying exception
  /// - `stackTrace` - Optional stack trace
  const SmartContractException(super.message, {super.cause, super.stackTrace});
}

/// Base exception for serialization/deserialization operations.
///
/// #### Example
/// ```dart
/// try {
///   final encoded = codec.encode(value);
/// } on SerializationException catch (e) {
///   print('Encoding failed: ${e.message}');
/// }
/// ```
class SerializationException extends AbidockException {
  /// Creates a serialization exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `cause` - Optional underlying exception
  /// - `stackTrace` - Optional stack trace
  const SerializationException(super.message, {super.cause, super.stackTrace});
}

/// Exception thrown when ABI binary codec fails.
///
/// #### Example
/// ```dart
/// try {
///   final encoded = codec.encodeTopLevel(value, type);
/// } on AbiBinaryCodecException catch (e) {
///   print('Codec error for ${e.typeName}: ${e.message}');
/// }
/// ```
class AbiBinaryCodecException extends SerializationException {
  /// Creates an ABI binary codec exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `typeName` - Optional ABI type being processed
  /// - `value` - Optional value being processed
  const AbiBinaryCodecException(
    super.message, {
    this.typeName,
    this.value,
    super.cause,
    super.stackTrace,
  });

  /// The type being encoded/decoded.
  final String? typeName;

  /// The value being processed.
  final dynamic value;

  @override
  String toString() {
    final buffer = StringBuffer('AbiBinaryCodecException: $message');
    if (typeName != null) buffer.write('\n  Type: $typeName');
    if (value != null) buffer.write('\n  Value: $value');
    if (cause != null) buffer.write('\n  Caused by: $cause');
    return buffer.toString();
  }
}

/// Exception thrown when ABI native serialization fails.
///
/// #### Example
/// ```dart
/// try {
///   final encoded = serializer.serialize(value);
/// } on AbiNativeSerializationException catch (e) {
///   print('Serialization error for ${e.typeName}: ${e.message}');
/// }
/// ```
class AbiNativeSerializationException extends SerializationException {
  /// Creates an ABI native serialization exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `typeName` - Optional ABI type being serialized
  /// - `value` - Optional value being serialized
  const AbiNativeSerializationException(
    super.message, {
    this.typeName,
    this.value,
    super.cause,
    super.stackTrace,
  });

  /// The type being serialized.
  final String? typeName;

  /// The value being serialized.
  final dynamic value;

  @override
  String toString() {
    final buffer = StringBuffer('AbiNativeSerializationException: $message');
    if (typeName != null) buffer.write('\n  Type: $typeName');
    if (value != null) buffer.write('\n  Value: $value');
    if (cause != null) buffer.write('\n  Caused by: $cause');
    return buffer.toString();
  }
}

/// Exception thrown when ABI argument serialization fails.
///
/// #### Example
/// ```dart
/// try {
///   final encoded = argSerializer.encode(args);
/// } on AbiArgumentSerializationException catch (e) {
///   print('Arg ${e.argumentIndex} failed for ${e.typeName}: ${e.message}');
/// }
/// ```
class AbiArgumentSerializationException extends SerializationException {
  /// Creates an ABI argument serialization exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `argumentIndex` - Optional 0-based argument position
  /// - `typeName` - Optional ABI type being serialized
  const AbiArgumentSerializationException(
    super.message, {
    this.argumentIndex,
    this.typeName,
    super.cause,
    super.stackTrace,
  });

  /// Argument index (0-based).
  final int? argumentIndex;

  /// The type being serialized.
  final String? typeName;

  @override
  String toString() {
    final buffer = StringBuffer('AbiArgumentSerializationException: $message');
    if (argumentIndex != null) {
      buffer.write('\n  Argument index: $argumentIndex');
    }
    if (typeName != null) buffer.write('\n  Type: $typeName');
    if (cause != null) buffer.write('\n  Caused by: $cause');
    return buffer.toString();
  }
}

/// Exception thrown when deserialization fails.
///
/// #### Example
/// ```dart
/// try {
///   final value = deserializer.decode(data, type);
/// } on DeserializationException catch (e) {
///   print('Failed to decode ${e.typeName}: ${e.message}');
/// }
/// ```
class DeserializationException extends SerializationException {
  /// Creates a deserialization exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `typeName` - Optional ABI type being deserialized
  /// - `rawData` - Optional raw data being deserialized
  const DeserializationException(
    super.message, {
    this.typeName,
    this.rawData,
    super.cause,
    super.stackTrace,
  });

  /// The type being deserialized.
  final String? typeName;

  /// The raw data being deserialized.
  final String? rawData;

  @override
  String toString() {
    final buffer = StringBuffer('DeserializationException: $message');
    if (typeName != null) buffer.write('\n  Type: $typeName');
    if (rawData != null) buffer.write('\n  Raw data: $rawData');
    if (cause != null) buffer.write('\n  Caused by: $cause');
    return buffer.toString();
  }
}

/// Exception thrown when ABI type formula parsing fails.
///
/// #### Example
/// ```dart
/// try {
///   final type = parser.parse('variadic<multi<u32,u64>>');
/// } on AbiTypeFormulaParseException catch (e) {
///   print('Invalid formula ${e.formula}: ${e.message}');
/// }
/// ```
class AbiTypeFormulaParseException extends SerializationException {
  /// Creates an ABI type formula parse exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `formula` - Optional formula string being parsed
  const AbiTypeFormulaParseException(
    super.message, {
    this.formula,
    super.cause,
    super.stackTrace,
  });

  /// The formula being parsed.
  final String? formula;

  @override
  String toString() {
    final buffer = StringBuffer('AbiTypeFormulaParseException: $message');
    if (formula != null) buffer.write('\n  Formula: $formula');
    if (cause != null) buffer.write('\n  Caused by: $cause');
    return buffer.toString();
  }
}

/// Exception thrown when input validation fails.
///
/// #### Example
/// ```dart
/// try {
///   validateAmount(amount);
/// } on ValidationException catch (e) {
///   print('Invalid ${e.parameterName}: ${e.message}');
///   print('Value: ${e.invalidValue}, constraint: ${e.constraint}');
/// }
/// ```
class ValidationException extends AbidockException {
  /// Creates a validation exception.
  ///
  /// #### Parameters
  /// - `message` - Error description
  /// - `parameterName` - Name of the invalid parameter
  /// - `invalidValue` - The value that failed validation
  /// - `constraint` - Description of the violated constraint
  const ValidationException(
    super.message, {
    required this.parameterName,
    required this.invalidValue,
    required this.constraint,
    super.cause,
    super.stackTrace,
  });

  /// The parameter name that failed validation.
  final String parameterName;

  /// The invalid value provided.
  final dynamic invalidValue;

  /// The validation constraint that was violated.
  final String constraint;

  @override
  String toString() =>
      'ValidationException: $message '
      '(parameter: $parameterName, value: $invalidValue, constraint: $constraint)';
}
