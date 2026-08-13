---
id: error-handling
title: Error Handling
sidebar_position: 2
description: Handle errors in MultiversX applications using the unified AbidockException hierarchy with typed exceptions.
---

# Error Handling

Properly handle errors in your MultiversX applications using the unified `AbidockException` hierarchy.

## SDK Exception Hierarchy

All SDK exceptions extend `AbidockException`, organized into categories:

```dart
try {
  await provider.sendTransaction(tx);
} on NetworkException catch (e) {
  // Handle network-specific error
  print('Network error: ${e.message}');
  if (e.cause != null) print('Caused by: ${e.cause}');
} on TransactionException catch (e) {
  // Handle transaction-specific error
  print('Transaction error: ${e.message}');
} on AbidockException catch (e) {
  // Catch any SDK exception
  print('SDK error: ${e.message}');
}
```

### Exception Categories

| Category | Base Class | Description | Examples |
|----------|-----------|-------------|----------|
| **Wallet** | `WalletException` | Key management, signing, encryption | `PemException`, `MnemonicException`, `SignerException` |
| **Network** | `NetworkException` | Connection/API errors | Timeout, 404, 503, circuit breaker |
| **Transaction** | `TransactionException` | TX creation, execution errors | `TransactionWatcherTimeoutException`, `EventParsingException` |
| **Smart Contract** | `SmartContractException` | ABI operations, argument/response handling | `ArgumentEncodingException`, `EndpointNotFoundException` |
| **Serialization** | `SerializationException` | Data encoding/decoding | `AbiBinaryCodecException`, `DeserializationException` |
| **Validation** | `ValidationException` | Input validation failures | Gas limit, address format, parameter constraints |

:::caution `SmartContractQueryException` stands apart
A failed *query* throws `SmartContractQueryException`, which implements `Exception` directly rather
than extending `AbidockException`. Neither `on AbidockException` nor `on SmartContractException`
catches it -- always give it its own `on` clause.
:::

## Network Errors

```dart
import 'dart:async';
import 'package:abidock_mvx/abidock_mvx.dart';

Future<void> getAccountSafe(Address address) async {
  final provider = GatewayNetworkProvider.devnet();
  
  try {
    final account = await provider.getAccount(address);
    print('Balance: ${account.balance}');
  } on TimeoutException catch (e) {
    print('Request timed out: $e');
    // Retry with exponential backoff
  } on NetworkException catch (e) {
    print('Network error: ${e.message}');
    print('Status code: ${e.statusCode}');
    // Check for 404 / account not found
    if (e.statusCode == 404) {
      print('Account not found (may never have received tokens)');
    }
  } catch (e) {
    print('Unexpected error: $e');
    rethrow;
  }
}
```

## Retry Pattern

```dart
/// Retry with exponential backoff
Future<T> retry<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(seconds: 1),
}) async {
  var delay = initialDelay;
  
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (e) {
      if (attempt == maxAttempts) rethrow;
      
      print('Attempt $attempt failed: $e');
      print('Retrying in ${delay.inSeconds}s...');
      
      await Future.delayed(delay);
      delay *= 2; // Exponential backoff
    }
  }
  
  throw StateError('Should not reach here');
}

// Usage
final account = await retry(
  () => provider.getAccount(address),
  maxAttempts: 5,
);
```

## Transaction Validation

### Before Sending

```dart
Future<String> sendTransactionSafe(
  GatewayNetworkProvider provider,
  Transaction tx,
  UserSigner signer,
) async {
  // Validate before signing
  if (tx.gasLimit < GasLimit(50000)) {
    throw ValidationException(
      'Gas limit too low',
      parameterName: 'gasLimit',
      invalidValue: tx.gasLimit.value,
      constraint: 'must be >= 50000',
    );
  }
  
  if (tx.value.value < BigInt.zero) {
    throw ValidationException(
      'Value cannot be negative',
      parameterName: 'value',
      invalidValue: tx.value.value,
      constraint: 'must be >= 0',
    );
  }
  
  // Check balance (manual validation)
  final account = await provider.getAccount(tx.sender);
  final requiredBalance = tx.value.value + 
    tx.gasLimit.toBigInt * tx.gasPrice.toBigInt;
  
  if (account.balance.value < requiredBalance) {
    // No built-in exception - manual check
    throw ValidationException(
      'Insufficient balance',
      parameterName: 'balance',
      invalidValue: account.balance.value,
      constraint: 'required: $requiredBalance',
    );
  }
  
  // Check nonce (manual validation)
  if (tx.nonce != account.nonce) {
    throw ValidationException(
      'Nonce mismatch',
      parameterName: 'nonce',
      invalidValue: tx.nonce.value,
      constraint: 'expected: ${account.nonce.value}',
    );
  }
  
  // Sign and send
  final signature = await signer.sign(tx.serializeForSigning());
  final signed = tx.copyWith(newSignature: Signature.fromUint8List(signature));
  return await provider.sendTransaction(signed);
}
```

