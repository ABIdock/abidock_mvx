/// Batch operation helper for concurrent processing with control.
/// Executes batch operations with configurable concurrency, error handling, timeouts, and progress tracking.
import 'dart:async';

import '../logging/logger.dart';
import 'batch_result.dart';

/// Batch operation configuration.
/// Configures concurrency limits, error handling, timeouts, and delays with preset options.
///
/// #### Example
/// ```dart
/// // Custom config
/// final config = BatchConfig(
///   maxConcurrency: 8,
///   stopOnError: true,
///   operationTimeout: Duration(seconds: 30),
///   batchDelay: Duration(milliseconds: 50),
/// );
///
/// // Use preset
/// final safeConfig = BatchConfig.conservative;
/// ```
class BatchConfig {
  const BatchConfig({
    this.maxConcurrency = 10,
    this.stopOnError = false,
    this.operationTimeout = const Duration(seconds: 5),
    this.batchDelay,
  }) : assert(maxConcurrency > 0, 'maxConcurrency must be positive');

  /// Max concurrent requests.
  final int maxConcurrency;

  /// Stop on first error.
  final bool stopOnError;

  /// Operation timeout.
  final Duration? operationTimeout;

  /// Delay between batches.
  final Duration? batchDelay;

  /// Default config.
  static const BatchConfig defaultConfig = BatchConfig();

  /// Conservative config (slower, safer).
  static const BatchConfig conservative = BatchConfig(
    maxConcurrency: 5,
    batchDelay: Duration(milliseconds: 50),
    operationTimeout: Duration(seconds: 10),
  );

  /// Aggressive config (faster, may hit limits).
  static const BatchConfig aggressive = BatchConfig(
    maxConcurrency: 20,
    operationTimeout: Duration(seconds: 3),
  );
}

/// Executes batch operations with concurrency control.
/// Manages parallel execution with configurable limits, error handling, and progress tracking.
///
/// #### Example
/// ```dart
/// final helper = BatchHelper(
///   config: BatchConfig.defaultConfig,
///   logger: consoleLogger,
/// );
/// ```
class BatchHelper {
  /// Creates batch helper.
  ///
  /// #### Parameters
  /// - `config` - Batch configuration
  /// - `logger` - Optional logger
  ///
  /// #### Example
  /// ```dart
  /// final helper = BatchHelper(
  ///   config: BatchConfig(maxConcurrency: 3, stopOnError: true),
  ///   logger: myLogger,
  /// );
  /// ```
  BatchHelper({this.config = BatchConfig.defaultConfig, this.logger});

  /// Batch config.
  final BatchConfig config;

  /// Logger.
  final Logger? logger;

  /// Executes batch operation on items.
  /// Processes items with specified operation, respecting concurrency limits and error handling.
  ///
  /// #### Parameters
  /// - `items` - List of items to process
  /// - `operation` - Async function to execute on each item
  /// - `getId` - Optional function to extract ID from item
  /// - `onProgress` - Optional callback for progress updates
  ///
  /// #### Returns
  /// `BatchResult<R>` - Results for all items
  ///
  /// #### Example
  /// ```dart
  /// final addresses = [address1, address2, address3];
  /// final result = await helper.execute<Address, Account>(
  ///   items: addresses,
  ///   operation: (addr) => provider.getAccount(addr),
  ///   getId: (addr) => addr.bech32,
  ///   onProgress: (completed, total) {
  ///     print('Progress: $completed/$total');
  ///   },
  /// );
  ///
  /// for (final item in result.items) {
  ///   if (item.isSuccess) {
  ///     print('${item.id}: ${item.data}');
  ///   } else {
  ///     print('${item.id} failed: ${item.error}');
  ///   }
  /// }
  /// ```
  Future<BatchResult<R>> execute<T, R>({
    required List<T> items,
    required Future<R> Function(T item) operation,
    String Function(T item)? getId,
    void Function(int completed, int total)? onProgress,
  }) async {
    if (items.isEmpty) {
      logger?.debug('Batch execute: no items to process');
      return BatchResult<R>(<BatchItemResult<R>>[]);
    }

    final String Function(T item) idExtractor =
        getId ?? (item) => item.toString();
    final List<BatchItemResult<R>> results = <BatchItemResult<R>>[];
    final _Semaphore semaphore = _Semaphore(config.maxConcurrency);
    int completed = 0;
    bool shouldStop = false;

    logger?.info(
      'Batch execute started',
      context: <String, dynamic>{
        'itemCount': items.length,
        'maxConcurrency': config.maxConcurrency,
        'stopOnError': config.stopOnError,
      },
    );

    final DateTime startTime = DateTime.now();

    final List<Future<BatchItemResult<R>>> futures = items.map((item) async {
      if (shouldStop) {
        final String id = idExtractor(item);
        return BatchItemResult<R>.failure(
          id,
          Exception('Batch stopped due to previous error'),
        );
      }
      await semaphore.acquire();

      try {
        final String id = idExtractor(item);

        logger?.debug(
          'Batch item starting',
          context: <String, dynamic>{'id': id},
        );
        final R result = await _executeWithTimeout(
          operation: () => operation(item),
          timeout: config.operationTimeout,
        );

        final BatchItemResult<R> itemResult = BatchItemResult<R>.success(
          id,
          result,
        );

        completed++;
        onProgress?.call(completed, items.length);

        logger?.debug(
          'Batch item completed',
          context: <String, dynamic>{
            'id': id,
            'completed': completed,
            'total': items.length,
          },
        );

        return itemResult;
      } catch (error, stackTrace) {
        final String id = idExtractor(item);
        completed++;
        onProgress?.call(completed, items.length);

        logger?.warning(
          'Batch item failed',
          context: <String, dynamic>{
            'id': id,
            'error': error.toString(),
            'completed': completed,
            'total': items.length,
          },
        );

        if (config.stopOnError) {
          shouldStop = true;
        }

        return BatchItemResult<R>.failure(id, error, stackTrace);
      } finally {
        semaphore.release();

        if (config.batchDelay != null && completed < items.length) {
          await Future<void>.delayed(config.batchDelay!);
        }
      }
    }).toList();

    results.addAll(await Future.wait(futures));

    final Duration duration = DateTime.now().difference(startTime);

    logger?.info(
      'Batch execute completed',
      context: <String, dynamic>{
        'total': results.length,
        'success': results.where((BatchItemResult<R> r) => r.isSuccess).length,
        'failed': results.where((BatchItemResult<R> r) => r.isFailed).length,
        'duration': '${duration.inMilliseconds}ms',
      },
    );

    return BatchResult<R>(results);
  }

