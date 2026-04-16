import 'dart:io';

import 'package:tagging_core/tagging_core.dart';

import '../../api/controller/comment_controller.dart';
import '../../api/controller/media_controller.dart';
import '../../api/media_processing/waveform_codec.dart';
import '../../api/models/comment.dart';
import '../../api/services/media_service.dart';
import 'soi_tag_comment_mapper.dart';
import 'soi_tagging_ids.dart';

/// SOI의 댓글/미디어 컨트롤러를 이용해 태그 저장을 수행하는 앱 전용 delegate입니다.
class SoiTaggingSaveDelegate implements TaggingSaveDelegate {
  const SoiTaggingSaveDelegate({
    required CommentController commentController,
    required MediaController mediaController,
  }) : _commentController = commentController,
       _mediaController = mediaController;

  static const int _kMaxWaveformSamples = 30;
  static const int _kSavedCommentLookupAttempts = 4;
  static const Duration _kSavedCommentLookupDelay = Duration(milliseconds: 180);
  static final WaveformCodec _waveformCodec = WaveformCodec();

  final CommentController _commentController;
  final MediaController _mediaController;

  @override
  Future<TagSaveResult> save({
    required TagSavePayload payload,
    void Function(double progress)? onProgress,
  }) async {
    final validationError = payload.validateForSave();
    if (validationError != null) {
      throw StateError(validationError);
    }

    switch (payload.kind) {
      case TagDraftKind.text:
        return _saveTextComment(payload, onProgress);
      case TagDraftKind.audio:
        return _saveAudioComment(payload, onProgress);
      case TagDraftKind.image:
      case TagDraftKind.video:
        return _saveMediaComment(payload, onProgress);
    }
  }

  Future<TagSaveResult> _saveTextComment(
    TagSavePayload payload,
    void Function(double progress)? onProgress,
  ) async {
    final postId = SoiTaggingIds.postIdFromScopeId(payload.scopeId);
    final userId = SoiTaggingIds.requiredIntFromEntityId(
      payload.userId,
      fieldName: 'userId',
    );
    onProgress?.call(0.45);
    final result = await _commentController.createComment(
      postId: postId,
      userId: userId,
      parentId: SoiTaggingIds.intFromEntityId(payload.parentId) ?? 0,
      replyUserId: SoiTaggingIds.intFromEntityId(payload.replyUserId) ?? 0,
      text: payload.text,
      locationX: payload.locationX,
      locationY: payload.locationY,
      type: CommentType.text,
    );
    onProgress?.call(0.9);

    if (!result.success) {
      throw StateError('댓글 저장에 실패했습니다.');
    }

    final comment = await _resolvePersistedComment(
      payload: payload,
      directComment: result.comment,
      matcher: (comments) => _findSavedTextComment(comments, payload),
    );
    return TagSaveResult(comment: SoiTagCommentMapper.fromComment(comment));
  }

  Future<TagSaveResult> _saveAudioComment(
    TagSavePayload payload,
    void Function(double progress)? onProgress,
  ) async {
    final postId = SoiTaggingIds.postIdFromScopeId(payload.scopeId);
    final userId = SoiTaggingIds.requiredIntFromEntityId(
      payload.userId,
      fieldName: 'userId',
    );
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
      userId: userId,
      postId: postId,
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
      postId: postId,
      userId: userId,
      parentId: SoiTaggingIds.intFromEntityId(payload.parentId) ?? 0,
      replyUserId: SoiTaggingIds.intFromEntityId(payload.replyUserId) ?? 0,
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

    final comment = await _resolvePersistedComment(
      payload: payload,
      directComment: result.comment,
      matcher: (comments) => _findSavedAudioComment(comments, payload),
    );
    return TagSaveResult(comment: SoiTagCommentMapper.fromComment(comment));
  }

  Future<TagSaveResult> _saveMediaComment(
    TagSavePayload payload,
    void Function(double progress)? onProgress,
  ) async {
    final postId = SoiTaggingIds.postIdFromScopeId(payload.scopeId);
    final userId = SoiTaggingIds.requiredIntFromEntityId(
      payload.userId,
      fieldName: 'userId',
    );
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
    final mediaType = payload.kind == TagDraftKind.video
        ? MediaType.video
        : MediaType.image;
    final uploadedKeys = await _mediaController.uploadMedia(
      files: [multipartFile],
      types: [mediaType],
      usageTypes: [MediaUsageType.comment],
      userId: userId,
      refId: postId,
      usageCount: 1,
    );
    if (uploadedKeys.isEmpty || uploadedKeys.first.isEmpty) {
      throw StateError('미디어 업로드에 실패했습니다.');
    }

    final fileKey = uploadedKeys.first;
    onProgress?.call(0.84);
    final result = await _commentController.createComment(
      postId: postId,
      userId: userId,
      parentId: SoiTaggingIds.intFromEntityId(payload.parentId) ?? 0,
      replyUserId: SoiTaggingIds.intFromEntityId(payload.replyUserId) ?? 0,
      fileKey: fileKey,
      locationX: payload.locationX,
      locationY: payload.locationY,
      type: payload.kind == TagDraftKind.video
          ? CommentType.video
          : CommentType.photo,
    );
    onProgress?.call(0.95);

    if (!result.success) {
      throw StateError('댓글 저장에 실패했습니다.');
    }

    final comment = await _resolvePersistedComment(
      payload: payload,
      directComment: result.comment,
      matcher: (comments) => _findSavedMediaComment(comments, payload, fileKey),
    );
    return TagSaveResult(comment: SoiTagCommentMapper.fromComment(comment));
  }

  Future<Comment> _resolvePersistedComment({
    required TagSavePayload payload,
    required Comment? directComment,
    required Comment? Function(List<Comment> comments) matcher,
  }) async {
    final postId = SoiTaggingIds.postIdFromScopeId(payload.scopeId);
    final persistedDirect = _persistedCommentOrNull(directComment);
    if (persistedDirect != null) {
      return persistedDirect;
    }

    for (var attempt = 0; attempt < _kSavedCommentLookupAttempts; attempt++) {
      final comments = await _commentController.getComments(postId: postId);
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
    TagSavePayload payload,
  ) {
    final trimmedText = (payload.text ?? '').trim();
    final userId = SoiTaggingIds.intFromEntityId(payload.userId);
    if (trimmedText.isEmpty) {
      return null;
    }

    for (final comment in comments.reversed) {
      if (!comment.isText || comment.userId != userId) {
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
    TagSavePayload payload,
  ) {
    final expectedDuration = payload.duration ?? 0;
    final userId = SoiTaggingIds.intFromEntityId(payload.userId);

    for (final comment in comments.reversed) {
      if (!comment.isAudio || comment.userId != userId) {
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
    TagSavePayload payload,
    String fileKey,
  ) {
    final userId = SoiTaggingIds.intFromEntityId(payload.userId);
    for (final comment in comments.reversed) {
      if (comment.userId != userId) {
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