### After Sending

```dart
Future<void> waitAndHandleResult(
  TransactionWatcher watcher,
  String hash,
) async {
  try {
    final tx = await watcher.awaitCompleted(hash);
    
    // Check transaction status
    if (tx.hasFailed) {
      final reason = parseFailureReason(tx);
      print('Transaction failed: $reason');
      
      if (reason.contains('out of gas')) {
        print('Suggestion: Increase gas limit');
      } else if (reason.contains('user error')) {
        print('Suggestion: Check contract requirements');
      }
      return;
    }
    
    print('Transaction successful!');
    
  } on TransactionWatcherTimeoutException {
    print('Transaction timeout - may still be processing');
    // Could be in mempool, check later
  } on TransactionException catch (e) {
    print('Transaction error: ${e.message}');
  }
}

String parseFailureReason(TransactionOnNetwork tx) {
  // The gas-refund receipt carries the node's own message, when present.
  final Map<String, dynamic>? receipt = tx.executionReceipt;
  final Object? receiptData = receipt?['data'];
  if (receiptData is String && receiptData.isNotEmpty) {
    return receiptData;
  }

  // Smart contract results carry the return code and message.
  for (final SmartContractResult scr
      in tx.smartContractResults ?? const <SmartContractResult>[]) {
    if (scr.errorMessage != null && scr.errorMessage!.isNotEmpty) {
      return scr.errorMessage!;
    }
    if (scr.returnCode.isError) {
      return scr.returnCode.message; // ReturnCode, not a raw String
    }
  }

  // Failure events (signalError) are in the logs.
  for (final TransactionEvent event in tx.logs?.events ?? const <TransactionEvent>[]) {
    if (event.identifier == 'signalError') {
      return event.dataAsString;
    }
  }

  return 'Unknown failure';
}
```

## Smart Contract Errors

```dart
/// Common contract error codes
class ContractErrors {
  static const outOfGas = 'out of gas';
  static const userError = 'user error';
  static const executionFailed = 'execution failed';
  static const actionNotAllowed = 'action is not allowed';
  static const insufficientFunds = 'insufficient funds';
  
  static String decode(String hexError) {
    String hex = hexError;
    if (hex.startsWith('@')) {
      hex = hex.substring(1);
    }

    try {
      final bytes = HexUtils.hexToBytes(hex);
      return String.fromCharCodes(bytes);
    } catch (e) {
      return hex;
    }
  }
}

// Handle contract query errors
Future<List<dynamic>> queryContract(
  SmartContractController controller,
  String endpointName,
  List<dynamic> args,
) async {
  try {
    final QueryResult result = await controller.query(
      endpointName: endpointName,
      arguments: args,
    );
    return result.values; // native Dart values
  } on SmartContractQueryException catch (e) {
    // `code` is the contract's return code; `message` its return message.
    print('Contract query failed: ${e.code} - ${e.message}');

    // Handle specific error patterns
    final String reason = e.message.toLowerCase();
    if (reason.contains('not active') || reason.contains('paused')) {
      print('Contract is paused or inactive');
    } else if (reason.contains('not whitelisted')) {
      print('Address not whitelisted');
    }

    rethrow;
  }
}
```

## Wallet Errors

```dart
import 'dart:convert';

Future<UserSecretKey> loadAccountSafe(String source, {String? password}) async {
  try {
    // Try mnemonic
    if (source.contains(' ')) {
      final mnemonic = Mnemonic.fromString(source);
      return await mnemonic.deriveKey(addressIndex: 0);
    }
    
    // Try PEM content
    if (source.contains('-----BEGIN')) {
      return UserSecretKey.fromPem(source);
    }
    
    // Try keystore JSON (requires password)
    if (source.startsWith('{') && password != null) {
      final keyFile = jsonDecode(source) as Map<String, dynamic>;
      return await UserWallet.decrypt(keyFile, password);
    }
    
    // Unknown format
    throw ArgumentError('Unknown account format: expected mnemonic, PEM, or keystore JSON');
    
  } on MnemonicException catch (e) {
    print('Invalid mnemonic: ${e.message}');
    print('Check for typos or missing words');
    rethrow;
    
  } on PemException catch (e) {
    print('Invalid PEM format: ${e.message}');
    rethrow;
    
  } on DecryptorException catch (e) {
    print('Decryption failed: ${e.message}');
    print('Check password or keystore integrity');
    rethrow;
  }
}
```

## Available Exception Classes

Every class below extends `AbidockException` -- with optional `cause` and `stackTrace` --
**except `SmartContractQueryException`**, which implements `Exception` directly and exposes
`message`, `code` and the original `response`.

### Wallet Exceptions
- `WalletException` - Base for all wallet errors
- `PemException` - PEM parsing/encoding errors
- `MnemonicException` - Mnemonic validation/derivation errors
- `SignerException` - Signing operation failures
- `DecryptorException` - Keystore decryption failures
- `WalletLengthException` - Invalid key/seed length

