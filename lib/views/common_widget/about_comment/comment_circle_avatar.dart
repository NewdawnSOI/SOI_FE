import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../api/controller/user_controller.dart';
import '../user/current_user_image_builder.dart';
import 'comment_tag_bubble.dart';
import 'model/comment_pending_model.dart';

/// 댓글 태그 안에서 재사용하는 원형 프로필 이미지를 캐시 정책과 함께 렌더링합니다.
class CommentCircleAvatar extends StatelessWidget {
  const CommentCircleAvatar({
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

/// 드래그 중이거나 저장 중인 pending 댓글 태그를 현재 사용자 이미지와 진행 상태로 표현합니다.
class CommentPendingTag extends StatelessWidget {
  const CommentPendingTag({
    super.key,
    this.targetUserId,
    this.profileImageUrl,
    this.profileImageKey,
    this.avatarSize = kPendingCommentAvatarSize,
    this.progress,
    this.opacity = 1,
    this.tagPadding = kCommentTagPadding,
    this.tagBackgroundColor = const Color(0xFF959595),
    this.progressColor = Colors.black,
    this.progressBackgroundColor = Colors.transparent,
  });

  final int? targetUserId;
  final String? profileImageUrl;
  final String? profileImageKey;
  final double avatarSize;
  final double? progress;
  final double opacity;
  final double tagPadding;
  final Color tagBackgroundColor;
  final Color progressColor;
  final Color progressBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final resolvedTargetUserId =
        targetUserId ??
        Provider.of<UserController?>(context, listen: false)?.currentUserId;

    return CommentTagBubble(
      contentSize: avatarSize,
      padding: tagPadding,
      backgroundColor: tagBackgroundColor,
      child: CurrentUserImageBuilder(
        imageKind: CurrentUserImageKind.profile,
        targetUserId: resolvedTargetUserId,
        fallbackImageUrl: _normalizeValue(profileImageUrl),
        fallbackImageKey: _normalizeValue(profileImageKey),
        builder: (context, imageUrl, cacheKey) {
          return SizedBox(
            width: avatarSize,
            height: avatarSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (progress != null)
                  SizedBox(
                    width: avatarSize,
                    height: avatarSize,
                    child: CircularProgressIndicator(
                      value: progress!.clamp(0.0, 1.0),
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      backgroundColor: progressBackgroundColor,
                    ),
                  ),
                CommentCircleAvatar(
                  imageUrl: imageUrl,
                  size: avatarSize,
                  opacity: opacity,
                  cacheKey: cacheKey,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String? _normalizeValue(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

/// 배치된 댓글 태그에서 공통 프로필 이미지를 사용자 selector와 함께 렌더링합니다.
class CommentProfileTagAvatar extends StatelessWidget {
  const CommentProfileTagAvatar({
    super.key,
    required this.targetUserId,
    this.targetUserHandle,
    this.fallbackImageUrl,
    this.fallbackImageKey,
    required this.avatarSize,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 1.5,
    this.opacity = 1,
  });

  final int? targetUserId;
  final String? targetUserHandle;
  final String? fallbackImageUrl;
  final String? fallbackImageKey;
  final double avatarSize;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return CurrentUserImageBuilder(
      imageKind: CurrentUserImageKind.profile,
      targetUserId: targetUserId,
      targetUserHandle: targetUserHandle,
      fallbackImageUrl: fallbackImageUrl,
      fallbackImageKey: fallbackImageKey,
      builder: (context, imageUrl, cacheKey) {
        return CommentCircleAvatar(
          imageUrl: imageUrl,
          size: avatarSize,
          showBorder: showBorder,
          borderColor: borderColor,
          borderWidth: borderWidth,
          opacity: opacity,
          cacheKey: cacheKey,
        );
      },
    );
  }
}
