import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// API에서 받아온 미디어(PostFileKey)를 기반으로 이미지 또는 비디오를 렌더링하는 위젯입니다.
/// - 텍스트만 있는 포스트는 텍스트 전용 렌더링을 합니다.
/// - 이미지/비디오가 있는 포스트는 해당 미디어를 렌더링하며, 더블탭으로 BoxFit 토글이 가능합니다.
/// - 비디오의 경우, 가시성에 따라 자동 재생/일시정지가 됩니다.
class ApiPhotoMediaContent extends StatelessWidget {
  const ApiPhotoMediaContent({
    super.key,
    required this.isTextOnlyPost,
    required this.isVideoPost,
    required this.hasImage,
    required this.mediaUrl,
    required this.postFileKey,
    required this.textContent,
    required this.imageSize,
    required this.videoController,
    required this.videoInitialization,
    required this.isVideoCoverMode,
    required this.isImageCoverMode,
    required this.onVideoToggleFit,
    required this.onImageToggleFit,
    required this.onVideoVisibilityChanged,
  });

  final bool isTextOnlyPost;
  final bool isVideoPost;
  final bool hasImage;
  final String? mediaUrl;
  final String? postFileKey;
  final String textContent;
  final Size imageSize;
  final VideoPlayerController? videoController;
  final Future<void>? videoInitialization;
  final bool isVideoCoverMode;
  final bool isImageCoverMode;
  final VoidCallback onVideoToggleFit;
  final VoidCallback onImageToggleFit;
  final ValueChanged<bool> onVideoVisibilityChanged;

  /// 포스트 유형에 따라 텍스트, 이미지, 비디오 렌더링과 기본 BoxFit 정책을 선택합니다.
  @override
  Widget build(BuildContext context) {
    if (isTextOnlyPost) {
      return _buildTextOnlyContent();
    }

    if (isVideoPost) {
      final controller = videoController;
      final init = videoInitialization;

      if (mediaUrl == null || mediaUrl!.isEmpty) {
        return _buildMediaPlaceholder();
      }

      // controller 유무와 상관없이 visibility를 먼저 측정해 lazy init 트리거를 보장합니다.
      return VisibilityDetector(
        key: ValueKey('api_video_$postFileKey'),
        onVisibilityChanged: (info) {
          onVideoVisibilityChanged(info.visibleFraction >= 0.6);
        },
        child: GestureDetector(
          onDoubleTap: onVideoToggleFit,
          child: Container(
            width: imageSize.width,
            height: imageSize.height,
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: const Color(0xff2b2b2b), width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Builder(
                builder: (context) {
                  if (controller == null || init == null) {
                    return _buildMediaPlaceholder();
                  }

                  return FutureBuilder<void>(
                    future: init,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done ||
                          !controller.value.isInitialized) {
                        return _buildMediaPlaceholder();
                      }

                      return FittedBox(
                        fit: isVideoCoverMode ? BoxFit.cover : BoxFit.contain,
                        child: SizedBox(
                          width: controller.value.size.width,
                          height: controller.value.size.height,
                          child: VideoPlayer(controller),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    if (hasImage) {
      final dpr = MediaQuery.of(context).devicePixelRatio;

      if (mediaUrl == null || mediaUrl!.isEmpty) {
        return _buildMediaPlaceholder();
      }

      //
      return GestureDetector(
        onDoubleTap: onImageToggleFit,
        child: Container(
          width: imageSize.width,
          height: imageSize.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: const Color(0xff2b2b2b), width: 2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            //
            child: CachedNetworkImage(
              imageUrl: mediaUrl!,
              cacheKey: postFileKey,
              useOldImageOnUrlChange: true,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              width: imageSize.width,
              height: imageSize.height,
              fit: isImageCoverMode ? BoxFit.cover : BoxFit.contain,
              memCacheWidth: (354.w * dpr).round(),
              maxWidthDiskCache: (354.w * dpr).round(),
              placeholder: (context, _) => _buildMediaPlaceholder(),
              errorWidget: (context, _, __) => Container(
                width: imageSize.width,
                height: imageSize.height,
                color: Colors.grey[800],
                child: Icon(
                  Icons.broken_image,
                  color: Colors.grey[600],
                  size: 50.w,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return _buildUnsupportedMedia();
  }

  /// 텍스트 전용 포스트 렌더링
  Widget _buildTextOnlyContent() {
    final text = textContent.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: const Color(0xff2b2b2b), width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          color: const Color(0xff1e1e1e),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xfff8f8f8),
                        fontSize: 30.sp,
                        fontFamily: 'Pretendard Variable',
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 지원되지 않는 미디어 유형에 대한 기본 렌더링
  Widget _buildUnsupportedMedia() {
    return Container(
      width: imageSize.width,
      height: imageSize.height,
      color: Colors.grey[800],
      child: Icon(
        Icons.image_not_supported,
        color: Colors.grey[600],
        size: 50.w,
      ),
    );
  }

  /// 로딩 중이거나 URL이 유효하지 않은 이미지/비디오에 대한 플레이스홀더 렌더링
  Widget _buildMediaPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: Container(
        width: imageSize.width,
        height: imageSize.height,
        color: Colors.grey[800],
      ),
    );
  }
}
