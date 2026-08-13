/// Transaction event parser with ABI-based decoding support.
/// Parses and decodes transaction events using smart contract ABI definitions.
import 'dart:typed_data';

import '../../abi/abi.dart';
import '../../utils/sdk_exceptions.dart';
import 'transaction_event.dart';
import 'transaction_on_network.dart';

/// Parsed event with raw event data, ABI definition, and decoded typed values.
/// Provides access to event data and decoded parameter values by name.
///
/// #### Example
/// ```dart
/// final parsedEvent = parser.parseSingleEvent(rawEvent, 'transfer');
///
/// // Access by name
/// final sender = parsedEvent.getValueByName('sender');
/// final recipient = parsedEvent.getValueByName('recipient');
/// final amount = parsedEvent.getValueByName('amount');
///
/// // Or as map
/// final allValues = parsedEvent.toMap();
/// for (final entry in allValues.entries) {
///   print('${entry.key}: ${entry.value.nativeValue}');
/// }
/// ```
class ParsedEvent {
  /// Creates parsed event with raw event, ABI definition, and decoded values.
  ///
  /// #### Parameters
  /// - `event` - Raw transaction event from blockchain
  /// - `definition` - ABI event definition with parameter types
  /// - `values` - Decoded typed values in definition order
  const ParsedEvent({
    required this.event,
    required this.definition,
    required this.values,
  });

  /// Raw transaction event from blockchain.
  final TransactionEvent event;

  /// ABI event definition describing parameters and types.
  final EventDefinition definition;

  /// Decoded typed values in order matching definition.inputs.
  final List<TypedValue> values;

  /// Gets decoded value by parameter name, returns null if not found.
  ///
  /// #### Parameters
  /// - `name` - Parameter name from ABI definition
  ///
  /// #### Returns
  /// `TypedValue?` - TypedValue if found, null otherwise
  ///
  /// #### Example
  /// ```dart
  /// final amount = parsedEvent.getValueByName('amount');
  /// if (amount != null) {
  ///   print('Amount: ${amount.nativeValue}');
  /// }
  /// ```
  TypedValue? getValueByName(String name) {
    for (int i = 0; i < definition.inputs.length; i++) {
      if (definition.inputs[i].name == name) {
        return i < values.length ? values[i] : null;
      }
    }
    return null;
  }

  /// Gets all decoded values as map of parameter name → value.
  ///
  /// #### Returns
  /// `Map<String, TypedValue>` - Map with keys as parameter names and values as TypedValue
  ///
  /// #### Example
  /// ```dart
  /// final valueMap = parsedEvent.toMap();
  /// print('Transfer from ${valueMap['from']} to ${valueMap['to']}');
  /// ```
  Map<String, TypedValue> toMap() {
    final Map<String, TypedValue> result = <String, TypedValue>{};
    for (int i = 0; i < definition.inputs.length; i++) {
      if (i < values.length) {
        result[definition.inputs[i].name] = values[i];
      }
    }
    return result;
  }

  @override
  String toString() {
    return 'ParsedEvent(${event.identifier}, ${values.length} values)';
  }
}

/// Event parser with full ABI codec integration for type-safe decoding.
/// Provides strongly-typed values for event parameters.
///
/// #### Example
/// ```dart
/// // Create with ABI
/// final parser = TransactionEventParser.withAbi(myContractAbi);
///
/// // Parse all events of type
/// final deposits = parser.parseEvents(transaction, 'deposit');
/// for (final deposit in deposits) {
///   final user = deposit.getValueByName('user');
///   final amount = deposit.getValueByName('amount');
///   print('User $user deposited $amount');
/// }
///
/// // Parse single event
/// final event = logs.findSingleOrNoneEvent('withdraw');
/// if (event != null) {
///   final parsed = parser.parseSingleEvent(event, 'withdraw');
///   print('Withdrawal: ${parsed.toMap()}');
/// }
/// ```
class TransactionEventParser {
  /// Creates parser without ABI (limited functionality).
  ///
  /// #### Example
  /// ```dart
  /// final parser = TransactionEventParser();
  /// // Can only use non-parsing methods like findEvents, hasEvent
  /// ```
  TransactionEventParser() : abi = null, _argSerializer = ArgSerializer();

