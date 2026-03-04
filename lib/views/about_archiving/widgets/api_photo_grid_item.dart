import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:soi/views/about_archiving/screens/archive_detail/api_photo_detail_screen.dart';
import '../../../api/models/post.dart';
import '../../../utils/video_thumbnail_cache.dart';

/// Hero 애니메이션에서 이미지가 확대/축소될 때,
/// 원본 위젯이 아닌 새로 생성된 위젯을 사용하여 부드러운 전환을 구현하는 함수
Widget _heroFlightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final toHero = (toHeroContext.widget as Hero).child;
  final fromHero = (fromHeroContext.widget as Hero).child;
  final shuttleChild = flightDirection == HeroFlightDirection.push
      ? toHero
      : fromHero;
  return Material(
    type: MaterialType.transparency,
    child: ClipRect(child: shuttleChild),
  );
}

/// 카테고리 내에서 사진 그리드 아이템을 표시하는 위젯
///
/// Parameters:
/// - [postUrl]: 게시물 이미지 URL
/// - [post]: 단일 게시물 정보를 담은 Post 모델
/// - [allPosts]: 모든 게시물 정보를 담은 Post 모델 리스트
/// - [currentIndex]: 현재 인덱스
/// - [categoryName]: 카테고리 이름
/// - [categoryId]: 카테고리 ID
/// - [onPostsDeleted]: 사진 삭제 후 콜백 함수
///
/// Returns: 사진 그리드 아이템 위젯
class ApiPhotoGridItem extends StatefulWidget {
  final String postUrl; // post 이미지 url -> post사진을 띄우기 위한 파라미터입니다.
  final Post post; // Post 모델 -> 단일 게시물 정보를 담고 있습니다.
  final List<Post> allPosts; // 모든 Post 모델 리스트 -> 상세 화면으로 전달하기 위해 받아옵니다.
  final int currentIndex; // 현재 인덱스 -> 상세 화면으로 전달하기 위해 받아옵니다.
  final String categoryName; // 카테고리 이름 -> 상세 화면으로 전달하기 위해 받아옵니다.
  final int categoryId; // 카테고리 ID -> 상세 화면으로 전달하기 위해 받아옵니다.
  final int initialCommentCount; // 상위에서 프리패치된 댓글 개수
  final ValueChanged<List<int>>?
  onPostsDeleted; // 사진 삭제 후 콜백 --> 삭제된 게시물 ID 리스트를 전달하는 이유는 상위 위젯에서 해당 게시물을 제거하기 위함입니다.

  const ApiPhotoGridItem({
    super.key,
    required this.post,
    required this.postUrl,
    required this.allPosts,
    required this.currentIndex,
    required this.categoryName,
    required this.categoryId,
    required this.initialCommentCount,
    this.onPostsDeleted,
  });

  @override
  State<ApiPhotoGridItem> createState() => _ApiPhotoGridItemState();
}

class _ApiPhotoGridItemState extends State<ApiPhotoGridItem> {
  static const _kForwardTransitionDuration = Duration(milliseconds: 260);
  static const _kReverseTransitionDuration = Duration(milliseconds: 220);
  static const double _kMediaAspectRatio = 170 / 204;
  static const double _kTextOnlyMaxWidth = 170;
  static const double _kTextOnlyMaxHeight = 204;
  bool _isNavigatingToDetail = false; // 상세 화면으로 이동 중인지 여부 (중복 방지)

  // 프로필 이미지 캐시
  String? _profileImageUrl;
  bool _isLoadingProfile = true;
  Uint8List? _videoThumbnailBytes;
  bool _isVideoThumbnailLoading = false;

  // 댓글 개수
  int _commentCount = 0;

  bool get _isTextOnlyPost {
    final hasText = widget.post.content?.trim().isNotEmpty ?? false;
    return widget.post.postType == PostType.textOnly ||
        (!widget.post.hasMedia && hasText);
  }

