---
id: infrastructure
title: Infrastructure Utilities
sidebar_position: 5
description: Circuit breakers, batch operations, caching, and pagination utilities for MultiversX apps.
---

# Infrastructure Utilities

Utilities for resilience, batching, caching, and pagination.

## Circuit Breaker

Protects your application from cascading failures when external services are down.

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  final circuitBreaker = CircuitBreaker(
    failureThreshold: 3,       // Open after 3 consecutive failures
    timeout: Duration(seconds: 10),
    retryDelay: Duration(seconds: 15),
    onOpen: () => print('Circuit opened - service unavailable'),
    onClose: () => print('Circuit closed - service recovered'),
    onHalfOpen: () => print('Circuit half-open - testing recovery'),
  );

  final provider = GatewayNetworkProvider.devnet();
  final address = Address.fromBech32('erd1...');

  try {
    final account = await circuitBreaker.execute(
      () => provider.getAccount(address),
    );
    print('Balance: ${account.balance}');
  } on CircuitBreakerOpenException catch (e) {
    print('Service unavailable: ${e.message}');
    print('Retry after: ${e.retryDelay}');
  }
}
```

### Circuit States

| State | Description |
|-------|-------------|
| `closed` | Normal operation, requests pass through |
| `open` | Service failing, requests rejected immediately |
| `halfOpen` | Testing recovery, single request allowed |

### Monitoring

```dart
// Check circuit state
print('State: ${circuitBreaker.state}');
print('Failures: ${circuitBreaker.failureCount}');
print('Is open: ${circuitBreaker.isOpen}');

// Get statistics
final stats = circuitBreaker.getStats();
print('Stats: $stats');

// Manual reset
circuitBreaker.reset();
```

## Batch Helper

Execute operations on multiple items with controlled concurrency.

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  final helper = BatchHelper(
    config: BatchConfig(
      maxConcurrency: 5,        // Max parallel requests
      stopOnError: false,       // Continue on failures
      operationTimeout: Duration(seconds: 10),
      batchDelay: Duration(milliseconds: 50),
    ),
  );

  final provider = GatewayNetworkProvider.devnet();
  final addresses = [
    Address.fromBech32('erd1...'),
    Address.fromBech32('erd1...'),
    Address.fromBech32('erd1...'),
  ];

  // Fetch all accounts in parallel
  final result = await helper.execute<Address, AccountOnNetwork>(
    items: addresses,
    operation: (address) => provider.getAccount(address),
    getId: (address) => address.bech32,
    onProgress: (completed, total) {
      print('Progress: $completed/$total');
    },
  );

  // Process results
  print('Success: ${result.successCount}/${result.totalCount}');
  
  for (final item in result.items) {
    if (item.isSuccess) {
      print('${item.id}: ${item.data!.balance}');
    } else {
      print('${item.id} failed: ${item.error}');
    }
  }
}
```

### Preset Configurations

```dart
// Conservative (slower, safer)
final conservative = BatchConfig.conservative;
// maxConcurrency: 5, batchDelay: 50ms, timeout: 10s

// Aggressive (faster, may hit rate limits)
final aggressive = BatchConfig.aggressive;
// maxConcurrency: 20, timeout: 3s

// Default
final defaultConfig = BatchConfig.defaultConfig;
// maxConcurrency: 10, timeout: 5s
```

### Batch Results

```dart
final result = await helper.execute<Address, AccountOnNetwork>(
  items: addresses,
  operation: (address) => provider.getAccount(address),
  getId: (address) => address.bech32,
);

// Summary
print('Total: ${result.totalCount}');
print('Success: ${result.successCount}');
print('Failed: ${result.failureCount}');
print('Success rate: ${(result.successRate * 100).toStringAsFixed(1)}%');

// Get only successful results
final successfulItems = result.successes;

// Get only failed results  
final failedItems = result.failures;
```

## Cache Manager

Caching with TTL and per-endpoint configuration.

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  final cacheManager = CacheManager(
    defaultConfig: CacheConfig.medium, // 5 min TTL
    endpointConfigs: {
      '/network/config': CacheConfig.long,   // 30 min (rarely changes)
      '/accounts': CacheConfig.short,         // 1 min (changes often)
    },
  );

  // Check cache first
  final cached = cacheManager.get<AccountOnNetwork>('/accounts/erd1...');
  if (cached != null) {
    print('Cache hit: ${cached.balance}');
    return;
  }

  // Fetch and store
  final provider = GatewayNetworkProvider.devnet();
  final account = await provider.getAccount(Address.fromBech32('erd1...'));
  cacheManager.put('/accounts/erd1...', account);
}
```

### Cache Presets

| Preset | TTL | Use Case |
|--------|-----|----------|
| `CacheConfig.disabled` | - | No caching |
| `CacheConfig.short` | 1 min | Accounts, balances |
| `CacheConfig.medium` | 5 min | Token lists |
| `CacheConfig.long` | 30 min | Network config |

### Custom Configuration

```dart
final config = CacheConfig(
  enabled: true,
  ttl: Duration(minutes: 10),
  maxSize: 200,           // Max entries
  cacheErrors: false,     // Don't cache errors
);
```

### Cache Statistics

```dart
// Get summary of all caches
final summary = cacheManager.getSummary();
print('Total entries: ${summary['totalSize']}');
print('Hit rate: ${(summary['hitRate'] * 100).toStringAsFixed(1)}%');

