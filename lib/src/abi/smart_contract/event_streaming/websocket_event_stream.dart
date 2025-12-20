/// Real-time WebSocket streaming client for MultiversX smart contract events.
/// Supports automatic reconnection, event parsing with ABI, and error handling.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/address.dart';
import '../../../core/transaction/transaction_event.dart';
import '../../../core/transaction/transaction_event_parser.dart';
import '../../../infrastructure/logging/logger.dart';
import '../../../utils/event_deduplicator.dart';
import '../../../utils/helpers.dart';
import '../../../utils/sdk_exceptions.dart';
import '../../abi.dart';

/// Status of the WebSocket connection.
///
/// Track connection lifecycle in status change stream.
enum WebSocketStatus {
  /// Not yet connected
  idle,

  /// Connection in progress
  connecting,

  /// Successfully connected to WebSocket
  connected,

  /// Subscribed and listening for events
  listening,

  /// Temporarily paused
  paused,

  /// Disconnected from WebSocket
  disconnected,

  /// Error state
  error,
}

/// Type of events to receive from MultiversX WebSocket notifier.
///
/// #### Example
/// ```dart
/// eventType: WebSocketEventType.allEvents,
/// ```
enum WebSocketEventType {
  /// Receive events from all transaction lifecycle stages.
  ///
  /// The MultiversX notifier sends events at multiple stages:
  /// - When transaction is pending (accepted to mempool)
  /// - When transaction is executed (processed by validators)
  /// - When transaction is finalized (block is confirmed)
  ///
  /// Note: You may receive the same transaction multiple times.
  allEvents,

  /// Subscribe only to specific event identifiers (server-side filtering).
  ///
  /// This is the cleanest approach - no deduplication needed, no client-side
  /// filtering. Just specify the event identifiers you want to receive.
  ///
  /// Example subscription payload:
  /// ```json
  /// { "subscriptionEntries": [{ "identifier": "swap" }] }
  /// ```
  byIdentifier,
}

/// Configuration for WebSocket event streaming with connection options.
///
/// Configure WebSocket connection, filtering, and behavior.
///
/// #### Example (Recommended - Subscribe by identifier)
/// ```dart
/// // Clean approach: subscribe only to specific events (server-side filtering)
/// final config = WebSocketEventStreamConfig.byIdentifiers(
///   websocketUrl: 'wss://devnet-notifier.multiversx.com',
///   identifiers: ['swap', 'deposit', 'withdraw'],
///   abi: abi, // Optional: for automatic parsing
/// );
/// ```
///
/// #### Example (Legacy - Subscribe to all events)
/// ```dart
/// final config = WebSocketEventStreamConfig(
///   websocketUrl: 'wss://devnet-notifier.multiversx.com',
///   contractAddress: Address.fromBech32('erd1qqqqqq...'),
///   eventType: WebSocketEventType.allEvents,
/// );
/// ```
class WebSocketEventStreamConfig {
  /// Creates WebSocket configuration.
  ///
  /// #### Parameters
  /// - `websocketUrl` - WebSocket notifier URL (e.g., wss://devnet-notifier.multiversx.com)
  /// - `contractAddress` - Contract address to monitor (required for allEvents mode)
  /// - `eventType` - Type of events to receive (default: byIdentifier)
  /// - `eventIdentifiers` - List of event identifiers to subscribe to (for byIdentifier mode)
  /// - `eventIdentifier` - Optional specific event to filter (client-side by topics[0])
  /// - `transactionIdentifier` - Optional transaction identifier for server-side filtering
  /// - `topics` - Optional topics to filter
  /// - `abi` - Optional ABI for automatic event parsing
  /// - `headers` - Optional HTTP headers
  /// - `customProtocols` - Optional WebSocket protocols
  /// - `autoReconnect` - Enable automatic reconnection (default: true)
  /// - `reconnectDelay` - Delay between reconnect attempts (default: 300ms)
  /// - `connectionTimeout` - Connection timeout (default: 5s)
  /// - `pingInterval` - Keep-alive ping interval (default: 10s)
  /// - `logger` - Optional logger
  const WebSocketEventStreamConfig({
    required this.websocketUrl,
    this.contractAddress,
    this.eventType = WebSocketEventType.byIdentifier,
    this.eventIdentifiers,
    this.eventIdentifier,
    this.transactionIdentifier,
    this.topics,
    this.abi,
    this.headers,
    this.customProtocols,
    this.autoReconnect = true,
    this.reconnectDelay = const Duration(milliseconds: 300),
    this.connectionTimeout = const Duration(seconds: 5),
    this.pingInterval = const Duration(seconds: 10),
    this.enableDeduplication = false,
    this.deduplicationTtl = const Duration(seconds: 30),
    this.deduplicationMaxSize = 10000,
    this.logger,
  });

