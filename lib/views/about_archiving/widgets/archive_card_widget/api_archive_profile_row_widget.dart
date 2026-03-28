import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:soi/api/controller/media_controller.dart';

/// REST API 기반 프로필 이미지 행 위젯
///
/// Category 객체에서 직접 프로필 URL/키 리스트와 총 인원수를 받아 표시합니다.
/// 최대 3개의 프로필을 표시하고, 초과 인원은 +N 배지로 표시합니다.
class ApiArchiveProfileRowWidget extends StatefulWidget {
  final List<String> profileImageUrls;
  final List<String> profileImageKeys;
  final int totalUserCount;
  final double avatarSize;

  const ApiArchiveProfileRowWidget({
    super.key,
    required this.profileImageUrls,
    required this.profileImageKeys,
    this.totalUserCount = 0,
    this.avatarSize = 23.44,
  }) : assert(avatarSize > 0);

  @override
  State<ApiArchiveProfileRowWidget> createState() =>
      _ApiArchiveProfileRowWidgetState();
}

class _ApiArchiveProfileRowWidgetState
    extends State<ApiArchiveProfileRowWidget> {
  // Presigned URL 캐시 (키 -> URL)
  final Map<String, String> _presignedUrlCache = {};

  @override
  void initState() {
    super.initState();
    _loadPresignedUrls();
  }

  @override
  void didUpdateWidget(ApiArchiveProfileRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final urlsChanged = !listEquals(
      oldWidget.profileImageUrls,
      widget.profileImageUrls,
    );
    final keysChanged = !listEquals(
      oldWidget.profileImageKeys,
      widget.profileImageKeys,
    );
    final countChanged = oldWidget.totalUserCount != widget.totalUserCount;

    if (urlsChanged || keysChanged || countChanged) {
      _presignedUrlCache.clear();
      _loadPresignedUrls(forceReload: true);
    }
  }

  /// 인덱스별 프로필 이미지 key를 읽어 key 기반 캐시와 presigned URL 갱신에 사용합니다.
  String? _profileImageKeyAt(int index) {
    if (index < 0 || index >= widget.profileImageKeys.length) {
      return null;
    }
    final normalized = widget.profileImageKeys[index].trim();
    return normalized.isEmpty ? null : normalized;
  }

  /// 인덱스별 프로필 이미지 URL을 읽어 첫 프레임에서 바로 렌더할 값을 제공합니다.
  String? _profileImageUrlAt(int index) {
    if (index < 0 || index >= widget.profileImageUrls.length) {
      return null;
    }
    final normalized = widget.profileImageUrls[index].trim();
    return normalized.isEmpty ? null : normalized;
  }

  /// key 기반으로 새 URL이 로드되면 그것을 우선 쓰고, 없으면 즉시 사용 가능한 URL을 그대로 사용합니다.
  String? _resolveDisplayImageUrlAt(int index) {
    final key = _profileImageKeyAt(index);
    final resolvedUrl = key == null ? null : _presignedUrlCache[key];
    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      return resolvedUrl;
    }

    return _profileImageUrlAt(index);
  }

  /// key가 있으면 그것을 캐시 식별자로 고정하고, 없을 때만 URL 기반 캐시 키를 사용합니다.
  String? _resolveCacheKeyAt(int index) {
    final key = _profileImageKeyAt(index);
    if (key != null) {
      return key;
    }

    final imageUrl = _profileImageUrlAt(index);
    if (imageUrl == null) {
      return null;
    }

    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !uri.hasScheme) {
      return null;
    }

    final normalizedPath = uri.path.trim();
    if (normalizedPath.isEmpty) {
      return null;
    }

    final normalizedHost = uri.host.trim();
    return normalizedHost.isEmpty
        ? normalizedPath
        : '$normalizedHost$normalizedPath';
  }

  Future<void> _loadPresignedUrls({bool forceReload = false}) async {
    final mediaController = context.read<MediaController>();
    final displayCount = widget.totalUserCount.clamp(1, 3);

    // 표시할 프로필 key들만 로드하되, 즉시 URL이 있더라도 key 기준 최신 URL로 갱신할 수 있도록 유지합니다.
    final keysToLoad = List<String?>.generate(
      displayCount,
      _profileImageKeyAt,
    ).whereType<String>().toList(growable: false);
    final unresolvedKeys = keysToLoad
        .where((key) => forceReload || !_presignedUrlCache.containsKey(key))
        .toList(growable: false);

    if (unresolvedKeys.isEmpty) {
      return;
    }

    final urls = await mediaController.getPresignedUrls(unresolvedKeys);
    if (!mounted) {
      return;
    }

    final resolvedUrls = <String, String>{};
    final resolvedCount = urls.length < unresolvedKeys.length
        ? urls.length
        : unresolvedKeys.length;
    for (var index = 0; index < resolvedCount; index++) {
      final url = urls[index];
      if (url.isEmpty) {
        continue;
      }
      resolvedUrls[unresolvedKeys[index]] = url;
    }

    if (resolvedUrls.isEmpty) {
      return;
    }

    setState(() {
      _presignedUrlCache.addAll(resolvedUrls);
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayCount = widget.totalUserCount.clamp(1, 3);
    final remainingCount = widget.totalUserCount > 3
        ? widget.totalUserCount - 3
        : 0;
    const overlapSpacing = 12.0;
    final avatarSize = widget.avatarSize;

    // +N 배지 포함 시 너비 계산
    final badgeCount = remainingCount > 0 ? 1 : 0;
    final totalWidth =
        (displayCount - 1 + badgeCount) * overlapSpacing + avatarSize;

    return SizedBox(
      height: avatarSize,
      width: totalWidth,
      child: Stack(
        children: [
          // displayCount개 프로필 표시
          ...List.generate(displayCount, (index) {
            final imageUrl = _resolveDisplayImageUrlAt(index) ?? '';
            final cacheKey = _resolveCacheKeyAt(index);

            return Positioned(
              right: index * overlapSpacing,
              child: imageUrl.isEmpty
                  ? _buildDefaultAvatar()
                  : _buildProfileImage(imageUrl, cacheKey: cacheKey),
            );
          }),
          // +N 배지 표시 (3명 초과 시)
          if (remainingCount > 0)
            Positioned(
              right: displayCount * overlapSpacing,
              child: _buildRemainingBadge(remainingCount),
            ),
        ],
      ),
    );
  }

  /// 기본 아바타 (이미지 없을 때)
  Widget _buildDefaultAvatar() {
    return Container(
      width: widget.avatarSize,
      height: widget.avatarSize,
      decoration: BoxDecoration(
        color: Colors.grey.shade700,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF1C1C1C), width: 1.5),
      ),
      child: const Icon(Icons.person, size: 12, color: Colors.white54),
    );
  }

  /// 프로필 이미지 빌드
  Widget _buildProfileImage(String imageUrl, {String? cacheKey}) {
    return Container(
      width: widget.avatarSize,
      height: widget.avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF1C1C1C), width: 1.5),
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          cacheKey: cacheKey,
          useOldImageOnUrlChange: cacheKey != null,
          width: widget.avatarSize,
          height: widget.avatarSize,
          memCacheWidth: (widget.avatarSize * 3).round(),
          maxWidthDiskCache: (widget.avatarSize * 3).round(),
          fit: BoxFit.cover,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: Colors.grey.shade800,
            highlightColor: Colors.grey.shade700,
            child: Container(
              width: widget.avatarSize,
              height: widget.avatarSize,
              color: Colors.grey.shade800,
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: widget.avatarSize,
            height: widget.avatarSize,
            color: Colors.grey.shade700,
            child: const Icon(Icons.person, size: 12, color: Colors.white54),
          ),
        ),
      ),
    );
  }

  /// 남은 인원수 배지 (+N)
  Widget _buildRemainingBadge(int count) {
    return Container(
      width: widget.avatarSize,
      height: widget.avatarSize,
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF1C1C1C), width: 1.5),
      ),
      child: Center(
        child: Text(
          '+$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
