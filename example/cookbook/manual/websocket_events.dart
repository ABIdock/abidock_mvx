import 'dart:io';

import 'package:abidock_mvx/abidock_mvx.dart';

/// Events API key, read from the `ABIDOCK_WS_API_KEY` environment variable.
///
/// Never hard-code a real key in a committed example: run this sample with
/// `ABIDOCK_WS_API_KEY=<your-key> dart run example/cookbook/manual/websocket_events.dart`.
final String _apiKey = Platform.environment['ABIDOCK_WS_API_KEY'] ?? 'your-key';

Future<void> main() async {
  final ConsoleLogger logger = ConsoleLogger(
    minLevel: LogLevel.debug,
    includeTimestamp: true,
    prettyPrintContext: true,
    showBorders: true,
    useColors: true,
  );
  final provider = ApiNetworkProvider.devnet();

  final abiFile = File('example/cookbook/pair.abi.json');
  final abiJsonString = await abiFile.readAsString();
  final abi = SmartContractAbi.fromJson(abiJsonString);

  final controller = SmartContractController(
    abi: abi,
    contractAddress: Address.fromBech32(
      'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
    ),
    networkProvider: provider,
    logger: logger,
  );

  final swapConfig = WebSocketEventStreamConfig.byIdentifiers(
    websocketUrl: 'wss://kepler-api.projectx.mx/devnet/events',
    identifiers: const ['swap'],
    contractAddress: controller.contractAddress,
    headers: {'Api-Key': _apiKey},
    abi: abi,
    logger: logger,
  );

  final swapStream = WebSocketEventStream(swapConfig);
  await swapStream.connect();

  swapStream.events.listen((result) {
    final parsed = result.parsedEvent!;
    print('Swap event: ${parsed.toMap()}');
  });
}
