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
import '../../common_widget/about_comment/widget/about_comment_list_sheet/api_comment_row.dart';

class ProfilePostTabView extends StatefulWidget {
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
    _maybeLoadInitial();
  }

  @override
  void didUpdateWidget(covariant ProfilePostTabView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final userChanged = oldWidget.userId != widget.userId;
    final typeChanged = oldWidget.postType != widget.postType;
    if (userChanged || typeChanged) {
      _resetState();
      _maybeLoadInitial();
      return;
    }

    if (!oldWidget.isActive && widget.isActive) {
      _maybeLoadInitial();
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

  List<Post> _normalizePosts(List<Post> rawPosts) {
    final filteredPosts = rawPosts
        .where((post) {
          final postType = post.postType;
          if (widget.postType == PostType.multiMedia) {
            return postType == PostType.multiMedia;
          }
          return postType == PostType.textOnly;
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
        padding: EdgeInsets.fromLTRB(8.w, 13.h, 8.w, 28.h),
        crossAxisCount: 2,
        mainAxisSpacing: 8.h,
        crossAxisSpacing: 8.w,
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
    _maybeLoadInitial();
  }

  @override
  void didUpdateWidget(covariant ProfileCommentTabView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId) {
      _resetState();
      _maybeLoadInitial();
      return;
    }

    if (!oldWidget.isActive && widget.isActive) {
      _maybeLoadInitial();
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

  String _commentIdentity(Comment comment) {
    final id = comment.id;
    if (id != null) {
      return 'id:$id';
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

  Future<void> _loadInitial() async {
    final userId = widget.userId;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _comments = const <Comment>[];
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
    if (!mounted) return;

    final normalizedComments = _normalizeComments(result.comments);
    final hasError =
        (commentController.errorMessage?.trim().isNotEmpty ?? false) &&
        normalizedComments.isEmpty;

    setState(() {
      _comments = normalizedComments;
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
    if (!mounted) return;

    final hasError =
        (commentController.errorMessage?.trim().isNotEmpty ?? false) &&
        result.comments.isEmpty;
    final mergedComments = _normalizeComments(<Comment>[
      ..._comments,
      ...result.comments,
    ]);

    setState(() {
      _comments = mergedComments;
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_hasLoadedOnce && !widget.isActive) {
      return const ColoredBox(color: Colors.black);
    }

    if (_isInitialLoading && _comments.isEmpty) {
      return const _ProfileCommentsLoadingView();
    }

    if (_hasLoadError && _comments.isEmpty) {
      return _ProfileRefreshableStatusView(
        onRefresh: _refresh,
        child: _ProfileTabStatusContent(
          messageKey: 'profile.main.load_failed',
          actionLabelKey: 'common.retry',
          onActionPressed: _refresh,
        ),
      );
    }

    if (_comments.isEmpty) {
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
        child: ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(0, 8.h, 0, 28.h),
          itemCount: _comments.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _comments.length) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 18.h),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              );
            }

            final comment = _comments[index];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  child: ApiCommentRow(comment: comment),
                ),
                if (index < _comments.length - 1)
                  Padding(
                    padding: EdgeInsets.only(
                      left: 27.w,
                      right: 27.w,
                      top: 7.h,
                      bottom: 7.h,
                    ),
                    child: const Divider(
                      color: Color(0xFF1E1E1E),
                      height: 1,
                      thickness: 1,
                    ),
                  ),
              ],
            );
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
      padding: EdgeInsets.fromLTRB(8.w, 13.h, 8.w, 28.h),
      crossAxisCount: 2,
      mainAxisSpacing: 8.h,
      crossAxisSpacing: 8.w,
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
