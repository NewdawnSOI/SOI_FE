import '../domain/tag_models.dart';

/// core가 overlay/thread 엔트리 캐시와 로드를 다루기 위해 기대하는 최소 query 계약입니다.
enum TagEntryLoadMode { overlay, thread }

/// 서비스별 저장소가 core와 주고받는 엔트리 조회/캐시 인터페이스입니다.
abstract class TagQueryPort {
  TagEntrySnapshot peekSnapshot({required TagScopeId scopeId});

  List<TagEntry>? peekEntries({
    required TagScopeId scopeId,
    required TagEntryLoadMode mode,
  });

  bool hasHydratedEntries({
    required TagScopeId scopeId,
    required TagEntryLoadMode mode,
  });

  void replaceEntries({
    required TagScopeId scopeId,
    required TagEntryLoadMode mode,
    required List<TagEntry> entries,
  });

  void appendCreatedEntry({
    required TagScopeId scopeId,
    required TagEntry entry,
  });

  void removeEntryFromCache({
    required TagScopeId scopeId,
    required TagEntityId entryId,
  });

  void invalidateScope({
    required TagScopeId scopeId,
    bool overlay = true,
    bool thread = true,
  });

  Future<List<TagEntry>> loadEntries({
    required TagScopeId scopeId,
    required TagEntryLoadMode mode,
    bool forceReload = false,
  });
}