// Get stats for specific pattern
final accountStats = cacheManager.getStats('/accounts');

// Remove specific entry
cacheManager.remove('/accounts/erd1...');

// Invalidate all entries matching pattern
cacheManager.invalidatePattern('/accounts');

// Clear all caches
cacheManager.clearAll();
```

## Paginator

Navigate paginated API responses with automatic caching and prefetching.

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  final provider = ApiNetworkProvider.devnet();
  final address = Address.fromBech32('erd1...');

  final paginator = Paginator<TokenOnNetwork>(
    initialParams: PaginationParams.offset(offset: 0, limit: 10),
    fetchPage: (params) async {
      // Provider methods take plain from/size; PaginationParams exposes both
      // as effectiveOffset / effectiveLimit whichever style you started from.
      final tokens = await provider.getFungibleTokensOfAccount(
        address,
        from: params.effectiveOffset,
        size: params.effectiveLimit,
      );
      return PagedResult<TokenOnNetwork>.fromResponse(
        items: tokens,
        params: params,
        totalCount: tokens.length,
      );
    },
    config: PaginatorConfig(
      enableCaching: true,
      prefetch: true,       // Auto-fetch next page
      cacheSize: 50,
    ),
  );

  // Fetch first page (reset to beginning)
  final firstPage = await paginator.reset();
  print('First page: ${firstPage.items.length} tokens');

  // Navigate pages
  while (paginator.currentPage?.hasNext ?? false) {
    final nextPage = await paginator.nextPage();
    print('Page: ${nextPage?.items.length} tokens');
  }

  // Go back
  final prevPage = await paginator.previousPage();

  // Jump to specific page (page-based only)
  final page5 = await paginator.goToPage(5);
}
```

### Streaming All Pages

```dart
// Stream all items across pages
await for (final token in paginator.stream()) {
  print('Token: ${token.identifier}');
}

// Fetch all at once (with optional page limit)
final allTokens = await paginator.fetchAll(maxPages: 10);
print('Total tokens: ${allTokens.length}');
```

### Pagination Parameters

```dart
// Offset-based pagination
final offsetParams = PaginationParams.offset(
  offset: 0,           // Starting offset
  limit: 25,           // Items per page
  sortBy: 'balance',   // Sort field
  sortOrder: SortOrder.descending, // or SortOrder.ascending
);

// Page-based pagination
final pageParams = PaginationParams.page(
  page: 1,             // Page number (1-indexed)
  size: 25,            // Items per page
);
```

### Paginator Presets

```dart
// Conservative (less memory)
final config = PaginatorConfig.conservative;
// cacheSize: 10, prefetch: false

// Aggressive (faster navigation)
final config = PaginatorConfig.aggressive;
// cacheSize: 100, prefetch: true
```

## Retry Helper

Automatic retry with exponential backoff for transient failures.

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  final retryHelper = RetryHelper(
    config: RetryConfig(
      maxRetries: 3,
      initialDelay: Duration(seconds: 1),
      maxDelay: Duration(seconds: 30),
      backoffMultiplier: 2.0,
      timeout: Duration(seconds: 10),
    ),
  );

  final provider = GatewayNetworkProvider.devnet();
  final address = Address.fromBech32('erd1...');

  final account = await retryHelper.execute(
    operation: () => provider.getAccount(address),
    isRetryable: (error) => error is TimeoutException || error is NetworkException,
    operationName: 'getAccount',
    context: {'address': address.bech32},
  );

  print('Balance: ${account.balance}');
}
```

### Retry Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `maxRetries` | 3 | Maximum retry attempts |
| `initialDelay` | 1s | Delay before first retry |
| `maxDelay` | 30s | Maximum delay cap |
| `backoffMultiplier` | 2.0 | Exponential backoff factor |
| `jitterFactor` | 0.1 | Random jitter factor (0.0 - 1.0) to prevent thundering herd |
| `timeout` | 30s | Timeout per attempt |

## Combining Utilities

Example using multiple utilities together:

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  // Circuit breaker for resilience
  final circuitBreaker = CircuitBreaker(
    failureThreshold: 3,
    retryDelay: Duration(seconds: 30),
  );

  // Cache for performance
  final cache = CacheManager(
    defaultConfig: CacheConfig.medium,
  );

  // Batch helper for bulk operations
  final batchHelper = BatchHelper(
    config: BatchConfig.conservative,
  );

  final provider = GatewayNetworkProvider.devnet();

  Future<AccountOnNetwork> getAccountCached(Address address) async {
    final key = '/accounts/${address.bech32}';
    
    // Check cache
    final cached = cache.get<AccountOnNetwork>(key);
    if (cached != null) return cached;
    
    // Fetch with circuit breaker
    final account = await circuitBreaker.execute(
      () => provider.getAccount(address),
    );
    
    // Store in cache
    cache.put(key, account);
    return account;
  }

  // Batch fetch with caching and resilience
  final addresses = <Address>[
    Address.fromBech32('erd1...'),
    Address.fromBech32('erd1...'),
  ];
  final result = await batchHelper.execute<Address, AccountOnNetwork>(
    items: addresses,
    operation: getAccountCached,
    getId: (addr) => addr.bech32,
  );

  print('Fetched ${result.successCount} accounts');
}
```
