import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/controller/notification_controller.dart';
import 'package:soi/api/models/notification.dart';
import 'package:soi/api/services/notification_service.dart';
import 'package:soi_api_client/api.dart';

class _UnusedNotificationApi extends NotificationAPIApi {}

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService({
    this.firstPageResult = const NotificationGetAllResult(
      friendRequestCount: 1,
      notifications: [AppNotification(id: 1, text: 'page-0')],
    ),
  }) : super(notificationApi: _UnusedNotificationApi());

  final List<int> requestedPages = <int>[];
  final NotificationGetAllResult firstPageResult;

  @override
  Future<NotificationGetAllResult> getAllNotifications({
    required int userId,
    int page = 0,
  }) async {
    requestedPages.add(page);
    if (page == 0) {
      return firstPageResult;
    }
    return NotificationGetAllResult(
      friendRequestCount: 0,
      notifications: [AppNotification(id: page + 1, text: 'page-$page')],
    );
  }
}

void main() {
  group('NotificationController paging', () {
    test('caches first page but bypasses cache for later pages', () async {
      final fakeService = _FakeNotificationService();
      final controller = NotificationController(
        notificationService: fakeService,
      );

      final first = await controller.getAllNotifications(userId: 7, page: 0);
      final cached = await controller.getAllNotifications(userId: 7, page: 0);
      final secondPage = await controller.getAllNotifications(
        userId: 7,
        page: 1,
      );

      expect(first.notifications.single.id, 1);
      expect(cached.notifications.single.id, 1);
      expect(secondPage.notifications.single.id, 2);
      expect(fakeService.requestedPages, <int>[0, 1]);
    });

    test('exposes unread badge state from the cached first page', () async {
      final controller = NotificationController(
        notificationService: _FakeNotificationService(
          firstPageResult: const NotificationGetAllResult(
            friendRequestCount: 0,
            notifications: [
              AppNotification(id: 1, text: 'read', isRead: true),
              AppNotification(id: 2, text: 'unread', isRead: false),
            ],
          ),
        ),
      );

      expect(controller.hasUnreadNotifications, isFalse);

      await controller.getAllNotifications(userId: 7);

      expect(controller.hasUnreadNotifications, isTrue);
    });

    test('treats pending friend requests as unread badge state', () async {
      final controller = NotificationController(
        notificationService: _FakeNotificationService(
          firstPageResult: const NotificationGetAllResult(
            friendRequestCount: 2,
            notifications: [AppNotification(id: 1, text: 'read', isRead: true)],
          ),
        ),
      );

      await controller.getAllNotifications(userId: 7);

      expect(controller.hasUnreadNotifications, isTrue);
    });
  });
}
