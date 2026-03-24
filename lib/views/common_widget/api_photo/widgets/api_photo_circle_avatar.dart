import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../tag_pointer.dart';

/// 이미지/비디오 위에 댓글 작성자 프로필 사진을 원형 아바타로 보여주는 위젯입니다.
/// - 댓글 작성자의 프로필 이미지를 원형으로 보여주는 태그입니다.
/// - 댓글 작성 중인 위치에 드래그하여 배치할 수 있으며, 드래그가 완료되면 댓글 작성이 완료되는 방식으로 동작합니다.
/// - 댓글 작성이 완료되면, 부모 위젯에 댓글 저장 진행 상황과 결과를 전달하는 역할도 수행합니다.
///
/// fields:
/// - [imageUrl]: 아바타로 보여줄 이미지의 URL입니다. null이거나 빈 문자열인 경우 기본 아바타 이미지가 보여집니다.
/// - [size]: 아바타의 가로세로 크기를 결정하는 값입니다. 기본값은 32입니다.
/// - [showBorder]: 아바타에 테두리를 보여줄지 여부를 결정하는 플래그입니다. 기본값은 false입니다.
/// - [borderColor]: 테두리를 보여줄 때 사용할 테두리 색상입니다. 기본값은 null이며, showBorder가 true이고 borderColor가 null인 경우 테두리 색상은 흰색으로 설정됩니다.
/// - [borderWidth]: 테두리를 보여줄 때 사용할 테두리 두께입니다. 기본값은 1.5입니다.
/// - [opacity]: 아바타의 투명도를 결정하는 값입니다. 0.0 (완전히 투명)에서 1.0 (완전히 불투명) 사이의 값을 가질 수 있으며, 기본값은 1입니다.
/// - [cacheKey]
///   - CachedNetworkImage에서 이미지 캐싱에 사용할 키입니다.
///   - 명시적으로 제공되지 않으면 imageUrl을 기반으로 캐시 키가 생성됩니다.
///   - 캐시 키는 이미지 URL이 변경되었을 때도 동일한 이미지를 재사용할 수 있도록 하는 역할을 합니다.
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
          memCacheWidth: (size * 4).round(),
          memCacheHeight: (size * 4).round(),
          maxWidthDiskCache: (size * 4).round(),
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

/// pending중인 댓글 마커로 사용할 원형 아바타 위젯입니다.
/// - 댓글 작성 중인 위치에 드래그하여 배치할 수 있으며, 드래그가 완료되면 댓글 작성이 완료되는 방식으로 동작합니다.
/// - 댓글 작성이 완료되면, 부모 위젯에 댓글 저장 진행 상황과 결과를 전달하는 역할도 수행합니다.
class ApiPhotoPendingProgressAvatar extends StatelessWidget {
  const ApiPhotoPendingProgressAvatar({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.progress,
    this.opacity = 1,
    this.cacheKey,
  });

  final String? imageUrl;
  final double size;
  final double? progress;
  final double opacity;
  final String? cacheKey;

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
            // 진행률 표시 원형 프로그레스 인디케이터
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

            // 프로필 이미지 아바타
            ApiPhotoCircleAvatar(
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
