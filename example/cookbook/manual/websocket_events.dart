import 'dart:io';

import 'package:abidock_mvx/abidock_mvx.dart';

Future<void> main() async {
  final ConsoleLogger logger = ConsoleLogger(
    minLevel: LogLevel.debug,
    includeTimestamp: true,
    prettyPrintContext: true,
    showBorders: true,
    useColors: true,
  );
  final provider = ApiNetworkProvider.devnet();

  final abiFile = File('assets/pair.abi.json');
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
    headers: {'Api-Key': 'e7dd4f836556656475c427a752958cd2'},
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
