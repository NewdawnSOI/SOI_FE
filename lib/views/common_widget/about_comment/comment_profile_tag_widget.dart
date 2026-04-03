import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../api/controller/comment_controller.dart';
import '../../../api/controller/media_controller.dart';
import '../../../api/models/comment.dart';
import '../../../api/services/media_service.dart';
import '../../../api/media_processing/waveform_codec.dart';
import '../photo/tag_pointer.dart';
import '../photo/widgets/photo_circle_avatar.dart';
import '../user/current_user_image_builder.dart';
import 'comment_for_pending.dart';
import 'comment_save_payload.dart';

/// 댓글 프로필 태그 위젯
/// - 댓글 작성자의 프로필 이미지를 원형으로 보여주는 태그입니다.
/// - 댓글 작성 중인 위치에 드래그하여 배치할 수 있으며, 드래그가 완료되면 댓글 작성이 완료되는 방식으로 동작합니다.
/// - 댓글 작성이 완료되면, 부모 위젯에 댓글 저장 진행 상황과 결과를 전달하는 역할도 수행합니다.
///
/// fields:
/// - [payload]: 댓글 저장에 필요한 정보를 담고 있는 객체입니다. 텍스트 댓글, 음성 댓글, 미디어 댓글 등 다양한 유형의 댓글 저장에 필요한 정보를 포함합니다.
/// - [resolveDropRelativePosition]: 드래그가 완료된 후, 댓글이 작성될 위치의 상대 좌표를 비동기로 조회하는 함수입니다. 댓글이 작성될 위치를 결정하는 데 사용됩니다.
/// - [onSaveProgress]: 댓글 저장 진행 상황이 업데이트될 때 호출되는 콜백 함수입니다. 진행 상황을 0.0 ~ 1.0 사이의 값으로 전달하여, 부모 위젯에서 프로그레스 표시 등에 활용할 수 있도록 합니다.
/// - [onSaveSuccess]: 댓글 저장이 성공적으로 완료되었을 때 호출되는 콜백 함수입니다. 저장된 댓글 객체를 인자로 전달하여, 부모 위젯에서 저장된 댓글 정보를 활용할 수 있도록 합니다.
/// - [onSaveFailure]: 댓글 저장이 실패했을 때 호출되는 콜백 함수입니다. 발생한 오류 객체를 인자로 전달하여, 부모 위젯에서 오류 처리 등을 할 수 있도록 합니다.
/// - [onDropCancelled]: 드래그가 취소되었을 때 호출되는 콜백 함수입니다. 댓글 작성이 취소되었음을 부모 위젯에 알리는 역할을 합니다.
/// - [dragData]: 드래그할 때 전달되는 데이터입니다. 기본값은 'profile_image'입니다.
/// - [avatarSize]: 프로필 태그의 원형 부분의 크기를 결정하는 값입니다. 기본값은 27입니다.
class CommentProfileTagWidget extends StatefulWidget {
  final CommentSavePayload payload;
  final FutureOr<Offset?> Function() resolveDropRelativePosition;
  final ValueChanged<double>? onSaveProgress;
  final ValueChanged<Comment>? onSaveSuccess;
  final ValueChanged<Object>? onSaveFailure;
  final VoidCallback? onDropCancelled;
  final String dragData;
  final double avatarSize;

  const CommentProfileTagWidget({
    super.key,
    required this.payload,
    required this.resolveDropRelativePosition,
    this.onSaveProgress,
    this.onSaveSuccess,
    this.onSaveFailure,
    this.onDropCancelled,
    this.dragData = 'profile_image',
    this.avatarSize = 27,
  });

  @override
  State<CommentProfileTagWidget> createState() =>
      _CommentProfileTagWidgetState();
}

class _CommentProfileTagWidgetState extends State<CommentProfileTagWidget> {
  static const int _kMaxWaveformSamples = 30;
  static final WaveformCodec _waveformCodec = WaveformCodec();

  // 댓글 저장 후, API에서 저장된 댓글 정보를 조회하여 id/userId를 확인하는 최대 시도 횟수입니다.
  // (실제 저장된 댓글이 조회되지 않는 경우에 대비한 폴백 로직입니다.)
  static const int _kSavedCommentLookupAttempts = 4;

  // 댓글 저장 후, 저장된 댓글이 API에서 조회되기까지의 예상 지연 시간입니다.
  static const Duration _kSavedCommentLookupDelay = Duration(milliseconds: 180);

  // 댓글 저장 진행 상태를 나타내는 플래그입니다.
  bool _isSaving = false;

  // 댓글 저장 진행 상황을 0.0 ~ 1.0 사이의 값으로 나타냅니다.
  // 부모 위젯에 전달하여 프로그레스 표시 등에 활용할 수 있습니다.
  double _progress = 0.0;

