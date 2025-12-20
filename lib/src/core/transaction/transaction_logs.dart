/// Transaction logs containing events emitted during execution.
import 'package:meta/meta.dart';

import '../../utils/helpers.dart';
import '../address.dart';
import 'transaction_event.dart';

/// Exception for unexpected event count when expecting 0 or 1 events.
class UnexpectedEventCountException implements Exception {
  /// Creates exception with error message and event identifier.
  ///
  /// #### Parameters
  /// - `message` - Description of the error
  /// - `identifier` - Event identifier that was searched
  const UnexpectedEventCountException(this.message, this.identifier);

  /// Error message describing the issue.
  final String message;

  /// Event identifier that caused the exception.
  final String identifier;

  @override
  String toString() =>
      'UnexpectedEventCountException: $message (identifier: $identifier)';
}

/// Logs emitted by a transaction containing all execution events.
/// Provides methods to search, filter, and analyze events including error detection.
///
/// #### Example
/// ```dart
/// // From API response
/// final logs = TransactionLogs.fromHttpResponse(txResponse['logs']);
///
/// // Search for events
/// final transfers = logs.findEvents('transfer');
/// final firstMint = logs.findFirstOrNoneEvent('mint');
///
/// // Check status
/// if (logs.hasErrors) {
///   print('Transaction failed with errors');
/// }
///
/// // Get event info
/// print('Total events: ${logs.events.length}');
/// print('Unique identifiers: ${logs.getEventIdentifiers()}');
/// ```
@immutable
class TransactionLogs {
  /// Creates transaction logs with address and events list.
  ///
  /// #### Parameters
  /// - `address` - Contract/account address that emitted the logs
  /// - `events` - List of all transaction events
  ///
  /// #### Example
  /// ```dart
  /// final logs = TransactionLogs(
  ///   address: contractAddress,
  ///   events: [event1, event2, event3],
  /// );
  /// ```
  const TransactionLogs({required this.address, required this.events});

  /// Creates empty transaction logs with zero address.
  ///
  /// #### Example
  /// ```dart
  /// final emptyLogs = TransactionLogs.empty();
  /// print(emptyLogs.isEmpty); // true
  /// ```
  TransactionLogs.empty()
    : address = Address.zero(),
      events = const <TransactionEvent>[];

  /// Creates transaction logs from API response map.
  ///
  /// #### Parameters
  /// - `response` - API response containing 'address' and 'events' fields
  ///
  /// #### Returns
  /// `TransactionLogs` - Transaction logs parsed from HTTP response
  ///
  /// #### Example
  /// ```dart
  /// final response = {
  ///   'address': 'erd1qqqqqqqqqqqqqpgq...',
  ///   'events': [
  ///     {'identifier': 'transfer', 'topics': [...]},
  ///     {'identifier': 'mint', 'topics': [...]}
  ///   ]
  /// };
  /// final logs = TransactionLogs.fromHttpResponse(response);
  /// ```
  factory TransactionLogs.fromHttpResponse(Map<String, dynamic> response) {
    final String addressStr = requireAs<String>(response['address'], 'address');
    final List<dynamic> eventsList =
        optionalAs<List<dynamic>>(response['events'], 'events') ?? <dynamic>[];

    final List<TransactionEvent> events = eventsList
        .map(
          (eventData) => TransactionEvent.fromHttpResponse(
            requireAs<Map<String, dynamic>>(eventData, 'eventData'),
          ),
        )
        .toList();

    return TransactionLogs(
      address: Address.fromBech32(addressStr),
      events: events,
    );
  }

  /// Address associated with the logs (usually contract address).
  final Address address;

  /// All events emitted during transaction execution.
  final List<TransactionEvent> events;

  /// Finds all events matching the given identifier with optional filtering.
  ///
  /// #### Parameters
  /// - `identifier` - Event identifier to search for (e.g., 'transfer', 'mint')
  /// - `predicate` - Optional filter function for additional filtering
  ///
  /// #### Returns
  /// `List<TransactionEvent>` - List of matching events, empty if none found
  ///
  /// #### Example
  /// ```dart
  /// // Find all transfer events
  /// final transfers = logs.findEvents('transfer');
  ///
  /// // Find transfers with specific topic
  /// final filtered = logs.findEvents(
  ///   'transfer',
  ///   predicate: (event) => event.topics.contains(myAddress.hex),
  /// );
  /// ```
  List<TransactionEvent> findEvents(
    String identifier, {
    bool Function(TransactionEvent)? predicate,
  }) {
    List<TransactionEvent> matchingEvents = events
        .where((TransactionEvent event) => event.identifier == identifier)
        .toList();

    if (predicate != null) {
      matchingEvents = matchingEvents.where(predicate).toList();
    }

    return matchingEvents;
  }