  /// Creates parser with ABI support for full event parsing.
  ///
  /// #### Parameters
  /// - `abi` - Smart contract ABI with event definitions
  ///
  /// #### Example
  /// ```dart
  /// final abi = SmartContractAbi.fromJson(abiJsonString);
  /// final parser = TransactionEventParser.withAbi(abi);
  /// ```
  TransactionEventParser.withAbi(this.abi) : _argSerializer = ArgSerializer();

  /// Smart contract ABI containing event definitions.
  final SmartContractAbi? abi;

  /// ArgSerializer for decoding typed event parameters from raw bytes.
  final ArgSerializer _argSerializer;

  /// Parses all events of given type from completed transaction.
  ///
  /// #### Parameters
  /// - `transaction` - Completed transaction with logs
  /// - `eventIdentifier` - Event name/identifier to parse (e.g., 'transfer', 'deposit')
  ///
  /// #### Returns
  /// `List<ParsedEvent>` - List of parsed events with decoded values, empty if no matches
  ///
  /// #### Throws
  /// - EventParsingException - If ABI is null, event not found in ABI, or decoding fails
  ///
  /// #### Example
  /// ```dart
  /// final parser = TransactionEventParser.withAbi(abi);
  /// final transfers = parser.parseEvents(transaction, 'transfer');
  ///
  /// for (final transfer in transfers) {
  ///   final from = transfer.getValueByName('from');
  ///   final to = transfer.getValueByName('to');
  ///   final amount = transfer.getValueByName('amount');
  ///   print('$from sent $amount to $to');
  /// }
  /// ```
  List<ParsedEvent> parseEvents(
    TransactionOnNetwork transaction,
    String eventIdentifier,
  ) {
    if (abi == null) {
      throw const EventParsingException(
        'Cannot parse events without ABI. Use TransactionEventParser.withAbi()',
        eventIdentifier: 'unknown',
      );
    }

    if (transaction.logs == null) {
      return <ParsedEvent>[];
    }

    final EventDefinition? definition = abi!.events.getByIdentifier(
      eventIdentifier,
    );
    if (definition == null) {
      throw EventParsingException(
        'Event definition not found in ABI',
        eventIdentifier: eventIdentifier,
      );
    }

    final List<TransactionEvent> events = transaction.logs!.findEvents(
      eventIdentifier,
    );

    final List<ParsedEvent> parsedEvents = <ParsedEvent>[];
    for (final TransactionEvent event in events) {
      try {
        final ParsedEvent parsed = _parseEvent(event, definition);
        parsedEvents.add(parsed);
      } catch (e) {
        throw EventParsingException(
          'Failed to parse event',
          eventIdentifier: eventIdentifier,
          cause: e,
        );
      }
    }

    return parsedEvents;
  }

  /// Parses single raw event using ABI definition for event type.
  ///
  /// #### Parameters
  /// - `event` - Raw transaction event from logs
  /// - `eventIdentifier` - Event name matching ABI definition
  ///
  /// #### Returns
  /// `ParsedEvent` - Parsed event with decoded typed values
  ///
  /// #### Throws
  /// - EventParsingException - If ABI is null, event definition not found, or decoding fails
  ///
  /// #### Example
  /// ```dart
  /// final rawEvent = logs.findFirstOrNoneEvent('deposit');
  /// if (rawEvent != null) {
  ///   final parsed = parser.parseSingleEvent(rawEvent, 'deposit');
  ///   final amount = parsed.getValueByName('amount');
  ///   print('Deposited: $amount');
  /// }
  /// ```
  ParsedEvent parseSingleEvent(TransactionEvent event, String eventIdentifier) {
    if (abi == null) {
      throw const EventParsingException(
        'Cannot parse events without ABI. Use TransactionEventParser.withAbi()',
        eventIdentifier: 'unknown',
      );
    }

    final EventDefinition? definition = abi!.events.getByIdentifier(
      eventIdentifier,
    );
    if (definition == null) {
      throw EventParsingException(
        'Event definition not found in ABI',
        eventIdentifier: eventIdentifier,
      );
    }

    return _parseEvent(event, definition);
  }

