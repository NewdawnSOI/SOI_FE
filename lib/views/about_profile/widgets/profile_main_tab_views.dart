import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

import '../../../api/controller/audio_controller.dart';
import '../../../api/controller/comment_controller.dart';
import '../../../api/controller/post_controller.dart';
import '../../../api/models/comment.dart';
import '../../../api/models/post.dart';
import '../../about_archiving/widgets/api_photo_grid_item.dart';
import '../../about_archiving/widgets/archive_card_widget/archive_card_placeholders.dart';
import 'threaded_comment_row.dart';

class ProfilePostTabView extends StatefulWidget {
  ///
  /// 프로필 메인 탭의 게시물과 댓글 뷰
  /// - 게시물 탭은 ApiPhotoGridItem을 사용하여 사진과 동영상 게시물을 표시합니다.
  /// - 댓글 탭은 ThreadedCommentRow를 사용하여 사용자가 작성한 댓글 스레드를 표시합니다.
  /// - 두 탭 모두 초기 로딩, 오류 상태, 빈 상태를 처리하며, 스크롤 위치에 따라 추가 데이터를 로드하는 무한 스크롤을 구현합니다.
  ///
  /// Parameters:
  /// - [userId]: 표시할 게시물과 댓글의 사용자 ID. null인 경우 빈 상태를 표시합니다.
  /// - [postType]: 게시물 탭에서 표시할 게시물 유형 (사진/동영상 또는 텍스트).
  /// - [isActive]: 탭이 현재 활성화되어 있는지 여부. 활성화되지 않은 경우 초기 로딩을 지연시킵니다.
  /// - [detailTitle]: ApiPhotoGridItem에 전달할 카테고리 이름 (게시물 탭에서만 사용).
  /// - [emptyMessageKey]: 게시물 또는 댓글이 없는 경우 표시할 메시지의 로컬라이즈된 키.
  ///
  const ProfilePostTabView({
    super.key,
    required this.userId,
    required this.postType,
    required this.isActive,
    required this.detailTitle,
    required this.emptyMessageKey,
  });

  final int? userId;
  final PostType postType;
  final bool isActive;
  final String detailTitle;
  final String emptyMessageKey;

  @override
  State<ProfilePostTabView> createState() => _ProfilePostTabViewState();
}

