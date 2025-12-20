import 'pagination_params.dart';

/// Container for paginated data with metadata and navigation.
/// Wraps page items with pagination information and navigation helpers.
class PagedResult<T> {
  /// Creates paged result with items and metadata.
  ///
  /// #### Parameters
  /// - `items` - List of items in this page
  /// - `currentPage` - Current page number (1-indexed)
  /// - `pageSize` - Number of items per page
  /// - `totalCount` - Total items across all pages (optional)
  /// - `totalPages` - Total number of pages (optional)
  /// - `params` - Pagination parameters used for this request
  PagedResult({
    required this.items,
    required this.currentPage,
    required this.pageSize,
    this.totalCount,
    this.totalPages,
    required this.params,
  });

  /// Creates paged result from API response.
  ///
  /// #### Parameters
  /// - `items` - List of items returned by API
  /// - `params` - Pagination parameters used in request
  /// - `totalCount` - Total items across all pages (if API provides it)
  ///
  /// #### Returns
  /// `PagedResult<T>` - Instance with computed page numbers and navigation info
  factory PagedResult.fromResponse({
    required List<T> items,
    required PaginationParams params,
    int? totalCount,
  }) {
    final int currentPage =
        params.page ?? ((params.offset ?? 0) ~/ params.effectiveLimit) + 1;
    final int pageSize = params.effectiveLimit;
    final int? totalPages = totalCount != null
        ? (totalCount / pageSize).ceil()
        : null;

    return PagedResult(
      items: items,
      currentPage: currentPage,
      pageSize: pageSize,
      totalCount: totalCount,
      totalPages: totalPages,
      params: params,
    );
  }

  /// Items in this page.
  final List<T> items;

  /// Current page number (1-indexed).
  final int currentPage;

  /// Items per page.
  final int pageSize;

  /// Total items across all pages (if known).
  final int? totalCount;

  /// Total pages (if known).
  final int? totalPages;

  /// Pagination parameters for this request.
  final PaginationParams params;

  /// Whether this is first page.
  bool get isFirst => currentPage == 1;

  /// Whether this is last page.
  bool get isLast {
    if (totalPages != null) {
      return currentPage >= totalPages!;
    }
    return items.length < pageSize;
  }

  /// Whether there is next page.
  bool get hasNext => !isLast;

  /// Whether there is previous page.
  bool get hasPrevious => currentPage > 1;

  /// Whether page is empty.
  bool get isEmpty => items.isEmpty;

  /// Whether page has items.
  bool get isNotEmpty => items.isNotEmpty;

  /// Number of items in page.
  int get length => items.length;

  /// Estimated progress (0.0 to 1.0) if totalCount known.
  double? get progress {
    if (totalCount == null) return null;
    final int itemsSoFar = (currentPage - 1) * pageSize + items.length;
    return (itemsSoFar / totalCount!).clamp(0.0, 1.0);
  }

  /// Maps items to new type.
  PagedResult<R> map<R>(R Function(T item) mapper) {
    return PagedResult<R>(
      items: items.map(mapper).toList(),
      currentPage: currentPage,
      pageSize: pageSize,
      totalCount: totalCount,
      totalPages: totalPages,
      params: params,
    );
  }

  /// Creates pagination parameters for next page.
  PaginationParams? get nextParams {
    if (!hasNext) return null;
    return params.next();
  }

  /// Creates pagination parameters for previous page.
  PaginationParams? get previousParams {
    if (!hasPrevious) return null;
    return params.previous();
  }

  /// Gets item by index.
  T operator [](int index) => items[index];

  /// Creates a copy with updated fields.
  PagedResult<T> copyWith({
    List<T>? items,
    int? currentPage,
    int? pageSize,
    int? totalCount,
    int? totalPages,
    PaginationParams? params,
  }) {
    return PagedResult<T>(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      totalCount: totalCount ?? this.totalCount,
      totalPages: totalPages ?? this.totalPages,
      params: params ?? this.params,
    );
  }

  @override
  String toString() {
    final String total = totalCount != null ? '/$totalCount' : '';
    final String pages = totalPages != null
        ? ' (page $currentPage/$totalPages)'
        : ' (page $currentPage)';
    return 'PagedResult<$T>(${items.length}$total items$pages)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PagedResult<T> &&
          runtimeType == other.runtimeType &&
          items == other.items &&
          currentPage == other.currentPage &&
          pageSize == other.pageSize &&
          totalCount == other.totalCount &&
          totalPages == other.totalPages;

  @override
  int get hashCode =>
      Object.hash(items, currentPage, pageSize, totalCount, totalPages);
}
