import 'dart:async';

import '../domain/tag_models.dart';
import '../domain/tag_position_math.dart';
import 'tagging_comment_gateway.dart';
import 'tagging_media_resolver.dart';

typedef TaggingListener = void Function();

/// 태깅 세션의 draft, marker, cache hydrate 규칙을 콘텐츠 scope 단위로 관리합니다.
class TaggingSessionController {
  TaggingSessionController({
    required TaggingCommentGateway commentGateway,
    required TaggingMediaResolver mediaResolver,
    String? Function()? currentUserHandleResolver,
  }) : _commentGateway = commentGateway,
       _mediaResolver = mediaResolver,
       _currentUserHandleResolver = currentUserHandleResolver;

  final TaggingCommentGateway _commentGateway;
  final TaggingMediaResolver _mediaResolver;
  final String? Function()? _currentUserHandleResolver;
  final Set<TaggingListener> _listeners = <TaggingListener>{};

  final Map<TagScopeId, TagDraft> _pendingDrafts = <TagScopeId, TagDraft>{};
  final Map<TagScopeId, TagPendingMarker> _pendingMarkers =
      <TagScopeId, TagPendingMarker>{};
  final Map<TagScopeId, String?> _selectedEmojisByScopeId =
      <TagScopeId, String?>{};
  final Map<TagScopeId, Future<List<TagComment>>> _inFlightParentCommentLoads =
      <TagScopeId, Future<List<TagComment>>>{};
  final Map<TagScopeId, Future<void>> _inFlightTagCommentLoads =
      <TagScopeId, Future<void>>{};
  final Map<TagScopeId, Future<List<TagComment>>> _inFlightFullCommentLoads =
      <TagScopeId, Future<List<TagComment>>>{};

  Map<TagScopeId, TagDraft> get pendingDrafts => _pendingDrafts;

  Map<TagScopeId, TagPendingMarker> get pendingMarkers => _pendingMarkers;

  Map<TagScopeId, String?> get selectedEmojisByScopeId =>
      _selectedEmojisByScopeId;

  void addListener(TaggingListener listener) {
    _listeners.add(listener);
  }

  void removeListener(TaggingListener listener) {
    _listeners.remove(listener);
  }

  void setSelectedEmoji(TagScopeId scopeId, String? emoji) {
    if (emoji == null) {
      _selectedEmojisByScopeId.remove(scopeId);
    } else {
      _selectedEmojisByScopeId[scopeId] = emoji;
    }
    _notifyListeners();
  }

  /// 댓글 시트가 즉시 돌려준 full thread를 현재 사용자 기준 선택 이모지 상태와 맞춥니다.
  void syncSelectedEmojiFromComments(
    TagScopeId scopeId,
    List<TagComment> comments,
  ) {
    _syncSelectedEmojiFromComments(scopeId, comments);
    _notifyListeners();
  }

  /// 댓글 시트가 돌려준 full thread를 session cache와 선택 이모지 상태에 함께 반영합니다.
  void replaceCommentsCache(TagScopeId scopeId, List<TagComment> comments) {
    _commentGateway.replaceCommentsCache(scopeId: scopeId, comments: comments);
    _syncSelectedEmojiFromComments(scopeId, comments);
    _notifyListeners();
  }

  /// overlay 삭제 직후에는 로컬 tag cache에서 먼저 제거한 뒤 reload로 서버 상태를 맞춥니다.
  void removeCommentFromCache({
    required TagScopeId scopeId,
    required TagEntityId commentId,
  }) {
    _commentGateway.removeCommentFromCache(
      scopeId: scopeId,
      commentId: commentId,
    );
    final fullComments = _commentGateway.peekCommentsCache(scopeId: scopeId);
    if (fullComments != null) {
      _syncSelectedEmojiFromComments(scopeId, fullComments);
    }
    _notifyListeners();
  }

  List<TagComment> peekComments(TagScopeId scopeId) {
    return _commentGateway.peekCommentsCache(scopeId: scopeId) ??
        const <TagComment>[];
  }

  List<TagComment> peekParentComments(TagScopeId scopeId) {
    return _commentGateway.peekParentCommentsCache(scopeId: scopeId) ??
        const <TagComment>[];
  }

