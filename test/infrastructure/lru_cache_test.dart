import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('LRUCache', () {
    test('stores and retrieves values', () {
      final cache = LRUCache<String, int>(maxSize: 5);
      cache.put('a', 1);
      expect(cache.get('a'), 1);
      expect(cache.size, 1);
    });

    test('returns null for missing keys and counts misses', () {
      final cache = LRUCache<String, int>(maxSize: 5);
      expect(cache.get('missing'), isNull);
      expect(cache.getStats()['misses'], 1);
    });

    test('evicts the least-recently-used entry when full', () {
      final cache = LRUCache<String, int>(maxSize: 3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);

      cache.get('a');
      cache.put('d', 4);

      expect(cache.containsKey('a'), isTrue);
      expect(cache.containsKey('b'), isFalse);
      expect(cache.containsKey('c'), isTrue);
      expect(cache.containsKey('d'), isTrue);
      expect(cache.getStats()['evictions'], 1);
    });

    test('expires entries past their TTL', () async {
      final cache = LRUCache<String, int>(
        maxSize: 5,
        defaultTTL: const Duration(milliseconds: 20),
      );
      cache.put('a', 1);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(cache.get('a'), isNull);
      expect(cache.getStats()['expirations'], 1);
    });

    test('put overrides existing entry value', () {
      final cache = LRUCache<String, int>(maxSize: 3);
      cache.put('a', 1);
      cache.put('a', 2);
      expect(cache.get('a'), 2);
      expect(cache.size, 1);
    });

    test('remove returns false for missing keys', () {
      final cache = LRUCache<String, int>(maxSize: 3);
      expect(cache.remove('missing'), isFalse);
      cache.put('a', 1);
      expect(cache.remove('a'), isTrue);
      expect(cache.containsKey('a'), isFalse);
    });

    test('removeExpired sweeps all expired entries', () async {
      final cache = LRUCache<String, int>(
        maxSize: 5,
        defaultTTL: const Duration(milliseconds: 10),
      );
      cache.put('a', 1);
      cache.put('b', 2);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(cache.removeExpired(), 2);
      expect(cache.isEmpty, isTrue);
    });

    test('hit rate reflects request history', () {
      final cache = LRUCache<String, int>(maxSize: 3);
      cache.put('a', 1);
      cache.get('a');
      cache.get('a');
      cache.get('missing');

      expect(cache.hitRate, closeTo(2 / 3, 0.01));
    });

    test('clear wipes cache but leaves stats intact', () {
      final cache = LRUCache<String, int>(maxSize: 3);
      cache.put('a', 1);
      cache.get('a');
      cache.clear();

      expect(cache.isEmpty, isTrue);
      expect(cache.getStats()['hits'], 1);
    });

    test('resetStats zeros counters', () {
      final cache = LRUCache<String, int>(maxSize: 3);
      cache.put('a', 1);
      cache.get('a');
      cache.get('missing');
      cache.resetStats();

      expect(cache.getStats()['hits'], 0);
      expect(cache.getStats()['misses'], 0);
    });
  });
}
