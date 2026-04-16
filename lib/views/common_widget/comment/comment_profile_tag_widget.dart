import 'dart:async';
import 'package:flutter/material.dart';

import '../../../api/models/comment.dart';
import '../../../features/tagging/application/tagging_save_delegate.dart';
import '../user/current_user_image_builder.dart';
import 'comment_circle_avatar.dart';
import 'comment_tag_bubble.dart';
import 'model/comment_pending_model.dart';
import 'comment_save_payload.dart';

/// 댓글 프로필 태그 위젯
/// - 댓글 작성자의 프로필 이미지를 원형으로 보여주는 태그입니다.
/// - 댓글 작성 중인 위치에 드래그하여 배치할 수 있으며, 드래그가 완료되면 댓글 작성이 완료되는 방식으로 동작합니다.
/// - 댓글 작성이 완료되면, 부모 위젯에 댓글 저장 진행 상황과 결과를 전달하는 역할도 수행합니다.
///
/// fields:
/// - [payload]: 댓글 저장에 필요한 정보를 담고 있는 객체입니다. 텍스트 댓글, 음성 댓글, 미디어 댓글 등 다양한 유형의 댓글 저장에 필요한 정보를 포함합니다.
/// - [resolveDropRelativePosition]: 드래그가 완료된 후, 댓글이 작성될 위치의 상대 좌표를 비동기로 조회하는 함수입니다. 댓글이 작성될 위치를 결정하는 데 사용됩니다.
/// - [onSaveProgress]: 댓글 저장 진행 상황이 업데이트될 때 호출되는 콜백 함수입니다. 진행 상황을 0.0 ~ 1.0 사이의 값으로 전달하여, 부모 위젯에서 프로그레스 표시 등에 활용할 수 있도록 합니다.
/// - [onSaveSuccess]: 댓글 저장이 성공적으로 완료되었을 때 호출되는 콜백 함수입니다. 저장된 댓글 객체를 인자로 전달하여, 부모 위젯에서 저장된 댓글 정보를 활용할 수 있도록 합니다.
/// - [onSaveFailure]: 댓글 저장이 실패했을 때 호출되는 콜백 함수입니다. 발생한 오류 객체를 인자로 전달하여, 부모 위젯에서 오류 처리 등을 할 수 있도록 합니다.
/// - [onDropCancelled]: 드래그가 취소되었을 때 호출되는 콜백 함수입니다. 댓글 작성이 취소되었음을 부모 위젯에 알리는 역할을 합니다.
/// - [dragData]: 드래그할 때 전달되는 데이터입니다. 기본값은 'profile_image'입니다.
/// - [avatarSize]: 프로필 태그의 원형 부분의 크기를 결정하는 값입니다. 기본값은 27입니다.
class CommentProfileTagWidget extends StatefulWidget {
  final CommentSavePayload payload;
  final TaggingSaveDelegate saveDelegate;
  final FutureOr<Offset?> Function() resolveDropRelativePosition;
  final ValueChanged<double>? onSaveProgress;
  final ValueChanged<Comment>? onSaveSuccess;
  final ValueChanged<Object>? onSaveFailure;
  final VoidCallback? onDropCancelled;
  final String dragData;
  final double avatarSize;

  const CommentProfileTagWidget({
    super.key,
    required this.payload,
    required this.saveDelegate,
    required this.resolveDropRelativePosition,
    this.onSaveProgress,
    this.onSaveSuccess,
    this.onSaveFailure,
    this.onDropCancelled,
    this.dragData = 'profile_image',
    this.avatarSize = 27,
  });

  @override
  State<CommentProfileTagWidget> createState() =>
      _CommentProfileTagWidgetState();
}

class _CommentProfileTagWidgetState extends State<CommentProfileTagWidget> {
  // 댓글 저장 진행 상태를 나타내는 플래그입니다.
  bool _isSaving = false;

  // 댓글 저장 진행 상황을 0.0 ~ 1.0 사이의 값으로 나타냅니다.
  // 부모 위젯에 전달하여 프로그레스 표시 등에 활용할 수 있습니다.
  double _progress = 0.0;

