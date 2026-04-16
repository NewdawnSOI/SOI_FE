import '../../../../api/controller/comment_controller.dart';
import '../../../../api/models/comment.dart';
import '../../application/tagging_comment_gateway.dart';

/// SOI의 CommentController를 태깅 모듈 인터페이스에 맞춰 어댑팅합니다.
class SoiTaggingCommentGateway implements TaggingCommentGateway {
  final CommentController _commentController;

  const SoiTaggingCommentGateway(this._commentController);

  @override
  void invalidatePostCaches({
    required int postId,
    bool full = true,
    bool parent = false,
    bool tag = true,
  }) {
    _commentController.invalidatePostCaches(
      postId: postId,
      full: full,
      parent: parent,
      tag: tag,
    );
  }

  @override
  Future<List<Comment>> loadComments({
    required int postId,
    bool forceReload = false,
  }) {
    return _commentController.getComments(
      postId: postId,
      forceReload: forceReload,
    );
  }

  @override
  Future<List<Comment>> loadParentComments({
    required int postId,
    bool forceReload = false,
  }) {
    return _commentController.getAllParentComments(
      postId: postId,
      forceReload: forceReload,
    );
  }

  @override
  Future<List<Comment>> loadTagComments({
    required int postId,
    bool forceReload = false,
  }) {
    return _commentController.getTagComments(
      postId: postId,
      forceReload: forceReload,
    );
  }

  @override
  List<Comment>? peekCommentsCache({required int postId}) {
    return _commentController.peekCommentsCache(postId: postId);
  }

  @override
  List<Comment>? peekParentCommentsCache({required int postId}) {
    return _commentController.peekParentCommentsCache(postId: postId);
  }

  @override
  List<Comment>? peekTagCommentsCache({required int postId}) {
    return _commentController.peekTagCommentsCache(postId: postId);
  }

  @override
  void replaceCommentsCache({
    required int postId,
    required List<Comment> comments,
  }) {
    _commentController.replaceCommentsCache(
      postId: postId,
      comments: comments,
    );
  }

  @override
  void replaceParentCommentsCache({
    required int postId,
    required List<Comment> comments,
  }) {
    _commentController.replaceParentCommentsCache(
      postId: postId,
      comments: comments,
    );
  }

  @override
  void replaceTagCommentsCache({
    required int postId,
    required List<Comment> comments,
  }) {
    _commentController.replaceTagCommentsCache(
      postId: postId,
      comments: comments,
    );
  }
}
