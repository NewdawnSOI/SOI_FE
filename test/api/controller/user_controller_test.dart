import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soi/api/api_client.dart';
import 'package:soi/api/api_exception.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/user.dart';
import 'package:soi/api/services/user_service.dart';
import 'package:soi_api_client/api.dart';

class _NoopAuthApi extends AuthControllerApi {}

class _NoopUserApi extends UserAPIApi {}

class _FakeUserService extends UserService {
  _FakeUserService({
    this.onLoginWithNickname,
    this.onLoginWithPhone,
    this.onGetCurrentUser,
  }) : super(
         authApi: _NoopAuthApi(),
         userApi: _NoopUserApi(),
         onAuthTokenIssued: (_) {},
         onAuthTokenCleared: () {},
       );

  final Future<User?> Function(String)? onLoginWithNickname;
  final Future<User?> Function(String)? onLoginWithPhone;
  final Future<User> Function()? onGetCurrentUser;

  @override
  Future<User?> loginWithNickname(String nickName) async {
    final handler = onLoginWithNickname;
    if (handler == null) {
      throw UnimplementedError('onLoginWithNickname is not configured');
    }
    return handler(nickName);
  }

  @override
  Future<User?> loginWithPhone(String phoneNum) async {
    final handler = onLoginWithPhone;
    if (handler == null) {
      throw UnimplementedError('onLoginWithPhone is not configured');
    }
    return handler(phoneNum);
  }

  @override
  Future<User> getCurrentUser() async {
    final handler = onGetCurrentUser;
    if (handler == null) {
      throw UnimplementedError('onGetCurrentUser is not configured');
    }
    return handler();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SoiApiClient.instance.initialize();
    SoiApiClient.instance.clearAuthToken();
  });

  group('UserController login error handling', () {
    test('returns null when nickname login throws NotFoundException', () async {
      final controller = UserController(
        userService: _FakeUserService(
          onLoginWithNickname: (_) async =>
              throw const NotFoundException(message: 'not found'),
        ),
      );

      final result = await controller.loginWithNickname('unknown');
      expect(result, isNull);
      expect(controller.currentUser, isNull);
    });

    test(
      'rethrows NetworkException when phone login fails by network',
      () async {
        final controller = UserController(
          userService: _FakeUserService(
            onLoginWithPhone: (_) async =>
                throw const NetworkException(message: 'network down'),
          ),
        );

        try {
          await controller.login('01011112222');
          fail('Expected NetworkException to be thrown');
        } on NetworkException {
          expect(controller.errorMessage, contains('로그인 실패'));
        }
      },
    );

    test('restores JWT token and current user during auto login', () async {
      SharedPreferences.setMockInitialValues({
        'api_is_logged_in': true,
        'api_user_id': 1,
        'api_phone_number': '01012345678',
        'api_access_token': 'jwt-token',
      });

      final controller = UserController(
        userService: _FakeUserService(
          onGetCurrentUser: () async => const User(
            id: 1,
            userId: 'minchan',
            name: '민찬',
            phoneNumber: '01012345678',
          ),
        ),
      );

      final result = await controller.tryAutoLogin();

      expect(result, isTrue);
      expect(SoiApiClient.instance.authToken, 'jwt-token');
      expect(controller.currentUser?.id, 1);
    });
  });
}
