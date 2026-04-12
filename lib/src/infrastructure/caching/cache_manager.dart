/// API response caching with TTL and per-endpoint configuration.
/// Manages LRU caches for API endpoints with pattern-based configuration and statistics.
///
/// #### Example
/// ```dart
/// final cacheManager = CacheManager(
///   defaultConfig: CacheConfig.medium,
///   endpointConfigs: {
///     '/network/config': CacheConfig.long, // 30 min
///     '/accounts': CacheConfig.short, // 1 min
///   },
/// );
///
/// // Get cached response
/// final cached = cacheManager.get<Account>('/accounts/erd1...');
/// if (cached != null) {
///   return cached; // Cache hit
/// }
///
/// // Store response
/// final account = await provider.getAccount(address);
/// cacheManager.put('/accounts/erd1...', account);
/// ```
import '../../utils/helpers.dart';
import 'lru_cache.dart';

/// Cache configuration for endpoints.
/// Defines cache behavior including TTL, size limits, and error caching.
///
/// #### Example
/// ```dart
/// // Custom config
/// final config = CacheConfig(
///   enabled: true,
///   ttl: Duration(minutes: 10),
///   maxSize: 200,
///   cacheErrors: false,
/// );
///
/// // Use preset
/// final quickConfig = CacheConfig.short;
/// ```
class CacheConfig {
  const CacheConfig({
    this.enabled = true,
    this.ttl = const Duration(minutes: 5),
    this.maxSize = 100,
    this.cacheErrors = false,
  });

  /// Caching enabled.
  final bool enabled;

  /// Time to live for cached responses.
  final Duration ttl;

  /// Max cached entries.
  final int maxSize;

  /// Cache error responses.
  final bool cacheErrors;

  /// No caching.
  static const CacheConfig disabled = CacheConfig(enabled: false);

  /// Short cache (1 min).
  static const CacheConfig short = CacheConfig(ttl: Duration(minutes: 1));

  /// Medium cache (5 min).
  static const CacheConfig medium = CacheConfig(ttl: Duration(minutes: 5));

  /// Long cache (30 min).
  static const CacheConfig long = CacheConfig(ttl: Duration(minutes: 30));
}

/// Manages API response caching.
///
/// Central cache manager supporting per-endpoint configuration, pattern matching,
/// and automatic cache instance management. Handles query parameters, TTL
/// expiration, and provides comprehensive statistics.
///
/// #### Example
/// ```dart
/// final manager = CacheManager(
///   defaultConfig: CacheConfig(ttl: Duration(minutes: 5)),
///   endpointConfigs: {
///     '/network': CacheConfig.long,
///     '/accounts': CacheConfig.short,
///   },
/// );
/// ```
class CacheManager {
  /// Creates cache manager.
  ///
  /// #### Parameters
  /// - `defaultConfig` - Default cache configuration
  /// - `endpointConfigs` - Per-endpoint cache configurations
  ///
  /// #### Example
  /// ```dart
  /// final manager = CacheManager(
  ///   defaultConfig: CacheConfig.medium,
  ///   endpointConfigs: {
  ///     '/network/config': CacheConfig.long,
  ///     '/accounts': CacheConfig(ttl: Duration(minutes: 2)),
  ///   },
  /// );
  /// ```
  CacheManager({
    this.defaultConfig = const CacheConfig(),
    this.endpointConfigs = const <String, CacheConfig>{},
  });

  /// Default cache config.
  final CacheConfig defaultConfig;

  /// Per-endpoint cache configs.
  final Map<String, CacheConfig> endpointConfigs;

  /// Maximum number of cache instances to prevent unbounded growth.
  static const int _maxCacheInstances = 100;

  /// Caches by endpoint pattern.
  final Map<String, LRUCache<String, dynamic>> _caches =
      <String, LRUCache<String, dynamic>>{};

