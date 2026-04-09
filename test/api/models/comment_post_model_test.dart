import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/models/comment.dart';
import 'package:soi/api/models/notification.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi/api/models/user.dart';
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
        postType: PostRespDtoPostTypeEnum.IMAGE,
        savedAspectRatio: 1.25,
        isFromGallery: true,
      );

      final post = Post.fromDto(dto);

      expect(post.postType, PostType.image);
      expect(post.commentCount, 12);
      expect(post.savedAspectRatio, 1.25);
      expect(post.isFromGallery, isTrue);
      expect(post.prefersContainMediaFit, isTrue);
      expect(post.toJson()['postType'], 'IMAGE');
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

    test(
      'treats url-only media payloads as media for profile/grid rendering',
      () {
        final post = Post(
          id: 12,
          nickName: 'alice',
          content: 'caption',
          postFileUrl: 'https://example.com/posts/url-only.jpg',
          postType: PostType.image,
        );

        expect(post.hasMedia, isTrue);
        expect(post.hasImage, isTrue);
        expect(post.isVideo, isFalse);
      },
    );

    test('detects video posts from url when key is absent', () {
      final post = Post(
        id: 13,
        nickName: 'alice',
        postFileUrl: 'https://example.com/posts/url-only.mp4',
        postType: PostType.video,
      );

      expect(post.hasMedia, isTrue);
      expect(post.isVideo, isTrue);
      expect(post.hasImage, isFalse);
    });

    test('treats postType video as video even when legacy urls lack extension', () {
      final post = Post(
        id: 14,
        nickName: 'alice',
        postFileUrl: 'https://example.com/media/legacy-video',
        postType: PostType.video,
      );

      expect(post.hasMedia, isTrue);
      expect(post.isVideo, isTrue);
      expect(post.hasImage, isFalse);
    });

    test('treats postType image as image even when legacy urls lack extension', () {
      final post = Post(
        id: 15,
        nickName: 'alice',
        postFileUrl: 'https://example.com/media/legacy-image',
        postType: PostType.image,
      );

      expect(post.hasMedia, isTrue);
      expect(post.isVideo, isFalse);
      expect(post.hasImage, isTrue);
    });

    test('keeps nullable postType when response omits it', () {
      final dto = PostRespDto(id: 9, nickname: 'alice');

      final post = Post.fromDto(dto);

      expect(post.postType, isNull);
    });

    test('maps generated postType enums to current domain types', () {
      final textPost = Post.fromDto(
        PostRespDto(
          id: 11,
          nickname: 'alice',
          postType: PostRespDtoPostTypeEnum.TEXT,
        ),
      );
      final imagePost = Post.fromDto(
        PostRespDto(
          id: 12,
          nickname: 'alice',
          postType: PostRespDtoPostTypeEnum.IMAGE,
        ),
      );
      final videoPost = Post.fromDto(
        PostRespDto(
          id: 13,
          nickname: 'alice',
          postType: PostRespDtoPostTypeEnum.VIDEO,
        ),
      );

      expect(textPost.postType, PostType.textOnly);
      expect(imagePost.postType, PostType.image);
      expect(videoPost.postType, PostType.video);
    });

    test('keeps legacy postType aliases readable from cached json', () {
      final textOnlyPost = Post.fromJson({
        'id': 14,
        'nickname': 'alice',
        'postType': 'TEXT_ONLY',
      });
      final multiMediaPost = Post.fromJson({
        'id': 15,
        'nickname': 'alice',
        'postType': 'MULTIMEDIA',
      });

      expect(textOnlyPost.postType, PostType.textOnly);
      expect(multiMediaPost.postType, PostType.multiMedia);
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

  group('User model image resolution', () {
    test('prefers explicit image urls and keeps keys for cache resolution', () {
      const user = User(
        id: 1,
        userId: 'alice',
        name: 'Alice',
        profileImageKey: 'profiles/alice.webp',
        profileImageUrl: 'https://example.com/profiles/alice.webp',
        profileCoverImageKey: 'covers/alice.webp',
        profileCoverImageUrl: 'https://example.com/covers/alice.webp',
        phoneNumber: '01012345678',
      );

      expect(
        user.displayProfileImageUrl,
        'https://example.com/profiles/alice.webp',
      );
      expect(user.profileImageCacheKey, 'profiles/alice.webp');
      expect(
        user.displayCoverImageUrl,
        'https://example.com/covers/alice.webp',
      );
      expect(user.profileCoverImageCacheKey, 'covers/alice.webp');
    });

    test('uses legacy url-shaped key only as display fallback', () {
      const user = User(
        id: 2,
        userId: 'bob',
        name: 'Bob',
        profileImageKey: 'https://legacy.example.com/profiles/bob.webp',
        phoneNumber: '01098765432',
      );

      expect(
        user.displayProfileImageUrl,
        'https://legacy.example.com/profiles/bob.webp',
      );
      expect(
        user.profileImageCacheKey,
        'https://legacy.example.com/profiles/bob.webp',
      );
    });

    test('serializes empty optional user fields as empty strings', () {
      const user = User(
        id: 3,
        userId: 'charlie',
        name: 'Charlie',
        phoneNumber: '01011112222',
      );

      expect(user.toJson()['profileImageKey'], '');
      expect(user.toJson()['profileImageUrl'], '');
      expect(user.toJson()['profileCoverImageKey'], '');
      expect(user.toJson()['profileCoverImageUrl'], '');
      expect(user.toJson()['birthDate'], '');
    });
  });

  group('Notification model image resolution', () {
    test('prefers explicit image urls and keeps keys for cache resolution', () {
      const notification = AppNotification(
        id: 1,
        userProfileKey: 'profiles/alice.webp',
        userProfileUrl: 'https://example.com/profiles/alice.webp',
      );

      expect(
        notification.userProfileImageUrl,
        'https://example.com/profiles/alice.webp',
      );
      expect(notification.userProfileCacheKey, 'profiles/alice.webp');
      expect(
        notification.userProfile,
        'https://example.com/profiles/alice.webp',
      );
      expect(notification.hasUserProfile, isTrue);
    });

    test('treats raw keys as cache-only when no direct url is available', () {
      const notification = AppNotification(
        id: 2,
        userProfileKey: 'profiles/cache-only.webp',
      );

      expect(notification.userProfileImageUrl, isNull);
      expect(notification.userProfileCacheKey, 'profiles/cache-only.webp');
      expect(notification.hasUserProfile, isTrue);
    });
  });
}
