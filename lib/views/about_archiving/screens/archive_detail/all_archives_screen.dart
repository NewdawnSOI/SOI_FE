import 'package:flutter/foundation.dart' show listEquals;
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

// 전체 아카이브 화면
// 모든 사용자의 아카이브 목록을 표시
// 아카이브를 클릭하면 아카이브 상세 화면으로 이동
class AllArchivesScreen extends StatefulWidget {
  final bool isListView; // 그리드 뷰와 리스트 뷰를 전환하는 플래그
  final bool isEditMode; // 편집 모드 여부 (편집 모드에서는 카테고리 이름 수정 UI가 활성화됨)
  final String? editingCategoryId; // 편집 중인 카테고리 ID (편집 모드에서만 사용)
  final TextEditingController? editingController;
  final Function(String categoryId, String currentName)? onStartEdit;
  final ScrollController? scrollController; // 외부에서 스크롤 컨트롤러를 주입받도록 변경

  const AllArchivesScreen({
    super.key,
    this.isListView = false,
    this.isEditMode = false,
    this.editingCategoryId,
    this.editingController,
    this.onStartEdit,
    this.scrollController,
  });

  @override
  State<AllArchivesScreen> createState() => _AllArchivesScreenState();
}

class _AllArchivesCategoryViewState {
  final List<int> categoryIds;
  final bool isInitialLoading;
  final String? fatalErrorMessage;

  const _AllArchivesCategoryViewState({
    required this.categoryIds,
    required this.isInitialLoading,
    required this.fatalErrorMessage,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AllArchivesCategoryViewState &&
          runtimeType == other.runtimeType &&
          isInitialLoading == other.isInitialLoading &&
          fatalErrorMessage == other.fatalErrorMessage &&
          listEquals(categoryIds, other.categoryIds);

  @override
  int get hashCode => Object.hash(
    isInitialLoading,
    fatalErrorMessage,
    Object.hashAll(categoryIds),
  );
}

class _AllArchivesScreenState extends State<AllArchivesScreen>
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

  /// 데이터 로드
  Future<void> _loadData() async {
    // 현재 로그인한 사용자 ID 가져오기
    final currentUser = _userController!.currentUser;
    if (currentUser != null) {
      if (mounted) {
        setState(() {
          _userId = currentUser.id;
        });
      }

      /// 카테고리 초기 로드
      await _categoryController!.loadCategories(
        currentUser.id,
        forceReload: false, // 강제 새로고침 없이 캐시 활용
        fetchAllPages: true, // 모든 페이지를 로드하여 완전한 목록 확보
        maxPages: 2, // 처음 로드 시 최대 2페이지만 로드
      );
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
      }
    } else {
      debugPrint('[AllArchivesScreen] 로그인된 사용자 없음');
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
        forceReload: true,
        fetchAllPages: true,
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

      // 카테고리 목록
      // Selector로 부분 갱신이 되도록 함.
      body: Selector<CategoryController, _AllArchivesCategoryViewState>(
        selector: (context, categoryController) {
          final categoryIds = categoryController.allCategories
              .map((c) => c.id)
              .toList(growable: false);

          // "목록이 비어있는 상태"에서만 로딩/에러 UI가 필요하므로 파생 상태로 구독한다.
          final isInitialLoading =
              categoryController.isLoading && categoryIds.isEmpty;
          final fatalErrorMessage = categoryIds.isEmpty
              ? categoryController.errorMessage
              : null;

          return _AllArchivesCategoryViewState(
            categoryIds: categoryIds,
            isInitialLoading: isInitialLoading,
            fatalErrorMessage: fatalErrorMessage,
          );
        },
        builder: (context, state, child) {
          final searchController = context.watch<CategorySearchController>();
          final isSearchActive = searchController.searchQuery.isNotEmpty;
          final displayCategoryIds = isSearchActive
              ?
                // 검색어가 있을 때는 검색 결과로 표시할 카테고리 ID 목록을 가져온다.
                searchController
                    .filteredCategoriesFor(CategoryFilter.all)
                    .map((c) => c.id)
                    .toList(growable: false)
              :
                // 검색어가 없을 때는 전체 카테고리 ID 목록을 표시한다.
                state.categoryIds;

          // 로딩 중 (카테고리 목록이 비어있는 경우에만)
          if (state.isInitialLoading) {
            return widget.isListView
                ? _buildShimmerList()
                : _buildShimmerGrid();
          }

          // 에러가 있을 때 (카테고리 목록이 비어있는 경우에만)
          if (state.fatalErrorMessage != null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 에러 메시지와 재시도 버튼
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
          if (displayCategoryIds.isEmpty) {
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
                    displayCategoryIds,
                    searchController.searchQuery,
                  )
                : _buildGridView(
                    displayCategoryIds,
                    searchController.searchQuery,
                  ),
          );
        },
      ),
    );
  }

