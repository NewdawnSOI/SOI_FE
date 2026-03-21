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
  final Map<int, Future<List<Comment>>> _inFlightCommentsByPost = {};
  final Map<String, Future<({List<Comment> comments, bool hasMore})>>
  _inFlightCommentsByUserPage = {};

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

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get errorMessage => _errorMessage;

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
  Future<List<Comment>> getComments({required int postId}) async {
    final task = _inFlightCommentsByPost.putIfAbsent(postId, () async {
      _beginRequest();
      try {
        return await _commentService.getComments(postId: postId);
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

  /// 사용자가 작성한 댓글 조회
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
