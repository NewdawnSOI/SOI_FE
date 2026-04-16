import 'dart:io';

import '../../../../api/controller/comment_controller.dart';
import '../../../../api/controller/media_controller.dart';
import '../../../../api/media_processing/waveform_codec.dart';
import '../../../../api/models/comment.dart';
import '../../../../api/services/media_service.dart';
import '../../application/tagging_save_delegate.dart';
import '../../domain/tagging_save_payload.dart';

/// SOI의 댓글/미디어 컨트롤러를 이용해 태그 저장을 수행하는 앱 전용 delegate입니다.
class SoiTaggingSaveDelegate implements TaggingSaveDelegate {
  static const int _kMaxWaveformSamples = 30;
  static const int _kSavedCommentLookupAttempts = 4;
  static const Duration _kSavedCommentLookupDelay = Duration(
    milliseconds: 180,
  );
  static final WaveformCodec _waveformCodec = WaveformCodec();

  final CommentController _commentController;
  final MediaController _mediaController;

  const SoiTaggingSaveDelegate({
    required CommentController commentController,
    required MediaController mediaController,
  }) : _commentController = commentController,
       _mediaController = mediaController;

  @override
  Future<Comment> save({
    required TaggingSavePayload payload,
    void Function(double progress)? onProgress,
  }) async {
    final validationError = payload.validateForSave();
    if (validationError != null) {
      throw StateError(validationError);
    }

    switch (payload.kind) {
      case TaggingDraftKind.text:
        return _saveTextComment(payload, onProgress);
      case TaggingDraftKind.audio:
        return _saveAudioComment(payload, onProgress);
      case TaggingDraftKind.image:
      case TaggingDraftKind.video:
        return _saveMediaComment(payload, onProgress);
    }
  }

  Future<Comment> _saveTextComment(
    TaggingSavePayload payload,
    void Function(double progress)? onProgress,
  ) async {
    onProgress?.call(0.45);
    final result = await _commentController.createComment(
      postId: payload.postId,
      userId: payload.userId,
      parentId: payload.parentId ?? 0,
      replyUserId: payload.replyUserId ?? 0,
      text: payload.text,
      locationX: payload.locationX,
      locationY: payload.locationY,
      type: CommentType.text,
    );
    onProgress?.call(0.9);

    if (!result.success) {
      throw StateError('댓글 저장에 실패했습니다.');
    }

    return _resolvePersistedComment(
      payload: payload,
      directComment: result.comment,
      matcher: (comments) => _findSavedTextComment(comments, payload),
    );
  }

  Future<Comment> _saveAudioComment(
    TaggingSavePayload payload,
    void Function(double progress)? onProgress,
  ) async {
    final audioPath = (payload.audioPath ?? '').trim();
    if (audioPath.isEmpty) {
      throw StateError('오디오 경로가 없습니다.');
    }

    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw StateError('오디오 파일을 찾을 수 없습니다.');
    }

    onProgress?.call(0.15);
    final multipartFile = await _mediaController.fileToMultipart(audioFile);
    onProgress?.call(0.35);
    final audioKey = await _mediaController.uploadCommentAudio(
      file: multipartFile,
      userId: payload.userId,
      postId: payload.postId,
    );
    if (audioKey == null || audioKey.isEmpty) {
      throw StateError('오디오 업로드에 실패했습니다.');
    }

    final waveformJson = _waveformCodec.encodeOrEmpty(
      payload.waveformData,
      maxSamples: _kMaxWaveformSamples,
    );

    onProgress?.call(0.82);
    final result = await _commentController.createComment(
      postId: payload.postId,
      userId: payload.userId,
      parentId: payload.parentId ?? 0,
      replyUserId: payload.replyUserId ?? 0,
      audioKey: audioKey,
      waveformData: waveformJson,
      duration: payload.duration,
      locationX: payload.locationX,
      locationY: payload.locationY,
      type: CommentType.audio,
    );
    onProgress?.call(0.95);

    if (!result.success) {
      throw StateError('댓글 저장에 실패했습니다.');
    }

