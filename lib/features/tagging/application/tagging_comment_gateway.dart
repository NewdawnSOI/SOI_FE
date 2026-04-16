import '../../../api/models/comment.dart';

/// 태깅 모듈이 댓글 캐시와 조회를 다루기 위해 기대하는 최소 인터페이스입니다.
abstract class TaggingCommentGateway {
  List<Comment>? peekCommentsCache({required int postId});

  List<Comment>? peekParentCommentsCache({required int postId});

  List<Comment>? peekTagCommentsCache({required int postId});

  void replaceCommentsCache({
    required int postId,
    required List<Comment> comments,
  });

  void replaceParentCommentsCache({
    required int postId,
    required List<Comment> comments,
  });

  void replaceTagCommentsCache({
    required int postId,
    required List<Comment> comments,
  });

  void invalidatePostCaches({
    required int postId,
    bool full = true,
    bool parent = false,
    bool tag = true,
  });

  Future<List<Comment>> loadComments({
    required int postId,
    bool forceReload = false,
  });

  Future<List<Comment>> loadParentComments({
    required int postId,
    bool forceReload = false,
  });

  Future<List<Comment>> loadTagComments({
    required int postId,
    bool forceReload = false,
  });
}
