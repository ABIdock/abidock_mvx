/// Parser for smart contract transaction outcomes.
/// Extracts structured results from contract deployment and execution with ABI-based type decoding.
import 'dart:typed_data';

import '../../../abi/abi.dart';
import '../../../utils/sdk_exceptions.dart';
import '../../address.dart';
import '../smart_contract_result.dart';
import '../transaction_event.dart';
import '../transaction_on_network.dart';

/// Exception for smart contract parsing failures.
/// Thrown when outcomes cannot be parsed due to missing data, invalid ABI, or unexpected structure.
/// Part of the unified SDK hierarchy: catch it as [TransactionException] or as
/// [AbidockException].
class SmartContractParseException extends TransactionException {
  /// Creates smart contract parse exception.
  const SmartContractParseException(super.message, [Object? cause])
    : super(cause: cause);

  @override
  String toString() {
    if (cause != null) {
      return 'SmartContractParseException: $message\nCaused by: $cause';
    }
    return 'SmartContractParseException: $message';
  }
}

/// Result of smart contract deployment.
/// Contains deployment status and list of deployed contracts with addresses, owners, and code hashes.
class SmartContractDeployOutcome {
  /// Creates smart contract deploy outcome.
  const SmartContractDeployOutcome({
    required this.returnCode,
    required this.returnMessage,
    required this.contracts,
  });

  final String returnCode;
  final String returnMessage;
  final List<DeployedContract> contracts;

  @override
  String toString() =>
      'SmartContractDeployOutcome(returnCode: $returnCode, contracts: ${contracts.length})';
}

/// Information about deployed contract.
/// Contains contract address, owner address, and code hash from SCDeploy event.
class DeployedContract {
  /// Creates deployed contract info.
  const DeployedContract({
    required this.address,
    required this.ownerAddress,
    required this.codeHash,
  });

  final Address address;
  final Address ownerAddress;
  final Uint8List codeHash;

  @override
  String toString() =>
      'DeployedContract(address: ${address.bech32}, owner: ${ownerAddress.bech32})';
}

/// Result of smart contract execution.
/// Contains execution status and decoded return values based on ABI or raw buffers.
class ParsedSmartContractCallOutcome {
  /// Creates parsed smart contract call outcome.
  const ParsedSmartContractCallOutcome({
    required this.returnCode,
    required this.returnMessage,
    required this.values,
  });

  final String returnCode;
  final String returnMessage;
  final List<dynamic> values;

  @override
  String toString() =>
      'ParsedSmartContractCallOutcome(returnCode: $returnCode, values: ${values.length})';
}

/// Internal result of smart contract call.
class _SmartContractCallOutcome {
  const _SmartContractCallOutcome({
    required this.returnCode,
    required this.returnMessage,
    required this.returnDataParts,
  });

  final String returnCode;
  final String returnMessage;
  final List<Uint8List> returnDataParts;
}

/// Parser for smart contract transaction outcomes.
/// Extracts and decodes results from transaction logs with optional ABI support.
class SmartContractOutcomeParser {
  /// Creates smart contract outcome parser.
  ///
  /// #### Parameters
  /// - `abi` - Optional ABI for type-safe decoding
  const SmartContractOutcomeParser({this.abi});

  final SmartContractAbi? abi;

