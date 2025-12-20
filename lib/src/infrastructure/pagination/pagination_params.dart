/// Parameters for pagination requests.
///
/// Supports two pagination styles: page-based (page number + items per page)
/// and offset-based (starting index + limit).
class PaginationParams {
  /// Creates pagination parameters (use named constructors instead).
  const PaginationParams({
    this.page,
    this.size,
    this.offset,
    this.limit,
    this.sortBy,
    this.sortOrder,
    this.filters,
  }) : assert(
         (page != null && size != null && offset == null && limit == null) ||
             (offset != null && limit != null && page == null && size == null),
         'Use either page/size OR offset/limit, not both',
       );

  /// Creates page-based pagination parameters.
  ///
  /// #### Parameters
  /// - `page` - Page number (1 for first page)
  /// - `size` - Items per page (default 25)
  /// - `sortBy` - Field name to sort by (optional)
  /// - `sortOrder` - Sort direction (optional)
  /// - `filters` - Additional filter parameters (optional)
  const PaginationParams.page({
    required int page,
    int size = 25,
    String? sortBy,
    SortOrder? sortOrder,
    Map<String, dynamic>? filters,
  }) : this(
         page: page,
         size: size,
         sortBy: sortBy,
         sortOrder: sortOrder,
         filters: filters,
       );

  /// Creates offset-based pagination parameters.
  ///
  /// #### Parameters
  /// - `offset` - Starting item index (0 for first item)
  /// - `limit` - Maximum items to return (default 25)
  /// - `sortBy` - Field name to sort by (optional)
  /// - `sortOrder` - Sort direction (optional)
  /// - `filters` - Additional filter parameters (optional)
  const PaginationParams.offset({
    required int offset,
    int limit = 25,
    String? sortBy,
    SortOrder? sortOrder,
    Map<String, dynamic>? filters,
  }) : this(
         offset: offset,
         limit: limit,
         sortBy: sortBy,
         sortOrder: sortOrder,
         filters: filters,
       );

  /// Page number (1-indexed). Mutually exclusive with offset.
  final int? page;

  /// Items per page. Used with page.
  final int? size;

  /// Offset index (0-indexed). Mutually exclusive with page.
  final int? offset;

  /// Maximum items to return. Used with offset.
  final int? limit;

  /// Field to sort by.
  final String? sortBy;

  /// Sort order.
  final SortOrder? sortOrder;

  /// Additional filters.
  final Map<String, dynamic>? filters;

  /// Whether uses page-based pagination.
  bool get isPageBased => page != null && size != null;

  /// Whether uses offset-based pagination.
  bool get isOffsetBased => offset != null && limit != null;

  /// Gets effective offset (works for both modes).
  int get effectiveOffset {
    if (offset != null) return offset!;
    if (page != null && size != null) return (page! - 1) * size!;
    return 0;
  }

  /// Gets effective limit (works for both modes).
  ///
  /// #### Returns
  /// `int` - Number of items per page/request
  int get effectiveLimit {
    if (limit != null) return limit!;
    if (size != null) return size!;
    return 25; // default
  }

  /// Creates parameters for next page.
  ///
  /// #### Returns
  /// `PaginationParams` - Parameters for the next page
  PaginationParams next() {
    if (isPageBased) {
      return PaginationParams(
        page: page! + 1,
        size: size,
        sortBy: sortBy,
        sortOrder: sortOrder,
        filters: filters,
      );
    } else {
      return PaginationParams(
        offset: offset! + limit!,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
        filters: filters,
      );
    }
  }

  /// Creates parameters for previous page.
  ///
  /// #### Returns
  /// `PaginationParams?` - Parameters for previous page, or null if at first page
  PaginationParams? previous() {
    if (isPageBased) {
      if (page! <= 1) return null;
      return PaginationParams(
        page: page! - 1,
        size: size,
        sortBy: sortBy,
        sortOrder: sortOrder,
        filters: filters,
      );
    } else {
      if (offset! <= 0) return null;
      return PaginationParams(
        offset: (offset! - limit!).clamp(0, offset!),
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
        filters: filters,
      );
    }
  }

  /// Creates parameters for specific page.
  PaginationParams goToPage(int targetPage) {
    if (!isPageBased) {
      throw StateError('goToPage() only works with page-based pagination');
    }

    return PaginationParams(
      page: targetPage,
      size: size,
      sortBy: sortBy,
      sortOrder: sortOrder,
      filters: filters,
    );
  }

  /// Converts to query string parameters for API requests.
  ///
  /// #### Returns
  /// `Map<String, dynamic>` - Query parameters compatible with MultiversX API
  Map<String, dynamic> toQueryParams() {
    final Map<String, dynamic> params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (size != null) params['size'] = size;
    if (offset != null) params['from'] = offset;
    if (limit != null) params['size'] = limit;
    if (sortBy != null) params['sort'] = sortBy;
    if (sortOrder != null) {
      params['order'] = sortOrder == SortOrder.ascending ? 'asc' : 'desc';
    }
    if (filters != null) {
      params.addAll(filters!);
    }

    return params;
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() => toQueryParams();

  /// Creates a copy with updated parameters.
  PaginationParams copyWith({
    int? page,
    int? size,
    int? offset,
    int? limit,
    String? sortBy,
    SortOrder? sortOrder,
    Map<String, dynamic>? filters,
  }) {
    return PaginationParams(
      page: page ?? this.page,
      size: size ?? this.size,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      filters: filters ?? this.filters,
    );
  }

  @override
  String toString() {
    if (isPageBased) {
      return 'PaginationParams(page: $page, size: $size${sortBy != null ? ', sortBy: $sortBy' : ''})';
    } else {
      return 'PaginationParams(offset: $offset, limit: $limit${sortBy != null ? ', sortBy: $sortBy' : ''})';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginationParams &&
          runtimeType == other.runtimeType &&
          page == other.page &&
          size == other.size &&
          offset == other.offset &&
          limit == other.limit &&
          sortBy == other.sortBy &&
          sortOrder == other.sortOrder;

  @override
  int get hashCode => Object.hash(page, size, offset, limit, sortBy, sortOrder);
}

/// Sort order for pagination.
enum SortOrder {
  /// Ascending order (A-Z, 0-9, oldest-newest).
  ascending,

  /// Descending order (Z-A, 9-0, newest-oldest).
  descending,
}