  /// Finds first event matching identifier, returns null if none found.
  ///
  /// #### Parameters
  /// - `identifier` - Event identifier to search for
  /// - `predicate` - Optional filter function
  ///
  /// #### Returns
  /// `TransactionEvent?` - First matching event or null if no matches
  ///
  /// #### Example
  /// ```dart
  /// final deposit = logs.findFirstOrNoneEvent('deposit');
  /// if (deposit != null) {
  ///   print('Found deposit: ${deposit.topics}');
  /// }
  /// ```
  TransactionEvent? findFirstOrNoneEvent(
    String identifier, {
    bool Function(TransactionEvent)? predicate,
  }) {
    final List<TransactionEvent> matchingEvents = findEvents(
      identifier,
      predicate: predicate,
    );

    return matchingEvents.isNotEmpty ? matchingEvents.first : null;
  }

  /// Finds single event matching identifier, returns null if none or throws if multiple.
  ///
  /// #### Parameters
  /// - `identifier` - Event identifier to search for
  /// - `predicate` - Optional filter function
  ///
  /// #### Returns
  /// `TransactionEvent?` - Single matching event or null if no matches
  ///
  /// #### Throws
  /// - `UnexpectedEventCountException` - If more than 1 event matches
  ///
  /// #### Example
  /// ```dart
  /// // Expect 0 or 1 withdraw event
  /// final withdraw = logs.findSingleOrNoneEvent('withdraw');
  ///
  /// // Will throw if multiple withdraws found
  /// try {
  ///   final deposit = logs.findSingleOrNoneEvent('deposit');
  /// } on UnexpectedEventCountException {
  ///   print('Multiple deposits found, expected only one');
  /// }
  /// ```
  TransactionEvent? findSingleOrNoneEvent(
    String identifier, {
    bool Function(TransactionEvent)? predicate,
  }) {
    final List<TransactionEvent> matchingEvents = findEvents(
      identifier,
      predicate: predicate,
    );

    if (matchingEvents.length > 1) {
      throw UnexpectedEventCountException(
        'Expected 0 or 1 event, but found ${matchingEvents.length}',
        identifier,
      );
    }

    return matchingEvents.isNotEmpty ? matchingEvents.first : null;
  }

  /// Checks if any event with the given identifier exists.
  ///
  /// #### Parameters
  /// - `identifier` - Event identifier to check
  ///
  /// #### Returns
  /// `bool` - True if at least one matching event exists
  ///
  /// #### Example
  /// ```dart
  /// if (logs.hasEvent('transfer')) {
  ///   print('Transfer occurred');
  /// }
  /// ```
  bool hasEvent(String identifier) {
    return events.any(
      (TransactionEvent event) => event.identifier == identifier,
    );
  }

  /// Gets set of all unique event identifiers in the logs.
  ///
  /// #### Returns
  /// `Set<String>` - Set of event identifiers
  ///
  /// #### Example
  /// ```dart
  /// final identifiers = logs.getEventIdentifiers();
  /// print('Events: ${identifiers.join(', ')}');
  /// // Events: transfer, mint, writeLog
  /// ```
  Set<String> getEventIdentifiers() {
    return events.map((TransactionEvent event) => event.identifier).toSet();
  }

  /// Checks if transaction had error events (signalError).
  ///
  /// #### Returns
  /// `bool` - True if any 'signalError' events exist
  ///
  /// #### Example
  /// ```dart
  /// if (logs.hasErrors) {
  ///   print('Transaction execution failed');
  ///   for (final error in logs.errorEvents) {
  ///     print('Error: ${error.data}');
  ///   }
  /// }
  /// ```
  bool get hasErrors => hasEvent('signalError');

  /// Gets all error events (signalError).
  ///
  /// #### Returns
  /// `List<TransactionEvent>` - List of error events, empty if no errors
  List<TransactionEvent> get errorEvents => findEvents('signalError');

  /// Checks if logs contain no events.
  bool get isEmpty => events.isEmpty;

  /// Checks if logs contain at least one event.
  bool get isNotEmpty => events.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TransactionLogs) return false;

    if (address != other.address) return false;
    if (events.length != other.events.length) return false;

    for (int i = 0; i < events.length; i++) {
      if (events[i] != other.events[i]) return false;
    }

    return true;
  }

  @override
  int get hashCode => Object.hash(address, Object.hashAll(events));

  @override
  String toString() {
    final String identifiers = getEventIdentifiers().join(', ');
    return 'TransactionLogs('
        'address: ${address.bech32}, '
        'events: ${events.length}, '
        'identifiers: [$identifiers]'
        ')';
  }
}