  /// 드래그 중 pending 태그의 포인터 끝점이 포인터와 맞도록 앵커를 반환합니다.
  ///
  /// Parameters:
  /// - [draggable]: 드래그 가능한 위젯입니다.
  /// - [context]: 빌드 컨텍스트입니다.
  /// - [position]: 드래그 시작 시의 글로벌 위치입니다.
  ///
  /// Returns:
  /// - [Offset]: 드래그 앵커로 사용할 오프셋입니다.
  Offset _tagPointerDragAnchor(
    Draggable<Object> draggable,
    BuildContext context,
    Offset position,
  ) {
    return CommentTagBubble.pointerTipOffset(
      contentSize: widget.avatarSize,
      padding: kPendingCommentTagPadding,
    );
  }

  /// 댓글 저장 진행 상황 업데이트 메서드입니다.
  /// 댓글 저장 진행 상황을 0.0 ~ 1.0 사이의 값으로 업데이트하고, 부모 위젯에 전달하는 역할을 합니다.
  ///
  /// Parameters:
  /// - [value]: 업데이트할 진행 상황 값입니다. 0.0 ~ 1.0 사이의 값으로 전달되어야 합니다.
  void _updateProgress(double value) {
    _progress = value.clamp(0.0, 1.0).toDouble();
    widget.onSaveProgress?.call(_progress);
  }

  Future<void> _handleDropAccepted() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    _updateProgress(0.05);

    try {
      final validationError = widget.payload.validateForSave();
      if (validationError != null) {
        throw StateError(validationError);
      }

      await Future<void>.delayed(Duration.zero);
      final relativePosition = await widget.resolveDropRelativePosition();
      if (relativePosition == null) {
        throw StateError('댓글 위치를 확인하지 못했습니다.');
      }

      final payloadWithLocation = widget.payload.copyWithLocation(
        locationX: relativePosition.dx,
        locationY: relativePosition.dy,
      );

      final savedComment = await widget.saveDelegate.save(
        payload: payloadWithLocation,
        onProgress: _updateProgress,
      );
      _updateProgress(1.0);
      widget.onSaveSuccess?.call(savedComment);
    } catch (error) {
      _updateProgress(0.0);
      widget.onSaveFailure?.call(error);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// 저장 중 원형 progress를 유지하면서 프로필 아바타를 일관된 캐시 정책으로 렌더링합니다.
  Widget _buildAvatar(String? imageUrl, {String? cacheKey}) {
    return SizedBox(
      width: widget.avatarSize,
      height: widget.avatarSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isSaving)
            SizedBox(
              width: widget.avatarSize,
              height: widget.avatarSize,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                backgroundColor: Colors.black.withValues(alpha: 0.3),
              ),
            ),
          CommentCircleAvatar(
            imageUrl: imageUrl,
            size: widget.avatarSize,
            cacheKey: cacheKey,
          ),
        ],
      ),
    );
  }

  /// 드래그용 태그와 저장 중 태그가 같은 크기와 같은 이미지 소스를 공유하도록 현재 표시 상태를 조립합니다.
  @override
  Widget build(BuildContext context) {
    final tagBubble = CommentTagBubble(
      contentSize: widget.avatarSize,
      padding: kPendingCommentTagPadding,
      backgroundColor: kPendingCommentTagBackgroundColor,
      child: CurrentUserImageBuilder(
        imageKind: CurrentUserImageKind.profile,
        targetUserId: widget.payload.userId,
        fallbackImageUrl: widget.payload.profileImageUrl,
        fallbackImageKey: widget.payload.profileImageKey,
        builder: (context, imageUrl, cacheKey) {
          return _buildAvatar(imageUrl, cacheKey: cacheKey);
        },
      ),
    );

    if (_isSaving) {
      return IgnorePointer(child: tagBubble);
    }

    return Draggable<String>(
      data: widget.dragData,
      dragAnchorStrategy: _tagPointerDragAnchor,
      feedback: Transform.scale(
        scale: 1.2,
        child: Opacity(opacity: 0.85, child: tagBubble),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tagBubble),
      onDragEnd: (details) {
        if (!details.wasAccepted) {
          widget.onDropCancelled?.call();
          return;
        }
        unawaited(_handleDropAccepted());
      },
      child: tagBubble,
    );
  }
}
