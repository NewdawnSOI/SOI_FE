import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/controller/notification_controller.dart';
import 'package:soi/api/models/notification.dart';
import 'package:soi/api/services/notification_service.dart';
import 'package:soi_api_client/api.dart';

class _UnusedNotificationApi extends NotificationAPIApi {}

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService() : super(notificationApi: _UnusedNotificationApi());

  final List<int> requestedPages = <int>[];

  @override
  Future<NotificationGetAllResult> getAllNotifications({
    required int userId,
    int page = 0,
  }) async {
    requestedPages.add(page);
    return NotificationGetAllResult(
      friendRequestCount: 1,
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
  });
}
