import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../api/controller/media_controller.dart';
import '../../../api/models/comment.dart';
import 'comment_for_pending.dart';
import 'comment_audio_recording_bottom_sheet_widget.dart';
import 'comment_camera_bottom_sheet_widget.dart';
import 'comment_base_bar_widget.dart';
import 'comment_profile_tag_widget.dart';
import 'comment_save_payload.dart';
import 'comment_text_input_widget.dart';

enum _CommentComposerMode { base, typing, placing }

/// 댓글 작성 UI 컴포저 위젯
/// 댓글 입력을 위한 기본 바(base_bar_widget), 텍스트 입력 UI(text_input_widget), 댓글 배치 모드(댓글을 드래그하여 위치를 지정하는 모드)를 포함합니다.
/// 댓글 작성과 관련된 다양한 상호작용과 상태를 관리하며, 댓글 작성 완료 시 필요한 데이터를 부모 위젯에 전달하는 역할을 합니다.
class CommentComposerV2Widget extends StatefulWidget {
  final int postId;
  final Map<int, PendingApiCommentDraft> pendingCommentDrafts;
  final Future<void> Function(int postId, String text) onTextCommentCompleted;
  final Future<void> Function(
    int postId,
    String audioPath,
    List<double> waveformData,
    int durationMs,
  )
  onAudioCommentCompleted;
  final Future<void> Function(int postId, String localFilePath, bool isVideo)
  onMediaCommentCompleted;
  final FutureOr<Offset?> Function(int postId) resolveDropRelativePosition;
  final void Function(int postId, double progress) onCommentSaveProgress;
  final void Function(int postId, Comment comment) onCommentSaveSuccess;
  final void Function(int postId, Object error) onCommentSaveFailure;
  final ValueChanged<bool>? onTextFieldFocusChanged;
  final VoidCallback? onCameraPressed;
  final VoidCallback? onMicPressed;

  const CommentComposerV2Widget({
    super.key,
    required this.postId,
    required this.pendingCommentDrafts,
    required this.onTextCommentCompleted,
    required this.onAudioCommentCompleted,
    required this.onMediaCommentCompleted,
    required this.resolveDropRelativePosition,
    required this.onCommentSaveProgress,
    required this.onCommentSaveSuccess,
    required this.onCommentSaveFailure,
    this.onTextFieldFocusChanged,
    this.onCameraPressed,
    this.onMicPressed,
  });

  @override
  State<CommentComposerV2Widget> createState() =>
      _CommentComposerV2WidgetState();
}

class _CommentComposerV2WidgetState extends State<CommentComposerV2Widget> {
  _CommentComposerMode _mode = _CommentComposerMode.base;

  void _showTyping() {
    setState(() {
      _mode = _CommentComposerMode.typing;
    });
  }

  /// pending draft에 담긴 프로필 source를 즉시 렌더 가능한 URL과 안정적인 key로 분리합니다.
  (String? profileImageUrl, String? profileImageKey) _resolveDraftProfileImage(
    PendingApiCommentDraft draft,
  ) {
    final profileSource = draft.profileImageUrlKey?.trim();
    if (profileSource == null || profileSource.isEmpty) {
      return (null, null);
    }

    final uri = Uri.tryParse(profileSource);
    if (uri != null && uri.hasScheme) {
      return (profileSource, null);
    }

    try {
      final mediaController = context.read<MediaController>();
      return (mediaController.peekPresignedUrl(profileSource), profileSource);
    } catch (_) {
      return (null, profileSource);
    }
  }

  CommentSavePayload? _buildPayloadFromDraft() {
    final draft = widget.pendingCommentDrafts[widget.postId];
    if (draft == null) {
      return null;
    }
    final (profileImageUrl, profileImageKey) = _resolveDraftProfileImage(draft);

    if (draft.isTextComment) {
      return CommentSavePayload(
        postId: widget.postId,
        userId: draft.recorderUserId,
        kind: CommentDraftKind.text,
        text: draft.text,
        profileImageUrl: profileImageUrl,
        profileImageKey: profileImageKey,
      );
    }

    if ((draft.audioPath ?? '').isNotEmpty) {
      return CommentSavePayload(
        postId: widget.postId,
        userId: draft.recorderUserId,
        kind: CommentDraftKind.audio,
        audioPath: draft.audioPath,
        waveformData: draft.waveformData,
        duration: draft.duration,
        profileImageUrl: profileImageUrl,
        profileImageKey: profileImageKey,
      );
    }

    if ((draft.mediaPath ?? '').isNotEmpty) {
      return CommentSavePayload(
        postId: widget.postId,
        userId: draft.recorderUserId,
        kind: draft.isVideo == true
            ? CommentDraftKind.video
            : CommentDraftKind.image,
        localFilePath: draft.mediaPath,
        profileImageUrl: profileImageUrl,
        profileImageKey: profileImageKey,
      );
    }

    return null;
  }

  Future<void> _handleTextSubmit(String text) async {
    await widget.onTextCommentCompleted(widget.postId, text);
    if (!mounted) {
      return;
    }

    setState(() {
      _mode = _CommentComposerMode.placing;
    });
    widget.onTextFieldFocusChanged?.call(false);
  }