  /// Gets cache config for endpoint.
  CacheConfig _getConfig(String endpoint) {
    if (endpointConfigs.containsKey(endpoint)) {
      return endpointConfigs[endpoint]!;
    }

    for (final String pattern in endpointConfigs.keys) {
      if (endpoint.startsWith(pattern)) {
        return endpointConfigs[pattern]!;
      }
    }

    return defaultConfig;
  }

  /// Gets cache instance for endpoint.
  ///
  /// Evicts the oldest cache instance when the limit is exceeded.
  LRUCache<String, dynamic> _getCache(String endpoint) {
    final String pattern = _extractPattern(endpoint);

    if (!_caches.containsKey(pattern)) {
      if (_caches.length >= _maxCacheInstances) {
        final String oldest = _caches.keys.first;
        _caches[oldest]!.clear();
        _caches.remove(oldest);
      }

      final CacheConfig config = _getConfig(pattern);
      _caches[pattern] = LRUCache(
        maxSize: config.maxSize,
        defaultTTL: config.ttl,
      );
    }

    return _caches[pattern]!;
  }

  /// Extracts endpoint pattern from path.
  String _extractPattern(String endpoint) {
    final String path = endpoint.split('?').first;
    final List<String> preservePatterns = <String>[
      '/network/config',
      '/network/status',
      '/network/economics',
    ];

    for (final String pattern in preservePatterns) {
      if (path == pattern) return pattern;
    }
    final List<String> segments = path
        .split('/')
        .where((String s) => s.isNotEmpty)
        .toList();
    if (segments.isEmpty) return '/';

    return '/${segments.first}';
  }

  /// Generates cache key from endpoint and params.
  String _generateKey(String endpoint, Map<String, dynamic>? queryParams) {
    if (queryParams == null || queryParams.isEmpty) {
      return endpoint;
    }
    final List<MapEntry<String, dynamic>> sortedParams =
        queryParams.entries.toList()..sort(
          (MapEntry<String, dynamic> a, MapEntry<String, dynamic> b) =>
              a.key.compareTo(b.key),
        );

    final String queryString = sortedParams
        .map((MapEntry<String, dynamic> e) => '${e.key}=${e.value}')
        .join('&');

    return '$endpoint|$queryString';
  }

  /// Gets cached response.
  /// Retrieves cached value for endpoint with optional query parameters.
  ///
  /// #### Parameters
  /// - `endpoint` - API endpoint path
  /// - `queryParams` - Optional query parameters
  ///
  /// #### Returns
  /// `T?` - Cached value or null if not found/expired
  ///
  /// #### Example
  /// ```dart
  /// // Simple endpoint
  /// final config = manager.get<NetworkConfig>('/network/config');
  ///
  /// // With query params
  /// final txs = manager.get<List<Transaction>>(
  ///   '/transactions',
  ///   queryParams: {'sender': 'erd1...', 'status': 'success'},
  /// );
  /// ```
  T? get<T>(String endpoint, {Map<String, dynamic>? queryParams}) {
    final CacheConfig config = _getConfig(endpoint);
    if (!config.enabled) return null;

    final LRUCache<String, dynamic> cache = _getCache(endpoint);
    final String key = _generateKey(endpoint, queryParams);

    return cache.get(key) as T?;
  }

  /// Stores response in cache.
  /// Caches value for endpoint with optional TTL override.
  ///
  /// #### Parameters
  /// - `endpoint` - API endpoint path
  /// - `value` - Value to cache
  /// - `queryParams` - Optional query parameters
  /// - `ttl` - Optional TTL override
  /// - `isError` - Whether this is an error response
  ///
  /// #### Example
  /// ```dart
  /// // Cache response with default TTL
  /// manager.put('/network/config', config);
  ///
  /// // Cache with custom TTL
  /// manager.put(
  ///   '/accounts/erd1...',
  ///   account,
  ///   ttl: Duration(seconds: 30),
  /// );
  ///
  /// // Cache error (only if cacheErrors=true)
  /// manager.put('/accounts/invalid', null, isError: true);
  /// ```
  void put<T>(
    String endpoint,
    T value, {
    Map<String, dynamic>? queryParams,
    Duration? ttl,
    bool isError = false,
  }) {
    final CacheConfig config = _getConfig(endpoint);
    if (!config.enabled) return;
    if (isError && !config.cacheErrors) return;

    final LRUCache<String, dynamic> cache = _getCache(endpoint);
    final String key = _generateKey(endpoint, queryParams);

    cache.put(key, value, ttl: ttl ?? config.ttl);
  }

