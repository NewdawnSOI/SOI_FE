import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tagging_core/tagging_core.dart';

import 'tag_bubble.dart';
import 'tag_specs.dart';

typedef TagDragHandleBuilder =
    Widget Function(BuildContext context, TagSaveRequest request, double size);

/// 저장 전 pending 태그를 드래그하고 drop 이후 generic mutation port에 저장을 위임합니다.
class TagDragHandle extends StatefulWidget {
  const TagDragHandle({
    super.key,
    required this.request,
    required this.mutationPort,
    required this.handleBuilder,
    required this.resolveDropRelativePosition,
    this.onSaveProgress,
    this.onSaveSuccess,
    this.onSaveFailure,
    this.onDropCancelled,
    this.dragData = 'tag_entry',
    this.avatarSize = TagProfileTagSpec.avatarSize,
    this.tagPadding = TagProfileTagSpec.padding,
    this.tagBackgroundColor = const Color(0xFF595959),
  });

  final TagSaveRequest request;
  final TagMutationPort mutationPort;
  final TagDragHandleBuilder handleBuilder;
  final FutureOr<TagPosition?> Function() resolveDropRelativePosition;
  final ValueChanged<double>? onSaveProgress;
  final ValueChanged<TagEntry>? onSaveSuccess;
  final ValueChanged<Object>? onSaveFailure;
  final VoidCallback? onDropCancelled;
  final String dragData;
  final double avatarSize;
  final double tagPadding;
  final Color tagBackgroundColor;

  @override
  State<TagDragHandle> createState() => _TagDragHandleState();
}

/// 드래그 앵커와 저장 진행률을 묶어 drop-then-save 흐름을 안정적으로 유지합니다.
class _TagDragHandleState extends State<TagDragHandle> {
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
      await Future<void>.delayed(Duration.zero);
      final relativePosition = await widget.resolveDropRelativePosition();
      if (relativePosition == null) {
        throw StateError('tag anchor is unavailable');
      }

      final requestWithAnchor = widget.request.copyWithAnchor(relativePosition);
      final validationError = requestWithAnchor.validateForSave();
      if (validationError != null) {
        throw StateError(validationError.name);
      }

      final saved = await widget.mutationPort.save(
        request: requestWithAnchor,
        onProgress: _updateProgress,
      );
      _updateProgress(1.0);
      widget.onSaveSuccess?.call(saved.entry);
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

  Widget _buildHandle() {
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
          widget.handleBuilder(context, widget.request, widget.avatarSize),
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
      child: _buildHandle(),
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
