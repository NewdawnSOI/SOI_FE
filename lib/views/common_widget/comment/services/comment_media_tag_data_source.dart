import 'dart:io';

import 'package:flutter/material.dart';
import 'package:soi_media_tagger/soi_media_tagger.dart';

import '../../../../api/controller/comment_controller.dart';
import '../../../../api/controller/media_controller.dart';
import '../../../../api/media_processing/waveform_codec.dart';
import '../../../../api/models/comment.dart';
import '../../../../api/services/media_service.dart';
import '../comment_save_payload.dart';

/// SOI 댓글 저장 규약을 패키지 태그 계약으로 연결해, 업로드/생성 로직을 앱 어댑터에 한정합니다.
class CommentMediaTagDataSource
    extends MediaTagDataSource<Comment, CommentSavePayload> {
  CommentMediaTagDataSource({
    required CommentController commentController,
    required MediaController mediaController,
  }) : _commentController = commentController,
       _mediaController = mediaController;

  static const int _kMaxWaveformSamples = 30;
  static const int _kSavedCommentLookupAttempts = 4;
  static const Duration _kSavedCommentLookupDelay = Duration(
    milliseconds: 180,
  );
  static final WaveformCodec _waveformCodec = WaveformCodec();

  final CommentController _commentController;
  final MediaController _mediaController;

  @override
  Future<List<MediaTag<Comment>>> fetchTags(String mediaId) async {
    final postId = _parsePostId(mediaId);
    final comments = await _commentController.getTagComments(postId: postId);
    return comments
        .where((comment) => comment.hasLocation)
        .map(_buildTagFromComment)
        .toList(growable: false);
  }

  @override
  Future<MediaTag<Comment>> createTag(
    String mediaId,
    Offset relativePosition,
    CommentSavePayload draftData, {
    ValueChanged<double>? onProgress,
  }) async {
    final postId = _parsePostId(mediaId);
    if (draftData.postId != postId) {
      throw StateError('draftData.postId와 mediaId가 일치하지 않습니다.');
    }

    final payload = draftData.copyWithLocation(
      locationX: relativePosition.dx,
      locationY: relativePosition.dy,
    );
    final validationError = payload.validateForSave();
    if (validationError != null) {
      throw StateError(validationError);
    }

    onProgress?.call(0.05);

    late final Comment savedComment;
    switch (payload.kind) {
      case CommentDraftKind.text:
        savedComment = await _saveTextComment(payload, onProgress);
        break;
      case CommentDraftKind.audio:
        savedComment = await _saveAudioComment(payload, onProgress);
        break;
      case CommentDraftKind.image:
      case CommentDraftKind.video:
        savedComment = await _saveMediaComment(payload, onProgress);
        break;
    }

    onProgress?.call(1.0);
    return _buildTagFromComment(savedComment);
  }

  @override
  Future<void> deleteTag(String tagId) async {
    final commentId = int.tryParse(tagId);
    if (commentId == null) {
      throw StateError('삭제할 댓글 ID가 올바르지 않습니다: $tagId');
    }

    final deleted = await _commentController.deleteComment(commentId);
    if (!deleted) {
      throw StateError('댓글 삭제에 실패했습니다.');
    }
  }

  /// 서버 댓글을 패키지 공통 태그 모델로 변환해 오버레이 렌더링 경계를 맞춥니다.
  MediaTag<Comment> _buildTagFromComment(Comment comment) {
    final tagId =
        comment.id?.toString() ??
        'comment_${comment.userId ?? 0}_${comment.locationX?.toStringAsFixed(4) ?? 'x'}_${comment.locationY?.toStringAsFixed(4) ?? 'y'}';

    return MediaTag<Comment>(
      id: tagId,
      relativePosition: Offset(
        comment.locationX ?? 0.5,
        comment.locationY ?? 0.5,
      ),
      content: comment,
    );
  }

  Future<Comment> _saveTextComment(
    CommentSavePayload payload,
    ValueChanged<double>? onProgress,
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
    CommentSavePayload payload,
    ValueChanged<double>? onProgress,
  ) async {
    final audioPath = (payload.audioPath ?? '').trim();
    if (audioPath.isEmpty) {
      throw StateError('오디오 경로가 없습니다.');
    }

    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw StateError('녹음 파일을 찾을 수 없습니다.');
    }

    onProgress?.call(0.2);
    final multipartFile = await _mediaController.fileToMultipart(audioFile);

    onProgress?.call(0.45);
    final audioKey = await _mediaController.uploadCommentAudio(
      file: multipartFile,
      userId: payload.userId,
      postId: payload.postId,
    );
    if (audioKey == null || audioKey.isEmpty) {
      throw StateError('음성 업로드에 실패했습니다.');
    }

    onProgress?.call(0.65);
    final result = await _commentController.createAudioComment(
      postId: payload.postId,
      userId: payload.userId,
      audioFileKey: audioKey,
      waveformData: _encodeWaveformForRequest(payload.waveformData),
      duration: payload.duration ?? 0,
      locationX: payload.locationX ?? 0.0,
      locationY: payload.locationY ?? 0.0,
    );
    onProgress?.call(0.9);

    if (!result.success) {
      throw StateError('음성 댓글 저장에 실패했습니다.');
    }

    return _resolvePersistedComment(
      payload: payload,
      directComment: result.comment,
      matcher: (comments) => _findSavedAudioComment(comments, payload),
    );
  }

  Future<Comment> _saveMediaComment(
    CommentSavePayload payload,
    ValueChanged<double>? onProgress,
  ) async {
    final localFilePath = (payload.localFilePath ?? '').trim();
    if (localFilePath.isEmpty) {
      throw StateError('미디어 경로가 없습니다.');
    }

    final mediaFile = File(localFilePath);
    if (!await mediaFile.exists()) {
      throw StateError('미디어 파일을 찾을 수 없습니다.');
    }

    onProgress?.call(0.2);
    final multipartFile = await _mediaController.fileToMultipart(mediaFile);
    final mediaType = payload.kind == CommentDraftKind.video
        ? MediaType.video
        : MediaType.image;

    onProgress?.call(0.45);
    final keys = await _mediaController.uploadMedia(
      files: [multipartFile],
      types: [mediaType],
      usageTypes: [MediaUsageType.comment],
      userId: payload.userId,
      refId: payload.postId,
      usageCount: 1,
    );

    final fileKey = keys.isEmpty ? null : keys.first;
    if (fileKey == null || fileKey.isEmpty) {
      throw StateError('미디어 업로드에 실패했습니다.');
    }

    onProgress?.call(0.7);
    final result = await _commentController.createComment(
      postId: payload.postId,
      userId: payload.userId,
      parentId: payload.parentId ?? 0,
      replyUserId: payload.replyUserId ?? 0,
      fileKey: fileKey,
      locationX: payload.locationX,
      locationY: payload.locationY,
      type: CommentType.photo,
    );
    onProgress?.call(0.9);

    if (!result.success) {
      throw StateError('미디어 댓글 저장에 실패했습니다.');
    }

    return _resolvePersistedComment(
      payload: payload,
      directComment: result.comment,
      matcher: (comments) => _findSavedMediaComment(comments, payload, fileKey),
    );
  }

  Future<Comment> _resolvePersistedComment({
    required CommentSavePayload payload,
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
    if (comment == null) {
      return null;
    }
    if (comment.id == null || comment.userId == null) {
      return null;
    }
    return comment;
  }

  Comment? _findSavedTextComment(
    List<Comment> comments,
    CommentSavePayload payload,
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
    CommentSavePayload payload,
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
    CommentSavePayload payload,
    String fileKey,
  ) {
    for (final comment in comments.reversed) {
      if (comment.userId != payload.userId) {
        continue;
      }

      final sameFileKey = (comment.fileKey ?? '').trim() == fileKey;
      if (sameFileKey) {
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

  bool _isNearCoordinate(double? a, double? b) {
    if (a == null || b == null) {
      return false;
    }
    return (a - b).abs() <= 0.03;
  }

  String _encodeWaveformForRequest(List<double>? waveformData) {
    return _waveformCodec.encodeOrEmpty(
      waveformData,
      maxSamples: _kMaxWaveformSamples,
    );
  }

  int _parsePostId(String mediaId) {
    final postId = int.tryParse(mediaId);
    if (postId == null || postId <= 0) {
      throw StateError('유효하지 않은 mediaId(postId)입니다: $mediaId');
    }
    return postId;
  }
}