  /// Parses event from JSON response from API `/events` endpoint.
  ///
  /// #### Parameters
  /// - `eventJson` - Event JSON from `/events` endpoint with hex-encoded topics
  /// - `eventIdentifier` - Event name matching ABI definition
  ///
  /// #### Returns
  /// `ParsedEvent` - Parsed event with decoded typed values
  ///
  /// #### Throws
  /// - EventParsingException - If ABI is null, event definition not found, or decoding fails
  ///
  /// #### Example
  /// ```dart
  /// // Fetch the transaction, then take a raw event payload from its logs
  /// final tx = await apiProvider.getTransaction(txHash);
  /// final eventJson = tx.logs!.events.first.raw;
  ///
  /// // Parse with ABI
  /// final parsed = parser.parseEventFromJson(eventJson, 'transfer');
  /// print('Transfer amount: ${parsed.getValueByName('amount')}');
  /// ```
  ParsedEvent parseEventFromJson(
    Map<String, dynamic> eventJson,
    String eventIdentifier,
  ) {
    if (abi == null) {
      throw const EventParsingException(
        'Cannot parse events without ABI. Use TransactionEventParser.withAbi()',
        eventIdentifier: 'unknown',
      );
    }

    final EventDefinition? definition = abi!.events.getByIdentifier(
      eventIdentifier,
    );
    if (definition == null) {
      throw EventParsingException(
        'Event definition not found in ABI',
        eventIdentifier: eventIdentifier,
      );
    }

    final TransactionEvent event = TransactionEvent.fromEventsEndpoint(
      eventJson,
    );

    return _parseEvent(event, definition);
  }

  ParsedEvent _parseEvent(TransactionEvent event, EventDefinition definition) {
    final Map<String, TypedValue> result = <String, TypedValue>{};

    final List<Uint8List> topicsWithoutIdentifier = event.topics
        .skip(1)
        .toList();

    final List<EventTopicDefinition> indexedInputs = definition.inputs
        .where((EventTopicDefinition input) => input.indexed)
        .toList();

    for (int i = 0; i < indexedInputs.length; i++) {
      TypedValue value;

      if (i >= topicsWithoutIdentifier.length ||
          topicsWithoutIdentifier[i].isEmpty) {
        value = _getDefaultValueForType(indexedInputs[i].type);
      } else {
        try {
          value = _argSerializer.codec.decodeTopLevel(
            topicsWithoutIdentifier[i],
            indexedInputs[i].type,
          );
        } catch (e) {
          value = _getDefaultValueForType(indexedInputs[i].type);
        }
      }

      result[indexedInputs[i].name] = value;
    }

    final List<EventTopicDefinition> nonIndexedInputs = definition.inputs
        .where((EventTopicDefinition input) => !input.indexed)
        .toList();

    final List<ParameterDefinition> nonIndexedParams = nonIndexedInputs
        .map(
          (EventTopicDefinition input) =>
              ParameterDefinition(input.type, input.name),
        )
        .toList();
    try {
      final List<Uint8List> dataBuffers = event.additionalData.isNotEmpty
          ? event.additionalData
          : (event.data.isNotEmpty ? <Uint8List>[event.data] : <Uint8List>[]);

      if (dataBuffers.isEmpty && nonIndexedParams.isNotEmpty) {
        throw ArgumentError(
          'Event has ${nonIndexedParams.length} non-indexed parameters but no data provided',
        );
      }

      final List<TypedValue> decodedValues = _argSerializer.buffersToValues(
        dataBuffers,
        nonIndexedParams,
      );

      for (int i = 0; i < nonIndexedInputs.length; i++) {
        if (i < decodedValues.length) {
          result[nonIndexedInputs[i].name] = decodedValues[i];
        }
      }
    } catch (e) {
      throw EventParsingException(
        'Failed to decode non-indexed parameters: $e '
        '(additionalData: ${event.additionalData.length} buffers, '
        'data: ${event.data.length} bytes, '
        'expected: ${nonIndexedInputs.length} params)',
        eventIdentifier: event.identifier,
        cause: e,
      );
    }

    final List<TypedValue> values = definition.inputs
        .map((EventTopicDefinition input) => result[input.name])
        .whereType<TypedValue>()
        .toList();

    return ParsedEvent(event: event, definition: definition, values: values);
  }

  /// Finds all events matching identifier in transaction logs (raw events).
  ///
  /// #### Parameters
  /// - `transaction` - Completed transaction with logs
  /// - `eventIdentifier` - Event name to search for
  ///
  /// #### Returns
  /// `List<TransactionEvent>` - List of raw transaction events, empty if none found
  ///
  /// #### Example
  /// ```dart
  /// final parser = TransactionEventParser();
  /// final transferEvents = parser.findEvents(transaction, 'transfer');
  /// print('Found ${transferEvents.length} transfer events');
  /// ```
  List<TransactionEvent> findEvents(
    TransactionOnNetwork transaction,
    String eventIdentifier,
  ) {
    if (transaction.logs == null) {
      return <TransactionEvent>[];
    }
    return transaction.logs!.findEvents(eventIdentifier);
  }