  /// 드래그 앵커 위치를 결정하는 메서드입니다.
  /// 태그의 원형 부분의 중심에서 포인터의 끝까지의 오프셋을 반환하여, 드래그 시 태그가 포인터에 맞춰지도록 합니다.
  ///
  /// Parameters:
  /// - [draggable]: 드래그 가능한 위젯입니다.
  /// - [context]: 빌드 컨텍스트입니다.
  /// - [position]: 드래그 시작 시의 글로벌 위치입니다.
  ///
  /// Returns:
  /// - [Offset]: 드래그 앵커로 사용할 오프셋입니다.
  Offset _tagPointerDragAnchor(
    Draggable<Object> draggable,
    BuildContext context,
    Offset position,
  ) {
    return TagBubble.pointerTipOffset(
      contentSize: widget.avatarSize,
      padding: kPendingCommentTagPadding,
    );
  }

  /// 댓글 저장 진행 상황 업데이트 메서드입니다.
  /// 댓글 저장 진행 상황을 0.0 ~ 1.0 사이의 값으로 업데이트하고, 부모 위젯에 전달하는 역할을 합니다.
  ///
  /// Parameters:
  /// - [value]: 업데이트할 진행 상황 값입니다. 0.0 ~ 1.0 사이의 값으로 전달되어야 합니다.
  void _updateProgress(double value) {
    _progress = value.clamp(0.0, 1.0).toDouble();
    widget.onSaveProgress?.call(_progress);
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

  Future<Comment> _resolvePersistedComment({
    required CommentSavePayload payload,
    required Comment? directComment,
    required Comment? Function(List<Comment> comments) matcher,
  }) async {
    final persistedDirect = _persistedCommentOrNull(directComment);
    if (persistedDirect != null) {
      return persistedDirect;
    }

    final commentController = context.read<CommentController>();
    for (var attempt = 0; attempt < _kSavedCommentLookupAttempts; attempt++) {
      final comments = await commentController.getComments(
        postId: payload.postId,
      );
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

  Future<Comment> _saveTextComment(CommentSavePayload payload) async {
    final commentController = context.read<CommentController>();

    _updateProgress(0.45);
    final result = await commentController.createComment(
      postId: payload.postId,
      userId: payload.userId,
      parentId: payload.parentId ?? 0,
      replyUserId: payload.replyUserId ?? 0,
      text: payload.text,
      locationX: payload.locationX,
      locationY: payload.locationY,
      type: CommentType.text,
    );

    _updateProgress(0.9);

    if (!result.success) {
      throw StateError('댓글 저장에 실패했습니다.');
    }

    return _resolvePersistedComment(
      payload: payload,
      directComment: result.comment,
      matcher: (comments) => _findSavedTextComment(comments, payload),
    );
  }

  Future<Comment> _saveAudioComment(CommentSavePayload payload) async {
    final commentController = context.read<CommentController>();
    final mediaController = context.read<MediaController>();

    final audioPath = (payload.audioPath ?? '').trim();
    if (audioPath.isEmpty) {
      throw StateError('오디오 경로가 없습니다.');
    }

    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw StateError('녹음 파일을 찾을 수 없습니다.');
    }

    _updateProgress(0.2);
    final multipartFile = await mediaController.fileToMultipart(audioFile);

    _updateProgress(0.45);
    final audioKey = await mediaController.uploadCommentAudio(
      file: multipartFile,
      userId: payload.userId,
      postId: payload.postId,
    );

    if (audioKey == null || audioKey.isEmpty) {
      throw StateError('음성 업로드에 실패했습니다.');
    }

    _updateProgress(0.65);
    final result = await commentController.createAudioComment(
      postId: payload.postId,
      userId: payload.userId,
      audioFileKey: audioKey,
      waveformData: _encodeWaveformForRequest(payload.waveformData),
      duration: payload.duration ?? 0,
      locationX: payload.locationX ?? 0.0,
      locationY: payload.locationY ?? 0.0,
    );

    _updateProgress(0.9);

    if (!result.success) {
      throw StateError('음성 댓글 저장에 실패했습니다.');
    }

    return _resolvePersistedComment(
      payload: payload,
      directComment: result.comment,
      matcher: (comments) => _findSavedAudioComment(comments, payload),
    );
  }

  Future<Comment> _saveMediaComment(CommentSavePayload payload) async {
    final commentController = context.read<CommentController>();
    final mediaController = context.read<MediaController>();

    final localFilePath = (payload.localFilePath ?? '').trim();
    if (localFilePath.isEmpty) {
      throw StateError('미디어 경로가 없습니다.');
    }

    final mediaFile = File(localFilePath);
    if (!await mediaFile.exists()) {
      throw StateError('미디어 파일을 찾을 수 없습니다.');
    }

    _updateProgress(0.2);
    final multipartFile = await mediaController.fileToMultipart(mediaFile);

    final mediaType = payload.kind == CommentDraftKind.video
        ? MediaType.video
        : MediaType.image;
    _updateProgress(0.45);
    final keys = await mediaController.uploadMedia(
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

    _updateProgress(0.7);
    final result = await commentController.createComment(
      postId: payload.postId,
      userId: payload.userId,
      parentId: payload.parentId ?? 0,
      replyUserId: payload.replyUserId ?? 0,
      fileKey: fileKey,
      locationX: payload.locationX,
      locationY: payload.locationY,
      type: CommentType.photo,
    );
    _updateProgress(0.9);

    if (!result.success) {
      throw StateError('미디어 댓글 저장에 실패했습니다.');
    }

    return _resolvePersistedComment(
      payload: payload,
      directComment: result.comment,
      matcher: (comments) => _findSavedMediaComment(comments, payload, fileKey),
    );
  }

  bool _isNearCoordinate(double? a, double? b) {
    if (a == null || b == null) {
      return false;
    }
    return (a - b).abs() <= 0.03;
  }

  /// 댓글 저장용 웨이브폼을 공통 코덱으로 JSON 문자열에 맞춰 압축합니다.
  String _encodeWaveformForRequest(List<double>? waveformData) {
    return _waveformCodec.encodeOrEmpty(
      waveformData,
      maxSamples: _kMaxWaveformSamples,
    );
  }

  Future<void> _handleDropAccepted() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    _updateProgress(0.05);

    try {
      final validationError = widget.payload.validateForSave();
      if (validationError != null) {
        throw StateError(validationError);
      }

      await Future<void>.delayed(Duration.zero);
      final relativePosition = await widget.resolveDropRelativePosition();
      if (relativePosition == null) {
        throw StateError('댓글 위치를 확인하지 못했습니다.');
      }

      final payloadWithLocation = widget.payload.copyWithLocation(
        locationX: relativePosition.dx,
        locationY: relativePosition.dy,
      );

      Comment savedComment;
      switch (payloadWithLocation.kind) {
        case CommentDraftKind.text:
          savedComment = await _saveTextComment(payloadWithLocation);
          break;
        case CommentDraftKind.audio:
          savedComment = await _saveAudioComment(payloadWithLocation);
          break;
        case CommentDraftKind.image:
        case CommentDraftKind.video:
          savedComment = await _saveMediaComment(payloadWithLocation);
          break;
      }

      _updateProgress(1.0);
      widget.onSaveSuccess?.call(savedComment);
    } catch (error) {
      _updateProgress(0.0);
      widget.onSaveFailure?.call(error);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// 저장 중 원형 progress를 유지하면서 프로필 아바타를 일관된 캐시 정책으로 렌더링합니다.
  Widget _buildAvatar(String? imageUrl, {String? cacheKey}) {
    return SizedBox(
      width: widget.avatarSize,
      height: widget.avatarSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isSaving)
            SizedBox(
              width: widget.avatarSize,
              height: widget.avatarSize,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                backgroundColor: Colors.black.withValues(alpha: 0.3),
              ),
            ),
          ApiPhotoCircleAvatar(
            imageUrl: imageUrl,
            size: widget.avatarSize,
            cacheKey: cacheKey,
          ),
        ],
      ),
    );
  }

