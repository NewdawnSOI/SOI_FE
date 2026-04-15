import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soi_media_tagger/soi_media_tagger.dart';

import '../../../api/models/comment.dart';
import '../user/current_user_image_builder.dart';
import 'comment_circle_avatar.dart';
import 'model/comment_pending_model.dart';
import 'comment_tag_bubble.dart';
import 'comment_save_payload.dart';

/// 댓글 저장 초안을 드래그 가능한 pending 태그로 보여주고, 드롭 시 앱 어댑터를 통해 서버 저장을 확정합니다.
class CommentProfileTagWidget extends StatefulWidget {
  const CommentProfileTagWidget({
    super.key,
    required this.payload,
    required this.resolveDropRelativePosition,
    required this.dataSource,
    this.onSaveProgress,
    this.onSaveSuccess,
    this.onSaveFailure,
    this.onDropCancelled,
    this.dragData = 'profile_image',
    this.avatarSize = 27,
  });

  final CommentSavePayload payload;
  final FutureOr<Offset?> Function() resolveDropRelativePosition;
  final MediaTagDataSource<Comment, CommentSavePayload> dataSource;
  final ValueChanged<double>? onSaveProgress;
  final ValueChanged<Comment>? onSaveSuccess;
  final ValueChanged<Object>? onSaveFailure;
  final VoidCallback? onDropCancelled;
  final String dragData;
  final double avatarSize;

  @override
  State<CommentProfileTagWidget> createState() =>
      _CommentProfileTagWidgetState();
}

/// pending 태그의 저장 진행률과 드래그 상태를 묶어, 저장 중에도 동일한 아바타 UI를 유지합니다.
class _CommentProfileTagWidgetState extends State<CommentProfileTagWidget> {
  bool _isSaving = false;
  double _progress = 0.0;

  /// 드래그 피드백의 포인터 끝점을 실제 드롭 좌표와 맞춰 pending 태그 이동을 일관되게 유지합니다.
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

      final savedTag = await widget.dataSource.createTag(
        widget.payload.postId.toString(),
        relativePosition,
        widget.payload,
        onProgress: _updateProgress,
      );

      _updateProgress(1.0);
      widget.onSaveSuccess?.call(savedTag.content);
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

  /// 저장 중 진행률과 프로필 이미지를 한 위젯에서 조합해 pending 태그와 완료 직전 모양을 일치시킵니다.
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
