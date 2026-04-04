import 'dart:io';

import 'package:easy_localization/easy_localization.dart';

import '../../../../../api/controller/comment_controller.dart';
import '../../../../../api/controller/media_controller.dart';
import '../../../../../api/controller/user_controller.dart';
import '../../../../../api/media_processing/waveform_codec.dart';
import '../../../../../api/models/comment.dart';
import '../../../../../api/services/media_service.dart';
import 'comment_persistence_service.dart';

/// 댓글 시트의 텍스트/오디오/미디어 저장 플로우를 담당합니다.
/// 업로드, 댓글 생성, 저장 직후 재조회 복원을 한 흐름으로 묶어 시트 상태 코드를 줄입니다.
class CommentSheetSubmissionService {
  const CommentSheetSubmissionService._();

  /// 텍스트 댓글 저장 후 재조회 매칭까지 완료한 저장 결과를 반환합니다.
  static Future<CommentSheetSaveResult> submitTextComment({
    required UserController userController,
    required CommentController commentController,
    required int postId,
    required String text,
    required Comment? replyTarget,
    required int savedCommentLookupAttempts,
    required Duration savedCommentLookupDelay,
    required int? Function(Comment? comment) replyThreadParentId,
    required void Function(String message) showSnackBar,
  }) async {
    final currentUser = userController.currentUser;
    if (currentUser == null) {
      showSnackBar(tr('common.login_required'));
      throw StateError('login_required');
    }

    final replyPayload = ApiCommentPersistenceService.buildReplyPayload(
      replyTarget: replyTarget,
      replyThreadParentId: replyThreadParentId,
    );
    final result = await commentController.createComment(
      postId: postId,
      userId: currentUser.id,
      parentId: replyPayload.parentId,
      replyUserId: replyPayload.replyUserId,
      text: text,
      type: replyTarget != null ? CommentType.reply : CommentType.text,
    );

    if (!result.success) {
      showSnackBar(tr('comments.save_failed'));
      throw StateError('comment_save_failed');
    }

    final savedComment = await ApiCommentPersistenceService.resolvePersistedComment(
      directComment: result.comment,
      loadComments: () => commentController.getComments(postId: postId),
      matcher: (comments) => ApiCommentPersistenceService.findSavedTextComment(
        comments: comments,
        userId: currentUser.id,
        text: text,
        replyTarget: replyTarget,
        replyThreadParentId: replyThreadParentId,
      ),
      attempts: savedCommentLookupAttempts,
      delay: savedCommentLookupDelay,
    );

    return CommentSheetSaveResult(
      savedComment: savedComment,
      replyTarget: replyTarget,
      currentUserProfileKey: currentUser.profileImageKey,
    );
  }

  /// 오디오 업로드와 답글 저장을 한 흐름으로 처리한 저장 결과를 반환합니다.
  static Future<CommentSheetSaveResult> submitAudioComment({
    required UserController userController,
    required CommentController commentController,
    required MediaController mediaController,
    required WaveformCodec waveformCodec,
    required int maxWaveformSamples,
    required int postId,
    required Comment replyTarget,
    required String audioPath,
    required List<double> waveformData,
    required int durationMs,
    required int savedCommentLookupAttempts,
    required Duration savedCommentLookupDelay,
    required int? Function(Comment? comment) replyThreadParentId,
    required void Function(String message) showSnackBar,
  }) async {
    final currentUser = userController.currentUser;
    if (currentUser == null) {
      showSnackBar(tr('common.login_required'));
      throw StateError('login_required');
    }

    final trimmedAudioPath = audioPath.trim();
    if (trimmedAudioPath.isEmpty) {
      showSnackBar(tr('comments.save_failed'));
      throw StateError('comment_save_failed');
    }

    final audioFile = File(trimmedAudioPath);
    if (!await audioFile.exists()) {
      showSnackBar(tr('comments.save_failed'));
      throw StateError('comment_save_failed');
    }

    final multipartFile = await mediaController.fileToMultipart(audioFile);
    final audioKey = await mediaController.uploadCommentAudio(
      file: multipartFile,
      userId: currentUser.id,
      postId: postId,
    );
    if (audioKey == null || audioKey.isEmpty) {
      showSnackBar(tr('comments.save_failed'));
      throw StateError('comment_save_failed');
    }

    final encodedWaveform = ApiCommentPersistenceService.encodeWaveformForRequest(
      waveformData: waveformData,
      codec: waveformCodec,
      maxWaveformSamples: maxWaveformSamples,
    );
    final replyPayload = ApiCommentPersistenceService.buildReplyPayload(
      replyTarget: replyTarget,
      replyThreadParentId: replyThreadParentId,
    );
    final result = await commentController.createComment(
      postId: postId,
      userId: currentUser.id,
      parentId: replyPayload.parentId,
      replyUserId: replyPayload.replyUserId,
      audioKey: audioKey,
      waveformData: encodedWaveform,
      duration: durationMs,
      type: CommentType.reply,
    );
    if (!result.success) {
      showSnackBar(tr('comments.save_failed'));
      throw StateError('comment_save_failed');
    }

    final savedComment = await ApiCommentPersistenceService.resolvePersistedComment(
      directComment: result.comment,
      loadComments: () => commentController.getComments(postId: postId),
      matcher: (comments) => ApiCommentPersistenceService.findSavedAudioReplyComment(
        comments: comments,
        userId: currentUser.id,
        replyTarget: replyTarget,
        durationMs: durationMs,
        replyThreadParentId: replyThreadParentId,
      ),
      attempts: savedCommentLookupAttempts,
      delay: savedCommentLookupDelay,
    );

    return CommentSheetSaveResult(
      savedComment: savedComment,
      replyTarget: replyTarget,
      currentUserProfileKey: currentUser.profileImageKey,
    );
  }

