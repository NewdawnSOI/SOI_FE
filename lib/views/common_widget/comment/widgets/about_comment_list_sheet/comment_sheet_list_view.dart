import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../api/models/comment.dart';
import 'comment_row_in_list.dart';

/// 댓글 시트에서 댓글 목록을 담당하는 위젯입니다.
/// - 댓글이 없을 때는 빈 상태를 안내하는 UI가 표시되고, 댓글이 있을 때는 댓글 목록이 separator와 함께 표시됩니다.
/// - 댓글 사이의 separator는 같은 스레드 안에서 이어지는 댓글 사이에만 표시되어, 스레드 구분이 명확하게 드러납니다.
/// - 댓글이 강조되어야 하는 경우, 해당 댓글과 separator에 배경색이 적용되어 강조 효과가 나타납니다.
/// - 댓글 목록은 스크롤 가능한 ListView로 구현되어, 댓글이 많아도 원활하게 탐색할 수 있습니다.
///
/// fields:
/// - [viewportKey]: 댓글 목록이 렌더링되는 영역의 GlobalKey입니다. 댓글 위치로 스크롤할 때 참조됩니다.
/// - [scrollController]: 댓글 목록의 ScrollController입니다. 댓글 위치로 스크롤할 때 사용됩니다.
/// - [comments]: 전체 댓글 목록입니다. 대댓글은 부모 댓글의 threadParentId로 구분됩니다.
/// - [visibleComments]: 현재 시점에서 시트에 표시되어야 하는 댓글 목록입니다. 대댓글은 부모 댓글이 확장된 경우에만 포함됩니다.
/// - [highlightedThreadKey]: 강조되어야 하는 댓글 스레드의 키입니다. 이 스레드에 속한 댓글과 separator는 강조 효과가 적용됩니다.
/// - [expandedReplyParentKeys]: 현재 확장된 대댓글 부모 댓글들의 키 집합입니다. 이 집합에 포함된 댓글의 대댓글은 visibleComments에 포함되어 시트에 표시됩니다.
/// - [expandedActionCommentKey]: 현재 액션이 확장된 댓글의 키입니다. 이 댓글은 액션 팝업이 열려 있어야 하며, 다른 댓글과 구분되어야 합니다.
/// - [commentKeyBuilder]: 댓글 객체에서 고유한 키를 생성하는 함수입니다. 댓글 스레드 구분과 액션 확장 상태 관리에 사용됩니다.
/// - [isCommentHighlighted]: 댓글이 강조되어야 하는지 여부를 판단하는 함수입니다.
/// - [keyForComment]: 댓글 객체에서 해당 댓글의 GlobalKey를 반환하는 함수입니다. 댓글 위치로 스크롤할 때 참조됩니다.
/// - [onScrollStarted]: 댓글 목록이 스크롤되기 시작했을 때 호출되는 콜백입니다.
///   - 스크롤 위치로 이동하는 중에 다른 인터랙션이 발생하는 것을 방지하기 위해 사용됩니다.
/// - [onLongPressComment]: 댓글이 길게 눌렸을 때, 호출되는 콜백입니다.
/// - [onReplyTap]: 댓글의 답글 버튼이 눌렸을 때, 호출되는 콜백입니다.
/// - [onHideRepliesTap]: 댓글의 대댓글 숨기기 버튼이 눌렸을 때, 호출되는 콜백입니다.
/// - [onViewMoreRepliesTap]: 댓글의 대댓글 더보기 버튼이 눌렸을 때, 호출되는 콜백입니다.
class ApiCommentSheetListView extends StatelessWidget {
  const ApiCommentSheetListView({
    super.key,
    required this.viewportKey,
    required this.scrollController,
    required this.comments,
    required this.visibleComments,
    required this.highlightedThreadKey,
    required this.expandedReplyParentKeys,
    required this.expandedActionCommentKey,
    required this.commentKeyBuilder,
    required this.isCommentHighlighted,
    required this.keyForComment,
    required this.onScrollStarted,
    required this.onLongPressComment,
    required this.onReplyTap,
    required this.onHideRepliesTap,
    required this.onViewMoreRepliesTap,
  });

