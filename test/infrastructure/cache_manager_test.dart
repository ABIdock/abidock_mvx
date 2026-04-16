import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('CacheManager', () {
    test('returns null for uncached endpoints', () {
      final manager = CacheManager();
      expect(manager.get<String>('/accounts/erd1'), isNull);
    });

    test('stores and retrieves values keyed by query params', () {
      final manager = CacheManager();
      manager.put<String>(
        '/transactions',
        'tx-a',
        queryParams: <String, dynamic>{'sender': 'alice'},
      );
      manager.put<String>(
        '/transactions',
        'tx-b',
        queryParams: <String, dynamic>{'sender': 'bob'},
      );

      expect(
        manager.get<String>(
          '/transactions',
          queryParams: <String, dynamic>{'sender': 'alice'},
        ),
        'tx-a',
      );
      expect(
        manager.get<String>(
          '/transactions',
          queryParams: <String, dynamic>{'sender': 'bob'},
        ),
        'tx-b',
      );
    });

    test('query param order does not affect the cache key', () {
      final manager = CacheManager();
      manager.put<String>(
        '/txs',
        'value',
        queryParams: <String, dynamic>{'a': 1, 'b': 2},
      );

      expect(
        manager.get<String>(
          '/txs',
          queryParams: <String, dynamic>{'b': 2, 'a': 1},
        ),
        'value',
      );
    });

    test('disabled cache never stores or returns', () {
      final manager = CacheManager(defaultConfig: CacheConfig.disabled);
      manager.put<String>('/x', 'value');
      expect(manager.get<String>('/x'), isNull);
    });

    test('invalidatePattern wipes matching cache', () {
      final manager = CacheManager();
      manager.put<String>('/accounts/a', 'v1');
      manager.get<String>('/accounts/a');

      manager.invalidatePattern('/accounts');
      expect(manager.get<String>('/accounts/a'), isNull);
    });

    test('clearAll empties every cache', () {
      final manager = CacheManager();
      manager.put<String>('/one', 'a');
      manager.put<String>('/two', 'b');
      manager.clearAll();
      expect(manager.get<String>('/one'), isNull);
      expect(manager.get<String>('/two'), isNull);
    });

    test('error responses are not cached by default', () {
      final manager = CacheManager();
      manager.put<String?>('/fail', null, isError: true);
      expect(manager.get<String>('/fail'), isNull);
    });
  });
}