  /// 그리드 뷰 빌드
  Widget _buildGridView(List<int> categoryIds, String searchQuery) {
    return GridView.builder(
      key: ValueKey('grid_${categoryIds.length}_$searchQuery'),
      controller: widget.scrollController, // 외부에서 주입받은 스크롤 컨트롤러 사용
      padding: EdgeInsets.only(left: 20.w, right: 22.w, bottom: 20.h),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: (170 / 204),
        mainAxisSpacing: 11.sp,
        crossAxisSpacing: 11.sp,
      ),
      itemCount: categoryIds.length,
      itemBuilder: (context, index) {
        final categoryId = categoryIds[index];
        final categoryController = context.read<CategoryController>();
        final category = categoryController.getCategoryById(categoryId);
        if (category == null) return const SizedBox.shrink();

        // 그리드 모드의 아카이브 카드 위젯
        return ApiArchiveCardWidget(
          key: ValueKey('archive_card_$categoryId'), // 고유 키 지정
          category: category,
          isListView: false,
          isEditMode: widget.isEditMode,
          isEditing:
              widget.isEditMode &&
              widget.editingCategoryId == categoryId.toString(),
          editingController:
              widget.isEditMode &&
                  widget.editingCategoryId == categoryId.toString()
              ? widget.editingController
              : null,
          onStartEdit: () {
            if (widget.onStartEdit != null) {
              final latest =
                  categoryController.getCategoryById(categoryId) ?? category;
              widget.onStartEdit!(categoryId.toString(), latest.name);
            }
          },
        );
      },
    );
  }

  Widget _buildListView(List<int> categoryIds, String searchQuery) {
    return ListView.separated(
      key: ValueKey('list_${categoryIds.length}_$searchQuery'),
      controller: widget.scrollController, // 외부에서 주입받은 스크롤 컨트롤러 사용
      padding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 20.h),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: categoryIds.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final categoryId = categoryIds[index];
        final categoryController = context.read<CategoryController>();
        final category = categoryController.getCategoryById(categoryId);
        if (category == null) return const SizedBox.shrink();

        return ApiArchiveCardWidget(
          key: ValueKey('archive_list_card_$categoryId'),
          category: category,
          isListView: true,
          isEditMode: widget.isEditMode,
          isEditing:
              widget.isEditMode &&
              widget.editingCategoryId == categoryId.toString(),
          editingController:
              widget.isEditMode &&
                  widget.editingCategoryId == categoryId.toString()
              ? widget.editingController
              : null,
          onStartEdit: () {
            if (widget.onStartEdit != null) {
              final latest =
                  categoryController.getCategoryById(categoryId) ?? category;
              widget.onStartEdit!(categoryId.toString(), latest.name);
            }
          },
        );
      },
    );
  }

  /// Shimmer 로딩 그리드
  /// 로딩 중일떄, 일반 CircularProgressIndicator 대신 표시
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
