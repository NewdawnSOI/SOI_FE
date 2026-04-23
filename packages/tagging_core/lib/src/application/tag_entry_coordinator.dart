import '../domain/tag_models.dart';
import 'tag_query_port.dart';

/// overlay/thread 엔트리 조회와 in-flight dedupe를 scope 단위로 관리합니다.
class TagEntryCoordinator {
  TagEntryCoordinator({required TagQueryPort queryPort})
    : _queryPort = queryPort;

  final TagQueryPort _queryPort;
  final Map<TagScopeId, Future<List<TagEntry>>> _inFlightOverlayLoads =
      <TagScopeId, Future<List<TagEntry>>>{};
  final Map<TagScopeId, Future<List<TagEntry>>> _inFlightThreadLoads =
      <TagScopeId, Future<List<TagEntry>>>{};

  List<TagEntry> peekEntries(
    TagScopeId scopeId, {
    required TagEntryLoadMode mode,
  }) {
    return _queryPort.peekEntries(scopeId: scopeId, mode: mode) ??
        const <TagEntry>[];
  }

  TagEntrySnapshot peekSnapshot(TagScopeId scopeId) {
    return _queryPort.peekSnapshot(scopeId: scopeId);
  }

  void replaceEntries({
    required TagScopeId scopeId,
    required TagEntryLoadMode mode,
    required List<TagEntry> entries,
  }) {
    _queryPort.replaceEntries(scopeId: scopeId, mode: mode, entries: entries);
  }

  void appendCreatedEntry({
    required TagScopeId scopeId,
    required TagEntry entry,
  }) {
    _queryPort.appendCreatedEntry(scopeId: scopeId, entry: entry);
  }

  void removeEntryFromCache({
    required TagScopeId scopeId,
    required TagEntityId entryId,
  }) {
    _queryPort.removeEntryFromCache(scopeId: scopeId, entryId: entryId);
  }

  Future<void> loadOverlayEntriesForScopes(
    List<TagScopeId> scopeIds, {
    bool forceReload = false,
  }) async {
    final uniqueScopeIds = scopeIds
        .toSet()
        .where(
          (scopeId) => _shouldLoad(
            scopeId: scopeId,
            mode: TagEntryLoadMode.overlay,
            forceReload: forceReload,
          ),
        )
        .toList(growable: false);
    if (uniqueScopeIds.isEmpty) {
      return;
    }

    await Future.wait(
      uniqueScopeIds.map(
        (scopeId) => loadEntriesForScope(
          scopeId,
          mode: TagEntryLoadMode.overlay,
          forceReload: forceReload,
        ),
      ),
    );
  }

  Future<List<TagEntry>> loadOverlayEntriesForScope(
    TagScopeId scopeId, {
    bool forceReload = false,
  }) {
    return loadEntriesForScope(
      scopeId,
      mode: TagEntryLoadMode.overlay,
      forceReload: forceReload,
    );
  }

  Future<List<TagEntry>> loadThreadEntriesForScope(
    TagScopeId scopeId, {
    bool forceReload = false,
  }) {
    return loadEntriesForScope(
      scopeId,
      mode: TagEntryLoadMode.thread,
      forceReload: forceReload,
    );
  }

  Future<List<TagEntry>> loadEntriesForScope(
    TagScopeId scopeId, {
    required TagEntryLoadMode mode,
    bool forceReload = false,
  }) async {
    if (!forceReload) {
      final cached = _queryPort.peekEntries(scopeId: scopeId, mode: mode);
      if (cached != null &&
          _queryPort.hasHydratedEntries(scopeId: scopeId, mode: mode)) {
        return cached;
      }

      final inFlight = _inFlightMapFor(mode)[scopeId];
      if (inFlight != null) {
        return inFlight;
      }
    }

    final future = () async {
      try {
        final entries = await _queryPort.loadEntries(
          scopeId: scopeId,
          mode: mode,
          forceReload: forceReload,
        );
        _queryPort.replaceEntries(scopeId: scopeId, mode: mode, entries: entries);
        return _queryPort.peekEntries(scopeId: scopeId, mode: mode) ?? entries;
      } catch (_) {
        return _queryPort.peekEntries(scopeId: scopeId, mode: mode) ??
            const <TagEntry>[];
      }
    }();

    _inFlightMapFor(mode)[scopeId] = future;
    try {
      return await future;
    } finally {
      final inFlightMap = _inFlightMapFor(mode);
      final registered = inFlightMap[scopeId];
      if (identical(registered, future)) {
        inFlightMap.remove(scopeId);
      }
    }
  }

  void clearScopeState(TagScopeId scopeId) {
    _inFlightOverlayLoads.remove(scopeId);
    _inFlightThreadLoads.remove(scopeId);
  }

  void dispose() {
    _inFlightOverlayLoads.clear();
    _inFlightThreadLoads.clear();
  }

  bool _shouldLoad({
    required TagScopeId scopeId,
    required TagEntryLoadMode mode,
    required bool forceReload,
  }) {
    final cached = _queryPort.peekEntries(scopeId: scopeId, mode: mode);
    return forceReload ||
        cached == null ||
        !_queryPort.hasHydratedEntries(scopeId: scopeId, mode: mode);
  }

  Map<TagScopeId, Future<List<TagEntry>>> _inFlightMapFor(
    TagEntryLoadMode mode,
  ) {
    return switch (mode) {
      TagEntryLoadMode.overlay => _inFlightOverlayLoads,
      TagEntryLoadMode.thread => _inFlightThreadLoads,
    };
  }
}
