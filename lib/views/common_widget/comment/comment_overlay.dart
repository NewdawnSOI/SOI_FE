import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:soi_media_tagger/soi_media_tagger.dart';

import '../../../../api/controller/user_controller.dart';
import '../../../../api/models/comment.dart';
import '../photo/services/photo_tag_domain_utils.dart';
import '../user/current_user_image_builder.dart';
import 'comment_circle_avatar.dart';
import 'comment_tag_specs.dart';
import 'model/comment_pending_model.dart';

typedef CommentTapCallback =
    Future<void> Function({
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
  final CommentTapCallback onCommentTap;
  final CommentLongPressCallback onCommentLongPress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (isShowingComments) _buildCommentContainer(),
        if (pendingMarker != null) _buildPendingMarker(context, pendingMarker!),
      ],
    );
  }

  Widget _buildCommentContainer() {
    final filteredComments = comments
        .where((comment) => comment.hasLocation)
        .toList(growable: false);

    final hiddenTagIds = <String>{};
    final tags = <MediaTag<Comment>>[];

    for (var i = 0; i < filteredComments.length; i++) {
        final comment = filteredComments[i];
        final key = _buildStableCommentKey(comment, i);
        final canExpandMedia = PhotoTagDomainUtils.canExpandMediaComment(comment);

        final relative = Offset(
            comment.locationX ?? 0.5,
            comment.locationY ?? 0.5,
        );

        tags.add(
            MediaTag<Comment>(
                id: key,
                relativePosition: relative,
                content: comment,
            ),
        );

        final hideOther = showActionOverlay &&
            selectedCommentKey != null &&
            key != selectedCommentKey;
        final hideExpandedTag = expandedMediaTagKey == key && canExpandMedia;

        if (hideOther || hideExpandedTag) {
            hiddenTagIds.add(key);
        }
    }

    return MediaTagOverlayContainer<Comment>(
        tags: tags,
        imageSize: imageSize,
        selectedTagId: selectedCommentKey,
        hiddenTagIds: hiddenTagIds,
        contentSize: CommentProfileTagSpec.avatarSize,
        padding: CommentProfileTagSpec.padding,
        onTagTap: (tag, anchor) {
            unawaited(
                onCommentTap(
                    comment: tag.content,
                    key: tag.id,
                    tipAnchor: anchor,
                ),
            );
        },
        onTagLongPress: (tag, anchor) {
            onCommentLongPress(
                key: tag.id,
                commentId: tag.content.id,
                position: anchor,
            );
        },
        tagBuilder: (context, tag, isSelected) {
            final comment = tag.content;
            return CurrentUserImageBuilder(
                imageKind: CurrentUserImageKind.profile,
                targetUserId: comment.userId,
                targetUserHandle: comment.nickname,
                fallbackImageUrl: comment.userProfileUrl,
                fallbackImageKey: comment.userProfileKey,
                builder: (context, imageUrl, cacheKey) {
                    return CommentCircleAvatar(
                        key: ValueKey<String>('avatar_${tag.id}'),
                        imageUrl: imageUrl,
                        size: CommentProfileTagSpec.avatarSize,
                        showBorder: isSelected,
                        borderColor: Colors.white,
                        cacheKey: cacheKey,
                    );
                },
            );
        },
    );
  }

  Widget _buildPendingMarker(
    BuildContext context,
    PendingApiCommentMarker marker,
  ) {
    final absolute = RelativePositionConverter.toAbsolutePosition(
      marker.relativePosition,
      imageSize,
    );
    final normalizedMarkerSource = _normalizeKey(marker.profileImageUrlKey);
    final pendingFallbackImageUrl = _isAbsoluteUrl(normalizedMarkerSource)
        ? normalizedMarkerSource
        : null;
    final pendingFallbackImageKey = pendingFallbackImageUrl == null
        ? normalizedMarkerSource
        : null;
    final currentUserId = Provider.of<UserController?>(
      context,
      listen: false,
    )?.currentUserId;
    
    final pendingTipOffset = GenericTagBubble.pointerTipOffset(
      contentSize: kPendingCommentAvatarSize,
      padding: kPendingCommentTagPadding,
    );
    final pendingDiameter = GenericTagBubble.diameterForContent(
      contentSize: kPendingCommentAvatarSize,
      padding: kPendingCommentTagPadding,
    );
    final clamped = Offset(
      absolute.dx.clamp(
        pendingDiameter / 2,
        imageSize.width - (pendingDiameter / 2),
      ),
      absolute.dy.clamp(pendingTipOffset.dy, imageSize.height),
    );

    return Positioned(
      left: clamped.dx - pendingTipOffset.dx,
      top: clamped.dy - pendingTipOffset.dy,
      child: IgnorePointer(
        child: CurrentUserImageBuilder(
          imageKind: CurrentUserImageKind.profile,
          targetUserId: currentUserId,
          fallbackImageUrl: pendingFallbackImageUrl,
          fallbackImageKey: pendingFallbackImageKey,
          builder: (context, imageUrl, cacheKey) {
            return CommentPendingProgressAvatar(
              imageUrl: imageUrl,
              cacheKey: cacheKey,
              size: kPendingCommentAvatarSize,
              progress: marker.progress,
              opacity: 0.85,
              tagPadding: kPendingCommentTagPadding,
              tagBackgroundColor: kPendingCommentTagBackgroundColor,
            );
          },
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
