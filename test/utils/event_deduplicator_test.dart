import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('EventDeduplicator', () {
    test('accepts a hash the first time, rejects the second', () {
      final dedup = EventDeduplicator();
      expect(dedup.shouldProcess('abc'), isTrue);
      expect(dedup.shouldProcess('abc'), isFalse);
    });

    test('evicts oldest entry when at capacity', () {
      final dedup = EventDeduplicator(maxSize: 2);
      dedup.shouldProcess('one');
      dedup.shouldProcess('two');
      dedup.shouldProcess('three');

      expect(dedup.size, 2);
      expect(dedup.shouldProcess('two'), isFalse);
      expect(dedup.shouldProcess('three'), isFalse);
    });

    test('expires entries past TTL', () async {
      final dedup = EventDeduplicator(ttl: const Duration(milliseconds: 20));
      dedup.shouldProcess('tx');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(dedup.shouldProcess('tx'), isTrue);
    });

    test('reset clears seen set', () {
      final dedup = EventDeduplicator();
      dedup.shouldProcess('a');
      dedup.reset();
      expect(dedup.size, 0);
      expect(dedup.shouldProcess('a'), isTrue);
    });
  });
}
