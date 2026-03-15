import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/api_exception.dart';
import 'package:soi/api/services/user_service.dart';
import 'package:soi_api_client/api.dart';

class _FakeAuthApi extends AuthControllerApi {
  _FakeAuthApi({this.onLogin});

  final Future<LoginRespDto?> Function(LoginReqDto)? onLogin;

  @override
  Future<LoginRespDto?> login(LoginReqDto loginReqDto) async {
    final handler = onLogin;
    if (handler == null) {
      throw UnimplementedError('onLogin is not configured');
    }
    return handler(loginReqDto);
  }
}

class _FakeUserApi extends UserAPIApi {
  _FakeUserApi({this.onGetUser});

  final Future<ApiResponseDtoUserRespDto?> Function()? onGetUser;

  @override
  Future<ApiResponseDtoUserRespDto?> getUser() async {
    final handler = onGetUser;
    if (handler == null) {
      throw UnimplementedError('onGetUser is not configured');
    }
    return handler();
  }
}

void main() {
  group('UserService login error mapping', () {
    test(
      'maps socket transport ApiException(400) to NetworkException',
      () async {
        final service = UserService(
          authApi: _FakeAuthApi(
            onLogin: (_) async => throw ApiException(
              400,
              'Socket operation failed: POST /auth/login',
            ),
          ),
          userApi: _FakeUserApi(onGetUser: () async => null),
          onAuthTokenIssued: (_) {},
          onAuthTokenCleared: () {},
        );

        expect(
          service.loginWithNickname('minchan'),
          throwsA(isA<NetworkException>()),
        );
      },
    );

    test('returns null for nickname login when API responds 404', () async {
      final service = UserService(
        authApi: _FakeAuthApi(
          onLogin: (_) async => throw ApiException(404, 'not found'),
        ),
        userApi: _FakeUserApi(onGetUser: () async => null),
        onAuthTokenIssued: (_) {},
        onAuthTokenCleared: () {},
      );

      final result = await service.loginWithNickname('unknown');
      expect(result, isNull);
    });

    test('returns null for phone login when API responds 404', () async {
      final service = UserService(
        authApi: _FakeAuthApi(
          onLogin: (_) async => throw ApiException(404, 'not found'),
        ),
        userApi: _FakeUserApi(onGetUser: () async => null),
        onAuthTokenIssued: (_) {},
        onAuthTokenCleared: () {},
      );

      final result = await service.loginWithPhone('01000000000');
      expect(result, isNull);
    });

    test('stores JWT token and fetches current user after login', () async {
      String? issuedToken;
      final service = UserService(
        authApi: _FakeAuthApi(
          onLogin: (_) async => LoginRespDto(accessToken: 'jwt-token'),
        ),
        userApi: _FakeUserApi(
          onGetUser: () async => ApiResponseDtoUserRespDto(
            success: true,
            data: UserRespDto(
              id: 1,
              nickname: 'minchan',
              name: '민찬',
              phoneNum: '01012345678',
            ),
          ),
        ),
        onAuthTokenIssued: (token) => issuedToken = token,
        onAuthTokenCleared: () {},
      );

      final result = await service.loginWithNickname('minchan');

      expect(issuedToken, 'jwt-token');
      expect(result?.id, 1);
      expect(result?.userId, 'minchan');
    });
  });
}
