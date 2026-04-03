import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../api/controller/user_controller.dart';
import '../../../../api/models/comment.dart';
import '../../../../utils/position_converter.dart';
import '../../about_comment/comment_for_pending.dart';
import '../../user/current_user_image_builder.dart';
import '../services/photo_tag_geometry_service.dart';
import '../tag_pointer.dart';
import 'photo_circle_avatar.dart';

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

/// 이미지/비디오 위에 댓글 작성자 프로필 사진을 원형 아바타로 보여주는 오버레이 위젯입니다.
/// - 댓글 작성자의 프로필 이미지를 원형으로 보여주는 태그입니다.
/// - 댓글 작성 중인 위치에 드래그하여 배치할 수 있으며, 드래그가 완료되면 댓글 작성이 완료되는 방식으로 동작합니다.
/// - 댓글 작성이 완료되면, 부모 위젯에 댓글 저장 진행 상황과 결과를 전달하는 역할도 수행합니다.
/// - 또한, 댓글이 작성 중인 위치에 표시할 수 있는 pending 댓글 마커도 포함하고 있습니다.
///   pending 댓글 마커는 음성 댓글 녹음 중이거나 텍스트 댓글 입력 중인 상태에서, 댓글이 작성 중인 위치에 표시할 마커 정보입니다
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
            child: CurrentUserImageBuilder(
              imageKind: CurrentUserImageKind.profile,
              targetUserId: comment.userId,
              targetUserHandle: comment.nickname,
              fallbackImageUrl: comment.userProfileUrl,
              fallbackImageKey: comment.userProfileKey,
              builder: (context, imageUrl, cacheKey) {
                return ApiPhotoCircleAvatar(
                  key: ValueKey<String>('avatar_$key'),
                  imageUrl: imageUrl,
                  size: avatarSize,
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

  /// pending 댓글 마커로 사용할 원형 아바타 위젯을 빌드하는 함수입니다.
  /// - 댓글 작성 중인 위치에 드래그하여 배치할 수 있으며, 드래그가 완료되면 댓글 작성이 완료되는 방식으로 동작합니다.
  /// - 댓글 작성이 완료되면, 부모 위젯에 댓글 저장 진행 상황과 결과를 전달하는 역할도 수행합니다.
  ///
  /// parameters:
  /// - [marker]: 댓글 작성 중인 위치에 표시할 마커 정보입니다. 포인터 끝점 기준 상대 좌표와 프로필 이미지 URL 키, 음성 댓글 녹음 진행률 등을 포함합니다.
  ///
  /// returns:
  /// - [Widget]: 댓글 작성 중인 위치에 표시할 원형 아바타 위젯
  Widget _buildPendingMarker(
    BuildContext context,
    PendingApiCommentMarker marker,
  ) {
    // 마커의 상대 좌표를 이미지 크기에 맞게 절대 좌표로 변환합니다.
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
    final pendingTipOffset = TagBubble.pointerTipOffset(
      contentSize: kPendingCommentAvatarSize,
      padding: kPendingCommentTagPadding,
    );
    final pendingDiameter = TagBubble.diameterForContent(
      contentSize: kPendingCommentAvatarSize,
      padding: kPendingCommentTagPadding,
    );
    // 마커의 절대 좌표를 pending 태그 외곽 크기에 맞게 클램핑하여, 화면 밖으로 벗어나지 않도록 합니다.
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
            return ApiPhotoPendingProgressAvatar(
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