  /// Executes batch operation with chunking.
  /// Processes items in chunks for large datasets or memory constraints.
  ///
  /// #### Parameters
  /// - `items` - List of items to process
  /// - `chunkSize` - Number of items per chunk
  /// - `operation` - Async function to execute on each item
  /// - `getId` - Optional function to extract ID from item
  /// - `onChunkComplete` - Optional callback after each chunk
  ///
  /// #### Returns
  /// `BatchResult<R>` - Results from all chunks
  ///
  /// #### Example
  /// ```dart
  /// final largeList = List.generate(1000, (i) => 'item$i');
  /// final result = await helper.executeChunked<String, String>(
  ///   items: largeList,
  ///   chunkSize: 100, // Process 100 items at a time
  ///   operation: (item) => processItem(item),
  ///   onChunkComplete: (chunk, total) {
  ///     print('Completed chunk $chunk/$total');
  ///   },
  /// );
  ///
  /// print('Processed ${result.successCount} items successfully');
  /// ```
  Future<BatchResult<R>> executeChunked<T, R>({
    required List<T> items,
    required int chunkSize,
    required Future<R> Function(T item) operation,
    String Function(T item)? getId,
    void Function(int chunkIndex, int totalChunks)? onChunkComplete,
  }) async {
    if (items.isEmpty) {
      return BatchResult<R>(<BatchItemResult<R>>[]);
    }

    final List<List<T>> chunks = _createChunks(items, chunkSize);
    final List<BatchItemResult<R>> allResults = <BatchItemResult<R>>[];

    logger?.info(
      'Batch execute chunked',
      context: <String, dynamic>{
        'itemCount': items.length,
        'chunkSize': chunkSize,
        'totalChunks': chunks.length,
      },
    );

    for (int i = 0; i < chunks.length; i++) {
      final List<T> chunk = chunks[i];

      logger?.debug(
        'Processing chunk',
        context: <String, dynamic>{
          'chunkIndex': i + 1,
          'totalChunks': chunks.length,
          'chunkSize': chunk.length,
        },
      );

      final BatchResult<R> chunkResult = await execute(
        items: chunk,
        operation: operation,
        getId: getId,
      );

      allResults.addAll(chunkResult.items);
      onChunkComplete?.call(i + 1, chunks.length);

      if (config.stopOnError && chunkResult.failureCount > 0) {
        logger?.warning('Stopping chunked batch due to errors');
        break;
      }
    }

    return BatchResult<R>(allResults);
  }

  /// Executes operation with timeout.
  Future<R> _executeWithTimeout<R>({
    required Future<R> Function() operation,
    Duration? timeout,
  }) async {
    if (timeout == null) {
      return operation();
    }

    return operation().timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'Operation timed out after ${timeout.inSeconds}s',
      ),
    );
  }

  /// Creates chunks from list.
  List<List<T>> _createChunks<T>(List<T> items, int chunkSize) {
    final List<List<T>> chunks = <List<T>>[];
    for (int i = 0; i < items.length; i += chunkSize) {
      final int end = (i + chunkSize < items.length)
          ? i + chunkSize
          : items.length;
      chunks.add(items.sublist(i, end));
    }
    return chunks;
  }
}

/// Semaphore for concurrency control.
class _Semaphore {
  _Semaphore(this._maxCount);
  final int _maxCount;
  int _currentCount = 0;
  final List<Completer<void>> _waiters = <Completer<void>>[];

  Future<void> acquire() async {
    if (_currentCount < _maxCount) {
      _currentCount++;
      return;
    }

    final Completer<void> completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      final Completer<void> completer = _waiters.removeAt(0);
      completer.complete();
    } else {
      _currentCount--;
    }
  }
}
