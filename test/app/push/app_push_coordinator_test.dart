import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/models/notification.dart';
import 'package:soi/app/push/app_push_coordinator.dart';

void main() {
  group('AppPushCoordinator helpers', () {
    test('decodeNotificationPayload parses valid payload json', () {
      final payload = AppPushCoordinator.decodeNotificationPayload('''
        {
          "notificationId": 31,
          "type": "COMMENT_REPLY_ADDED",
          "categoryId": 7,
          "postId": 11,
          "text": "reply arrived"
        }
        ''');

      expect(payload, isNotNull);
      expect(payload?.notificationId, 31);
      expect(payload?.type, AppNotificationType.commentReplyAdded);
      expect(payload?.categoryId, 7);
      expect(payload?.postId, 11);
      expect(payload?.body, 'reply arrived');
    });

    test('decodeNotificationPayload parses nickname and imageUrl fields', () {
      final payload = AppPushCoordinator.decodeNotificationPayload('''
        {
          "notificationId": 41,
          "type": "COMMENT_ADDED",
          "nickname": "김훈진",
          "body": "새 카테고리에 초대했습니다.",
          "imageUrl": "https://example.com/post.jpg"
        }
        ''');

      expect(payload, isNotNull);
      expect(payload?.nickname, '김훈진');
      expect(payload?.imageUrl, 'https://example.com/post.jpg');
      expect(AppPushCoordinator.resolveDisplayTitle(payload!), '김훈진');
      expect(AppPushCoordinator.resolveDisplayBody(payload), '새 카테고리에 초대했습니다.');
    });

    test(
      'decodeNotificationPayload returns null for malformed payload json',
      () {
        final payload = AppPushCoordinator.decodeNotificationPayload(
          '{"notificationId": 31',
        );

        expect(payload, isNull);
      },
    );

    test('resolvePendingLaunchPayload prefers firebase initial message', () {
      final initialMessage = RemoteMessage.fromMap({
        'data': {
          'notificationId': '41',
          'type': 'CATEGORY_ADDED',
          'categoryId': '99',
          'title': 'remote title',
          'body': 'remote body',
        },
      });
      final localLaunchDetails = NotificationAppLaunchDetails(
        true,
        notificationResponse: const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload:
              '{"notificationId": 12, "type": "COMMENT_REPLY_ADDED", "categoryId": 1, "postId": 2}',
        ),
      );

      final payload = AppPushCoordinator.resolvePendingLaunchPayload(
        initialMessage: initialMessage,
        localNotificationLaunchDetails: localLaunchDetails,
      );

      expect(payload, isNotNull);
      expect(payload?.notificationId, 41);
      expect(payload?.type, AppNotificationType.categoryAdded);
      expect(payload?.categoryId, 99);
      expect(payload?.title, 'remote title');
    });

    test(
      'resolvePendingLaunchPayload falls back to local notification launch payload',
      () {
        final localLaunchDetails = NotificationAppLaunchDetails(
          true,
          notificationResponse: const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload:
                '{"notificationId": 15, "type": "COMMENT_REPLY_ADDED", "categoryId": 8, "postId": 13, "body": "fallback body"}',
          ),
        );

        final payload = AppPushCoordinator.resolvePendingLaunchPayload(
          initialMessage: null,
          localNotificationLaunchDetails: localLaunchDetails,
        );

        expect(payload, isNotNull);
        expect(payload?.notificationId, 15);
        expect(payload?.type, AppNotificationType.commentReplyAdded);
        expect(payload?.categoryId, 8);
        expect(payload?.postId, 13);
        expect(payload?.body, 'fallback body');
      },
    );

    test('resolveDisplayBody falls back to title when nickname exists', () {
      final payload = AppPushCoordinator.decodeNotificationPayload('''
        {
          "notificationId": 52,
          "type": "CATEGORY_ADDED",
          "nickname": "김훈진",
          "title": "새 카테고리에 초대했습니다."
        }
        ''');

      expect(payload, isNotNull);
      expect(AppPushCoordinator.resolveDisplayTitle(payload!), '김훈진');
      expect(AppPushCoordinator.resolveDisplayBody(payload), '새 카테고리에 초대했습니다.');
    });

    test(
      'shouldDisplayBackgroundDataOnlyMessage returns true for data-only text payload',
      () {
        final message = RemoteMessage.fromMap({
          'data': {
            'notificationId': '27',
            'type': 'COMMENT_REPLY_ADDED',
            'text': 'background body',
          },
        });

        expect(
          AppPushCoordinator.shouldDisplayBackgroundDataOnlyMessage(message),
          isTrue,
        );
      },
    );

    test(
      'shouldDisplayBackgroundDataOnlyMessage returns false for invisible data-only payload',
      () {
        final message = RemoteMessage.fromMap({
          'data': {'notificationId': '27', 'type': 'COMMENT_REPLY_ADDED'},
        });

        expect(
          AppPushCoordinator.shouldDisplayBackgroundDataOnlyMessage(message),
          isFalse,
        );
      },
    );

    test(
      'shouldDisplayBackgroundDataOnlyMessage returns false when notification payload exists',
      () {
        final message = RemoteMessage.fromMap({
          'data': {
            'notificationId': '27',
            'type': 'COMMENT_REPLY_ADDED',
            'text': 'background body',
          },
          'notification': {'title': 'remote title', 'body': 'remote body'},
        });

        expect(
          AppPushCoordinator.shouldDisplayBackgroundDataOnlyMessage(message),
          isFalse,
        );
      },
    );
  });
}