  /// Checks if transaction has any events of given type.
  ///
  /// #### Parameters
  /// - `transaction` - Completed transaction with logs
  /// - `eventIdentifier` - Event name to check for
  ///
  /// #### Returns
  /// `bool` - True if at least one event found, false otherwise
  ///
  /// #### Example
  /// ```dart
  /// if (parser.hasEvent(transaction, 'signalError')) {
  ///   print('Transaction failed');
  /// }
  /// ```
  bool hasEvent(TransactionOnNetwork transaction, String eventIdentifier) {
    if (transaction.logs == null) {
      return false;
    }
    return transaction.logs!.hasEvent(eventIdentifier);
  }

  /// Gets all unique event identifiers from transaction.
  ///
  /// #### Parameters
  /// - `transaction` - Completed transaction with logs
  ///
  /// #### Returns
  /// `Set<String>` - Set of unique event identifiers, empty if no logs
  ///
  /// #### Example
  /// ```dart
  /// final identifiers = parser.getEventIdentifiers(transaction);
  /// print('Event types: ${identifiers.join(', ')}');
  /// // Might print: "transfer, writeLog, completedTxEvent"
  /// ```
  Set<String> getEventIdentifiers(TransactionOnNetwork transaction) {
    if (transaction.logs == null) {
      return <String>{};
    }
    return transaction.logs!.getEventIdentifiers();
  }

  /// Extracts error messages from signalError events in transaction.
  ///
  /// #### Parameters
  /// - `transaction` - Completed transaction with logs
  ///
  /// #### Returns
  /// `List<String>` - List of error message strings from signalError events, empty if none
  ///
  /// #### Example
  /// ```dart
  /// final errors = parser.getErrorMessages(transaction);
  /// if (errors.isNotEmpty) {
  ///   print('Transaction errors:');
  ///   for (final error in errors) {
  ///     print('  - $error');
  ///   }
  /// }
  /// ```
  List<String> getErrorMessages(TransactionOnNetwork transaction) {
    if (transaction.logs == null) {
      return <String>[];
    }

    final List<TransactionEvent> errorEvents = transaction.logs!.errorEvents;
    return errorEvents
        .map((TransactionEvent event) => event.dataAsString)
        .toList();
  }

  TypedValue _getDefaultValueForType(AbiType type) {
    if (type is U8Type) return U8Value(0);
    if (type is U16Type) return U16Value(0);
    if (type is U32Type) return U32Value(0);
    if (type is U64Type) return U64Value(BigInt.zero);
    if (type is I8Type) return I8Value(0);
    if (type is I16Type) return I16Value(0);
    if (type is I32Type) return I32Value(0);
    if (type is I64Type) return I64Value(BigInt.zero);
    if (type is BigIntType) return BigIntValue(BigInt.zero);
    if (type is BigUIntType) return BigUIntValue(BigInt.zero);
    if (type is AddressType) return AddressValue.zero;
    if (type is BooleanType) return BooleanValue(false);
    if (type is StringType) return StringValue('');
    if (type is TokenIdentifierType) return TokenIdentifierValue('');
    if (type is EgldOrEsdtTokenIdentifierType) {
      return EgldOrEsdtTokenIdentifierValue('');
    }
    if (type is H256Type) return H256Value(Uint8List(32));
    if (type is BytesType) return BytesValue(Uint8List(0));
    if (type is ListType) return ListValue(type, <TypedValue>[]);
    if (type is OptionType) return OptionValue.none(type);
    if (type is EnumType) {
      if (type.variants.isEmpty) {
        throw StateError('EnumType "${type.name}" has no variants defined');
      }
      final firstVariant = type.variants.first;
      return EnumValue(type, firstVariant, const <TypedValue>[]);
    }
    if (type is StructType) {
      final Map<String, dynamic> fieldDefaults = {};
      for (final fieldDef in type.fieldDefinitions) {
        fieldDefaults[fieldDef.name] = _getDefaultValueForType(fieldDef.type)
            .nativeValue;
      }
      return type.createValue(fieldDefaults);
    }
    if (type is ArrayType) {
      final List<TypedValue> elements = List.generate(
        type.length,
        (_) => _getDefaultValueForType(type.elementType),
      );
      return ArrayValue(type, elements);
    }
    return OptionValue.none(OptionType(type));
  }
}
