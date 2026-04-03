import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../api/controller/category_controller.dart';
import '../../../../api/controller/user_controller.dart';
import '../../../../api/models/category.dart';
import '../../../../theme/theme.dart';
import '../../widgets/archive_card_widget/archive_card_widget.dart';
import '../../../../api/controller/category_search_controller.dart';
import 'archive_category_view_state.dart';

class MyArchivesScreen extends StatefulWidget {
  final bool isListView;
  final bool isEditMode;
  final String? editingCategoryId;
  final TextEditingController? editingController;
  final Function(String categoryId, String currentName)? onStartEdit;
  final ScrollController? scrollController; // 외부에서 스크롤 컨트롤러를 주입받도록 변경

  // 초기 로드를 부모에게 위임할지 여부 (기본값: false)
  // - true로 설정하면, MyArchivesScreen이 처음 빌드될 때 데이터를 로드하지 않고, 부모 위젯이 명시적으로 loadData()를 호출할 때 로드하도록 합니다.
  // - false로 설정하면, MyArchivesScreen이 처음 빌드될 때 자동으로 데이터를 로드합니다.
  final bool deferInitialLoadToParent;

  ///
  /// "내 기록" 화면
  /// - 내가 생성한 카테고리 목록을 그리드 또는 리스트 형태로 보여주는 화면입니다.
  /// - 카테고리 편집 모드에서는 카테고리 이름을 수정할 수 있는 UI가 활성화됩니다.
  /// - 초기 로드 시, 로그인한 사용자의 카테고리를 API에서 로드하여 화면에 표시합니다.
  /// - 새로고침 기능을 제공하여, 사용자가 당겨서 새로고침할 때 API에서 최신 데이터를 다시 로드하도록 합니다.
  /// - API 요청 중이거나, 데이터가 없는 경우에는 적절한 로딩 또는 빈 상태 UI를 보여줍니다.
  ///
  /// fields:
  /// - [isListView]: 그리드 뷰 대신 리스트 뷰로 보여줄지 여부
  /// - [isEditMode]: 편집 모드 활성화 여부
  /// - [editingCategoryId]: 현재 편집 중인 카테고리 ID (편집 모드에서만 사용)
  /// - [editingController]: 편집 중인 카테고리 이름을 수정하기 위한 텍스트 컨트롤러 (편집 모드에서만 사용)
  /// - [onStartEdit]: 카테고리 편집을 시작할 때 호출되는 콜백 함수 (편집 모드에서만 사용)
  /// - [scrollController]: 외부에서 스크롤 컨트롤러를 주입받아, 부모 위젯에서 스크롤 위치를 제어할 수 있도록 함
  /// - [deferInitialLoadToParent]: 초기 로드를 부모에게 위임할지 여부 (기본값: false)
  ///

  const MyArchivesScreen({
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
  State<MyArchivesScreen> createState() => _MyArchivesScreenState();
}

class _MyArchivesScreenState extends State<MyArchivesScreen>
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
          filter: CategoryFilter.private_,
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
        maxPages: _kInitialLoadMaxPages,
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
      body: Selector<CategoryController, ArchiveCategoryViewState>(
        selector: (context, categoryController) {
          final categoryIds = categoryController.privateCategories
              .map((category) => category.id)
              .toList(growable: false);
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
              ? searchController
                    .filteredCategoriesFor(CategoryFilter.private_)
                    .map((category) => category.id)
                    .toList(growable: false)
              : state.categoryIds;

          // 로딩 중
          if (state.isInitialLoading) {
            return widget.isListView
                ? _buildShimmerList()
                : _buildShimmerGrid();
          }

          // 에러가 있을 때
          if (state.fatalErrorMessage != null) {
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
