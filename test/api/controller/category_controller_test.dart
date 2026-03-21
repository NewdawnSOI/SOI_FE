import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/controller/category_controller.dart';
import 'package:soi/api/models/category.dart';
import 'package:soi/api/services/category_service.dart';
import 'package:soi_api_client/api.dart';

typedef _GetCategoriesHandler =
    Future<List<Category>> Function({
      required CategoryFilter filter,
      int page,
      bool fetchAllPages,
      int maxPages,
    });

typedef _ToggleCategoryPinHandler =
    Future<bool> Function({required int categoryId});

typedef _UpdateCustomProfileHandler =
    Future<bool> Function({required int categoryId, String? profileImageKey});

class _FakeCategoryService extends CategoryService {
  _FakeCategoryService({
    this.onGetCategories,
    this.onToggleCategoryPin,
    this.onUpdateCustomProfile,
  }) : super(categoryApi: CategoryAPIApi());

  final _GetCategoriesHandler? onGetCategories;
  final _ToggleCategoryPinHandler? onToggleCategoryPin;
  final _UpdateCustomProfileHandler? onUpdateCustomProfile;

  @override
  Future<List<Category>> getCategories({
    CategoryFilter filter = CategoryFilter.all,
    int page = 0,
    bool fetchAllPages = true,
    int maxPages = 50,
  }) async {
    final handler = onGetCategories;
    if (handler == null) {
      throw UnimplementedError('onGetCategories is not configured');
    }

    return handler(
      filter: filter,
      page: page,
      fetchAllPages: fetchAllPages,
      maxPages: maxPages,
    );
  }

  @override
  Future<bool> toggleCategoryPin({required int categoryId}) async {
    final handler = onToggleCategoryPin;
    if (handler == null) {
      throw UnimplementedError('onToggleCategoryPin is not configured');
    }
    return handler(categoryId: categoryId);
  }

  @override
  Future<bool> updateCustomProfile({
    required int categoryId,
    String? profileImageKey,
  }) async {
    final handler = onUpdateCustomProfile;
    if (handler == null) {
      throw UnimplementedError('onUpdateCustomProfile is not configured');
    }
    return handler(categoryId: categoryId, profileImageKey: profileImageKey);
  }
}

void main() {
  group('CategoryController', () {
    test('separates cache entries by request shape', () async {
      final calls = <String>[];
      final controller = CategoryController(
        categoryService: _FakeCategoryService(
          onGetCategories:
              ({
                required CategoryFilter filter,
                int page = 0,
                bool fetchAllPages = true,
                int maxPages = 50,
              }) async {
                calls.add('${filter.value}:$page:$fetchAllPages:$maxPages');
                return [Category(id: page + 1, name: 'page-$page')];
              },
        ),
      );

      final pageZero = await controller.loadCategories(
        1,
        filter: CategoryFilter.public_,
        page: 0,
        fetchAllPages: false,
        forceReload: false,
      );
      final pageOne = await controller.loadCategories(
        1,
        filter: CategoryFilter.public_,
        page: 1,
        fetchAllPages: false,
        forceReload: false,
      );
      final pageOneAgain = await controller.loadCategories(
        1,
        filter: CategoryFilter.public_,
        page: 1,
        fetchAllPages: false,
        forceReload: false,
      );

      expect(calls, ['PUBLIC:0:false:50', 'PUBLIC:1:false:50']);
      expect(pageZero.single.id, 1);
      expect(pageOne.single.id, 2);
      expect(pageOneAgain.single.name, 'page-1');
    });

    test('updates cached pin state locally after toggle', () async {
      final controller = CategoryController(
        categoryService: _FakeCategoryService(
          onGetCategories:
              ({
                required CategoryFilter filter,
                int page = 0,
                bool fetchAllPages = true,
                int maxPages = 50,
              }) async => [
                const Category(id: 1, name: 'Pinned target', isPinned: false),
              ],
          onToggleCategoryPin: ({required int categoryId}) async => true,
        ),
      );

      await controller.loadCategories(
        1,
        filter: CategoryFilter.public_,
        fetchAllPages: false,
      );
      await controller.toggleCategoryPin(categoryId: 1);

      expect(controller.getCategoryById(1)?.isPinned, isTrue);
      expect(
        controller
            .getCategoriesByFilter(CategoryFilter.public_)
            .single
            .isPinned,
        isTrue,
      );
    });

    test(
      'clears cached profile image when custom profile is removed',
      () async {
        final controller = CategoryController(
          categoryService: _FakeCategoryService(
            onGetCategories:
                ({
                  required CategoryFilter filter,
                  int page = 0,
                  bool fetchAllPages = true,
                  int maxPages = 50,
                }) async => [
                  const Category(
                    id: 2,
                    name: 'Profile target',
                    photoUrl: 'profiles/original.jpg',
                  ),
                ],
            onUpdateCustomProfile:
                ({required int categoryId, String? profileImageKey}) async =>
                    true,
          ),
        );

        await controller.loadCategories(
          1,
          filter: CategoryFilter.private_,
          fetchAllPages: false,
        );
        await controller.updateCustomProfile(
          categoryId: 2,
          profileImageKey: '',
        );

        expect(controller.getCategoryById(2)?.photoUrl, isNull);
      },
    );
  });
}
