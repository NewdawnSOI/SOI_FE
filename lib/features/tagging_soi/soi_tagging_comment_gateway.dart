import 'package:tagging_core/tagging_core.dart';

import '../../api/controller/comment_controller.dart';
import 'soi_tag_comment_mapper.dart';
import 'soi_tagging_ids.dart';

/// SOI CommentController를 tagging_core gateway 인터페이스에 맞춰 어댑팅합니다.
class SoiTaggingCommentGateway implements TaggingCommentGateway {
  const SoiTaggingCommentGateway(this._commentController);

  final CommentController _commentController;

  @override
  void appendCreatedComment({
    required TagScopeId scopeId,
    required TagComment comment,
  }) {
    _commentController.appendCreatedComment(
      postId: SoiTaggingIds.postIdFromScopeId(scopeId),
      newComment: SoiTagCommentMapper.toComment(comment),
    );
  }

  @override
  void invalidateScopeCaches({
    required TagScopeId scopeId,
    bool full = true,
    bool parent = false,
    bool tag = true,
  }) {
    _commentController.invalidatePostCaches(
      postId: SoiTaggingIds.postIdFromScopeId(scopeId),
      full: full,
      parent: parent,
      tag: tag,
    );
  }

  @override
  Future<List<TagComment>> loadComments({
    required TagScopeId scopeId,
    bool forceReload = false,
  }) async {
    final comments = await _commentController.getComments(
      postId: SoiTaggingIds.postIdFromScopeId(scopeId),
      forceReload: forceReload,
    );
    return SoiTagCommentMapper.fromComments(comments);
  }

  @override
  Future<List<TagComment>> loadParentComments({
    required TagScopeId scopeId,
    bool forceReload = false,
  }) async {
    final comments = await _commentController.getAllParentComments(
      postId: SoiTaggingIds.postIdFromScopeId(scopeId),
      forceReload: forceReload,
    );
    return SoiTagCommentMapper.fromComments(comments);
  }

  @override
  Future<List<TagComment>> loadTagComments({
    required TagScopeId scopeId,
    bool forceReload = false,
  }) async {
    final comments = await _commentController.getTagComments(
      postId: SoiTaggingIds.postIdFromScopeId(scopeId),
      forceReload: forceReload,
    );
    return SoiTagCommentMapper.fromComments(comments);
  }

  @override
  List<TagComment>? peekCommentsCache({required TagScopeId scopeId}) {
    final cached = _commentController.peekCommentsCache(
      postId: SoiTaggingIds.postIdFromScopeId(scopeId),
    );
    return cached == null ? null : SoiTagCommentMapper.fromComments(cached);
  }

  @override
  List<TagComment>? peekParentCommentsCache({required TagScopeId scopeId}) {
    final cached = _commentController.peekParentCommentsCache(
      postId: SoiTaggingIds.postIdFromScopeId(scopeId),
    );
    return cached == null ? null : SoiTagCommentMapper.fromComments(cached);
  }

  @override
  List<TagComment>? peekTagCommentsCache({required TagScopeId scopeId}) {
    final cached = _commentController.peekTagCommentsCache(
      postId: SoiTaggingIds.postIdFromScopeId(scopeId),
    );
    return cached == null ? null : SoiTagCommentMapper.fromComments(cached);
  }

  /// tagging_core가 임시 tag cache와 서버 hydrate cache를 구분할 수 있게 연결합니다.
  @override
  bool hasHydratedTagCommentsCache({required TagScopeId scopeId}) {
    return _commentController.hasHydratedTagCommentsCache(
      postId: SoiTaggingIds.postIdFromScopeId(scopeId),
    );
  }

  @override
  TagThreadSnapshot peekThreadSnapshot({required TagScopeId scopeId}) {
    return TagThreadSnapshot(
      comments: peekCommentsCache(scopeId: scopeId),
      parentComments: peekParentCommentsCache(scopeId: scopeId),
      tagComments: peekTagCommentsCache(scopeId: scopeId),
    );
  }

  @override
  void removeCommentFromCache({
    required TagScopeId scopeId,
    required TagEntityId commentId,
  }) {
    final numericCommentId = SoiTaggingIds.intFromEntityId(commentId);
    if (numericCommentId == null) {
      return;
    }
    _commentController.removeCommentFromCache(
      postId: SoiTaggingIds.postIdFromScopeId(scopeId),
      commentId: numericCommentId,
    );
  }

  @override
  void replaceCommentsCache({
    required TagScopeId scopeId,
    required List<TagComment> comments,
  }) {
    _commentController.replaceCommentsCache(
      postId: SoiTaggingIds.postIdFromScopeId(scopeId),
      comments: SoiTagCommentMapper.toComments(comments),
    );
  }

  @override
  void replaceParentCommentsCache({
    required TagScopeId scopeId,
    required List<TagComment> comments,
  }) {
    _commentController.replaceParentCommentsCache(
      postId: SoiTaggingIds.postIdFromScopeId(scopeId),
      comments: SoiTagCommentMapper.toComments(comments),
    );
  }

  @override
  void replaceTagCommentsCache({
    required TagScopeId scopeId,
    required List<TagComment> comments,
  }) {
    _commentController.replaceTagCommentsCache(
      postId: SoiTaggingIds.postIdFromScopeId(scopeId),
      comments: SoiTagCommentMapper.toComments(comments),
    );
  }
}
