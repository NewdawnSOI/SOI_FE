import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/models/notification.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi/app/push/app_push_payload.dart';
import 'package:soi/views/about_notification/services/notification_navigation_handler.dart';

void main() {
  group('NotificationNavigationHandler.resolvePushNavigation', () {
    test('routes category invite pushes to notifications screen', () {
      final route = NotificationNavigationHandler.resolvePushNavigation(
        const AppPushPayload(type: AppNotificationType.categoryInvite),
      );

      expect(route.action, PushNavigationAction.notifications);
      expect(route.categoryId, isNull);
      expect(route.postId, isNull);
    });

    test('routes friend request style pushes to friend request screen', () {
      final friendRequestRoute =
          NotificationNavigationHandler.resolvePushNavigation(
            const AppPushPayload(type: AppNotificationType.friendRequest),
          );
      final friendRespondRoute =
          NotificationNavigationHandler.resolvePushNavigation(
            const AppPushPayload(type: AppNotificationType.friendRespond),
          );

      expect(friendRequestRoute.action, PushNavigationAction.friendRequest);
      expect(friendRespondRoute.action, PushNavigationAction.friendRequest);
    });

    test('routes category added pushes to category screen', () {
      final route = NotificationNavigationHandler.resolvePushNavigation(
        const AppPushPayload(
          type: AppNotificationType.categoryAdded,
          categoryId: 19,
        ),
      );

      expect(route.action, PushNavigationAction.category);
      expect(route.categoryId, 19);
      expect(route.postId, isNull);
    });

    test('routes post related pushes to category backed detail flow', () {
      final route = NotificationNavigationHandler.resolvePushNavigation(
        const AppPushPayload(
          type: AppNotificationType.commentReplyAdded,
          categoryId: 7,
          postId: 33,
        ),
      );

      expect(route.action, PushNavigationAction.categoryPost);
      expect(route.categoryId, 7);
      expect(route.postId, 33);
    });

    test('falls back to notifications when post route info is incomplete', () {
      final route = NotificationNavigationHandler.resolvePushNavigation(
        const AppPushPayload(
          type: AppNotificationType.photoAdded,
          categoryId: 7,
        ),
      );

      expect(route.action, PushNavigationAction.notifications);
      expect(route.categoryId, isNull);
      expect(route.postId, isNull);
    });
  });

  group('NotificationNavigationHandler.resolvePostDetailLaunch', () {
    test('keeps refreshed category list when target post exists', () {
      final targetPost = const Post(
        id: 11,
        nickName: 'user-a',
        content: 'text only post',
        postType: PostType.textOnly,
      );
      final launch = NotificationNavigationHandler.resolvePostDetailLaunch(
        categoryPosts: <Post>[
          Post(id: 7, nickName: 'user-b'),
          targetPost,
        ],
        postId: 11,
      );

      expect(launch, isNotNull);
      expect(launch?.posts.length, 2);
      expect(launch?.initialIndex, 1);
      expect(launch?.singlePostMode, isFalse);
      expect(launch?.posts[1].id, 11);
    });

    test('falls back to single post mode when target is missing in list', () {
      const exactPost = Post(
        id: 21,
        nickName: 'user-c',
        content: 'newest post',
        postType: PostType.textOnly,
      );

      final launch = NotificationNavigationHandler.resolvePostDetailLaunch(
        categoryPosts: const <Post>[Post(id: 1, nickName: 'user-a')],
        postId: 21,
        exactPost: exactPost,
      );

      expect(launch, isNotNull);
      expect(launch?.posts.length, 1);
      expect(launch?.posts.first.id, 21);
      expect(launch?.initialIndex, 0);
      expect(launch?.singlePostMode, isTrue);
    });

    test('returns null when neither list nor exact post contains target', () {
      final launch = NotificationNavigationHandler.resolvePostDetailLaunch(
        categoryPosts: const <Post>[Post(id: 1, nickName: 'user-a')],
        postId: 99,
        exactPost: const Post(id: 42, nickName: 'user-b'),
      );

      expect(launch, isNull);
    });
  });
}
