import 'dart:async';

import 'package:abidock_mvx/abidock_mvx.dart';

import '../../models/add_liquidity_event.dart';

/// HTTP polling stream for add_liquidity events.
///
/// #### Event Fields:
/// - `firstToken`: TokenIdentifier (indexed)
/// - `secondToken`: TokenIdentifier (indexed)
/// - `caller`: Address (indexed)
/// - `epoch`: u64 (indexed)
/// - `addLiquidityEvent`: AddLiquidityEvent
final class AddLiquidityPollingStream {
  const AddLiquidityPollingStream(this.controller);

  final SmartContractController controller;

  /// Starts polling for add_liquidity events.
  Stream<AddLiquidityEvent> call({
    Duration pollingInterval = const Duration(seconds: 10),
    String? startFrom,
  }) {
    return controller
        .streamEvents(
          eventIdentifier: 'add_liquidity',
          pollingInterval: pollingInterval,
          startFrom: startFrom,
        )
        .map((parsedEvent) {
          final eventStruct = parsedEvent.getValueByName('add_liquidity_event');
          if (eventStruct == null) {
            throw StateError('Event struct not found in parsed event');
          }
          return AddLiquidityEvent.fromAbi(eventStruct);
        });
  }
}
