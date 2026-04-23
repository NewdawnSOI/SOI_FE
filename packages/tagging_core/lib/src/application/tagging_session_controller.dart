import '../domain/tag_models.dart';
import '../domain/tag_save_request.dart';
import 'tag_draft_session_controller.dart';
import 'tag_entry_coordinator.dart';
import 'tag_query_port.dart';

typedef TaggingListener = void Function();

/// draft 세션과 엔트리 조회를 묶어 플랫폼이 한 객체로 태깅 흐름을 다루게 합니다.
class TaggingSessionController {
  TaggingSessionController({required TagQueryPort queryPort})
    : _draftSession = TagDraftSessionController(),
      _entryCoordinator = TagEntryCoordinator(queryPort: queryPort);

  final TagDraftSessionController _draftSession;
  final TagEntryCoordinator _entryCoordinator;
  final Set<TaggingListener> _listeners = <TaggingListener>{};

  Map<TagScopeId, TagDraft> get pendingDrafts => _draftSession.pendingDrafts;

  Map<TagScopeId, TagPendingMarker> get pendingMarkers =>
      _draftSession.pendingMarkers;

  void addListener(TaggingListener listener) {
    _listeners.add(listener);
  }

  void removeListener(TaggingListener listener) {
    _listeners.remove(listener);
  }

  void stageDraft({required TagScopeId scopeId, required TagDraft draft}) {
    _draftSession.stageDraft(scopeId: scopeId, draft: draft);
    _notifyListeners();
  }

  TagSaveRequest? buildSaveRequest(TagScopeId scopeId) {
    return _draftSession.buildSaveRequest(scopeId);
  }

  TagPosition? resolveDropRelativePosition(TagScopeId scopeId) {
    return _draftSession.resolveDropRelativePosition(scopeId);
  }

  void updatePendingMarkerFromAbsolutePosition({
    required TagScopeId scopeId,
    required TagPosition absolutePosition,
    required TagViewportSize viewportSize,
  }) {
    _draftSession.updatePendingMarkerFromAbsolutePosition(
      scopeId: scopeId,
      absolutePosition: absolutePosition,
      viewportSize: viewportSize,
    );
    _notifyListeners();
  }

  void updatePendingProgress(TagScopeId scopeId, double progress) {
    _draftSession.updatePendingProgress(scopeId, progress);
    _notifyListeners();
  }

  List<TagEntry> peekOverlayEntries(TagScopeId scopeId) {
    return _entryCoordinator.peekEntries(
      scopeId,
      mode: TagEntryLoadMode.overlay,
    );
  }

  List<TagEntry> peekThreadEntries(TagScopeId scopeId) {
    return _entryCoordinator.peekEntries(scopeId, mode: TagEntryLoadMode.thread);
  }

  TagEntrySnapshot peekSnapshot(TagScopeId scopeId) {
    return _entryCoordinator.peekSnapshot(scopeId);
  }

  void replaceOverlayEntries(TagScopeId scopeId, List<TagEntry> entries) {
    _entryCoordinator.replaceEntries(
      scopeId: scopeId,
      mode: TagEntryLoadMode.overlay,
      entries: entries,
    );
    _notifyListeners();
  }

  void replaceThreadEntries(TagScopeId scopeId, List<TagEntry> entries) {
    _entryCoordinator.replaceEntries(
      scopeId: scopeId,
      mode: TagEntryLoadMode.thread,
      entries: entries,
    );
    _notifyListeners();
  }

  void removeEntryFromCache({
    required TagScopeId scopeId,
    required TagEntityId entryId,
  }) {
    _entryCoordinator.removeEntryFromCache(scopeId: scopeId, entryId: entryId);
    _notifyListeners();
  }

  Future<void> loadOverlayEntriesForScopes(
    List<TagScopeId> scopeIds, {
    bool forceReload = false,
  }) async {
    await _entryCoordinator.loadOverlayEntriesForScopes(
      scopeIds,
      forceReload: forceReload,
    );
    _notifyListeners();
  }

  Future<List<TagEntry>> loadOverlayEntriesForScope(
    TagScopeId scopeId, {
    bool forceReload = false,
  }) async {
    final entries = await _entryCoordinator.loadOverlayEntriesForScope(
      scopeId,
      forceReload: forceReload,
    );
    _notifyListeners();
    return entries;
  }

  Future<List<TagEntry>> loadThreadEntriesForScope(
    TagScopeId scopeId, {
    bool forceReload = false,
  }) async {
    final entries = await _entryCoordinator.loadThreadEntriesForScope(
      scopeId,
      forceReload: forceReload,
    );
    _notifyListeners();
    return entries;
  }

  /// 저장 성공 시 pending 상태를 비우고 이미 가진 overlay/thread cache에는 새 엔트리를 즉시 반영합니다.
  void handleSaveSuccess(TagScopeId scopeId, TagEntry entry) {
    _entryCoordinator.appendCreatedEntry(scopeId: scopeId, entry: entry);
    _draftSession.handleSaveSuccess(scopeId);
    _notifyListeners();
  }

  void handleSaveFailure(TagScopeId scopeId) {
    _draftSession.handleSaveFailure(scopeId);
    _notifyListeners();
  }

  void clearScopeState(TagScopeId scopeId) {
    _draftSession.clearScopeState(scopeId);
    _entryCoordinator.clearScopeState(scopeId);
    _notifyListeners();
  }

  void dispose() {
    _listeners.clear();
    _draftSession.dispose();
    _entryCoordinator.dispose();
  }

  void _notifyListeners() {
    for (final listener in _listeners.toList(growable: false)) {
      listener();
    }
  }
}
