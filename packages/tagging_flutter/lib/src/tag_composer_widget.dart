import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tagging_core/tagging_core.dart';

import 'tag_base_bar_widget.dart';
import 'tag_profile_drag_widget.dart';
import 'tag_specs.dart';
import 'tag_text_input_widget.dart';

enum _TagComposerMode { base, typing, placing }

/// 기본 바, 텍스트 입력, 드래그 저장 모드를 오가는 태그 컴포저입니다.
class TagComposerWidget extends StatefulWidget {
  const TagComposerWidget({
    super.key,
    required this.scopeId,
    required this.pendingDrafts,
    required this.saveDelegate,
    required this.avatarBuilder,
    required this.resolveDropRelativePosition,
    required this.onTextDraftSubmitted,
    required this.basePlaceholderText,
    required this.textInputHintText,
    required this.cameraIcon,
    required this.micIcon,
    required this.onCommentSaveProgress,
    required this.onCommentSaveSuccess,
    required this.onCommentSaveFailure,
    this.onCameraDraftRequested,
    this.onAudioDraftRequested,
    this.onTextFieldFocusChanged,
    this.avatarSize = TagProfileTagSpec.avatarSize,
  });

  final TagScopeId scopeId;
  final Map<TagScopeId, TagDraft> pendingDrafts;
  final TaggingSaveDelegate saveDelegate;
  final TagPendingAvatarBuilder avatarBuilder;
  final FutureOr<TagPosition?> Function(TagScopeId scopeId)
  resolveDropRelativePosition;
  final Future<void> Function(TagScopeId scopeId, String text)
  onTextDraftSubmitted;
  final Future<bool> Function(TagScopeId scopeId)? onCameraDraftRequested;
  final Future<bool> Function(TagScopeId scopeId)? onAudioDraftRequested;
  final String basePlaceholderText;
  final String textInputHintText;
  final Widget cameraIcon;
  final Widget micIcon;
  final void Function(TagScopeId scopeId, double progress)
  onCommentSaveProgress;
  final void Function(TagScopeId scopeId, TagComment comment)
  onCommentSaveSuccess;
  final void Function(TagScopeId scopeId, Object error) onCommentSaveFailure;
  final ValueChanged<bool>? onTextFieldFocusChanged;
  final double avatarSize;

  @override
  State<TagComposerWidget> createState() => _TagComposerWidgetState();
}

/// 드래프트 종류에 따라 payload를 만들고 모드 전환을 조정합니다.
class _TagComposerWidgetState extends State<TagComposerWidget> {
  _TagComposerMode _mode = _TagComposerMode.base;

  void _showTyping() {
    setState(() {
      _mode = _TagComposerMode.typing;
    });
  }

  (String? profileImageUrl, String? profileImageKey) _splitProfileSource(
    String? profileSource,
  ) {
    final normalized = profileSource?.trim();
    if (normalized == null || normalized.isEmpty) {
      return (null, null);
    }

    final uri = Uri.tryParse(normalized);
    if (uri != null && uri.hasScheme) {
      return (normalized, null);
    }

    return (null, normalized);
  }

  TagSavePayload? _buildPayloadFromDraft() {
    final draft = widget.pendingDrafts[widget.scopeId];
    if (draft == null) {
      return null;
    }
    final (profileImageUrl, profileImageKey) = _splitProfileSource(
      draft.profileImageSource,
    );

    switch (draft.kind) {
      case TagDraftKind.text:
        return TagSavePayload(
          scopeId: widget.scopeId,
          userId: draft.recorderUserId,
          kind: TagDraftKind.text,
          text: draft.text,
          profileImageUrl: profileImageUrl,
          profileImageKey: profileImageKey,
        );
      case TagDraftKind.audio:
        return TagSavePayload(
          scopeId: widget.scopeId,
          userId: draft.recorderUserId,
          kind: TagDraftKind.audio,
          audioPath: draft.audioPath,
          waveformData: draft.waveformData,
          duration: draft.durationMs,
          profileImageUrl: profileImageUrl,
          profileImageKey: profileImageKey,
        );
      case TagDraftKind.image:
      case TagDraftKind.video:
        return TagSavePayload(
          scopeId: widget.scopeId,
          userId: draft.recorderUserId,
          kind: draft.kind,
          localFilePath: draft.mediaPath,
          profileImageUrl: profileImageUrl,
          profileImageKey: profileImageKey,
        );
    }
  }

