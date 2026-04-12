import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

class _FakeNetworkProvider implements NetworkProvider {
  int callCount = 0;
  Nonce nextNonce = const Nonce(10);
  Exception? throwNext;

  @override
  Future<AccountOnNetwork> getAccount(Address address) async {
    callCount++;
    if (throwNext != null) {
      final Exception e = throwNext!;
      throwNext = null;
      throw e;
    }
    return AccountOnNetwork(
      address: address,
      nonce: nextNonce,
      balance: Balance.zero(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not implemented');
}

void main() {
  late Address address;
  late _FakeNetworkProvider provider;
  late NonceManager manager;

  setUp(() {
    address = Address.fromBech32(
      'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
    );
    provider = _FakeNetworkProvider();
    manager = NonceManager(
      address: address,
      networkProvider: provider,
      resyncInterval: Duration.zero,
    );
  });

  group('NonceManager', () {
    test('seeds from the network on first call and increments locally',
        () async {
      provider.nextNonce = const Nonce(42);

      final Nonce first = await manager.next();
      final Nonce second = await manager.next();
      final Nonce third = await manager.next();

      expect(first.value, 42);
      expect(second.value, 43);
      expect(third.value, 44);
      // Only a single bootstrap fetch — subsequent `next()` stays local.
      expect(provider.callCount, 1);
      expect(manager.peek, 45);
    });

    test('release rewinds the counter when the last-reserved nonce is freed',
        () async {
      provider.nextNonce = const Nonce(10);

      final Nonce a = await manager.next(); // 10
      final Nonce b = await manager.next(); // 11
      manager.release(b);

      final Nonce reused = await manager.next();
      expect(reused.value, 11);
      expect(a.value, 10);
    });

    test('release queues for reuse when a non-trailing nonce is freed',
        () async {
      provider.nextNonce = const Nonce(0);

      final Nonce a = await manager.next(); // 0
      final Nonce b = await manager.next(); // 1
      final Nonce c = await manager.next(); // 2
      // Free the middle one.
      manager.release(b);
      expect(a.value, 0);
      expect(c.value, 2);

      // Next call should hand out the freed middle nonce first.
      final Nonce reused = await manager.next();
      expect(reused.value, 1);

      // Then keep advancing the counter.
      final Nonce follow = await manager.next();
      expect(follow.value, 3);
    });

    test('resync never moves the counter backwards', () async {
      provider.nextNonce = const Nonce(100);
      await manager.next(); // reserves 100 → counter at 101
      await manager.next(); // reserves 101 → counter at 102

      // Network reports a lower nonce — we must not regress.
      provider.nextNonce = const Nonce(50);
      await manager.resync();
      expect(manager.peek, 102);
    });

    test('resync advances the counter when the network is ahead', () async {
      provider.nextNonce = const Nonce(5);
      await manager.next(); // 5

      provider.nextNonce = const Nonce(20);
      await manager.resync();
      expect(manager.peek, 20);
    });

    test('applyNonce sets a floor for resync', () async {
      provider.nextNonce = const Nonce(10);
      final Nonce reserved = await manager.next(); // 10
      manager.applyNonce(reserved);

      // Network briefly reports an older state (e.g. load-balanced replica).
      provider.nextNonce = const Nonce(5);
      await manager.resync();
      // Must clamp to applied+1 = 11.
      expect(manager.peek, 11);
    });

    test('first next() rethrows when network bootstrap fails', () async {
      provider.throwNext = Exception('boom');
      await expectLater(manager.next(), throwsA(isA<Exception>()));
      expect(manager.peek, isNull);
    });
  });
}
