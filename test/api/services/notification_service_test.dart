import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/models/notification.dart';
import 'package:soi/api/services/notification_service.dart';
import 'package:soi_api_client/api.dart';

class _FakeNotificationApi extends NotificationAPIApi {
  _FakeNotificationApi({this.onGetAll, this.onGetFriend});

  final Future<ApiResponseDtoNotificationGetAllRespDto?> Function(int page)?
  onGetAll;
  final Future<ApiResponseDtoListNotificationRespDto?> Function(int page)?
  onGetFriend;

  @override
  Future<ApiResponseDtoNotificationGetAllRespDto?> getAll(int page) async {
    final handler = onGetAll;
    if (handler == null) {
      throw UnimplementedError('onGetAll is not configured');
    }
    return handler(page);
  }

  @override
  Future<ApiResponseDtoListNotificationRespDto?> getFriend(int page) async {
    final handler = onGetFriend;
    if (handler == null) {
      throw UnimplementedError('onGetFriend is not configured');
    }
    return handler(page);
  }
}

NotificationRespDto _notificationDto() {
  return NotificationRespDto(
    id: 10,
    text: 'reply added',
    nickname: 'minchan',
    type: NotificationRespDtoTypeEnum.COMMENT_REPLY_ADDED,
    isRead: false,
    categoryIdForPost: 77,
    relatedId: 88,
    replyCommentId: 99,
    parentCommentId: 55,
  );
}

void main() {
  group('NotificationService response mapping', () {
    test('getAllNotifications preserves reply comment ids', () async {
      final service = NotificationService(
        notificationApi: _FakeNotificationApi(
          onGetAll: (page) async {
            expect(page, 0);
            return ApiResponseDtoNotificationGetAllRespDto(
              success: true,
              data: NotificationGetAllRespDto(
                friendReqCount: 1,
                notifications: [_notificationDto()],
              ),
            );
          },
        ),
      );

      final result = await service.getAllNotifications(userId: 7);

      expect(result.friendRequestCount, 1);
      expect(result.notifications, hasLength(1));
      expect(
        result.notifications.first.type,
        AppNotificationType.commentReplyAdded,
      );
      expect(result.notifications.first.relatedId, 88);
      expect(result.notifications.first.replyCommentId, 99);
      expect(result.notifications.first.parentCommentId, 55);
    });

    test('getFriendNotifications preserves reply comment ids', () async {
      final service = NotificationService(
        notificationApi: _FakeNotificationApi(
          onGetFriend: (page) async {
            expect(page, 0);
            return ApiResponseDtoListNotificationRespDto(
              success: true,
              data: [_notificationDto()],
            );
          },
        ),
      );

      final result = await service.getFriendNotifications(userId: 7);

      expect(result, hasLength(1));
      expect(result.first.type, AppNotificationType.commentReplyAdded);
      expect(result.first.relatedId, 88);
      expect(result.first.replyCommentId, 99);
      expect(result.first.parentCommentId, 55);
    });
  });
}
