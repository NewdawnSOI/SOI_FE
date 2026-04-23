import '../domain/tag_models.dart';
import '../domain/tag_position_math.dart';
import '../domain/tag_save_request.dart';

/// draft와 pending anchor를 scope 단위로 보관하고 저장 요청 생성을 돕습니다.
class TagDraftSessionController {
  final Map<TagScopeId, TagDraft> _pendingDrafts = <TagScopeId, TagDraft>{};
  final Map<TagScopeId, TagPendingMarker> _pendingMarkers =
      <TagScopeId, TagPendingMarker>{};

  Map<TagScopeId, TagDraft> get pendingDrafts => _pendingDrafts;

  Map<TagScopeId, TagPendingMarker> get pendingMarkers => _pendingMarkers;

  void stageDraft({required TagScopeId scopeId, required TagDraft draft}) {
    _pendingDrafts[scopeId] = draft;
  }

  TagSaveRequest? buildSaveRequest(TagScopeId scopeId) {
    final draft = _pendingDrafts[scopeId];
    if (draft == null) {
      return null;
    }

    return TagSaveRequest(
      scopeId: scopeId,
      actorId: draft.actorId,
      content: draft.content,
      parentEntryId: draft.parentEntryId,
      anchor: _pendingMarkers[scopeId]?.relativePosition,
      metadata: draft.metadata,
    );
  }

  TagPosition? resolveDropRelativePosition(TagScopeId scopeId) {
    return _pendingMarkers[scopeId]?.relativePosition;
  }

  void updatePendingMarkerFromAbsolutePosition({
    required TagScopeId scopeId,
    required TagPosition absolutePosition,
    required TagViewportSize viewportSize,
  }) {
    final draft = _pendingDrafts[scopeId];
    if (draft == null || viewportSize.width <= 0 || viewportSize.height <= 0) {
      return;
    }

    final previousProgress = _pendingMarkers[scopeId]?.progress;
    _pendingMarkers[scopeId] = TagPendingMarker(
      relativePosition: TagPositionMath.normalizeAbsolutePosition(
        absolutePosition: absolutePosition,
        viewportSize: viewportSize,
      ),
      progress: previousProgress,
    );
  }

  void updatePendingProgress(TagScopeId scopeId, double progress) {
    final marker = _pendingMarkers[scopeId];
    if (marker == null) {
      return;
    }

    _pendingMarkers[scopeId] = marker.copyWith(
      progress: progress.clamp(0.0, 1.0).toDouble(),
    );
  }

  void handleSaveSuccess(TagScopeId scopeId) {
    _pendingDrafts.remove(scopeId);
    _pendingMarkers.remove(scopeId);
  }

  void handleSaveFailure(TagScopeId scopeId) {
    final marker = _pendingMarkers[scopeId];
    if (marker == null) {
      return;
    }
    _pendingMarkers[scopeId] = marker.copyWith(clearProgress: true);
  }

  void clearScopeState(TagScopeId scopeId) {
    _pendingDrafts.remove(scopeId);
    _pendingMarkers.remove(scopeId);
  }

  void dispose() {
    _pendingDrafts.clear();
    _pendingMarkers.clear();
  }
}
