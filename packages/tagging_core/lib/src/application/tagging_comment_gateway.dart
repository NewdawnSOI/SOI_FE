import '../domain/tag_models.dart';

/// 태깅 모듈이 댓글 캐시와 조회를 다루기 위해 기대하는 최소 인터페이스입니다.
abstract class TaggingCommentGateway {
  TagThreadSnapshot peekThreadSnapshot({required TagScopeId scopeId});

  List<TagComment>? peekCommentsCache({required TagScopeId scopeId});

  List<TagComment>? peekParentCommentsCache({required TagScopeId scopeId});

  List<TagComment>? peekTagCommentsCache({required TagScopeId scopeId});

  void replaceCommentsCache({
    required TagScopeId scopeId,
    required List<TagComment> comments,
  });

  void replaceParentCommentsCache({
    required TagScopeId scopeId,
    required List<TagComment> comments,
  });

  void replaceTagCommentsCache({
    required TagScopeId scopeId,
    required List<TagComment> comments,
  });

  void appendCreatedComment({
    required TagScopeId scopeId,
    required TagComment comment,
  });

  void removeCommentFromCache({
    required TagScopeId scopeId,
    required TagEntityId commentId,
  });

  void invalidateScopeCaches({
    required TagScopeId scopeId,
    bool full = true,
    bool parent = false,
    bool tag = true,
  });

  Future<List<TagComment>> loadComments({
    required TagScopeId scopeId,
    bool forceReload = false,
  });

  Future<List<TagComment>> loadParentComments({
    required TagScopeId scopeId,
    bool forceReload = false,
  });

  Future<List<TagComment>> loadTagComments({
    required TagScopeId scopeId,
    bool forceReload = false,
  });
}