    return _resolvePersistedComment(
      payload: payload,
      directComment: result.comment,
      matcher: (comments) => _findSavedAudioComment(comments, payload),
    );
  }

  Future<Comment> _saveMediaComment(
    TaggingSavePayload payload,
    void Function(double progress)? onProgress,
  ) async {
    final localFilePath = (payload.localFilePath ?? '').trim();
    if (localFilePath.isEmpty) {
      throw StateError('미디어 경로가 없습니다.');
    }

    final mediaFile = File(localFilePath);
    if (!await mediaFile.exists()) {
      throw StateError('미디어 파일을 찾을 수 없습니다.');
    }

    onProgress?.call(0.18);
    final multipartFile = await _mediaController.fileToMultipart(mediaFile);
    final mediaType = payload.kind == TaggingDraftKind.video
        ? MediaType.video
        : MediaType.image;
    final uploadedKeys = await _mediaController.uploadMedia(
      files: [multipartFile],
      types: [mediaType],
      usageTypes: [MediaUsageType.comment],
      userId: payload.userId,
      refId: payload.postId,
      usageCount: 1,
    );
    if (uploadedKeys.isEmpty || uploadedKeys.first.isEmpty) {
      throw StateError('미디어 업로드에 실패했습니다.');
    }

    final fileKey = uploadedKeys.first;
    onProgress?.call(0.84);
    final result = await _commentController.createComment(
      postId: payload.postId,
      userId: payload.userId,
      parentId: payload.parentId ?? 0,
      replyUserId: payload.replyUserId ?? 0,
      fileKey: fileKey,
      locationX: payload.locationX,
      locationY: payload.locationY,
      type: payload.kind == TaggingDraftKind.video
          ? CommentType.video
          : CommentType.photo,
    );
    onProgress?.call(0.95);

    if (!result.success) {
      throw StateError('댓글 저장에 실패했습니다.');
    }

    return _resolvePersistedComment(
      payload: payload,
      directComment: result.comment,
      matcher: (comments) => _findSavedMediaComment(
        comments,
        payload,
        fileKey,
      ),
    );
  }

  Future<Comment> _resolvePersistedComment({
    required TaggingSavePayload payload,
    required Comment? directComment,
    required Comment? Function(List<Comment> comments) matcher,
  }) async {
    final persistedDirect = _persistedCommentOrNull(directComment);
    if (persistedDirect != null) {
      return persistedDirect;
    }

    for (var attempt = 0; attempt < _kSavedCommentLookupAttempts; attempt++) {
      final comments = await _commentController.getComments(postId: payload.postId);
      final matched = _persistedCommentOrNull(matcher(comments));
      if (matched != null) {
        return matched;
      }
      if (attempt < _kSavedCommentLookupAttempts - 1) {
        await Future<void>.delayed(_kSavedCommentLookupDelay);
      }
    }

    throw StateError('저장된 댓글의 id/userId를 확인하지 못했습니다.');
  }

  Comment? _persistedCommentOrNull(Comment? comment) {
    if (comment == null || comment.id == null || comment.userId == null) {
      return null;
    }
    return comment;
  }

  Comment? _findSavedTextComment(
    List<Comment> comments,
    TaggingSavePayload payload,
  ) {
    final trimmedText = (payload.text ?? '').trim();
    if (trimmedText.isEmpty) {
      return null;
    }

    for (final comment in comments.reversed) {
      if (!comment.isText || comment.userId != payload.userId) {
        continue;
      }

      final matchesX = _isNearCoordinate(comment.locationX, payload.locationX);
      final matchesY = _isNearCoordinate(comment.locationY, payload.locationY);
      final sameText = (comment.text ?? '').trim() == trimmedText;
      if (matchesX && matchesY && sameText) {
        return comment;
      }
    }

    return null;
  }

  Comment? _findSavedAudioComment(
    List<Comment> comments,
    TaggingSavePayload payload,
  ) {
    final expectedDuration = payload.duration ?? 0;

    for (final comment in comments.reversed) {
      if (!comment.isAudio || comment.userId != payload.userId) {
        continue;
      }

      final matchesX = _isNearCoordinate(comment.locationX, payload.locationX);
      final matchesY = _isNearCoordinate(comment.locationY, payload.locationY);
      final matchesDuration =
          expectedDuration <= 0 ||
          comment.duration == null ||
          comment.duration == expectedDuration;
      if (matchesX && matchesY && matchesDuration) {
        return comment;
      }
    }

    return null;
  }

  Comment? _findSavedMediaComment(
    List<Comment> comments,
    TaggingSavePayload payload,
    String fileKey,
  ) {
    for (final comment in comments.reversed) {
      if (comment.userId != payload.userId) {
        continue;
      }

      if ((comment.fileKey ?? '').trim() == fileKey) {
        return comment;
      }

      final isMediaComment = comment.isPhoto || comment.isVideo;
      if (!isMediaComment) {
        continue;
      }

      final matchesX = _isNearCoordinate(comment.locationX, payload.locationX);
      final matchesY = _isNearCoordinate(comment.locationY, payload.locationY);
      if (matchesX && matchesY) {
        return comment;
      }
    }

    return null;
  }

  bool _isNearCoordinate(double? lhs, double? rhs) {
    if (lhs == null || rhs == null) {
      return false;
    }
    return (lhs - rhs).abs() <= 0.0001;
  }
}
