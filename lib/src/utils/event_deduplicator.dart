import 'dart:collection';

class EventDeduplicator {
  EventDeduplicator({
    this.maxSize = 10000,
    this.ttl = const Duration(seconds: 30),
  });

  final int maxSize;
  final Duration ttl;
  final LinkedHashMap<String, DateTime> _seen =
      LinkedHashMap<String, DateTime>();

  bool shouldProcess(String txHash) {
    final now = DateTime.now();

    _cleanExpired(now);

    if (_seen.containsKey(txHash)) {
      return false;
    }

    if (_seen.length >= maxSize) {
      _seen.remove(_seen.keys.first);
    }

    _seen[txHash] = now;
    return true;
  }

  void _cleanExpired(DateTime now) {
    _seen.removeWhere((_, time) => now.difference(time) > ttl);
  }

  void reset() => _seen.clear();

  int get size => _seen.length;
}
