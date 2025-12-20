/// Batch processing results and statistics.
/// Container classes for batch operation results with successes, failures, and metrics.

/// Batch item result (success or failure).
/// Represents outcome of a single batch item with data or error.
class BatchItemResult<T> {
  BatchItemResult._({required this.id, this.data, this.error, this.stackTrace});

  /// Creates successful result.
  ///
  /// #### Parameters
  /// - `id` - Unique identifier for the item
  /// - `data` - Successful result data
  ///
  /// #### Returns
  /// `BatchItemResult<T>` - Result with data and no error
  ///
  /// #### Example
  /// ```dart
  /// final result = BatchItemResult.success('addr123', account);
  /// ```
  factory BatchItemResult.success(String id, T data) {
    return BatchItemResult._(id: id, data: data);
  }

  /// Creates failed result.
  ///
  /// #### Parameters
  /// - `id` - Unique identifier for the item
  /// - `error` - Error that occurred
  /// - `stackTrace` - Optional stack trace
  ///
  /// #### Returns
  /// `BatchItemResult<T>` - Result with error and no data
  ///
  /// #### Example
  /// ```dart
  /// try {
  ///   final data = await operation(item);
  ///   return BatchItemResult.success(id, data);
  /// } catch (e, stack) {
  ///   return BatchItemResult.failure(id, e, stack);
  /// }
  /// ```
  factory BatchItemResult.failure(
    String id,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    return BatchItemResult._(id: id, error: error, stackTrace: stackTrace);
  }

  /// Batch item ID.
  final String id;

  /// Result data.
  final T? data;

  /// Error if failed.
  final Object? error;

  /// Stack trace if failed.
  final StackTrace? stackTrace;

  /// Item succeeded.
  bool get isSuccess => error == null;

  /// Item failed.
  bool get isFailed => error != null;

  @override
  String toString() {
    if (isSuccess) {
      return 'BatchItemResult.success($id)';
    }
    return 'BatchItemResult.failure($id, $error)';
  }
}

/// Batch operation result with all item results.
/// Aggregates results from batch operation with successes, failures, and statistics.
///
/// #### Example
/// ```dart
/// final result = BatchResult([
///   BatchItemResult.success('item1', data1),
///   BatchItemResult.failure('item2', error),
///   BatchItemResult.success('item3', data3),
/// ]);
///
/// print('Total: ${result.totalCount}');
/// print('Success: ${result.successCount}');
/// print('Failed: ${result.failureCount}');
/// print('Success rate: ${result.successRate}');
///
/// // Check specific item
/// final item2Data = result.getDataById('item2'); // null (failed)
/// final item2Error = result.getErrorById('item2'); // error object
/// ```
class BatchResult<T> {
  /// Creates batch result.
  ///
  /// #### Parameters
  /// - `items` - List of all item results
  ///
  /// #### Example
  /// ```dart
  /// final result = BatchResult(itemResults);
  /// ```
  BatchResult(this.items);

  /// All item results.
  final List<BatchItemResult<T>> items;

  /// Successful results.
  List<BatchItemResult<T>> get successes =>
      items.where((BatchItemResult<T> item) => item.isSuccess).toList();

  /// Failed results.
  List<BatchItemResult<T>> get failures =>
      items.where((BatchItemResult<T> item) => item.isFailed).toList();

  /// Successful data values.
  List<T> get successData =>
      successes.map((BatchItemResult<T> item) => item.data!).toList();

  /// All errors.
  List<Object> get errors =>
      failures.map((BatchItemResult<T> item) => item.error!).toList();

  /// Successful item count.
  int get successCount => successes.length;

  /// Failed item count.
  int get failureCount => failures.length;

  /// Total item count.
  int get totalCount => items.length;

  /// All items succeeded.
  bool get allSucceeded => failureCount == 0;

  /// All items failed.
  bool get allFailed => successCount == 0;

  /// Partial success.
  bool get partialSuccess => successCount > 0 && failureCount > 0;

  /// Success rate (0.0-1.0).
  double get successRate => totalCount > 0 ? successCount / totalCount : 0.0;

  /// Gets result by ID.
  BatchItemResult<T>? getById(String id) {
    try {
      return items.firstWhere((BatchItemResult<T> item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Gets successful data by ID.
  T? getDataById(String id) {
    final BatchItemResult<T>? result = getById(id);
    return result?.data;
  }

  /// Gets error by ID.
  Object? getErrorById(String id) {
    final BatchItemResult<T>? result = getById(id);
    return result?.error;
  }

  @override
  String toString() {
    return 'BatchResult(total: $totalCount, success: $successCount, failed: $failureCount)';
  }
}
