import 'package:tagging_core/tagging_core.dart';
import 'package:test/test.dart';

class _FakeGateway implements TaggingCommentGateway {
  final Map<TagScopeId, List<TagComment>> full =
      <TagScopeId, List<TagComment>>{};
  final Map<TagScopeId, List<TagComment>> parent =
      <TagScopeId, List<TagComment>>{};
  final Map<TagScopeId, List<TagComment>> tag =
      <TagScopeId, List<TagComment>>{};

  @override
  void appendCreatedComment({
    required TagScopeId scopeId,
    required TagComment comment,
  }) {
    final existing = tag[scopeId] ?? const <TagComment>[];
    if (comment.hasLocation) {
      tag[scopeId] = <TagComment>[...existing, comment];
    }
  }

  @override
  void invalidateScopeCaches({
    required TagScopeId scopeId,
    bool full = true,
    bool parent = false,
    bool tag = true,
  }) {}

  @override
  Future<List<TagComment>> loadComments({
    required TagScopeId scopeId,
    bool forceReload = false,
  }) async {
    return full[scopeId] ?? const <TagComment>[];
  }

  @override
  Future<List<TagComment>> loadParentComments({
    required TagScopeId scopeId,
    bool forceReload = false,
  }) async {
    return parent[scopeId] ?? const <TagComment>[];
  }

  @override
  Future<List<TagComment>> loadTagComments({
    required TagScopeId scopeId,
    bool forceReload = false,
  }) async {
    return tag[scopeId] ?? const <TagComment>[];
  }

  @override
  List<TagComment>? peekCommentsCache({required TagScopeId scopeId}) =>
      full[scopeId];

  @override
  List<TagComment>? peekParentCommentsCache({required TagScopeId scopeId}) =>
      parent[scopeId];

  @override
  List<TagComment>? peekTagCommentsCache({required TagScopeId scopeId}) =>
      tag[scopeId];

  @override
  TagThreadSnapshot peekThreadSnapshot({required TagScopeId scopeId}) {
    return TagThreadSnapshot(
      comments: full[scopeId],
      parentComments: parent[scopeId],
      tagComments: tag[scopeId],
    );
  }

  @override
  void removeCommentFromCache({
    required TagScopeId scopeId,
    required TagEntityId commentId,
  }) {
    tag[scopeId] = (tag[scopeId] ?? const <TagComment>[])
        .where((comment) => comment.id != commentId)
        .toList(growable: false);
  }

  @override
  void replaceCommentsCache({
    required TagScopeId scopeId,
    required List<TagComment> comments,
  }) {
    full[scopeId] = comments;
  }

  @override
  void replaceParentCommentsCache({
    required TagScopeId scopeId,
    required List<TagComment> comments,
  }) {
    parent[scopeId] = comments;
  }

  @override
  void replaceTagCommentsCache({
    required TagScopeId scopeId,
    required List<TagComment> comments,
  }) {
    tag[scopeId] = comments;
  }
}

class _FakeResolver implements TaggingMediaResolver {
  @override
  Future<String?> getPresignedUrl(String key) async => key;

  @override
  Future<List<String>> getPresignedUrls(List<String> keys) async => keys;

  @override
  String? peekPresignedUrl(String key) => key;
}

void main() {
  group('TaggingSessionController', () {
    test('stages drafts and resolves relative marker positions', () {
      final controller = TaggingSessionController(
        commentGateway: _FakeGateway(),
        mediaResolver: _FakeResolver(),
      );

      controller.stageTextDraft(
        scopeId: 'post:10',
        text: 'hello',
        author: const TagAuthor(id: '3', profileImageSource: 'profiles/me.png'),
      );

      controller.updatePendingMarkerFromAbsolutePosition(
        scopeId: 'post:10',
        absolutePosition: const TagPosition(x: 177, y: 125),
        imageSize: const TagViewportSize(width: 354, height: 500),
      );

      expect(controller.pendingDrafts['post:10']?.isTextComment, isTrue);
      expect(
        controller.resolveDropRelativePosition('post:10')?.x,
        closeTo(0.5, 0.001),
      );
      expect(
        controller.resolveDropRelativePosition('post:10')?.y,
        closeTo(0.25, 0.001),
      );
    });

    test(
      'appends saved comments into loaded tag cache and clears pending state',
      () {
        final gateway = _FakeGateway()
          ..replaceTagCommentsCache(
            scopeId: 'post:10',
            comments: const <TagComment>[],
          );
        final controller = TaggingSessionController(
          commentGateway: gateway,
          mediaResolver: _FakeResolver(),
        );

        controller.stageTextDraft(
          scopeId: 'post:10',
          text: 'hello',
          author: const TagAuthor(id: '3'),
        );
        controller.updatePendingMarkerFromAbsolutePosition(
          scopeId: 'post:10',
          absolutePosition: const TagPosition(x: 50, y: 60),
          imageSize: const TagViewportSize(width: 100, height: 100),
        );

        controller.handleCommentSaveSuccess(
          'post:10',
          const TagComment(
            id: '1',
            userId: '3',
            locationX: 0.5,
            locationY: 0.6,
            kind: TagCommentKind.text,
          ),
        );

        expect(controller.pendingDrafts.containsKey('post:10'), isFalse);
        expect(controller.pendingMarkers.containsKey('post:10'), isFalse);
        expect(controller.peekTagComments('post:10'), hasLength(1));
      },
    );
  });
}
