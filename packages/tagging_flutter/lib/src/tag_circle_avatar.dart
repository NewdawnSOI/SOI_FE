import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'tag_bubble.dart';
import 'tag_specs.dart';

/// 네트워크 기반 태그 아바타를 공통 캐시 정책으로 렌더링합니다.
class TagCircleAvatar extends StatelessWidget {
  const TagCircleAvatar({
    super.key,
    required this.imageUrl,
    this.size = TagProfileTagSpec.avatarSize,
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
    final normalizedImageUrl = imageUrl?.trim() ?? '';
    final resolvedCacheKey = _resolveCacheKey(
      explicitCacheKey: cacheKey,
      imageUrl: normalizedImageUrl,
    );

    if (normalizedImageUrl.isNotEmpty) {
      avatarContent = ClipOval(
        child: CachedNetworkImage(
          imageUrl: normalizedImageUrl,
          cacheKey: resolvedCacheKey,
          useOldImageOnUrlChange: resolvedCacheKey != null,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          width: size,
          height: size,
          memCacheWidth: (size * 3).round(),
          maxWidthDiskCache: (size * 3).round(),
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
          errorWidget: (context, url, error) => _buildFallback(),
        ),
      );
    } else {
      avatarContent = _buildFallback();
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

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xffd9d9d9),
      ),
      child: const Icon(Icons.person, color: Colors.white),
    );
  }

  String? _resolveCacheKey({
    required String? explicitCacheKey,
    required String imageUrl,
  }) {
    final normalizedExplicit = explicitCacheKey?.trim();
    if (normalizedExplicit != null && normalizedExplicit.isNotEmpty) {
      return normalizedExplicit;
    }

    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !uri.hasScheme) {
      return null;
    }

    final normalizedHost = uri.host.trim();
    final normalizedPath = uri.path.trim();
    if (normalizedPath.isEmpty) {
      return null;
    }

    if (normalizedHost.isEmpty) {
      return normalizedPath;
    }

    return '$normalizedHost$normalizedPath';
  }
}

/// pending 진행률을 함께 보여주는 태그 아바타입니다.
class TagPendingProgressAvatar extends StatelessWidget {
  const TagPendingProgressAvatar({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.progress,
    this.opacity = 1,
    this.cacheKey,
    this.tagPadding = TagProfileTagSpec.padding,
    this.tagBackgroundColor = const Color(0xFF959595),
  });

  final String? imageUrl;
  final double size;
  final double? progress;
  final double opacity;
  final String? cacheKey;
  final double tagPadding;
  final Color tagBackgroundColor;

  @override
  Widget build(BuildContext context) {
    return TagBubble(
      contentSize: size,
      padding: tagPadding,
      backgroundColor: tagBackgroundColor,
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
                value: progress?.clamp(0.0, 1.0),
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                backgroundColor: Colors.transparent,
              ),
            ),
            TagCircleAvatar(
              imageUrl: imageUrl,
              size: size,
              opacity: opacity,
              cacheKey: cacheKey,
            ),
          ],
        ),
      ),
    );
  }
}
