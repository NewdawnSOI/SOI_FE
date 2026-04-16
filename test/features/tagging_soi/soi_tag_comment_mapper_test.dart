import 'package:flutter_test/flutter_test.dart';
import 'package:tagging_core/tagging_core.dart';

import 'package:soi/api/models/comment.dart';
import 'package:soi/features/tagging_soi/tagging_soi.dart';

void main() {
  group('SoiTagCommentMapper', () {
    test(
      'maps SOI comment variants into tag comments without losing coordinates',
      () {
        final replyComment = Comment(
          id: 9,
          threadParentId: 4,
          userId: 12,
          nickname: 'writer',
          replyUserName: 'target',
          userProfileUrl: 'https://example.com/profile.png',
          userProfileKey: 'profiles/me.png',
          createdAt: DateTime(2024, 1, 1, 12),
          replyCommentCount: 3,
          text: 'reply body',
          emojiId: 2,
          audioUrl: 'https://example.com/audio.m4a',
          waveformData: '0.1000,0.2000',
          duration: 7,
          locationX: 0.35,
          locationY: 0.8,
          type: CommentType.reply,
        );

        final tagComment = SoiTagCommentMapper.fromComment(replyComment);

        expect(tagComment.id, '9');
        expect(tagComment.threadParentId, '4');
        expect(tagComment.replyUserName, 'target');
        expect(tagComment.locationX, 0.35);
        expect(tagComment.locationY, 0.8);
        expect(tagComment.waveformData, '0.1000,0.2000');
        expect(tagComment.kind, TagCommentKind.reply);
      },
    );

    test(
      'maps tag media comments back to SOI comments preserving nullability',
      () {
        const tagComment = TagComment(
          id: '21',
          threadParentId: '11',
          userId: '4',
          nickname: 'artist',
          userProfileKey: 'profiles/a.png',
          fileKey: 'comments/video.mp4',
          locationX: 0.45,
          locationY: 0.12,
          kind: TagCommentKind.video,
        );

        final comment = SoiTagCommentMapper.toComment(tagComment);

        expect(comment.id, 21);
        expect(comment.threadParentId, 11);
        expect(comment.userId, 4);
        expect(comment.nickname, 'artist');
        expect(comment.userProfileKey, 'profiles/a.png');
        expect(comment.fileKey, 'comments/video.mp4');
        expect(comment.locationX, 0.45);
        expect(comment.locationY, 0.12);
        expect(comment.fileUrl, isNull);
        expect(comment.text, isNull);
        expect(comment.type, CommentType.video);
      },
    );

    test('maps photo comments and round-trips media identity fields', () {
      final source = Comment(
        id: 33,
        userId: 18,
        nickname: 'camera',
        userProfileKey: 'profiles/camera.png',
        fileUrl: 'https://example.com/comments/photo.jpg',
        fileKey: 'comments/photo.jpg',
        locationX: 0.5,
        locationY: 0.5,
        type: CommentType.photo,
      );

      final tagComment = SoiTagCommentMapper.fromComment(source);
      final restored = SoiTagCommentMapper.toComment(tagComment);

      expect(tagComment.kind, TagCommentKind.image);
      expect(restored.type, CommentType.photo);
      expect(restored.fileUrl, source.fileUrl);
      expect(restored.fileKey, source.fileKey);
      expect(restored.userProfileKey, source.userProfileKey);
    });
  });
}
