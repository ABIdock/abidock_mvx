import 'dart:async';

import 'package:abidock_mvx/abidock_mvx.dart';

import '../models/add_liquidity_event.dart';
import '../models/remove_liquidity_event.dart';
import '../models/swap_event.dart';
import '../models/swap_no_fee_and_forward_event.dart';

/// Combined WebSocket stream that fans out every event.
/// Use typed getters, `all`, or `only` to consume events.
final class MultiEventWebSocketStream {
  MultiEventWebSocketStream({
    required SmartContractController controller,
    required String websocketUrl,
    Map<String, String> headers = const {},
    bool autoReconnect = true,
    Duration reconnectDelay = const Duration(milliseconds: 300),
    Duration connectionTimeout = const Duration(seconds: 5),
    Duration pingInterval = const Duration(seconds: 10),
  }) : _controller = controller {
    _config = WebSocketEventStreamConfig.byIdentifiers(
      websocketUrl: websocketUrl,
      identifiers: [
        'swap',
        'swap_no_fee_and_forward',
        'add_liquidity',
        'remove_liquidity',
      ],
      contractAddress: _controller.contractAddress,
      abi: _controller.abi,
      headers: headers,
      logger: _controller.logger,
      autoReconnect: autoReconnect,
      reconnectDelay: reconnectDelay,
      connectionTimeout: connectionTimeout,
      pingInterval: pingInterval,
    );

    _stream = WebSocketEventStream(_config);
  }

  final SmartContractController _controller;
  late final WebSocketEventStreamConfig _config;
  late final WebSocketEventStream _stream;

  /// Stream of swap events.
  Stream<SwapEvent> get swap => EventConverter.filterByIdentifier<SwapEvent>(
    _stream.events,
    'swap',
    (parsed) => EventConverter.convertEvent<SwapEvent>(
      parsed,
      SwapEvent.fromAbi,
      SwapEvent.type,
    ),
  );

  /// Stream of swap_no_fee_and_forward events.
  Stream<SwapNoFeeAndForwardEvent> get swapNoFeeAndForward =>
      EventConverter.filterByIdentifier<SwapNoFeeAndForwardEvent>(
        _stream.events,
        'swap_no_fee_and_forward',
        (parsed) => EventConverter.convertEvent<SwapNoFeeAndForwardEvent>(
          parsed,
          SwapNoFeeAndForwardEvent.fromAbi,
          SwapNoFeeAndForwardEvent.type,
        ),
      );

  /// Stream of add_liquidity events.
  Stream<AddLiquidityEvent> get addLiquidity =>
      EventConverter.filterByIdentifier<AddLiquidityEvent>(
        _stream.events,
        'add_liquidity',
        (parsed) => EventConverter.convertEvent<AddLiquidityEvent>(
          parsed,
          AddLiquidityEvent.fromAbi,
          AddLiquidityEvent.type,
        ),
      );

  /// Stream of remove_liquidity events.
  Stream<RemoveLiquidityEvent> get removeLiquidity =>
      EventConverter.filterByIdentifier<RemoveLiquidityEvent>(
        _stream.events,
        'remove_liquidity',
        (parsed) => EventConverter.convertEvent<RemoveLiquidityEvent>(
          parsed,
          RemoveLiquidityEvent.fromAbi,
          RemoveLiquidityEvent.type,
        ),
      );

  /// Stream of all events (any type).
  ///
  /// Use type checks to handle different events:
  /// ```dart
  /// stream.all.listen((event) {
  ///   if (event is SwapEvent) { ... }
  /// });
  /// ```
  Stream<dynamic> get all => _stream.events
      .where((r) => r.parsedEvent != null)
      .map((r) {
        final identifier = r.parsedEvent!.definition.identifier;
        switch (identifier) {
          case 'swap':
            return EventConverter.convertEvent<SwapEvent>(
              r.parsedEvent!,
              SwapEvent.fromAbi,
              SwapEvent.type,
            );
          case 'swap_no_fee_and_forward':
            return EventConverter.convertEvent<SwapNoFeeAndForwardEvent>(
              r.parsedEvent!,
              SwapNoFeeAndForwardEvent.fromAbi,
              SwapNoFeeAndForwardEvent.type,
            );
          case 'add_liquidity':
            return EventConverter.convertEvent<AddLiquidityEvent>(
              r.parsedEvent!,
              AddLiquidityEvent.fromAbi,
              AddLiquidityEvent.type,
            );
          case 'remove_liquidity':
            return EventConverter.convertEvent<RemoveLiquidityEvent>(
              r.parsedEvent!,
              RemoveLiquidityEvent.fromAbi,
              RemoveLiquidityEvent.type,
            );
          default:
            return r;
        }
      })
      .where((event) => event != null)
      .cast<dynamic>();

  /// Filter to only specified event types.
  ///
  /// Example:
  /// ```dart
  /// stream.only([SwapEvent, SwapNoFeeAndForwardEvent]).listen((event) {
  ///   // Only receive these event types
  /// });
  /// ```
  Stream<dynamic> only(List<Type> eventTypes) {
    return all.where((event) => eventTypes.contains(event.runtimeType));
  }

  /// Stream of connection status changes.
  Stream<WebSocketStatusChange> get statusChanges => _stream.statusChanges;

  /// Stream of WebSocket errors.
  Stream<WebSocketEventError> get errors => _stream.errors;

  /// Connects to WebSocket server.
  Future<void> connect() => _stream.connect();

  /// Disconnects from WebSocket server.
  Future<void> disconnect() => _stream.disconnect();

  /// Dispose resources.
  Future<void> dispose() => _stream.dispose();

  /// Current connection status.
  WebSocketStatus get status => _stream.status;

  /// Pause event streaming.
  void pause() => _stream.pause();

  /// Resume event streaming.
  void resume() => _stream.resume();
}