  /// Creates config for subscribing to specific event identifiers (recommended).
  ///
  /// This is the cleanest approach - no deduplication needed, server-side filtering.
  ///
  /// #### Parameters
  /// - `websocketUrl` - WebSocket notifier URL
  /// - `identifiers` - List of event identifiers to subscribe to
  /// - `contractAddress` - Optional contract address for client-side filtering
  /// - `abi` - Optional ABI for automatic parsing
  /// - `headers` - Optional HTTP headers
  /// - `autoReconnect` - Enable automatic reconnection (default: true)
  /// - `logger` - Optional logger
  ///
  /// #### Example
  /// ```dart
  /// final config = WebSocketEventStreamConfig.byIdentifiers(
  ///   websocketUrl: 'wss://devnet-notifier.multiversx.com',
  ///   identifiers: ['swap', 'addLiquidity', 'removeLiquidity'],
  ///   contractAddress: controller.contractAddress,
  /// );
  /// ```
  factory WebSocketEventStreamConfig.byIdentifiers({
    required String websocketUrl,
    required List<String> identifiers,
    Address? contractAddress,
    SmartContractAbi? abi,
    Map<String, String>? headers,
    bool autoReconnect = true,
    Duration reconnectDelay = const Duration(milliseconds: 300),
    Duration connectionTimeout = const Duration(seconds: 5),
    Duration pingInterval = const Duration(seconds: 10),
    Logger? logger,
  }) {
    return WebSocketEventStreamConfig(
      websocketUrl: websocketUrl,
      contractAddress: contractAddress,
      eventType: WebSocketEventType.byIdentifier,
      eventIdentifiers: identifiers,
      abi: abi,
      headers: headers,
      autoReconnect: autoReconnect,
      reconnectDelay: reconnectDelay,
      connectionTimeout: connectionTimeout,
      pingInterval: pingInterval,
      enableDeduplication: false,
      logger: logger,
    );
  }

  /// WebSocket notifier URL.
  final String websocketUrl;

  /// Contract address to monitor (optional, only needed for allEvents mode).
  final Address? contractAddress;

  /// Type of events to receive from MultiversX notifier.
  final WebSocketEventType eventType;

  /// List of event identifiers to subscribe to (for byIdentifier mode).
  ///
  /// Each identifier creates a separate subscription entry.
  /// Example: ['swap', 'deposit'] subscribes to both 'swap' and 'deposit' events.
  final List<String>? eventIdentifiers;

  /// Specific event identifier to filter (optional).
  ///
  /// Filters events CLIENT-SIDE by matching the decoded topics[0] value.
  /// Set to null to receive all events from the contract.
  ///
  /// Example: Set to 'swap' to only receive events where topics[0] == 'swap'
  final String? eventIdentifier;

  /// Transaction identifier for SERVER-SIDE filtering (optional).
  ///
  /// Filters events at the MultiversX WebSocket server by the raw 'identifier' field.
  /// This field contains function/transaction names (e.g., 'swapTokensFixedInput').
  ///
  /// Example: Set to 'swapTokensFixedInput' to only receive events where
  /// the raw identifier matches exactly.
  final String? transactionIdentifier;

  /// Topics to filter by (optional).
  final List<String>? topics;

  /// ABI for automatic event parsing.
  final SmartContractAbi? abi;

  /// Custom HTTP headers for WebSocket connection.
  final Map<String, String>? headers;

  /// Custom WebSocket protocols.
  final Iterable<String>? customProtocols;