  Future<void> _handleTextSubmit(String text) async {
    await widget.onTextDraftSubmitted(widget.scopeId, text);
    if (!mounted) {
      return;
    }

    setState(() {
      _mode = _TagComposerMode.placing;
    });
    widget.onTextFieldFocusChanged?.call(false);
  }

  Future<void> _handleCameraPressed() async {
    final accepted = await widget.onCameraDraftRequested?.call(widget.scopeId);
    if (!mounted || accepted != true) {
      return;
    }

    setState(() {
      _mode = _TagComposerMode.placing;
    });
    widget.onTextFieldFocusChanged?.call(false);
  }

  Future<void> _handleMicPressed() async {
    final accepted = await widget.onAudioDraftRequested?.call(widget.scopeId);
    if (!mounted || accepted != true) {
      return;
    }

    setState(() {
      _mode = _TagComposerMode.placing;
    });
    widget.onTextFieldFocusChanged?.call(false);
  }

  void _handleTextFocusChanged(bool isFocused) {
    widget.onTextFieldFocusChanged?.call(isFocused);
  }

  void _handleTypingCancelled() {
    if (!mounted) {
      return;
    }
    setState(() {
      _mode = _TagComposerMode.base;
    });
    widget.onTextFieldFocusChanged?.call(false);
  }

  FutureOr<TagPosition?> _resolveDropPosition() {
    return widget.resolveDropRelativePosition(widget.scopeId);
  }

  void _handleSaveSuccess(TagComment comment) {
    widget.onCommentSaveSuccess(widget.scopeId, comment);
    if (!mounted) {
      return;
    }
    setState(() {
      _mode = _TagComposerMode.base;
    });
  }

  void _handleSaveFailure(Object error) {
    widget.onCommentSaveFailure(widget.scopeId, error);
    if (!mounted) {
      return;
    }
    setState(() {
      _mode = _TagComposerMode.placing;
    });
  }

  Widget _buildPlacingMode() {
    final payload = _buildPayloadFromDraft();
    if (payload == null) {
      return TagBaseBarWidget(
        onCenterTap: _showTyping,
        placeholderText: widget.basePlaceholderText,
        cameraIcon: widget.cameraIcon,
        micIcon: widget.micIcon,
        onCameraPressed: _handleCameraPressed,
        onMicPressed: _handleMicPressed,
      );
    }

    return Align(
      alignment: Alignment.center,
      child: TagProfileDragWidget(
        payload: payload,
        saveDelegate: widget.saveDelegate,
        avatarBuilder: widget.avatarBuilder,
        avatarSize: widget.avatarSize,
        resolveDropRelativePosition: _resolveDropPosition,
        onSaveProgress: (progress) {
          widget.onCommentSaveProgress(widget.scopeId, progress);
        },
        onSaveSuccess: _handleSaveSuccess,
        onSaveFailure: _handleSaveFailure,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    late final Widget child;

    switch (_mode) {
      case _TagComposerMode.base:
        child = TagBaseBarWidget(
          onCenterTap: _showTyping,
          placeholderText: widget.basePlaceholderText,
          cameraIcon: widget.cameraIcon,
          micIcon: widget.micIcon,
          onCameraPressed: _handleCameraPressed,
          onMicPressed: _handleMicPressed,
        );
        break;
      case _TagComposerMode.typing:
        child = TagTextInputWidget(
          onSubmitText: _handleTextSubmit,
          onFocusChanged: _handleTextFocusChanged,
          onEditingCancelled: _handleTypingCancelled,
          hintText: widget.textInputHintText,
        );
        break;
      case _TagComposerMode.placing:
        child = _buildPlacingMode();
        break;
    }

    return SizedBox(
      width: 354,
      height: 52,
      child: KeyedSubtree(key: ValueKey(_mode.name), child: child),
    );
  }
}