  /// 드래그용 태그와 저장 중 태그가 같은 크기와 같은 이미지 소스를 공유하도록 현재 표시 상태를 조립합니다.
  @override
  Widget build(BuildContext context) {
    final tagBubble = TagBubble(
      contentSize: widget.avatarSize,
      padding: kPendingCommentTagPadding,
      backgroundColor: kPendingCommentTagBackgroundColor,
      child: CurrentUserImageBuilder(
        imageKind: CurrentUserImageKind.profile,
        targetUserId: widget.payload.userId,
        fallbackImageUrl: widget.payload.profileImageUrl,
        fallbackImageKey: widget.payload.profileImageKey,
        builder: (context, imageUrl, cacheKey) {
          return _buildAvatar(imageUrl, cacheKey: cacheKey);
        },
      ),
    );

    if (_isSaving) {
      return IgnorePointer(child: tagBubble);
    }

    return Draggable<String>(
      data: widget.dragData,
      dragAnchorStrategy: _tagPointerDragAnchor,
      feedback: Transform.scale(
        scale: 1.2,
        child: Opacity(opacity: 0.85, child: tagBubble),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tagBubble),
      onDragEnd: (details) {
        if (!details.wasAccepted) {
          widget.onDropCancelled?.call();
          return;
        }
        unawaited(_handleDropAccepted());
      },
      child: tagBubble,
    );
  }
}
