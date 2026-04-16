import '../../../api/media_processing/media_processing_backend.dart';
import '../../../api/media_processing/waveform_codec.dart';
import '../../../api/models/comment.dart';

enum TaggingDraftKind { text, audio, image, video }

/// 태그 저장에 필요한 draft/위치/작성자 정보를 단일 payload로 묶습니다.
class TaggingSavePayload {
  static final WaveformCodec _waveformCodec = WaveformCodec();

  final int postId;
  final int userId;
  final TaggingDraftKind kind;

  final String? text;
  final String? audioPath;
  final List<double>? waveformData;
  final int? duration;
  final String? fileKey;
  final String? localFilePath;

  final int? parentId;
  final int? replyUserId;
  final String? profileImageUrl;
  final String? profileImageKey;

  final double? locationX;
  final double? locationY;

  const TaggingSavePayload({
    required this.postId,
    required this.userId,
    required this.kind,
    this.text,
    this.audioPath,
    this.waveformData,
    this.duration,
    this.fileKey,
    this.localFilePath,
    this.parentId,
    this.replyUserId,
    this.profileImageUrl,
    this.profileImageKey,
    this.locationX,
    this.locationY,
  });

  CommentType get commentType {
    switch (kind) {
      case TaggingDraftKind.text:
        return CommentType.text;
      case TaggingDraftKind.audio:
        return CommentType.audio;
      case TaggingDraftKind.image:
      case TaggingDraftKind.video:
        return CommentType.photo;
    }
  }

  String? validateForSave() {
    if (postId <= 0) {
      return '유효하지 않은 postId';
    }
    if (userId <= 0) {
      return '유효하지 않은 userId';
    }

    switch (kind) {
      case TaggingDraftKind.text:
        if ((text ?? '').trim().isEmpty) {
          return '텍스트 댓글 내용이 비어 있습니다.';
        }
        return null;
      case TaggingDraftKind.audio:
        if ((audioPath ?? '').trim().isEmpty) {
          return '오디오 경로가 없습니다.';
        }
        return null;
      case TaggingDraftKind.image:
      case TaggingDraftKind.video:
        final hasFileKey = (fileKey ?? '').trim().isNotEmpty;
        final hasLocalPath = (localFilePath ?? '').trim().isNotEmpty;
        if (!hasFileKey && !hasLocalPath) {
          return '파일 정보가 없습니다.';
        }
        return null;
    }
  }

  TaggingSavePayload copyWithLocation({
    required double locationX,
    required double locationY,
  }) {
    return TaggingSavePayload(
      postId: postId,
      userId: userId,
      kind: kind,
      text: text,
      audioPath: audioPath,
      waveformData: waveformData,
      duration: duration,
      fileKey: fileKey,
      localFilePath: localFilePath,
      parentId: parentId,
      replyUserId: replyUserId,
      profileImageUrl: profileImageUrl,
      profileImageKey: profileImageKey,
      locationX: locationX,
      locationY: locationY,
    );
  }

  /// 저장 직후 응답이 불완전한 경우에도 overlay UI가 버틸 수 있게 fallback comment를 만듭니다.
  Comment toFallbackComment({String? nickname, String? userProfileUrl}) {
    final waveform = _waveformCodec.encodeOrNull(
      waveformData,
      maxSamples: waveformData?.length ?? 0,
      decimals: 4,
      format: WaveformTransportFormat.csv,
    );

    return Comment(
      id: null,
      userId: userId,
      userProfileKey: profileImageKey,
      text: text,
      fileKey: fileKey,
      audioUrl: audioPath,
      waveformData: waveform,
      duration: duration,
      locationX: locationX,
      locationY: locationY,
      type: commentType,
      replyUserName: null,
      nickname: nickname,
      userProfileUrl: userProfileUrl ?? profileImageUrl ?? profileImageKey,
      fileUrl: localFilePath,
      emojiId: 0,
    );
  }
}