  /// Auto-reconnect on connection loss.
  final bool autoReconnect;

  /// Reconnect delay.
  final Duration reconnectDelay;

  /// Connection timeout.
  final Duration connectionTimeout;

  /// Ping interval. to keep connection alive
  final Duration pingInterval;

  /// Enable event deduplication to filter duplicates.
  final bool enableDeduplication;

  /// Deduplication time-to-live duration.
  final Duration deduplicationTtl;

  /// Maximum size of deduplication cache.
  final int deduplicationMaxSize;

  /// Optional logger for debugging and monitoring
  final Logger? logger;
}

/// Result of a WebSocket event with raw and parsed data.
///
/// Emitted by events stream for each received event.
///
/// #### Example
/// ```dart
/// stream.events.listen((result) {
///   print('TX Hash: ${result.txHash}');
///   print('Raw identifier: ${result.rawEvent.identifier}');
///
///   if (result.parsedEvent != null) {
///     final data = result.parsedEvent!.toMap();
///     print('Parsed data: $data');
///   }
/// });
/// ```
class WebSocketEventResult {
  /// Creates event result.
  ///
  /// #### Parameters
  /// - `rawEvent` - Raw event data
  /// - `parsedEvent` - Parsed event if ABI available
  /// - `txHash` - Transaction hash
  /// - `blockHash` - Optional block hash
  /// - `receivedAt` - Timestamp when received
  const WebSocketEventResult({
    required this.rawEvent,
    this.parsedEvent,
    required this.txHash,
    this.blockHash,
    required this.receivedAt,
  });

  /// Raw transaction event.
  final TransactionEvent rawEvent;

  /// Parsed event (available if ABI was provided).
  final ParsedEvent? parsedEvent;

  /// Transaction hash.
  final String txHash;

  /// Block hash.
  final String? blockHash;

  /// Timestamp when received.
  final DateTime receivedAt;
}

/// Error information for WebSocket failures.
class WebSocketEventError {
  /// Creates error event.
  const WebSocketEventError({
    required this.message,
    this.error,
    this.stackTrace,
    required this.timestamp,
  });

  /// Error message.
  final String message;

  /// Original error object.
  final Object? error;

  /// Stack trace.
  final StackTrace? stackTrace;

  /// Timestamp of error.
  final DateTime timestamp;
}

/// Status change event.
class WebSocketStatusChange {
  /// Creates status change event.
  const WebSocketStatusChange({
    required this.from,
    required this.to,
    required this.timestamp,
  });

  /// Previous status.
  final WebSocketStatus from;

  /// New status.
  final WebSocketStatus to;

  /// Timestamp.
  final DateTime timestamp;
}

/// MultiversX WebSocket event streaming client with auto-reconnection.
///
/// Connect to MultiversX WebSocket notifier for real-time events.
///
/// #### Example
/// ```dart
/// final stream = WebSocketEventStream(config);
///
/// // Subscribe to events
/// stream.events.listen((result) {
///   print('Event received: ${result.txHash}');
/// });
///
/// // Subscribe to errors
/// stream.errors.listen((error) {
///   print('Error: ${error.message}');
/// });
///
/// // Subscribe to status changes
/// stream.statusChanges.listen((change) {
///   print('Status: ${change.from} → ${change.to}');
/// });
///
/// // Connect
/// await stream.connect();
///
/// // Disconnect when done
/// await stream.disconnect();
/// await stream.dispose();
/// ```
class WebSocketEventStream {
  /// Creates WebSocket event stream with configuration.
  ///
  /// #### Parameters
  /// - `config` - WebSocket configuration
  ///
  /// #### Returns
  /// `WebSocketEventStream` instance
  WebSocketEventStream(this.config) : _logger = config.logger {
    _logger?.debug(
      'WebSocketEventStream initialized',
      context: {
        'url': config.websocketUrl,
        'contract': config.contractAddress?.bech32,
        'mode': config.eventType.name,
        'eventIdentifiers': config.eventIdentifiers,
        'eventIdentifier': config.eventIdentifier,
        'transactionIdentifier': config.transactionIdentifier,
        'hasABI': config.abi != null,
        'hasHeaders': config.headers != null,
        'autoReconnect': config.autoReconnect,
        'enableDeduplication': config.enableDeduplication,
      },
    );
    if (config.abi != null) {
      _parser = TransactionEventParser.withAbi(config.abi);
      _logger?.debug('ABI parser initialized');
    }
    if (config.enableDeduplication) {
      _deduplicator = EventDeduplicator(
        maxSize: config.deduplicationMaxSize,
        ttl: config.deduplicationTtl,
      );
      _logger?.debug('Event deduplicator initialized');
    }
  }

