import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../api/controller/user_controller.dart';
import '../../../../api/models/comment.dart';
import '../../../../utils/position_converter.dart';
import '../user/current_user_image_builder.dart';
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

/// 이미지/비디오 위에 댓글 작성자 프로필 사진을 원형 아바타로 보여주는 오버레이 위젯입니다.
/// - 댓글 작성자의 프로필 이미지를 원형으로 보여주는 태그입니다.
/// - 댓글 작성 중인 위치에 드래그하여 배치할 수 있으며, 드래그가 완료되면 댓글 작성이 완료되는 방식으로 동작합니다.
/// - 댓글 작성이 완료되면, 부모 위젯에 댓글 저장 진행 상황과 결과를 전달하는 역할도 수행합니다.
/// - 또한, 댓글이 작성 중인 위치에 표시할 수 있는 pending 댓글 마커도 포함하고 있습니다.
///   pending 댓글 마커는 음성 댓글 녹음 중이거나 텍스트 댓글 입력 중인 상태에서, 댓글이 작성 중인 위치에 표시할 마커 정보입니다
/// - 부착된 태그와 pending 태그 모두 33x33 외곽, 27x27 아바타 공통 규격을 사용합니다.
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
        if (isShowingComments) ..._buildCommentAvatars(),
        if (pendingMarker != null) _buildPendingMarker(context, pendingMarker!),
      ],
    );
  }

  /// 위치가 있는 댓글만 골라 각 태그 아바타가 현재 사용자 이미지 selector만 구독하게 만듭니다.
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
        kCommentTagAvatarSize,
      );
      final topLeft = ApiPhotoTagGeometryService.tagTopLeftFromTipAnchor(
        clampedSmallTip,
        kCommentTagAvatarSize,
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
            contentSize: kCommentTagAvatarSize,
            child: CurrentUserImageBuilder(
              imageKind: CurrentUserImageKind.profile,
              targetUserId: comment.userId,
              targetUserHandle: comment.nickname,
              fallbackImageUrl: comment.userProfileUrl,
              fallbackImageKey: comment.userProfileKey,
              builder: (context, imageUrl, cacheKey) {
                return CommentCircleAvatar(
                  key: ValueKey<String>('avatar_$key'),
                  imageUrl: imageUrl,
                  size: kCommentTagAvatarSize,
                  showBorder: isSelected,
                  borderColor: Colors.white,
                  cacheKey: cacheKey,
                );
              },
            ),
          ),
        ),
      );
    });
  }

  /// pending 댓글 마커를 동일한 태그 스타일 위에 진행률과 함께 배치합니다.
  Widget _buildPendingMarker(
    BuildContext context,
    PendingApiCommentMarker marker,
  ) {
    final absolute = PositionConverter.toAbsolutePosition(
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
    final pendingTipOffset = CommentTagBubble.pointerTipOffset(
      contentSize: kPendingCommentAvatarSize,
      padding: kPendingCommentTagPadding,
    );
    final pendingDiameter = CommentTagBubble.diameterForContent(
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

    // 태그의 원형 부분의 중심에서 포인터의 끝까지의 오프셋을 계산하여, 마커가 가리키는 위치에 원형 아바타가 정확히 배치되도록 합니다.
    return Positioned(
      left: clamped.dx - pendingTipOffset.dx,
      top: clamped.dy - pendingTipOffset.dy,
      child: IgnorePointer(
        // 진행률 표시 원형 프로그레스 인디케이터와 프로필 이미지 아바타가 겹쳐진 형태로, 진행률이 표시된 원형 아바타를 보여줍니다.
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
