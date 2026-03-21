import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/models/category.dart';
import 'package:soi/api/services/category_service.dart';
import 'package:soi_api_client/api.dart';

typedef _GetCategoriesHandler =
    Future<ApiResponseDtoListCategoryRespDto?> Function(
      String categoryFilter, {
      int? page,
    });

class _FakeCategoryApi extends CategoryAPIApi {
  _FakeCategoryApi({this.onGetCategories});

  final _GetCategoriesHandler? onGetCategories;

  @override
  Future<ApiResponseDtoListCategoryRespDto?> getCategories(
    String categoryFilter, {
    int? page,
  }) async {
    final handler = onGetCategories;
    if (handler == null) {
      throw UnimplementedError('onGetCategories is not configured');
    }
    return handler(categoryFilter, page: page);
  }
}

void main() {
  group('CategoryService', () {
    test('reuses in-flight requests for identical parameters', () async {
      final completer = Completer<ApiResponseDtoListCategoryRespDto?>();
      var callCount = 0;
      final service = CategoryService(
        categoryApi: _FakeCategoryApi(
          onGetCategories: (categoryFilter, {int? page}) {
            callCount++;
            return completer.future;
          },
        ),
      );

      final first = service.getCategories(
        filter: CategoryFilter.public_,
        fetchAllPages: false,
      );
      final second = service.getCategories(
        filter: CategoryFilter.public_,
        fetchAllPages: false,
      );

      completer.complete(
        ApiResponseDtoListCategoryRespDto(
          success: true,
          data: [_categoryDto(id: 1, name: 'shared')],
        ),
      );

      final results = await Future.wait([first, second]);

      expect(callCount, 1);
      expect(results[0].single.id, 1);
      expect(results[1].single.name, 'shared');
    });

    test('deduplicates repeated category ids across paged results', () async {
      var callCount = 0;
      final service = CategoryService(
        categoryApi: _FakeCategoryApi(
          onGetCategories: (categoryFilter, {int? page}) async {
            callCount++;
            switch (page ?? 0) {
              case 0:
                return ApiResponseDtoListCategoryRespDto(
                  success: true,
                  data: [
                    _categoryDto(id: 1, name: 'one'),
                    _categoryDto(id: 2, name: 'two'),
                  ],
                );
              case 1:
                return ApiResponseDtoListCategoryRespDto(
                  success: true,
                  data: [
                    _categoryDto(id: 2, name: 'two-duplicate'),
                    _categoryDto(id: 3, name: 'three'),
                  ],
                );
              default:
                return ApiResponseDtoListCategoryRespDto(
                  success: true,
                  data: const [],
                );
            }
          },
        ),
      );

      final results = await service.getCategories(
        filter: CategoryFilter.all,
        fetchAllPages: true,
      );

      expect(callCount, 3);
      expect(results.map((category) => category.id).toList(), [1, 2, 3]);
    });
  });
}

CategoryRespDto _categoryDto({required int id, required String name}) {
  return CategoryRespDto(id: id, name: name);
}
