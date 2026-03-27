import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/comment_service.dart';

/// 댓글 컨트롤러
///
/// 댓글 관련 UI 상태 관리 및 비즈니스 로직을 담당합니다.
/// CommentService를 내부적으로 사용하며, API 변경 시 Service만 수정하면 됩니다.
///
/// 사용 예시:
/// ```dart
/// final controller = Provider.of<CommentController>(context, listen: false);
///
/// // 댓글 생성
/// await controller.createComment(
///   postId: 1,
///   userId: 1,
///   text: '좋은 사진이네요!',
/// );
///
/// // 댓글 조회
/// final comments = await controller.getComments(postId: 1);
/// ```
class CommentController extends ChangeNotifier {
  final CommentService _commentService;

  /// 게시물 ID별 "전체 댓글" 스레드 캐시 맵 (원댓글 + 대댓글 포함)
  final Map<int, List<Comment>> _cachedCommentsByPost = {};

  /// 위치 있는 댓글만 별도 보관하는 캐시 맵
  final Map<int, List<Comment>> _cachedTagCommentsByPost = {};
  final Map<int, Future<List<Comment>>> _inFlightCommentsByPost = {};

  /// 위치 있는 댓글만 별도 조회하는 경로의 in-flight 트래킹 맵
  final Map<int, Future<List<Comment>>> _inFlightTagCommentsByPost = {};

  /// 사용자별 **댓글 페이지 요청**을 캐싱하여 중복 조회를 방지합니다.
  ///
  /// **Key**: "userId:page" 형식의 문자열
  /// - 예: `'42:0'` (사용자 ID 42의 페이지 0)
  ///
  /// **Value**: "Future<({List<Comment> comments, bool hasMore})>"
  /// - "comments": 해당 페이지의 댓글 목록
  /// - "hasMore": 다음 페이지 존재 여부
  ///
  /// 정리하면,
  /// **ID가 42인 사용자**가 작성한 댓글 중 페이지 0에 해당하는 **댓글 목록**과 **다음 페이지 존재 여부**를 함께 캐싱하여서
  /// 동일한 페이지 요청이 중복으로 발생하는 것을 방지합니다.
  final Map<String, Future<({List<Comment> comments, bool hasMore})>>
  _inFlightCommentsByUserPage = {};

  /// 게시물별 **원댓글 페이지 요청**을 캐싱하여 중복 조회를 방지합니다.
  ///
  /// **Key**: "postId:page" 형식의 문자열
  /// - 예: `'123:0'` (게시물 ID 123의 페이지 0)
  ///
  /// **Value**: "Future<({List<Comment> comments, bool hasMore})>"
  /// - "comments": 해당 페이지의 원댓글 목록
  ///   - 원댓글과 대댓글이 계층 구조로 병합된 형태가 아니라, 해당 페이지에 해당하는 **원댓글 목록만** 반환됩니다.
  /// - "hasMore": 다음 페이지 존재 여부
  ///
  /// 정리하면,
  /// **ID가 123인 게시물**에 달린 **원댓글** 중 페이지 0에 해당하는 **원댓글 목록**과 **다음 페이지 존재 여부**를 함께 캐싱하여서
  /// 동일한 페이지 요청이 중복으로 발생하는 것을 방지합니다.
  final Map<String, Future<({List<Comment> comments, bool hasMore})>>
  _inFlightParentCommentsByPostPage = {};

  /// 게시물별 **대댓글 페이지 요청**을 캐싱하여 중복 조회를 방지합니다.
  ///
  /// **Key**: "parentCommentId:page" 형식의 문자열
  /// - 예: "123:0" (부모 댓글 ID 123의 페이지 0)
  ///
  /// **Value**: "Future<({List<Comment> comments, bool hasMore})>"
  /// - "comments": 해당 페이지의 대댓글 목록
  ///   - 원댓글-대댓글 계층구조가 아니라, 대댓글 목록만 반환됩니다.
  /// - "hasMore": 다음 페이지 존재 여부
  ///
  /// 정리하면,
  /// **ID가 123인 부모 댓글**에 달린 **대댓글** 중 페이지 0에 해당하는 **대댓글 목록**과 **다음 페이지 존재 여부**를 함께 캐싱하여서
  /// 동일한 페이지 요청이 중복으로 발생하는 것을 방지합니다.
  final Map<String, Future<({List<Comment> comments, bool hasMore})>>
  _inFlightChildCommentsByParentPage = {};

  bool _isLoading = false;
  String? _errorMessage;
  int _activeRequestCount = 0;