  /// Configuration for WebSocket connection and behavior.
  final WebSocketEventStreamConfig config;
  final Logger? _logger;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  WebSocketStatus _status = WebSocketStatus.idle;
  final StreamController<WebSocketEventResult> _eventsController =
      StreamController<WebSocketEventResult>.broadcast(sync: true);
  final StreamController<WebSocketStatusChange> _statusController =
      StreamController<WebSocketStatusChange>.broadcast(sync: true);
  final StreamController<WebSocketEventError> _errorsController =
      StreamController<WebSocketEventError>.broadcast(sync: true);
  TransactionEventParser? _parser;
  EventDeduplicator? _deduplicator;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  bool _isReconnecting = false;
  static const int _maxReconnectAttempts = 5;
  static const Duration _maxReconnectDelay = Duration(seconds: 2);
  DateTime? _connectedAt;
  int _eventsReceived = 0;
  int _duplicatesFiltered = 0;
  DateTime? _lastEventTime;

  /// Current WebSocket connection status.
  WebSocketStatus get status => _status;

  /// Stream of received WebSocket events.
  Stream<WebSocketEventResult> get events => _eventsController.stream;

  /// Stream of WebSocket status changes.
  Stream<WebSocketStatusChange> get statusChanges => _statusController.stream;

  /// Stream of WebSocket errors.
  Stream<WebSocketEventError> get errors => _errorsController.stream;

  /// Timestamp when connected.
  DateTime? get connectedAt => _connectedAt;

  /// Total number of events received.
  int get eventsReceived => _eventsReceived;

  /// Number of duplicate events filtered.
  int get duplicatesFiltered => _duplicatesFiltered;

  /// Timestamp of the last received event.
  DateTime? get lastEventTime => _lastEventTime;

  /// Number of reconnection attempts made.
  int get reconnectAttempts => _reconnectAttempts;

  /// Connects to WebSocket and subscribes to contract events.
  ///
  /// Establishes connection and starts listening for events.
  ///
  /// #### Returns
  /// `Future` that completes when connected and subscribed
  ///
  /// #### Throws
  /// `Exception` if connection fails and autoReconnect is false
  ///
  /// #### Example
  /// ```dart
  /// try {
  ///   await stream.connect();
  ///   print('Connected successfully');
  /// } catch (e) {
  ///   print('Connection failed: $e');
  /// }
  /// ```
  Future<void> connect() async {
    if (_status == WebSocketStatus.connecting ||
        _status == WebSocketStatus.connected ||
        _status == WebSocketStatus.listening) {
      _logger?.debug(
        'Connect called but already in progress/connected',
        context: <String, dynamic>{'currentStatus': _status.toString()},
      );
      return;
    }

    try {
      await _cleanupConnection();

      _logger?.info(
        'Connecting to WebSocket',
        context: <String, dynamic>{
          'url': config.websocketUrl,
          'mode': config.eventType.name,
          'contract': config.contractAddress?.bech32,
          'eventIdentifiers': config.eventIdentifiers,
        },
      );

      _updateStatus(WebSocketStatus.connecting);

      final Uri uri = Uri.parse(config.websocketUrl);

      if (config.headers != null || config.customProtocols != null) {
        _logger?.debug(
          'Connecting with authentication',
          context: <String, dynamic>{
            'hasHeaders': config.headers != null,
            'hasProtocols': config.customProtocols != null,
          },
        );

        WebSocket? socket;
        try {
          socket =
              await WebSocket.connect(
                uri.toString(),
                headers: config.headers,
                protocols: config.customProtocols,
              ).timeout(
                config.connectionTimeout,
                onTimeout: () {
                  throw TimeoutException(
                    'WebSocket connection timeout',
                    config.connectionTimeout,
                  );
                },
              );
          _channel = IOWebSocketChannel(socket);
        } catch (e) {
          await socket?.close();
          rethrow;
        }
      } else {
        _logger?.debug('Connecting with direct socket');
        WebSocket? socket;
        try {
          socket = await WebSocket.connect(uri.toString()).timeout(
            config.connectionTimeout,
            onTimeout: () {
              throw TimeoutException(
                'WebSocket connection timeout',
                config.connectionTimeout,
              );
            },
          );
          _channel = IOWebSocketChannel(socket);
        } catch (e) {
          await socket?.close();
          rethrow;
        }
      }

      _connectedAt = DateTime.now();
      _reconnectAttempts = 0;

      _listenToMessages();
      _startPingTimer();
      _updateStatus(WebSocketStatus.connected);

      _logger?.info('WebSocket connected successfully');

      await _subscribe();

      _updateStatus(WebSocketStatus.listening);
      _logger?.info('Now listening for events');
    } catch (e, stackTrace) {
      _logger?.error('Connection failed', error: e, stackTrace: stackTrace);
      _handleError('Failed to connect', e, stackTrace);

      if (config.autoReconnect) {
        _scheduleReconnect();
      }
    }
  }

