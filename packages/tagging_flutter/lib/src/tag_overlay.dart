import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tagging_core/tagging_core.dart';

import 'tag_bubble.dart';
import 'tag_geometry_service.dart';
import 'tag_specs.dart';

typedef TagTapCallback =
    Future<void> Function({
      required TagEntry comment,
      required String key,
      required Offset tipAnchor,
    });

typedef TagLongPressCallback =
    void Function({
      required String key,
      required TagEntityId? commentId,
      required Offset position,
    });

typedef TagCommentAvatarBuilder =
    Widget Function(
      BuildContext context,
      TagEntry comment,
      double size,
      bool isSelected,
    );

typedef TagPendingMarkerAvatarBuilder =
    Widget Function(
      BuildContext context,
      TagPendingMarker marker,
      double size,
      double? progress,
    );

/// media 위의 persisted tag와 pending marker를 같은 좌표계로 렌더링합니다.
class TagOverlay extends StatelessWidget {
  const TagOverlay({
    super.key,
    required this.comments,
    required this.pendingMarker,
    required this.isShowingComments,
    required this.showActionOverlay,
    required this.selectedCommentKey,
    required this.expandedMediaTagKey,
    required this.imageSize,
    required this.commentAvatarBuilder,
    required this.pendingAvatarBuilder,
    required this.onCommentTap,
    required this.onCommentLongPress,
    this.canExpandEntry,
  });

  final List<TagEntry> comments;
  final TagPendingMarker? pendingMarker;
  final bool isShowingComments;
  final bool showActionOverlay;
  final String? selectedCommentKey;
  final String? expandedMediaTagKey;
  final Size imageSize;
  final TagCommentAvatarBuilder commentAvatarBuilder;
  final TagPendingMarkerAvatarBuilder pendingAvatarBuilder;
  final TagTapCallback onCommentTap;
  final TagLongPressCallback onCommentLongPress;
  final bool Function(TagEntry entry)? canExpandEntry;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (isShowingComments) ..._buildCommentAvatars(context),
        if (pendingMarker != null) _buildPendingMarker(context, pendingMarker!),
      ],
    );
  }

  List<Widget> _buildCommentAvatars(BuildContext context) {
    final filteredComments = comments
        .where((comment) => comment.hasLocation)
        .toList(growable: false);

    return List<Widget>.generate(filteredComments.length, (index) {
      final comment = filteredComments[index];
      final key = _buildStableCommentKey(comment, index);
      final canExpandMedia = canExpandEntry?.call(comment) ?? false;
      final anchor = comment.anchor;
      if (anchor == null) {
        return const SizedBox.shrink();
      }
      final absolute = TagPositionMath.denormalizeRelativePosition(
        relativePosition: anchor,
        viewportSize: TagViewportSize(
          width: imageSize.width,
          height: imageSize.height,
        ),
      );
      final clampedSmallTip = TagGeometryService.clampTagAnchor(
        Offset(absolute.x, absolute.y),
        imageSize,
        TagProfileTagSpec.avatarSize,
      );
      final topLeft = TagGeometryService.tagTopLeftFromTipAnchor(
        clampedSmallTip,
        TagProfileTagSpec.avatarSize,
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
          onTap: () {
            unawaited(
              onCommentTap(
                comment: comment,
                key: key,
                tipAnchor: clampedSmallTip,
              ),
            );
          },
          onLongPress: () => onCommentLongPress(
            key: key,
            commentId: comment.id,
            position: clampedSmallTip,
          ),
          child: TagBubble(
            contentSize: TagProfileTagSpec.avatarSize,
            child: commentAvatarBuilder(
              context,
              comment,
              TagProfileTagSpec.avatarSize,
              isSelected,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildPendingMarker(BuildContext context, TagPendingMarker marker) {
    final absolute = TagPositionMath.denormalizeRelativePosition(
      relativePosition: marker.relativePosition,
      viewportSize: TagViewportSize(
        width: imageSize.width,
        height: imageSize.height,
      ),
    );
    final pendingTipOffset = TagBubble.pointerTipOffset(
      contentSize: TagProfileTagSpec.avatarSize,
      padding: TagProfileTagSpec.padding,
    );
    final pendingDiameter = TagBubble.diameterForContent(
      contentSize: TagProfileTagSpec.avatarSize,
      padding: TagProfileTagSpec.padding,
    );
    final clamped = Offset(
      absolute.x.clamp(
        pendingDiameter / 2,
        imageSize.width - (pendingDiameter / 2),
      ),
      absolute.y.clamp(pendingTipOffset.dy, imageSize.height),
    );

    return Positioned(
      left: clamped.dx - pendingTipOffset.dx,
      top: clamped.dy - pendingTipOffset.dy,
      child: IgnorePointer(
        child: pendingAvatarBuilder(
          context,
          marker,
          TagProfileTagSpec.avatarSize,
          marker.progress,
        ),
      ),
    );
  }

  String _buildStableCommentKey(TagEntry comment, int index) {
    final commentId = comment.id;
    if (commentId != null) {
      return 'comment_$commentId';
    }

    final userId = comment.actorId;
    final x = comment.anchor?.x.toStringAsFixed(4) ?? 'x';
    final y = comment.anchor?.y.toStringAsFixed(4) ?? 'y';
    return 'comment_${userId}_${x}_${y}_$index';
  }
}
