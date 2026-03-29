import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:soi/views/about_archiving/screens/archive_detail/api_photo_detail_screen.dart';
import '../../../api/controller/media_controller.dart';
import '../../../api/models/post.dart';
import '../../../utils/video_thumbnail_cache.dart';
import '../../common_widget/user/current_user_image_builder.dart';

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
  final bool singlePostMode;
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
    this.singlePostMode = false,
    this.onPostsDeleted,
  });

  @override
  State<ApiPhotoGridItem> createState() => _ApiPhotoGridItemState();
}

class _ApiPhotoGridItemState extends State<ApiPhotoGridItem> {
  static const _kForwardTransitionDuration = Duration(milliseconds: 260);
  static const _kReverseTransitionDuration = Duration(milliseconds: 220);
  static const double _kMediaAspectRatio = 170 / 204;
  double get _textOnlyMaxWidth => 170.sp;
  double get _textOnlyMaxHeight => 204.sp;
  bool _isNavigatingToDetail = false; // 상세 화면으로 이동 중인지 여부 (중복 방지)

  String? _mediaUrl;
  int _mediaLoadGeneration = 0;
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
    _mediaUrl = _resolveImmediateMediaUrl();
    _loadVideoThumbnailIfNeeded();
    _loadMediaUrl();
  }

  @override
  void didUpdateWidget(covariant ApiPhotoGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postUrl != widget.postUrl ||
        oldWidget.post.postFileUrl != widget.post.postFileUrl ||
        oldWidget.post.postFileKey != widget.post.postFileKey) {
      _loadMediaUrl();
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

    final url = _mediaUrl;
    if (url == null || url.isEmpty) return;

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

  /// 서버가 내려준 작성자 프로필 URL을 첫 프레임 표시용 값으로 정규화합니다.
  String? _normalizeImageUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  /// 미디어/프로필 키를 캐시 식별 및 presigned URL 재발급 기준으로 정규화합니다.
  String? _normalizeImageKey(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  /// 그리드 미디어는 서버 URL을 바로 쓰고, 없을 때만 key의 캐시된 presigned URL을 재사용합니다.
  String? _resolveImmediateMediaUrl() {
    final immediateUrl =
        _normalizeImageUrl(widget.post.postFileUrl) ??
        _normalizeImageUrl(widget.postUrl);
    if (immediateUrl != null) {
      return immediateUrl;
    }

    final postFileKey = _normalizedPostFileKey();
    if (postFileKey == null) {
      return null;
    }

    try {
      return context.read<MediaController>().peekPresignedUrl(postFileKey);
    } catch (_) {
      return null;
    }
  }

  /// 게시물 미디어 key는 캐시와 presigned URL 갱신의 단일 기준으로 사용합니다.
  String? _normalizedPostFileKey() {
    return _normalizeImageKey(widget.post.postFileKey);
  }

  /// 그리드 미디어는 URL을 먼저 표시하고, key가 있으면 최신 presigned URL로 백그라운드 갱신합니다.
  Future<void> _loadMediaUrl() async {
    final requestId = ++_mediaLoadGeneration;
    final mediaController = context.read<MediaController>();
    final immediateUrl = _resolveImmediateMediaUrl();
    final postFileKey = _normalizedPostFileKey();
    final previousUrl = _mediaUrl;

    if (!mounted) return;
    setState(() {
      _mediaUrl = immediateUrl;
      if (widget.post.isVideo && immediateUrl != previousUrl) {
        _videoThumbnailBytes = null;
        _isVideoThumbnailLoading = false;
      }
    });

    if (widget.post.isVideo && immediateUrl != null) {
      await _loadVideoThumbnailIfNeeded(
        forceReload: immediateUrl != previousUrl,
      );
    }

    if (postFileKey == null) {
      return;
    }

    try {
      final resolvedUrl = _normalizeImageUrl(
        await mediaController.getPresignedUrl(postFileKey),
      );
      if (!mounted || requestId != _mediaLoadGeneration) {
        return;
      }

      final nextUrl = resolvedUrl ?? immediateUrl;
      final currentUrl = _mediaUrl;
      setState(() {
        _mediaUrl = nextUrl;
        if (widget.post.isVideo && nextUrl != currentUrl) {
          _videoThumbnailBytes = null;
          _isVideoThumbnailLoading = false;
        }
      });

      if (widget.post.isVideo && nextUrl != null) {
        await _loadVideoThumbnailIfNeeded(forceReload: nextUrl != currentUrl);
      }
    } catch (_) {
      if (!mounted || requestId != _mediaLoadGeneration) {
        return;
      }
    }
  }

  /// 상세 화면 진입 라우트를 플랫폼별 네비게이션 감각에 맞게 구성합니다.
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
          allPosts: widget.singlePostMode
              ? <Post>[widget.post]
              : widget.allPosts,
          initialIndex: widget.singlePostMode ? 0 : widget.currentIndex,
          categoryName: widget.categoryName,
          categoryId: widget.categoryId,
          singlePostMode: widget.singlePostMode,
        ),
      );
    }

    // 그 외 플랫폼에서는 추가 전환 효과 없이 상세 화면을 즉시 표시합니다.
    return PageRouteBuilder<List<int>>(
      transitionDuration: _kForwardTransitionDuration,
      reverseTransitionDuration: _kReverseTransitionDuration,
      pageBuilder: (_, animation, __) => ApiPhotoDetailScreen(
        allPosts: widget.singlePostMode ? <Post>[widget.post] : widget.allPosts,
        initialIndex: widget.singlePostMode ? 0 : widget.currentIndex,
        categoryName: widget.categoryName,
        categoryId: widget.categoryId,
        singlePostMode: widget.singlePostMode,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
  }

  /// 중복 탭을 막으면서 상세 화면 이동 결과를 목록 삭제 상태와 동기화합니다.
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
      if (!mounted) return;
      onPostsDeleted?.call(deletedPostIds);
    } finally {
      _isNavigatingToDetail = false;
    }
  }

  /// 그리드 셀에서 사진, 영상 썸네일, 텍스트 카드를 공통 레이아웃으로 렌더링합니다.
  ///
  /// Parameters: null
  ///
  /// Returns: 사진 또는 비디오 썸네일을 표시하는 미디어 카드
  Widget _buildMediaCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return _isTextOnlyPost
            ? _buildTextOnlyCard(math.min(width, _textOnlyMaxWidth))
            : SizedBox(
                width: width,
                height: width / _kMediaAspectRatio,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20.0),
                    child: widget.post.isVideo
                        ? _buildVideoThumbnail()
                        : ((_mediaUrl ?? '').isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: _mediaUrl!,
                                  // presigned URL이 바뀌어도 같은 파일이면 디스크 캐시 재사용
                                  cacheKey: widget.post.postFileKey,
                                  useOldImageOnUrlChange:
                                      widget.post.postFileKey != null,
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
          _buildMediaCard(),

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
    final outerHorizontalPadding = 18.sp;
    final outerTopPadding = 18.sp;
    final outerBottomPadding = 56.sp;
    final textScaler = MediaQuery.textScalerOf(context);
    final maxTextHeight = math.max(
      0.0,
      _textOnlyMaxHeight - outerTopPadding - outerBottomPadding,
    );
    final textMaxWidth = math.max(
      0.0,
      cardWidth - (outerHorizontalPadding * 2),
    );
    final textLayout = _resolveTextOnlyLayout(
      text: text,
      maxWidth: textMaxWidth,
      maxHeight: maxTextHeight,
      textScaler: textScaler,
    );
    final cardHeight = math.min(
      _textOnlyMaxHeight,
      textLayout.painter.height.ceilToDouble() +
          outerTopPadding +
          outerBottomPadding,
    );

    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
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
                style: textLayout.style,
                maxLines: textLayout.maxLines,
                overflow: TextOverflow.ellipsis,
                textScaler: textScaler,
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ResolvedTextLayout _resolveTextOnlyLayout({
    required String text,
    required double maxWidth,
    required double maxHeight,
    required TextScaler textScaler,
  }) {
    // 기본 스타일 설정
    final baseStyle = TextStyle(
      color: const Color(0xfff8f8f8),
      fontSize: 20.sp,
      fontFamily: 'Pretendard Variable',
      fontWeight: FontWeight.w500,
      height: 1.25,
    );
    const minFontSize = 5.0; // 최소 폰트 크기 설정
    final heightSafetyPadding = 4.sp; // 하단 글리프 잘림 방지를 위한 여유값

    TextStyle selectedStyle = baseStyle; // 최종 선택된 스타일 (초기값은 기본 스타일)
    int? selectedMaxLines;
    TextPainter selectedPainter = _buildTextPainter(
      text: text,
      style: baseStyle,
      maxWidth: maxWidth,
      maxLines: null,
      ellipsis: null,
      textScaler: textScaler,
    );

    final baseFont = baseStyle.fontSize ?? 20.0; // 기본 폰트 크기
    var fitFound = false; // 텍스트가 최대 높이 내에 맞는 스타일을 찾았는지 여부

    // 폰트 크기를 줄여가며 텍스트가 최대 높이 내에 맞는지 확인하는 반복문
    for (double fontSize = baseFont; fontSize >= minFontSize; fontSize -= 1) {
      final style = baseStyle.copyWith(fontSize: fontSize); // 폰트 크기 조정

      final fullPainter = _buildTextPainter(
        text: text,
        style: style,
        maxWidth: maxWidth,
        maxLines: null,
        ellipsis: null,
        textScaler: textScaler,
      );

      // 전체 텍스트가 들어가면 ellipsis 없이 확정
      if (fullPainter.height <= maxHeight - heightSafetyPadding) {
        selectedStyle = style;
        selectedMaxLines = null;
        selectedPainter = fullPainter;
        fitFound = true; // 텍스트가 최대 높이 내에 맞는 경우, 반복 종료
        break;
      }

      // 전체 텍스트가 안 들어가는 경우, 들어갈 수 있는 최대 줄수로 ellipsis 처리
      final fittedMaxLines = _findFittingMaxLines(
        text: text,
        style: style,
        maxWidth: maxWidth,
        maxHeight: maxHeight - heightSafetyPadding,
        textScaler: textScaler,
      );
      final ellipsisPainter = _buildTextPainter(
        text: text,
        style: style,
        maxWidth: maxWidth,
        maxLines: fittedMaxLines,
        ellipsis: '...',
        textScaler: textScaler,
      );

      selectedStyle = style;
      selectedMaxLines = fittedMaxLines;
      selectedPainter = ellipsisPainter;

      if (ellipsisPainter.height <= maxHeight - heightSafetyPadding) {
        fitFound = true;
        break;
      }
    }

    if (!fitFound && selectedPainter.height > 0 && maxHeight > 0) {
      final scaleRatio = maxHeight / selectedPainter.height; // 높이에 맞춰 비율 계산
      // 폰트 크기 스케일링 (최소 폰트 크기 이하로는 줄이지 않음)
      final scaledFontSize = math.max(
        minFontSize,
        (selectedStyle.fontSize ?? minFontSize) * scaleRatio,
      );
      // 스타일 업데이트 - 폰트 크기만 조정
      selectedStyle = selectedStyle.copyWith(fontSize: scaledFontSize);
      selectedMaxLines = _findFittingMaxLines(
        text: text,
        style: selectedStyle,
        maxWidth: maxWidth,
        maxHeight: maxHeight - heightSafetyPadding,
        textScaler: textScaler,
      );

      // 스타일 업데이트 후 텍스트 레이아웃 재계산
      selectedPainter = _buildTextPainter(
        text: text,
        style: selectedStyle,
        maxWidth: maxWidth,
        maxLines: selectedMaxLines,
        ellipsis: '...',
        textScaler: textScaler,
      );
    }

    return _ResolvedTextLayout(
      style: selectedStyle,
      maxLines: selectedMaxLines,
      painter: selectedPainter,
    );
  }

  /// 주어진 스타일/영역에서 ellipsis를 포함해 들어갈 수 있는 최대 줄 수를 계산하는 함수
  ///
  /// Parameters:
  ///   - [text]: 레이아웃을 계산할 텍스트
  ///   - [style]: 텍스트 스타일 (폰트 크기, 줄 높이 등)
  ///   - [maxWidth]: 텍스트가 차지할 수 있는 최대 너비
  ///   - [maxHeight]: 텍스트가 차지할 수 있는 최대 높이
  ///
  /// Returns:
  ///   - 최대 줄 수 (1 이상)
  int _findFittingMaxLines({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required double maxHeight,
    required TextScaler textScaler,
  }) {
    if (maxHeight <= 0) return 1;
    final fontSize = style.fontSize ?? 14.0;
    final lineHeight = fontSize * (style.height ?? 1.0);
    final roughMaxLines = lineHeight > 0
        ? math.max(1, (maxHeight / lineHeight).ceil() + 2)
        : 20;

    var best = 1;
    for (int lines = 1; lines <= roughMaxLines; lines++) {
      final painter = _buildTextPainter(
        text: text,
        style: style,
        maxWidth: maxWidth,
        maxLines: lines,
        ellipsis: '...',
        textScaler: textScaler,
      );
      if (painter.height <= maxHeight) {
        best = lines;
      } else {
        break;
      }
    }

    return best;
  }

  /// 텍스트 레이아웃을 계산하는 함수
  ///
  /// Parameters:
  ///   - [text]: 레이아웃을 계산할 텍스트
  ///   - [style]: 텍스트 스타일
  ///   - [maxWidth]: 텍스트가 차지할 수 있는 최대 너비
  ///   - [maxLines]: 텍스트가 차지할 수 있는 최대 줄 수
  ///
  /// Returns:
  ///   - TextPainter: 계산된 텍스트 레이아웃 정보를 담은 TextPainter 객체
  TextPainter _buildTextPainter({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required int? maxLines,
    required String? ellipsis,
    required TextScaler textScaler,
  }) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: maxLines,
      ellipsis: ellipsis,
    )..layout(maxWidth: maxWidth);
  }

  /// 작성자 아바타 셀만 현재 사용자 selector를 구독해 그리드 전체 재빌드를 막습니다.
  Widget _buildProfileImage() {
    return CurrentUserImageBuilder(
      imageKind: CurrentUserImageKind.profile,
      targetUserHandle: widget.post.nickName,
      fallbackImageUrl: widget.post.userProfileImageUrl,
      fallbackImageKey: widget.post.userProfileImageKey,
      builder: (context, imageUrl, cacheKey) {
        return _GridItemProfileAvatar(
          postId: widget.post.id,
          imageUrl: imageUrl,
          cacheKey: cacheKey,
        );
      },
    );
  }
}

