import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  Future<PagedResult<int>> Function(PaginationParams) pagedFetcher({
    required List<List<int>> pages,
    int? totalCount,
  }) {
    return (params) async {
      final int idx = params.page != null
          ? params.page! - 1
          : (params.offset ?? 0) ~/ params.effectiveLimit;
      final List<int> items = idx < pages.length ? pages[idx] : <int>[];
      return PagedResult<int>.fromResponse(
        items: items,
        params: params,
        totalCount: totalCount,
      );
    };
  }

  group('Paginator', () {
    test('nextPage walks through pages until the last', () async {
      final paginator = Paginator<int>(
        fetchPage: pagedFetcher(
          pages: <List<int>>[
            <int>[1, 2, 3],
            <int>[4, 5, 6],
            <int>[7],
          ],
        ),
        initialParams: const PaginationParams.page(page: 1, size: 3),
      );

      final p1 = await paginator.nextPage();
      expect(p1!.items, <int>[1, 2, 3]);
      final p2 = await paginator.nextPage();
      expect(p2!.items, <int>[4, 5, 6]);
      final p3 = await paginator.nextPage();
      expect(p3!.items, <int>[7]);
      expect(p3.isLast, isTrue);
    });

    test('fetchAll collects items across all pages', () async {
      final paginator = Paginator<int>(
        fetchPage: pagedFetcher(
          pages: <List<int>>[
            <int>[1, 2],
            <int>[3, 4],
            <int>[5],
          ],
        ),
        initialParams: const PaginationParams.page(page: 1, size: 2),
      );

      final all = await paginator.fetchAll();
      expect(all, <int>[1, 2, 3, 4, 5]);
    });

    test('stream respects maxPages', () async {
      final paginator = Paginator<int>(
        fetchPage: pagedFetcher(
          pages: <List<int>>[
            <int>[1, 2],
            <int>[3, 4],
            <int>[5, 6],
          ],
          totalCount: 6,
        ),
        initialParams: const PaginationParams.page(page: 1, size: 2),
      );

      final collected = await paginator.stream(maxPages: 2).toList();
      expect(collected, <int>[1, 2, 3, 4]);
    });

    test('caches identical page requests', () async {
      int fetches = 0;
      final paginator = Paginator<int>(
        fetchPage: (params) async {
          fetches++;
          return PagedResult<int>.fromResponse(
            items: <int>[1, 2],
            params: params,
            totalCount: 2,
          );
        },
        initialParams: const PaginationParams.page(page: 1, size: 2),
      );

      await paginator.nextPage();
      await paginator.reset();
      expect(fetches, 1);
    });

    test('dedups concurrent fetches for the same page', () async {
      int fetches = 0;
      final paginator = Paginator<int>(
        fetchPage: (params) async {
          fetches++;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return PagedResult<int>.fromResponse(
            items: <int>[1],
            params: params,
            totalCount: 1,
          );
        },
        initialParams: const PaginationParams.page(page: 1, size: 1),
      );

      final futures = <Future<PagedResult<int>?>>[
        paginator.nextPage(),
        paginator.nextPage(),
        paginator.nextPage(),
      ];
      await Future.wait(futures);
      expect(fetches, 1);
    });
  });
}