  /// Parses deployment outcome from transaction.
  /// Extracts deployment results from SCDeploy events with addresses, owners, and code hashes.
  ///
  /// #### Parameters
  /// - `transaction` - Completed transaction from network
  ///
  /// #### Returns
  /// `SmartContractDeployOutcome` - Deployment results
  SmartContractDeployOutcome parseDeploy(TransactionOnNetwork transaction) {
    if (transaction.logs == null) {
      return const SmartContractDeployOutcome(
        returnCode: '',
        returnMessage: '',
        contracts: <DeployedContract>[],
      );
    }

    final List<TransactionEvent> scDeployEvents = transaction.logs!.findEvents(
      'SCDeploy',
    );
    final List<DeployedContract> contracts = scDeployEvents
        .map(_parseScDeployEvent)
        .toList();

    String returnCode = 'ok';
    String returnMessage = '';

    final List<TransactionEvent> errorEvents = transaction.logs!.errorEvents;
    if (errorEvents.isNotEmpty) {
      final TransactionEvent error = errorEvents.first;
      final List<Uint8List> topics = error.topics;
      returnCode = topics.isNotEmpty
          ? String.fromCharCodes(topics.last)
          : 'error';
      returnMessage = returnCode;
    }

    return SmartContractDeployOutcome(
      returnCode: returnCode,
      returnMessage: returnMessage,
      contracts: contracts,
    );
  }

  /// Parses execution outcome from transaction.
  /// Extracts return values with ABI-based decoding if available, otherwise raw buffers.
  ///
  /// #### Parameters
  /// - `transaction` - Completed transaction from network
  /// - `function` - Optional function name for ABI decoding
  ///
  /// #### Returns
  /// `ParsedSmartContractCallOutcome` - Decoded values or raw buffers
  ParsedSmartContractCallOutcome parseExecute(
    TransactionOnNetwork transaction, {
    String? function,
  }) {
    final _SmartContractCallOutcome directCallOutcome =
        _findDirectSmartContractCallOutcome(transaction);

    final String? functionName = function ?? transaction.function;

    if (abi == null || functionName == null || functionName.isEmpty) {
      return ParsedSmartContractCallOutcome(
        returnCode: directCallOutcome.returnCode,
        returnMessage: directCallOutcome.returnMessage,
        values: directCallOutcome.returnDataParts,
      );
    }

    try {
      final AbiEndpoint? endpoint = abi!.endpoints.getByName(functionName);
      if (endpoint == null) {
        throw SmartContractParseException(
          'Endpoint "$functionName" not found in ABI',
        );
      }

      final ArgSerializer argSerializer = ArgSerializer();

      final List<ParameterDefinition> parameters = endpoint.outputs
          .map(
            (AbiParameter param) => ParameterDefinition(param.type, param.name),
          )
          .toList();
      final List<TypedValue> values = argSerializer.buffersToValues(
        directCallOutcome.returnDataParts,
        parameters,
      );

      return ParsedSmartContractCallOutcome(
        returnCode: directCallOutcome.returnCode,
        returnMessage: directCallOutcome.returnMessage,
        values: values.map((TypedValue value) => value.valueOf()).toList(),
      );
    } catch (e) {
      throw SmartContractParseException(
        'Failed to decode return values for function "$functionName"',
        e,
      );
    }
  }

  DeployedContract _parseScDeployEvent(TransactionEvent event) {
    final Uint8List topicForAddress =
        event.topics.isNotEmpty && event.topics[0].isNotEmpty
        ? event.topics[0]
        : Uint8List(0);
    final Uint8List topicForOwnerAddress =
        event.topics.length > 1 && event.topics[1].isNotEmpty
        ? event.topics[1]
        : Uint8List(0);
    final Uint8List topicForCodeHash =
        event.topics.length > 2 && event.topics[2].isNotEmpty
        ? event.topics[2]
        : Uint8List(0);

    final Address address = topicForAddress.isNotEmpty
        ? Address(topicForAddress)
        : Address.zero();
    final Address ownerAddress = topicForOwnerAddress.isNotEmpty
        ? Address(topicForOwnerAddress)
        : Address.zero();
    final Uint8List codeHash = topicForCodeHash;

    return DeployedContract(
      address: address,
      ownerAddress: ownerAddress,
      codeHash: codeHash,
    );
  }

