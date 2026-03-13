import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../api/models/post.dart';
import '../../../api/models/comment.dart';
import '../../../api/controller/audio_controller.dart';
import '../../../utils/analytics_service.dart';
import 'api_photo_display_widget.dart';
import 'api_user_info_widget.dart';
import '../about_comment/comment_composer_v2_widget.dart';
import '../about_comment/comment_media_tag_preview_widget.dart';
import '../about_comment/api_voice_comment_list_sheet.dart';
import '../about_comment/pending_api_voice_comment.dart';
import '../report/report_bottom_sheet.dart';
import 'tag_pointer.dart';

/// 사진 카드 위젯
/// 사진과 관련된 정보(작성자, 작성 날짜 등)를 표시하고, 댓글 작성과 댓글 태그 기능을 포함하는 위젯입니다.
/// 댓글 태그가 확장될 때, 해당 태그의 내용을 보여주는 오버레이를 관리하는 기능도 포함합니다.
/// 사진 카드 위젯은 피드 페이지, 아카이브 상세 페이지, 카테고리 페이지 등에서 사용될 수 있다.
///
/// Parameters:
/// - [post]: 표시할 게시물 데이터
/// - [categoryName]: 게시물이 속한 카테고리 이름 (댓글 태그에 표시하기 위함)
/// - [categoryId]: 게시물이 속한 카테고리 ID (댓글 태그 저장 시 필요)
/// - [index]: 피드 내에서의 게시물 순서 (댓글 태그 저장 시 필요)
/// - [isOwner]: 현재 사용자가 게시물 작성자인지 여부 (삭제 버튼 표시 여부 결정)
/// - [isArchive]: 아카이브 상세 페이지에서 사용되는지 여부 (댓글 태그 저장 시 surface 구분)
/// - [isCategory]: 카테고리 페이지에서 사용되는지 여부 (댓글 태그 저장 시 surface 구분)
/// - [isFromCamera]: 카메라에서 바로 게시된 사진인지 여부 (댓글 태그 저장 시 surface 구분)
/// - [selectedEmoji]: 현재 게시물에 선택된 이모지 (댓글 태그에 표시하기 위함)
/// - [onEmojiSelected]: 이모지 선택이 변경될 때 호출되는 콜백 (부모 위젯에서 선택된 이모지를 관리하기 위함)
/// - [onReportSubmitted]: 신고 제출이 완료되었을 때 호출되는 콜백 (신고 결과를 부모 위젯에서 처리하기 위함)
/// - [postComments]: 게시물 ID별 댓글 리스트 (댓글 태그와 댓글 리스트 표시를 위해 필요)
/// - [pendingCommentDrafts]: 게시물 ID별 댓글 작성 중인 드래프트 (댓글 태그의 콘텐츠 유형 판단과 댓글 작성 UI에 필요)
/// - [pendingVoiceComments]: 게시물 ID별 음성 댓글 작성 중인 드래프트 (댓글 태그의 콘텐츠 유형 판단과 음성 댓글 작성 UI에 필요)
/// - [onToggleAudio]: 게시물의 음성 댓글 재생/일시정지 토글 시 호출되는 콜백 (음성 댓글 UI와 상호작용하기 위함)
/// - [onTextCommentCompleted]: 텍스트 댓글 작성이 완료되었을 때 호출되는 콜백 (댓글 작성 UI와 상호작용하기 위함)
/// - [onAudioCommentCompleted]: 음성 댓글 작성이 완료되었을 때 호출되는 콜백 (댓글 작성 UI와 상호작용하기 위함)
/// - [onMediaCommentCompleted]: 미디어 댓글 작성이 완료되었을 때 호출되는 콜백 (댓글 작성 UI와 상호작용하기 위함)
/// - [onProfileImageDragged]: 프로필 이미지를 드래그하여 댓글 태그 위치를 지정할 때 호출되는 콜백 (댓글 태그 위치 지정과 상호작용하기 위함)
/// - [onCommentSaveProgress]: 댓글 저장 진행 상황이 업데이트될 때 호출되는 콜백 (댓글 작성 UI에서 저장 진행 상황 표시하기 위함)
/// - [onCommentSaveSuccess]: 댓글이 성공적으로 저장되었을 때 호출되는 콜백 (댓글 작성 UI에서 저장 성공 처리하기 위함)
/// - [onCommentSaveFailure]: 댓글 저장이 실패했을 때 호출되는 콜백 (댓글 작성 UI에서 저장 실패 처리하기 위함)
/// - [onDeletePressed]: 게시물 삭제 버튼이 눌렸을 때 호출되는 콜백 (게시물 삭제 처리하기 위함)
/// - [onCommentsReloadRequested]: 댓글 리스트를 새로고침해야 할 때 호출되는 콜백 (댓글 리스트 새로고침 처리하기 위함)
class ApiPhotoCardWidget extends StatefulWidget {
  final Post post;
  final String categoryName;
  final int categoryId;
  final int index;
  final bool isOwner;
  final bool isArchive;
  final bool isCategory;
  final bool isFromCamera;

