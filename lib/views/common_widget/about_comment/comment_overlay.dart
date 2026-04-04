import 'package:flutter/material.dart';

import '../../../../api/models/comment.dart';
import '../../../../utils/position_converter.dart';
import '../photo/services/photo_tag_geometry_service.dart';
import 'comment_circle_avatar.dart';
import 'comment_tag_bubble.dart';
import 'model/comment_pending_model.dart';

typedef CommentTapCallback =
    void Function({
      required Comment comment,
      required String key,
      required Offset tipAnchor,
    });

typedef CommentLongPressCallback =
    void Function({
      required String key,
      required int? commentId,
      required Offset position,
    });

/// 사진 위에 배치된 댓글 태그와 pending 태그를 같은 좌표계 규칙으로 렌더링합니다.
class CommentOverlay extends StatelessWidget {
  const CommentOverlay({
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
  final CommentTapCallback onCommentTap;
  final CommentLongPressCallback onCommentLongPress;

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

  /// 위치가 있는 댓글만 골라 사진 좌표 위에 개별 태그로 배치합니다.
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
          child: CommentTagBubble(
            contentSize: avatarSize,
            child: CommentProfileTagAvatar(
              key: ValueKey<String>('avatar_$key'),
              targetUserId: comment.userId,
              targetUserHandle: comment.nickname,
              fallbackImageUrl: comment.userProfileUrl,
              fallbackImageKey: comment.userProfileKey,
              avatarSize: avatarSize,
              showBorder: isSelected,
              borderColor: Colors.white,
            ),
          ),
        ),
      );
    });
  }

  /// pending 댓글 마커를 동일한 태그 스타일 위에 진행률과 함께 배치합니다.
  Widget _buildPendingMarker(PendingApiCommentMarker marker) {
    final circleCenter = PositionConverter.toAbsolutePosition(
      marker.relativePosition,
      imageSize,
    );
    final pendingDiameter = CommentTagBubble.diameterForContent(
      contentSize: kPendingCommentAvatarSize,
      padding: kPendingCommentTagPadding,
    );
    final clampedCenter = Offset(
      circleCenter.dx.clamp(
        pendingDiameter / 2,
        imageSize.width - (pendingDiameter / 2),
      ),
      circleCenter.dy.clamp(
        pendingDiameter / 2,
        imageSize.height - (pendingDiameter / 2),
      ),
    );
    final pendingCenterOffset = CommentTagBubble.circleCenterOffset(
      contentSize: kPendingCommentAvatarSize,
      padding: kPendingCommentTagPadding,
    );

    return Positioned(
      left: clampedCenter.dx - pendingCenterOffset.dx,
      top: clampedCenter.dy - pendingCenterOffset.dy,
      child: IgnorePointer(
        child: CommentPendingTag(
          profileImageUrl: _isAbsoluteUrl(marker.profileImageUrlKey)
              ? _normalizeKey(marker.profileImageUrlKey)
              : null,
          profileImageKey: _isAbsoluteUrl(marker.profileImageUrlKey)
              ? null
              : _normalizeKey(marker.profileImageUrlKey),
          avatarSize: kPendingCommentAvatarSize,
          progress: marker.progress,
          opacity: 0.85,
          tagPadding: kPendingCommentTagPadding,
          tagBackgroundColor: kPendingCommentTagBackgroundColor,
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

  String? _normalizeKey(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  bool _isAbsoluteUrl(String? value) {
    final normalized = _normalizeKey(value);
    if (normalized == null) {
      return false;
    }

    final uri = Uri.tryParse(normalized);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }
}
