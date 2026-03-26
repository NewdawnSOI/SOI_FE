import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/models/comment.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi/utils/format_utils.dart';
import 'package:soi_api_client/api.dart';

void main() {
  group('Comment model mapping', () {
    test('maps new DTO fields for reply comments', () {
      final dto = CommentRespDto(
        id: 10,
        userId: 7,
        nickname: 'alice',
        replyUserName: 'bob',
        userProfileUrl: 'https://example.com/profile.jpg',
        userProfileKey: 'profiles/alice.jpg',
        fileUrl: 'https://example.com/comment.jpg',
        fileKey: 'comments/comment.jpg',
        commentType: CommentRespDtoCommentTypeEnum.REPLY,
      );

      final comment = Comment.fromDto(dto);

      expect(comment.userId, 7);
      expect(comment.threadParentId, isNull);
      expect(comment.id, 10);
      expect(comment.replyUserName, 'bob');
      expect(comment.userProfileUrl, 'https://example.com/profile.jpg');
      expect(comment.userProfileKey, 'profiles/alice.jpg');
      expect(comment.fileUrl, 'https://example.com/comment.jpg');
      expect(comment.fileKey, 'comments/comment.jpg');
      expect(comment.type, CommentType.reply);
      expect(comment.toJson()['commentType'], 'REPLY');
    });

    test('maps thread relation fields for parent comments and json', () {
      final dto = CommentRespDto(
        id: 77,
        userId: 9,
        nickname: 'root',
        commentType: CommentRespDtoCommentTypeEnum.TEXT,
      );

      final comment = Comment.fromDto(dto);
      final restored = Comment.fromJson(comment.toJson());

      expect(comment.threadParentId, 77);
      expect(comment.id, 77);
      expect(restored.threadParentId, 77);
    });

    test('normalizes comment createdAt in one shared utility path', () {
      final dto = CommentRespDto(
        id: 88,
        userId: 3,
        nickname: 'alice',
        createdAt: DateTime.parse('2026-03-08T10:00:00Z'),
        commentType: CommentRespDtoCommentTypeEnum.TEXT,
      );
      final json = {
        'id': 89,
        'userId': 3,
        'nickname': 'alice',
        'createdAt': '2026-03-08T10:00:00',
        'commentType': 'TEXT',
      };

      final dtoComment = Comment.fromDto(dto);
      final jsonComment = Comment.fromJson(json);
      final restored = Comment.fromJson(dtoComment.toJson());
      final expected = DateTime.parse('2026-03-08T10:00:00Z').toLocal();

      expect(dtoComment.createdAt, expected);
      expect(jsonComment.createdAt, expected);
      expect(restored.createdAt, expected);
      expect(
        dtoComment.toJson()['createdAt'],
        expected.toUtc().toIso8601String(),
      );
    });
  });

  group('Post model mapping', () {
    test('maps postType/gallery/aspect fields from DTO', () {
      final dto = PostRespDto(
        id: 3,
        nickname: 'alice',
        commentCount: 12,
        postType: PostRespDtoPostTypeEnum.MULTIMEDIA,
        savedAspectRatio: 1.25,
        isFromGallery: true,
      );

      final post = Post.fromDto(dto);

      expect(post.postType, PostType.multiMedia);
      expect(post.commentCount, 12);
      expect(post.savedAspectRatio, 1.25);
      expect(post.isFromGallery, isTrue);
      expect(post.prefersContainMediaFit, isTrue);
      expect(post.toJson()['postType'], 'MULTIMEDIA');
      expect(post.toJson()['commentCount'], 12);
    });

    test(
      'defaults fit preference to cover when gallery metadata is absent',
      () {
        final post = Post(
          id: 11,
          nickName: 'alice',
          postFileKey: 'posts/example.jpg',
          postType: PostType.multiMedia,
        );

        expect(post.prefersContainMediaFit, isFalse);
      },
    );

    test('keeps nullable postType when response omits it', () {
      final dto = PostRespDto(id: 9, nickname: 'alice');

      final post = Post.fromDto(dto);

      expect(post.postType, isNull);
    });

    test('normalizes post createdAt with the shared server time utility', () {
      final dto = PostRespDto(
        id: 10,
        nickname: 'alice',
        createdAt: DateTime.parse('2026-03-08T10:00:00Z'),
      );
      final json = {
        'id': 10,
        'nickname': 'alice',
        'createdAt': '2026-03-08T10:00:00',
      };

      final postFromDto = Post.fromDto(dto);
      final postFromJson = Post.fromJson(json);
      final restored = Post.fromJson(postFromDto.toJson());
      final expected = FormatUtils.normalizeServerDateTime(
        DateTime.parse('2026-03-08T10:00:00Z'),
      );

      expect(postFromDto.createdAt, expected);
      expect(postFromJson.createdAt, expected);
      expect(restored.createdAt, expected);
      expect(
        postFromDto.toJson()['createdAt'],
        expected?.toUtc().toIso8601String(),
      );
    });
  });
}