  final GlobalKey viewportKey;
  final ScrollController scrollController;
  final List<Comment> comments;
  final List<Comment> visibleComments;
  final String? highlightedThreadKey;
  final Set<String> expandedReplyParentKeys;
  final String Function(Comment comment) commentKeyBuilder;
  final bool Function(Comment comment, String? anchorKey) isCommentHighlighted;
  final GlobalKey Function(Comment comment) keyForComment;
  final VoidCallback onScrollStarted;
  final ValueChanged<Comment> onLongPressComment;
  final ValueChanged<Comment> onReplyTap;
  final ValueChanged<Comment> onHideRepliesTap;
  final ValueChanged<Comment> onViewMoreRepliesTap;
  final String? expandedActionCommentKey;

  /// 댓글 사이의 separator에 적용되는 수직 패딩입니다.
  /// - 이 패딩은 댓글 사이의 간격을 조절하는 역할을 합니다.
  static const double _commentDividerVerticalPadding = 20.0;

  /// 댓글 사이의 separator에 적용되는 강조 색상입니다.
  static const Color _commentHighlightColor = Color(0x3B000000);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        key: viewportKey,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is UserScrollNotification &&
                notification.direction != ScrollDirection.idle) {
              onScrollStarted();
            }
            return false;
          },
          child: comments.isEmpty
              ? _buildEmptyState(context)
              : _buildListView(),
        ),
      ),
    );
  }

  /// 댓글이 없을 때 표시되는 빈 상태 UI입니다.
  Widget _buildEmptyState(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          controller: scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            SizedBox(
              height: constraints.maxHeight,
              child: Center(
                child: Text(
                  tr('comments.empty', context: context),
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
    );
  }

  /// 실제 댓글 목록은 separator와 스레드 강조 상태를 함께 계산해 렌더링합니다.
  Widget _buildListView() {
    return ListView.separated(
      controller: scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      primary: false,
      itemCount: visibleComments.length,
      separatorBuilder: (_, index) {
        final current = visibleComments[index];
        final next = visibleComments[index + 1];
        return _buildCommentSeparator(
          current: current,
          next: next,
          currentHighlighted: isCommentHighlighted(
            current,
            highlightedThreadKey,
          ),
          nextHighlighted: isCommentHighlighted(next, highlightedThreadKey),
        );
      },
      itemBuilder: (context, index) {
        final comment = visibleComments[index];
        final commentKey = commentKeyBuilder(comment);
        return KeyedSubtree(
          key: keyForComment(comment),
          child: ApiCommentRow(
            comment: comment,
            isHighlighted: isCommentHighlighted(comment, highlightedThreadKey),
            isActionExpanded: expandedActionCommentKey == commentKey,
            onLongPress: () => onLongPressComment(comment),
            onReplyTap: onReplyTap,
            showHideRepliesButton:
                !comment.isReply &&
                (comment.replyCommentCount ?? 0) > 0 &&
                expandedReplyParentKeys.contains(commentKey),
            showViewMoreRepliesButton:
                !comment.isReply &&
                (comment.replyCommentCount ?? 0) > 0 &&
                !expandedReplyParentKeys.contains(commentKey),
            onHideRepliesTap: onHideRepliesTap,
            onViewMoreRepliesTap: onViewMoreRepliesTap,
          ),
        );
      },
    );
  }

  /// 같은 스레드 안에서 이어지는 댓글 사이만 구분선을 접어 표시합니다.
  Widget _buildCommentSeparator({
    required Comment current,
    required Comment next,
    required bool currentHighlighted,
    required bool nextHighlighted,
  }) {
    final sharesThread =
        current.threadParentId != null &&
        current.threadParentId == next.threadParentId;

    if (next.isReply && sharesThread) {
      return Container(
        width: double.infinity,
        height: 15.sp,
        color: currentHighlighted || nextHighlighted
            ? _commentHighlightColor
            : Colors.transparent,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          height: _commentDividerVerticalPadding.sp,
          color: currentHighlighted
              ? _commentHighlightColor
              : Colors.transparent,
        ),
        const Divider(color: Color(0xFF323232), thickness: 1, height: 1),
        Container(
          width: double.infinity,
          height: _commentDividerVerticalPadding.sp,
          color: nextHighlighted ? _commentHighlightColor : Colors.transparent,
        ),
      ],
    );
  }
}
