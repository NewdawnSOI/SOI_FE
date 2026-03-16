import 'package:flutter/material.dart';

import '../../../../api/models/comment.dart';
import '../../../../utils/position_converter.dart';
import '../../about_comment/pending_api_voice_comment.dart';
import '../services/api_photo_tag_geometry_service.dart';
import '../tag_pointer.dart';
import 'api_photo_circle_avatar.dart';

typedef ApiPhotoCommentTapCallback =
    void Function({
      required Comment comment,
      required String key,
      required Offset tipAnchor,
    });

typedef ApiPhotoCommentLongPressCallback =
    void Function({
      required String key,
      required int? commentId,
      required Offset position,
    });

class ApiPhotoCommentOverlay extends StatelessWidget {
  const ApiPhotoCommentOverlay({
    super.key,
    required this.comments,
    required this.pendingMarker,
    required this.isShowingComments,
    required this.showActionOverlay,
    required this.selectedCommentKey,
    required this.expandedMediaTagKey,
    required this.imageSize,
    required this.avatarSize,
    required this.onCommentTap,
    required this.onCommentLongPress,
  });

  final List<Comment> comments;
  final PendingApiCommentMarker? pendingMarker;
  final bool isShowingComments;
  final bool showActionOverlay;
  final String? selectedCommentKey;
  final String? expandedMediaTagKey;
  final Size imageSize;
  final double avatarSize;
  final ApiPhotoCommentTapCallback onCommentTap;
  final ApiPhotoCommentLongPressCallback onCommentLongPress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (isShowingComments) ..._buildCommentAvatars(),
        if (pendingMarker != null) _buildPendingMarker(pendingMarker!),
      ],
    );
  }

  List<Widget> _buildCommentAvatars() {
    final filteredComments = comments
        .where((comment) => comment.hasLocation)
        .toList(growable: false);

    return List<Widget>.generate(filteredComments.length, (index) {
      final comment = filteredComments[index];
      final key = _buildStableCommentKey(comment, index);
      final canExpandMedia = ApiPhotoTagGeometryService.canExpandMediaComment(
        comment,
      );
      final relative = Offset(
        comment.locationX ?? 0.5,
        comment.locationY ?? 0.5,
      );
      final absolute = PositionConverter.toAbsolutePosition(
        relative,
        imageSize,
      );
      final clampedSmallTip = ApiPhotoTagGeometryService.clampTagAnchor(
        absolute,
        imageSize,
        avatarSize,
      );
      final topLeft = ApiPhotoTagGeometryService.tagTopLeftFromTipAnchor(
        clampedSmallTip,
        avatarSize,
      );
      final hideOther =
          showActionOverlay &&
          selectedCommentKey != null &&
          key != selectedCommentKey;
      final hideExpandedTag = expandedMediaTagKey == key && canExpandMedia;

      if (hideOther || hideExpandedTag) {
        return const SizedBox.shrink();
      }

      final isSelected = selectedCommentKey == key;

      return Positioned(
        left: topLeft.dx,
        top: topLeft.dy,
        child: GestureDetector(
          onTap: () => onCommentTap(
            comment: comment,
            key: key,
            tipAnchor: clampedSmallTip,
          ),
          onLongPress: () => onCommentLongPress(
            key: key,
            commentId: comment.id,
            position: clampedSmallTip,
          ),
          child: TagBubble(
            contentSize: avatarSize,
            child: ApiPhotoCircleAvatar(
              key: ValueKey<String>('avatar_$key'),
              imageUrl: _resolveProfileImageSource(comment),
              size: avatarSize,
              showBorder: isSelected,
              borderColor: Colors.white,
              cacheKey: _resolveProfileCacheKey(comment),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildPendingMarker(PendingApiCommentMarker marker) {
    final absolute = PositionConverter.toAbsolutePosition(
      marker.relativePosition,
      imageSize,
    );
    final clamped = ApiPhotoTagGeometryService.clampTagAnchor(
      absolute,
      imageSize,
      avatarSize,
    );
    final tipOffset = TagBubble.pointerTipOffset(contentSize: avatarSize);

    return Positioned(
      left: clamped.dx - tipOffset.dx,
      top: clamped.dy - tipOffset.dy,
      child: IgnorePointer(
        child: ApiPhotoPendingProgressAvatar(
          imageUrl: marker.profileImageUrlKey,
          cacheKey: _normalizeKey(marker.profileImageUrlKey),
          size: avatarSize,
          progress: marker.progress,
          opacity: 0.85,
        ),
      ),
    );
  }

  String _buildStableCommentKey(Comment comment, int index) {
    final commentId = comment.id;
    if (commentId != null) {
      return 'comment_$commentId';
    }

    final userId = comment.userId ?? 0;
    final x = comment.locationX?.toStringAsFixed(4) ?? 'x';
    final y = comment.locationY?.toStringAsFixed(4) ?? 'y';
    return 'comment_${userId}_${x}_${y}_$index';
  }

  String? _resolveProfileImageSource(Comment comment) {
    final profileUrl = (comment.userProfileUrl ?? '').trim();
    if (profileUrl.isNotEmpty) {
      return profileUrl;
    }

    final profileKey = (comment.userProfileKey ?? '').trim();
    if (profileKey.isNotEmpty) {
      return profileKey;
    }

    return null;
  }

  String? _resolveProfileCacheKey(Comment comment) {
    final profileKey = _normalizeKey(comment.userProfileKey);
    if (profileKey != null) {
      return profileKey;
    }

    final profileUrl = (comment.userProfileUrl ?? '').trim();
    final uri = Uri.tryParse(profileUrl);
    if (uri == null || !uri.hasScheme) {
      return null;
    }

    final normalizedPath = uri.path.trim();
    if (normalizedPath.isEmpty) {
      return null;
    }

    final normalizedHost = uri.host.trim();
    if (normalizedHost.isEmpty) {
      return normalizedPath;
    }

    return '$normalizedHost$normalizedPath';
  }

  String? _normalizeKey(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