class _ProfilePostTabViewState extends State<ProfilePostTabView>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  List<Post> _posts = const <Post>[];
  bool _initialLoadScheduled = false; // 위젯 트리가 완성된 후에 초기 로딩을 시도하기 위한 플래그
  bool _hasLoadedOnce = false;
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _hasLoadError = false;
  int _nextPage = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _scheduleMaybeLoadInitial(); // 초기 로딩을 시도하되, 위젯 트리가 완성된 후에 실행되도록 예약
  }

  @override
  void didUpdateWidget(covariant ProfilePostTabView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final userChanged = oldWidget.userId != widget.userId;
    final typeChanged = oldWidget.postType != widget.postType;
    if (userChanged || typeChanged) {
      _resetState();
      _scheduleMaybeLoadInitial();
      return;
    }

    if (!oldWidget.isActive && widget.isActive) {
      _scheduleMaybeLoadInitial();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _resetState() {
    _posts = const <Post>[];
    _hasLoadedOnce = false;
    _isInitialLoading = false;
    _isLoadingMore = false;
    _hasMore = true;
    _hasLoadError = false;
    _nextPage = 0;
  }

  void _maybeLoadInitial() {
    if (!widget.isActive || _hasLoadedOnce || _isInitialLoading) {
      return;
    }
    _loadInitial();
  }

  /// 초기 로딩을 시도하되, 위젯 트리가 완성된 후에 실행되도록 예약하는 메서드입니다.
  void _scheduleMaybeLoadInitial() {
    if (_initialLoadScheduled) return;

    _initialLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialLoadScheduled = false;
      if (!mounted) return;
      _maybeLoadInitial();
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        !_hasLoadedOnce ||
        _isInitialLoading ||
        _isLoadingMore ||
        !_hasMore) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  /// 프로필 탭이 기대하는 2분류 기준으로 게시물을 필터링하고 안정적으로 정렬합니다.
  List<Post> _normalizePosts(List<Post> rawPosts) {
    final filteredPosts = rawPosts
        .where((post) {
          final postType = post.postType;
          if (widget.postType == PostType.multiMedia) {
            return postType?.isMediaCategory ?? false;
          }
          return postType?.isTextCategory ?? false;
        })
        .toList(growable: false);

    final uniquePosts = <int, Post>{};
    for (final post in filteredPosts) {
      uniquePosts[post.id] = post;
    }

    final normalizedPosts = uniquePosts.values.toList(growable: false)
      ..sort((a, b) {
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime != null && bTime != null) {
          final compare = bTime.compareTo(aTime);
          if (compare != 0) {
            return compare;
          }
        } else if (aTime != null) {
          return -1;
        } else if (bTime != null) {
          return 1;
        }
        return b.id.compareTo(a.id);
      });

    return normalizedPosts;
  }

  Future<void> _loadInitial() async {
    final userId = widget.userId;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _posts = const <Post>[];
        _hasLoadedOnce = true;
        _isInitialLoading = false;
        _isLoadingMore = false;
        _hasMore = false;
        _hasLoadError = false;
        _nextPage = 0;
      });
      return;
    }

    setState(() {
      _isInitialLoading = true;
      _isLoadingMore = false;
      _hasLoadError = false;
    });

    final postController = context.read<PostController>();
    final result = await postController.getMediaByUserId(
      userId: userId,
      postType: widget.postType,
      page: 0,
    );
    if (!mounted) return;
    final normalizedPosts = _normalizePosts(result.posts);
    final hasError =
        (postController.errorMessage?.trim().isNotEmpty ?? false) &&
        normalizedPosts.isEmpty;

    setState(() {
      _posts = normalizedPosts;
      _hasLoadedOnce = true;
      _isInitialLoading = false;
      _hasMore = result.hasMore;
      _hasLoadError = hasError;
      _nextPage = 1;
    });
  }

  Future<void> _loadMore() async {
    final userId = widget.userId;
    if (userId == null || _isLoadingMore || !_hasMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    final postController = context.read<PostController>();
    final result = await postController.getMediaByUserId(
      userId: userId,
      postType: widget.postType,
      page: _nextPage,
    );
    if (!mounted) return;

    final hasError =
        (postController.errorMessage?.trim().isNotEmpty ?? false) &&
        result.posts.isEmpty;
    final mergedPosts = _normalizePosts(<Post>[..._posts, ...result.posts]);

    setState(() {
      _posts = mergedPosts;
      _isLoadingMore = false;
      _hasMore = hasError ? false : result.hasMore;
      _nextPage = hasError ? _nextPage : _nextPage + 1;
    });
  }

  Future<void> _refresh() async {
    _hasLoadedOnce = false;
    _nextPage = 0;
    _hasMore = true;
    await _loadInitial();
  }

  void _removeDeletedPosts(List<int> deletedPostIds) {
    if (deletedPostIds.isEmpty) return;

    setState(() {
      _posts = _posts
          .where((post) => !deletedPostIds.contains(post.id))
          .toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_hasLoadedOnce && !widget.isActive) {
      return const ColoredBox(color: Colors.black);
    }

    if (_isInitialLoading && _posts.isEmpty) {
      return const _ProfilePostGridLoadingView();
    }

    if (_hasLoadError && _posts.isEmpty) {
      return _ProfileRefreshableStatusView(
        onRefresh: _refresh,
        child: _ProfileTabStatusContent(
          messageKey: 'profile.main.load_failed',
          actionLabelKey: 'common.retry',
          onActionPressed: _refresh,
        ),
      );
    }

    if (_posts.isEmpty) {
      return _ProfileRefreshableStatusView(
        onRefresh: _refresh,
        child: _ProfileTabStatusContent(messageKey: widget.emptyMessageKey),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: Colors.white,
      backgroundColor: const Color(0xFF1C1C1C),
      child: MasonryGridView.count(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.only(
          left: (20.05).w,
          right: (20.05).w,
          top: 20.h,
          bottom: 30.h,
        ),
        crossAxisCount: 2,
        mainAxisSpacing: 11.sp,
        crossAxisSpacing: 11.sp,
        itemCount: _posts.length + (_isLoadingMore ? 2 : 0),
        itemBuilder: (context, index) {
          if (index >= _posts.length) {
            return const _ProfileGridPlaceholderCard();
          }

          final post = _posts[index];
          return ApiPhotoGridItem(
            key: ValueKey('profile_post_${widget.postType.name}_${post.id}'),
            post: post,
            postUrl: post.postFileUrl ?? '',
            allPosts: <Post>[post],
            currentIndex: 0,
            categoryName: widget.detailTitle,
            categoryId: post.id,
            initialCommentCount: post.commentCount ?? 0,
            onPostsDeleted: _removeDeletedPosts,
            singlePostMode: true,
          );
        },
      ),
    );
  }
}

class ProfileCommentTabView extends StatefulWidget {
  const ProfileCommentTabView({
    super.key,
    required this.userId,
    required this.isActive,
    required this.emptyMessageKey,
  });

  final int? userId;
  final bool isActive;
  final String emptyMessageKey;

  @override
  State<ProfileCommentTabView> createState() => _ProfileCommentTabViewState();
}

class _ProfileCommentTabViewState extends State<ProfileCommentTabView>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  late final AudioController _audioController;

  List<Comment> _comments = const <Comment>[];

  /// 원댓글과 대댓글이 부모-자식 구조로 묶인 스레드 리스트입니다.
  /// 해당 List를 이용해서 댓글 탭에서 댓글을 렌더링합니다.
  ///
  /// 댓글 탭이 바로 렌더링할 수 있게 변환된 데이터입니다.
  ///
  /// - Comment: 원댓글
  /// - List<[Comment]>: 해당 원댓글의 대댓글 리스트
  List<Map<Comment, List<Comment>>> _commentThreads =
      const <Map<Comment, List<Comment>>>[];

  /// 부모 ID별로 대댓글 리스트를 캐싱하는 맵입니다.
  ///
  /// 댓글 스레드를 구성할 때 원댓글 ID로 대댓글을 빠르게 조회하기 위해 사용합니다.
  ///
  /// - int: 원댓글 ID
  /// - List<[Comment]>: 해당 원댓글의 대댓글 리스트
  final Map<int, List<Comment>> _childCommentsByParentId =
      <int, List<Comment>>{};
  bool _initialLoadScheduled = false; // 위젯 트리가 완성된 후에 초기 로딩을 시도하기 위한 플래그
  bool _hasLoadedOnce = false;
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _hasLoadError = false;
  int _nextPage = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _audioController = AudioController();
    _scrollController.addListener(_handleScroll);
    _scheduleMaybeLoadInitial();
  }

  @override
  void didUpdateWidget(covariant ProfileCommentTabView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId) {
      _resetState(); // 사용자 ID가 변경되면 상태를 초기화합니다.
      _scheduleMaybeLoadInitial(); // 사용자 ID가 변경되면 상태를 초기화하고 새 사용자에 대한 데이터를 로드합니다.
      return;
    }

    if (!oldWidget.isActive && widget.isActive) {
      _scheduleMaybeLoadInitial(); // 탭이 비활성화에서 활성화로 변경된 경우 초기 로딩을 시도합니다.
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _audioController.dispose();
    super.dispose();
  }

  void _resetState() {
    _comments = const <Comment>[];
    _commentThreads = const <Map<Comment, List<Comment>>>[]; // 댓글 스레드 데이터 초기화
    _childCommentsByParentId.clear(); // 부모 ID별 대댓글 캐시 초기화
    _hasLoadedOnce = false;
    _isInitialLoading = false;
    _isLoadingMore = false;
    _hasMore = true;
    _hasLoadError = false;
    _nextPage = 0;
  }

  void _maybeLoadInitial() {
    if (!widget.isActive || _hasLoadedOnce || _isInitialLoading) {
      return;
    }
    _loadInitial();
  }

  /// 초기 로딩을 시도하되, 위젯 트리가 완성된 후에 실행되도록 예약하는 메서드입니다.
  void _scheduleMaybeLoadInitial() {
    if (_initialLoadScheduled) return;

    _initialLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialLoadScheduled = false;
      if (!mounted) return;
      _maybeLoadInitial();
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        !_hasLoadedOnce ||
        _isInitialLoading ||
        _isLoadingMore ||
        !_hasMore) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  List<Comment> _normalizeComments(List<Comment> rawComments) {
    final uniqueComments = <String, Comment>{};
    for (final comment in rawComments) {
      uniqueComments[_commentIdentity(comment)] = comment;
    }

    final normalizedComments = uniqueComments.values.toList(growable: false)
      ..sort((a, b) {
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime != null && bTime != null) {
          final compare = bTime.compareTo(aTime);
          if (compare != 0) {
            return compare;
          }
        } else if (aTime != null) {
          return -1;
        } else if (bTime != null) {
          return 1;
        }
        return (b.id ?? 0).compareTo(a.id ?? 0);
      });

    return normalizedComments;
  }

  /// 사용자 댓글 응답을 클래스 내부 전용 리스트로 복사한 뒤 정렬과 중복 제거를 적용합니다.
  List<Comment> _copyComments(List<Comment> rawComments) {
    return List<Comment>.unmodifiable(
      _normalizeComments(List<Comment>.from(rawComments)),
    );
  }

  /// 댓글의 스레드 관계와 실제 댓글 ID를 함께 반영한 고유 키를 생성합니다.
  String _commentIdentity(Comment comment) {
    final commentId = comment.id;
    if (commentId != null) {
      final parentId = comment.threadParentId?.toString() ?? 'none';
      final prefix = comment.isReply ? 'reply' : 'parent';
      return '$prefix:$parentId:$commentId';
    }

    return [
      comment.userId ?? 0,
      comment.nickname ?? '',
      comment.createdAt?.toIso8601String() ?? '',
      comment.text ?? '',
      comment.audioUrl ?? '',
      comment.fileKey ?? '',
    ].join('|');
  }

  /// 현재 페이지의 원댓글들에 필요한 대댓글 첫 페이지를 병렬로 조회해 스레드 캐시를 채웁니다.
  Future<void> _loadChildCommentsForParents({
    required CommentController commentController,
    required List<Comment> sourceComments,
  }) async {
    final parentsToLoad = sourceComments
        .where((comment) => !comment.isReply && comment.threadParentId != null)
        .where(
          (comment) =>
              !_childCommentsByParentId.containsKey(comment.threadParentId),
        )
        .toList(growable: false);

    if (parentsToLoad.isEmpty) {
      return;
    }

    final loadedChildEntries = await Future.wait(
      parentsToLoad.map((parentComment) async {
        final parentId = parentComment.threadParentId!;
        final result = await commentController.getChildComments(
          parentCommentId: parentId,
          page: 0,
        );
        return MapEntry(parentId, _copyComments(result.comments));
      }),
    );

    for (final entry in loadedChildEntries) {
      _childCommentsByParentId[entry.key] = entry.value;
    }
  }

  /// 원댓글이 확인된 경우에만 부모-자식 스레드를 구성해, 고아 대댓글은 부모가 도착할 때까지 숨깁니다.
  List<Map<Comment, List<Comment>>> _buildCommentThreads(
    List<Comment> sourceComments,
  ) {
    final sourceChildCommentsByParentId = <int, List<Comment>>{};
    for (final comment in sourceComments) {
      final parentId = comment.threadParentId;
      if (!comment.isReply || parentId == null) {
        continue;
      }
      sourceChildCommentsByParentId
          .putIfAbsent(parentId, () => <Comment>[])
          .add(comment);
    }

    final threads = <Map<Comment, List<Comment>>>[];
    for (final comment in sourceComments) {
      if (comment.isReply) {
        continue;
      }

      final parentId = comment.threadParentId;
      final childComments = parentId == null
          ? const <Comment>[]
          : _copyComments([
              ...?_childCommentsByParentId[parentId],
              ...?sourceChildCommentsByParentId[parentId],
            ]);
      threads.add({comment: childComments});
    }

    return List<Map<Comment, List<Comment>>>.unmodifiable(threads);
  }

  /// 한 스레드의 부모 댓글과 대댓글 묶음을 프로필 전용 댓글 행으로 그립니다.
  Widget _buildCommentThreadItem(Map<Comment, List<Comment>> commentThread) {
    final threadEntry = commentThread.entries.single;
    final parentComment = threadEntry.key;
    final childComments = threadEntry.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ThreadedCommentRow(comment: parentComment),
        for (final childComment in childComments) ...[
          SizedBox(height: 15.sp),
          ThreadedCommentRow(comment: childComment),
        ],
      ],
    );
  }

  Future<void> _loadInitial() async {
    final userId = widget.userId;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _comments = const <Comment>[];
        _commentThreads = const <Map<Comment, List<Comment>>>[];
        _childCommentsByParentId.clear();
        _hasLoadedOnce = true;
        _isInitialLoading = false;
        _isLoadingMore = false;
        _hasMore = false;
        _hasLoadError = false;
        _nextPage = 0;
      });
      return;
    }

    setState(() {
      _isInitialLoading = true;
      _isLoadingMore = false;
      _hasLoadError = false;
    });

    final commentController = context.read<CommentController>();
    final result = await commentController.getCommentsByUserId(
      userId: userId,
      page: 0,
    );
    final copiedComments = _copyComments(result.comments);
    await _loadChildCommentsForParents(
      commentController: commentController,
      sourceComments: copiedComments,
    );
    if (!mounted) return;

    final commentThreads = _buildCommentThreads(copiedComments);
    final hasError =
        (commentController.errorMessage?.trim().isNotEmpty ?? false) &&
        copiedComments.isEmpty;

    setState(() {
      _comments = copiedComments;
      _commentThreads = commentThreads;
      _hasLoadedOnce = true;
      _isInitialLoading = false;
      _hasMore = result.hasMore;
      _hasLoadError = hasError;
      _nextPage = 1;
    });
  }

  Future<void> _loadMore() async {
    final userId = widget.userId;
    if (userId == null || _isLoadingMore || !_hasMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    final commentController = context.read<CommentController>();
    final result = await commentController.getCommentsByUserId(
      userId: userId,
      page: _nextPage,
    );
    final copiedComments = _copyComments(<Comment>[
      ..._comments,
      ...result.comments,
    ]);
    await _loadChildCommentsForParents(
      commentController: commentController,
      sourceComments: copiedComments,
    );
    if (!mounted) return;

    final hasError =
        (commentController.errorMessage?.trim().isNotEmpty ?? false) &&
        result.comments.isEmpty;
    final commentThreads = _buildCommentThreads(copiedComments);

    setState(() {
      _comments = copiedComments;
      _commentThreads = commentThreads;
      _isLoadingMore = false;
      _hasMore = hasError ? false : result.hasMore;
      _nextPage = hasError ? _nextPage : _nextPage + 1;
    });
  }

  Future<void> _refresh() async {
    _hasLoadedOnce = false;
    _nextPage = 0;
    _hasMore = true;
    _commentThreads = const <Map<Comment, List<Comment>>>[];
    _childCommentsByParentId.clear();
    await _loadInitial();
  }

  /// 댓글 탭은 실제로 렌더링 가능한 부모 중심 스레드가 있을 때만 목록 상태를 노출합니다.
  bool get _hasRenderableCommentThreads => _commentThreads.isNotEmpty;

  /// 렌더링 가능한 스레드 수를 기준으로 로딩/빈 상태를 결정해 고아 대댓글 단독 노출을 막습니다.
  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_hasLoadedOnce && !widget.isActive) {
      return const ColoredBox(color: Colors.black);
    }

    if (_isInitialLoading && !_hasRenderableCommentThreads) {
      return const _ProfileCommentsLoadingView();
    }

    if (_hasLoadError && !_hasRenderableCommentThreads) {
      return _ProfileRefreshableStatusView(
        onRefresh: _refresh,
        child: _ProfileTabStatusContent(
          messageKey: 'profile.main.load_failed',
          actionLabelKey: 'common.retry',
          onActionPressed: _refresh,
        ),
      );
    }

    if (!_hasRenderableCommentThreads) {
      return _ProfileRefreshableStatusView(
        onRefresh: _refresh,
        child: _ProfileTabStatusContent(messageKey: widget.emptyMessageKey),
      );
    }

    return ChangeNotifierProvider<AudioController>.value(
      value: _audioController,
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: Colors.white,
        backgroundColor: const Color(0xFF1C1C1C),
        child: ListView.separated(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(0, 8.h, 0, 28.h),
          itemCount: _commentThreads.length + (_isLoadingMore ? 1 : 0),
          separatorBuilder: (_, index) {
            // 로딩 인디케이터 앞 구분선이나 범위 밖은 빈 위젯
            if (index >= _commentThreads.length - 1) {
              return const SizedBox.shrink();
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 20.sp),
                const Divider(
                  color: Color(0xFF323232),
                  thickness: 1,
                  height: 1,
                ),
                SizedBox(height: 20.sp),
              ],
            );
          },
          itemBuilder: (context, index) {
            if (index >= _commentThreads.length) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 18.h),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              );
            }
            return _buildCommentThreadItem(_commentThreads[index]);
          },
        ),
      ),
    );
  }
}