### Network Exceptions
- `NetworkException` - HTTP/API communication errors (includes `statusCode`)
- `AccountAwaiterTimeoutException` - Account state polling timeout
- `AccountAwaiterException` - Account polling failures

### Transaction Exceptions
- `TransactionException` - Base for transaction errors
- `TransactionCreationException` - Transaction building failures
- `TransactionWatcherTimeoutException` - Transaction completion timeout
- `TransactionWatcherException` - Transaction monitoring failures
- `EventParsingException` - Event extraction/parsing errors

### Smart Contract Exceptions
- `SmartContractException` - Base for contract operations
- `SmartContractQueryException` - Contract query failures (includes `code` and `response`; **not** an `AbidockException`)
- `ArgumentEncodingException` - Function argument encoding errors
- `ResponseParsingException` - Response deserialization errors
- `EndpointNotFoundException` - Unknown contract endpoint
- `ArgumentValidationException` - Invalid argument values
- `ResponseValidationException` - Unexpected response structure
- `GasEstimationException` - Gas simulation failures

### Serialization Exceptions
- `SerializationException` - Base for encoding/decoding
- `AbiBinaryCodecException` - ABI binary codec errors (includes `typeName`, `value`)
- `AbiNativeSerializationException` - Native serialization failures
- `AbiArgumentSerializationException` - Argument serialization errors (includes `argumentIndex`)
- `DeserializationException` - Data deserialization failures
- `AbiTypeFormulaParseException` - Type formula parsing errors

### Validation Exception
- `ValidationException` - Input validation failures
  - **Required parameters**: `parameterName`, `invalidValue`, `constraint`
  - Use for pre-flight validation checks

## Complete Error Handling Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

class SafeTransactionService {
  final GatewayNetworkProvider provider;
  final TransactionWatcher watcher;
  
  SafeTransactionService(this.provider)
      : watcher = TransactionWatcher(networkProvider: provider);
  
  Future<TransactionResult> sendEgld({
    required Account account,
    required Address recipient,
    required BigInt amount,
    String? message,
  }) async {
    try {
      // 1. Get fresh account state
      final networkAccount = await retry(
        () => provider.getAccount(account.address),
      );
      
      // 2. Calculate gas
      final dataLength = message?.length ?? 0;
      final config = await provider.getNetworkConfig();
      final gasLimit = config.minGasLimit + (dataLength * config.gasPerDataByte);
      final gasCost = BigInt.from(gasLimit) * BigInt.from(config.minGasPrice);
      
      // 3. Validate balance (manual check - no built-in exception)
      final totalRequired = amount + gasCost;
      if (networkAccount.balance.value < totalRequired) {
        return TransactionResult.error(
          'Insufficient balance. Need $totalRequired, have ${networkAccount.balance.value}',
        );
      }
      
      // 4. Build transaction
      final tx = Transaction(
        sender: account.address,
        receiver: recipient,
        value: Balance(amount),
        nonce: networkAccount.nonce,
        gasLimit: GasLimit(gasLimit),
        gasPrice: GasPrice(config.minGasPrice),
        chainId: ChainId(config.chainId),
        version: const TransactionVersion(2),
        data: message != null ? Uint8List.fromList(utf8.encode(message)) : Uint8List(0),
      );
      
      // 5. Sign and send
      final signature = await account.signTransaction(tx);
      final signed = tx.copyWith(newSignature: Signature.fromUint8List(signature));
      final hash = await provider.sendTransaction(signed);
      
      // 6. Wait for result
      final result = await watcher.awaitCompleted(hash);
      
      if (result.isSuccessful) {
        return TransactionResult.success(hash);
      } else {
        return TransactionResult.failed(
          hash,
          parseFailureReason(result),
        );
      }
      
    } on NetworkException catch (e) {
      return TransactionResult.error('Network error: ${e.message}');
    } on TransactionWatcherTimeoutException catch (e) {
      return TransactionResult.error('Timeout: $e');
    } catch (e) {
      return TransactionResult.error('Unexpected error: $e');
    }
  }
}

class TransactionResult {
  final bool isSuccess;
  final String? hash;
  final String? error;
  
  TransactionResult._({
    required this.isSuccess,
    this.hash,
    this.error,
  });
  
  factory TransactionResult.success(String hash) =>
      TransactionResult._(isSuccess: true, hash: hash);
  
  factory TransactionResult.failed(String hash, String reason) =>
      TransactionResult._(isSuccess: false, hash: hash, error: reason);
  
  factory TransactionResult.error(String error) =>
      TransactionResult._(isSuccess: false, error: error);
}
```

## Next Steps

- [Best Practices](/docs/advanced/best-practices) - Production tips
- [Custom Serialization](/docs/advanced/custom-serialization) - Extend types
- [Transaction Tracking](/docs/transactions/transaction-tracking) - Monitor status
