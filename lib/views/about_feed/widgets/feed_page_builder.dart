import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../common_widget/about_comment/pending_api_voice_comment.dart';
import '../../common_widget/about_comment/api_voice_comment_list_sheet.dart';
import '../../common_widget/about_comment/comment_composer_v2_widget.dart';
import '../../common_widget/api_photo/api_photo_card_widget.dart';
import '../../common_widget/api_photo/api_user_info_widget.dart';
import '../../../api/controller/audio_controller.dart';
import '../../../api/models/comment.dart';
import '../manager/feed_data_manager.dart';
import '../../../utils/analytics_service.dart';

/// 피드 화면 레이아웃 위젯.
///
/// 사진/영상 부분만 위아래로 스크롤되고,
/// 작성자 정보와 댓글 입력창은 화면에 고정되어 있습니다.
class FeedPageBuilder extends StatefulWidget {
  final List<FeedPostItem> posts;
  final bool hasMoreData;
  final bool isLoadingMore;
  final Map<int, List<Comment>> postComments;
  final Map<int, String?> selectedEmojisByPostId;
  final Map<int, PendingApiCommentDraft> pendingCommentDrafts;
  final Map<int, PendingApiCommentMarker> pendingVoiceComments;
  final Function(FeedPostItem) onToggleAudio;
  final Future<void> Function(int, String) onTextCommentCompleted;
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
  final Future<void> Function(int, FeedPostItem) onDeletePost;
  final Function(int) onPageChanged;
  final VoidCallback onStopAllAudio;
  final String? currentUserNickname;
  final Future<void> Function(int postId) onReloadComments;
  final void Function(int postId, String? emoji) onEmojiSelected;

  final PageController? pageController;

  const FeedPageBuilder({
    super.key,
    required this.posts,
    required this.hasMoreData,
    required this.isLoadingMore,
    required this.postComments,
    required this.selectedEmojisByPostId,
    required this.pendingCommentDrafts,
    required this.pendingVoiceComments,
    required this.onToggleAudio,
    required this.onTextCommentCompleted,
    required this.onAudioCommentCompleted,
    required this.onMediaCommentCompleted,
    required this.onProfileImageDragged,
    required this.onCommentSaveProgress,
    required this.onCommentSaveSuccess,
    required this.onCommentSaveFailure,
    required this.onDeletePost,
    required this.onPageChanged,
    required this.onStopAllAudio,
    this.currentUserNickname,
    required this.onReloadComments,
    required this.onEmojiSelected,
    this.pageController,
  });

  @override
  State<FeedPageBuilder> createState() => _FeedPageBuilderState();
}

/// FeedPageBuilder의 상태 관리 클래스.
/// 지금 보이는 게시물 번호를 기억하고,
/// 페이지가 바뀔 때 작성자 정보와 댓글 입력창을 새 게시물에 맞게 바꿔줍니다.
class _FeedPageBuilderState extends State<FeedPageBuilder> {
  /// 지금 화면에 보이는 게시물의 순서 번호.
  int _currentIndex = 0;
  bool _isTextFieldFocused = false;

  /// 지금 보이는 게시물을 반환합니다. 목록이 비어 있거나 범위를 벗어나면 null을 반환합니다.
  /// 부모 위젯에서 전달된 게시물 목록과 현재 인덱스를 기준으로 현재 게시물을 계산합니다.
  /// - widget.posts[_currentIndex]가 유효한 범위에 있으면 해당 게시물을 반환하고, 그렇지 않으면 null을 반환합니다.
  FeedPostItem? get _currentPost =>
      widget.posts.isNotEmpty && _currentIndex < widget.posts.length
      ? widget.posts[_currentIndex]
      : null;

  /// 작성 중인 댓글의 종류를 문자열로 반환합니다. Mixpanel event 기록에 사용됩니다.
  /// 작성 중인 댓글이
  /// 없으면 'unknown',
  /// 있으면 'text' / 'audio' / 'image' / 'video' 중 하나를 반환합니다.
  ///
  /// parameters:
  /// - [draft]: 작성 중인 댓글의 임시 데이터. null이면 댓글 작성이 없는 것으로 간주합니다.
  ///
  /// returns:
  /// - [String]
  ///   - 'text', 'audio', 'image', 'video' 중 하나. 작성 중인 댓글의 종류에 따라 결정됩니다.
  ///   - 'unknown' 작성 중인 댓글이 없거나, 종류를 판단할 수 없는 경우 반환됩니다.
  String _resolveTagContentType(PendingApiCommentDraft? draft) {
    if (draft == null) return 'unknown';
    if (draft.isTextComment) return 'text';
    if ((draft.audioPath ?? '').isNotEmpty) return 'audio';
    if ((draft.mediaPath ?? '').isNotEmpty) {
      return draft.isVideo == true ? 'video' : 'image';
    }
    return 'unknown';
  }