  @override
  void initState() {
    super.initState();
    _commentCount = widget.initialCommentCount;
    _loadVideoThumbnailIfNeeded();
    // 빌드 완료 후 프로필 이미지 로드 (notifyListeners 충돌 방지)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileImage(widget.post.userProfileImageKey);
    });
  }

  @override
  void didUpdateWidget(covariant ApiPhotoGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.userProfileImageKey != widget.post.userProfileImageKey ||
        oldWidget.post.userProfileImageUrl != widget.post.userProfileImageUrl) {
      _loadProfileImage(widget.post.userProfileImageKey);
    }
    if (oldWidget.postUrl != widget.postUrl ||
        oldWidget.post.postFileKey != widget.post.postFileKey) {
      _loadVideoThumbnailIfNeeded(forceReload: true);
    }
    if (oldWidget.initialCommentCount != widget.initialCommentCount) {
      setState(() {
        _commentCount = widget.initialCommentCount;
      });
    }
  }

  /// 비디오 썸네일 로드
  Future<void> _loadVideoThumbnailIfNeeded({bool forceReload = false}) async {
    if (!widget.post.isVideo) {
      if (!mounted) return;
      if (_videoThumbnailBytes == null && !_isVideoThumbnailLoading) return;
      setState(() {
        _videoThumbnailBytes = null;
        _isVideoThumbnailLoading = false;
      });
      return;
    }

    if (!forceReload &&
        (_videoThumbnailBytes != null || _isVideoThumbnailLoading)) {
      return;
    }

    final url = widget.postUrl;
    if (url.isEmpty) return;

    // 캐시 키 생성
    final cacheKey = VideoThumbnailCache.buildStableCacheKey(
      fileKey: widget.post.postFileKey,
      videoUrl: url,
    );

    // 동기적 메모리 캐시 확인 (즉시 반영)
    if (!forceReload) {
      final memHit = VideoThumbnailCache.getFromMemory(cacheKey);
      if (memHit != null) {
        if (!mounted) return;
        setState(() {
          _videoThumbnailBytes = memHit;
          _isVideoThumbnailLoading = false;
        });
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isVideoThumbnailLoading = true);

    // 3-tier 조회: Memory → Disk → Generate
    final bytes = await VideoThumbnailCache.getThumbnail(
      videoUrl: url,
      cacheKey: cacheKey,
    );

    if (!mounted) return;
    setState(() {
      _videoThumbnailBytes = bytes;
      _isVideoThumbnailLoading = false;
    });
  }

  /// 프로필 이미지 URL 설정 (서버에서 직접 제공)
  void _loadProfileImage(String? profileKey) {
    if (!mounted) return;
    final url = widget.post.userProfileImageUrl;
    setState(() {
      _profileImageUrl = (url != null && url.isNotEmpty) ? url : null;
      _isLoadingProfile = false;
    });
  }

  String get _heroTag => 'archive_photo_${widget.categoryId}_${widget.post.id}';

  /// 상세 화면으로 이동하는 함수
  /// 중복 탭 방지 위해 이동 중에는 추가 탭 무시
  ///
  /// Parameters
  /// - [context]: 빌드 컨텍스트
  ///
  /// Returns
  /// - [Future<List<int>>] (상세 화면에서 삭제된 게시물 ID 리스트를 받아 상위 콜백으로 전달)
  Route<List<int>> _buildDetailRoute(BuildContext context) {
    final platform = Theme.of(context).platform;
    final useGestureBackRoute =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    // iOS/macOS에서는 제스처 백이 자연스럽게 작동하는 MaterialPageRoute 사용
    if (useGestureBackRoute) {
      return MaterialPageRoute<List<int>>(
        builder: (_) => ApiPhotoDetailScreen(
          allPosts: widget.allPosts,
          initialIndex: widget.currentIndex,
          categoryName: widget.categoryName,
          categoryId: widget.categoryId,
        ),
      );
    }

    // 그 외 플랫폼에서는 커스텀 페이지 라우트로 빠른 전환과 안정적인 Hero 애니메이션 구현
    return PageRouteBuilder<List<int>>(
      transitionDuration: _kForwardTransitionDuration,
      reverseTransitionDuration: _kReverseTransitionDuration,
      pageBuilder: (_, animation, __) => ApiPhotoDetailScreen(
        allPosts: widget.allPosts,
        initialIndex: widget.currentIndex,
        categoryName: widget.categoryName,
        categoryId: widget.categoryId,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
  }

  /// 상세 화면으로 이동하는 함수
  /// 중복 탭 방지 위해 이동 중에는 추가 탭 무시
  ///
  /// Parameters: null
  ///
  /// Returns: `Future<void>` (상세 화면에서 삭제된 게시물 ID 리스트를 받아 상위 콜백으로 전달)
  Future<void> _openDetailScreen() async {
    if (_isNavigatingToDetail) return;
    _isNavigatingToDetail = true;
    final onPostsDeleted =
        widget.onPostsDeleted; // 삭제 콜백 참조 (null이 될 수 있으므로 지역 변수로 참조)
    final detailRoute = _buildDetailRoute(context); // 상세 화면으로 이동하기 위한 라우트 생성

    try {
      final deletedPostIds = await Navigator.push<List<int>>(
        context,
        detailRoute,
      ); // 상세 화면으로 이동하고, 삭제된 게시물 ID 리스트를 기다림
      if (deletedPostIds == null || deletedPostIds.isEmpty) return;
      // 상세 pop 역방향 Hero가 안정화된 뒤 목록을 갱신합니다.
      await Future<void>.delayed(_kReverseTransitionDuration);
      if (!mounted) return;
      onPostsDeleted?.call(deletedPostIds);
    } finally {
      _isNavigatingToDetail = false;
    }
  }

  /// Hero 미디어 카드를 빌드하는 함수
  ///
  /// Parameters: null
  ///
  /// Returns: Hero 위젯으로 감싸진 미디어 카드 (사진 또는 비디오 썸네일)
  Widget _buildHeroMediaCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final heroChild = _isTextOnlyPost
            ? _buildTextOnlyCard(math.min(width, _kTextOnlyMaxWidth))
            : SizedBox(
                width: width,
                height: width / _kMediaAspectRatio,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(
                      color: const Color(0xff2b2b2b),
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18.0),
                    child: widget.post.isVideo
                        ? _buildVideoThumbnail()
                        : (widget.postUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: widget.postUrl,
                                  // presigned URL이 바뀌어도 같은 파일이면 디스크 캐시 재사용
                                  cacheKey: widget.post.postFileKey,
                                  useOldImageOnUrlChange: true,
                                  fadeInDuration: Duration.zero,
                                  fadeOutDuration: Duration.zero,
                                  memCacheWidth: (170 * 2).round(),
                                  maxWidthDiskCache: (170 * 2).round(),
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      Shimmer.fromColors(
                                        baseColor: Colors.grey.shade800,
                                        highlightColor: Colors.grey.shade700,
                                        period: const Duration(
                                          milliseconds: 1500,
                                        ),
                                        child: Container(
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: Colors.grey.shade800,
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.image,
                                          color: Colors.grey.shade600,
                                          size: 32.sp,
                                        ),
                                      ),
                                )
                              : Container(
                                  color: Colors.grey.shade800,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.grey.shade600,
                                    size: 32.sp,
                                  ),
                                )),
                  ),
                ),
              );

        return Hero(
          tag: _heroTag,
          createRectTween: (begin, end) =>
              MaterialRectArcTween(begin: begin, end: end),
          transitionOnUserGestures: true,
          flightShuttleBuilder: _heroFlightShuttleBuilder,
          child: heroChild,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openDetailScreen,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 미디어(사진/비디오 썸네일)
          _buildHeroMediaCard(),

          // 댓글 개수 (우측 하단)
          Positioned(
            bottom: 8.h,
            right: 8.w,
            child: Row(
              children: [
                Text(
                  '$_commentCount',
                  style: TextStyle(
                    color: const Color(0xFFF8F8F8),
                    fontSize: 14,
                    fontFamily: 'Pretendard Variable',
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.40,
                  ),
                ),
                SizedBox(width: (5.96).w),
                Image.asset(
                  'assets/comment_icon.png',
                  width: (15.75),
                  height: (15.79),
                  color: Color(0xfff9f9f9),
                ),
                SizedBox(width: (10.29)),
              ],
            ),
          ),

          // 하단 프로필
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  SizedBox(width: 8.w),
                  // 프로필 이미지
                  Container(
                    width: 28.w,
                    height: 28.h,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: _buildProfileImage(),
                  ),
                  SizedBox(width: 5.w),
                ],
              ),
              SizedBox(height: 5.h),
            ],
          ),
        ],
      ),
    );
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
            // 메모리 최적화: 디코딩 시 크기 제한
            cacheWidth: 262, // 175 * 1.5
          ),
          // 비디오 재생 아이콘 표시
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
          Shimmer.fromColors(
            baseColor: Colors.grey.shade800,
            highlightColor: Colors.grey.shade700,
            period: const Duration(milliseconds: 1500),
            child: Container(color: Colors.grey.shade800),
          ),
          // ✨ 로딩 중에도 비디오 아이콘 표시
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
      color: Colors.grey.shade800,
      alignment: Alignment.center,
      child: Icon(Icons.videocam, color: Colors.grey.shade600, size: 32.sp),
    );
  }

  /// 카테고리 사진 화면에서 사진이 "하나도 없을 때" 보여주는 슬리버 위젯
  /// Parameters:
  ///   - 없음
  /// Returns:
  ///   - SliverToBoxAdapter를 사용하여 화면 중앙에 "사진이 없습니다" 메시지를 표시
  Widget _buildTextOnlyCard(double cardWidth) {
    final text = widget.post.content?.trim() ?? '';
    final outerHorizontalPadding = 18.w;
    final outerTopPadding = 18.h;
    final outerBottomPadding = 56.h;
    final maxTextHeight = math.max(
      0.0,
      _kTextOnlyMaxHeight - outerTopPadding - outerBottomPadding,
    );
    final textMaxWidth = math.max(
      0.0,
      cardWidth - (outerHorizontalPadding * 2),
    );
    final textStyle = _resolveTextOnlyStyle(
      text: text,
      maxWidth: textMaxWidth,
      maxHeight: maxTextHeight,
    );
    final cardHeight = math.min(
      _kTextOnlyMaxHeight,
      textStyle.painter.height + outerTopPadding + outerBottomPadding,
    );

    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: const Color(0xff2b2b2b), width: 2.0),
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.0),
          child: Container(
            color: const Color(0xff1e1e1e),
            alignment: Alignment.center,
            padding: EdgeInsets.only(
              left: outerHorizontalPadding,
              right: outerHorizontalPadding,
              top: outerTopPadding,
              bottom: outerBottomPadding,
            ),
            child: SizedBox(
              width: textMaxWidth,
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: textStyle.style,
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ResolvedTextStyle _resolveTextOnlyStyle({
    required String text,
    required double maxWidth,
    required double maxHeight,
  }) {
    final baseStyle = TextStyle(
      color: const Color(0xfff8f8f8),
      fontSize: 30.sp,
      fontFamily: 'Pretendard Variable',
      fontWeight: FontWeight.w500,
      height: 1.25,
    );
    const minFontSize = 8.0;

    TextStyle selectedStyle = baseStyle;
    TextPainter selectedPainter = TextPainter(
      text: TextSpan(text: text, style: baseStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    final baseFont = baseStyle.fontSize ?? 30.0;
    var fitFound = false;
    for (double fontSize = baseFont; fontSize >= minFontSize; fontSize -= 1) {
      final style = baseStyle.copyWith(fontSize: fontSize);
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      selectedStyle = style;
      selectedPainter = painter;
      if (painter.height <= maxHeight) {
        fitFound = true;
        break;
      }
    }

    if (!fitFound && selectedPainter.height > 0 && maxHeight > 0) {
      final scaleRatio = maxHeight / selectedPainter.height;
      final scaledFontSize = math.max(
        1.0,
        (selectedStyle.fontSize ?? minFontSize) * scaleRatio,
      );
      selectedStyle = selectedStyle.copyWith(fontSize: scaledFontSize);
      selectedPainter = TextPainter(
        text: TextSpan(text: text, style: selectedStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
    }

    return _ResolvedTextStyle(style: selectedStyle, painter: selectedPainter);
  }

  /// 프로필 이미지 빌드
  Widget _buildProfileImage() {
    if (_isLoadingProfile) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade800,
        highlightColor: Colors.grey.shade700,
        period: const Duration(milliseconds: 1500),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    if (_profileImageUrl == null || _profileImageUrl!.isEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: const Color(0xffd9d9d9),
        child: Icon(Icons.person, color: Colors.white, size: 18.sp),
      );
    }

    return CachedNetworkImage(
      key: ValueKey(
        'profile_${widget.post.nickName}_${widget.post.userProfileImageKey}',
      ),
      imageUrl: _profileImageUrl!,
      cacheKey: widget.post.userProfileImageKey,
      useOldImageOnUrlChange: true,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      memCacheWidth: (28 * 5).round(),
      maxWidthDiskCache: (28 * 5).round(),
      imageBuilder: (context, imageProvider) =>
          CircleAvatar(radius: 14, backgroundImage: imageProvider),
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: Colors.grey.shade800,
        highlightColor: Colors.grey.shade700,
        period: const Duration(milliseconds: 1500),
        child: CircleAvatar(radius: 14, backgroundColor: Colors.grey.shade800),
      ),
      errorWidget: (context, url, error) => Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFd9d9d9),
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 26),
      ),
    );
  }
}

class _ResolvedTextStyle {
  final TextStyle style;
  final TextPainter painter;

  const _ResolvedTextStyle({required this.style, required this.painter});
}
