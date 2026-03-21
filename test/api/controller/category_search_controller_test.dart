import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/controller/category_search_controller.dart';
import 'package:soi/api/models/category.dart';
import 'package:soi/api/services/category_search_service.dart';
import 'package:soi_api_client/api.dart';

typedef _SearchHandler =
    Future<List<Category>> Function({
      int? userId,
      required CategoryFilter filter,
      String? keyword,
      int page,
      bool fetchAllPages,
      int maxPages,
    });

class _FakeCategorySearchService extends CategorySearchService {
  _FakeCategorySearchService({required this.onSearch})
    : super(categoryApi: CategoryAPIApi());

  final _SearchHandler onSearch;

  @override
  Future<List<Category>> searchCategories({
    int? userId,
    CategoryFilter filter = CategoryFilter.all,
    String? keyword,
    int page = 0,
    bool fetchAllPages = true,
    int maxPages = 50,
  }) {
    return onSearch(
      userId: userId,
      filter: filter,
      keyword: keyword,
      page: page,
      fetchAllPages: fetchAllPages,
      maxPages: maxPages,
    );
  }
}

void main() {
  group('CategorySearchController', () {
    test('ignores stale responses for an older query', () async {
      final firstCompleter = Completer<List<Category>>();
      final secondCompleter = Completer<List<Category>>();
      final controller = CategorySearchController(
        searchService: _FakeCategorySearchService(
          onSearch:
              ({
                int? userId,
                required CategoryFilter filter,
                String? keyword,
                int page = 0,
                bool fetchAllPages = true,
                int maxPages = 50,
              }) {
                if (keyword == 'a') {
                  return firstCompleter.future;
                }
                return secondCompleter.future;
              },
        ),
      );

      final first = controller.searchCategoriesFromApi(userId: 1, query: 'a');
      final second = controller.searchCategoriesFromApi(userId: 1, query: 'ab');

      secondCompleter.complete([const Category(id: 2, name: 'ab')]);
      await second;

      firstCompleter.complete([const Category(id: 1, name: 'a')]);
      await first;

      expect(controller.searchQuery, 'ab');
      expect(controller.filteredCategoriesFor(CategoryFilter.all).single.id, 2);
      expect(controller.isSearchLoading, isFalse);
    });

    test('ignores stale responses from a previous user session', () async {
      final firstCompleter = Completer<List<Category>>();
      final secondCompleter = Completer<List<Category>>();
      final controller = CategorySearchController(
        searchService: _FakeCategorySearchService(
          onSearch:
              ({
                int? userId,
                required CategoryFilter filter,
                String? keyword,
                int page = 0,
                bool fetchAllPages = true,
                int maxPages = 50,
              }) {
                if (userId == 1) {
                  return firstCompleter.future;
                }
                return secondCompleter.future;
              },
        ),
      );

      final first = controller.searchCategoriesFromApi(
        userId: 1,
        query: 'album',
      );
      final second = controller.searchCategoriesFromApi(
        userId: 2,
        query: 'album',
      );

      secondCompleter.complete([const Category(id: 20, name: 'user-two')]);
      await second;

      firstCompleter.complete([const Category(id: 10, name: 'user-one')]);
      await first;

      expect(
        controller.filteredCategoriesFor(CategoryFilter.all).single.id,
        20,
      );
      expect(controller.searchQuery, 'album');
    });
  });
}