  /// 댓글 태그가 사진에 저장됐을 때,  Mixpanel event를 전송합니다.
  /// 댓글 종류, 기존 태그 수, 게시물/카테고리 ID 등의 정보를 함께 보냅니다.
  Future<void> _trackCommentTagSaved({
    required int postId,
    required int categoryId,
    required String tagContentType,
    required int existingTagCountBefore,
    required Comment comment,
  }) async {
    try {
      // AnalyticsService 인스턴스를 가져옵니다.
      final analytics = context.read<AnalyticsService>();

      // Mixpanel 이벤트에 포함할 속성들을 준비합니다.
      // 'post_id': 태그가 저장된 게시물의 ID입니다.
      // 'category_id': 태그가 저장된 게시물이 속한 카테고리의 ID입니다.
      // 'surface': 이벤트가 발생한 화면이나 위치를 나타냅니다. 여기서는 'feed_home'으로 고정합니다.
      // 'tag_content_type': 작성 중인 댓글의 종류입니다. 'text', 'audio', 'image', 'video' 중 하나입니다.
      // 'existing_tag_count_before': 태그가 저장되기 전, 해당 게시물에 이미 존재하던 위치 태그의 수입니다.
      // 'existing_tag_count_after': 태그가 저장된 후, 해당 게시물에 존재하는 위치 태그의 수입니다. 기존 태그 수에 1을 더한 값으로 계산합니다.
      final properties = <String, dynamic>{
        'post_id': postId,
        'category_id': categoryId,
        'surface': 'feed_home',
        'tag_content_type': tagContentType,
        'existing_tag_count_before': existingTagCountBefore,
        'existing_tag_count_after': existingTagCountBefore + 1,
      };

      // comment 객체에 ID가 있으면 properties에 추가합니다.
      // ID가 없으면 새로 생성된 댓글이 아직 서버에서 반환되지 않은 상태일 수 있습니다.
      if (comment.id != null) {
        properties['comment_id'] = comment.id;
      }

      // Mixpanel에 'comment_tag_saved' 이벤트를 전송합니다.
      await analytics.track('comment_tag_saved', properties: properties);
    } catch (error) {
      debugPrint('Mixpanel comment_tag_saved tracking failed: $error');
    }
  }

  /// 피드 레이아웃을 구성합니다.
  ///
  /// - 위쪽 500 높이: 사진/영상만 "위아래로 스크롤"
  /// - 중간: 게시물의 작성자 정보 (화면에 고정)
  /// - 아래쪽: 댓글 입력창 (화면에 고정, 홈 탭 바 높이를 제외한 만큼만 키보드 위로 이동)
  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = _isTextFieldFocused || keyboardInset > 0;
    final homeNavigationReservedHeight = 70.h + 10.h;
    final effectiveKeyboardInset = keyboardInset > homeNavigationReservedHeight
        ? keyboardInset - homeNavigationReservedHeight
        : 0.0;
    final composerBottomInset = isKeyboardVisible
        ? effectiveKeyboardInset + 10.0
        : 10.0;

    // 페이지뷰의 아이템 수: 게시물 수 + (더 불러올 데이터가 있으면 로딩 인디케이터용 아이템 1개)
    final itemCount = widget.posts.length + (widget.hasMoreData ? 1 : 0);

