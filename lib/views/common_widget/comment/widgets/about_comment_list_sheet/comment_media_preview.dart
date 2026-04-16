// == dart 패키지 ==
import 'dart:io';
import 'dart:typed_data';

// == flutter 패키지 ==
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:soi/utils/video_thumbnail_cache.dart';
import 'package:tagging_flutter/tagging_flutter.dart';
import 'package:video_player/video_player.dart';

/// 댓글에 첨부된 이미지나 동영상의 미리보기를 보여주는 위젯
/// [isVideo]가 true이면 동영상 미리보기를, false이면 이미지 미리보기를 보여줍니다.
///
/// Parameters:
/// - [source]: 이미지나 동영상의 URL 또는 로컬 파일 경로
/// - [isVideo]: 첨부된 미디어가 동영상인지 여부
/// - [cacheKey]: 동영상 썸네일 캐시를 위한 고유 키
///
/// Returns:
/// - 동영상인 경우, 썸네일을 보여주고 탭하면 동영상이 재생됩니다. 재생 중에는 플레이 아이콘이 사라지고, 탭하면 재생이 일시정지됩니다.
///   동영상 로드에 실패하면 썸네일 대신 이미지 미리보기가 표시됩니다.
/// - 이미지인 경우, 해당 이미지를 보여줍니다. 로드에 실패하면 기본 이미지 미리보기가 표시됩니다.
class ApiCommentMediaPreview extends StatefulWidget {
  final String source;
  final bool isVideo;
  final String cacheKey;

  const ApiCommentMediaPreview({
    super.key,
    required this.source,
    required this.isVideo,
    required this.cacheKey,
  });

  @override
  State<ApiCommentMediaPreview> createState() => _ApiCommentMediaPreviewState();
}

class _ApiCommentMediaPreviewState extends State<ApiCommentMediaPreview> {
  Future<Uint8List?>? _thumbnailFuture;
  VideoPlayerController? _videoController;
  Future<void>? _videoInitialization;
  bool _videoLoadFailed = false;
  bool _showPlayOverlay = true;

  @override
  void initState() {
    super.initState();
    _refreshPreviewState();
  }

  @override
  void didUpdateWidget(covariant ApiCommentMediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.cacheKey != widget.cacheKey) {
      _refreshPreviewState();
    }
  }

  @override
  void dispose() {
    _disposeVideoController();
    super.dispose();
  }

  void _refreshPreviewState() {
    _showPlayOverlay = true;
    _refreshThumbnailFuture();
    if (widget.isVideo) {
      _initializeVideoController();
    } else {
      _disposeVideoController();
    }
  }

  void _refreshThumbnailFuture() {
    if (!widget.isVideo) {
      _thumbnailFuture = null;
      return;
    }

    final stableKey = VideoThumbnailCache.buildStableCacheKey(
      fileKey: widget.cacheKey,
      videoUrl: widget.source,
    );
    _thumbnailFuture = VideoThumbnailCache.getThumbnail(
      videoUrl: widget.source,
      cacheKey: stableKey,
    );
  }

  Future<void> _initializeVideoController() async {
    _disposeVideoController();
    _videoLoadFailed = false;
    _showPlayOverlay = true;

    final source = widget.source;
    final isLocal = _isLocalFile(source);

    VideoPlayerController? controller;
    try {
      if (isLocal) {
        final file = File(source);
        if (!await file.exists()) {
          if (!mounted) return;
          setState(() {
            _videoLoadFailed = true;
          });
          return;
        }
        controller = VideoPlayerController.file(file);
      } else {
        controller = VideoPlayerController.networkUrl(Uri.parse(source));
      }

      _videoController = controller;
      _videoInitialization = controller
          .initialize()
          .then((_) async {
            await controller?.setLooping(true);
            await controller?.setVolume(1.0);
            if (!mounted) return;
            setState(() {});
          })
          .catchError((_) {
            if (!mounted) return;
            setState(() {
              _videoLoadFailed = true;
              _showPlayOverlay = true;
            });
          });

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _videoLoadFailed = true;
        _showPlayOverlay = true;
      });
    }
  }

  void _disposeVideoController() {
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    _videoInitialization = null;
  }

  Future<void> _toggleVideoPlayback() async {
    final controller = _videoController;
    final initialization = _videoInitialization;
    if (controller == null || initialization == null) {
      return;
    }

    try {
      if (!controller.value.isInitialized) {
        await initialization;
      }
      if (!mounted || !controller.value.isInitialized) {
        return;
      }

      if (controller.value.isPlaying) {
        await controller.pause();
        if (!mounted) return;
        setState(() {
          _showPlayOverlay = true;
        });
      } else {
        await controller.play();
        if (!mounted) return;
        setState(() {
          _showPlayOverlay = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _videoLoadFailed = true;
        _showPlayOverlay = true;
      });
    }
  }

  bool _isLocalFile(String source) {
    final uri = Uri.tryParse(source);
    if (uri == null) {
      return false;
    }
    if (uri.hasScheme) {
      return uri.scheme == 'file';
    }
    return true;
  }

  Widget _buildImagePreview() {
    final source = widget.source;
    final isLocal = _isLocalFile(source);
    final file = File(source);

    if (isLocal) {
      if (!file.existsSync()) {
        return _buildPlaceholder();
      }
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    return CachedNetworkImage(
      imageUrl: source,
      cacheKey: widget.cacheKey,
      useOldImageOnUrlChange: true,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => _buildPlaceholder(),
      errorWidget: (_, __, ___) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return const ColoredBox(
      color: Color(0xFF4A4A4A),
      child: Center(
        child: Icon(Icons.image_not_supported, color: Colors.white70, size: 24),
      ),
    );
  }

  Widget _buildThumbnail({bool showPlayIcon = false}) {
    return FutureBuilder<Uint8List?>(
      future: _thumbnailFuture,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes, fit: BoxFit.cover)
            else
              _buildPlaceholder(),
            if (showPlayIcon)
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 30,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildVideoPreview() {
    final controller = _videoController;
    final initialization = _videoInitialization;

    final videoContent =
        _videoLoadFailed || controller == null || initialization == null
        ? _buildThumbnail()
        : FutureBuilder<void>(
            future: initialization,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done ||
                  !controller.value.isInitialized) {
                return _buildThumbnail();
              }

              return FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              );
            },
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleVideoPlayback,
      child: Stack(
        fit: StackFit.expand,
        children: [
          videoContent,
          if (_showPlayOverlay)
            const Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 30,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // 태그 미디어 프리뷰 규격을 사용하여 프레임과 콘텐츠 크기를 맞춥니다.
      width: TagProfileMediaPreviewSpec.frameSize,
      height: TagProfileMediaPreviewSpec.frameSize,
      padding: EdgeInsets.all(TagProfileMediaPreviewSpec.padding),
      decoration: const BoxDecoration(
        color: Color(0xFF959595),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: SizedBox(
          width: TagProfileMediaPreviewSpec.contentSize,
          height: TagProfileMediaPreviewSpec.contentSize,
          child: widget.isVideo ? _buildVideoPreview() : _buildImagePreview(),
        ),
      ),
    );
  }
}