  /// 생성자
  ///
  /// [commentService]를 주입받아 사용합니다. 테스트 시 MockCommentService를 주입할 수 있습니다.
  CommentController({CommentService? commentService})
    : _commentService = commentService ?? CommentService();

  String _buildUserCommentsRequestKey({
    required int userId,
    required int page,
  }) {
    return '$userId:$page';
  }

  /// 게시물별 원댓글 페이지 요청을 같은 키로 묶어 중복 조회를 막습니다.
  String _buildParentCommentsRequestKey({
    required int postId,
    required int page,
  }) {
    return '$postId:$page';
  }

  /// 부모 댓글별 대댓글 페이지 요청을 같은 키로 묶어 중복 조회를 막습니다.
  String _buildChildCommentsRequestKey({
    required int parentCommentId,
    required int page,
  }) {
    return '$parentCommentId:$page';
  }

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get errorMessage => _errorMessage;

  /// full thread cache는 바텀시트 hydration과 화면 간 재진입에서 공용 재사용됩니다.
  List<Comment>? peekCommentsCache({required int postId}) {
    return _cachedCommentsByPost[postId];
  }

  /// tag cache는 overlay scope만 보존하고, full cache가 있으면 그 결과에서 바로 파생합니다.
  List<Comment>? peekTagCommentsCache({required int postId}) {
    final cached = _cachedTagCommentsByPost[postId];
    if (cached != null) {
      return cached;
    }

    final full = _cachedCommentsByPost[postId];
    if (full == null) {
      return null;
    }

    final derived = _freezeComments(_filterTagComments(full));
    _cachedTagCommentsByPost[postId] = derived;
    return derived;
  }

  /// full thread를 갱신하면 tag cache도 같은 스냅샷 기준으로 같이 맞춰 둡니다.
  void replaceCommentsCache({
    required int postId,
    required List<Comment> comments,
  }) {
    final frozenComments = _freezeComments(comments);
    _cachedCommentsByPost[postId] = frozenComments;
    _cachedTagCommentsByPost[postId] = _freezeComments(
      _filterTagComments(frozenComments),
    );
  }

  /// overlay scope만 새로 가져온 경우 full cache를 건드리지 않고 tag cache만 교체합니다.
  void replaceTagCommentsCache({
    required int postId,
    required List<Comment> comments,
  }) {
    _cachedTagCommentsByPost[postId] = _freezeComments(comments);
  }

  /// 생성 직후에는 이미 로드된 scope만 append해서 partial cache를 진실 소스로 만들지 않습니다.
  void appendCreatedComment({required int postId, required Comment comment}) {
    final full = _cachedCommentsByPost[postId];
    if (full != null && !_containsComment(full, comment.id)) {
      _cachedCommentsByPost[postId] = _freezeComments(
        List<Comment>.from(full)..add(comment),
      );
    }

    if (!comment.hasLocation) {
      return;
    }

    final tags = _cachedTagCommentsByPost[postId];
    if (tags != null && !_containsComment(tags, comment.id)) {
      _cachedTagCommentsByPost[postId] = _freezeComments(
        List<Comment>.from(tags)..add(comment),
      );
      return;
    }

    if (full != null) {
      _cachedTagCommentsByPost[postId] = _freezeComments(
        _filterTagComments(_cachedCommentsByPost[postId] ?? const <Comment>[]),
      );
    }
  }

  /// 삭제 직후에는 이미 로드된 scope에서만 제거하고, force reload가 들어오면 최신 서버값으로 덮습니다.
  void removeCommentFromCache({required int postId, required int commentId}) {
    final full = _cachedCommentsByPost[postId];
    if (full != null) {
      _cachedCommentsByPost[postId] = _freezeComments(
        List<Comment>.from(full)
          ..removeWhere((comment) => comment.id == commentId),
      );
    }

    final tags = _cachedTagCommentsByPost[postId];
    if (tags != null) {
      _cachedTagCommentsByPost[postId] = _freezeComments(
        List<Comment>.from(tags)
          ..removeWhere((comment) => comment.id == commentId),
      );
    }
  }

  /// force refresh나 post 삭제 시 댓글 scope별 공용 cache를 명시적으로 비웁니다.
  void invalidatePostCaches({
    required int postId,
    bool full = true,
    bool tag = true,
  }) {
    if (full) {
      _cachedCommentsByPost.remove(postId);
    }
    if (tag) {
      _cachedTagCommentsByPost.remove(postId);
    }
  }