  // postId별 선택된 이모지 (부모가 관리)
  final String? selectedEmoji;
  final ValueChanged<String?>? onEmojiSelected; // 부모 캐시 갱신 콜백
  final Future<void> Function(Post post, ReportResult result)?
  onReportSubmitted;

  // 상태 관리 관련
  final Map<int, List<Comment>> postComments;
  final Map<int, PendingApiCommentDraft> pendingCommentDrafts;
  final Map<int, PendingApiCommentMarker> pendingVoiceComments;

  // 콜백 함수들
  final Function(Post) onToggleAudio;
  final Function(int, String) onTextCommentCompleted;
  final Future<void> Function(
    int postId,
    String audioPath,
    List<double> waveformData,
    int durationMs,
  )
  onAudioCommentCompleted;
  final Future<void> Function(int postId, String localFilePath, bool isVideo)
  onMediaCommentCompleted;
  final Function(int, Offset) onProfileImageDragged;
  final void Function(int, double) onCommentSaveProgress;
  final void Function(int, Comment) onCommentSaveSuccess;
  final void Function(int, Object) onCommentSaveFailure;
  final VoidCallback onDeletePressed;
  final Future<void> Function(int postId)? onCommentsReloadRequested;

  const ApiPhotoCardWidget({
    super.key,
    required this.post,
    required this.categoryName,
    required this.categoryId,
    required this.index,
    required this.isOwner,
    this.isArchive = false,
    this.isCategory = false,
    this.isFromCamera = false,
    this.selectedEmoji,
    this.onEmojiSelected,
    this.onReportSubmitted,
    required this.postComments,
    required this.pendingCommentDrafts,
    this.pendingVoiceComments = const {},
    required this.onToggleAudio,
    required this.onTextCommentCompleted,
    required this.onAudioCommentCompleted,
    required this.onMediaCommentCompleted,
    required this.onProfileImageDragged,
    required this.onCommentSaveProgress,
    required this.onCommentSaveSuccess,
    required this.onCommentSaveFailure,
    required this.onDeletePressed,
    this.onCommentsReloadRequested,
  });

  @override
  State<ApiPhotoCardWidget> createState() => _ApiPhotoCardWidgetState();
}