    // 현재 페이지에 해당하는 게시물을 가져옵니다. 게시물이 없거나 인덱스가 범위를 벗어나면 null이 됩니다.
    // _currentPost는 getter로 정의되어있고, widget.posts와 _currentIndex를 참조하여 현재 게시물을 계산합니다.
    final currentPost = _currentPost;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ApiPhotoDisplayWidget만 PageView로 스크롤
            // PageView.builder는 페이지가 스크롤 되도록 만드는 위젯인데,
            // 여기서는 ApiPhotoCardWidget의 displayOnly 모드를 활용해서 사진/영상 부분만 스크롤되도록 구성했습니다.
            SizedBox(
              height: 500.h,
              child: PageView.builder(
                controller: widget.pageController,
                scrollDirection: Axis.vertical, // 상하로 스크롤
                clipBehavior: Clip.hardEdge, // 페이지가 화면 밖으로 넘어가지 않도록 클리핑
                itemCount: itemCount, // 게시물 수 + 로딩 인디케이터(있으면)
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                  widget.onPageChanged(index);
                  widget.onStopAllAudio();
                },
                itemBuilder: (context, index) {
                  if (index >= widget.posts.length) {
                    return widget.isLoadingMore
                        ? const Center(child: CircularProgressIndicator())
                        : const SizedBox.shrink();
                  }

                  // 현재 페이지에 해당하는 게시물을 가져옵니다. 인덱스가 범위를 벗어나면 null이 됩니다.
                  // 여기서 가져온 post 정보로 ApiPhotoCardWidget을 구성합니다.
                  final feedItem = widget.posts[index];

                  return ApiPhotoCardWidget(
                    key: ValueKey(feedItem.post.id),
                    post: feedItem.post,
                    categoryName: feedItem.categoryName,
                    categoryId: feedItem.categoryId,
                    index: index,
                    isOwner: false,
                    displayOnly: true,
                    selectedEmoji:
                        widget.selectedEmojisByPostId[feedItem.post.id],
                    onEmojiSelected: (emoji) =>
                        widget.onEmojiSelected(feedItem.post.id, emoji),
                    postComments: widget.postComments,
                    pendingCommentDrafts: widget.pendingCommentDrafts,
                    pendingVoiceComments: widget.pendingVoiceComments,
                    onToggleAudio: (p) => widget.onToggleAudio(feedItem),
                    onProfileImageDragged: widget.onProfileImageDragged,
                    onCommentsReloadRequested: widget.onReloadComments,
                  );
                },
              ),
            ),

            // 현재 포스트의 유저 정보 (고정)
            if (currentPost != null) ...[
              SizedBox(height: 12.h),
              ApiUserInfoWidget(
                post: currentPost.post,
                isCurrentUserPost:
                    widget.currentUserNickname != null &&
                    widget.currentUserNickname == currentPost.post.nickName,
                onDeletePressed: () =>
                    widget.onDeletePost(_currentIndex, currentPost),
                onCommentPressed: () {
                  final comments =
                      widget.postComments[currentPost.post.id] ?? const [];
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) {
                      return ChangeNotifierProvider(
                        create: (_) => AudioController(),
                        child: ApiVoiceCommentListSheet(
                          postId: currentPost.post.id,
                          comments: comments,
                          onCommentsUpdated: (updatedComments) {
                            if (!mounted) return;
                            setState(() {
                              widget.postComments[currentPost.post.id] =
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
              // 하단 CommentComposer 공간 확보
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: isKeyboardVisible ? 0 : 90.h,
              ),
            ],
          ],
        ),

        // 댓글 입력 위젯 (현재 포스트 기준 고정)
        if (currentPost != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: composerBottomInset),
              child: CommentComposerV2Widget(
                postId: currentPost.post.id,
                pendingCommentDrafts: widget.pendingCommentDrafts,
                onTextCommentCompleted: (postId, text) =>
                    widget.onTextCommentCompleted(postId, text),
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
                resolveDropRelativePosition: (id) =>
                    widget.pendingVoiceComments[id]?.relativePosition,
                onCommentSaveProgress: widget.onCommentSaveProgress,
                onCommentSaveSuccess: (postId, comment) {
                  final existingTagCountBefore =
                      (widget.postComments[postId] ?? const <Comment>[])
                          .where((c) => c.hasLocation)
                          .length;
                  if (comment.hasLocation) {
                    unawaited(
                      _trackCommentTagSaved(
                        postId: postId,
                        categoryId: currentPost.categoryId,
                        tagContentType: _resolveTagContentType(
                          widget.pendingCommentDrafts[postId],
                        ),
                        existingTagCountBefore: existingTagCountBefore,
                        comment: comment,
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
          ),
      ],
    );
  }
}