  void _notifyIfChanged(bool changed) {
    if (changed) {
      notifyListeners();
    }
  }

  bool _setLoadingValue(bool value) {
    if (_isLoading == value) return false;
    _isLoading = value;
    return true;
  }

  bool _setErrorValue(String? message) {
    if (_errorMessage == message) return false;
    _errorMessage = message;
    return true;
  }

  /// 화면 간 재사용 캐시는 mutation 방지를 위해 immutable snapshot으로 보관합니다.
  List<Comment> _freezeComments(List<Comment> comments) {
    if (comments.isEmpty) {
      return const <Comment>[];
    }
    return List<Comment>.unmodifiable(comments);
  }

  /// overlay용 cache는 위치가 있는 댓글만 유지해 full thread 비용과 책임을 분리합니다.
  List<Comment> _filterTagComments(List<Comment> comments) {
    return comments
        .where((comment) => comment.hasLocation)
        .toList(growable: false);
  }

  bool _containsComment(List<Comment> comments, int? commentId) {
    if (commentId == null) {
      return false;
    }
    return comments.any((comment) => comment.id == commentId);
  }

  void _beginRequest() {
    var changed = _setErrorValue(null);
    _activeRequestCount += 1;
    changed = _setLoadingValue(true) || changed;
    _notifyIfChanged(changed);
  }

  void _endRequest() {
    if (_activeRequestCount > 0) {
      _activeRequestCount -= 1;
    }

    final changed = _setLoadingValue(_activeRequestCount > 0);
    _notifyIfChanged(changed);
  }

  // ============================================
  // 댓글 생성
  // ============================================

  /// 댓글 생성
  Future<CommentCreationResult> createComment({
    required int postId, // 댓글이 달릴 게시물 ID(대댓글도 동일하게 postId로 식별)
    required int userId, // 댓글 작성자 ID
    // 이모지 댓글인 경우 이모지 ID, 텍스트/음성/사진 댓글인 경우 0
    int? emojiId,

    // 대댓글인 경우 부모 댓글 ID, 대댓글이 아닌 경우 0
    int? parentId,

    // 대댓글인 경우 답글 대상 사용자 ID, 대댓글이 아닌 경우 0
    int? replyUserId,
    String? text,
    String? audioKey,
    String? fileKey,
    String? waveformData,
    int? duration,
    double? locationX,
    double? locationY,
    CommentType? type,
  }) async {
    _beginRequest();
    try {
      final normalizedEmojiId = emojiId ?? 0;
      final normalizedParentId = parentId ?? 0;
      final normalizedReplyUserId = replyUserId ?? 0;
      final normalizedText = text?.trim() ?? '';
      final normalizedAudioKey = audioKey?.trim() ?? '';
      final normalizedWaveform = waveformData?.trim() ?? '';
      final normalizedFileKey = fileKey?.trim() ?? '';
      final normalizedDuration = duration ?? 0;
      final normalizedLocationX = locationX ?? 0.0;
      final normalizedLocationY = locationY ?? 0.0;

      final inferredType =
          type ??
          (normalizedAudioKey.isNotEmpty
              ? CommentType.audio
              : (normalizedReplyUserId > 0 || normalizedParentId > 0
                    ? CommentType.reply
                    : (normalizedFileKey.isNotEmpty
                          ? CommentType.photo
                          : CommentType.text)));

      final hasAudioPayload = normalizedAudioKey.isNotEmpty;

      // Swagger에서 동작하는 형태에 맞춰, 서버가 null 값에 민감할 수 있는 필드들을 기본값으로 맞춥니다.
      // REPLY 타입이어도 오디오 답글은 audio payload를 함께 전달해야 합니다.
      final payloadText = hasAudioPayload ? '' : normalizedText;
      final payloadAudioKey = hasAudioPayload ? normalizedAudioKey : '';
      final payloadWaveform = hasAudioPayload ? normalizedWaveform : '';
      final payloadDuration = hasAudioPayload ? normalizedDuration : 0;

      final result = await _commentService.createComment(
        postId: postId,
        userId: userId,
        emojiId: normalizedEmojiId,
        parentId: normalizedParentId,
        replyUserId: normalizedReplyUserId,
        text: payloadText,
        audioFileKey: payloadAudioKey,
        fileKey: normalizedFileKey,
        waveformData: payloadWaveform,
        duration: payloadDuration,
        locationX: normalizedLocationX,
        locationY: normalizedLocationY,
        type: inferredType,
      );
      if (result.success) {
        if (result.comment != null) {
          appendCreatedComment(postId: postId, comment: result.comment!);
        } else {
          invalidatePostCaches(postId: postId);
        }
      }
      return result;
    } catch (e) {
      _setError('댓글 생성 실패: $e');
      return const CommentCreationResult.failure();
    } finally {
      _endRequest();
    }
  }

