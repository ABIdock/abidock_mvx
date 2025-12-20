import 'package:abidock_mvx/abidock_mvx.dart';
import 'pair/pair.dart';

Future<void> main() async {
  final provider = ApiNetworkProvider.devnet();

  final controller = PairController(
    contractAddress:
        'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
    networkProvider: provider,
  );
  final stream = controller.events.pollingStream().all;
  stream.listen((event) {
    if (event is SwapEvent) {
      print('Swap event: ${event.toJson()}');
    } else if (event is AddLiquidityEvent) {
      print('Add Liquidity event: ${event.toJson()}');
    } else if (event is RemoveLiquidityEvent) {
      print('Remove Liquidity event: ${event.toJson()}');
    } else if (event is SwapNoFeeAndForwardEvent) {
      print('SwapNoFeeAndForward event: ${event.toJson()}');
    }
  });
}