  _SmartContractCallOutcome _findDirectSmartContractCallOutcome(
    TransactionOnNetwork transaction,
  ) {
    _SmartContractCallOutcome? outcome =
        _findDirectSmartContractCallOutcomeWithinSmartContractResults(
          transaction,
        );
    if (outcome != null) return outcome;

    outcome = _findDirectSmartContractCallOutcomeIfError(transaction);
    if (outcome != null) return outcome;

    outcome = _findDirectSmartContractCallOutcomeWithinWriteLogEvents(
      transaction,
    );
    if (outcome != null) return outcome;

    return const _SmartContractCallOutcome(
      returnCode: '',
      returnMessage: '',
      returnDataParts: <Uint8List>[],
    );
  }

  _SmartContractCallOutcome?
  _findDirectSmartContractCallOutcomeWithinSmartContractResults(
    TransactionOnNetwork transaction,
  ) {
    final List<SmartContractResult>? results = transaction.smartContractResults;
    if (results == null) return null;

    final List<SmartContractResult> eligibleResults = <SmartContractResult>[
      for (final SmartContractResult scr in results)
        if (scr.returnCode.isSuccess &&
            (scr.returnData.isNotEmpty ||
                (scr.raw['data'] as String?)?.startsWith('@') == true))
          scr,
    ];

    if (eligibleResults.isEmpty) return null;

    final SmartContractResult result = eligibleResults.length == 1
        ? eligibleResults.first
        : eligibleResults.firstWhere(
            (SmartContractResult scr) => scr.receiver == transaction.sender,
            orElse: () => eligibleResults.first,
          );
    final String returnCode = result.returnCode.code;
    return _SmartContractCallOutcome(
      returnCode: returnCode,
      returnMessage: result.errorMessage ?? returnCode,
      returnDataParts: List<Uint8List>.of(result.returnData),
    );
  }

  _SmartContractCallOutcome? _findDirectSmartContractCallOutcomeIfError(
    TransactionOnNetwork transaction,
  ) {
    if (transaction.logs == null) return null;

    final List<TransactionEvent> eligibleEvents = <TransactionEvent>[];

    eligibleEvents.addAll(transaction.logs!.findEvents('signalError'));

    if (eligibleEvents.isEmpty) return null;

    final TransactionEvent event = eligibleEvents.first;
    final ArgSerializer argSerializer = ArgSerializer();
    final String data = event.dataAsString;
    final String lastTopic = event.topics.isNotEmpty
        ? String.fromCharCodes(event.topics.last)
        : '';

    final List<Uint8List> parts = argSerializer.stringToBuffers(data);
    final String returnCode = parts.isNotEmpty
        ? String.fromCharCodes(parts.last)
        : 'signalError';

    return _SmartContractCallOutcome(
      returnCode: returnCode.isEmpty ? 'signalError' : returnCode,
      returnMessage: lastTopic.isEmpty ? returnCode : lastTopic,
      returnDataParts: const <Uint8List>[],
    );
  }

  _SmartContractCallOutcome?
  _findDirectSmartContractCallOutcomeWithinWriteLogEvents(
    TransactionOnNetwork transaction,
  ) {
    if (transaction.logs == null) return null;

    final List<TransactionEvent> eligibleEvents = <TransactionEvent>[];

    eligibleEvents.addAll(transaction.logs!.findEvents('writeLog'));

    if (eligibleEvents.isEmpty) return null;

    final TransactionEvent event = eligibleEvents.last;
    final ArgSerializer argSerializer = ArgSerializer();
    final String data = event.dataAsString;
    final List<Uint8List> buffers = argSerializer.stringToBuffers(data);

    if (buffers.isEmpty) {
      return const _SmartContractCallOutcome(
        returnCode: '',
        returnMessage: '',
        returnDataParts: <Uint8List>[],
      );
    }

    final String returnCode = buffers.length > 1
        ? String.fromCharCodes(buffers[1])
        : '';
    final List<Uint8List> returnDataParts = buffers.length > 2
        ? buffers.skip(2).cast<Uint8List>().toList()
        : <Uint8List>[];

    return _SmartContractCallOutcome(
      returnCode: returnCode,
      returnMessage: returnCode,
      returnDataParts: returnDataParts,
    );
  }
}
