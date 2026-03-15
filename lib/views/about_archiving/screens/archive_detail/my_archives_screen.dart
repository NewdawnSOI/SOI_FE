import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../api/controller/category_controller.dart';
import '../../../../api/controller/user_controller.dart';
import '../../../../api/models/category.dart';
import '../../../../theme/theme.dart';
import '../../widgets/archive_card_widget/api_archive_card_widget.dart';
import '../../../../api/controller/category_search_controller.dart';

// 나의 아카이브 화면 (REST API 버전)
// 현재 사용자가 생성한 카테고리만 표시
class MyArchivesScreen extends StatefulWidget {
  final bool isListView;
  final bool isEditMode;
  final String? editingCategoryId;
  final TextEditingController? editingController;
  final Function(String categoryId, String currentName)? onStartEdit;
  final ScrollController? scrollController; // 외부에서 스크롤 컨트롤러를 주입받도록 변경

  const MyArchivesScreen({
    super.key,
    this.isListView = false,
    this.isEditMode = false,
    this.editingCategoryId,
    this.editingController,
    this.onStartEdit,
    this.scrollController,
  });

  @override
  State<MyArchivesScreen> createState() => _MyArchivesScreenState();
}

class _MyArchivesScreenState extends State<MyArchivesScreen>
    with AutomaticKeepAliveClientMixin {
  int? _userId;

  // API 컨트롤러들
  UserController? _userController;
  CategoryController? _categoryController;

  /// 초기 로드 상태
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userController ??= Provider.of<UserController>(context, listen: false);
    _categoryController ??= Provider.of<CategoryController>(
      context,
      listen: false,
    );
  }

  /// 카테고리 초기 로드
  Future<void> _loadData() async {
    final userController = Provider.of<UserController>(context, listen: false);
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );

    _userController = userController;
    _categoryController = categoryController;

    // 현재 로그인한 사용자 ID 가져오기
    final currentUser = userController.currentUser;
    if (currentUser != null) {
      if (mounted) {
        setState(() {
          _userId = currentUser.id;
        });
      }
      // 카테고리 로드 (private 필터 - 내가 생성한 카테고리)
      await categoryController.loadCategories(
        currentUser.id,
        filter: CategoryFilter.private_,
        forceReload: false, // 강제 새로고침 없이 캐시 활용
        fetchAllPages: true, // 모든 페이지를 로드하여 완전한 목록 확보
        maxPages: 2,
      );
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
      }
    } else {
      debugPrint('[MyArchivesScreen] 로그인된 사용자 없음');
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
      }
    }
  }

  /// 새로고침
  Future<void> _refresh() async {
    if (_userId != null && _categoryController != null) {
      await _categoryController!.loadCategories(
        _userId!,
        filter: CategoryFilter.private_,
        forceReload: true,
        fetchAllPages: true,
        maxPages: 2,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 초기 로딩 중
    if (_isInitialLoad) {
      return Scaffold(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        body: widget.isListView ? _buildShimmerList() : _buildShimmerGrid(),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: Consumer<CategoryController>(
        builder: (context, categoryController, child) {
          final categories = categoryController.privateCategories;
          final searchController = context.watch<CategorySearchController>();
          final isSearchActive = searchController.searchQuery.isNotEmpty;
          final displayCategories = isSearchActive
              ? searchController.filteredCategoriesFor(CategoryFilter.private_)
              : categories;

          // 로딩 중
          if (categoryController.isLoading && categories.isEmpty) {
            return widget.isListView
                ? _buildShimmerList()
                : _buildShimmerGrid();
          }

          // 에러가 있을 때
          if (categoryController.errorMessage != null && categories.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'common.error_occurred',
                      style: TextStyle(color: Colors.white, fontSize: 16.sp),
                      textAlign: TextAlign.center,
                    ).tr(),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: Text('common.retry').tr(),
                    ),
                  ],
                ),
              ),
            );
          }

          // 카테고리가 없는 경우
          if (displayCategories.isEmpty) {
            if (isSearchActive) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.h),
                  child: Text(
                    'archive.search_empty',
                    style: TextStyle(color: Colors.white, fontSize: 16.sp),
                    textAlign: TextAlign.center,
                  ).tr(),
                ),
              );
            }

            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.h),
                child: Text(
                  'archive.empty_categories',
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  textAlign: TextAlign.center,
                ).tr(),
              ),
            );
          }

          // RefreshIndicator로 당겨서 새로고침 지원
          return RefreshIndicator(
            onRefresh: _refresh,
            color: Colors.white,
            backgroundColor: const Color(0xFF1C1C1C),
            child: widget.isListView
                ? _buildListView(
                    displayCategories,
                    searchController.searchQuery,
                  )
                : _buildGridView(
                    displayCategories,
                    searchController.searchQuery,
                  ),
          );
        },
      ),
    );
  }

  Widget _buildGridView(List<Category> categories, String searchQuery) {
    return GridView.builder(
      key: ValueKey('my_grid_${categories.length}_$searchQuery'),
      controller: widget.scrollController, // 외부에서 주입받은 스크롤 컨트롤러 사용
      padding: EdgeInsets.only(left: 20.w, right: 22.w, bottom: 20.h),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: (170 / 204),
        mainAxisSpacing: 11.sp,
        crossAxisSpacing: 11.sp,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];

        return ApiArchiveCardWidget(
          key: ValueKey('my_archive_card_${category.id}'),
          category: category,
          isListView: false,
          isEditMode: widget.isEditMode,
          isEditing:
              widget.isEditMode &&
              widget.editingCategoryId == category.id.toString(),
          editingController:
              widget.isEditMode &&
                  widget.editingCategoryId == category.id.toString()
              ? widget.editingController
              : null,
          onStartEdit: () {
            if (widget.onStartEdit != null) {
              widget.onStartEdit!(category.id.toString(), category.name);
            }
          },
        );
      },
    );
  }

  Widget _buildListView(List<Category> categories, String searchQuery) {
    return ListView.separated(
      key: ValueKey('my_list_${categories.length}_$searchQuery'),
      controller: widget.scrollController, // 외부에서 주입받은 스크롤 컨트롤러 사용
      padding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 20.h),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: categories.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final category = categories[index];

        return ApiArchiveCardWidget(
          key: ValueKey('my_archive_list_card_${category.id}'),
          category: category,
          isListView: true,
          isEditMode: widget.isEditMode,
          isEditing:
              widget.isEditMode &&
              widget.editingCategoryId == category.id.toString(),
          editingController:
              widget.isEditMode &&
                  widget.editingCategoryId == category.id.toString()
              ? widget.editingController
              : null,
          onStartEdit: () {
            if (widget.onStartEdit != null) {
              widget.onStartEdit!(category.id.toString(), category.name);
            }
          },
        );
      },
    );
  }

  /// Shimmer 로딩 그리드
  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: EdgeInsets.only(left: 20.w, right: 22.w, bottom: 20.h),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: (170 / 204),
        mainAxisSpacing: 11.sp,
        crossAxisSpacing: 11.sp,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: const Color(0xFF1C1C1C),
          highlightColor: const Color(0xFF2A2A2A),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.7),
            child: Container(
              width: 170.sp,
              height: 204.sp,
              color: Colors.black,
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerList() {
    return ListView.separated(
      padding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 20.h),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: const Color(0xFF1C1C1C),
          highlightColor: const Color(0xFF2A2A2A),
          child: Container(
            height: 90.h,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(9.3),
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