  /// Removes cached response.
  bool remove(String endpoint, {Map<String, dynamic>? queryParams}) {
    final LRUCache<String, dynamic> cache = _getCache(endpoint);
    final String key = _generateKey(endpoint, queryParams);
    return cache.remove(key);
  }

  /// Invalidates all cached responses for pattern.
  void invalidatePattern(String pattern) {
    final LRUCache<String, dynamic>? cache = _caches[pattern];
    if (cache != null) {
      cache.clear();
    }
  }

  /// Invalidates cached responses matching predicate.
  void invalidateWhere(bool Function(String key) predicate) {
    for (final LRUCache<String, dynamic> cache in _caches.values) {
      final List<String> keysToRemove = cache.keys.where(predicate).toList();
      for (final String key in keysToRemove) {
        cache.remove(key);
      }
    }
  }

  /// Clears all caches.
  void clearAll() {
    for (final LRUCache<String, dynamic> cache in _caches.values) {
      cache.clear();
    }
  }

  /// Removes expired entries from all caches.
  int removeExpired() {
    int total = 0;
    for (final LRUCache<String, dynamic> cache in _caches.values) {
      total += cache.removeExpired();
    }
    return total;
  }

  /// Gets stats for endpoint pattern.
  Map<String, dynamic>? getStats(String pattern) {
    final LRUCache<String, dynamic>? cache = _caches[pattern];
    return cache?.getStats();
  }

  /// Gets stats for all patterns.
  Map<String, Map<String, dynamic>> getAllStats() {
    return Map.fromEntries(
      _caches.entries.map(
        (MapEntry<String, LRUCache<String, dynamic>> e) =>
            MapEntry(e.key, e.value.getStats()),
      ),
    );
  }

  /// Gets summary of all cache stats.
  Map<String, dynamic> getSummary() {
    int totalSize = 0;
    int totalMaxSize = 0;
    int totalHits = 0;
    int totalMisses = 0;
    int totalEvictions = 0;
    int totalExpirations = 0;

    for (final LRUCache<String, dynamic> cache in _caches.values) {
      final Map<String, dynamic> stats = cache.getStats();
      totalSize += requireAs<int>(stats['size'], 'size');
      totalMaxSize += requireAs<int>(stats['maxSize'], 'maxSize');
      totalHits += requireAs<int>(stats['hits'], 'hits');
      totalMisses += requireAs<int>(stats['misses'], 'misses');
      totalEvictions += requireAs<int>(stats['evictions'], 'evictions');
      totalExpirations += requireAs<int>(stats['expirations'], 'expirations');
    }

    final int totalRequests = totalHits + totalMisses;
    final double hitRate = totalRequests > 0 ? totalHits / totalRequests : 0.0;

    return <String, dynamic>{
      'endpointCount': _caches.length,
      'totalSize': totalSize,
      'totalMaxSize': totalMaxSize,
      'totalUtilization': totalMaxSize > 0 ? totalSize / totalMaxSize : 0.0,
      'totalHits': totalHits,
      'totalMisses': totalMisses,
      'totalEvictions': totalEvictions,
      'totalExpirations': totalExpirations,
      'totalRequests': totalRequests,
      'hitRate': hitRate,
    };
  }

  /// Resets stats for all caches.
  void resetStats() {
    for (final LRUCache<String, dynamic> cache in _caches.values) {
      cache.resetStats();
    }
  }
}
