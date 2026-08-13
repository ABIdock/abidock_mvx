/// Smart contract event querying and streaming functionality.
/// Provides event querying, watching, and real-time streaming via polling.

import 'dart:convert';

import '../../../core/transaction/transaction_event_parser.dart';
import '../../../core/transaction/transaction_on_network.dart';
import '../../../core/transaction/transaction_watcher.dart';
import '../../../infrastructure/logging/logger.dart';
import '../../../infrastructure/network/network_provider.dart';
import '../../../utils/event_deduplicator.dart';
import '../../../utils/helpers.dart';
import '../../../utils/sdk_exceptions.dart';
import '../../abi.dart';

/// Runner for smart contract event operations.
///
/// Provides methods for querying, watching, and streaming events
/// from smart contracts with ABI-based parsing.
///
/// #### Example
/// ```dart
/// final eventRunner = SmartContractEventRunner(
///   contractAddress: SmartContractAddress.fromBech32('erd1qqqqqq...'),
///   networkProvider: apiProvider,
///   abi: SmartContractAbi.fromJson(abiJson),
/// );
///
/// final events = await eventRunner.queryEvents(
///   txHash: txHash,
///   eventIdentifier: 'deposit',
/// );
/// ```
final class SmartContractEventRunner {
  /// Creates event runner with contract address, network provider, and ABI.
  ///
  /// #### Parameters
  /// - `contractAddress` - Target smart contract address
  /// - `networkProvider` - Network provider for API calls
  /// - `abi` - Smart contract ABI for event parsing
  /// - `logger` - Optional logger for debugging
  SmartContractEventRunner({
    required this.contractAddress,
    required NetworkProvider networkProvider,
    required this.abi,
    this.logger,
  }) : _networkProvider = networkProvider,
       _eventParser = TransactionEventParser.withAbi(abi),
       _watcher = TransactionWatcher(networkProvider: networkProvider);

  /// The target smart contract address.
  final SmartContractAddress contractAddress;

  /// The smart contract ABI.
  final SmartContractAbi abi;

  /// Optional logger for debugging.
  final Logger? logger;

  /// Network provider for API calls.
  final NetworkProvider _networkProvider;

  /// Event parser with ABI integration.
  final TransactionEventParser _eventParser;

  /// Transaction watcher for awaiting completion.
  final TransactionWatcher _watcher;

