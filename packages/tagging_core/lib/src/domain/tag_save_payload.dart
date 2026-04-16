import 'tag_models.dart';

/// 태그 저장에 필요한 draft와 위치 정보를 묶어 전달합니다.
class TagSavePayload {
  const TagSavePayload({
    required this.scopeId,
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

  final TagScopeId scopeId;
  final TagEntityId userId;
  final TagDraftKind kind;
  final String? text;
  final String? audioPath;
  final List<double>? waveformData;
  final int? duration;
  final String? fileKey;
  final String? localFilePath;
  final TagEntityId? parentId;
  final TagEntityId? replyUserId;
  final String? profileImageUrl;
  final String? profileImageKey;
  final double? locationX;
  final double? locationY;

  String? validateForSave() {
    if (scopeId.trim().isEmpty) {
      return '유효하지 않은 scopeId';
    }
    if (userId.trim().isEmpty) {
      return '유효하지 않은 userId';
    }

    switch (kind) {
      case TagDraftKind.text:
        if ((text ?? '').trim().isEmpty) {
          return '텍스트 댓글 내용이 비어 있습니다.';
        }
        return null;
      case TagDraftKind.audio:
        if ((audioPath ?? '').trim().isEmpty) {
          return '오디오 경로가 없습니다.';
        }
        return null;
      case TagDraftKind.image:
      case TagDraftKind.video:
        final hasFileKey = (fileKey ?? '').trim().isNotEmpty;
        final hasLocalPath = (localFilePath ?? '').trim().isNotEmpty;
        if (!hasFileKey && !hasLocalPath) {
          return '파일 정보가 없습니다.';
        }
        return null;
    }
  }

  TagSavePayload copyWithLocation(TagPosition position) {
    return TagSavePayload(
      scopeId: scopeId,
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
      locationX: position.x,
      locationY: position.y,
    );
  }
}