/// 그리드 하단 프로필 이미지만 별도 렌더링해 URL 변경 시 셀 단위로만 갱신합니다.
class _GridItemProfileAvatar extends StatelessWidget {
  const _GridItemProfileAvatar({
    required this.postId,
    required this.imageUrl,
    required this.cacheKey,
  });

  final int postId;
  final String? imageUrl;
  final String? cacheKey;

  @override
  Widget build(BuildContext context) {
    final normalizedImageUrl = imageUrl?.trim();
    final normalizedCacheKey = cacheKey?.trim();
    final resolvedImageUrl = normalizedImageUrl ?? '';
    final hasImageUrl =
        normalizedImageUrl != null && normalizedImageUrl.isNotEmpty;
    final hasCacheKey =
        normalizedCacheKey != null && normalizedCacheKey.isNotEmpty;

    if (!hasImageUrl && hasCacheKey) {
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

    if (!hasImageUrl) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: const Color(0xffd9d9d9),
        child: Icon(Icons.person, color: Colors.white, size: 18.sp),
      );
    }

    return CachedNetworkImage(
      key: ValueKey('profile_${postId}_${normalizedCacheKey ?? 'default'}'),
      imageUrl: resolvedImageUrl,
      cacheKey: normalizedCacheKey,
      useOldImageOnUrlChange: hasCacheKey,
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

class _ResolvedTextLayout {
  final TextStyle style;
  final int? maxLines;
  final TextPainter painter;

  const _ResolvedTextLayout({
    required this.style,
    required this.maxLines,
    required this.painter,
  });
}
