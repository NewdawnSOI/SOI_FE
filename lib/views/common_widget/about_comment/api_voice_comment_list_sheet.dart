import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../api/controller/comment_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../api/models/comment.dart';
import 'comment_text_input_widget.dart';
import 'widget/about_comment_list_sheet/api_comment_row.dart';

/// 댓글 리스트를 보여주는 바텀 시트
/// Comment.dart(Model)을 사용하여 댓글 정보를 표시합니다.
/// API의 CommentRespDto와 달리, Comment 모델은 UI/도메인 레이어에서 사용하기 위한 모델입니다.
class ApiVoiceCommentListSheet extends StatefulWidget {
  final int postId;
  final List<Comment> comments;
  final String? selectedCommentId;
  final ValueChanged<List<Comment>>? onCommentsUpdated;

  const ApiVoiceCommentListSheet({
    super.key,
    required this.postId,
    required this.comments,
    this.selectedCommentId,
    this.onCommentsUpdated,
  });

  @override
  State<ApiVoiceCommentListSheet> createState() =>
      _ApiVoiceCommentListSheetState();
}

class _ApiVoiceCommentListSheetState extends State<ApiVoiceCommentListSheet> {
  static const double _sheetHeightFactor = 0.6;
  static const double _commentDividerVerticalPadding = 20.0;

  late final ScrollController _scrollController;
  late final TextEditingController _replyDraftController;
  late final FocusNode _replyDraftFocusNode;
  late final List<Comment> _comments;
  final GlobalKey _commentListViewportKey = GlobalKey(
    debugLabel: 'comment_list_viewport',
  );
  final Map<String, GlobalKey> _commentKeys = <String, GlobalKey>{};
  final Set<String> _expandedReplyParentKeys = <String>{};
  Comment? _replyTargetComment;
  bool _isReplyDraftArmed = false;
  bool _isTextInputMode = false;
  String _pendingInitialReplyText = '';
  int _textInputSession = 0;

