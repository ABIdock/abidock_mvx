/// Parser for delegation transaction outcomes.
/// Extracts structured results from delegation logs including contract creation and error detection.
import 'dart:typed_data';

import '../../../utils/sdk_exceptions.dart';
import '../../address.dart';
import '../transaction_event.dart';
import '../transaction_logs.dart';
import '../transaction_on_network.dart';

/// Exception for delegation parsing failures.
/// Thrown when outcomes cannot be parsed due to missing data, unexpected format, or transaction errors.
/// Part of the unified SDK hierarchy: catch it as [TransactionException] or as
/// [AbidockException].
class DelegationParseException extends TransactionException {
  /// Creates delegation parse exception.
  const DelegationParseException(super.message, [Object? cause])
    : super(cause: cause);

  @override
  String toString() {
    if (cause != null) {
      return 'DelegationParseException: $message\nCaused by: $cause';
    }
    return 'DelegationParseException: $message';
  }
}

/// Result of creating delegation contract.
/// Contains the address of the newly deployed delegation smart contract.
class CreateDelegationContractResult {
  /// Creates create delegation contract result.
  const CreateDelegationContractResult({required this.contractAddress});

  final String contractAddress;

  @override
  String toString() =>
      'CreateDelegationContractResult(contractAddress: $contractAddress)';
}

/// Parser for delegation transaction outcomes.
/// Extracts structured results from delegation transactions by analyzing logs and events.
class DelegationOutcomeParser {
  /// Creates delegation outcome parser.
  const DelegationOutcomeParser();

  /// Parses result of creating new delegation contract.
  /// Extracts contract address from SCDeploy events in transaction logs.
  ///
  /// #### Parameters
  /// - `transaction` - Completed transaction from network
  ///
  /// #### Returns
  /// `List<CreateDelegationContractResult>` - Contract creation results
  ///
  /// #### Throws
  /// - `DelegationParseException` - If transaction contains signalError event
  List<CreateDelegationContractResult> parseCreateNewDelegationContract(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoError(transaction.logs);

    final List<TransactionEvent> events = _findEventsByIdentifier(
      transaction,
      'SCDeploy',
    );

    return events.map((TransactionEvent event) {
      return CreateDelegationContractResult(
        contractAddress: _extractContractAddress(event),
      );
    }).toList();
  }

  void _ensureNoError(TransactionLogs? logs) {
    if (logs == null) return;

    for (final TransactionEvent event in logs.events) {
      if (event.identifier == 'signalError') {
        final String data = event.additionalData.isNotEmpty
            ? String.fromCharCodes(event.additionalData[0].skip(1))
            : '';
        final String message = event.topics.length > 1
            ? _decodeTopicAsString(event.topics[1])
            : '';

        throw DelegationParseException(
          'encountered signalError: $message ($data)',
        );
      }
    }
  }

  List<TransactionEvent> _findEventsByIdentifier(
    TransactionOnNetwork transaction,
    String identifier,
  ) {
    final List<TransactionEvent> events = <TransactionEvent>[];
    if (transaction.logs != null) {
      events.addAll(transaction.logs!.findEvents(identifier));
    }

    return events;
  }

  String _extractContractAddress(TransactionEvent event) {
    if (event.topics.isEmpty || event.topics[0].isEmpty) {
      return '';
    }
    final Address address = Address(event.topics[0]);
    return address.bech32;
  }

  String _decodeTopicAsString(Uint8List topic) {
    return String.fromCharCodes(topic);
  }
}