  /// 텍스트 댓글 생성
  /// createComment 메서드를 내부적으로 호출하여, payload/에러/상태 처리를 일관되게 유지합니다.
  /// 원 댓글을 생성할 때, 사용하는 편의 메서드입니다.
  Future<CommentCreationResult> createTextComment({
    required int postId,
    required int userId,
    required String text,
    required double locationX,
    required double locationY,
  }) async {
    // createComment 단일 경로를 사용해 payload/에러/상태 처리를 일관되게 유지합니다.
    return createComment(
      postId: postId,
      userId: userId,
      emojiId: 0,
      parentId: 0,
      replyUserId: 0,
      text: text,
      locationX: locationX,
      locationY: locationY,
      type: CommentType.text,
    );
  }

  /// 음성 댓글 생성
  /// createComment 메서드를 내부적으로 호출하여, payload/에러/상태 처리를 일관되게 유지합니다.
  /// 원 댓글을 생성할 때, 사용하는 편의 메서드입니다.
  Future<CommentCreationResult> createAudioComment({
    required int postId,
    required int userId,
    required String audioFileKey,
    required String waveformData,
    required int duration,
    required double locationX,
    required double locationY,
  }) async {
    // createComment 단일 경로를 사용해 payload/에러/상태 처리를 일관되게 유지합니다.
    return createComment(
      postId: postId,
      userId: userId,
      emojiId: 0,
      parentId: 0,
      replyUserId: 0,
      audioKey: audioFileKey,
      waveformData: waveformData,
      duration: duration,
      locationX: locationX,
      locationY: locationY,
      type: CommentType.audio,
    );
  }

  // ============================================
  // 댓글 조회
  // ============================================

  /// 게시물의 댓글 조회
  Future<List<Comment>> getComments({
    required int postId,
    bool forceReload = false,
  }) async {
    if (!forceReload) {
      final cached = _cachedCommentsByPost[postId];
      if (cached != null) {
        return cached;
      }
    } else {
      invalidatePostCaches(postId: postId, full: true, tag: true);
    }

    final task = _inFlightCommentsByPost.putIfAbsent(postId, () async {
      _beginRequest();
      try {
        final comments = await _commentService.getComments(postId: postId);
        replaceCommentsCache(postId: postId, comments: comments);
        return _cachedCommentsByPost[postId] ?? const <Comment>[];
      } finally {
        _endRequest();
      }
    });

    try {
      return await task;
    } catch (e) {
      _setError('댓글 조회 실패: $e');
      return [];
    } finally {
      final registeredTask = _inFlightCommentsByPost[postId];
      if (identical(registeredTask, task)) {
        _inFlightCommentsByPost.remove(postId);
      }
    }
  }

  /// 태그 오버레이는 위치가 있는 부모 댓글만 별도 경로로 조회합니다.
  Future<List<Comment>> getTagComments({
    required int postId,
    bool forceReload = false,
  }) async {
    if (!forceReload) {
      final cached = peekTagCommentsCache(postId: postId);
      if (cached != null) {
        return cached;
      }
    } else {
      invalidatePostCaches(postId: postId, tag: true, full: false);
    }

    final task = _inFlightTagCommentsByPost.putIfAbsent(postId, () async {
      _beginRequest();
      try {
        final comments = await _commentService.getTagComments(postId: postId);
        replaceTagCommentsCache(postId: postId, comments: comments);
        return _cachedTagCommentsByPost[postId] ?? const <Comment>[];
      } finally {
        _endRequest();
      }
    });

    try {
      return await task;
    } catch (e) {
      _setError('태그 댓글 조회 실패: $e');
      return [];
    } finally {
      final registeredTask = _inFlightTagCommentsByPost[postId];
      if (identical(registeredTask, task)) {
        _inFlightTagCommentsByPost.remove(postId);
      }
    }
  }

  /// 댓글 개수 조회
  Future<int> getCommentCount({required int postId}) async {
    _beginRequest();
    try {
      final count = await _commentService.getCommentCount(postId: postId);
      return count;
    } catch (e) {
      _setError('댓글 개수 조회 실패: $e');
      return 0;
    } finally {
      _endRequest();
    }
  }