  /// Subscribe to smart contract events using MultiversX protocol.
  Future<void> _subscribe() async {
    try {
      final List<Map<String, dynamic>> subscriptionEntries =
          <Map<String, dynamic>>[];

      if (config.eventType == WebSocketEventType.byIdentifier) {
        final List<String> identifiers = config.eventIdentifiers ?? <String>[];
        if (identifiers.isEmpty && config.eventIdentifier != null) {
          identifiers.add(config.eventIdentifier!);
        }

        for (final String identifier in identifiers) {
          subscriptionEntries.add(<String, dynamic>{'identifier': identifier});
        }

        _logger?.debug(
          'Subscribing by identifiers (clean mode)',
          context: <String, dynamic>{
            'identifiers': identifiers,
            'count': identifiers.length,
          },
        );
      } else {
        if (config.contractAddress == null) {
          throw ArgumentError('contractAddress is required for allEvents mode');
        }

        final Map<String, dynamic> subscriptionEntry = <String, dynamic>{
          'eventType': 'all_events',
          'address': config.contractAddress!.bech32,
        };

        if (config.transactionIdentifier != null) {
          subscriptionEntry['identifier'] = config.transactionIdentifier;
        }

        if (config.topics != null && config.topics!.isNotEmpty) {
          subscriptionEntry['topics'] = config.topics;
        }

        subscriptionEntries.add(subscriptionEntry);

        _logger?.debug(
          'Subscribing to all_events (legacy mode)',
          context: <String, dynamic>{
            'address': config.contractAddress!.bech32,
            'transactionIdentifier': config.transactionIdentifier,
            'topics': config.topics,
          },
        );
      }

      final Map<String, dynamic> subscribeMessage = <String, dynamic>{
        'subscriptionEntries': subscriptionEntries,
      };

      final String jsonMessage = jsonEncode(subscribeMessage);
      _channel!.sink.add(jsonMessage);

      _logger?.info(
        'Subscription sent successfully',
        context: <String, dynamic>{
          'mode': config.eventType.name,
          'entriesCount': subscriptionEntries.length,
        },
      );
    } catch (e, stackTrace) {
      _logger?.error('Subscription failed', error: e, stackTrace: stackTrace);
      throw NetworkException('Failed to subscribe', cause: e);
    }
  }