  /// Fetches and parses events from a specific transaction.
  ///
  /// #### Parameters
  /// - `txHash` - Transaction hash to query events from
  /// - `eventIdentifier` - Event name to parse
  ///
  /// #### Returns
  /// `List<ParsedEvent>` - Parsed events with decoded values
  ///
  /// #### Throws
  /// - `NetworkException` - If API request fails
  /// - `EventParsingException` - If event parsing fails
  ///
  /// #### Example
  /// ```dart
  /// final events = await eventRunner.queryEvents(
  ///   txHash: 'abc123...',
  ///   eventIdentifier: 'transfer',
  /// );
  ///
  /// for (final event in events) {
  ///   final from = event.getValueByName('from');
  ///   final to = event.getValueByName('to');
  ///   final amount = event.getValueByName('amount');
  ///   print('Transfer: $from -> $to: $amount');
  /// }
  /// ```
  Future<List<ParsedEvent>> queryEvents({
    required String txHash,
    required String eventIdentifier,
  }) async {
    logger?.debug(
      'Querying events from transaction',
      context: <String, dynamic>{
        'txHash': txHash,
        'eventIdentifier': eventIdentifier,
      },
    );

    try {
      final String resourceUrl =
          '/events?txHash=$txHash&identifier=$eventIdentifier';

      final dynamic responseData = await _networkProvider.doGetGeneric(
        resourceUrl,
      );
      final List<dynamic> eventData = requireAs<List<dynamic>>(
        responseData,
        'response.data',
      );

      final List<ParsedEvent> events = <ParsedEvent>[];
      for (final dynamic eventJson in eventData) {
        try {
          final ParsedEvent event = _eventParser.parseEventFromJson(
            requireAs<Map<String, dynamic>>(eventJson, 'eventJson'),
            eventIdentifier,
          );
          events.add(event);
        } catch (e) {
          logger?.warning(
            'Failed to parse event',
            context: <String, dynamic>{
              'error': e.toString(),
              'txHash': txHash,
              'eventIdentifier': eventIdentifier,
            },
          );
        }
      }

      logger?.debug(
        'Events parsed successfully',
        context: <String, dynamic>{
          'txHash': txHash,
          'eventCount': events.length,
        },
      );

      return events;
    } catch (e, stackTrace) {
      logger?.error(
        'Failed to query events',
        error: e,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'txHash': txHash,
          'eventIdentifier': eventIdentifier,
        },
      );
      rethrow;
    }
  }

  /// Fetches and parses events from multiple transactions in batch.
  ///
  /// #### Parameters
  /// - `txHashes` - List of transaction hashes to query
  /// - `eventIdentifier` - Event name to parse
  ///
  /// #### Returns
  /// `Map<String, List<ParsedEvent>>` - Map of txHash → events
  ///
  /// #### Throws
  /// - `NetworkException` - If API request fails
  ///
  /// #### Example
  /// ```dart
  /// final batchEvents = await eventRunner.queryEventsBatch(
  ///   txHashes: ['abc123...', 'def456...', 'ghi789...'],
  ///   eventIdentifier: 'transfer',
  /// );
  ///
  /// for (final entry in batchEvents.entries) {
  ///   print('Transaction ${entry.key}: ${entry.value.length} events');
  /// }
  /// ```
  Future<Map<String, List<ParsedEvent>>> queryEventsBatch({
    required List<String> txHashes,
    required String eventIdentifier,
  }) async {
    logger?.debug(
      'Querying events from multiple transactions',
      context: <String, dynamic>{
        'txCount': txHashes.length,
        'eventIdentifier': eventIdentifier,
      },
    );

    try {
      final List<Future<MapEntry<String, List<ParsedEvent>>>> futures = txHashes
          .map((String hash) async {
            try {
              final String resourceUrl =
                  '/events?txHash=$hash&identifier=$eventIdentifier';

              final dynamic responseData = await _networkProvider.doGetGeneric(
                resourceUrl,
              );
              final List<dynamic> eventData = requireAs<List<dynamic>>(
                responseData,
                'response.data',
              );

              final List<ParsedEvent> events = <ParsedEvent>[];
              for (final dynamic eventJson in eventData) {
                try {
                  final ParsedEvent event = _eventParser.parseEventFromJson(
                    requireAs<Map<String, dynamic>>(eventJson, 'eventJson'),
                    eventIdentifier,
                  );
                  events.add(event);
                } catch (e) {
                  logger?.warning(
                    'Failed to parse event in batch',
                    context: <String, dynamic>{
                      'error': e.toString(),
                      'txHash': hash,
                    },
                  );
                }
              }

              return MapEntry<String, List<ParsedEvent>>(hash, events);
            } catch (e) {
              logger?.error(
                'Failed to fetch events in batch',
                error: e,
                context: <String, dynamic>{'txHash': hash},
              );
              return MapEntry<String, List<ParsedEvent>>(hash, <ParsedEvent>[]);
            }
          })
          .toList();

      final List<MapEntry<String, List<ParsedEvent>>> results =
          await Future.wait(futures);

      final Map<String, List<ParsedEvent>> result =
          Map<String, List<ParsedEvent>>.fromEntries(results);

      logger?.debug(
        'Batch events parsed successfully',
        context: <String, dynamic>{
          'txCount': txHashes.length,
          'totalEvents': result.values.fold(
            0,
            (int sum, List<ParsedEvent> events) => sum + events.length,
          ),
        },
      );

      return result;
    } catch (e, stackTrace) {
      logger?.error(
        'Failed to query batch events',
        error: e,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'txCount': txHashes.length,
          'eventIdentifier': eventIdentifier,
        },
      );
      rethrow;
    }
  }

  /// Fetches recent events from the contract's transaction history.
  ///
  /// #### Parameters
  /// - `eventIdentifier` - Event name to fetch
  /// - `limit` - Maximum number of events to return (default: 25)
  ///
  /// #### Returns
  /// `List<ParsedEvent>` - Recent parsed events
  ///
  /// #### Throws
  /// - `NetworkException` - If API request fails
  ///
  /// #### Example
  /// ```dart
  /// final recentDeposits = await eventRunner.getEventHistory(
  ///   eventIdentifier: 'deposit',
  ///   limit: 50,
  /// );
  ///
  /// for (final deposit in recentDeposits) {
  ///   print('Deposit: ${deposit.getValueByName('amount')}');
  /// }
  /// ```
  Future<List<ParsedEvent>> getEventHistory({
    required String eventIdentifier,
    int limit = 25,
  }) async {
    logger?.debug(
      'Fetching event history',
      context: <String, dynamic>{
        'contract': contractAddress.bech32,
        'eventIdentifier': eventIdentifier,
        'limit': limit,
      },
    );

    try {
      final String resourceUrl =
          '/events?address=${contractAddress.bech32}&identifier=$eventIdentifier&size=$limit';
      final dynamic responseData = await _networkProvider.doGetGeneric(
        resourceUrl,
      );

      final List<dynamic> eventData = requireAs<List<dynamic>>(
        responseData,
        'response.data',
      );

      final List<ParsedEvent> events = <ParsedEvent>[];
      for (final dynamic eventJson in eventData) {
        try {
          final ParsedEvent event = _eventParser.parseEventFromJson(
            requireAs<Map<String, dynamic>>(eventJson, 'eventJson'),
            eventIdentifier,
          );
          events.add(event);
        } catch (e) {
          logger?.warning(
            'Failed to parse event in history',
            context: <String, dynamic>{'error': e.toString()},
          );
        }
      }

      logger?.debug(
        'Event history fetched',
        context: <String, dynamic>{'totalEvents': events.length},
      );

      return events;
    } catch (e, stackTrace) {
      logger?.error(
        'Failed to fetch event history',
        error: e,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'contract': contractAddress.bech32,
          'eventIdentifier': eventIdentifier,
        },
      );
      rethrow;
    }
  }

  /// Watches a transaction until completion and returns parsed events.
  ///
  /// #### Parameters
  /// - `txHash` - Transaction hash to monitor
  /// - `eventIdentifier` - Event name to parse
  /// - `timeout` - Maximum time to wait (default: 1 minute)
  /// - `pollingInterval` - How often to check status (default: 1 second)
  ///
  /// #### Returns
  /// `List<ParsedEvent>` - Parsed events once transaction completes
  ///
  /// #### Throws
  /// - `TimeoutException` - If transaction doesn't complete in time
  /// - `EventParsingException` - If event parsing fails
  ///
  /// #### Example
  /// ```dart
  /// // Send transaction
  /// final txHash = await provider.sendTransaction(signedTx);
  ///
  /// // Watch for completion and get events
  /// final events = await eventRunner.watchTransaction(
  ///   txHash: txHash,
  ///   eventIdentifier: 'deposit',
  ///   timeout: Duration(minutes: 2),
  /// );
  ///
  /// print('Deposit completed! Events: ${events.length}');
  /// ```
  Future<List<ParsedEvent>> watchTransaction({
    required String txHash,
    required String eventIdentifier,
    Duration timeout = const Duration(minutes: 1),
    Duration pollingInterval = const Duration(seconds: 1),
  }) async {
    logger?.debug(
      'Watching transaction for events',
      context: <String, dynamic>{
        'txHash': txHash,
        'eventIdentifier': eventIdentifier,
        'timeout': timeout.toString(),
      },
    );

    try {
      final TransactionOnNetwork tx = await _watcher.awaitCompleted(
        txHash,
        options: TransactionAwaitingOptions(
          timeout: timeout,
          pollingInterval: pollingInterval,
        ),
      );

      final List<ParsedEvent> events = _eventParser.parseEvents(
        tx,
        eventIdentifier,
      );

      logger?.debug(
        'Transaction completed, events parsed',
        context: <String, dynamic>{
          'txHash': txHash,
          'status': tx.status.status,
          'eventCount': events.length,
        },
      );

      return events;
    } catch (e, stackTrace) {
      logger?.error(
        'Failed to watch transaction for events',
        error: e,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'txHash': txHash,
          'eventIdentifier': eventIdentifier,
        },
      );
      rethrow;
    }
  }

  /// Creates a real-time stream of events by polling the contract.
  ///
  /// #### Parameters
  /// - `eventIdentifier` - Event name to watch for
  /// - `pollingInterval` - How often to check for new events (default: 2 seconds)
  /// - `startFrom` - Optional transaction hash to start from (for resuming)
  ///
  /// #### Returns
  /// `Stream<ParsedEvent>` that emits events as they occur
  ///
  /// #### Example
  /// ```dart
  /// // Subscribe to deposit events
  /// final subscription = eventRunner.streamEvents(
  ///   eventIdentifier: 'deposit',
  /// ).listen(
  ///   (event) {
  ///     final amount = event.getValueByName('amount');
  ///     print('New deposit: $amount');
  ///   },
  ///   onError: (error) => print('Stream error: $error'),
  /// );
  ///
  /// // Later...
  /// await subscription.cancel();
  /// ```
  Stream<ParsedEvent> streamEvents({
    required String eventIdentifier,
    Duration pollingInterval = const Duration(milliseconds: 500),
    String? startFrom,
  }) async* {
    logger?.info(
      'Starting event stream',
      context: <String, dynamic>{
        'contract': contractAddress.bech32,
        'eventIdentifier': eventIdentifier,
        'pollingInterval': pollingInterval.toString(),
      },
    );

    final EventDeduplicator seenTxHashes = EventDeduplicator(
      maxSize: 10000,
      ttl: const Duration(minutes: 10),
    );
    String? lastTxHash = startFrom;
    int totalEventsEmitted = 0;

    final String eventTopicBase64 = base64.encode(utf8.encode(eventIdentifier));

    poll:
    while (true) {
      try {
        final String resourceUrl =
            '/events?address=${contractAddress.bech32}&size=25';

        dynamic responseData;
        int retryCount = 0;
        const int maxRetries = 3;

        while (true) {
          try {
            responseData = await _networkProvider.doGetGeneric(resourceUrl);
            break;
          } catch (e) {
            if (e is NetworkException && e.statusCode == 429) {
              retryCount++;
              if (retryCount > maxRetries) {
                logger?.warning(
                  'Rate limit exceeded after $maxRetries retries, skipping poll',
                );
                await Future<void>.delayed(pollingInterval);
                continue poll;
              }

              final Duration backoff = Duration(seconds: 2 * retryCount);
              logger?.warning(
                'Rate limited (429), retrying after ${backoff.inSeconds}s',
              );
              await Future<void>.delayed(backoff);
            } else {
              rethrow;
            }
          }
        }

        final List<dynamic> eventData = requireAs<List<dynamic>>(
          responseData,
          'response.data',
        );

        for (final dynamic eventJson in eventData) {
          final String txHash = requireAs<String>(
            eventJson['txHash'],
            'txHash',
          );

          if (!seenTxHashes.shouldProcess(txHash)) {
            continue;
          }

          if (lastTxHash != null && txHash == lastTxHash) {
            break;
          }

          final List<dynamic>? topics = optionalAs<List<dynamic>>(
            eventJson['topics'],
            'topics',
          );
          if (topics == null || topics.isEmpty) {
            continue;
          }

          final String firstTopic = requireAs<String>(topics[0], 'topics[0]');
          if (firstTopic != eventTopicBase64) {
            continue;
          }

          try {
            final ParsedEvent event = _eventParser.parseEventFromJson(
              requireAs<Map<String, dynamic>>(eventJson, 'eventJson'),
              eventIdentifier,
            );

            totalEventsEmitted++;

            logger?.info(
              'Event emitted',
              context: <String, dynamic>{
                'eventNumber': totalEventsEmitted,
                'txHash': txHash,
                'eventIdentifier': eventIdentifier,
              },
            );

            yield event;
          } catch (e) {
            logger?.error(
              'Error parsing event in stream',
              error: e,
              context: <String, dynamic>{'txHash': txHash},
            );
          }
        }

        if (eventData.isNotEmpty) {
          lastTxHash = requireAs<String>(eventData.first['txHash'], 'txHash');
        }

        await Future<void>.delayed(pollingInterval);
      } catch (e) {
        logger?.error(
          'Error in event stream',
          error: e,
          context: <String, dynamic>{
            'contract': contractAddress.bech32,
            'eventIdentifier': eventIdentifier,
          },
        );
        yield* Stream<ParsedEvent>.error(e);
      }
    }
  }

  /// Creates a real-time stream of ALL events by polling the contract.
  ///
  /// #### Parameters
  /// - `pollingInterval` - How often to check for new events (default: 2 seconds)
  /// - `startFrom` - Optional transaction hash to start from (for resuming)
  ///
  /// #### Returns
  /// `Stream<ParsedEvent>` that emits events for ALL event types
  ///
  /// #### Example
  /// ```dart
  /// // Subscribe to all events
  /// final subscription = eventRunner.streamAllEvents().listen(
  ///   (event) {
  ///     print('Event: ${event.definition.identifier}');
  ///     if (event.definition.identifier == 'swap') {
  ///       // Handle swap
  ///     } else if (event.definition.identifier == 'addLiquidity') {
  ///       // Handle add liquidity
  ///     }
  ///   },
  /// );
  /// ```
  Stream<ParsedEvent> streamAllEvents({
    Duration pollingInterval = const Duration(milliseconds: 500),
    String? startFrom,
  }) async* {
    logger?.info(
      'Starting all-events stream',
      context: <String, dynamic>{
        'contract': contractAddress.bech32,
        'pollingInterval': pollingInterval.toString(),
      },
    );

    final EventDeduplicator seenTxHashes = EventDeduplicator(
      maxSize: 10000,
      ttl: const Duration(minutes: 10),
    );
    String? lastTxHash = startFrom;
    int totalEventsEmitted = 0;

    final Map<String, String> eventTopicMap = <String, String>{};
    for (final EventDefinition eventDef in abi.events) {
      final String topic = base64.encode(utf8.encode(eventDef.identifier));
      eventTopicMap[topic] = eventDef.identifier;
    }

    poll:
    while (true) {
      try {
        final String resourceUrl =
            '/events?address=${contractAddress.bech32}&size=25';

        dynamic responseData;
        int retryCount = 0;
        const int maxRetries = 3;

        while (true) {
          try {
            responseData = await _networkProvider.doGetGeneric(resourceUrl);
            break;
          } catch (e) {
            if (e is NetworkException && e.statusCode == 429) {
              retryCount++;
              if (retryCount > maxRetries) {
                logger?.warning(
                  'Rate limit exceeded after $maxRetries retries, skipping poll',
                );
                await Future<void>.delayed(pollingInterval);
                continue poll;
              }

              final Duration backoff = Duration(seconds: 2 * retryCount);
              logger?.warning(
                'Rate limited (429), retrying after ${backoff.inSeconds}s',
              );
              await Future<void>.delayed(backoff);
            } else {
              rethrow;
            }
          }
        }

        final List<dynamic> eventData = requireAs<List<dynamic>>(
          responseData,
          'response.data',
        );

        for (final dynamic eventJson in eventData) {
          final String txHash = requireAs<String>(
            eventJson['txHash'],
            'txHash',
          );

          if (!seenTxHashes.shouldProcess(txHash)) {
            continue;
          }

          if (lastTxHash != null && txHash == lastTxHash) {
            break;
          }

          final List<dynamic>? topics = optionalAs<List<dynamic>>(
            eventJson['topics'],
            'topics',
          );
          if (topics == null || topics.isEmpty) {
            continue;
          }

          final String firstTopic = requireAs<String>(topics[0], 'topics[0]');
          final String? matchedIdentifier = eventTopicMap[firstTopic];

          if (matchedIdentifier == null) {
            continue;
          }

          try {
            final ParsedEvent event = _eventParser.parseEventFromJson(
              requireAs<Map<String, dynamic>>(eventJson, 'eventJson'),
              matchedIdentifier,
            );

            totalEventsEmitted++;

            logger?.info(
              'Event emitted',
              context: <String, dynamic>{
                'eventNumber': totalEventsEmitted,
                'txHash': txHash,
                'eventIdentifier': matchedIdentifier,
              },
            );

            yield event;
          } catch (e) {
            logger?.error(
              'Error parsing event in stream',
              error: e,
              context: <String, dynamic>{
                'txHash': txHash,
                'identifier': matchedIdentifier,
              },
            );
          }
        }

        if (eventData.isNotEmpty) {
          lastTxHash = requireAs<String>(eventData.first['txHash'], 'txHash');
        }

        await Future<void>.delayed(pollingInterval);
      } catch (e) {
        logger?.error(
          'Error in all-events stream',
          error: e,
          context: <String, dynamic>{'contract': contractAddress.bech32},
        );
        yield* Stream<ParsedEvent>.error(e);
      }
    }
  }

  /// Gets all event definitions from the ABI.
  ///
  /// #### Returns
  /// List of event definitions
  List<EventDefinition> getAllEventDefinitions() {
    return abi.events.toList();
  }

  /// Gets a specific event definition by identifier.
  ///
  /// #### Parameters
  /// - `eventIdentifier` - Event name
  ///
  /// #### Returns
  /// `EventDefinition?` - Event definition or null if not found
  EventDefinition? getEventDefinition(String eventIdentifier) {
    return abi.events.getByIdentifier(eventIdentifier);
  }

  /// Checks if an event exists in the ABI.
  ///
  /// #### Parameters
  /// - `eventIdentifier` - Event name to check
  ///
  /// #### Returns
  /// `true` if event exists in ABI
  bool hasEvent(String eventIdentifier) {
    return abi.events.getByIdentifier(eventIdentifier) != null;
  }
}