class _ApiPhotoCardWidgetState extends State<ApiPhotoCardWidget>
    with SingleTickerProviderStateMixin {
  static const Duration _kOverlayExpandDuration = Duration(milliseconds: 220);
  static const Curve _kOverlayExpandCurve = Curves.easeOutCubic;

  bool _isTextFieldFocused = false;
  ExpandedMediaTagOverlayData? _expandedOverlayData;
  OverlayEntry? _expandedOverlayEntry;
  late final AnimationController _overlayExpandController;
  late final Animation<double> _overlayExpandAnimation;

  Future<void> _handleTextCommentCreated(String text) async {
    await widget.onTextCommentCompleted(widget.post.id, text);
  }

  String _currentTagContentType() {
    final draft = widget.pendingCommentDrafts[widget.post.id];
    if (draft == null) {
      return 'unknown';
    }

    if (draft.isTextComment) {
      return 'text';
    }

    if ((draft.audioPath ?? '').isNotEmpty) {
      return 'audio';
    }

    if ((draft.mediaPath ?? '').isNotEmpty) {
      return draft.isVideo == true ? 'video' : 'image';
    }

    return 'unknown';
  }

  Future<void> _trackCommentTagSaved({
    required Comment comment,
    required int existingTagCountBefore,
  }) async {
    try {
      final analytics = context.read<AnalyticsService>();
      final properties = <String, dynamic>{
        'post_id': widget.post.id,
        'category_id': widget.categoryId,
        'surface': widget.isArchive ? 'archive_detail' : 'feed_home',
        'tag_content_type': _currentTagContentType(),
        'existing_tag_count_before': existingTagCountBefore,
        'existing_tag_count_after': existingTagCountBefore + 1,
      };

      if (comment.id != null) {
        properties['comment_id'] = comment.id;
      }

      await analytics.track('comment_tag_saved', properties: properties);
      if (kDebugMode) {
        analytics.flush();
      }
    } catch (error) {
      debugPrint('Mixpanel comment_tag_saved tracking failed: $error');
    }
  }

  Offset? _resolveDropRelativePosition(int postId) {
    return widget.pendingVoiceComments[postId]?.relativePosition;
  }

  @override
  void initState() {
    super.initState();
    _overlayExpandController = AnimationController(
      vsync: this,
      duration: _kOverlayExpandDuration,
    );
    _overlayExpandAnimation = CurvedAnimation(
      parent: _overlayExpandController,
      curve: _kOverlayExpandCurve,
    );
  }

  @override
  void didUpdateWidget(covariant ApiPhotoCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _removeExpandedMediaOverlay();
    }
  }

  @override
  void deactivate() {
    _removeExpandedMediaOverlay();
    super.deactivate();
  }

  @override
  void dispose() {
    _removeExpandedMediaOverlay();
    _overlayExpandController.dispose();
    super.dispose();
  }

  // 미디어 댓글이 확장 가능한지 여부를 판단하는 메서드
  void _removeExpandedMediaOverlay() {
    _overlayExpandController.stop();
    _overlayExpandController.reset();
    _expandedOverlayEntry?.remove();
    _expandedOverlayEntry = null;
    _expandedOverlayData = null;
  }

  // 미디어 댓글이 확장 가능한지 여부를 판단하는 메서드
  void _handleExpandedMediaOverlayChanged(ExpandedMediaTagOverlayData? data) {
    if (!mounted) return;
    if (data == null) {
      _removeExpandedMediaOverlay();
      return;
    }

    _expandedOverlayData = data;

    final overlay = Overlay.of(context, rootOverlay: true); // 최상위 Overlay

    if (_expandedOverlayEntry == null) {
      _expandedOverlayEntry = OverlayEntry(
        builder: _buildExpandedMediaOverlayEntry,
      );
      overlay.insert(_expandedOverlayEntry!);
    }
    _expandedOverlayEntry!.markNeedsBuild();
    _overlayExpandController.forward(from: 0.0);
  }

  Widget _buildExpandedMediaOverlayEntry(BuildContext overlayContext) {
    final data = _expandedOverlayData;
    if (data == null) return const SizedBox.shrink();

    final mediaQuery = MediaQuery.of(overlayContext);
    final screenSize = mediaQuery.size;
    final safePadding = mediaQuery.padding;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: data.onDismiss,
              child: const SizedBox.expand(),
            ),
          ),
          AnimatedBuilder(
            animation: _overlayExpandAnimation,
            builder: (_, __) {
              final progress = _overlayExpandAnimation.value;
              final contentSize =
                  data.collapsedContentSize +
                  ((data.expandedContentSize - data.collapsedContentSize) *
                      progress);
              final diameter = TagBubble.diameterForContent(
                contentSize: contentSize,
              );
              final totalHeight = TagBubble.totalHeightForContent(
                contentSize: contentSize,
              );
              final topLeft = Offset(
                data.globalCircleCenter.dx - (diameter / 2),
                data.globalCircleCenter.dy - (diameter / 2),
              );

              final clampedLeft = topLeft.dx.clamp(
                0.0,
                (screenSize.width - diameter).clamp(0.0, double.infinity),
              );
              final maxTop = (screenSize.height - totalHeight).clamp(
                0.0,
                double.infinity,
              );
              final minTop = safePadding.top.clamp(0.0, maxTop);
              final clampedTop = topLeft.dy.clamp(minTop, maxTop);

              return Positioned(
                left: clampedLeft,
                top: clampedTop,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: data.onDismiss,
                  onLongPress: data.onLongPress,
                  child: TagBubble(
                    contentSize: contentSize,
                    child: CommentMediaTagPreviewWidget(
                      key: ValueKey('overlay_media_${data.tagKey}'),
                      comment: data.comment,
                      size: contentSize,
                      autoplayVideo: true,
                      playWithSound: true,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = _isTextFieldFocused;
    final bottomPadding = isKeyboardVisible
        ? 10.0
        : (widget.isCategory ? 55.0 : 10.0);

    return VisibilityDetector(
      key: ValueKey('api_photo_card_${widget.post.id}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction < 0.55 && _expandedOverlayEntry != null) {
          _removeExpandedMediaOverlay();
        }
      },
      child: Stack(
        clipBehavior: Clip.none, // 오버레이와 하단 코멘트 컴포저 레이어를 유지
        children: [
          SingleChildScrollView(
            clipBehavior: Clip.none,
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 피드 페이지에 SOI Appbar를 표시하지 않는 경우를 대비한 공간 확보
                // if (!widget.isArchive) SizedBox(height: 90.h),

                // 사진 표시 위젯
                ApiPhotoDisplayWidget(
                  key: ValueKey(widget.post.id),
                  post: widget.post,
                  categoryId: widget.categoryId,
                  categoryName: widget.categoryName,
                  isArchive: widget.isArchive,
                  isFromCamera: widget.isFromCamera,
                  postComments: widget.postComments,
                  onProfileImageDragged: widget.onProfileImageDragged,
                  onToggleAudio: widget.onToggleAudio,
                  pendingVoiceComments: widget.pendingVoiceComments,
                  onCommentsReloadRequested: widget.onCommentsReloadRequested,
                  onExpandedMediaOverlayChanged:
                      _handleExpandedMediaOverlayChanged,
                ),
                SizedBox(height: 12.h),

                // 사용자 정보 위젯 (아이디와 날짜)
                ApiUserInfoWidget(
                  post: widget.post,
                  isCurrentUserPost: widget.isOwner,
                  onDeletePressed: widget.onDeletePressed,
                  onReportSubmitted: widget.onReportSubmitted == null
                      ? null
                      : (result) =>
                            widget.onReportSubmitted!(widget.post, result),
                  onCommentPressed: () {
                    // 댓글 리스트 Bottom Sheet 표시
                    final comments = widget.postComments[widget.post.id] ?? [];
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) {
                        return ChangeNotifierProvider(
                          create: (_) => AudioController(),
                          child: ApiVoiceCommentListSheet(
                            postId: widget.post.id,
                            comments: comments,
                            onCommentsUpdated: (updatedComments) {
                              if (!mounted) return;
                              setState(() {
                                widget.postComments[widget.post.id] =
                                    updatedComments;
                              });
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
                SizedBox(height: 10.h),

                // 음성 녹음 위젯을 위한 공간 확보
                SizedBox(height: 90.h),
              ],
            ),
          ),

          // 음성 녹음 위젯을 Stack 위에 배치
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPadding,
            child: CommentComposerV2Widget(
              postId: widget.post.id,
              pendingCommentDrafts: widget.pendingCommentDrafts,
              onTextCommentCompleted: (postId, text) =>
                  _handleTextCommentCreated(text),
              onAudioCommentCompleted:
                  (postId, audioPath, waveformData, durationMs) =>
                      widget.onAudioCommentCompleted(
                        postId,
                        audioPath,
                        waveformData,
                        durationMs,
                      ),
              onMediaCommentCompleted: (postId, localFilePath, isVideo) =>
                  widget.onMediaCommentCompleted(
                    postId,
                    localFilePath,
                    isVideo,
                  ),
              resolveDropRelativePosition: _resolveDropRelativePosition,
              onCommentSaveProgress: widget.onCommentSaveProgress,
              onCommentSaveSuccess: (postId, comment) {
                final existingTagCountBefore =
                    (widget.postComments[widget.post.id] ?? const <Comment>[])
                        .where((existingComment) => existingComment.hasLocation)
                        .length;

                if (comment.hasLocation) {
                  unawaited(
                    _trackCommentTagSaved(
                      comment: comment,
                      existingTagCountBefore: existingTagCountBefore,
                    ),
                  );
                }

                widget.onCommentSaveSuccess(postId, comment);
              },
              onCommentSaveFailure: widget.onCommentSaveFailure,
              onTextFieldFocusChanged: (isFocused) {
                setState(() {
                  _isTextFieldFocused = isFocused;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
