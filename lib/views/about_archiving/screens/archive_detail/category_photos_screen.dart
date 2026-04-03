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

  ///
  /// 카테고리 사진 화면
  /// 카테고리에 속한 사진(포스트)을 그리드 형태로 보여주는 화면입니다.
  /// 사용자는 이 화면에서 카테고리 멤버를 확인하고, 카테고리를 편집할 수 있습니다.
  ///
  /// 주요 기능:
  /// - 카테고리에 속한 사진(포스트) 목록을 로드하여 그리드로 표시
  /// - 로딩, 에러, 빈 상태에 따른 UI 표시
  /// - 당겨서 새로고침 기능
  /// - 카테고리 멤버 확인 및 친구 추가 기능
  /// - 카테고리 편집 화면으로 이동 기능
  ///
  /// fields:
  /// - [category]: 현재 카테고리 정보를 담고 있는 Category 객체입니다.
  /// - [prefetchedHeaderImage]: 카테고리 헤더 이미지 프리페치 페이로드로, 초기 렌더링 시 헤더 이미지를 빠르게 표시하는 데 사용됩니다.
  /// - [initialPostId]: (선택적) 초기 딥링크된 포스트 ID로, 이 값이 제공되면 해당 포스트를 상세 화면으로 바로 엽니다.
  ///
  /// Returns:
  /// - [ApiCategoryPhotosScreen]: 카테고리에 속한 사진 그리드 화면을 표시하는 StatefulWidget
  ///
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
  static const int _kMaxCategoryPostsPages = 50; // 페이지 무한 조회 방지 안전 가드
  static final CategoryPostsScreenCacheStore _categoryPostsCache =
      CategoryPostsScreenCacheStore(); // 카테고리별 포스트 캐시 저장소
  static final Map<int, CategoryHeaderImagePrefetch> _headerImageMemoryCache =
      {}; // 카테고리 ID별 헤더 이미지 프리페치 페이로드를 메모리에 캐싱하는 맵

  final ValueNotifier<_CategoryPhotosBodyState> _bodyStateNotifier =
      ValueNotifier<_CategoryPhotosBodyState>((
        posts: const <Post>[],
        isLoading: true,
        errorMessageKey: null,
      ));
  Category? _category; // 갱신된 카테고리 정보
  CategoryHeaderImagePrefetch? _headerImagePrefetch;
  final CategoryPostsVisibleAccumulator _visiblePostAccumulator =
      CategoryPostsVisibleAccumulator();

  late final CategoryController _categoryController;
  late final PostController _postController;
  late final UserController _userController;
  late final FriendController _friendController;
  VoidCallback? _postsChangedListener; // 포스트 변경을 감지하는 리스너
  int _pagingGeneration = 0; // 새 로드 시작 시 기존 백그라운드 페이징 무효화
  bool _isBackgroundPaging = false; // 백그라운드에서 페이지를 로드 중인지 여부
  bool _hasMorePages = false; // 추가 페이지가 있는지 여부
  int _nextPage = 1; // 다음에 로드할 페이지 번호

  // 현재 라우트가 사용자에게 보이는 상태인지 여부
  // 사용자가 화면을 보고 있는 지를 체크하는 변수이다.
  bool _isRouteVisible = true;

  // 보이지 않는 상태에서 변경 감지 시, 복귀 시 1회 새로고침이 필요한지 여부
  bool _needsRefreshOnVisible = false;
  final Set<int> _pendingDeletedPostIdsFromDetail =
      <int>{}; // 상세에서 전달된 삭제 결과를 안전 시점에 반영하기 위한 임시 버퍼
  Timer? _deferredVisibleRefreshTimer;
  bool _isRouteObserverSubscribed = false; // RouteObserver 구독 상태
  ModalRoute<void>? _subscribedRoute; // 현재 구독 중인 라우트

  Category get _currentCategory => _category ?? widget.category;
  _CategoryPhotosBodyState get _bodyState => _bodyStateNotifier.value;
  List<Post> get _posts => _bodyState.posts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeRouteObserverIfNeeded(); // 라우트 옵저버 구독
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

    // 화면이 렌더링된 후 초기 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (_headerImagePrefetch != null) {
        unawaited(_precacheHeaderImageIfNeeded(_headerImagePrefetch!));
      }

      _categoryController.markCategoryAsViewed(_currentCategory.id);

      // 리스너 등록을 데이터 로딩 전에 수행하여 타이밍 이슈 방지
      // 게시물 추가 알림을 놓치지 않도록 즉시 등록
      _attachPostChangedListenerIfNeeded();

      if (widget.initialPostId != null) {
        await _openInitialDeepLinkedPost(widget.initialPostId!);
        return;
      }

      await _loadPosts(); // 초기 데이터 로드
    });
  }

  // Provider가 관리하는 컨트롤러는 dispose하지 않음
  @override
  void dispose() {
    _deferredVisibleRefreshTimer?.cancel();
    if (_isRouteObserverSubscribed) {
      // 라우트 옵저버 구독 해제
      // 현재 구독 중인 라우트가 있다면 옵저버에서 구독 해제하고 상태 업데이트
      appRouteObserver.unsubscribe(this);

      // 구독 상태 초기화
      // 구독 해제 후에는 구독 상태를 초기화하여, 다음에 라우트가 변경될 때 올바르게 구독이 재설정될 수 있도록 합니다.
      _isRouteObserverSubscribed = false;
    }

    // 포스트 변경 리스너 제거
    if (_postsChangedListener != null) {
      _postController.removePostsChangedListener(_postsChangedListener!);
    }
    _bodyStateNotifier.dispose();
    super.dispose();
  }

  /// 라우트 옵저버 구독
  /// 현재 라우트에 구독되어 있지 않다면 구독을 시작합니다.
  /// 이미 구독 중인 경우에는 아무 작업도 수행하지 않습니다.
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

    // 상세 -> 목록 복귀 직후 레이아웃 안정화를 위해 약간 지연 후 새로고침합니다.
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

  /// 본문 상태를 immutable 스냅샷으로 갱신해 헤더 리빌드를 분리합니다.
  void _setBodyState(_CategoryPhotosBodyState nextState) {
    if (!mounted) return;
    _bodyStateNotifier.value = nextState;
  }

  /// 포스트 목록은 유지한 채 본문만 로딩 상태로 전환합니다.
  void _showLoadingBody() {
    _setBodyState((posts: _posts, isLoading: true, errorMessageKey: null));
  }

  /// 화면에 보이는 포스트 목록을 교체하고 로딩 및 에러 상태를 정리합니다.
  void _showLoadedPosts(List<Post> posts) {
    _setBodyState((
      posts: List<Post>.unmodifiable(posts),
      isLoading: false,
      errorMessageKey: null,
    ));
  }

  /// 기존 포스트를 유지한 채 로딩 상태만 종료합니다.
  void _finishLoadingWithCurrentPosts() {
    _setBodyState((posts: _posts, isLoading: false, errorMessageKey: null));
  }

  /// 빈 화면일 때만 표시되는 로컬라이즈 에러 키를 본문 상태에 기록합니다.
  void _showBodyError(String errorMessageKey) {
    _setBodyState((
      posts: _posts,
      isLoading: false,
      errorMessageKey: errorMessageKey,
    ));
  }

  /// 현재 사용자와 카테고리 기준의 mutation revision을 한 곳에서 계산합니다.
  int _currentMutationRevision({required int userId}) {
    return _postController.getCategoryMutationRevision(
      userId: userId,
      categoryId: _currentCategory.id,
    );
  }

  /// 아카이브 상세 화면용 카테고리 캐시 키를 일관되게 생성합니다.
  String _cacheKeyForUser(int userId) {
    return buildCategoryPostsCacheKey(
      userId: userId,
      categoryId: _currentCategory.id,
    );
  }

  /// 새 로드가 시작될 때 기존 백그라운드 페이징 상태를 초기화합니다.
  void _resetPagingSession() {
    _isBackgroundPaging = false;
    _hasMorePages = false;
    _nextPage = 1;
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

  /// 카테고리 내 사진(포스트) 목록 로드
  Future<void> _loadPosts({bool forceRefresh = false}) async {
    if (!mounted) return;
    final loadStopwatch = Stopwatch()..start();
    final generation = ++_pagingGeneration;
    _resetPagingSession();

    try {
      // 현재 사용자 ID 가져오기
      final currentUser = _userController.currentUser;
      if (currentUser == null) {
        _showBodyError('common.login_required');
        return;
      }

      // 캐시 확인
      final cacheKey = _cacheKeyForUser(currentUser.id);
      // 캐시 유효성 판단을 위한 현재 카테고리의 포스트 변경 이력 번호를 가져옵니다.
      final currentMutationRevision = _currentMutationRevision(
        userId: currentUser.id,
      );

      // Optimistic UI: 만료된 캐시도 일단 사용
      final cached = _categoryPostsCache.read(
        cacheKey,
        allowExpired: true,
        currentMutationRevision: currentMutationRevision,
      );

      // 신선한(?) 캐시를 즉시 UI에 반영하고, 만료 여부와 관계없이 캐시가 존재하면 API 호출을 백그라운드에서 진행합니다.
      final freshCache = _categoryPostsCache.read(
        cacheKey,
        allowExpired: false,
        currentMutationRevision: currentMutationRevision,
      );

      if (cached != null && !forceRefresh) {
        // 즉시 캐시 데이터 표시 (만료 여부와 관계없이)
        _showLoadedPosts(cached.posts);

        // 캐시가 신선하면 여기서 종료
        if (freshCache != null) {
          if (foundation.kDebugMode) {
            debugPrint('[_loadPosts] 신선한 캐시 사용, API 호출 생략');
          }
          return;
        }
        // 만료된 캐시인 경우 백그라운드에서 새로고침 계속 진행
        // (UI는 이미 표시됨)
        if (foundation.kDebugMode) {
          debugPrint('[_loadPosts] 만료된 캐시 표시, 백그라운드 갱신 시작');
        }
      } else {
        _showLoadingBody();
      }

      // 1단계: page=0 + 차단 유저를 병렬 조회 후 즉시 렌더
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
      _isBackgroundPaging = _hasMorePages;

      _showLoadedPosts(visiblePosts);

      _syncCategoryPostsCache(
        cacheKey,
        mutationRevision: currentMutationRevision,
      );

      // 비디오 썸네일 프리페칭 (백그라운드)
      _prefetchVideoThumbnails(visiblePosts);

      if (foundation.kDebugMode) {
        debugPrint(
          '[_loadPosts] first-page latency=${loadStopwatch.elapsedMilliseconds}ms '
          'fetched=${firstPagePosts.length} visible=${visiblePosts.length} '
          'blockedRemoved=${firstPageResult.blockedRemoved} '
          'deduped=${firstPageResult.duplicateRemoved}',
        );
      }

      // 2단계: page=1..N 백그라운드 누적
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
      } else {
        _isBackgroundPaging = false;
      }
    } catch (e) {
      debugPrint('[ApiCategoryPhotosScreen] 포스트 로드 실패: $e');
      // Optimistic UI: 에러 시에도 기존 캐시 데이터 유지
      if (!mounted) return;

      // 캐시된 데이터가 없을 때만 에러 메시지 표시
      if (_posts.isEmpty) {
        _showBodyError('archive.photo_load_failed');
      } else {
        // 캐시된 데이터가 있으면 유지하고 로딩만 종료
        _finishLoadingWithCurrentPosts();
        if (foundation.kDebugMode) {
          debugPrint('[_loadPosts] 갱신 실패했지만 캐시 데이터 유지');
        }
      }
    }
  }

  /// 새로고침
  Future<void> _onRefresh() async {
    await _loadPosts(forceRefresh: true);
  }

  /// 상세 화면에서 포스트가 삭제된 경우, 해당 포스트를 목록에서 제거하는 메서드
  /// 상세 화면에서 삭제된 포스트의 ID 리스트를 받아,
  /// 현재 화면에 표시된 포스트 목록에서 해당 ID에 해당하는 포스트를 제거합니다.
  ///
  /// Parameters:
  /// - [deletedPostIds]: 상세 화면에서 삭제된 포스트의 ID 리스트로,
  ///                     이 ID들을 기준으로 현재 화면에 표시된 포스트 목록에서 삭제된 포스트를 제거합니다.
  void _onPostsDeletedFromDetail(List<int> deletedPostIds) {
    if (!mounted || deletedPostIds.isEmpty) return;
    _pendingDeletedPostIdsFromDetail.addAll(deletedPostIds);

    // 상세에서 명시적으로 전달된 삭제 결과는 로컬 반영을 신뢰하고
    // 복귀 직후 강제 리로드를 건너뜁니다.
    _needsRefreshOnVisible = false;
    _deferredVisibleRefreshTimer?.cancel();

    if (!_isRouteVisible) return;
    _applyPendingDeletedPostsFromDetail();
  }

  void _applyPendingDeletedPostsFromDetail() {
    if (!mounted || _pendingDeletedPostIdsFromDetail.isEmpty) return;
    final deletedIdSet = _pendingDeletedPostIdsFromDetail.toSet();
    _pendingDeletedPostIdsFromDetail.clear();

    final updatedPosts = removePostsByIds(_posts, deletedIdSet);

    if (updatedPosts.length == _posts.length) return;

    _visiblePostAccumulator.reset(seedPosts: updatedPosts);
    _showLoadedPosts(updatedPosts);

    final currentUser = _userController.currentUser;
    if (currentUser != null) {
      final cacheKey = _cacheKeyForUser(currentUser.id);
      _syncCategoryPostsCache(
        cacheKey,
        mutationRevision: _currentMutationRevision(userId: currentUser.id),
      );
    }
  }

  /// 백그라운드에서 남은 페이지를 로드하는 메서드
  ///
  /// Parameters:
  /// - [generation]: 현재 페이징 세션을 식별하는 고유 번호로, 새 로드가 시작될 때마다 증가합니다.
  ///                 백그라운드 작업이 오래 걸리는 경우, 사용자가 새로고침을 해서 새로운 로드가 시작될 수 있기 때문에,
  ///                 이 값을 통해 오래된 백그라운드 작업이 결과를 반영하지 않도록 합니다.
  /// - [userId]: 현재 사용자 ID로, API 호출에 필요합니다.
  /// - [categoryId]: 현재 카테고리 ID로, API 호출에 필요합니다.
  /// - [cacheKey]: 현재 카테고리의 캐시 키로, 새로 로드된 포스트 목록을 캐시에 저장할 때 사용합니다.
  /// - [startedAt]: 전체 로드 작업이 시작된 시점의 Stopwatch로, 로드 작업의 지연 시간을 측정하는 데 사용합니다.
  /// - [loadedPages]: 이미 로드된 페이지 수로, 첫 페이지는 이미 로드된 상태에서 이 메서드가 호출되므로 1로 시작합니다.
  /// - [totalFetchedPosts]: 지금까지 API에서 받아온  포스트의 총 수로, 중복 제거 전의 수입니다.
  /// - [totalDedupedPosts]: 지금까지 중복 제거 후 최종적으로 화면에 표시된 포스트의 총 수입니다.
  ///
  /// Returns: `Future<void>`로, 모든 페이지 로드가 완료되거나, 더 이상 로드할 페이지가 없거나, 또는 로드 작업이 무효화될 때 완료됩니다.
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
        final currentPage =
            _nextPage; // 현재 로드할 페이지 번호를 nextPage에서 읽어와 지역 변수로 저장

        // 다음 페이지 로드
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

        pagesLoaded++; // 로드된 페이지 수 증가
        fetchedPosts += pagePosts.length; // API에서 받아온 포스트 수 누적

        final pageResult = _visiblePostAccumulator.appendPage(pagePosts);
        dedupedPosts += pageResult.duplicateRemoved;

        _nextPage = currentPage + 1;

        if (pageResult.posts.isNotEmpty) {
          _showLoadedPosts(<Post>[..._posts, ...pageResult.posts]);
          _syncCategoryPostsCache(
            cacheKey,
            mutationRevision: _postController.getCategoryMutationRevision(
              userId: userId,
              categoryId: categoryId,
            ),
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
      if (generation == _pagingGeneration) {
        _isBackgroundPaging = false;
      }
      if (foundation.kDebugMode && generation == _pagingGeneration) {
        debugPrint(
          '[_loadPosts] background complete latency=${startedAt.elapsedMilliseconds}ms '
          'pages=$pagesLoaded fetched=$fetchedPosts loaded=${_posts.length} '
          'deduped=$dedupedPosts hasMore=$_hasMorePages nextPage=$_nextPage '
          'isBackgroundPaging=$_isBackgroundPaging',
        );
      }
    }
  }

  /// 카테고리별 포스트 캐시를 동기화하는 메서드
  /// 현재 로드된 포스트 목록을 기반으로 캐시를 업데이트하여, 다음에 동일한 카테고리를 로드할 때 빠르게 데이터를 제공할 수 있도록 합니다.
  ///
  /// Parameters:
  /// - [cacheKey]: 업데이트할 캐시 항목의 키로, 일반적으로 'userId:categoryId' 형식입니다.
  void _syncCategoryPostsCache(
    String cacheKey, {
    // 현재 카테고리의 포스트 변경 이력을 추적하는 번호로, 변경이 발생할 때마다 증가합니다.
    // 캐시의 유효성을 판단할 때 사용됩니다.
    required int mutationRevision,
  }) {
    _categoryPostsCache.write(
      cacheKey,
      posts: _posts,
      mutationRevision: mutationRevision,
    );
  }

  /// 비디오 썸네일 프리페칭
  ///
  /// 화면에 표시될 비디오들의 썸네일을 백그라운드에서 미리 생성합니다.
  /// 이를 통해 사용자가 그리드를 스크롤할 때 썸네일이 즉시 표시됩니다.
  void _prefetchVideoThumbnails(List<Post> posts) {
    final videoPosts = posts.where((post) => post.isVideo).toList();

    if (videoPosts.isEmpty) return;

    // 초반 메모리 버스트를 줄이기 위해 상한을 낮춰 프리페칭합니다.
    final videosToFetch = videoPosts.take(4).toList();

    if (foundation.kDebugMode) {
      debugPrint('[VideoThumbnail] ${videosToFetch.length}개 비디오 썸네일 프리페칭 시작');
    }

    for (final post in videosToFetch) {
      final url = post.postFileUrl;
      if (url == null || url.isEmpty) continue;

      // 캐시 키 생성
      final cacheKey = VideoThumbnailCache.buildStableCacheKey(
        fileKey: post.postFileKey,
        videoUrl: url,
      );

      // 이미 메모리 캐시에 있으면 스킵
      if (VideoThumbnailCache.getFromMemory(cacheKey) != null) {
        continue;
      }

      // 백그라운드에서 3-tier 조회 (Memory → Disk → Generate)
      VideoThumbnailCache.getThumbnail(videoUrl: url, cacheKey: cacheKey);
    }
  }

  /// 포스트 변경 리스너를 등록
  void _attachPostChangedListenerIfNeeded() {
    if (_postsChangedListener != null) return;

    _postsChangedListener = () {
      if (!mounted) return;
      final currentUser = _userController.currentUser;
      if (currentUser == null) return;

      // 해당 카테고리의 캐시 항목 제거
      _categoryPostsCache.remove(_cacheKeyForUser(currentUser.id));

      // 비가시 상태에서는 즉시 리로드를 미루고 복귀 시 1회 갱신합니다.
      if (!_isRouteVisible) {
        _needsRefreshOnVisible = true;
        return;
      }

      unawaited(_loadPosts(forceRefresh: true));
    };

    // 리스너 등록
    _postController.addPostsChangedListener(_postsChangedListener!);
  }

  /// 친구 추가를 처리하는 메서드
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

    final updatedCategory = await _refreshCategory(); // 카테고리 정보 갱신
    if (!mounted) return;

    if (updatedCategory != null &&
        updatedCategory.totalUserCount != previousCount) {
      // 멤버 수가 변경된 경우에만 바텀시트 표시
      showApiCategoryMembersBottomSheet(
        context,
        category: updatedCategory,
        onAddFriendPressed: _handleAddFriends,
      );
    }
  }

  /// 카테고리 정보를 갱신하는 메서드
  Future<Category?> _refreshCategory() async {
    final userId = _userController.currentUser?.id;
    if (userId == null) {
      return _currentCategory;
    }

    // 카테고리 목록을 로드하고 캐시합니다.
    await _categoryController.loadCategories(userId, forceReload: true);

    // ID로 캐시된 카테고리 가져오기
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

  /// 카테고리 편집 화면으로 이동하는 메서드
  Future<void> _openCategoryEditor() async {
    final prefetched = _headerImagePrefetch;
    if (prefetched != null) {
      // Editor 진입 직전에 한 번 더 워밍업해 첫 프레임 플리커를 줄입니다.
      unawaited(_precacheHeaderImageIfNeeded(prefetched));
    }

    final categoryForEditor = _currentCategory.copyWith(
      photoUrl: prefetched?.imageUrl ?? _currentCategory.photoUrl,
    );

    // 편집 화면에서 돌아온 후 카테고리 정보를 갱신하여 변경사항 반영
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

  /// 카테고리 멤버 바텀시트를 표시하는 메서드:
  /// showApiCategoryMembersBottomSheet를 호출하여 현재 카테고리의 멤버 정보를 보여주는 바텀시트를 띄웁니다.
  void _showCategoryMembersBottomSheet() {
    showApiCategoryMembersBottomSheet(
      context,
      category: _currentCategory,
      onAddFriendPressed: _handleAddFriends,
    );
  }

  int get _gridCrossAxisCount => 2; // 그리드의 열 수
  double get _gridMainAxisSpacing => 11.sp; // 그리드의 행 간격
  double get _gridCrossAxisSpacing => 11.sp; // 그리드의 열 간격

  /// 그리드 패딩을 반환하는 게터
  EdgeInsets get _gridPadding => EdgeInsets.only(
    left: (20.05).w,
    right: (20.05).w,
    top: 20.h,
    bottom: 30.h,
  );

  @override
  Widget build(BuildContext context) {
    final topSafeArea = MediaQuery.paddingOf(context).top; // 상단 안전 영역 높이
    final collapsedHeight = topSafeArea + kToolbarHeight; // 축소된 헤더 높이

    /// 확장된 헤더 높이
    final expandedHeight = 253.h;

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _onRefresh, // 당겨서 새로고침 기능
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

  /// 현재 본문 스냅샷에 맞는 단일 슬리버를 선택해 렌더링합니다.
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
