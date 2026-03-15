import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/api_exception.dart';
import 'package:soi/api/services/notification_device_service.dart';
import 'package:soi_api_client/api.dart';

class _FakeNotificationDeviceApi extends NotificationDeviceAPIApi {
  _FakeNotificationDeviceApi({this.onRegister, this.onDelete});

  final Future<ApiResponseDtoBoolean?> Function(
    NotificationRegisterTokenReqDto,
  )?
  onRegister;
  final Future<ApiResponseDtoBoolean?> Function(NotificationDeleteTokenReqDto)?
  onDelete;

  @override
  Future<ApiResponseDtoBoolean?> register(
    NotificationRegisterTokenReqDto notificationRegisterTokenReqDto,
  ) async {
    final handler = onRegister;
    if (handler == null) {
      throw UnimplementedError('onRegister is not configured');
    }
    return handler(notificationRegisterTokenReqDto);
  }

  @override
  Future<ApiResponseDtoBoolean?> delete(
    NotificationDeleteTokenReqDto notificationDeleteTokenReqDto,
  ) async {
    final handler = onDelete;
    if (handler == null) {
      throw UnimplementedError('onDelete is not configured');
    }
    return handler(notificationDeleteTokenReqDto);
  }
}

void main() {
  group('NotificationDeviceService', () {
    test('registerToken trims token and forwards platform', () async {
      NotificationRegisterTokenReqDto? capturedDto;
      final service = NotificationDeviceService(
        notificationDeviceApi: _FakeNotificationDeviceApi(
          onRegister: (dto) async {
            capturedDto = dto;
            return ApiResponseDtoBoolean(success: true, data: true);
          },
        ),
      );

      final result = await service.registerToken(
        token: '  token-123  ',
        platform: NotificationDevicePlatform.android,
      );

      expect(result, isTrue);
      expect(capturedDto?.token, 'token-123');
      expect(
        capturedDto?.platform,
        NotificationRegisterTokenReqDtoPlatformEnum.ANDROID,
      );
    });

    test('registerToken rejects empty token before API call', () async {
      final service = NotificationDeviceService(
        notificationDeviceApi: _FakeNotificationDeviceApi(
          onRegister: (_) async => ApiResponseDtoBoolean(success: true),
        ),
      );

      await expectLater(
        service.registerToken(
          token: '   ',
          platform: NotificationDevicePlatform.ios,
        ),
        throwsA(isA<BadRequestException>()),
      );
    });

    test('deleteToken maps 401 response to AuthException', () async {
      final service = NotificationDeviceService(
        notificationDeviceApi: _FakeNotificationDeviceApi(
          onDelete: (_) async => throw ApiException(401, 'expired'),
        ),
      );

      await expectLater(
        service.deleteToken('token-123'),
        throwsA(isA<AuthException>()),
      );
    });

    test('deleteToken returns false when API responds without body', () async {
      final service = NotificationDeviceService(
        notificationDeviceApi: _FakeNotificationDeviceApi(
          onDelete: (_) async => null,
        ),
      );

      final result = await service.deleteToken('token-123');
      expect(result, isFalse);
    });
  });
}
