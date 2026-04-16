import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tagging_core/tagging_core.dart';

import 'tag_bubble.dart';
import 'tag_specs.dart';

typedef TagPendingAvatarBuilder =
    Widget Function(BuildContext context, TagSavePayload payload, double size);

/// 저장 전 pending 태그를 드래그하고 drop 이후 저장까지 이어주는 위젯입니다.
class TagProfileDragWidget extends StatefulWidget {
  const TagProfileDragWidget({
    super.key,
    required this.payload,
    required this.saveDelegate,
    required this.avatarBuilder,
    required this.resolveDropRelativePosition,
    this.onSaveProgress,
    this.onSaveSuccess,
    this.onSaveFailure,
    this.onDropCancelled,
    this.dragData = 'profile_image',
    this.avatarSize = TagProfileTagSpec.avatarSize,
    this.tagPadding = TagProfileTagSpec.padding,
    this.tagBackgroundColor = const Color(0xFF595959),
  });

  final TagSavePayload payload;
  final TaggingSaveDelegate saveDelegate;
  final TagPendingAvatarBuilder avatarBuilder;
  final FutureOr<TagPosition?> Function() resolveDropRelativePosition;
  final ValueChanged<double>? onSaveProgress;
  final ValueChanged<TagComment>? onSaveSuccess;
  final ValueChanged<Object>? onSaveFailure;
  final VoidCallback? onDropCancelled;
  final String dragData;
  final double avatarSize;
  final double tagPadding;
  final Color tagBackgroundColor;

  @override
  State<TagProfileDragWidget> createState() => _TagProfileDragWidgetState();
}

/// 드래그 앵커와 저장 진행률 상태를 일관되게 유지합니다.
class _TagProfileDragWidgetState extends State<TagProfileDragWidget> {
  bool _isSaving = false;
  double _progress = 0.0;

  Offset _tagPointerDragAnchor(
    Draggable<Object> draggable,
    BuildContext context,
    Offset position,
  ) {
    return TagBubble.pointerTipOffset(
      contentSize: widget.avatarSize,
      padding: widget.tagPadding,
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

      final payloadWithLocation = widget.payload.copyWithLocation(
        relativePosition,
      );

      final saved = await widget.saveDelegate.save(
        payload: payloadWithLocation,
        onProgress: _updateProgress,
      );
      _updateProgress(1.0);
      widget.onSaveSuccess?.call(saved.comment);
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

  Widget _buildAvatar() {
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
          widget.avatarBuilder(context, widget.payload, widget.avatarSize),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tagBubble = TagBubble(
      contentSize: widget.avatarSize,
      padding: widget.tagPadding,
      backgroundColor: widget.tagBackgroundColor,
      child: _buildAvatar(),
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
