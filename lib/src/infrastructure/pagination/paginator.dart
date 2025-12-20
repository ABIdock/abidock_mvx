import 'dart:async';

import '../caching/lru_cache.dart';
import '../logging/logger.dart';
import 'paged_result.dart';
import 'pagination_params.dart';

/// Configuration options for Paginator behavior.
class PaginatorConfig {
  const PaginatorConfig({
    this.enableCaching = true,
    this.cacheSize = 50,
    this.prefetch = false,
    this.cacheTTL = const Duration(minutes: 5),
    this.logger,
  });

  /// Whether to enable page caching.
  final bool enableCaching;

  /// Page cache size.
  final int cacheSize;

  /// Whether to prefetch next page automatically.
  final bool prefetch;

  /// TTL for cached pages.
  final Duration cacheTTL;

  /// Logger.
  final Logger? logger;

  /// Default configuration.
  static const PaginatorConfig defaultConfig = PaginatorConfig();

  /// Conservative configuration (less caching, no prefetch).
  static const PaginatorConfig conservative = PaginatorConfig(
    enableCaching: true,
    cacheSize: 10,
    prefetch: false,
  );

  /// Aggressive configuration (more caching, prefetch enabled).
  static const PaginatorConfig aggressive = PaginatorConfig(
    enableCaching: true,
    cacheSize: 100,
    prefetch: true,
  );
}

/// Helper for managing paginated data fetching with caching and prefetching.
/// Provides automatic page caching, navigation helpers, and streaming across pages.
class Paginator<T> {
  /// Creates paginator.
  Paginator({
    required this.fetchPage,
    required this.initialParams,
    PaginatorConfig? config,
  }) : config = config ?? PaginatorConfig.defaultConfig,
       _currentParams = initialParams,
       _cache = (config ?? PaginatorConfig.defaultConfig).enableCaching
           ? LRUCache<String, PagedResult<T>>(
               maxSize: (config ?? PaginatorConfig.defaultConfig).cacheSize,
               defaultTTL: (config ?? PaginatorConfig.defaultConfig).cacheTTL,
             )
           : null;

  /// Function to fetch a page given pagination parameters.
  final Future<PagedResult<T>> Function(PaginationParams params) fetchPage;

  /// Initial pagination parameters.
  final PaginationParams initialParams;

  /// Configuration.
  final PaginatorConfig config;

  /// Cache for pages (if caching enabled).
  final LRUCache<String, PagedResult<T>>? _cache;

  /// Current page result.
  PagedResult<T>? _currentPage;

  /// Current pagination parameters.
  PaginationParams _currentParams;

  /// Whether fetch is in progress.
  bool _isFetching = false;

  /// Gets current page (if any fetched).
  PagedResult<T>? get currentPage => _currentPage;

  /// Gets current pagination parameters.
  PaginationParams get currentParams => _currentParams;

  /// Whether currently fetching.
  bool get isFetching => _isFetching;

  /// Generates cache key for pagination parameters.
  String _cacheKey(PaginationParams params) {
    return 'page_${params.effectiveOffset}_${params.effectiveLimit}_${params.sortBy ?? 'none'}_${params.sortOrder?.name ?? 'none'}';
  }

  /// Fetches a page with the given parameters.
  Future<PagedResult<T>> _fetch(PaginationParams params) async {
    if (_isFetching) {
      throw StateError('Fetch already in progress');
    }

    _isFetching = true;

    try {
      final LRUCache<String, PagedResult<T>>? cache = _cache;
      if (cache != null) {
        final String cacheKey = _cacheKey(params);
        final PagedResult<T>? cached = cache.get(cacheKey);

        if (cached != null) {
          config.logger?.debug('Cache hit for $cacheKey');
          return cached;
        }

        config.logger?.debug('Cache miss for $cacheKey');
      }
      config.logger?.info('Fetching page: $params');
      final PagedResult<T> result = await fetchPage(params);
      final LRUCache<String, PagedResult<T>>? cacheForStore = _cache;
      if (cacheForStore != null) {
        final String cacheKey = _cacheKey(params);
        cacheForStore.put(cacheKey, result);
        config.logger?.debug('Cached $cacheKey');
      }
      if (config.prefetch && result.hasNext) {
        final PaginationParams? nextParams = result.nextParams;
        if (nextParams != null) {
          unawaited(_prefetch(nextParams));
        }
      }

      return result;
    } finally {
      _isFetching = false;
    }
  }

  /// Prefetches page in background.
  Future<void> _prefetch(PaginationParams params) async {
    try {
      config.logger?.debug('Prefetching: $params');
      await _fetch(params);
    } catch (e) {
      config.logger?.warning('Prefetch failed: $e');
    }
  }

  /// Fetches next page.
  ///
  /// #### Returns
  /// `PagedResult<T>?` - Next page result, or null if already at last page
  Future<PagedResult<T>?> nextPage() async {
    if (_currentPage != null && !_currentPage!.hasNext) {
      return null;
    }

    final PaginationParams params = _currentPage?.nextParams ?? initialParams;
    final PagedResult<T> result = await _fetch(params);

    _currentPage = result;
    _currentParams = params;

    return result;
  }

  /// Fetches previous page.
  Future<PagedResult<T>?> previousPage() async {
    if (_currentPage != null && !_currentPage!.hasPrevious) {
      return null;
    }

    final PaginationParams? params = _currentPage?.previousParams;
    if (params == null) return null;

    final PagedResult<T> result = await _fetch(params);

    _currentPage = result;
    _currentParams = params;

    return result;
  }

  /// Jumps to specific page number.
  Future<PagedResult<T>> goToPage(int page) async {
    if (!initialParams.isPageBased) {
      throw StateError('goToPage() only works with page-based pagination');
    }

    final PaginationParams params = initialParams.goToPage(page);
    final PagedResult<T> result = await _fetch(params);

    _currentPage = result;
    _currentParams = params;

    return result;
  }

  /// Resets to initial parameters.
  Future<PagedResult<T>> reset() async {
    _currentParams = initialParams;
    _currentPage = null;
    return _fetch(initialParams);
  }

  /// Streams all items across all pages.
  Stream<T> stream({int? maxPages}) async* {
    int pagesFetched = 0;
    PaginationParams params = initialParams;

    while (true) {
      if (maxPages != null && pagesFetched >= maxPages) {
        break;
      }
      final PagedResult<T> page = await _fetch(params);
      pagesFetched++;
      for (final T item in page.items) {
        yield item;
      }
      if (!page.hasNext) {
        break;
      }

      final PaginationParams? nextParams = page.nextParams;
      if (nextParams == null) {
        break;
      }

      params = nextParams;
    }
  }

  /// Fetches all items across multiple pages into a list.
  ///
  /// #### Parameters
  /// - `maxPages` - Maximum number of pages to fetch (optional)
  ///
  /// #### Returns
  /// `List<T>` - List of all items from all fetched pages
  Future<List<T>> fetchAll({int? maxPages}) async {
    final List<T> items = <T>[];

    await for (final T item in stream(maxPages: maxPages)) {
      items.add(item);
    }

    return items;
  }

  /// Clears the page cache.
  void clearCache() {
    _cache?.clear();
    config.logger?.debug('Cache cleared');
  }

  /// Gets cache statistics.
  Map<String, dynamic>? getCacheStats() {
    return _cache?.getStats();
  }

  @override
  String toString() {
    return 'Paginator<$T>(current: ${_currentPage?.toString() ?? 'none'})';
  }
}