  /// 선택된 댓글 ID에서 해시코드를 추출하는 함수
  int? _selectedHashCode(String? selectedCommentId) {
    if (selectedCommentId == null) return null;
    final parts = selectedCommentId.split('_');
    if (parts.length < 2) return null;
    return int.tryParse(parts.last);
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _replyDraftController = TextEditingController();
    _replyDraftFocusNode = FocusNode();
    _replyDraftFocusNode.addListener(_handleReplyDraftFocusChanged);
    _comments = widget.comments.toList();
    _expandSelectedReplyParentIfNeeded();

    if (widget.selectedCommentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedComment();
      });
    }
  }

  @override
  void dispose() {
    _replyDraftFocusNode.removeListener(_handleReplyDraftFocusChanged);
    _replyDraftFocusNode.dispose();
    _replyDraftController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 댓글 리스트가 처음 열릴 때, 선택된 댓글이 있으면 해당 댓글로 스크롤하는 함수
  void _scrollToSelectedComment() {
    if (widget.selectedCommentId == null) return;

    final targetHash = _selectedHashCode(widget.selectedCommentId);
    if (targetHash == null) return;

    final targetComment = _comments.cast<Comment?>().firstWhere(
      (comment) => comment?.hashCode == targetHash,
      orElse: () => null,
    );
    if (targetComment == null) return;

    _scrollCommentAboveActionBar(targetComment, animated: false);
  }

  void _expandSelectedReplyParentIfNeeded() {
    final targetHash = _selectedHashCode(widget.selectedCommentId);
    if (targetHash == null) return;

    final targetComment = _comments.cast<Comment?>().firstWhere(
      (comment) => comment?.hashCode == targetHash,
      orElse: () => null,
    );
    if (targetComment == null || !targetComment.isReply) return;

    final parentComment = _findParentComment(targetComment);
    if (parentComment == null) return;

    _expandedReplyParentKeys.add(_commentKeyId(parentComment));
  }

  void _showReplyInput({Comment? replyTarget}) {
    if (replyTarget != null &&
        (replyTarget.id == null || replyTarget.userId == null)) {
      _showSnackBar(tr('common.user_info_unavailable'));
      return;
    }

    setState(() {
      _replyTargetComment = replyTarget;
      _isReplyDraftArmed = true;
      _isTextInputMode = false;
      _pendingInitialReplyText = '';
    });

    _replyDraftController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      FocusScope.of(context).requestFocus(_replyDraftFocusNode);
      if (replyTarget != null) {
        _scrollCommentAboveActionBar(replyTarget);
      }
    });
  }

  String _commentKeyId(Comment comment) {
    final idPart = comment.id?.toString() ?? 'hash_${comment.hashCode}';
    return '${comment.type.name}_$idPart';
  }

  GlobalKey _keyForComment(Comment comment) {
    return _commentKeys.putIfAbsent(
      _commentKeyId(comment),
      () => GlobalKey(debugLabel: 'comment_${_commentKeyId(comment)}'),
    );
  }

  Future<void> _scrollCommentAboveActionBar(
    Comment targetComment, {
    bool animated = true,
  }) async {
    if (!_scrollController.hasClients) {
      return;
    }

    final viewportContext = _commentListViewportKey.currentContext;
    final targetContext = _keyForComment(targetComment).currentContext;
    if (viewportContext == null || targetContext == null) {
      return;
    }

    final viewportBox = viewportContext.findRenderObject() as RenderBox?;
    final targetBox = targetContext.findRenderObject() as RenderBox?;
    if (viewportBox == null || targetBox == null) {
      return;
    }

    final viewportTopLeft = viewportBox.localToGlobal(Offset.zero);
    final targetTopLeft = targetBox.localToGlobal(Offset.zero);
    final viewportBottom = viewportTopLeft.dy + viewportBox.size.height;
    final targetBottom = targetTopLeft.dy + targetBox.size.height;
    final scrollDelta = targetBottom - viewportBottom;

    if (scrollDelta.abs() < 1) {
      return;
    }

    final nextOffset = (_scrollController.offset + scrollDelta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    if (animated) {
      await _scrollController.animateTo(
        nextOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }

    _scrollController.jumpTo(nextOffset);
  }

  void _handleReplyDraftFocusChanged() {
    if (_replyDraftFocusNode.hasFocus ||
        _isTextInputMode ||
        !_isReplyDraftArmed ||
        _replyDraftController.text.trim().isNotEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _replyTargetComment = null;
      _isReplyDraftArmed = false;
    });
  }

  void _handleReplyDraftChanged(String value) {
    if (!_isReplyDraftArmed || _isTextInputMode || value.isEmpty) {
      return;
    }

    final replyTarget = _replyTargetComment;
    _replyDraftFocusNode.unfocus();
    setState(() {
      _pendingInitialReplyText = value;
      _isTextInputMode = true;
      _textInputSession++;
    });
    _replyDraftController.clear();
    if (replyTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _scrollCommentAboveActionBar(replyTarget);
      });
    }
  }

  void _hideReplyInput() {
    if (!mounted) {
      return;
    }
    setState(() {
      _replyTargetComment = null;
      _isReplyDraftArmed = false;
      _isTextInputMode = false;
      _pendingInitialReplyText = '';
    });
    _replyDraftController.clear();
    _replyDraftFocusNode.unfocus();
  }

  Future<void> _submitTextComment(String text) async {
    final currentUser = context.read<UserController>().currentUser;
    if (currentUser == null) {
      _showSnackBar(tr('common.login_required'));
      throw StateError('login_required');
    }

    final replyTarget = _replyTargetComment;
    final result = await context.read<CommentController>().createComment(
      postId: widget.postId,
      userId: currentUser.id,
      parentId: replyTarget?.id ?? 0,
      replyUserId: replyTarget?.userId ?? 0,
      text: text,
      type: replyTarget != null ? CommentType.reply : CommentType.text,
    );

    if (!mounted) {
      return;
    }

    if (!result.success) {
      _showSnackBar(tr('comments.save_failed'));
      throw StateError('comment_save_failed');
    }

    final savedComment =
        result.comment ??
        Comment(
          id: null,
          userId: currentUser.id,
          nickname: currentUser.userId,
          replyUserName: replyTarget?.nickname,
          userProfileUrl: currentUser.profileImageUrlKey,
          userProfileKey: currentUser.profileImageUrlKey,
          createdAt: DateTime.now(),
          text: text,
          type: replyTarget != null ? CommentType.reply : CommentType.text,
        );

    final insertIndex = _resolveInsertIndex(replyTarget);
    setState(() {
      if (replyTarget != null) {
        final parentComment = _findParentComment(replyTarget);
        if (parentComment != null) {
          final parentIndex = _indexOfComment(parentComment);
          if (parentIndex >= 0) {
            final currentParent = _comments[parentIndex];
            _comments[parentIndex] = currentParent.copyWith(
              replyUserCount: (currentParent.replyUserCount ?? 0) + 1,
            );
            _expandedReplyParentKeys.add(_commentKeyId(currentParent));
          }
        }
      }
      _comments.insert(insertIndex, savedComment);
      _replyTargetComment = null;
      _isReplyDraftArmed = false;
      _isTextInputMode = false;
      _pendingInitialReplyText = '';
    });
    _notifyCommentsUpdated();
  }

  int _resolveInsertIndex(Comment? replyTarget) {
    if (replyTarget == null) {
      return _comments.length;
    }

    final targetIndex = _comments.indexWhere(
      (comment) =>
          comment.id == replyTarget.id &&
          comment.hashCode == replyTarget.hashCode,
    );
    if (targetIndex < 0) {
      return _comments.length;
    }

    if (replyTarget.isReply) {
      return targetIndex + 1;
    }

    var insertIndex = targetIndex + 1;
    while (insertIndex < _comments.length && _comments[insertIndex].isReply) {
      insertIndex++;
    }
    return insertIndex;
  }

  int _indexOfComment(Comment target) {
    return _comments.indexWhere(
      (comment) =>
          comment.id == target.id && comment.hashCode == target.hashCode,
    );
  }

  Comment? _findParentComment(Comment comment) {
    final targetIndex = _indexOfComment(comment);
    if (targetIndex < 0) return null;
    if (!comment.isReply) return comment;

    for (var index = targetIndex - 1; index >= 0; index--) {
      final candidate = _comments[index];
      if (!candidate.isReply) {
        return candidate;
      }
    }

    return null;
  }

  List<Comment> _visibleComments() {
    final visible = <Comment>[];
    Comment? currentParent;
    var isCurrentParentExpanded = false;

    for (final comment in _comments) {
      if (!comment.isReply) {
        currentParent = comment;
        isCurrentParentExpanded = _expandedReplyParentKeys.contains(
          _commentKeyId(comment),
        );
        visible.add(comment);
        continue;
      }

      if (currentParent == null || isCurrentParentExpanded) {
        visible.add(comment);
      }
    }

    return visible;
  }

  void _showRepliesForComment(Comment comment) {
    final parentComment = comment.isReply
        ? _findParentComment(comment)
        : comment;
    if (parentComment == null || !mounted) return;

    setState(() {
      _expandedReplyParentKeys.add(_commentKeyId(parentComment));
    });
  }

  void _hideRepliesForComment(Comment comment) {
    final parentComment = comment.isReply
        ? _findParentComment(comment)
        : comment;
    if (parentComment == null || !mounted) return;

    setState(() {
      _expandedReplyParentKeys.remove(_commentKeyId(parentComment));
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF5A5A5A),
      ),
    );
  }

  void _notifyCommentsUpdated() {
    widget.onCommentsUpdated?.call(List<Comment>.unmodifiable(_comments));
  }

  Widget _buildCommentSeparator({
    required Comment current,
    required Comment next,
  }) {
    // 다음 항목이 대댓글이면 같은 reply 묶음으로 간주해 선을 숨깁니다.
    if (next.isReply) {
      return SizedBox(height: (_commentDividerVerticalPadding * 2).sp);
    }
    return _buildCommentDivider();
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * _sheetHeightFactor;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        width: double.infinity,
        height: sheetHeight,
        decoration: BoxDecoration(
          color: const Color(0xFF1c1c1c),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24.8),
            topRight: Radius.circular(24.8),
          ),
        ),
        padding: EdgeInsets.only(bottom: 10.sp),
        child: Column(
          children: [
            SizedBox(height: 20.sp),
            Text(
              "댓글",
              style: TextStyle(
                color: const Color(0xFFF8F8F8),
                fontSize: 18.sp,
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 15.sp),
            _buildCommentList(),
            //SizedBox(height: 10.sp),
            _buildCommentActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentList() {
    final selectedHash = _selectedHashCode(widget.selectedCommentId);
    final visibleComments = _visibleComments();
    return Expanded(
      child: Container(
        key: _commentListViewportKey,
        child: _comments.isEmpty
            ? LayoutBuilder(
                builder: (context, constraints) {
                  return ListView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    children: [
                      SizedBox(
                        height: constraints.maxHeight,
                        child: Center(
                          child: Text(
                            '댓글이 없습니다',
                            style: TextStyle(
                              color: const Color(0xFF9E9E9E),
                              fontSize: 16.sp,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            : ListView.separated(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                primary: false,
                itemCount: visibleComments.length,
                separatorBuilder: (_, index) => _buildCommentSeparator(
                  current: visibleComments[index],
                  next: visibleComments[index + 1],
                ),
                itemBuilder: (context, index) {
                  final comment = visibleComments[index];
                  final isHighlighted =
                      selectedHash != null && comment.hashCode == selectedHash;
                  return KeyedSubtree(
                    key: _keyForComment(comment),
                    child: ApiCommentRow(
                      comment: comment,
                      isHighlighted: isHighlighted,
                      onReplyTap: (target) =>
                          _showReplyInput(replyTarget: target),
                      showHideRepliesButton:
                          !comment.isReply &&
                          (comment.replyUserCount ?? 0) > 0 &&
                          _expandedReplyParentKeys.contains(
                            _commentKeyId(comment),
                          ),
                      showViewMoreRepliesButton:
                          !comment.isReply &&
                          (comment.replyUserCount ?? 0) > 0 &&
                          !_expandedReplyParentKeys.contains(
                            _commentKeyId(comment),
                          ),
                      onHideRepliesTap: _hideRepliesForComment,
                      onViewMoreRepliesTap: _showRepliesForComment,
                    ),
                  );
                },
              ),
      ),
    );
  }

  /// 댓글 리스트에서 각 댓글 사이에 들어가는 구분선 위젯
  Widget _buildCommentDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: _commentDividerVerticalPadding.sp,
      ),
      child: const Divider(color: Color(0xFF323232), thickness: 1, height: 1),
    );
  }

  /// CommentListSheet 내부에 있는 댓글 추가 액션 바
  Widget _buildCommentActionBar() {
    return Center(
      child: SizedBox(
        height: 52.sp,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _isTextInputMode
              ? KeyedSubtree(
                  key: ValueKey(
                    'reply_input_${_replyTargetComment?.id ?? 0}_$_textInputSession',
                  ),
                  child: CommentTextInputWidget(
                    initialText: _pendingInitialReplyText,
                    onSubmitText: _submitTextComment,
                    onEditingCancelled: _hideReplyInput,
                    hintText: tr('comments.add_comment'),
                  ),
                )
              : KeyedSubtree(
                  key: const ValueKey('comment_action_bar'),
                  child: Container(
                    width: 353.sp,
                    height: 46.sp,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0B0B),
                      borderRadius: BorderRadius.circular(52.r),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 10.sp),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          icon: Container(
                            width: 32.sp,
                            height: 32.sp,
                            decoration: ShapeDecoration(
                              color: const Color(0xFF323232),
                              shape: const CircleBorder(),
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/camera_mode.png',
                                width: (17.78).sp,
                                height: 16.sp,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.sp),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: IgnorePointer(
                              ignoring: !_isReplyDraftArmed,
                              child: TextField(
                                controller: _replyDraftController,
                                focusNode: _replyDraftFocusNode,
                                autofocus: false,
                                minLines: 1,
                                maxLines: 1,
                                onChanged: _handleReplyDraftChanged,
                                onTapOutside: (_) =>
                                    FocusScope.of(context).unfocus(),
                                style: TextStyle(
                                  color: const Color(0xFFF8F8F8),
                                  fontSize: 16.sp,
                                  fontFamily: 'Pretendard Variable',
                                  fontWeight: FontWeight.w200,
                                  letterSpacing: -1.14,
                                ),
                                cursorColor: Colors.white,
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                  hintText: tr('comments.add_comment'),
                                  hintStyle: TextStyle(
                                    color: const Color(0xFFF8F8F8),
                                    fontSize: 16.sp,
                                    fontFamily: 'Pretendard Variable',
                                    fontWeight: FontWeight.w200,
                                    letterSpacing: -1.14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          icon: Image.asset(
                            'assets/record_icon.png',
                            width: 36.sp,
                            height: 36.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
