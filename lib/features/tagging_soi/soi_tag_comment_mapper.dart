import 'package:tagging_core/tagging_core.dart';

import '../../api/models/comment.dart';
import 'soi_tagging_ids.dart';

/// SOI Comment 모델과 tagging_core 모델 사이의 변환을 전담합니다.
class SoiTagCommentMapper {
  const SoiTagCommentMapper._();

  static TagComment fromComment(Comment comment) {
    return TagComment(
      id: SoiTaggingIds.entityIdFromInt(comment.id),
      threadParentId: SoiTaggingIds.entityIdFromInt(comment.threadParentId),
      userId: SoiTaggingIds.entityIdFromInt(comment.userId),
      nickname: comment.nickname,
      replyUserName: comment.replyUserName,
      userProfileUrl: comment.userProfileUrl,
      userProfileKey: comment.userProfileKey,
      fileUrl: comment.fileUrl,
      fileKey: comment.fileKey,
      createdAt: comment.createdAt,
      replyCommentCount: comment.replyCommentCount,
      text: comment.text,
      emojiId: comment.emojiId,
      audioUrl: comment.audioUrl,
      waveformData: comment.waveformData,
      duration: comment.duration,
      locationX: comment.locationX,
      locationY: comment.locationY,
      kind: _kindFromCommentType(comment.type),
    );
  }

  static List<TagComment> fromComments(List<Comment> comments) {
    return comments.map(fromComment).toList(growable: false);
  }

  static Comment toComment(TagComment comment) {
    return Comment(
      id: SoiTaggingIds.intFromEntityId(comment.id),
      threadParentId: SoiTaggingIds.intFromEntityId(comment.threadParentId),
      userId: SoiTaggingIds.intFromEntityId(comment.userId),
      nickname: comment.nickname,
      replyUserName: comment.replyUserName,
      userProfileUrl: comment.userProfileUrl,
      userProfileKey: comment.userProfileKey,
      fileUrl: comment.fileUrl,
      fileKey: comment.fileKey,
      createdAt: comment.createdAt,
      replyCommentCount: comment.replyCommentCount,
      text: comment.text,
      emojiId: comment.emojiId,
      audioUrl: comment.audioUrl,
      waveformData: comment.waveformData,
      duration: comment.duration,
      locationX: comment.locationX,
      locationY: comment.locationY,
      type: _commentTypeFromKind(comment.kind),
    );
  }

  static List<Comment> toComments(List<TagComment> comments) {
    return comments.map(toComment).toList(growable: false);
  }

  static TagCommentKind _kindFromCommentType(CommentType type) {
    switch (type) {
      case CommentType.text:
        return TagCommentKind.text;
      case CommentType.audio:
        return TagCommentKind.audio;
      case CommentType.photo:
        return TagCommentKind.image;
      case CommentType.video:
        return TagCommentKind.video;
      case CommentType.reply:
        return TagCommentKind.reply;
    }
  }

  static CommentType _commentTypeFromKind(TagCommentKind kind) {
    switch (kind) {
      case TagCommentKind.text:
        return CommentType.text;
      case TagCommentKind.audio:
        return CommentType.audio;
      case TagCommentKind.image:
        return CommentType.photo;
      case TagCommentKind.video:
        return CommentType.video;
      case TagCommentKind.reply:
        return CommentType.reply;
    }
  }
}
