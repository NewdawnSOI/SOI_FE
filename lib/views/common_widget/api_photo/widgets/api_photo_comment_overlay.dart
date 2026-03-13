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
    final filteredComments = comments.where((comment) => comment.hasLocation);

    return List<Widget>.generate(filteredComments.length, (index) {
      final comment = filteredComments.elementAt(index);
      final key = '${index}_${comment.hashCode}';
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
              key: ValueKey('avatar_$key'),
              imageUrl: comment.userProfileUrl,
              size: avatarSize,
              showBorder: isSelected,
              borderColor: Colors.white,
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
          size: avatarSize,
          progress: marker.progress,
          opacity: 0.85,
        ),
      ),
    );
  }
}
