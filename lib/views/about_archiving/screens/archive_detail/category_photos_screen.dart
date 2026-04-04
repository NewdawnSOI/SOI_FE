import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:soi/views/about_archiving/screens/category_edit/category_editor_screen.dart';
import 'package:soi/views/about_archiving/widgets/api_category_members_bottom_sheet.dart';
import 'package:soi/views/about_friends/friend_list_add_screen.dart';

import '../../../../api/controller/category_controller.dart';
import '../../../../api/controller/friend_controller.dart';
import '../../../../api/controller/post_controller.dart';
import '../../../../api/controller/user_controller.dart';
import '../../../../api/models/category.dart';
import '../../../../api/models/friend.dart';
import '../../../../api/models/post.dart';
import '../../../../api/models/user.dart';
import '../../../../theme/theme.dart';
import '../../../../utils/app_route_observer.dart';
import '../../../../utils/video_thumbnail_cache.dart';
import 'photo_detail_screen.dart';
import 'widgets/category_photos_header+body/category_header_image_prefetch.dart';
import 'widgets/category_photos_header+body/category_photos_body_slivers.dart';
import 'widgets/category_photos_header+body/category_photos_header.dart';
import 'services/category_photos_screen_service.dart';

import 'package:flutter/foundation.dart' as foundation show kDebugMode;

typedef _CategoryPhotosBodyState = ({
  List<Post> posts,
  bool isLoading,
  String? errorMessageKey,
});

/// 카테고리 상세 화면의 헤더와 포토 그리드를 한 화면에서 조립합니다.
class ApiCategoryPhotosScreen extends StatefulWidget {
  final Category category;
  final CategoryHeaderImagePrefetch? prefetchedHeaderImage;
  final int? initialPostId;
  const ApiCategoryPhotosScreen({
    super.key,
    required this.category,
    this.prefetchedHeaderImage,
    this.initialPostId,
  });

  @override
  State<ApiCategoryPhotosScreen> createState() =>
      _ApiCategoryPhotosScreenState();
}