  List<TagComment> peekTagComments(TagScopeId scopeId) {
    return _commentGateway.peekTagCommentsCache(scopeId: scopeId) ??
        const <TagComment>[];
  }

  TagThreadSnapshot peekThreadSnapshot(TagScopeId scopeId) {
    return _commentGateway.peekThreadSnapshot(scopeId: scopeId);
  }

  /// 텍스트 입력이 끝난 시점의 draft를 저장해 이후 배치/저장을 이어갑니다.
  void stageTextDraft({
    required TagScopeId scopeId,
    required String text,
    required TagAuthor author,
  }) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return;
    }

    _pendingDrafts[scopeId] = TagDraft(
      kind: TagDraftKind.text,
      text: trimmedText,
      recorderUserId: author.id,
      profileImageSource: author.profileImageSource,
    );
    _notifyListeners();
  }

  /// 오디오 녹음 결과를 draft로 저장해 이후 위치 배치와 업로드를 분리합니다.
  void stageAudioDraft({
    required TagScopeId scopeId,
    required String audioPath,
    required List<double> waveformData,
    required int durationMs,
    required TagAuthor author,
  }) {
    if (audioPath.trim().isEmpty) {
      return;
    }

    _pendingDrafts[scopeId] = TagDraft(
      kind: TagDraftKind.audio,
      audioPath: audioPath,
      waveformData: waveformData,
      durationMs: durationMs,
      recorderUserId: author.id,
      profileImageSource: author.profileImageSource,
    );
    _notifyListeners();
  }

  /// 미디어 선택 결과를 draft로 저장해 드래그 배치 후 저장하도록 만듭니다.
  void stageMediaDraft({
    required TagScopeId scopeId,
    required String localFilePath,
    required bool isVideo,
    required TagAuthor author,
  }) {
    final trimmedPath = localFilePath.trim();
    if (trimmedPath.isEmpty) {
      return;
    }

    _pendingDrafts[scopeId] = TagDraft(
      kind: isVideo ? TagDraftKind.video : TagDraftKind.image,
      mediaPath: trimmedPath,
      recorderUserId: author.id,
      profileImageSource: author.profileImageSource,
    );
    _notifyListeners();
  }

  TagPosition? resolveDropRelativePosition(TagScopeId scopeId) {
    return _pendingMarkers[scopeId]?.relativePosition;
  }

  /// 드래그된 pending 태그를 표시 영역 비율 좌표로 정규화해 재사용 가능한 marker로 저장합니다.
  void updatePendingMarkerFromAbsolutePosition({
    required TagScopeId scopeId,
    required TagPosition absolutePosition,
    required TagViewportSize imageSize,
  }) {
    final draft = _pendingDrafts[scopeId];
    if (draft == null || imageSize.width <= 0 || imageSize.height <= 0) {
      return;
    }

    final previousProgress = _pendingMarkers[scopeId]?.progress;
    _pendingMarkers[scopeId] = TagPendingMarker(
      relativePosition: TagPositionMath.normalizeAbsolutePosition(
        absolutePosition: absolutePosition,
        viewportSize: imageSize,
      ),
      profileImageSource: draft.profileImageSource,
      progress: previousProgress,
    );
    _notifyListeners();
  }

  void updatePendingProgress(TagScopeId scopeId, double progress) {
    final marker = _pendingMarkers[scopeId];
    if (marker == null) {
      return;
    }

    _pendingMarkers[scopeId] = marker.copyWith(
      progress: progress.clamp(0.0, 1.0).toDouble(),
    );
    _notifyListeners();
  }

  /// 저장 성공 시 pending 상태를 비우고 이미 로드한 cache에는 새 태그를 즉시 반영합니다.
  void handleCommentSaveSuccess(TagScopeId scopeId, TagComment comment) {
    _commentGateway.appendCreatedComment(scopeId: scopeId, comment: comment);
    _pendingDrafts.remove(scopeId);
    _pendingMarkers.remove(scopeId);
    final fullComments = _commentGateway.peekCommentsCache(scopeId: scopeId);
    if (fullComments != null) {
      _syncSelectedEmojiFromComments(scopeId, fullComments);
    }
    _notifyListeners();
  }

  void handleCommentSaveFailure(TagScopeId scopeId) {
    final marker = _pendingMarkers[scopeId];
    if (marker != null) {
      _pendingMarkers[scopeId] = marker.copyWith(clearProgress: true);
    }
    _notifyListeners();
  }

  /// 같은 콘텐츠 범위를 공유하는 transient tagging state를 한 번에 정리합니다.
  void clearScopeState(TagScopeId scopeId) {
    _pendingDrafts.remove(scopeId);
    _pendingMarkers.remove(scopeId);
    _selectedEmojisByScopeId.remove(scopeId);
    _inFlightParentCommentLoads.remove(scopeId);
    _inFlightTagCommentLoads.remove(scopeId);
    _inFlightFullCommentLoads.remove(scopeId);
    _notifyListeners();
  }

  /// tag overlay 로드는 로컬 임시 cache를 그대로 신뢰하지 않고, hydrate 여부까지 확인합니다.
  Future<void> loadTagCommentsForScopes(
    List<TagScopeId> scopeIds, {
    bool forceReload = false,
  }) async {
    final uniqueScopeIds = scopeIds
        .toSet()
        .where((scopeId) {
          final cached = _commentGateway.peekTagCommentsCache(scopeId: scopeId);
          return forceReload ||
              cached == null ||
              !_commentGateway.hasHydratedTagCommentsCache(scopeId: scopeId) ||
              _needsProfileImageResolution(cached);
        })
        .toList(growable: false);
    if (uniqueScopeIds.isEmpty) {
      return;
    }

    await Future.wait(
      uniqueScopeIds.map(
        (scopeId) =>
            _loadTagCommentsForScopeInternal(scopeId, forceReload: forceReload),
      ),
    );
  }

  Future<void> loadTagCommentsForScope(
    TagScopeId scopeId, {
    bool forceReload = false,
  }) async {
    await loadTagCommentsForScopes([scopeId], forceReload: forceReload);
  }

  Future<void> loadParentCommentsForScopes(
    List<TagScopeId> scopeIds, {
    bool forceReload = false,
  }) async {
    final uniqueScopeIds = scopeIds
        .toSet()
        .where((scopeId) {
          final cached = _commentGateway.peekParentCommentsCache(
            scopeId: scopeId,
          );
          return forceReload ||
              cached == null ||
              _needsProfileImageResolution(cached);
        })
        .toList(growable: false);
    if (uniqueScopeIds.isEmpty) {
      return;
    }

    await Future.wait(
      uniqueScopeIds.map(
        (scopeId) => _loadParentCommentsForScopeInternal(
          scopeId,
          forceReload: forceReload,
        ),
      ),
    );
  }

  Future<List<TagComment>> loadParentCommentsForScope(
    TagScopeId scopeId, {
    bool forceReload = false,
  }) async {
    return _loadParentCommentsForScopeInternal(
      scopeId,
      forceReload: forceReload,
    );
  }

  Future<List<TagComment>> loadCommentsForScope(
    TagScopeId scopeId, {
    bool forceReload = false,
  }) async {
    if (!forceReload) {
      final cached = _commentGateway.peekCommentsCache(scopeId: scopeId);
      if (cached != null) {
        final resolved = await _resolveAndStoreCommentsIfNeeded(
          scopeId: scopeId,
          comments: cached,
          tagOnly: false,
        );
        _syncSelectedEmojiFromComments(scopeId, resolved);
        _notifyListeners();
        return resolved;
      }

      final inFlight = _inFlightFullCommentLoads[scopeId];
      if (inFlight != null) {
        return inFlight;
      }
    }

    final future = _loadFullCommentsForScopeInternal(
      scopeId,
      forceReload: forceReload,
    );
    _inFlightFullCommentLoads[scopeId] = future;
    try {
      return await future;
    } finally {
      final registered = _inFlightFullCommentLoads[scopeId];
      if (identical(registered, future)) {
        _inFlightFullCommentLoads.remove(scopeId);
      }
    }
  }

  Future<List<TagComment>> _loadParentCommentsForScopeInternal(
    TagScopeId scopeId, {
    required bool forceReload,
  }) async {
    if (!forceReload) {
      final inFlight = _inFlightParentCommentLoads[scopeId];
      if (inFlight != null) {
        return inFlight;
      }
    }

    final future = () async {
      final comments = await _commentGateway.loadParentComments(
        scopeId: scopeId,
        forceReload: forceReload,
      );
      final resolvedComments = await _resolveCommentProfileImages(comments);
      _commentGateway.replaceParentCommentsCache(
        scopeId: scopeId,
        comments: resolvedComments,
      );
      _syncSelectedEmojiFromComments(scopeId, resolvedComments);
      _notifyListeners();
      return resolvedComments;
    }();

    _inFlightParentCommentLoads[scopeId] = future;
    try {
      return await future;
    } catch (_) {
      return _commentGateway.peekParentCommentsCache(scopeId: scopeId) ??
          const <TagComment>[];
    } finally {
      final registered = _inFlightParentCommentLoads[scopeId];
      if (identical(registered, future)) {
        _inFlightParentCommentLoads.remove(scopeId);
      }
    }
  }

  Future<void> _loadTagCommentsForScopeInternal(
    TagScopeId scopeId, {
    required bool forceReload,
  }) async {
    if (!forceReload) {
      final inFlight = _inFlightTagCommentLoads[scopeId];
      if (inFlight != null) {
        return inFlight;
      }
    }

    final future = () async {
      final cached = forceReload
          ? null
          : _commentGateway.peekTagCommentsCache(scopeId: scopeId);
      final shouldReuseCached =
          cached != null &&
          _commentGateway.hasHydratedTagCommentsCache(scopeId: scopeId);
      final comments = shouldReuseCached
          ? cached
          : await _commentGateway.loadTagComments(
              scopeId: scopeId,
              forceReload: forceReload,
            );
      await _resolveAndStoreCommentsIfNeeded(
        scopeId: scopeId,
        comments: comments,
        tagOnly: true,
      );
      _notifyListeners();
    }();

    _inFlightTagCommentLoads[scopeId] = future;
    try {
      await future;
    } finally {
      final registered = _inFlightTagCommentLoads[scopeId];
      if (identical(registered, future)) {
        _inFlightTagCommentLoads.remove(scopeId);
      }
    }
  }

  Future<List<TagComment>> _loadFullCommentsForScopeInternal(
    TagScopeId scopeId, {
    required bool forceReload,
  }) async {
    try {
      final comments = await _commentGateway.loadComments(
        scopeId: scopeId,
        forceReload: forceReload,
      );
      final resolvedComments = await _resolveCommentProfileImages(comments);
      _commentGateway.replaceCommentsCache(
        scopeId: scopeId,
        comments: resolvedComments,
      );
      _syncSelectedEmojiFromComments(scopeId, resolvedComments);
      _notifyListeners();
      return resolvedComments;
    } catch (_) {
      return _commentGateway.peekCommentsCache(scopeId: scopeId) ??
          const <TagComment>[];
    }
  }

  Future<List<TagComment>> _resolveAndStoreCommentsIfNeeded({
    required TagScopeId scopeId,
    required List<TagComment> comments,
    required bool tagOnly,
  }) async {
    if (!_needsProfileImageResolution(comments)) {
      return comments;
    }

    final resolvedComments = await _resolveCommentProfileImages(comments);
    if (tagOnly) {
      _commentGateway.replaceTagCommentsCache(
        scopeId: scopeId,
        comments: resolvedComments,
      );
      return _commentGateway.peekTagCommentsCache(scopeId: scopeId) ??
          resolvedComments;
    }

    _commentGateway.replaceCommentsCache(
      scopeId: scopeId,
      comments: resolvedComments,
    );
    return _commentGateway.peekCommentsCache(scopeId: scopeId) ??
        resolvedComments;
  }

  Future<List<TagComment>> _resolveCommentProfileImages(
    List<TagComment> comments,
  ) async {
    if (comments.isEmpty) {
      return comments;
    }

    final resolvedUrlsByKey = <String, String>{};
    final keysToResolve = <String>[];
    final seenKeys = <String>{};

    for (final comment in comments) {
      final profileKey = _extractCommentProfileKey(comment);
      if (profileKey == null) {
        continue;
      }

      final cachedUrl = _mediaResolver.peekPresignedUrl(profileKey);
      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        resolvedUrlsByKey[profileKey] = cachedUrl;
        continue;
      }

      if (seenKeys.add(profileKey)) {
        keysToResolve.add(profileKey);
      }
    }

    if (keysToResolve.isNotEmpty) {
      final resolvedUrls = await _mediaResolver.getPresignedUrls(keysToResolve);
      final upperBound = keysToResolve.length < resolvedUrls.length
          ? keysToResolve.length
          : resolvedUrls.length;
      for (var index = 0; index < upperBound; index++) {
        final resolvedUrl = resolvedUrls[index].trim();
        if (resolvedUrl.isEmpty) {
          continue;
        }
        resolvedUrlsByKey[keysToResolve[index]] = resolvedUrl;
      }
    }

    return comments
        .map((comment) {
          final profileKey = _extractCommentProfileKey(comment);
          if (profileKey == null) {
            return comment;
          }

          final originalUrl = (comment.userProfileUrl ?? '').trim();
          final resolvedUrl = resolvedUrlsByKey[profileKey];
          final nextUrl = (resolvedUrl != null && resolvedUrl.isNotEmpty)
              ? resolvedUrl
              : originalUrl;
          final originalKey = (comment.userProfileKey ?? '').trim();
          final nextKey = originalKey.isNotEmpty ? originalKey : profileKey;

          if (nextUrl == originalUrl && nextKey == originalKey) {
            return comment;
          }

          return comment.copyWith(
            userProfileUrl: nextUrl.isEmpty ? profileKey : nextUrl,
            userProfileKey: nextKey,
          );
        })
        .toList(growable: false);
  }

  void _syncSelectedEmojiFromComments(
    TagScopeId scopeId,
    List<TagComment> comments,
  ) {
    final currentUserHandle = _currentUserHandleResolver?.call();
    if (currentUserHandle == null) {
      return;
    }

    final selected = _selectedEmojiFromComments(
      comments: comments,
      currentUserHandle: currentUserHandle,
    );
    if (selected == null) {
      _selectedEmojisByScopeId.remove(scopeId);
      return;
    }
    _selectedEmojisByScopeId[scopeId] = selected;
  }

  String? _selectedEmojiFromComments({
    required List<TagComment> comments,
    required String currentUserHandle,
  }) {
    for (final comment in comments.reversed) {
      if (comment.emojiId == null || comment.emojiId == 0) {
        continue;
      }
      if (comment.nickname != currentUserHandle) {
        continue;
      }
      return _emojiFromId(comment.emojiId);
    }
    return null;
  }

  String? _emojiFromId(int? emojiId) {
    switch (emojiId) {
      case 0:
        return '😀';
      case 1:
        return '😍';
      case 2:
        return '😭';
      case 3:
        return '😡';
    }
    return null;
  }

  bool _needsProfileImageResolution(List<TagComment> comments) {
    for (final comment in comments) {
      final profileKey = _extractCommentProfileKey(comment);
      if (profileKey == null) {
        continue;
      }

      final profileUrl = (comment.userProfileUrl ?? '').trim();
      final uri = Uri.tryParse(profileUrl);
      if (profileUrl.isEmpty || uri == null || !uri.hasScheme) {
        return true;
      }
    }
    return false;
  }

  String? _extractCommentProfileKey(TagComment comment) {
    final profileKey = (comment.userProfileKey ?? '').trim();
    if (profileKey.isNotEmpty) {
      return profileKey;
    }

    final profileUrl = (comment.userProfileUrl ?? '').trim();
    if (profileUrl.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(profileUrl);
    if (uri != null && uri.hasScheme) {
      return null;
    }

    return profileUrl;
  }

  void dispose() {
    _listeners.clear();
    _pendingDrafts.clear();
    _pendingMarkers.clear();
    _selectedEmojisByScopeId.clear();
    _inFlightParentCommentLoads.clear();
    _inFlightTagCommentLoads.clear();
    _inFlightFullCommentLoads.clear();
  }

  void _notifyListeners() {
    for (final listener in _listeners.toList(growable: false)) {
      listener();
    }
  }
}