  /// 게시물에 달린 원댓글 한 페이지를 UI가 바로 쓰는 `Comment` 모델로 반환합니다.
  Future<({List<Comment> comments, bool hasMore})> getParentComments({
    required int postId,
    int page = 0,
  }) async {
    final requestKey = _buildParentCommentsRequestKey(
      postId: postId,
      page: page,
    );
    final task = _inFlightParentCommentsByPostPage.putIfAbsent(
      requestKey,
      () async {
        _beginRequest();
        try {
          return await _commentService.getParentComments(
            postId: postId,
            page: page,
          );
        } finally {
          _endRequest();
        }
      },
    );

    try {
      return await task;
    } catch (e) {
      _setError('원댓글 조회 실패: $e');
      return (comments: <Comment>[], hasMore: false);
    } finally {
      final registeredTask = _inFlightParentCommentsByPostPage[requestKey];
      if (identical(registeredTask, task)) {
        _inFlightParentCommentsByPostPage.remove(requestKey);
      }
    }
  }

  /// 부모 댓글에 달린 대댓글 한 페이지를 UI가 바로 쓰는 `Comment` 모델로 반환합니다.
  Future<({List<Comment> comments, bool hasMore})> getChildComments({
    required int parentCommentId,
    int page = 0,
  }) async {
    final requestKey = _buildChildCommentsRequestKey(
      parentCommentId: parentCommentId,
      page: page,
    );
    final task = _inFlightChildCommentsByParentPage.putIfAbsent(
      requestKey,
      () async {
        _beginRequest();
        try {
          return await _commentService.getChildComments(
            parentCommentId: parentCommentId,
            page: page,
          );
        } finally {
          _endRequest();
        }
      },
    );

    try {
      return await task;
    } catch (e) {
      _setError('대댓글 조회 실패: $e');
      return (comments: <Comment>[], hasMore: false);
    } finally {
      final registeredTask = _inFlightChildCommentsByParentPage[requestKey];
      if (identical(registeredTask, task)) {
        _inFlightChildCommentsByParentPage.remove(requestKey);
      }
    }
  }

  /// 사용자가 작성한 댓글 조회
  ///
  /// Parameters:
  /// - [userId]: 댓글 작성자 ID
  /// - [page]: 페이지 번호 (0부터 시작)
  ///
  /// Returns:
  /// - [Future<({List<Comment> comments, bool hasMore})>]: 댓글 목록과 다음 페이지 존재 여부를 함께 반환합니다.
  ///   - `comments`: 댓글 목록
  ///   - `hasMore`: 다음 페이지에 댓글이 더 존재하는지 여부
  ///     - **true**인 경우, 다음 페이지를 조회할 수 있습니다.
  ///     - **false**인 경우, 더 이상 다음 페이지가 없습니다.
  ///   - 댓글 목록은 원댓글과 대댓글이 계층 구조로 병합된 형태로 반환됩니다.
  ///
  Future<({List<Comment> comments, bool hasMore})> getCommentsByUserId({
    required int userId,
    int page = 0,
  }) async {
    final requestKey = _buildUserCommentsRequestKey(userId: userId, page: page);
    final task = _inFlightCommentsByUserPage.putIfAbsent(requestKey, () async {
      _beginRequest();
      try {
        return await _commentService.getCommentsByUserId(
          userId: userId,
          page: page,
        );
      } finally {
        _endRequest();
      }
    });

    try {
      return await task;
    } catch (e) {
      _setError('사용자 댓글 조회 실패: $e');
      return (comments: <Comment>[], hasMore: false);
    } finally {
      final registeredTask = _inFlightCommentsByUserPage[requestKey];
      if (identical(registeredTask, task)) {
        _inFlightCommentsByUserPage.remove(requestKey);
      }
    }
  }

  // ============================================
  // 댓글 삭제
  // ============================================

  /// 댓글 삭제
  Future<bool> deleteComment(int commentId) async {
    _beginRequest();
    try {
      final result = await _commentService.deleteComment(commentId);
      return result;
    } catch (e) {
      _setError('댓글 삭제 실패: $e');
      return false;
    } finally {
      _endRequest();
    }
  }

  // ============================================
  // 에러 처리
  // ============================================

  /// 에러 초기화
  void clearError() {
    final changed = _setErrorValue(null);
    _notifyIfChanged(changed);
  }

  void _setError(String message) {
    final changed = _setErrorValue(message);
    _notifyIfChanged(changed);
  }
}
