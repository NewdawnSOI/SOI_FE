import 'package:flutter/material.dart';

import '../../../api/models/comment.dart';
import '../../common_widget/about_comment/widget/about_comment_list_sheet/api_comment_row.dart';

/// 프로필 탭에서만 쓰는 댓글 행으로, 공용 댓글 레이아웃에 프로필 탭 전용 액션 표시 정책만 덧입힙니다.
class ThreadedCommentRow extends StatelessWidget {
  final Comment comment;
  final bool isHighlighted;

  const ThreadedCommentRow({
    super.key,
    required this.comment,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return ApiCommentRow(
      comment: comment,
      isHighlighted: isHighlighted,
      showReplyAction: false,
    );
  }
}
