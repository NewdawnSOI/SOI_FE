import 'dart:async';

import 'package:flutter/material.dart';

import '../../controller/media_tag_workspace_controller.dart';
import '../../interfaces/media_tag_input_delegate.dart';
import '../../models/media_tag.dart';
import '../generic_tag_bubble.dart';
import '../media_tag_action_bar.dart';
import '../media_tag_overlay_container.dart';
import '../media_tag_text_input_bar.dart';

/// 호스트가 기본 액션 바를 교체하면서도 같은 입력 이벤트 계약을 재사용할 수 있게 합니다.
typedef MediaTagComposerBuilder = Widget Function(
  BuildContext context,
  Future<void> Function(MediaTagComposerAction action) handleAction,
);

/// 호스트가 typing 단계의 텍스트 입력 UI를 교체하되 제출/취소 계약은 유지할 수 있게 합니다.
typedef MediaTagTextComposerBuilder = Widget Function(
  BuildContext context,
  Future<void> Function(String text) submitText,
  VoidCallback cancelTyping,
);

/// pending 태그의 드래그 앵커를 호스트 시각 규칙에 맞춰 계산해 드롭 좌표를 복원합니다.
typedef MediaTagPendingAnchorBuilder<DRAFT> = Offset Function(DRAFT draft);

/// 드래그 타깃이 드롭 시점에 같은 앵커를 복원할 수 있도록 pending 태그 메타데이터를 묶어 전달합니다.
class _PendingTagDragData<DRAFT> {
  const _PendingTagDragData({
    required this.draft,
    required this.anchorOffset,
  });

  final DRAFT draft;
  final Offset anchorOffset;
}

/// 태그 오버레이, pending 마커, 입력 진입 바를 한 화면에서 조립하는 호스트용 워크스페이스입니다.
class MediaTaggerWorkspace<T, DRAFT> extends StatefulWidget {
  final MediaTaggerWorkspaceController<T, DRAFT> controller;
  final MediaTagInputDelegate<DRAFT> inputDelegate;

  /// 화면 맨 밑에 깔릴 대상 미디어 (예: 사진, 동영상 플레이어)
  final Widget backgroundMedia;

  /// 확정된 일반 태그들을 어떤 모양으로 그릴지 결정
  final Widget Function(BuildContext, MediaTag<T>, bool isSelected) tagBuilder;

  /// 작성 중인(드래그 중인) 임시 마커를 어떤 모양으로 그릴지 결정
  /// progress: 컨트롤러가 saving 상태일 때 0.0 ~ 1.0 등의 값(혹은 빙글이) 처리를 위해 사용할 수 있음
  final Widget Function(BuildContext, DRAFT, double progress)?
      pendingMarkerBuilder;
  final MediaTagComposerBuilder? composerBuilder;
  final MediaTagTextComposerBuilder? textComposerBuilder;
  final MediaTagPendingAnchorBuilder<DRAFT>? pendingAnchorBuilder;
  final void Function(MediaTag<T> tag, Offset anchor)? onTagTap;
  final void Function(MediaTag<T> tag, Offset anchor)? onTagLongPress;
  final String? selectedTagId;
  final Set<String> hiddenTagIds;
  final bool fetchOnInit;

  final Size mediaSize;

  const MediaTaggerWorkspace({
    super.key,
    required this.controller,
    required this.inputDelegate,
    required this.backgroundMedia,
    required this.tagBuilder,
    required this.mediaSize,
    this.pendingMarkerBuilder,
    this.composerBuilder,
    this.textComposerBuilder,
    this.pendingAnchorBuilder,
    this.onTagTap,
    this.onTagLongPress,
    this.selectedTagId,
    this.hiddenTagIds = const {},
    this.fetchOnInit = true,
  });

  @override
  State<MediaTaggerWorkspace<T, DRAFT>> createState() =>
      _MediaTaggerWorkspaceState<T, DRAFT>();
}