  Future<void> _handleCameraPressed() async {
    widget.onCameraPressed?.call();

    final result = await showModalBottomSheet<CommentCameraSheetResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const CommentCameraRecordingBottomSheetWidget(),
    );

    if (!mounted || result == null) {
      return;
    }

    await widget.onMediaCommentCompleted(
      widget.postId,
      result.localFilePath,
      result.isVideo,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _mode = _CommentComposerMode.placing;
    });
    widget.onTextFieldFocusChanged?.call(false);
  }

  Future<void> _handleMicPressed() async {
    widget.onMicPressed?.call();

    final result = await showModalBottomSheet<CommentAudioSheetResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const CommentAudioRecordingBottomSheetWidget(),
    );

    if (!mounted || result == null) {
      return;
    }

    await widget.onAudioCommentCompleted(
      widget.postId,
      result.audioPath,
      result.waveformData,
      result.durationMs,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _mode = _CommentComposerMode.placing;
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
      _mode = _CommentComposerMode.base;
    });
    widget.onTextFieldFocusChanged?.call(false);
  }

  FutureOr<Offset?> _resolveDropPosition() {
    return widget.resolveDropRelativePosition(widget.postId);
  }

  void _handleSaveSuccess(Comment comment) {
    widget.onCommentSaveSuccess(widget.postId, comment);
    if (!mounted) {
      return;
    }
    setState(() {
      _mode = _CommentComposerMode.base;
    });
  }

  void _handleSaveFailure(Object error) {
    widget.onCommentSaveFailure(widget.postId, error);
    if (!mounted) {
      return;
    }
    setState(() {
      _mode = _CommentComposerMode.placing;
    });
  }

  /// 댓글 배치 모드에서 보여줄 위젯을 빌드하는 메서드입니다.
  Widget _buildPlacingMode() {
    // 현재 댓글 작성 중인 댓글의 정보를 기반으로 CommentSavePayload을 생성합니다.
    // 댓글 작성 중인 댓글이 없거나, 지원되지 않는 종류의 댓글인 경우 null이 될 수 있습니다.
    final payload = _buildPayloadFromDraft();

    // payload가 null인 경우는 댓글 작성 중인 댓글이 없거나, 지원되지 않는 종류의 댓글인 경우입니다.
    // 이 경우에는 댓글 작성의 첫 단계인 기본 바 UI를 보여줍니다.
    if (payload == null) {
      return CommentBaseBarWidget(
        onCenterTap: _showTyping,
        onCameraPressed: _handleCameraPressed,
        onMicPressed: _handleMicPressed,
      );
    }

    // 댓글 배치 모드에서 보여줄 위젯은 CommentProfileTagWidget입니다.
    // CommentProfileTagWidget은 댓글 작성자의 프로필 이미지와 함께,
    // 댓글이 드래그되는 위치에 따라 실시간으로 댓글 작성 내용을 미리 보여주는 역할을 합니다.
    return Align(
      alignment: Alignment.center,
      child: CommentProfileTagWidget(
        payload: payload,
        avatarSize: kPendingCommentAvatarSize,
        resolveDropRelativePosition: _resolveDropPosition,
        onSaveProgress: (progress) {
          widget.onCommentSaveProgress(widget.postId, progress);
        },
        onSaveSuccess: _handleSaveSuccess,
        onSaveFailure: _handleSaveFailure,
      ),
    );
  }

  /// 댓글 작성 모드에 맞는 하단 UI를 즉시 교체해 입력 진입 시 불필요한 흔들림을 줄입니다.
  /// _base 모드에서는 댓글 작성의 진입점이 되는 CommentBaseBarWidget을 보여주고,
  /// _typing 모드에서는 CommentTextInputWidget을 보여주며,
  /// _placing 모드에서는 댓글 작성 중인 댓글의 정보를 기반으로 CommentProfileTagWidget을 보여줍니다.
  @override
  Widget build(BuildContext context) {
    late final Widget child;

    switch (_mode) {
      // 기본 모드에서는 댓글 작성의 진입점이 되는 CommentBaseBarWidget을 보여줍니다.
      case _CommentComposerMode.base:
        child = CommentBaseBarWidget(
          onCenterTap: _showTyping,
          onCameraPressed: _handleCameraPressed,
          onMicPressed: _handleMicPressed,
        );
        break;
      // 텍스트 입력 모드에서는 CommentTextInputWidget을 보여줍니다.
      case _CommentComposerMode.typing:
        child = CommentTextInputWidget(
          onSubmitText: _handleTextSubmit,
          onFocusChanged: _handleTextFocusChanged,
          onEditingCancelled: _handleTypingCancelled,
        );
        break;
      // 댓글 배치 모드에서는 댓글 작성 중인 댓글의 정보를 기반으로 CommentProfileTagWidget을 보여줍니다.
      case _CommentComposerMode.placing:
        child = _buildPlacingMode();
        break;
    }
    // 댓글 작성 모드에 따라 보여주는 UI가 즉시 교체되도록 KeyedSubtree로 감싸고, 고유한 key로 모드를 지정합니다.
    // 이렇게 하면 모드가 변경될 때마다 완전히 새로운 위젯 트리가 빌드되어, 입력 진입 시 불필요한 흔들림을 줄일 수 있습니다.
    return Container(
      width: 354,
      height: 52,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: KeyedSubtree(key: ValueKey(_mode.name), child: child),
    );
  }
}
