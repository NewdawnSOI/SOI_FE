import '../../../../../api/models/comment.dart';

/// 댓글 시트의 스레드 식별, 부모 탐색, 가시 목록 계산을 담당합니다.
/// 위젯 상태와 분리된 순수 계산만 제공해 재사용과 테스트를 쉽게 만듭니다.
class ApiCommentThreadService {
  const ApiCommentThreadService._();

  /// 댓글을 현재 스레드 관계 안에서 안정적으로 식별할 수 있는 키로 변환합니다.
  static String commentKeyId(Comment comment) {
    final idPart = comment.id?.toString() ?? 'hash_${comment.hashCode}';
    return '${comment.type.name}_$idPart';
  }

  /// 외부 선택 키에서 저장된 댓글 ID를 추출해 fallback 매칭에 사용합니다.
  static int? selectedCommentNumericId(String? selectedCommentId) {
    if (selectedCommentId == null) {
      return null;
    }

    final parts = selectedCommentId.split('_');
    if (parts.length < 2) {
      return null;
    }
    return int.tryParse(parts.last);
  }

  /// 선택 키와 댓글 ID를 함께 사용해 현재 목록의 대상 댓글을 찾습니다.
  static Comment? selectedComment(
    String? selectedCommentId,
    List<Comment> comments,
  ) {
    if (selectedCommentId == null) {
      return null;
    }

    for (final comment in comments) {
      if (commentKeyId(comment) == selectedCommentId) {
        return comment;
      }
    }

    final numericId = selectedCommentNumericId(selectedCommentId);
    if (numericId == null) {
      return null;
    }

    for (final comment in comments) {
      if (comment.id == numericId || comment.hashCode == numericId) {
        return comment;
      }
    }

    return null;
  }

  /// 현재 댓글이 속한 원댓글을 찾아 스레드 기준 댓글을 반환합니다.
  static Comment? findParentComment(Comment comment, List<Comment> comments) {
    if (!comment.isReply) {
      return comment;
    }

    final explicitParentId = comment.threadParentId;
    if (explicitParentId != null) {
      for (final candidate in comments) {
        if (!candidate.isReply && candidate.threadParentId == explicitParentId) {
          return candidate;
        }
      }
    }

    final targetIndex = indexOfComment(comments, comment);
    if (targetIndex < 0) {
      return null;
    }

    for (var index = targetIndex - 1; index >= 0; index--) {
      final candidate = comments[index];
      if (!candidate.isReply) {
        return candidate;
      }
    }

    return null;
  }

  /// 원댓글 스레드 ID를 우선 사용하고, 없으면 부모 탐색으로 보완합니다.
  static int? replyThreadParentId(Comment? comment, List<Comment> comments) {
    if (comment == null) {
      return null;
    }

    return comment.threadParentId ??
        findParentComment(comment, comments)?.threadParentId ??
        (!comment.isReply ? comment.id : null);
  }

  /// 수동 강조가 없으면 선택 댓글이 속한 스레드를 강조 기준으로 계산합니다.
  static String? highlightThreadKey({
    required String? manualHighlightedThreadKey,
    required String? selectedCommentId,
    required List<Comment> comments,
  }) {
    if (manualHighlightedThreadKey != null) {
      return manualHighlightedThreadKey;
    }

    final selected = selectedComment(selectedCommentId, comments);
    if (selected == null) {
      return null;
    }

    final anchor = selected.isReply
        ? findParentComment(selected, comments) ?? selected
        : selected;
    return commentKeyId(anchor);
  }

  /// 주어진 댓글이 강조 대상 스레드에 속하는지 판별합니다.
  static bool belongsToHighlightedThread({
    required Comment comment,
    required String? anchorKey,
    required List<Comment> comments,
  }) {
    if (anchorKey == null) {
      return false;
    }
    if (commentKeyId(comment) == anchorKey) {
      return true;
    }
    if (!comment.isReply) {
      return false;
    }

    final parent = findParentComment(comment, comments);
    return parent != null && commentKeyId(parent) == anchorKey;
  }

  /// 현재 펼쳐진 스레드 상태를 기준으로 화면에 보여줄 댓글만 추립니다.
  static List<Comment> visibleComments(
    List<Comment> comments,
    Set<String> expandedReplyParentKeys,
  ) {
    final visible = <Comment>[];

    for (final comment in comments) {
      if (!comment.isReply) {
        visible.add(comment);
        continue;
      }

      final parent = findParentComment(comment, comments);
      final isExpanded =
          parent == null || expandedReplyParentKeys.contains(commentKeyId(parent));
      if (isExpanded) {
        visible.add(comment);
      }
    }

    return visible;
  }

  /// 현재 목록 안에서 같은 댓글을 다시 찾을 때 스레드 관계까지 함께 비교합니다.
  static int indexOfComment(List<Comment> comments, Comment target) {
    return comments.indexWhere(
      (comment) =>
          comment.isReply == target.isReply &&
          (comment.id == target.id ||
              (comment.id == null &&
                  target.id == null &&
                  comment.hashCode == target.hashCode)) &&
          (comment.threadParentId == target.threadParentId ||
              comment.threadParentId == null ||
              target.threadParentId == null),
    );
  }

  /// 새 댓글이 현재 스레드 순서를 유지하도록 삽입 위치를 계산합니다.
  static int resolveInsertIndex(List<Comment> comments, Comment? replyTarget) {
    if (replyTarget == null) {
      return comments.length;
    }

    final targetIndex = indexOfComment(comments, replyTarget);
    if (targetIndex < 0) {
      return comments.length;
    }

    if (replyTarget.isReply) {
      return targetIndex + 1;
    }

    var insertIndex = targetIndex + 1;
    final targetParentId = replyThreadParentId(replyTarget, comments);
    while (insertIndex < comments.length &&
        comments[insertIndex].isReply &&
        comments[insertIndex].threadParentId == targetParentId) {
      insertIndex++;
    }
    return insertIndex;
  }
}
