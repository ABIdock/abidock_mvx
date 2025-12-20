import 'package:abidock_mvx/abidock_mvx.dart';
import 'pair/pair.dart';

Future<void> main() async {
  final provider = ApiNetworkProvider.devnet();

  final controller = PairController(
    contractAddress:
        'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
    networkProvider: provider,
  );

  final stream = controller.events.websocketStream(
    websocketUrl: 'wss://kepler-api.projectx.mx/devnet/events',
    headers: {'Api-Key': 'e7dd4f836556656475c427a752958cd2'},
  );

  await stream.connect();

  stream.swap.listen((event) {
    print('Swap event: ${event.toJson()}');
  });
}
