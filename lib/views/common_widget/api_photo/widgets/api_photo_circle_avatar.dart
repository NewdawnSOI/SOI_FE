import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../tag_pointer.dart';

class ApiPhotoCircleAvatar extends StatelessWidget {
  const ApiPhotoCircleAvatar({
    super.key,
    required this.imageUrl,
    this.size = 32,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 1.5,
    this.opacity = 1,
    this.cacheKey,
  });

  final String? imageUrl;
  final double size;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;
  final double opacity;
  final String? cacheKey;

  @override
  Widget build(BuildContext context) {
    Widget avatarContent;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatarContent = ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          cacheKey: cacheKey,
          useOldImageOnUrlChange: cacheKey != null,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: const Color(0xFF2A2A2A),
            highlightColor: const Color(0xFF3A3A3A),
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2A2A2A),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: Color(0xffd9d9d9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white),
          ),
        ),
      );
    } else {
      avatarContent = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xffd9d9d9),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, color: Colors.white),
      );
    }

    if (showBorder) {
      avatarContent = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? Colors.white,
            width: borderWidth,
          ),
        ),
        child: avatarContent,
      );
    }

    return opacity < 1
        ? Opacity(opacity: opacity, child: avatarContent)
        : avatarContent;
  }
}

class ApiPhotoPendingProgressAvatar extends StatelessWidget {
  const ApiPhotoPendingProgressAvatar({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.progress,
    this.opacity = 1,
  });

  final String? imageUrl;
  final double size;
  final double? progress;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return TagBubble(
      contentSize: size,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: progress?.clamp(0.0, 2.0),
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                backgroundColor: Colors.transparent,
              ),
            ),
            ApiPhotoCircleAvatar(
              imageUrl: imageUrl,
              size: size,
              opacity: opacity,
            ),
          ],
        ),
      ),
    );
  }
}
