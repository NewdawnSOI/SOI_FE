import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../api/models/comment.dart';
import '../domain/tagging_author.dart';
import '../domain/tagging_state_models.dart';
import 'tagging_comment_gateway.dart';
import 'tagging_media_resolver.dart';

/// 태깅 세션의 draft, marker, 캐시 hydrate 규칙을 post 단위로 관리합니다.
class TaggingSessionController extends ChangeNotifier {
  final TaggingCommentGateway _commentGateway;
  final TaggingMediaResolver _mediaResolver;
  final String? Function()? _currentUserHandleResolver;

  final Map<int, TaggingPendingDraft> _pendingDrafts = {};
  final Map<int, TaggingPendingMarker> _pendingMarkers = {};
  final Map<int, String?> _selectedEmojisByPostId = {};
  final Map<int, Future<List<Comment>>> _inFlightParentCommentLoads = {};
  final Map<int, Future<void>> _inFlightTagCommentLoads = {};
  final Map<int, Future<List<Comment>>> _inFlightFullCommentLoads = {};

  TaggingSessionController({
    required TaggingCommentGateway commentGateway,
    required TaggingMediaResolver mediaResolver,
    String? Function()? currentUserHandleResolver,
  }) : _commentGateway = commentGateway,
       _mediaResolver = mediaResolver,
       _currentUserHandleResolver = currentUserHandleResolver;

  Map<int, TaggingPendingDraft> get pendingDrafts => _pendingDrafts;

  Map<int, TaggingPendingMarker> get pendingMarkers => _pendingMarkers;

  Map<int, String?> get selectedEmojisByPostId => _selectedEmojisByPostId;

  void setSelectedEmoji(int postId, String? emoji) {
    if (emoji == null) {
      _selectedEmojisByPostId.remove(postId);
    } else {
      _selectedEmojisByPostId[postId] = emoji;
    }
    notifyListeners();
  }

  /// 댓글 시트가 즉시 돌려준 full thread를 현재 사용자 기준 선택 이모지 상태와 맞춥니다.
  void syncSelectedEmojiFromComments(int postId, List<Comment> comments) {
    _syncSelectedEmojiFromComments(postId, comments);
    notifyListeners();
  }