/// 아카이브 상세의 헤더, 캐시, 페이징, 상세 복귀 반영을 한 곳에서 조율합니다.
class _ApiCategoryPhotosScreenState extends State<ApiCategoryPhotosScreen>
    with RouteAware {
  static const int _kMaxCategoryPostsPages = 50;
  static final CategoryPostsScreenCacheStore _categoryPostsCache =
      CategoryPostsScreenCacheStore();
  static final Map<int, CategoryHeaderImagePrefetch> _headerImageMemoryCache =
      {};

  final ValueNotifier<_CategoryPhotosBodyState> _bodyStateNotifier =
      ValueNotifier<_CategoryPhotosBodyState>((
        posts: const <Post>[],
        isLoading: true,
        errorMessageKey: null,
      ));
  Category? _category;
  CategoryHeaderImagePrefetch? _headerImagePrefetch;
  final CategoryPostsVisibleAccumulator _visiblePostAccumulator =
      CategoryPostsVisibleAccumulator();

  late final CategoryController _categoryController;
  late final PostController _postController;
  late final UserController _userController;
  late final FriendController _friendController;
  VoidCallback? _postsChangedListener;
  int _pagingGeneration = 0;
  bool _hasMorePages = false;
  int _nextPage = 1;
  bool _isRouteVisible = true;
  bool _needsRefreshOnVisible = false;
  final Set<int> _pendingDeletedPostIdsFromDetail = <int>{};
  Timer? _deferredVisibleRefreshTimer;
  bool _isRouteObserverSubscribed = false;
  ModalRoute<void>? _subscribedRoute;

  Category get _currentCategory => _category ?? widget.category;
  _CategoryPhotosBodyState get _bodyState => _bodyStateNotifier.value;
  List<Post> get _posts => _bodyState.posts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeRouteObserverIfNeeded();
  }

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _headerImagePrefetch = _resolveInitialHeaderImagePrefetch();
    _categoryController = context.read<CategoryController>();
    _postController = context.read<PostController>();
    _userController = context.read<UserController>();
    _friendController = context.read<FriendController>();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (_headerImagePrefetch != null) {
        unawaited(_precacheHeaderImageIfNeeded(_headerImagePrefetch!));
      }

      _categoryController.markCategoryAsViewed(_currentCategory.id);
      _attachPostChangedListenerIfNeeded();

      if (widget.initialPostId != null) {
        await _openInitialDeepLinkedPost(widget.initialPostId!);
        return;
      }
      await _loadPosts();
    });
  }

  @override
  void dispose() {
    _deferredVisibleRefreshTimer?.cancel();
    if (_isRouteObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
      _isRouteObserverSubscribed = false;
    }

    if (_postsChangedListener != null) {
      _postController.removePostsChangedListener(_postsChangedListener!);
    }
    _bodyStateNotifier.dispose();
    super.dispose();
  }

  /// 현재 라우트에 맞춰 RouteObserver 구독을 유지합니다.
  void _subscribeRouteObserverIfNeeded() {
    final route = ModalRoute.of(context);
    if (route == null) return;

    final modalRoute = route as ModalRoute<void>;

    if (_isRouteObserverSubscribed && _subscribedRoute == modalRoute) {
      return;
    }

    if (_isRouteObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
      _isRouteObserverSubscribed = false;
    }

    _subscribedRoute = modalRoute;
    appRouteObserver.subscribe(this, modalRoute);
    _isRouteObserverSubscribed = true;
  }

  @override
  void didPush() {
    _isRouteVisible = true;
  }

  @override
  void didPushNext() {
    _isRouteVisible = false;
  }

  @override
  void didPop() {
    _isRouteVisible = false;
  }

  @override
  void didPopNext() {
    _isRouteVisible = true;
    _applyPendingDeletedPostsFromDetail();
    if (!_needsRefreshOnVisible) return;

    _deferredVisibleRefreshTimer?.cancel();
    _deferredVisibleRefreshTimer = Timer(const Duration(milliseconds: 260), () {
      if (!mounted || !_isRouteVisible || !_needsRefreshOnVisible) return;
      if (_pendingDeletedPostIdsFromDetail.isNotEmpty) {
        _applyPendingDeletedPostsFromDetail();
      }
      if (!_needsRefreshOnVisible) return;
      _needsRefreshOnVisible = false;
      unawaited(_loadPosts(forceRefresh: true));
    });
  }

  CategoryHeaderImagePrefetch? _resolveInitialHeaderImagePrefetch() {
    if (widget.prefetchedHeaderImage != null) {
      _headerImageMemoryCache[_currentCategory.id] =
          widget.prefetchedHeaderImage!;
      return widget.prefetchedHeaderImage;
    }

    final cached = _headerImageMemoryCache[_currentCategory.id];
    if (cached != null) return cached;

    final fallback = CategoryHeaderImagePrefetch.fromCategory(_currentCategory);
    if (fallback != null) {
      _headerImageMemoryCache[_currentCategory.id] = fallback;
    }
    return fallback;
  }

  Future<void> _precacheHeaderImageIfNeeded(
    CategoryHeaderImagePrefetch payload,
  ) {
    return CategoryHeaderImagePrefetchRegistry.prefetchIfNeeded(
      context,
      payload,
    );
  }

  /// 본문 상태를 한 곳에서 갱신해 로딩, 성공, 에러 전환을 단순화합니다.
  void _updateBodyState({
    List<Post>? posts,
    required bool isLoading,
    String? errorMessageKey,
  }) {
    if (!mounted) return;
    _bodyStateNotifier.value = (
      posts: List<Post>.unmodifiable(posts ?? _posts),
      isLoading: isLoading,
      errorMessageKey: errorMessageKey,
    );
  }

  /// 현재 사용자와 카테고리 기준의 mutation revision을 계산합니다.
  int _currentMutationRevision({required int userId}) {
    return _postController.getCategoryMutationRevision(
      userId: userId,
      categoryId: _currentCategory.id,
    );
  }

  /// 아카이브 상세 화면용 카테고리 캐시 키를 생성합니다.
  String _cacheKeyForUser(int userId) {
    return buildCategoryPostsCacheKey(
      userId: userId,
      categoryId: _currentCategory.id,
    );
  }

  Future<void> _openInitialDeepLinkedPost(int postId) async {
    final exactPost = await _postController.getPostDetail(postId);
    if (!mounted) return;

    if (exactPost?.id != postId) {
      await _loadPosts(forceRefresh: true);
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ApiPhotoDetailScreen(
          allPosts: List<Post>.unmodifiable(<Post>[exactPost!]),
          initialIndex: 0,
          categoryName: _currentCategory.name,
          categoryId: _currentCategory.id,
          singlePostMode: true,
        ),
      ),
    );
    if (!mounted) return;

    if (_needsRefreshOnVisible) {
      _needsRefreshOnVisible = false;
      _deferredVisibleRefreshTimer?.cancel();
    }

    await _loadPosts(forceRefresh: true);
  }

  /// 카테고리 포스트를 캐시 우선으로 보여주고 남은 페이지는 백그라운드에서 누적합니다.
  Future<void> _loadPosts({bool forceRefresh = false}) async {
    if (!mounted) return;
    final loadStopwatch = Stopwatch()..start();
    final generation = ++_pagingGeneration;
    _hasMorePages = false;
    _nextPage = 1;

    try {
      final currentUser = _userController.currentUser;
      if (currentUser == null) {
        _updateBodyState(
          isLoading: false,
          errorMessageKey: 'common.login_required',
        );
        return;
      }

      final cacheKey = _cacheKeyForUser(currentUser.id);
      final currentMutationRevision = _currentMutationRevision(
        userId: currentUser.id,
      );

      final cached = _categoryPostsCache.read(
        cacheKey,
        allowExpired: true,
        currentMutationRevision: currentMutationRevision,
      );

      final freshCache = _categoryPostsCache.read(
        cacheKey,
        allowExpired: false,
        currentMutationRevision: currentMutationRevision,
      );

      if (cached != null && !forceRefresh) {
        _updateBodyState(posts: cached.posts, isLoading: false);

        if (freshCache != null) {
          if (foundation.kDebugMode) {
            debugPrint('[_loadPosts] 신선한 캐시 사용, API 호출 생략');
          }
          return;
        }
        if (foundation.kDebugMode) {
          debugPrint('[_loadPosts] 만료된 캐시 표시, 백그라운드 갱신 시작');
        }
      } else {
        _updateBodyState(isLoading: true);
      }

      final results = await Future.wait([
        _postController.getPostsByCategory(
          categoryId: _currentCategory.id,
          userId: currentUser.id,
          notificationId: null,
          page: 0,
          notifyLoading: false,
          forceRefresh: forceRefresh,
        ),
        _friendController.getAllFriends(
          userId: currentUser.id,
          status: FriendStatus.blocked,
        ),
      ]);
      if (!mounted || generation != _pagingGeneration) return;

      final firstPagePosts = results[0] as List<Post>;
      final blockedUsers = results[1] as List<User>;
      _visiblePostAccumulator
        ..replaceBlockedUserIds(blockedUsers.map((user) => user.userId))
        ..reset();

      final firstPageResult = _visiblePostAccumulator.appendPage(
        firstPagePosts,
      );
      final visiblePosts = firstPageResult.posts;
      _nextPage = 1;
      _hasMorePages = firstPagePosts.isNotEmpty;

      _updateBodyState(posts: visiblePosts, isLoading: false);
      _categoryPostsCache.write(
        cacheKey,
        posts: visiblePosts,
        mutationRevision: currentMutationRevision,
      );

      _prefetchVideoThumbnails(visiblePosts);

      if (foundation.kDebugMode) {
        debugPrint(
          '[_loadPosts] first-page latency=${loadStopwatch.elapsedMilliseconds}ms '
          'fetched=${firstPagePosts.length} visible=${visiblePosts.length} '
          'blockedRemoved=${firstPageResult.blockedRemoved} '
          'deduped=${firstPageResult.duplicateRemoved}',
        );
      }

      if (_hasMorePages) {
        unawaited(
          _loadRemainingPagesInBackground(
            generation: generation,
            userId: currentUser.id,
            categoryId: _currentCategory.id,
            cacheKey: cacheKey,
            startedAt: loadStopwatch,
            loadedPages: 1,
            totalFetchedPosts: firstPagePosts.length,
            totalDedupedPosts: firstPageResult.duplicateRemoved,
            forceRefresh: forceRefresh,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ApiCategoryPhotosScreen] 포스트 로드 실패: $e');
      if (!mounted) return;

      if (_posts.isEmpty) {
        _updateBodyState(
          isLoading: false,
          errorMessageKey: 'archive.photo_load_failed',
        );
      } else {
        _updateBodyState(isLoading: false);
        if (foundation.kDebugMode) {
          debugPrint('[_loadPosts] 갱신 실패했지만 캐시 데이터 유지');
        }
      }
    }
  }

  /// 당겨서 새로고침 시 캐시를 무시하고 현재 카테고리 목록을 다시 불러옵니다.
  Future<void> _onRefresh() => _loadPosts(forceRefresh: true);

  /// 상세 화면에서 전달된 삭제 결과를 현재 목록과 캐시에 즉시 반영합니다.
  void _onPostsDeletedFromDetail(List<int> deletedPostIds) {
    if (!mounted || deletedPostIds.isEmpty) return;
    _pendingDeletedPostIdsFromDetail.addAll(deletedPostIds);

    _needsRefreshOnVisible = false;
    _deferredVisibleRefreshTimer?.cancel();

    if (!_isRouteVisible) return;
    _applyPendingDeletedPostsFromDetail();
  }

  /// 상세 화면에서 전달된 삭제 ID를 현재 그리드와 캐시에 한 번만 안전하게 반영합니다.
  void _applyPendingDeletedPostsFromDetail() {
    if (!mounted || _pendingDeletedPostIdsFromDetail.isEmpty) return;
    final deletedIdSet = _pendingDeletedPostIdsFromDetail.toSet();
    _pendingDeletedPostIdsFromDetail.clear();

    final updatedPosts = removePostsByIds(_posts, deletedIdSet);

    if (updatedPosts.length == _posts.length) return;

    _visiblePostAccumulator.reset(seedPosts: updatedPosts);
    _updateBodyState(posts: updatedPosts, isLoading: false);

    final currentUser = _userController.currentUser;
    if (currentUser != null) {
      _categoryPostsCache.write(
        _cacheKeyForUser(currentUser.id),
        posts: updatedPosts,
        mutationRevision: _currentMutationRevision(userId: currentUser.id),
      );
    }
  }

  /// 첫 페이지 이후의 결과를 이어 붙여 목록과 캐시를 점진적으로 확장합니다.
  Future<void> _loadRemainingPagesInBackground({
    required int generation,
    required int userId,
    required int categoryId,
    required String cacheKey,
    required Stopwatch startedAt,
    required int loadedPages,
    required int totalFetchedPosts,
    required int totalDedupedPosts,
    bool forceRefresh = false,
  }) async {
    var pagesLoaded = loadedPages;
    var fetchedPosts = totalFetchedPosts;
    var dedupedPosts = totalDedupedPosts;
    try {
      while (mounted &&
          generation == _pagingGeneration &&
          _hasMorePages &&
          _nextPage < _kMaxCategoryPostsPages) {
        final currentPage = _nextPage;

        final pagePosts = await _postController.getPostsByCategory(
          categoryId: categoryId,
          userId: userId,
          notificationId: null,
          page: currentPage,
          notifyLoading: false,
          forceRefresh: forceRefresh,
        );
        if (!mounted || generation != _pagingGeneration) return;

        if (pagePosts.isEmpty) {
          _hasMorePages = false;
          break;
        }

        pagesLoaded++;
        fetchedPosts += pagePosts.length;

        final pageResult = _visiblePostAccumulator.appendPage(pagePosts);
        dedupedPosts += pageResult.duplicateRemoved;

        _nextPage = currentPage + 1;

        if (pageResult.posts.isNotEmpty) {
          final updatedPosts = <Post>[..._posts, ...pageResult.posts];
          _updateBodyState(posts: updatedPosts, isLoading: false);
          _categoryPostsCache.write(
            cacheKey,
            posts: updatedPosts,
            mutationRevision: _currentMutationRevision(userId: userId),
          );
          _prefetchVideoThumbnails(pageResult.posts);
        }
      }
      if (_nextPage >= _kMaxCategoryPostsPages) {
        _hasMorePages = false;
      }
    } catch (e) {
      if (foundation.kDebugMode) {
        debugPrint('[ApiCategoryPhotosScreen] 백그라운드 페이징 실패: $e');
      }
    } finally {
      if (foundation.kDebugMode && generation == _pagingGeneration) {
        debugPrint(
          '[_loadPosts] background complete latency=${startedAt.elapsedMilliseconds}ms '
          'pages=$pagesLoaded fetched=$fetchedPosts loaded=${_posts.length} '
          'deduped=$dedupedPosts hasMore=$_hasMorePages nextPage=$_nextPage',
        );
      }
    }
  }

  /// 화면에 등장할 비디오 썸네일을 소량만 먼저 워밍업합니다.
  void _prefetchVideoThumbnails(List<Post> posts) {
    final videoPosts = posts.where((post) => post.isVideo).toList();

    if (videoPosts.isEmpty) return;

    final videosToFetch = videoPosts.take(4).toList();

    if (foundation.kDebugMode) {
      debugPrint('[VideoThumbnail] ${videosToFetch.length}개 비디오 썸네일 프리페칭 시작');
    }

    for (final post in videosToFetch) {
      final url = post.postFileUrl;
      if (url == null || url.isEmpty) continue;

      final cacheKey = VideoThumbnailCache.buildStableCacheKey(
        fileKey: post.postFileKey,
        videoUrl: url,
      );

      if (VideoThumbnailCache.getFromMemory(cacheKey) != null) {
        continue;
      }

      VideoThumbnailCache.getThumbnail(videoUrl: url, cacheKey: cacheKey);
    }
  }

  /// 전역 포스트 변경 알림을 현재 카테고리 갱신으로 연결합니다.
  void _attachPostChangedListenerIfNeeded() {
    if (_postsChangedListener != null) return;

    _postsChangedListener = () {
      if (!mounted) return;
      final currentUser = _userController.currentUser;
      if (currentUser == null) return;

      _categoryPostsCache.remove(_cacheKeyForUser(currentUser.id));

      if (!_isRouteVisible) {
        _needsRefreshOnVisible = true;
        return;
      }

      unawaited(_loadPosts(forceRefresh: true));
    };

    _postController.addPostsChangedListener(_postsChangedListener!);
  }

  /// 멤버 추가 뒤 카테고리 인원 수가 변하면 최신 바텀시트를 다시 엽니다.
  Future<void> _handleAddFriends() async {
    final category = _currentCategory;
    final previousCount = category.totalUserCount;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendListAddScreen(
          categoryId: category.id.toString(),
          categoryMemberUids: null,
        ),
      ),
    );

    final updatedCategory = await _refreshCategory();
    if (!mounted) return;

    if (updatedCategory != null &&
        updatedCategory.totalUserCount != previousCount) {
      showApiCategoryMembersBottomSheet(
        context,
        category: updatedCategory,
        onAddFriendPressed: _handleAddFriends,
      );
    }
  }

  /// 편집 또는 멤버 변경 뒤 최신 카테고리와 헤더 프리페치 상태를 동기화합니다.
  Future<Category?> _refreshCategory() async {
    final userId = _userController.currentUser?.id;
    if (userId == null) {
      return _currentCategory;
    }

    await _categoryController.loadCategories(userId, forceReload: true);

    final updated = _categoryController.getCategoryById(_currentCategory.id);
    final current = updated ?? _currentCategory;
    final nextHeaderImagePrefetch = CategoryHeaderImagePrefetch.fromCategory(
      current,
    );
    final headerChanged =
        _headerImagePrefetch?.imageUrl != nextHeaderImagePrefetch?.imageUrl ||
        _headerImagePrefetch?.cacheKey != nextHeaderImagePrefetch?.cacheKey;

    if (nextHeaderImagePrefetch != null) {
      _headerImageMemoryCache[current.id] = nextHeaderImagePrefetch;
    } else {
      _headerImageMemoryCache.remove(current.id);
    }

    if (mounted && updated != null) {
      setState(() {
        _category = updated;
        _headerImagePrefetch = nextHeaderImagePrefetch;
      });
    } else {
      _headerImagePrefetch = nextHeaderImagePrefetch;
    }

    if (headerChanged && nextHeaderImagePrefetch != null) {
      unawaited(_precacheHeaderImageIfNeeded(nextHeaderImagePrefetch));
    }
    return current;
  }

  /// 편집 진입 전 헤더 이미지를 워밍업하고 복귀 후 최신 카테고리를 다시 불러옵니다.
  Future<void> _openCategoryEditor() async {
    final prefetched = _headerImagePrefetch;
    if (prefetched != null) {
      unawaited(_precacheHeaderImageIfNeeded(prefetched));
    }

    final categoryForEditor = _currentCategory.copyWith(
      photoUrl: prefetched?.imageUrl ?? _currentCategory.photoUrl,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryEditorScreen(
          category: categoryForEditor,
          initialCoverPhotoUrl: prefetched?.imageUrl,
          initialCoverPhotoCacheKey: prefetched?.cacheKey,
        ),
      ),
    );
    if (!mounted) return;
    await _refreshCategory();
  }

  /// 현재 카테고리 멤버 바텀시트를 열고 추가 액션을 연결합니다.
  void _showCategoryMembersBottomSheet() {
    showApiCategoryMembersBottomSheet(
      context,
      category: _currentCategory,
      onAddFriendPressed: _handleAddFriends,
    );
  }

  int get _gridCrossAxisCount => 2;
  double get _gridMainAxisSpacing => 11.sp;
  double get _gridCrossAxisSpacing => 11.sp;

  /// 카테고리 사진 그리드의 공통 레이아웃 값을 제공합니다.
  EdgeInsets get _gridPadding => EdgeInsets.only(
    left: (20.05).w,
    right: (20.05).w,
    top: 20.h,
    bottom: 30.h,
  );

  @override
  Widget build(BuildContext context) {
    final topSafeArea = MediaQuery.paddingOf(context).top;
    final collapsedHeight = topSafeArea + kToolbarHeight;
    final expandedHeight = 253.h;

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: Colors.white,
        backgroundColor: Colors.grey.shade800,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            ApiCategoryPhotosHeader(
              category: _currentCategory,
              backgroundImageUrl: _headerImagePrefetch?.imageUrl,
              backgroundImageCacheKey: _headerImagePrefetch?.cacheKey,
              collapsedHeight: collapsedHeight,
              expandedHeight: expandedHeight,
              onBackPressed: () => Navigator.of(context).maybePop(),
              onMembersPressed: _showCategoryMembersBottomSheet,
              onMenuPressed: () {
                unawaited(_openCategoryEditor());
              },
            ),
            ValueListenableBuilder<_CategoryPhotosBodyState>(
              valueListenable: _bodyStateNotifier,
              builder: (context, bodyState, _) {
                return _buildBodySliver(bodyState);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 본문 스냅샷에 맞는 단일 슬리버만 선택해 상태 분기를 단순하게 유지합니다.
  Widget _buildBodySliver(_CategoryPhotosBodyState bodyState) {
    if (bodyState.isLoading) {
      return ApiCategoryPhotosLoadingSliver(
        padding: _gridPadding,
        crossAxisCount: _gridCrossAxisCount,
        mainAxisSpacing: _gridMainAxisSpacing,
        crossAxisSpacing: _gridCrossAxisSpacing,
      );
    }

    final errorMessageKey = bodyState.errorMessageKey;
    if (errorMessageKey != null) {
      return ApiCategoryPhotosErrorSliver(
        errorMessageKey: errorMessageKey,
        onRetry: _loadPosts,
      );
    }

    if (bodyState.posts.isEmpty) {
      return const ApiCategoryPhotosEmptySliver();
    }

    return ApiCategoryPhotosGridSliver(
      posts: bodyState.posts,
      categoryName: _currentCategory.name,
      categoryId: _currentCategory.id,
      padding: _gridPadding,
      crossAxisCount: _gridCrossAxisCount,
      mainAxisSpacing: _gridMainAxisSpacing,
      crossAxisSpacing: _gridCrossAxisSpacing,
      onPostsDeleted: _onPostsDeletedFromDetail,
    );
  }
}
