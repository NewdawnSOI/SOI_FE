import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:soi/api/controller/media_controller.dart';
import 'package:soi/api/controller/post_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi/utils/video_thumbnail_cache.dart';

/// 삭제된 게시물 목록 화면
/// 사용자가 삭제한 게시물들을 보여주는 화면입니다.
/// 사용자는 이 화면에서 삭제된 게시물을 선택하여 복원할 수 있습니다.
class DeletedPostListScreen extends StatefulWidget {
  const DeletedPostListScreen({super.key});

  @override
  State<DeletedPostListScreen> createState() => _DeletedPostListScreenState();
}

class _DeletedPostListScreenState extends State<DeletedPostListScreen> {
  static const int _kInitialVideoThumbnailPrefetchCount = 4;
  static const double _paginationThreshold = 240;

  late final ScrollController _scrollController;
  List<Post> _deletedPosts = [];
  final Set<int> _selectedPostIds = <int>{};
  final Map<int, String> _imageUrlByPostId = <int, String>{};
  final Map<int, Uint8List> _videoThumbnailBytesByPostId = <int, Uint8List>{};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreDeletedPosts = true;
  String? _error;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDeletedPosts();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _isLoading ||
        _isLoadingMore ||
        !_hasMoreDeletedPosts) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - _paginationThreshold) {
      return;
    }

    _loadDeletedPosts(loadMore: true);
  }

  Future<void> _loadDeletedPosts({bool loadMore = false}) async {
    final userController = context.read<UserController>();
    final user = userController.currentUser;
    if (user == null || user.id == 0) {
      setState(() {
        _error = tr('common.login_required', context: context);
        _isLoading = false;
        _isLoadingMore = false;
        _hasMoreDeletedPosts = false;
      });
      return;
    }

    if (loadMore && (_isLoadingMore || !_hasMoreDeletedPosts)) {
      return;
    }

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _error = null;
        _currentPage = 0;
        _hasMoreDeletedPosts = true;
      }
    });

    try {
      final postController = context.read<PostController>();
      final nextPage = loadMore ? _currentPage + 1 : 0;

      final posts = await postController.getAllPosts(
        userId: user.id,
        postStatus: PostStatus.deleted,
        page: nextPage,
      );

      if (!loadMore) {
        _imageUrlByPostId.clear();
        _videoThumbnailBytesByPostId.clear();
      }

      await _cacheMediaUrls(posts);
      await _prefetchInitialVideoThumbnails(posts);

      if (!mounted) return;
      final mergedPosts = loadMore
          ? _mergeDeletedPosts(_deletedPosts, posts)
          : posts;
      setState(() {
        _deletedPosts = mergedPosts;
        _selectedPostIds.removeWhere(
          (id) => !_deletedPosts.any((post) => post.id == id),
        );
        _currentPage = nextPage;
        _hasMoreDeletedPosts = posts.isNotEmpty;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!loadMore) {
          _error = e.toString();
          _isLoading = false;
        }
        _isLoadingMore = false;
      });
    }
  }

  /// 삭제된 게시물 미디어는 서버 URL을 먼저 쓰고, 없을 때만 key 기준 presigned URL로 채워 넣습니다.
  Future<void> _cacheMediaUrls(List<Post> posts) async {
    final mediaController = context.read<MediaController>();
    final unresolvedPostIds = <int>[];
    final unresolvedKeys = <String>[];

    for (final post in posts) {
      final immediateUrl = _resolveImmediateMediaUrl(
        post: post,
        mediaController: mediaController,
      );
      if (immediateUrl != null) {
        _imageUrlByPostId[post.id] = immediateUrl;
        continue;
      }

      final mediaKey = _normalizeImageKey(post.postFileKey);
      if (mediaKey != null) {
        unresolvedPostIds.add(post.id);
        unresolvedKeys.add(mediaKey);
      }
    }

    if (unresolvedKeys.isEmpty) {
      return;
    }

    final resolvedUrls = await Future.wait(
      unresolvedKeys.map(mediaController.getPresignedUrl),
    );

    for (var index = 0; index < unresolvedPostIds.length; index++) {
      final resolvedUrl = _normalizeImageUrl(resolvedUrls[index]);
      if (resolvedUrl == null) {
        continue;
      }
      _imageUrlByPostId[unresolvedPostIds[index]] = resolvedUrl;
    }
  }

  /// 서버가 내려준 미디어 URL을 즉시 표시용 값으로 정규화합니다.
  String? _normalizeImageUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  /// 게시물 미디어 key는 캐시 식별과 presigned URL 재발급 기준으로 정규화합니다.
  String? _normalizeImageKey(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  /// 삭제된 게시물 목록은 서버 URL을 바로 쓰고, 없을 때만 key의 캐시된 presigned URL을 재사용합니다.
  String? _resolveImmediateMediaUrl({
    required Post post,
    required MediaController mediaController,
  }) {
    final immediateUrl = _normalizeImageUrl(post.postFileUrl);
    if (immediateUrl != null) {
      return immediateUrl;
    }

    final mediaKey = _normalizeImageKey(post.postFileKey);
    if (mediaKey == null) {
      return null;
    }

    return mediaController.peekPresignedUrl(mediaKey);
  }

  List<Post> _mergeDeletedPosts(List<Post> current, List<Post> incoming) {
    final merged = List<Post>.from(current);
    final seenIds = current.map((post) => post.id).toSet();

    for (final post in incoming) {
      if (seenIds.add(post.id)) {
        merged.add(post);
      }
    }

    return merged;
  }

  Future<void> _prefetchInitialVideoThumbnails(List<Post> posts) async {
    final candidates = posts
        .where(
          (post) =>
              post.isVideo &&
              ((_imageUrlByPostId[post.id]?.isNotEmpty ?? false)),
        )
        .take(_kInitialVideoThumbnailPrefetchCount)
        .toList(growable: false);

    await Future.wait(
      candidates.map((post) async {
        final videoUrl = _imageUrlByPostId[post.id];
        if (videoUrl == null || videoUrl.isEmpty) {
          return;
        }

        final cacheKey = VideoThumbnailCache.buildStableCacheKey(
          fileKey: post.postFileKey,
          videoUrl: videoUrl,
        );

        final memHit = VideoThumbnailCache.getFromMemory(cacheKey);
        if (memHit != null) {
          _videoThumbnailBytesByPostId[post.id] = memHit;
          return;
        }

        final bytes = await VideoThumbnailCache.getThumbnail(
          videoUrl: videoUrl,
          cacheKey: cacheKey,
        );
        if (bytes != null) {
          _videoThumbnailBytesByPostId[post.id] = bytes;
        }
      }),
    );
  }

  void _cacheVideoThumbnail(int postId, Uint8List bytes) {
    if (_videoThumbnailBytesByPostId[postId] == bytes) {
      return;
    }

    if (!mounted) {
      _videoThumbnailBytesByPostId[postId] = bytes;
      return;
    }

    setState(() {
      _videoThumbnailBytesByPostId[postId] = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('deleted_posts.title', context: context),
              textAlign: TextAlign.start,
              style: TextStyle(
                color: const Color(0xFFF8F8F8),
                fontSize: 20.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          _buildBody(),
          Positioned(
            bottom: 40.h,

            child: SizedBox(
              width: 349.w,
              height: 50.h,
              child: ElevatedButton(
                onPressed: _selectedPostIds.isNotEmpty
                    ? _restoreSelectedPosts
                    : () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedPostIds.isNotEmpty
                      ? Colors.white
                      : const Color(0xFF595959),

                  disabledBackgroundColor: const Color(0xFF595959),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26.90),
                  ),
                ),
                child: Text(
                  tr('deleted_posts.restore_button', context: context),
                  style: TextStyle(
                    color: _selectedPostIds.isNotEmpty
                        ? Colors.black
                        : Colors.white,
                    fontSize: 18,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tr('common.error_occurred', context: context),
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _error!,
              style: TextStyle(
                color: const Color(0xFFB0B0B0),
                fontSize: 14.sp,
                fontFamily: 'Pretendard',
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _loadDeletedPosts,
              child: Text(tr('common.retry', context: context)),
            ),
          ],
        ),
      );
    }

    if (_deletedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64.sp,
              color: const Color(0xFF666666),
            ),
            SizedBox(height: 16.h),
            Text(
              tr('deleted_posts.empty', context: context),
              style: TextStyle(
                color: const Color(0xFFB0B0B0),
                fontSize: 16.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16.w, 16.w, 16.w, 120.h),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 13.h,
              childAspectRatio: 175 / 233,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return _buildDeletedPostItem(_deletedPosts[index], index);
              },
              childCount: _deletedPosts.length,
              addAutomaticKeepAlives: false,
            ),
          ),
        ),
        if (_isLoadingMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 120.h),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDeletedPostItem(Post post, int index) {
    final bool isPostSelected = _selectedPostIds.contains(post.id);
    final imageUrl = _imageUrlByPostId[post.id];
    final initialVideoThumbnailBytes = _videoThumbnailBytesByPostId[post.id];

    return GestureDetector(
      onTap: () {
        _togglePostSelection(post.id);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF1C1C1C),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _DeletedPostMediaPreview(
                post: post,
                mediaUrl: imageUrl,
                initialVideoThumbnailBytes: initialVideoThumbnailBytes,
                onVideoThumbnailLoaded: (bytes) {
                  _cacheVideoThumbnail(post.id, bytes);
                },
              ),
              // 선택 오버레이
              if (isPostSelected)
                Container(color: Colors.black.withValues(alpha: 0.3)),
              // 체크마크
              if (isPostSelected)
                Positioned(
                  top: 8.h,
                  left: 8.w,
                  child: Container(
                    width: 24.w,
                    height: 24.h,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, color: Colors.white, size: 16.sp),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _togglePostSelection(int postId) {
    setState(() {
      if (_selectedPostIds.contains(postId)) {
        _selectedPostIds.remove(postId);
      } else {
        _selectedPostIds.add(postId);
      }
    });
  }

  Future<void> _restoreSelectedPosts() async {
    if (context.read<UserController>().currentUserId == null) return;

    if (_selectedPostIds.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final postController = context.read<PostController>();
    int successCount = 0;
    int failCount = 0;

    for (final postId in _selectedPostIds.toList()) {
      try {
        final success = await postController.setPostStatus(
          postId: postId,
          postStatus: PostStatus.active,
        );

        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        debugPrint('사진 복원 오류: $e');
        failCount++;
      }
    }
    // 선택 상태 초기화
    if (!mounted) return;
    setState(_selectedPostIds.clear);

    // 삭제된 사진 목록 다시 로드
    await _loadDeletedPosts();

    // 사용자에게 결과 알림
    if (mounted) {
      String message;
      if (failCount == 0) {
        message = tr(
          'deleted_posts.restore_success',
          context: context,
          namedArgs: {'count': successCount.toString()},
        );
      } else if (successCount == 0) {
        message = tr('deleted_posts.restore_failed', context: context);
      } else {
        message = tr(
          'deleted_posts.restore_partial',
          context: context,
          namedArgs: {
            'success': successCount.toString(),
            'fail': failCount.toString(),
          },
        );
      }

      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 14.sp,
      );
    }
  }
}

class _DeletedPostMediaPreview extends StatefulWidget {
  const _DeletedPostMediaPreview({
    required this.post,
    required this.mediaUrl,
    this.initialVideoThumbnailBytes,
    this.onVideoThumbnailLoaded,
  });

  final Post post;
  final String? mediaUrl;
  final Uint8List? initialVideoThumbnailBytes;
  final ValueChanged<Uint8List>? onVideoThumbnailLoaded;

  @override
  State<_DeletedPostMediaPreview> createState() =>
      _DeletedPostMediaPreviewState();
}

class _DeletedPostMediaPreviewState extends State<_DeletedPostMediaPreview> {
  Uint8List? _videoThumbnailBytes;
  bool _isVideoThumbnailLoading = false;

  @override
  void initState() {
    super.initState();
    _videoThumbnailBytes = widget.initialVideoThumbnailBytes;
    _loadVideoThumbnailIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _DeletedPostMediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    final initialBytesChanged =
        oldWidget.initialVideoThumbnailBytes !=
        widget.initialVideoThumbnailBytes;
    if (initialBytesChanged && widget.initialVideoThumbnailBytes != null) {
      _videoThumbnailBytes = widget.initialVideoThumbnailBytes;
    }

    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.postFileKey != widget.post.postFileKey ||
        oldWidget.mediaUrl != widget.mediaUrl) {
      _videoThumbnailBytes = widget.initialVideoThumbnailBytes;
      _loadVideoThumbnailIfNeeded(forceReload: true);
    }
  }

  Future<void> _loadVideoThumbnailIfNeeded({bool forceReload = false}) async {
    if (!widget.post.isVideo) {
      return;
    }

    if (!forceReload &&
        (_videoThumbnailBytes != null || _isVideoThumbnailLoading)) {
      return;
    }

    final videoUrl = widget.mediaUrl;
    if (videoUrl == null || videoUrl.isEmpty) {
      return;
    }

    final cacheKey = VideoThumbnailCache.buildStableCacheKey(
      fileKey: widget.post.postFileKey,
      videoUrl: videoUrl,
    );

    if (!forceReload) {
      final memHit = VideoThumbnailCache.getFromMemory(cacheKey);
      if (memHit != null) {
        if (!mounted) return;
        setState(() {
          _videoThumbnailBytes = memHit;
          _isVideoThumbnailLoading = false;
        });
        widget.onVideoThumbnailLoaded?.call(memHit);
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _isVideoThumbnailLoading = true;
    });

    final bytes = await VideoThumbnailCache.getThumbnail(
      videoUrl: videoUrl,
      cacheKey: cacheKey,
    );

    if (!mounted) return;
    setState(() {
      _videoThumbnailBytes = bytes;
      _isVideoThumbnailLoading = false;
    });

    if (bytes != null) {
      widget.onVideoThumbnailLoaded?.call(bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaUrl = widget.mediaUrl;
    if (widget.post.isVideo) {
      return _buildVideoThumbnail();
    }

    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: mediaUrl,
        cacheKey: widget.post.postFileKey,
        useOldImageOnUrlChange: true,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        fit: BoxFit.cover,
        memCacheWidth: (175 * 2).round(),
        maxWidthDiskCache: (175 * 2).round(),
        placeholder: (context, url) => _buildShimmerPlaceholder(),
        errorWidget: (context, url, error) => _buildImageFallback(),
      );
    }

    return _buildImageFallback();
  }

  Widget _buildVideoThumbnail() {
    if (_videoThumbnailBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _videoThumbnailBytes!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: 262,
          ),
          Center(
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow, color: Colors.white, size: 24.sp),
            ),
          ),
        ],
      );
    }

    if (_isVideoThumbnailLoading) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _buildShimmerPlaceholder(),
          Center(
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.videocam,
                color: Colors.white.withValues(alpha: 0.7),
                size: 24.sp,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      color: const Color(0xFF333333),
      alignment: Alignment.center,
      child: Icon(Icons.videocam, color: Colors.white54, size: 48.sp),
    );
  }

  Widget _buildShimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF333333),
      highlightColor: const Color(0xFF555555),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF333333),
          borderRadius: BorderRadius.circular(8.r),
        ),
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      color: const Color(0xFF333333),
      child: Icon(Icons.image, color: Colors.white54, size: 48.sp),
    );
  }
}
