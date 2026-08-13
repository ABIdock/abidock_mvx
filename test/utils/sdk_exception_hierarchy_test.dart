import 'dart:io';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

/// Rethrows [error] through a single `on AbidockException` clause.
///
/// Returns the message reported by that clause, or `null` when the error
/// escaped it and was picked up by the untyped fallback.
String? messageFromSingleCatchClause(Object error) {
  try {
    throw error;
  } on AbidockException catch (e) {
    return e.message;
  } catch (_) {
    return null;
  }
}

void main() {
  final Address address = Address.fromBech32(
    'erd1qqqqqqqqqqqqqpgqhe8t5jewej70zupmh44jurgn29psua5l2jps3ntjj3',
  );

  final Map<String, Object> exceptions = <String, Object>{
    'WalletException': const WalletException('boom'),
    'PemException': const PemException('boom'),
    'MnemonicException': const MnemonicException('boom'),
    'SignerException': const SignerException('boom'),
    'DecryptorException': const DecryptorException('boom'),
    'WalletLengthException': const WalletLengthException('boom'),
    'NetworkException': const NetworkException('boom'),
    'AccountAwaiterTimeoutException': const AccountAwaiterTimeoutException(
      'boom',
    ),
    'AccountAwaiterException': const AccountAwaiterException('boom'),
    'TransactionException': const TransactionException('boom'),
    'TransactionCreationException': const TransactionCreationException('boom'),
    'TransactionWatcherTimeoutException':
        const TransactionWatcherTimeoutException('boom'),
    'TransactionWatcherException': const TransactionWatcherException('boom'),
    'EventParsingException': const EventParsingException('boom'),
    'SmartContractException': const SmartContractException('boom'),
    'SerializationException': const SerializationException('boom'),
    'AbiBinaryCodecException': const AbiBinaryCodecException('boom'),
    'AbiNativeSerializationException': const AbiNativeSerializationException(
      'boom',
    ),
    'AbiArgumentSerializationException':
        const AbiArgumentSerializationException('boom'),
    'DeserializationException': const DeserializationException('boom'),
    'AbiTypeFormulaParseException': const AbiTypeFormulaParseException('boom'),
    'ValidationException': const ValidationException(
      'boom',
      parameterName: 'p',
      invalidValue: 1,
      constraint: 'c',
    ),
    'AddressException': const AddressException('boom'),
    'ArgumentEncodingException': const ArgumentEncodingException('boom'),
    'ResponseParsingException': const ResponseParsingException('boom'),
    'EndpointNotFoundException': const EndpointNotFoundException(
      'boom',
      endpointName: 'getTotal',
    ),
    'ArgumentValidationException': const ArgumentValidationException(
      'boom',
      endpointName: 'getTotal',
      expectedCount: 1,
      actualCount: 2,
    ),
    'ResponseValidationException': const ResponseValidationException(
      'boom',
      endpointName: 'getTotal',
      expectedCount: 1,
      actualCount: 2,
    ),
    'GasEstimationException': const GasEstimationException(
      'boom',
      transactionType: 'call',
    ),
    'SmartContractQueryException': const SmartContractQueryException(
      message: 'boom',
      code: 'user error',
    ),
    'UnexpectedEventCountException': const UnexpectedEventCountException(
      'boom',
      'transfer',
    ),
    'DelegationParseException': const DelegationParseException('boom'),
    'GovernanceParseException': const GovernanceParseException('boom'),
    'SmartContractParseException': const SmartContractParseException('boom'),
    'TokenManagementParseException': const TokenManagementParseException(
      'boom',
    ),
    'MultisigParseException': const MultisigParseException('boom'),
    'ValidatorsParseException': const ValidatorsParseException('boom'),
    'CircuitBreakerOpenException': CircuitBreakerOpenException(
      'boom',
      DateTime.utc(2024),
      const Duration(seconds: 30),
    ),
  };

  group('Unified exception hierarchy', () {
    test('every concrete exception type declared in lib/ is covered', () {
      final RegExp declaration = RegExp(
        r'^(?:abstract\s+|final\s+|sealed\s+|base\s+|interface\s+)*'
        r'class\s+(\w+Exception)\b',
        multiLine: true,
      );
      final Set<String> declared = <String>{};
      for (final FileSystemEntity entity in Directory(
        'lib',
      ).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        for (final RegExpMatch match in declaration.allMatches(
          entity.readAsStringSync(),
        )) {
          final String name = match.group(1)!;
          if (!name.startsWith('_') && name != 'AbidockException') {
            declared.add(name);
          }
        }
      }
      expect(declared.difference(exceptions.keys.toSet()), <String>{});
      expect(exceptions.keys.toSet().difference(declared), <String>{});
    });

    for (final MapEntry<String, Object> entry in exceptions.entries) {
      test('${entry.key} is caught by a single on AbidockException clause', () {
        expect(entry.value, isA<AbidockException>());
        expect(entry.value.runtimeType.toString(), entry.key);
        expect(messageFromSingleCatchClause(entry.value), 'boom');
      });
    }

    test('no exception type in lib/ only implements Exception', () {
      final RegExp declaration = RegExp(
        r'^(?:abstract\s+|final\s+|sealed\s+|base\s+|interface\s+|mixin\s+)*'
        r'class\s+(\w+)\s+implements\s+Exception\b',
        multiLine: true,
      );
      final List<String> offenders = <String>[];
      for (final FileSystemEntity entity in Directory(
        'lib',
      ).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        for (final RegExpMatch match in declaration.allMatches(
          entity.readAsStringSync(),
        )) {
          final String name = match.group(1)!;
          if (name != 'AbidockException') {
            offenders.add(name);
          }
        }
      }
      expect(offenders, <String>[]);
    });
  });

  group('Hierarchy placement', () {
    test('query and controller parse failures are SmartContractException', () {
      expect(
        const SmartContractQueryException(message: 'boom', code: 'user error'),
        isA<SmartContractException>(),
      );
      expect(
        const MultisigParseException('boom'),
        isA<SmartContractException>(),
      );
      expect(
        const ValidatorsParseException('boom'),
        isA<SmartContractException>(),
      );
    });

    test('outcome parse failures are TransactionException', () {
      expect(
        const DelegationParseException('boom'),
        isA<TransactionException>(),
      );
      expect(
        const GovernanceParseException('boom'),
        isA<TransactionException>(),
      );
      expect(
        const SmartContractParseException('boom'),
        isA<TransactionException>(),
      );
      expect(
        const TokenManagementParseException('boom'),
        isA<TransactionException>(),
      );
      expect(
        const UnexpectedEventCountException('boom', 'transfer'),
        isA<TransactionException>(),
      );
    });

    test('circuit breaker rejection is not classified as a network error', () {
      final CircuitBreakerOpenException error = CircuitBreakerOpenException(
        'boom',
        DateTime.utc(2024),
        const Duration(seconds: 30),
      );
      expect(error, isA<AbidockException>());
      expect(error, isNot(isA<NetworkException>()));
    });
  });

  group('Constructor shape and message are preserved', () {
    test('SmartContractQueryException keeps named parameters', () {
      const SmartContractQueryException error = SmartContractQueryException(
        message: 'contract panicked',
        code: 'user error',
      );
      expect(error.message, 'contract panicked');
      expect(error.code, 'user error');
      expect(error.response, isNull);
      expect(error.function, isNull);
      expect(
        error.toString(),
        'SmartContractQueryException: contract panicked (code: user error)',
      );
    });

    test('SmartContractQueryException.fromResponse keeps its message', () {
      final SmartContractQueryException error =
          SmartContractQueryException.fromResponse(
            SmartContractQueryResponse.error(
              function: const SmartContractFunction('getTotal'),
              returnCode: 'user error',
              returnMessage: 'insufficient funds',
            ),
          );
      expect(error.message, 'insufficient funds');
      expect(error.code, 'user error');
      expect(
        error.toString(),
        'SmartContractQueryException: insufficient funds (code: user error)',
      );
    });

    test('outcome parse exceptions keep the optional positional cause', () {
      const SmartContractParseException error = SmartContractParseException(
        'Failed to decode return values',
        'FormatException: bad hex',
      );
      expect(error.message, 'Failed to decode return values');
      expect(error.cause, 'FormatException: bad hex');
      expect(
        error.toString(),
        'SmartContractParseException: Failed to decode return values\n'
        'Caused by: FormatException: bad hex',
      );
      expect(
        const DelegationParseException('no contract address').toString(),
        'DelegationParseException: no contract address',
      );
      expect(
        const GovernanceParseException('no proposal event').toString(),
        'GovernanceParseException: no proposal event',
      );
      expect(
        const TokenManagementParseException('no issue event').toString(),
        'TokenManagementParseException: no issue event',
      );
    });

    test('UnexpectedEventCountException keeps identifier and message', () {
      const UnexpectedEventCountException error = UnexpectedEventCountException(
        'found 3 events, expected 0 or 1',
        'transfer',
      );
      expect(error.message, 'found 3 events, expected 0 or 1');
      expect(error.identifier, 'transfer');
      expect(
        error.toString(),
        'UnexpectedEventCountException: found 3 events, expected 0 or 1 '
        '(identifier: transfer)',
      );
    });

    test('CircuitBreakerOpenException keeps its three positional fields', () {
      final DateTime lastFailure = DateTime.now().subtract(
        const Duration(seconds: 100),
      );
      final CircuitBreakerOpenException error = CircuitBreakerOpenException(
        'gateway unavailable',
        lastFailure,
        const Duration(seconds: 30),
      );
      expect(error.message, 'gateway unavailable');
      expect(error.lastFailureTime, lastFailure);
      expect(error.retryDelay, const Duration(seconds: 30));
      expect(
        error.toString(),
        'CircuitBreakerOpenException: gateway unavailable (retry in 0s)',
      );
    });

    test('controller parse exceptions keep a single positional message', () {
      expect(
        const MultisigParseException('no action id').toString(),
        'MultisigParseException: no action id',
      );
      expect(
        const ValidatorsParseException('no stake event').toString(),
        'ValidatorsParseException: no stake event',
      );
    });
  });

  group('QueryResult.values native types', () {
    test('u8/u16/u32/i32 decode to int', () {
      expect(U8Value(7).nativeValue, 7);
      expect(U16Value(7).nativeValue, 7);
      expect(U32Value(7).nativeValue, 7);
      expect(I32Value(-7).nativeValue, -7);
    });

    test('u64 and BigUint decode to BigInt', () {
      expect(U64Value(BigInt.from(7)).nativeValue, BigInt.from(7));
      expect(BigUIntValue(BigInt.from(7)).nativeValue, BigInt.from(7));
    });

    test('Address decodes to a bech32 String, not an Address', () {
      final AddressValue value = AddressValue.fromBech32(address.bech32);
      expect(
        value.nativeValue,
        'erd1qqqqqqqqqqqqqpgqhe8t5jewej70zupmh44jurgn29psua5l2jps3ntjj3',
      );
      expect(value.nativeValue, isA<String>());
      expect(value.nativeValue, isNot(isA<Address>()));
    });

    test('bytes decode to Uint8List', () {
      expect(
        BytesValue(Uint8List.fromList(<int>[1, 2, 3])).nativeValue,
        Uint8List.fromList(<int>[1, 2, 3]),
      );
    });
  });
}
