import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/api_exception.dart';
import 'package:soi/api/services/user_service.dart';
import 'package:soi/utils/firebase_phone_auth_service.dart';
import 'package:soi_api_client/api.dart';

/// 인증 전용 엔드포인트를 테스트 더블로 대체해 서비스 예외 분기를 검증합니다.
class _FakeAuthApi extends AuthControllerApi {
  _FakeAuthApi({
    this.onAuthSms,
    this.onCheckAuthSms,
    this.onCreateUser,
    this.onIdCheck,
    this.onLogin,
  });

  final Future<bool?> Function(String phoneNum)? onAuthSms;
  final Future<bool?> Function(AuthCheckReqDto dto)? onCheckAuthSms;
  final Future<ApiResponseDtoUserRespDto?> Function(UserCreateReqDto dto)?
  onCreateUser;
  final Future<ApiResponseDtoBoolean?> Function(String userId)? onIdCheck;
  final Future<LoginRespDto?> Function(LoginReqDto)? onLogin;

  @override
  Future<bool?> authSMS(String phoneNum) async {
    final handler = onAuthSms;
    if (handler == null) {
      throw UnimplementedError('onAuthSms is not configured');
    }
    return handler(phoneNum);
  }

  @override
  Future<bool?> checkAuthSMS(AuthCheckReqDto authCheckReqDto) async {
    final handler = onCheckAuthSms;
    if (handler == null) {
      throw UnimplementedError('onCheckAuthSms is not configured');
    }
    return handler(authCheckReqDto);
  }

  @override
  Future<ApiResponseDtoUserRespDto?> createUser(
    UserCreateReqDto userCreateReqDto,
  ) async {
    final handler = onCreateUser;
    if (handler == null) {
      throw UnimplementedError('onCreateUser is not configured');
    }
    return handler(userCreateReqDto);
  }

  @override
  Future<ApiResponseDtoBoolean?> idCheck(String userId) async {
    final handler = onIdCheck;
    if (handler == null) {
      throw UnimplementedError('onIdCheck is not configured');
    }
    return handler(userId);
  }

  @override
  Future<LoginRespDto?> login(LoginReqDto loginReqDto) async {
    final handler = onLogin;
    if (handler == null) {
      throw UnimplementedError('onLogin is not configured');
    }
    return handler(loginReqDto);
  }
}

/// Firebase 전화번호 인증 의존성을 테스트에서 제어해 API/Firebase 분기를 독립적으로 검증합니다.
class _FakePhoneVerificationService extends FirebasePhoneVerificationService {
  _FakePhoneVerificationService({
    this.onSendVerificationCode,
    this.onVerifyCode,
  });

  final Future<bool> Function(String phoneNumber)? onSendVerificationCode;
  final Future<bool> Function(String phoneNumber, String code)? onVerifyCode;

  @override
  Future<bool> sendVerificationCode(String phoneNumber) async {
    final handler = onSendVerificationCode;
    if (handler == null) {
      throw UnimplementedError('onSendVerificationCode is not configured');
    }
    return handler(phoneNumber);
  }

  @override
  Future<bool> verifyCode(String phoneNumber, String smsCode) async {
    final handler = onVerifyCode;
    if (handler == null) {
      throw UnimplementedError('onVerifyCode is not configured');
    }
    return handler(phoneNumber, smsCode);
  }
}

/// 사용자 API 응답을 주입해 wrapper의 DTO 매핑 결과를 고정합니다.
class _FakeUserApi extends UserAPIApi {
  _FakeUserApi({this.onGetUser, this.onUpdateProfile, this.onUpdateCoverImage});

  final Future<ApiResponseDtoUserRespDto?> Function()? onGetUser;
  final Future<ApiResponseDtoUserRespDto?> Function(String? profileImageKey)?
  onUpdateProfile;
  final Future<ApiResponseDtoUserRespDto?> Function(String? coverImageKey)?
  onUpdateCoverImage;

