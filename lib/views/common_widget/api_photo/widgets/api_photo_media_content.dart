import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

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

      if (controller == null || init == null) {
        return _buildUnsupportedMedia();
      }

      return FutureBuilder<void>(
        future: init,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              !controller.value.isInitialized) {
            return _buildMediaPlaceholder();
          }

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
                  child: FittedBox(
                    fit: isVideoCoverMode ? BoxFit.contain : BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    if (hasImage) {
      final dpr = MediaQuery.of(context).devicePixelRatio;

      if (mediaUrl == null || mediaUrl!.isEmpty) {
        return _buildMediaPlaceholder();
      }

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
            child: CachedNetworkImage(
              imageUrl: mediaUrl!,
              cacheKey: postFileKey,
              useOldImageOnUrlChange: true,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              width: imageSize.width,
              height: imageSize.height,
              fit: isImageCoverMode ? BoxFit.contain : BoxFit.cover,
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
