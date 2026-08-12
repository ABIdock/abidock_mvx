import 'dart:io';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'pair/pair.dart';

/// Events API key, read from the `ABIDOCK_WS_API_KEY` environment variable.
///
/// Never hard-code a real key in a committed example: run this sample with
/// `ABIDOCK_WS_API_KEY=<your-key> dart run example/cookbook/generated/generated_websocket_events.dart`.
final String _apiKey = Platform.environment['ABIDOCK_WS_API_KEY'] ?? 'your-key';

Future<void> main() async {
  final provider = ApiNetworkProvider.devnet();

  final controller = PairController(
    contractAddress:
        'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
    networkProvider: provider,
  );

  final stream = controller.events.websocketStream(
    websocketUrl: 'wss://kepler-api.projectx.mx/devnet/events',
    headers: {'Api-Key': _apiKey},
  );

  await stream.connect();

  stream.swap.listen((event) {
    print('Swap event: ${event.toJson()}');
  });
}