  /// Start periodic ping to keep connection alive.
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(config.pingInterval, (Timer timer) {
      if (_status == WebSocketStatus.listening ||
          _status == WebSocketStatus.connected) {
        try {
          _channel?.sink.add('{}');
        } catch (e) {
          _handleError('Ping failed', e, StackTrace.current);
          _scheduleReconnect();
        }
      }
    });
  }

  /// Listen to WebSocket messages
  void _listenToMessages() {
    _channelSubscription?.cancel();

    _channelSubscription = _channel!.stream.listen(
      (dynamic message) {
        _handleMessage(message);
      },
      onError: (Object error, StackTrace stackTrace) {
        _handleError('WebSocket stream error', error, stackTrace);
      },
      onDone: () {
        _handleDisconnection();
      },
      cancelOnError: false,
    );
  }

  /// Handle incoming WebSocket message.
  void _handleMessage(dynamic message) {
    try {
      if (message is! String) {
        return;
      }

      final Map<String, dynamic> envelope = requireAs<Map<String, dynamic>>(
        jsonDecode(message),
        'message',
      );

      final String? type = optionalAs<String>(envelope['type'], 'type');
      final dynamic data = envelope['data'];

      if (type == null || data == null) {
        return;
      }

      switch (type) {
        case 'all_events':
        case 'finalized_events':
        case 'revert_events':
          _handleAllEvents(data);
          break;
        case 'block_events':
          _handleBlockEvents(data);
          break;
        default:
          _logger?.debug(
            'Unknown message type received',
            context: <String, dynamic>{'type': type},
          );
      }
    } catch (e, stackTrace) {
      _handleError('Failed to process message', e, stackTrace);
    }
  }

  /// Handle 'all_events' type messages.
  void _handleAllEvents(dynamic data) {
    try {
      List<dynamic>? events;
      String? blockHash;

      if (data is List) {
        events = data;
      } else if (data is Map<String, dynamic>) {
        blockHash = optionalAs<String>(data['hash'], 'hash');
        events = optionalAs<List<dynamic>>(data['events'], 'events');
      } else if (data is String) {
        final dynamic parsed = jsonDecode(data);
        if (parsed is List) {
          events = parsed;
        } else if (parsed is Map<String, dynamic>) {
          blockHash = optionalAs<String>(parsed['hash'], 'hash');
          events = optionalAs<List<dynamic>>(parsed['events'], 'events');
        }
      }

      if (events == null || events.isEmpty) {
        return;
      }
      for (final dynamic eventJson in events) {
        if (eventJson is Map<String, dynamic>) {
          _processEvent(eventJson, blockHash);
        }
      }
    } catch (e, stackTrace) {
      _handleError('Failed to handle all_events', e, stackTrace);
    }
  }

  /// Handle 'block_events' type messages.
  void _handleBlockEvents(dynamic data) {
    try {
      final Map<String, dynamic> blockData = data is String
          ? requireAs<Map<String, dynamic>>(jsonDecode(data), 'data')
          : requireAs<Map<String, dynamic>>(data, 'data');

      final String? blockHash = optionalAs<String>(blockData['hash'], 'hash');
      final List<dynamic>? events = optionalAs<List<dynamic>>(
        blockData['events'],
        'events',
      );

      if (events == null || events.isEmpty) {
        return;
      }
      for (final dynamic eventJson in events) {
        if (eventJson is Map<String, dynamic>) {
          _processEvent(eventJson, blockHash);
        }
      }
    } catch (e, stackTrace) {
      _handleError('Failed to handle block_events', e, stackTrace);
    }
  }

  void _processEvent(Map<String, dynamic> eventJson, String? blockHash) {
    try {
      if (eventJson case {
        'address': final String address,
        'identifier': final String identifier,
        'txHash': final String txHash,
      }) {
        final String dedupeKey = '$txHash:$identifier';
        if (_deduplicator != null && !_deduplicator!.shouldProcess(dedupeKey)) {
          _duplicatesFiltered++;
          return;
        }

        if (config.contractAddress != null &&
            address.toLowerCase() !=
                config.contractAddress!.bech32.toLowerCase()) {
          return;
        }

        final List<Uint8List> topics = <Uint8List>[];
        if (eventJson['topics'] case final List<dynamic> topicsList) {
          for (final topic in topicsList) {
            if (topic case final String s when s.isNotEmpty) {
              try {
                topics.add(Uint8List.fromList(base64.decode(s)));
              } catch (e) {
                _logger?.debug('Invalid base64 topic: $e');
              }
            }
          }
        }

        final Uint8List data = switch (eventJson['data']) {
          final String s when s.isNotEmpty => () {
            try {
              return Uint8List.fromList(base64.decode(s));
            } catch (e) {
              _logger?.debug('Invalid base64 data: $e');
              return Uint8List(0);
            }
          }(),
          _ => Uint8List(0),
        };

        final List<Uint8List> additionalData = <Uint8List>[];
        if (eventJson['additionalData'] case final List<dynamic> dataList) {
          for (final item in dataList) {
            if (item case final String s when s.isNotEmpty) {
              try {
                additionalData.add(Uint8List.fromList(base64.decode(s)));
              } catch (e) {
                _logger?.debug('Invalid base64 additionalData: $e');
              }
            }
          }
        }

        final TransactionEvent rawEvent = TransactionEvent(
          address: Address.fromBech32(address),
          identifier: identifier,
          topics: topics,
          data: data,
          additionalData: additionalData,
        );

        if (config.eventIdentifier != null) {
          if (topics.isEmpty) {
            _logger?.debug(
              'Skipping event with no topics (cannot verify event identifier)',
              context: <String, dynamic>{'identifier': identifier},
            );
            return;
          }

          try {
            final String topicIdentifier = utf8.decode(topics[0]);

            if (topicIdentifier != config.eventIdentifier) {
              _logger?.debug(
                'Skipping event - topics[0] does not match filter',
                context: <String, dynamic>{
                  'identifier': identifier,
                  'topics[0]': topicIdentifier,
                  'filterIdentifier': config.eventIdentifier,
                },
              );
              return;
            }

            _logger?.debug(
              'Event matched by topics[0]',
              context: <String, dynamic>{
                'identifier': identifier,
                'topics[0]': topicIdentifier,
                'txHash': txHash,
              },
            );
          } catch (e) {
            _logger?.debug(
              'Failed to decode topics[0] as UTF-8, skipping event',
              context: <String, dynamic>{
                'identifier': identifier,
                'error': e.toString(),
              },
            );
            return;
          }
        } else {
          _logger?.debug(
            'Processing event (no filter)',
            context: <String, dynamic>{
              'identifier': identifier,
              'txHash': txHash,
              'blockHash': blockHash,
            },
          );
        }

        ParsedEvent? parsedEvent;
        if (_parser != null && config.abi != null) {
          String parseIdentifier = identifier;
          if (topics.isNotEmpty) {
            try {
              parseIdentifier = utf8.decode(topics[0]);
            } catch (_) {}
          }

          try {
            parsedEvent = _parser!.parseSingleEvent(rawEvent, parseIdentifier);

            final Map<String, TypedValue> parsedData = parsedEvent.toMap();
            _logger?.debug(
              'Event parsed successfully with ABI',
              context: <String, dynamic>{
                'identifier': identifier,
                'parseIdentifier': parseIdentifier,
                'parsedFields': parsedData.length,
                'data': parsedData.toString(),
              },
            );
          } catch (e) {
            _logger?.debug(
              'Event not in ABI - emitting raw data only',
              context: <String, dynamic>{
                'identifier': parseIdentifier,
                'rawIdentifier': identifier,
                'reason': e.toString(),
              },
            );
          }
        }

        final WebSocketEventResult result = WebSocketEventResult(
          rawEvent: rawEvent,
          parsedEvent: parsedEvent,
          txHash: txHash,
          blockHash: blockHash,
          receivedAt: DateTime.now(),
        );

        _eventsReceived++;
        _lastEventTime = DateTime.now();
        _eventsController.add(result);

        _logger?.info(
          'Event emitted',
          context: <String, dynamic>{
            'identifier': identifier,
            'txHash': txHash,
            'totalEvents': _eventsReceived,
            'hasParsedData': parsedEvent != null,
          },
        );
      } else {
        _logger?.debug('Skipping event with missing fields');
        return;
      }
    } catch (e, stackTrace) {
      _logger?.error(
        'Failed to process event',
        error: e,
        stackTrace: stackTrace,
      );
      _handleError('Failed to process event', e, stackTrace);
    }
  }

  /// Handle WebSocket error.
  void _handleError(String message, Object? error, StackTrace? stackTrace) {
    _logger?.error(message, error: error, stackTrace: stackTrace);
    _updateStatus(WebSocketStatus.error);

    final WebSocketEventError errorEvent = WebSocketEventError(
      message: message,
      error: error,
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
    );

    _errorsController.add(errorEvent);

    if (config.autoReconnect && _status != WebSocketStatus.disconnected) {
      _scheduleReconnect();
    }
  }

  /// Handle WebSocket disconnection.
  void _handleDisconnection() {
    if (_status != WebSocketStatus.disconnected) {
      _logger?.warning('WebSocket disconnected');
      _updateStatus(WebSocketStatus.disconnected);

      if (config.autoReconnect) {
        _scheduleReconnect();
      }
    }
  }

  /// Schedule reconnection attempt.
  void _scheduleReconnect() {
    if (_isReconnecting) {
      _logger?.debug('Reconnection already in progress, skipping');
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      const String errorMsg =
          'Max reconnection attempts reached ($_maxReconnectAttempts)';
      _logger?.critical(errorMsg);
      _handleError(errorMsg, null, null);
      return;
    }

    _isReconnecting = true;
    _reconnectTimer?.cancel();
    final int multiplier = 1 << _reconnectAttempts;
    Duration delay = config.reconnectDelay * multiplier;
    if (delay > _maxReconnectDelay) {
      delay = _maxReconnectDelay;
    }

    _reconnectAttempts++;

    _logger?.warning(
      'Scheduling reconnection',
      context: <String, dynamic>{
        'attempt': _reconnectAttempts,
        'maxAttempts': _maxReconnectAttempts,
        'delaySeconds': delay.inSeconds,
      },
    );

    _reconnectTimer = Timer(delay, () async {
      _logger?.info(
        'Attempting reconnection',
        context: <String, dynamic>{'attempt': _reconnectAttempts},
      );
      await connect();
      _isReconnecting = false;
    });
  }

  /// Pause event streaming (keeps connection open).
  void pause() {
    if (_status == WebSocketStatus.listening) {
      _logger?.info('Pausing event stream');
      _updateStatus(WebSocketStatus.paused);
    }
  }

  /// Resume event streaming.
  void resume() {
    if (_status == WebSocketStatus.paused) {
      _logger?.info('Resuming event stream');
      _updateStatus(WebSocketStatus.listening);
    }
  }

  /// Clean up existing connection resources.
  Future<void> _cleanupConnection() async {
    await _channelSubscription?.cancel();
    _channelSubscription = null;

    if (_channel != null) {
      try {
        await _channel!.sink.close();
        _logger?.debug('WebSocket channel closed');
      } catch (e) {
        _logger?.debug('Error closing channel (ignoring): $e');
      }
      _channel = null;
    }
  }

  /// Disconnect from WebSocket.
  Future<void> disconnect() async {
    _logger?.info(
      'Disconnecting WebSocket',
      context: <String, dynamic>{
        'eventsReceived': _eventsReceived,
        'connectedDuration': _connectedAt != null
            ? '${DateTime.now().difference(_connectedAt!).inSeconds}s'
            : null,
      },
    );

    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _updateStatus(WebSocketStatus.disconnected);

    await _cleanupConnection();
    _connectedAt = null;
  }

  /// Dispose and clean up all resources.
  Future<void> dispose() async {
    _logger?.info(
      'Disposing WebSocket stream',
      context: <String, dynamic>{
        'totalEventsReceived': _eventsReceived,
        'duplicatesFiltered': _duplicatesFiltered,
        'finalStatus': _status.name,
      },
    );

    await disconnect();
    await _eventsController.close();
    await _statusController.close();
    await _errorsController.close();
    _deduplicator?.reset();

    _logger?.debug('All resources disposed');
  }

  /// Update status and emit change event.
  void _updateStatus(WebSocketStatus newStatus) {
    if (_status != newStatus) {
      final WebSocketStatus oldStatus = _status;
      _status = newStatus;

      final WebSocketStatusChange change = WebSocketStatusChange(
        from: oldStatus,
        to: newStatus,
        timestamp: DateTime.now(),
      );

      _logger?.info('Status changed: ${oldStatus.name} → ${newStatus.name}');
      _statusController.add(change);
    }
  }
}