  /// 텍스트 입력이 끝난 시점의 draft를 저장해 이후 배치/저장을 이어갑니다.
  void stageTextDraft({
    required int postId,
    required String text,
    required TaggingAuthor author,
  }) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return;
    }

    _pendingDrafts[postId] = (
      isTextComment: true,
      text: trimmedText,
      audioPath: null,
      mediaPath: null,
      isVideo: null,
      waveformData: null,
      duration: null,
      recorderUserId: author.id,
      profileImageUrlKey: author.profileImageSource,
    );
    notifyListeners();
  }

  /// 오디오 녹음 결과를 draft로 저장해 이후 위치 배치와 업로드를 분리합니다.
  void stageAudioDraft({
    required int postId,
    required String audioPath,
    required List<double> waveformData,
    required int durationMs,
    required TaggingAuthor author,
  }) {
    if (audioPath.trim().isEmpty) {
      return;
    }

    _pendingDrafts[postId] = (
      isTextComment: false,
      text: null,
      audioPath: audioPath,
      mediaPath: null,
      isVideo: null,
      waveformData: waveformData,
      duration: durationMs,
      recorderUserId: author.id,
      profileImageUrlKey: author.profileImageSource,
    );
    notifyListeners();
  }

  /// 미디어 선택 결과를 draft로 저장해 드래그 배치 후 저장하도록 만듭니다.
  void stageMediaDraft({
    required int postId,
    required String localFilePath,
    required bool isVideo,
    required TaggingAuthor author,
  }) {
    final trimmedPath = localFilePath.trim();
    if (trimmedPath.isEmpty) {
      return;
    }

    _pendingDrafts[postId] = (
      isTextComment: false,
      text: null,
      audioPath: null,
      mediaPath: trimmedPath,
      isVideo: isVideo,
      waveformData: null,
      duration: null,
      recorderUserId: author.id,
      profileImageUrlKey: author.profileImageSource,
    );
    notifyListeners();
  }

  Offset? resolveDropRelativePosition(int postId) {
    return _pendingMarkers[postId]?.relativePosition;
  }

  /// 드래그된 pending 태그를 표시 영역 비율 좌표로 정규화해 재사용 가능한 marker로 저장합니다.
  void updatePendingMarkerFromAbsolutePosition({
    required int postId,
    required Offset absolutePosition,
    required Size imageSize,
  }) {
    final draft = _pendingDrafts[postId];
    if (draft == null || imageSize.width <= 0 || imageSize.height <= 0) {
      return;
    }

    final previousProgress = _pendingMarkers[postId]?.progress;
    _pendingMarkers[postId] = (
      relativePosition: _toRelativePosition(absolutePosition, imageSize),
      profileImageUrlKey: draft.profileImageUrlKey,
      progress: previousProgress,
    );
    notifyListeners();
  }

  void updatePendingProgress(int postId, double progress) {
    final marker = _pendingMarkers[postId];
    if (marker == null) {
      return;
    }

    _pendingMarkers[postId] = (
      relativePosition: marker.relativePosition,
      profileImageUrlKey: marker.profileImageUrlKey,
      progress: progress.clamp(0.0, 1.0).toDouble(),
    );
    notifyListeners();
  }

  void handleCommentSaveSuccess(int postId, Comment _) {
    _pendingDrafts.remove(postId);
    _pendingMarkers.remove(postId);
    notifyListeners();
  }

  void handleCommentSaveFailure(int postId) {
    final marker = _pendingMarkers[postId];
    if (marker != null) {
      _pendingMarkers[postId] = (
        relativePosition: marker.relativePosition,
        profileImageUrlKey: marker.profileImageUrlKey,
        progress: null,
      );
    }
    notifyListeners();
  }

  /// 게시물 단위 transient state를 한 번에 정리해 화면별 삭제 경로를 단순화합니다.
  void clearPostState(int postId) {
    _pendingDrafts.remove(postId);
    _pendingMarkers.remove(postId);
    _selectedEmojisByPostId.remove(postId);
    _inFlightParentCommentLoads.remove(postId);
    _inFlightTagCommentLoads.remove(postId);
    _inFlightFullCommentLoads.remove(postId);
    notifyListeners();
  }

  Future<void> loadTagCommentsForPosts(
    List<int> postIds, {
    bool forceReload = false,
  }) async {
    final uniquePostIds = postIds
        .toSet()
        .where((postId) {
          final cached = _commentGateway.peekTagCommentsCache(postId: postId);
          return forceReload ||
              cached == null ||
              _needsProfileImageResolution(cached);
        })
        .toList(growable: false);
    if (uniquePostIds.isEmpty) {
      return;
    }

    await Future.wait(
      uniquePostIds.map(
        (postId) => _loadTagCommentsForPostInternal(
          postId,
          forceReload: forceReload,
        ),
      ),
    );
  }

  Future<void> loadTagCommentsForPost(
    int postId, {
    bool forceReload = false,
  }) async {
    await loadTagCommentsForPosts([postId], forceReload: forceReload);
  }

  Future<void> loadParentCommentsForPosts(
    List<int> postIds, {
    bool forceReload = false,
  }) async {
    final uniquePostIds = postIds
        .toSet()
        .where((postId) {
          final cached = _commentGateway.peekParentCommentsCache(postId: postId);
          return forceReload ||
              cached == null ||
              _needsProfileImageResolution(cached);
        })
        .toList(growable: false);
    if (uniquePostIds.isEmpty) {
      return;
    }

    await Future.wait(
      uniquePostIds.map(
        (postId) => _loadParentCommentsForPostInternal(
          postId,
          forceReload: forceReload,
        ),
      ),
    );
  }

  Future<List<Comment>> loadParentCommentsForPost(
    int postId, {
    bool forceReload = false,
  }) async {
    return _loadParentCommentsForPostInternal(
      postId,
      forceReload: forceReload,
    );
  }

  Future<List<Comment>> loadCommentsForPost(
    int postId, {
    bool forceReload = false,
  }) async {
    if (!forceReload) {
      final cached = _commentGateway.peekCommentsCache(postId: postId);
      if (cached != null) {
        final resolved = await _resolveAndStoreCommentsIfNeeded(
          postId: postId,
          comments: cached,
          tagOnly: false,
        );
        _syncSelectedEmojiFromComments(postId, resolved);
        notifyListeners();
        return resolved;
      }

      final inFlight = _inFlightFullCommentLoads[postId];
      if (inFlight != null) {
        return inFlight;
      }
    }

    final future = _loadFullCommentsForPostInternal(
      postId,
      forceReload: forceReload,
    );
    _inFlightFullCommentLoads[postId] = future;
    try {
      return await future;
    } finally {
      final registered = _inFlightFullCommentLoads[postId];
      if (identical(registered, future)) {
        _inFlightFullCommentLoads.remove(postId);
      }
    }
  }

  Future<List<Comment>> _loadParentCommentsForPostInternal(
    int postId, {
    required bool forceReload,
  }) async {
    if (!forceReload) {
      final inFlight = _inFlightParentCommentLoads[postId];
      if (inFlight != null) {
        return inFlight;
      }
    }

    final future = () async {
      try {
        final comments = await _commentGateway.loadParentComments(
          postId: postId,
          forceReload: forceReload,
        );
        final resolvedComments = await _resolveCommentProfileImages(comments);
        _commentGateway.replaceParentCommentsCache(
          postId: postId,
          comments: resolvedComments,
        );
        _syncSelectedEmojiFromComments(postId, resolvedComments);
        notifyListeners();
        return resolvedComments;
      } catch (error) {
        debugPrint('원댓글 로드 실패(postId: $postId): $error');
        return _commentGateway.peekParentCommentsCache(postId: postId) ??
            const <Comment>[];
      }
    }();

    _inFlightParentCommentLoads[postId] = future;
    try {
      return await future;
    } finally {
      final registered = _inFlightParentCommentLoads[postId];
      if (identical(registered, future)) {
        _inFlightParentCommentLoads.remove(postId);
      }
    }
  }

  Future<void> _loadTagCommentsForPostInternal(
    int postId, {
    required bool forceReload,
  }) async {
    if (!forceReload) {
      final inFlight = _inFlightTagCommentLoads[postId];
      if (inFlight != null) {
        return inFlight;
      }
    }

    final future = () async {
      try {
        final cached = forceReload
            ? null
            : _commentGateway.peekTagCommentsCache(postId: postId);
        final comments =
            cached ??
            await _commentGateway.loadTagComments(
              postId: postId,
              forceReload: forceReload,
            );
        final resolvedComments = await _resolveCommentProfileImages(comments);
        _commentGateway.replaceTagCommentsCache(
          postId: postId,
          comments: resolvedComments,
        );
        notifyListeners();
      } catch (error) {
        debugPrint('태그 댓글 로드 실패(postId: $postId): $error');
      }
    }();

    _inFlightTagCommentLoads[postId] = future;
    try {
      await future;
    } finally {
      final registered = _inFlightTagCommentLoads[postId];
      if (identical(registered, future)) {
        _inFlightTagCommentLoads.remove(postId);
      }
    }
  }

  Future<List<Comment>> _loadFullCommentsForPostInternal(
    int postId, {
    required bool forceReload,
  }) async {
    try {
      final comments = await _commentGateway.loadComments(
        postId: postId,
        forceReload: forceReload,
      );
      final resolvedComments = await _resolveCommentProfileImages(comments);
      _commentGateway.replaceCommentsCache(
        postId: postId,
        comments: resolvedComments,
      );
      _syncSelectedEmojiFromComments(postId, resolvedComments);
      notifyListeners();
      return resolvedComments;
    } catch (error) {
      debugPrint('전체 댓글 로드 실패(postId: $postId): $error');
      return _commentGateway.peekCommentsCache(postId: postId) ??
          const <Comment>[];
    }
  }

  Future<List<Comment>> _resolveAndStoreCommentsIfNeeded({
    required int postId,
    required List<Comment> comments,
    required bool tagOnly,
  }) async {
    if (!_needsProfileImageResolution(comments)) {
      return comments;
    }

    final resolvedComments = await _resolveCommentProfileImages(comments);
    if (tagOnly) {
      _commentGateway.replaceTagCommentsCache(
        postId: postId,
        comments: resolvedComments,
      );
      return _commentGateway.peekTagCommentsCache(postId: postId) ??
          resolvedComments;
    }

    _commentGateway.replaceCommentsCache(
      postId: postId,
      comments: resolvedComments,
    );
    return _commentGateway.peekCommentsCache(postId: postId) ??
        resolvedComments;
  }

  Future<List<Comment>> _resolveCommentProfileImages(
    List<Comment> comments,
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

    return comments.map((comment) {
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
    }).toList(growable: false);
  }

  void _syncSelectedEmojiFromComments(int postId, List<Comment> comments) {
    final currentUserHandle = _currentUserHandleResolver?.call();
    if (currentUserHandle == null) {
      return;
    }

    final selected = _selectedEmojiFromComments(
      comments: comments,
      currentUserHandle: currentUserHandle,
    );
    if (selected == null) {
      _selectedEmojisByPostId.remove(postId);
      return;
    }
    _selectedEmojisByPostId[postId] = selected;
  }

  String? _selectedEmojiFromComments({
    required List<Comment> comments,
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

  bool _needsProfileImageResolution(List<Comment> comments) {
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

  String? _extractCommentProfileKey(Comment comment) {
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

  Offset _toRelativePosition(Offset absolutePosition, Size imageSize) {
    return Offset(
      (absolutePosition.dx / imageSize.width).clamp(0.0, 1.0).toDouble(),
      (absolutePosition.dy / imageSize.height).clamp(0.0, 1.0).toDouble(),
    );
  }

  @override
  void dispose() {
    _pendingDrafts.clear();
    _pendingMarkers.clear();
    _selectedEmojisByPostId.clear();
    _inFlightParentCommentLoads.clear();
    _inFlightTagCommentLoads.clear();
    _inFlightFullCommentLoads.clear();
    super.dispose();
  }
}
