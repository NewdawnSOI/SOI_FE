import 'package:tagging_core/tagging_core.dart';
import 'package:test/test.dart';

class _FakeQueryPort implements TagQueryPort {
  final Map<TagScopeId, List<TagEntry>> overlay =
      <TagScopeId, List<TagEntry>>{};
  final Map<TagScopeId, List<TagEntry>> thread = <TagScopeId, List<TagEntry>>{};
  final Map<TagScopeId, List<TagEntry>> overlayLoadResponses =
      <TagScopeId, List<TagEntry>>{};
  final Set<TagScopeId> hydratedOverlayScopes = <TagScopeId>{};
  int loadOverlayCallCount = 0;

  @override
  void appendCreatedEntry({
    required TagScopeId scopeId,
    required TagEntry entry,
  }) {
    final existing = overlay[scopeId] ?? const <TagEntry>[];
    if (entry.hasAnchor) {
      overlay[scopeId] = <TagEntry>[...existing, entry];
    }
  }

  @override
  void invalidateScope({
    required TagScopeId scopeId,
    bool overlay = true,
    bool thread = true,
  }) {}

  @override
  Future<List<TagEntry>> loadEntries({
    required TagScopeId scopeId,
    required TagEntryLoadMode mode,
    bool forceReload = false,
  }) async {
    if (mode == TagEntryLoadMode.overlay) {
      loadOverlayCallCount += 1;
      final response =
          overlayLoadResponses[scopeId] ??
          overlay[scopeId] ??
          const <TagEntry>[];
      overlay[scopeId] = response;
      hydratedOverlayScopes.add(scopeId);
      return response;
    }

    return thread[scopeId] ?? const <TagEntry>[];
  }

  @override
  TagEntrySnapshot peekSnapshot({required TagScopeId scopeId}) {
    return TagEntrySnapshot(
      overlayEntries: overlay[scopeId],
      threadEntries: thread[scopeId],
    );
  }

  @override
  List<TagEntry>? peekEntries({
    required TagScopeId scopeId,
    required TagEntryLoadMode mode,
  }) => mode == TagEntryLoadMode.overlay ? overlay[scopeId] : thread[scopeId];

  @override
  bool hasHydratedEntries({
    required TagScopeId scopeId,
    required TagEntryLoadMode mode,
  }) {
    return mode == TagEntryLoadMode.overlay
        ? hydratedOverlayScopes.contains(scopeId)
        : thread.containsKey(scopeId);
  }

  @override
  void removeEntryFromCache({
    required TagScopeId scopeId,
    required TagEntityId entryId,
  }) {
    overlay[scopeId] = (overlay[scopeId] ?? const <TagEntry>[])
        .where((entry) => entry.id != entryId)
        .toList(growable: false);
    hydratedOverlayScopes.remove(scopeId);
  }

  @override
  void replaceEntries({
    required TagScopeId scopeId,
    required TagEntryLoadMode mode,
    required List<TagEntry> entries,
  }) {
    if (mode == TagEntryLoadMode.overlay) {
      overlay[scopeId] = entries;
      hydratedOverlayScopes.add(scopeId);
      return;
    }

    thread[scopeId] = entries;
  }
}

void main() {
  group('TaggingSessionController', () {
    test('stages drafts and resolves relative marker positions', () {
      final controller = TaggingSessionController(queryPort: _FakeQueryPort());

      controller.stageDraft(
        scopeId: 'post:10',
        draft: const TagDraft(
          actorId: '3',
          content: TagContent.text('hello'),
          metadata: <String, Object?>{'profileImageSource': 'profiles/me.png'},
        ),
      );

      controller.updatePendingMarkerFromAbsolutePosition(
        scopeId: 'post:10',
        absolutePosition: const TagPosition(x: 177, y: 125),
        viewportSize: const TagViewportSize(width: 354, height: 500),
      );

      expect(controller.pendingDrafts['post:10']?.content.isText, isTrue);
      expect(
        controller.resolveDropRelativePosition('post:10')?.x,
        closeTo(0.5, 0.001),
      );
      expect(
        controller.resolveDropRelativePosition('post:10')?.y,
        closeTo(0.25, 0.001),
      );
    });

    test('appends saved entries into loaded overlay cache and clears pending state', () {
      final queryPort = _FakeQueryPort()
        ..replaceEntries(
          scopeId: 'post:10',
          mode: TagEntryLoadMode.overlay,
          entries: const <TagEntry>[],
        );
      final controller = TaggingSessionController(queryPort: queryPort);

      controller.stageDraft(
        scopeId: 'post:10',
        draft: const TagDraft(
          actorId: '3',
          content: TagContent.text('hello'),
        ),
      );
      controller.updatePendingMarkerFromAbsolutePosition(
        scopeId: 'post:10',
        absolutePosition: const TagPosition(x: 50, y: 60),
        viewportSize: const TagViewportSize(width: 100, height: 100),
      );

      controller.handleSaveSuccess(
        'post:10',
        const TagEntry(
          id: '1',
          scopeId: 'post:10',
          actorId: '3',
          anchor: TagPosition(x: 0.5, y: 0.6),
          content: TagContent.text('hello'),
        ),
      );

      expect(controller.pendingDrafts.containsKey('post:10'), isFalse);
      expect(controller.pendingMarkers.containsKey('post:10'), isFalse);
      expect(controller.peekOverlayEntries('post:10'), hasLength(1));
    });

    test('reloads overlay entries when only a provisional local cache exists', () async {
      final queryPort = _FakeQueryPort()
        ..overlay['post:10'] = const <TagEntry>[
          TagEntry(
            id: '1',
            scopeId: 'post:10',
            actorId: '3',
            anchor: TagPosition(x: 0.5, y: 0.6),
            content: TagContent.text('first'),
          ),
        ]
        ..overlayLoadResponses['post:10'] = const <TagEntry>[
          TagEntry(
            id: '1',
            scopeId: 'post:10',
            actorId: '3',
            anchor: TagPosition(x: 0.5, y: 0.6),
            content: TagContent.text('first'),
          ),
          TagEntry(
            id: '2',
            scopeId: 'post:10',
            actorId: '7',
            anchor: TagPosition(x: 0.2, y: 0.4),
            content: TagContent.text('second'),
          ),
        ];
      final controller = TaggingSessionController(queryPort: queryPort);

      await controller.loadOverlayEntriesForScope('post:10');

      expect(queryPort.loadOverlayCallCount, 1);
      expect(
        controller.peekOverlayEntries('post:10').map((comment) => comment.id),
        ['1', '2'],
      );
    });
  });
}