  /// 이미지/비디오 업로드와 답글 저장을 한 흐름으로 처리한 저장 결과를 반환합니다.
  static Future<CommentSheetSaveResult> submitMediaComment({
    required UserController userController,
    required CommentController commentController,
    required MediaController mediaController,
    required int postId,
    required Comment replyTarget,
    required String localFilePath,
    required bool isVideo,
    required int savedCommentLookupAttempts,
    required Duration savedCommentLookupDelay,
    required int? Function(Comment? comment) replyThreadParentId,
    required void Function(String message) showSnackBar,
  }) async {
    final currentUser = userController.currentUser;
    if (currentUser == null) {
      showSnackBar(tr('common.login_required'));
      throw StateError('login_required');
    }

    final trimmedPath = localFilePath.trim();
    if (trimmedPath.isEmpty) {
      showSnackBar(tr('comments.save_failed'));
      throw StateError('comment_save_failed');
    }

    final mediaFile = File(trimmedPath);
    if (!await mediaFile.exists()) {
      showSnackBar(tr('comments.save_failed'));
      throw StateError('comment_save_failed');
    }

    final multipartFile = await mediaController.fileToMultipart(mediaFile);
    final mediaType = isVideo ? MediaType.video : MediaType.image;
    final uploadedKeys = await mediaController.uploadMedia(
      files: [multipartFile],
      types: [mediaType],
      usageTypes: [MediaUsageType.comment],
      userId: currentUser.id,
      refId: postId,
      usageCount: 1,
    );
    if (uploadedKeys.isEmpty || uploadedKeys.first.isEmpty) {
      showSnackBar(tr('comments.save_failed'));
      throw StateError('comment_save_failed');
    }

    final fileKey = uploadedKeys.first;
    final replyPayload = ApiCommentPersistenceService.buildReplyPayload(
      replyTarget: replyTarget,
      replyThreadParentId: replyThreadParentId,
    );
    final result = await commentController.createComment(
      postId: postId,
      userId: currentUser.id,
      parentId: replyPayload.parentId,
      replyUserId: replyPayload.replyUserId,
      fileKey: fileKey,
      type: CommentType.reply,
    );
    if (!result.success) {
      showSnackBar(tr('comments.save_failed'));
      throw StateError('comment_save_failed');
    }

    final savedComment = await ApiCommentPersistenceService.resolvePersistedComment(
      directComment: result.comment,
      loadComments: () => commentController.getComments(postId: postId),
      matcher: (comments) => ApiCommentPersistenceService.findSavedMediaReplyComment(
        comments: comments,
        userId: currentUser.id,
        replyTarget: replyTarget,
        fileKey: fileKey,
        replyThreadParentId: replyThreadParentId,
      ),
      attempts: savedCommentLookupAttempts,
      delay: savedCommentLookupDelay,
    );

    return CommentSheetSaveResult(
      savedComment: savedComment,
      replyTarget: replyTarget,
      currentUserProfileKey: currentUser.profileImageKey,
    );
  }
}

/// 저장 완료 후 시트가 로컬 리스트를 갱신하는 데 필요한 최소 결과만 전달합니다.
class CommentSheetSaveResult {
  const CommentSheetSaveResult({
    required this.savedComment,
    required this.replyTarget,
    required this.currentUserProfileKey,
  });

  final Comment savedComment;
  final Comment? replyTarget;
  final String? currentUserProfileKey;
}
