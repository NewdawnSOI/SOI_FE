import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/models/category.dart';
import 'package:soi/api/services/category_search_service.dart';
import 'package:soi_api_client/api.dart';

typedef _SearchCategoriesHandler =
    Future<ApiResponseDtoListCategoryRespDto?> Function(
      String categoryFilter, {
      String? keyword,
      int? page,
    });

class _FakeCategorySearchApi extends CategoryAPIApi {
  _FakeCategorySearchApi({this.onSearch});

  final _SearchCategoriesHandler? onSearch;

  @override
  Future<ApiResponseDtoListCategoryRespDto?> getCategories1(
    String categoryFilter, {
    String? keyword,
    int? page,
  }) async {
    final handler = onSearch;
    if (handler == null) {
      throw UnimplementedError('onSearch is not configured');
    }
    return handler(categoryFilter, keyword: keyword, page: page);
  }
}

void main() {
  group('CategorySearchService', () {
    test('caches identical search results within the TTL window', () async {
      var callCount = 0;
      final service = CategorySearchService(
        categoryApi: _FakeCategorySearchApi(
          onSearch: (categoryFilter, {String? keyword, int? page}) async {
            callCount++;
            return ApiResponseDtoListCategoryRespDto(
              success: true,
              data: [_categoryDto(id: 1, name: '$categoryFilter:$keyword')],
            );
          },
        ),
      );

      final first = await service.searchCategories(
        userId: 7,
        filter: CategoryFilter.all,
        keyword: 'album',
        fetchAllPages: false,
      );
      final second = await service.searchCategories(
        userId: 7,
        filter: CategoryFilter.all,
        keyword: 'album',
        fetchAllPages: false,
      );

      expect(callCount, 1);
      expect(first.single.name, 'ALL:album');
      expect(second.single.id, 1);
    });

    test('reuses in-flight search requests for identical parameters', () async {
      final completer = Completer<ApiResponseDtoListCategoryRespDto?>();
      var callCount = 0;
      final service = CategorySearchService(
        categoryApi: _FakeCategorySearchApi(
          onSearch: (categoryFilter, {String? keyword, int? page}) {
            callCount++;
            return completer.future;
          },
        ),
      );

      final first = service.searchCategories(
        userId: 7,
        filter: CategoryFilter.public_,
        keyword: 'group',
        fetchAllPages: false,
      );
      final second = service.searchCategories(
        userId: 7,
        filter: CategoryFilter.public_,
        keyword: 'group',
        fetchAllPages: false,
      );

      completer.complete(
        ApiResponseDtoListCategoryRespDto(
          success: true,
          data: [_categoryDto(id: 10, name: 'group')],
        ),
      );

      final results = await Future.wait([first, second]);

      expect(callCount, 1);
      expect(results[0].single.id, 10);
      expect(results[1].single.name, 'group');
    });

    test('separates cache entries by user id', () async {
      var callCount = 0;
      final service = CategorySearchService(
        categoryApi: _FakeCategorySearchApi(
          onSearch: (categoryFilter, {String? keyword, int? page}) async {
            callCount++;
            return ApiResponseDtoListCategoryRespDto(
              success: true,
              data: [_categoryDto(id: callCount, name: '$keyword-$callCount')],
            );
          },
        ),
      );

      final userOneResults = await service.searchCategories(
        userId: 1,
        filter: CategoryFilter.private_,
        keyword: 'memo',
        fetchAllPages: false,
      );
      final userTwoResults = await service.searchCategories(
        userId: 2,
        filter: CategoryFilter.private_,
        keyword: 'memo',
        fetchAllPages: false,
      );

      expect(callCount, 2);
      expect(userOneResults.single.id, 1);
      expect(userTwoResults.single.id, 2);
    });
  });
}

CategoryRespDto _categoryDto({required int id, required String name}) {
  return CategoryRespDto(id: id, name: name);
}
