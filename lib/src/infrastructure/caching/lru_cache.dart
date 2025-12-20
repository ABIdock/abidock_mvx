/// LRU cache implementation with TTL expiration.
/// Automatically evicts oldest entries when at capacity and removes expired entries.
///
/// **Thread Safety:** This cache is NOT thread-safe. If accessed from multiple
/// isolates or concurrent async operations that may interleave, external
/// synchronization is required. For single-isolate async code with non-interleaving
/// operations, the cache is safe to use.
///
/// #### Example
/// ```dart
/// final cache = LRUCache<String, Account>(
///   maxSize: 100,
///   defaultTTL: Duration(minutes: 5),
/// );
///
/// // Store value
/// cache.put('erd1...', account);
///
/// // Retrieve value
/// final cached = cache.get('erd1...');
/// if (cached != null) {
///   print('Cache hit: $cached');
/// }
///
/// // Check stats
/// print('Hit rate: ${cache.hitRate}');
/// print('Size: ${cache.size}/${cache.maxSize}');
/// ```

/// Cache entry with value and expiration.
///
/// Wraps cached value with metadata including creation time, expiration,
/// access count, and last access time.
///
/// #### Example
/// ```dart
/// final entry = CacheEntry(
///   value: account,
///   createdAt: DateTime.now(),
///   expiresAt: DateTime.now().add(Duration(minutes: 5)),
/// );
///
/// print('Age: ${entry.age.inSeconds}s');
/// print('Access count: ${entry.accessCount}');
/// print('Expired: ${entry.isExpired}');
/// ```
class CacheEntry<T> {
  CacheEntry({required this.value, required this.createdAt, this.expiresAt})
    : lastAccessedAt = createdAt;

  /// Cached value.
  final T value;

  /// Entry creation time.
  final DateTime createdAt;

  /// Entry expiration time.
  final DateTime? expiresAt;

  /// Access count.
  int accessCount = 0;

  /// Last access time.
  DateTime lastAccessedAt;

  /// Entry has expired.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Entry age.
  Duration get age => DateTime.now().difference(createdAt);

  /// Records entry access.
  void recordAccess() {
    accessCount++;
    lastAccessedAt = DateTime.now();
  }
}

/// LRU cache with TTL support.
///
/// Thread-safe Least Recently Used cache with automatic expiration and eviction.
/// Maintains access order for LRU policy and tracks comprehensive statistics.
///
/// #### Example
/// ```dart
/// final cache = LRUCache<String, Account>(
///   maxSize: 50,
///   defaultTTL: Duration(minutes: 10),
/// );
/// ```
class LRUCache<K, V> {
  /// Creates LRU cache.
  ///
  /// #### Parameters
  /// - `maxSize` - Maximum number of entries
  /// - `defaultTTL` - Default time-to-live for entries
  ///
  /// #### Example
  /// ```dart
  /// // With TTL
  /// final cache = LRUCache<String, Data>(
  ///   maxSize: 100,
  ///   defaultTTL: Duration(minutes: 5),
  /// );
  ///
  /// // No expiration
  /// final permanentCache = LRUCache<int, String>(
  ///   maxSize: 1000,
  ///   defaultTTL: null,
  /// );
  /// ```
  LRUCache({this.maxSize = 100, this.defaultTTL = const Duration(minutes: 5)})
    : assert(maxSize > 0, 'maxSize must be positive');

  /// Max cache entries.
  final int maxSize;

  /// Default entry TTL.
  final Duration? defaultTTL;

  /// Cache storage.
  final Map<K, CacheEntry<V>> _cache = <K, CacheEntry<V>>{};

  /// Access order for LRU.
  final List<K> _accessOrder = <K>[];

  /// Statistics.
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _expirations = 0;

  /// Gets value from cache.
  /// Retrieves value and updates access tracking.
  ///
  /// #### Parameters
  /// - `key` - Cache key
  ///
  /// #### Returns
  /// `V?` - Cached value or null if not found/expired
  ///
  /// #### Example
  /// ```dart
  /// final value = cache.get('key123');
  /// if (value != null) {
  ///   print('Cache hit: $value');
  /// } else {
  ///   print('Cache miss');
  /// }
  /// ```
  V? get(K key) {
    final CacheEntry<V>? entry = _cache[key];

    if (entry == null) {
      _misses++;
      return null;
    }

    if (entry.isExpired) {
      _remove(key);
      _expirations++;
      _misses++;
      return null;
    }

    entry.recordAccess();
    _updateAccessOrder(key);

    _hits++;
    return entry.value;
  }

