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
import 'archive_category_view_state.dart';

class AllArchivesScreen extends StatefulWidget {
  final bool isListView; // 그리드 뷰와 리스트 뷰를 전환하는 플래그
  final bool isEditMode; // 편집 모드 여부 (편집 모드에서는 카테고리 이름 수정 UI가 활성화됨)
  final String? editingCategoryId; // 편집 중인 카테고리 ID (편집 모드에서만 사용)
  final TextEditingController? editingController;
  final Function(String categoryId, String currentName)? onStartEdit;
  final ScrollController? scrollController; // 외부에서 스크롤 컨트롤러를 주입받도록 변경

  // 초기 로드를 부모에게 위임할지 여부 (기본값: false)
  // - true로 설정하면, AllArchivesScreen이 처음 빌드될 때 데이터를 로드하지 않고, 부모 위젯이 명시적으로 loadData()를 호출할 때 로드하도록 합니다.
  // - false로 설정하면, AllArchivesScreen이 처음 빌드될 때 자동으로 데이터를 로드합니다.
  final bool deferInitialLoadToParent;

  ///
  /// 전체 아카이브 화면
  /// 모든 사용자의 아카이브 목록을 표시
  /// 아카이브를 클릭하면 아카이브 상세 화면으로 이동
  ///
  /// fields:
  /// - [isListView]: 그리드를 리스트 뷰로 표시할지 여부 (기본값: false)
  /// - [isEditMode]: 편집 모드 여부 (편집 모드에서는 카테고리 이름 수정 UI가 활성화됨)
  /// - [editingCategoryId]: 편집 중인 카테고리 ID (편집 모드에서만 사용)
  /// - [editingController]: 편집 중인 카테고리 이름을 제어하는 TextEditingController (편집 모드에서만 사용)
  /// - [onStartEdit]: 카테고리 편집을 시작할 때 호출되는 콜백 함수 (편집 모드에서만 사용)
  /// - [scrollController]: 외부에서 스크롤 컨트롤러를 주입받아, 부모 위젯에서 스크롤 위치를 제어할 수 있도록 함
  /// - [deferInitialLoadToParent]: 초기 로드를 부모에게 위임할지 여부 (기본값: false)
  ///

  const AllArchivesScreen({
    super.key,
    this.isListView = false,
    this.isEditMode = false,
    this.editingCategoryId,
    this.editingController,
    this.onStartEdit,
    this.scrollController,
    this.deferInitialLoadToParent = false,
  });

  @override
  State<AllArchivesScreen> createState() => _AllArchivesScreenState();
}

class _AllArchivesScreenState extends State<AllArchivesScreen>
    with AutomaticKeepAliveClientMixin {
  static const int _kInitialLoadMaxPages = 2;

  int? _userId;

  // API 컨트롤러들
  UserController? _userController;
  CategoryController? _categoryController;

  /// 초기 로드 상태
  bool _isInitialLoad = true;
  int? _initializedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userController ??= Provider.of<UserController>(context, listen: false);
    _categoryController ??= Provider.of<CategoryController>(
      context,
      listen: false,
    );
    _ensureInitialLoadState(); // 초기 로드 상태 확인 및 필요 시 데이터 로드
  }

  // 초기 로드 상태를 확인하고, 필요하면 데이터를 로드합니다.
  // - 로그인한 사용자가 변경되었거나, 초기 로드 상태가 아직 결정되지 않은 경우에만 로드 수행
  void _ensureInitialLoadState() {
    final currentUser = _userController?.currentUser;
    final currentUserId = currentUser?.id;

    if (_initializedUserId == currentUserId) {
      return;
    }

    _initializedUserId = currentUserId;
    _userId = currentUserId;

    if (currentUserId == null) {
      _isInitialLoad = false;
      return;
    }

    final hasFreshCache =
        _categoryController?.hasFreshRequest(
          userId: currentUserId,
          filter: CategoryFilter.all,
          fetchAllPages: true,
          maxPages: _kInitialLoadMaxPages,
        ) ??
        false;

    if (widget.deferInitialLoadToParent || hasFreshCache) {
      _isInitialLoad = false;
      return;
    }

    _isInitialLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadData();
    });
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
        maxPages: _kInitialLoadMaxPages, // 처음 로드 시 최대 2페이지만 로드
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
      body: Selector<CategoryController, ArchiveCategoryViewState>(
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

          return ArchiveCategoryViewState(
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
                ? _buildListView(displayCategoryIds)
                : _buildGridView(displayCategoryIds),
          );
        },
      ),
    );
  }

  /// 그리드 뷰 빌드
  Widget _buildGridView(List<int> categoryIds) {
    final categoryController = context.read<CategoryController>();
    return GridView.builder(
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

  Widget _buildListView(List<int> categoryIds) {
    final categoryController = context.read<CategoryController>();
    return ListView.separated(
      controller: widget.scrollController, // 외부에서 주입받은 스크롤 컨트롤러 사용
      padding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 20.h),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: categoryIds.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final categoryId = categoryIds[index];
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