  @override
  Future<ApiResponseDtoUserRespDto?> getUser() async {
    final handler = onGetUser;
    if (handler == null) {
      throw UnimplementedError('onGetUser is not configured');
    }
    return handler();
  }

  @override
  Future<ApiResponseDtoUserRespDto?> updateProfile({
    String? profileImageKey,
  }) async {
    final handler = onUpdateProfile;
    if (handler == null) {
      throw UnimplementedError('onUpdateProfile is not configured');
    }
    return handler(profileImageKey);
  }

  @override
  Future<ApiResponseDtoUserRespDto?> updateCoverImage({
    String? coverImageKey,
  }) async {
    final handler = onUpdateCoverImage;
    if (handler == null) {
      throw UnimplementedError('onUpdateCoverImage is not configured');
    }
    return handler(coverImageKey);
  }
}

void main() {
  group('UserService login error mapping', () {
    test(
      'uses Firebase verification service when useFirebase is true',
      () async {
        final service = UserService(
          authApi: _FakeAuthApi(onLogin: (_) async => LoginRespDto()),
          userApi: _FakeUserApi(onGetUser: () async => null),
          phoneVerificationService: _FakePhoneVerificationService(
            onSendVerificationCode: (phoneNumber) async {
              expect(phoneNumber, '+14155551234');
              return true;
            },
            onVerifyCode: (phoneNumber, code) async {
              expect(phoneNumber, '+14155551234');
              expect(code, '654321');
              return true;
            },
          ),
          onAuthTokenIssued: (_) {},
          onAuthTokenCleared: () {},
        );

        final sent = await service.sendSmsVerification('+14155551234');
        final verified = await service.verifySmsCode('+14155551234', '654321');

        expect(sent, isTrue);
        expect(verified, isTrue);
      },
    );

    test('uses unauthenticated auth api for API SMS verification', () async {
      final service = UserService(
        authApi: _FakeAuthApi(onLogin: (_) async => LoginRespDto()),
        userApi: _FakeUserApi(onGetUser: () async => null),
        buildUnauthenticatedAuthApi: () => _FakeAuthApi(
          onAuthSms: (phoneNum) async {
            expect(phoneNum, '01066784110');
            return true;
          },
          onCheckAuthSms: (dto) async {
            expect(dto.phoneNum, '01066784110');
            expect(dto.code, '12345');
            return true;
          },
        ),
        phoneVerificationService: _FakePhoneVerificationService(
          onSendVerificationCode: (_) async =>
              throw StateError('firebase should not be used'),
          onVerifyCode: (_, __) async =>
              throw StateError('firebase should not be used'),
        ),
        onAuthTokenIssued: (_) {},
        onAuthTokenCleared: () {},
      );

      final sent = await service.sendSmsVerification(
        '01066784110',
        useFirebase: false,
      );
      final verified = await service.verifySmsCode(
        '01066784110',
        '12345',
        useFirebase: false,
      );

      expect(sent, isTrue);
      expect(verified, isTrue);
    });

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
          service.login(nickName: 'minchan', phoneNum: '01012345678'),
          throwsA(isA<NetworkException>()),
        );
      },
    );

    test('returns null when combined login API responds 404', () async {
      final service = UserService(
        authApi: _FakeAuthApi(
          onLogin: (_) async => throw ApiException(404, 'not found'),
        ),
        userApi: _FakeUserApi(onGetUser: () async => null),
        onAuthTokenIssued: (_) {},
        onAuthTokenCleared: () {},
      );

      final result = await service.login(
        nickName: 'unknown',
        phoneNum: '01000000000',
      );
      expect(result, isNull);
    });

    test(
      'throws BadRequestException when nickname or phone is missing',
      () async {
        final service = UserService(
          authApi: _FakeAuthApi(onLogin: (_) async => LoginRespDto()),
          userApi: _FakeUserApi(onGetUser: () async => null),
          onAuthTokenIssued: (_) {},
          onAuthTokenCleared: () {},
        );

        expect(
          service.login(nickName: 'minchan'),
          throwsA(isA<BadRequestException>()),
        );
        expect(
          service.login(phoneNum: '01012345678'),
          throwsA(isA<BadRequestException>()),
        );
      },
    );

    test('stores JWT token and fetches current user after login', () async {
      String? issuedToken;
      final service = UserService(
        authApi: _FakeAuthApi(
          onLogin: (dto) async {
            expect(dto.nickname, 'minchan');
            expect(dto.phoneNum, '01012345678');
            return LoginRespDto(accessToken: 'jwt-token');
          },
        ),
        userApi: _FakeUserApi(
          onGetUser: () async => ApiResponseDtoUserRespDto(
            success: true,
            data: UserRespDto(
              id: 1,
              nickname: 'minchan',
              name: '민찬',
              profileImageUrl: 'https://example.com/profile.webp',
              profileCoverImageKey: 'covers/minchan.webp',
              profileCoverImageUrl: 'https://example.com/covers/minchan.webp',
              phoneNum: '01012345678',
            ),
          ),
        ),
        onAuthTokenIssued: (token) => issuedToken = token,
        onAuthTokenCleared: () {},
      );

      final result = await service.login(
        nickName: 'minchan',
        phoneNum: '01012345678',
      );

      expect(issuedToken, 'jwt-token');
      expect(result?.id, 1);
      expect(result?.userId, 'minchan');
      expect(result?.profileImageUrl, 'https://example.com/profile.webp');
      expect(result?.profileCoverImageKey, 'covers/minchan.webp');
      expect(
        result?.profileCoverImageUrl,
        'https://example.com/covers/minchan.webp',
      );
    });

    test('trims login credentials before calling auth api', () async {
      String? issuedToken;
      final service = UserService(
        authApi: _FakeAuthApi(
          onLogin: (dto) async {
            expect(dto.nickname, 'minchan');
            expect(dto.phoneNum, '01012345678');
            return LoginRespDto(accessToken: 'jwt-token');
          },
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

      final result = await service.login(
        nickName: '  minchan  ',
        phoneNum: ' 01012345678 ',
      );

      expect(issuedToken, 'jwt-token');
      expect(result?.id, 1);
    });

    test('uses unauthenticated auth api for login', () async {
      String? issuedToken;
      final service = UserService(
        authApi: _FakeAuthApi(
          onLogin: (_) async => throw StateError('authenticated auth api used'),
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
        buildUnauthenticatedAuthApi: () => _FakeAuthApi(
          onLogin: (dto) async {
            expect(dto.nickname, 'minchan');
            expect(dto.phoneNum, '01012345678');
            return LoginRespDto(accessToken: 'jwt-token');
          },
        ),
        onAuthTokenIssued: (token) => issuedToken = token,
        onAuthTokenCleared: () {},
      );

      final result = await service.login(
        nickName: 'minchan',
        phoneNum: '01012345678',
      );

      expect(issuedToken, 'jwt-token');
      expect(result?.id, 1);
    });

    test('uses unauthenticated auth api for user creation', () async {
      final service = UserService(
        authApi: _FakeAuthApi(onLogin: (_) async => LoginRespDto()),
        userApi: _FakeUserApi(onGetUser: () async => null),
        buildUnauthenticatedAuthApi: () => _FakeAuthApi(
          onCreateUser: (dto) async {
            expect(dto.name, '민찬');
            expect(dto.nickname, 'minchan');
            expect(dto.phoneNum, '+821012345678');
            return ApiResponseDtoUserRespDto(
              success: true,
              data: UserRespDto(
                id: 1,
                nickname: dto.nickname,
                name: dto.name,
                phoneNum: dto.phoneNum,
              ),
            );
          },
        ),
        onAuthTokenIssued: (_) {},
        onAuthTokenCleared: () {},
      );

      final result = await service.createUser(
        name: '민찬',
        nickName: 'minchan',
        phoneNum: '+821012345678',
        birthDate: '1990-01-01',
      );

      expect(result.id, 1);
      expect(result.userId, 'minchan');
    });

    test('serializes omitted signup image fields as empty strings', () async {
      final service = UserService(
        authApi: _FakeAuthApi(onLogin: (_) async => LoginRespDto()),
        userApi: _FakeUserApi(onGetUser: () async => null),
        buildUnauthenticatedAuthApi: () => _FakeAuthApi(
          onCreateUser: (dto) async {
            expect(dto.name, '민찬');
            expect(dto.nickname, 'minchan');
            expect(dto.phoneNum, '01012345678');
            expect(dto.birthDate, '1990-01-01');
            expect(dto.profileImageKey, '');
            expect(dto.profileCoverImageKey, '');
            return ApiResponseDtoUserRespDto(
              success: true,
              data: UserRespDto(
                id: 3,
                nickname: dto.nickname,
                name: dto.name,
                phoneNum: dto.phoneNum,
              ),
            );
          },
        ),
        onAuthTokenIssued: (_) {},
        onAuthTokenCleared: () {},
      );

      final result = await service.createUser(
        name: '  민찬 ',
        nickName: ' minchan ',
        phoneNum: ' 01012345678 ',
        birthDate: ' 1990-01-01 ',
        profileImageKey: '   ',
      );

      expect(result.id, 3);
      expect(result.userId, 'minchan');
    });

    test(
      'uses unauthenticated auth api for nickname availability check',
      () async {
        final service = UserService(
          authApi: _FakeAuthApi(onLogin: (_) async => LoginRespDto()),
          userApi: _FakeUserApi(onGetUser: () async => null),
          buildUnauthenticatedAuthApi: () => _FakeAuthApi(
            onIdCheck: (userId) async {
              expect(userId, 'minchan');
              return ApiResponseDtoBoolean(success: true, data: true);
            },
          ),
          onAuthTokenIssued: (_) {},
          onAuthTokenCleared: () {},
        );

        final result = await service.checknickNameAvailable('minchan');

        expect(result, isTrue);
      },
    );

    test('updateProfile maps generated response to domain model', () async {
      final service = UserService(
        authApi: _FakeAuthApi(onLogin: (_) async => LoginRespDto()),
        userApi: _FakeUserApi(
          onUpdateProfile: (profileImageKey) async {
            expect(profileImageKey, 'profile-key');
            return ApiResponseDtoUserRespDto(
              success: true,
              data: UserRespDto(
                id: 1,
                nickname: 'minchan',
                name: '민찬',
                profileImageKey: profileImageKey,
                profileImageUrl: 'https://example.com/profile-key.webp',
                phoneNum: '01012345678',
              ),
            );
          },
        ),
        onAuthTokenIssued: (_) {},
        onAuthTokenCleared: () {},
      );

      final result = await service.updateProfile(
        profileImageKey: 'profile-key',
      );

      expect(result.id, 1);
      expect(result.profileImageKey, 'profile-key');
      expect(result.profileImageUrl, 'https://example.com/profile-key.webp');
    });

    test('updateCoverImage maps generated response to domain model', () async {
      final service = UserService(
        authApi: _FakeAuthApi(onLogin: (_) async => LoginRespDto()),
        userApi: _FakeUserApi(
          onUpdateCoverImage: (coverImageKey) async {
            expect(coverImageKey, 'cover-key');
            return ApiResponseDtoUserRespDto(
              success: true,
              data: UserRespDto(
                id: 1,
                nickname: 'minchan',
                name: '민찬',
                profileCoverImageKey: coverImageKey,
                profileCoverImageUrl:
                    'https://example.com/covers/cover-key.webp',
                phoneNum: '01012345678',
              ),
            );
          },
        ),
        onAuthTokenIssued: (_) {},
        onAuthTokenCleared: () {},
      );

      final result = await service.updateCoverImage(
        userId: 1,
        coverImageKey: 'cover-key',
      );

      expect(result.id, 1);
      expect(result.userId, 'minchan');
      expect(result.profileCoverImageKey, 'cover-key');
      expect(
        result.profileCoverImageUrl,
        'https://example.com/covers/cover-key.webp',
      );
    });
  });
}