  /// Puts value into cache.
  /// Stores value with optional TTL override. Evicts LRU entry if at capacity.
  ///
  /// #### Parameters
  /// - `key` - Cache key
  /// - `value` - Value to cache
  /// - `ttl` - Optional TTL override
  ///
  /// #### Example
  /// ```dart
  /// // Use default TTL
  /// cache.put('key1', value1);
  ///
  /// // Custom TTL
  /// cache.put('key2', value2, ttl: Duration(seconds: 30));
  ///
  /// // No expiration
  /// cache.put('key3', value3, ttl: null);
  /// ```
  void put(K key, V value, {Duration? ttl}) {
    if (_cache.containsKey(key)) {
      _remove(key);
    }

    if (_cache.length >= maxSize) {
      _evictLRU();
    }

    final Duration? effectiveTTL = ttl ?? defaultTTL;
    final DateTime now = DateTime.now();
    final DateTime? expiresAt = effectiveTTL != null
        ? now.add(effectiveTTL)
        : null;

    _cache[key] = CacheEntry(
      value: value,
      createdAt: now,
      expiresAt: expiresAt,
    );

    _accessOrder.add(key);
  }

  /// Removes value from cache.
  bool remove(K key) {
    if (_cache.containsKey(key)) {
      _remove(key);
      return true;
    }
    return false;
  }

  /// Removes entry and updates access order.
  void _remove(K key) {
    _cache.remove(key);
    _accessOrder.remove(key);
  }

  /// Evicts least recently used entry.
  void _evictLRU() {
    if (_accessOrder.isEmpty) return;

    final K lruKey = _accessOrder.first;
    _remove(lruKey);
    _evictions++;
  }

  /// Updates access order for LRU.
  void _updateAccessOrder(K key) {
    _accessOrder.remove(key);
    _accessOrder.add(key);
  }

  /// Cache contains key.
  bool containsKey(K key) {
    final CacheEntry<V>? entry = _cache[key];
    if (entry == null) return false;
    if (entry.isExpired) {
      _remove(key);
      _expirations++;
      return false;
    }
    return true;
  }

  /// Clears all cache entries.
  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }

  /// Removes all expired entries.
  int removeExpired() {
    final List<K> expiredKeys = <K>[];

    for (final MapEntry<K, CacheEntry<V>> entry in _cache.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }

    for (final K key in expiredKeys) {
      _remove(key);
      _expirations++;
    }

    return expiredKeys.length;
  }

  /// Current cache size.
  int get size => _cache.length;

  /// Cache is empty.
  bool get isEmpty => _cache.isEmpty;

  /// Cache is at capacity.
  bool get isFull => _cache.length >= maxSize;

  /// Cache hit rate.
  double get hitRate {
    final int total = _hits + _misses;
    return total > 0 ? _hits / total : 0.0;
  }

  /// Gets cache stats.
  Map<String, dynamic> getStats() {
    final int totalRequests = _hits + _misses;

    return <String, dynamic>{
      'size': size,
      'maxSize': maxSize,
      'utilization': size / maxSize,
      'hits': _hits,
      'misses': _misses,
      'evictions': _evictions,
      'expirations': _expirations,
      'totalRequests': totalRequests,
      'hitRate': hitRate,
    };
  }

  /// Resets stats.
  void resetStats() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    _expirations = 0;
  }

  /// All cache keys.
  List<K> get keys => List.unmodifiable(_cache.keys);

  /// Gets detailed entry information.
  Map<K, Map<String, dynamic>> getEntryDetails() {
    return Map.fromEntries(
      _cache.entries.map(
        (MapEntry<K, CacheEntry<V>> e) => MapEntry(e.key, <String, dynamic>{
          'age': e.value.age.inSeconds,
          'accessCount': e.value.accessCount,
          'lastAccessed': e.value.lastAccessedAt.toIso8601String(),
          'expiresAt': e.value.expiresAt?.toIso8601String(),
          'isExpired': e.value.isExpired,
        }),
      ),
    );
  }
}
