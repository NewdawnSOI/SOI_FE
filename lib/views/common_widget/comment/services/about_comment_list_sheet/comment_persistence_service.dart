import '../../../../../api/media_processing/waveform_codec.dart';
import '../../../../../api/models/comment.dart';

/// 댓글 저장 직후의 매칭, payload 생성, 표시용 정규화를 담당합니다.
/// API 지연이나 부분 응답을 보완하는 저장 후 복원 규칙을 한곳에 모읍니다.
class ApiCommentPersistenceService {
  const ApiCommentPersistenceService._();

  /// 저장된 댓글만 통과시켜 id/userId가 없는 임시 댓글을 걸러냅니다.
  static Comment? persistedCommentOrNull(Comment? comment) {
    if (comment == null || comment.id == null || comment.userId == null) {
      return null;
    }
    return comment;
  }

  /// 직접 응답이나 재조회 결과에서 저장된 댓글을 복원합니다.
  static Future<Comment> resolvePersistedComment({
    required Comment? directComment,
    required Future<List<Comment>> Function() loadComments,
    required Comment? Function(List<Comment> comments) matcher,
    required int attempts,
    required Duration delay,
  }) async {
    final persistedDirect = persistedCommentOrNull(directComment);
    if (persistedDirect != null) {
      return persistedDirect;
    }

    for (var attempt = 0; attempt < attempts; attempt++) {
      final comments = await loadComments();
      final matched = persistedCommentOrNull(matcher(comments));
      if (matched != null) {
        return matched;
      }
      if (attempt < attempts - 1) {
        await Future<void>.delayed(delay);
      }
    }

    throw StateError('저장된 댓글의 id/userId를 확인하지 못했습니다.');
  }

  /// 텍스트 댓글 저장 직후 가장 가능성 높은 댓글을 찾습니다.
  static Comment? findSavedTextComment({
    required List<Comment> comments,
    required int userId,
    required String text,
    required Comment? replyTarget,
    required int? Function(Comment? comment) replyThreadParentId,
  }) {
    final trimmedText = text.trim();
    final targetReplyUserName = (replyTarget?.nickname ?? '').trim();
    final targetParentId = replyThreadParentId(replyTarget);

    for (final comment in comments.reversed) {
      if (comment.userId != userId) {
        continue;
      }

      final isExpectedType = replyTarget != null ? comment.isReply : comment.isText;
      if (!isExpectedType) {
        continue;
      }

      if ((comment.text ?? '').trim() != trimmedText) {
        continue;
      }

      if (targetParentId != null && comment.threadParentId != targetParentId) {
        continue;
      }

      if (replyTarget != null &&
          targetReplyUserName.isNotEmpty &&
          (comment.replyUserName ?? '').trim() != targetReplyUserName) {
        continue;
      }

      return comment;
    }

    return null;
  }

  /// 오디오 댓글 저장 직후 duration과 스레드 관계를 기준으로 댓글을 찾습니다.
  static Comment? findSavedAudioComment({
    required List<Comment> comments,
    required int userId,
    required Comment? replyTarget,
    required int durationMs,
    required int? Function(Comment? comment) replyThreadParentId,
  }) {
    final targetReplyUserName = (replyTarget?.nickname ?? '').trim();
    final targetParentId = replyThreadParentId(replyTarget);

    for (final comment in comments.reversed) {
      if (comment.userId != userId) {
        continue;
      }

      final isExpectedType = replyTarget != null ? comment.isReply : comment.isAudio;
      if (!isExpectedType) {
        continue;
      }

      if (targetParentId != null && comment.threadParentId != targetParentId) {
        continue;
      }

      if (targetReplyUserName.isNotEmpty &&
          (comment.replyUserName ?? '').trim() != targetReplyUserName) {
        continue;
      }

      if ((comment.duration ?? 0) == durationMs) {
        return comment;
      }
    }

    return null;
  }

  /// 미디어 댓글 저장 직후 fileKey와 스레드 관계를 기준으로 댓글을 찾습니다.
  static Comment? findSavedMediaComment({
    required List<Comment> comments,
    required int userId,
    required Comment? replyTarget,
    required String fileKey,
    required int? Function(Comment? comment) replyThreadParentId,
  }) {
    final targetReplyUserName = (replyTarget?.nickname ?? '').trim();
    final targetParentId = replyThreadParentId(replyTarget);

    for (final comment in comments.reversed) {
      if (comment.userId != userId) {
        continue;
      }

      final isExpectedType = replyTarget != null
          ? comment.isReply
          : (comment.isPhoto || comment.isVideo);
      if (!isExpectedType) {
        continue;
      }

      if (targetParentId != null && comment.threadParentId != targetParentId) {
        continue;
      }

      if (targetReplyUserName.isNotEmpty &&
          (comment.replyUserName ?? '').trim() != targetReplyUserName) {
        continue;
      }

      if ((comment.fileKey ?? '').trim() == fileKey) {
        return comment;
      }
    }

    return null;
  }

  /// 답글 저장에 필요한 parentId와 replyUserId를 댓글 관계 기준으로 계산합니다.
  static ({int parentId, int replyUserId}) buildReplyPayload({
    required Comment? replyTarget,
    required int? Function(Comment? comment) replyThreadParentId,
  }) {
    if (replyTarget == null) {
      return (parentId: 0, replyUserId: 0);
    }

    return (
      parentId: replyThreadParentId(replyTarget) ?? replyTarget.id ?? 0,
      replyUserId: replyTarget.userId ?? 0,
    );
  }

  /// 저장 직후 리스트에 삽입할 댓글에 스레드 관계와 표시 정보를 보강합니다.
  static Comment normalizeCommentForThread({
    required Comment comment,
    required Comment? replyTarget,
    required String? currentUserProfileKey,
    required int? Function(Comment? comment) replyThreadParentId,
  }) {
    final normalizedReplyUserName =
        (comment.replyUserName ?? '').trim().isNotEmpty
            ? comment.replyUserName
            : replyTarget?.nickname;
    final normalizedProfileUrl =
        (comment.userProfileUrl ?? '').trim().isNotEmpty
            ? comment.userProfileUrl
            : currentUserProfileKey;
    final normalizedProfileKey =
        (comment.userProfileKey ?? '').trim().isNotEmpty
            ? comment.userProfileKey
            : currentUserProfileKey;
    final normalizedThreadParentId = replyTarget != null
        ? replyThreadParentId(replyTarget)
        : (comment.threadParentId ?? comment.id);

    return comment.copyWith(
      threadParentId: normalizedThreadParentId,
      replyUserName: normalizedReplyUserName,
      userProfileUrl: normalizedProfileUrl,
      userProfileKey: normalizedProfileKey,
      createdAt: comment.createdAt ?? DateTime.now(),
      type: replyTarget != null ? CommentType.reply : comment.type,
    );
  }

  /// 음성 댓글 업로드용 웨이브폼을 공통 코덱으로 요청 포맷에 맞춰 압축합니다.
  static String encodeWaveformForRequest({
    required List<double>? waveformData,
    required WaveformCodec codec,
    required int maxWaveformSamples,
  }) {
    return codec.encodeOrEmpty(waveformData, maxSamples: maxWaveformSamples);
  }
}