/// workspace의 입력 단계와 드래그-드롭 저장 흐름을 한 곳에서 조립합니다.
class _MediaTaggerWorkspaceState<T, DRAFT>
    extends State<MediaTaggerWorkspace<T, DRAFT>> {
  MediaTagComposerMode _composerMode = MediaTagComposerMode.base;

  @override
  void initState() {
    super.initState();
    if (widget.fetchOnInit) {
      unawaited(widget.controller.fetchTags());
    }
  }

  /// 입력 액션을 호스트 델리게이트에 위임해 draft를 만든 뒤 배치 모드로 전환합니다.
  Future<void> _handleComposerAction(MediaTagComposerAction action) async {
    switch (action) {
      case MediaTagComposerAction.text:
        if (!mounted) {
          return;
        }
        setState(() {
          _composerMode = MediaTagComposerMode.typing;
        });
        return;
      case MediaTagComposerAction.camera:
        await _startDraftCreation(
          () => widget.inputDelegate.createCameraDraft(context),
        );
        break;
      case MediaTagComposerAction.mic:
        await _startDraftCreation(
          () => widget.inputDelegate.createMicDraft(context),
        );
        break;
    }
  }

  /// 입력 델리게이트가 만든 draft를 받아 placing 단계로 올리고 composer를 base 상태로 되돌립니다.
  Future<void> _startDraftCreation(Future<DRAFT?> Function() createDraft) async {
    final draft = await createDraft();
    if (!mounted || draft == null) {
      return;
    }

    setState(() {
      _composerMode = MediaTagComposerMode.base;
    });
    widget.controller.startPlacing(draft);
  }

  /// 기본 typing 입력을 제출하면 텍스트를 draft로 변환하고 이후 흐름은 placing 단계로 넘깁니다.
  Future<void> _handleTextSubmitted(String text) async {
    await _startDraftCreation(
      () => widget.inputDelegate.createTextDraft(context, text),
    );
  }

  Future<void> _commitPendingTag() async {
    try {
      await widget.controller.commitPendingTag();
    } catch (_) {
      // 에러는 controller.lastError로 호스트가 읽을 수 있게 유지합니다.
    }
  }

  /// 기본 pending 태그와 동일한 기준으로 드래그 앵커를 계산해 드롭 좌표와 저장 좌표를 일치시킵니다.
  Offset _resolvePendingAnchor(DRAFT draft) {
    return widget.pendingAnchorBuilder?.call(draft) ??
        GenericTagBubble.pointerTipOffset(contentSize: 40);
  }

  /// 드롭 시 글로벌 좌표를 현재 미디어 프레임의 상대 좌표로 환산해 저장 위치를 확정합니다.
  Future<void> _handlePendingAccepted(
    DragTargetDetails<_PendingTagDragData<DRAFT>> details,
    BuildContext surfaceContext,
  ) async {
    if (widget.controller.mode != TaggerWorkspaceMode.placing) {
      return;
    }

    final renderBox = surfaceContext.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }

    final localPosition = renderBox.globalToLocal(details.offset);
    final anchoredPosition = localPosition + details.data.anchorOffset;
    final relativePosition = Offset(
      (anchoredPosition.dx / widget.mediaSize.width).clamp(0.0, 1.0),
      (anchoredPosition.dy / widget.mediaSize.height).clamp(0.0, 1.0),
    );

    widget.controller.confirmPendingPosition(relativePosition);
    await _commitPendingTag();
  }

  /// 기본 composer는 base/typing UI를 패키지 내부에서 제공하되, 호스트가 단계별로 바꿔 끼울 수 있게 유지합니다.
  Widget _buildComposerContent() {
    switch (_composerMode) {
      case MediaTagComposerMode.base:
        if (widget.composerBuilder != null) {
          return widget.composerBuilder!(context, _handleComposerAction);
        }
        return MediaTagActionBar(onAction: _handleComposerAction);
      case MediaTagComposerMode.typing:
        if (widget.textComposerBuilder != null) {
          return widget.textComposerBuilder!(
            context,
            _handleTextSubmitted,
            _cancelTyping,
          );
        }
        return MediaTagTextInputBar(
          onSubmitText: _handleTextSubmitted,
          onEditingCancelled: _cancelTyping,
        );
    }
  }

  void _cancelTyping() {
    if (!mounted) {
      return;
    }
    setState(() {
      _composerMode = MediaTagComposerMode.base;
    });
  }

  /// pending draft를 현재 진행률과 함께 재사용 가능한 하나의 시각 요소로 조립합니다.
  Widget _buildPendingVisual(
    BuildContext context,
    DRAFT draft,
    double progress,
  ) {
    if (widget.pendingMarkerBuilder != null) {
      return widget.pendingMarkerBuilder!(context, draft, progress);
    }

    return GenericTagBubble(
      contentSize: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (progress > 0 && progress < 1)
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                backgroundColor: Colors.black.withValues(alpha: 0.25),
              ),
            ),
          const CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  /// 저장 중이거나 실패 뒤 위치가 남아 있는 pending draft를 미디어 위에 그대로 표시합니다.
  Widget _buildPendingSurfaceMarker() {
    final pos = widget.controller.pendingPosition;
    final draft = widget.controller.pendingDraft;
    if (pos == null || draft == null) return const SizedBox.shrink();

    final absoluteX = pos.dx * widget.mediaSize.width;
    final absoluteY = pos.dy * widget.mediaSize.height;

    final progress = widget.controller.pendingProgress ?? 0.0;
    final anchorOffset = _resolvePendingAnchor(draft);
    final visual = _buildPendingVisual(context, draft, progress);

    return Positioned(
      left: absoluteX - anchorOffset.dx,
      top: absoluteY - anchorOffset.dy,
      child: IgnorePointer(child: visual),
    );
  }

  /// placing 단계에서는 하단의 pending 태그를 Draggable로 노출해 SOI와 같은 드래그-드롭 흐름을 만듭니다.
  Widget _buildBottomOverlay() {
    late final Widget child;

    if (widget.controller.mode == TaggerWorkspaceMode.placing) {
      final draft = widget.controller.pendingDraft;
      if (draft == null) {
        return const SizedBox.shrink();
      }

      final anchorOffset = _resolvePendingAnchor(draft);
      final visual = _buildPendingVisual(context, draft, 0.0);
      child = Align(
        alignment: Alignment.center,
        child: Draggable<_PendingTagDragData<DRAFT>>(
          data: _PendingTagDragData<DRAFT>(
            draft: draft,
            anchorOffset: anchorOffset,
          ),
          dragAnchorStrategy: (_, __, ___) => anchorOffset,
          feedback: Transform.scale(
            scale: 1.2,
            child: Opacity(opacity: 0.85, child: visual),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: visual),
          onDragEnd: (details) {
            if (!details.wasAccepted) {
              widget.controller.cancelPlacing();
            }
          },
          child: visual,
        ),
      );
    } else {
      child = _buildComposerContent();
    }

    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return Builder(
          builder: (surfaceContext) {
            return DragTarget<_PendingTagDragData<DRAFT>>(
              onWillAcceptWithDetails: (_) =>
                  widget.controller.mode == TaggerWorkspaceMode.placing,
              onAcceptWithDetails: (details) {
                unawaited(_handlePendingAccepted(details, surfaceContext));
              },
              builder: (context, candidateData, rejectedData) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Background Media
                    SizedBox.fromSize(
                      size: widget.mediaSize,
                      child: widget.backgroundMedia,
                    ),

                    // 2. Existing Tags Layer
                    MediaTagOverlayContainer<T>(
                      tags: widget.controller.tags,
                      imageSize: widget.mediaSize,
                      tagBuilder: widget.tagBuilder,
                      selectedTagId: widget.selectedTagId,
                      hiddenTagIds: widget.hiddenTagIds,
                      onTagTap: widget.onTagTap,
                      onTagLongPress: widget.onTagLongPress,
                    ),

                    // 3. Pending Tag Layer
                    if (widget.controller.pendingPosition != null &&
                        (widget.controller.mode == TaggerWorkspaceMode.placing ||
                            widget.controller.mode == TaggerWorkspaceMode.saving))
                      _buildPendingSurfaceMarker(),

                    // 4. Bottom Composer / Pending Drag Layer
                    if (widget.controller.mode != TaggerWorkspaceMode.saving)
                      _buildBottomOverlay(),

                    // 5. Initial Loading Overlay
                    if (widget.controller.mode ==
                        TaggerWorkspaceMode.initialLoading)
                      const Positioned.fill(
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