class _ProfileRefreshableStatusView extends StatelessWidget {
  const _ProfileRefreshableStatusView({
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: Colors.white,
      backgroundColor: const Color(0xFF1C1C1C),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.42,
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}

class _ProfileTabStatusContent extends StatelessWidget {
  const _ProfileTabStatusContent({
    required this.messageKey,
    this.actionLabelKey,
    this.onActionPressed,
  });

  final String messageKey;
  final String? actionLabelKey;
  final Future<void> Function()? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 36.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr(messageKey, context: context),
            style: TextStyle(
              color: const Color(0xFFB5B5B5),
              fontSize: 15.sp,
              fontFamily: 'Pretendard Variable',
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabelKey != null && onActionPressed != null) ...[
            SizedBox(height: 16.h),
            TextButton(
              onPressed: () {
                onActionPressed?.call();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF232323),
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                tr(actionLabelKey!, context: context),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfilePostGridLoadingView extends StatelessWidget {
  const _ProfilePostGridLoadingView();

  @override
  Widget build(BuildContext context) {
    return MasonryGridView.count(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        left: (20.05).w,
        right: (20.05).w,
        top: 20.h,
        bottom: 30.h,
      ),
      crossAxisCount: 2,
      mainAxisSpacing: 11.sp,
      crossAxisSpacing: 11.sp,
      itemCount: 6,
      itemBuilder: (_, __) => const _ProfileGridPlaceholderCard(),
    );
  }
}

class _ProfileCommentsLoadingView extends StatelessWidget {
  const _ProfileCommentsLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(0, 12.h, 0, 28.h),
      itemCount: 4,
      separatorBuilder: (_, __) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 27.w),
        child: const Divider(color: Color(0xFF1E1E1E), height: 1),
      ),
      itemBuilder: (_, __) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 27.w, vertical: 10.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(radius: 19, backgroundColor: Color(0xFF3A3A3A)),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 82.w,
                    height: 12.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3A3A),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Container(
                    width: double.infinity,
                    height: 52.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1F1F),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileGridPlaceholderCard extends StatelessWidget {
  const _ProfileGridPlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ShimmerOnceThenFallbackIcon(
          width: constraints.maxWidth,
          height: constraints.maxWidth / (170 / 204),
          borderRadius: 20,
          shimmerCycles: 2,
        );
      },
    );
  }
}
