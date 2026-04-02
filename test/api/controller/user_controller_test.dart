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

/// 컨트롤러가 의존하는 사용자 서비스 호출을 주입형 테스트 더블로 대체합니다.
class _FakeUserService extends UserService {
  _FakeUserService({
    this.onSendSmsVerification,
    this.onVerifySmsCode,
    this.onLogin,
    this.onGetCurrentUser,
    this.onCreateUser,
    this.onUpdateProfileImage,
    this.onUpdateCoverImage,
    this.onDeleteUser,
  }) : super(
         authApi: _NoopAuthApi(),
         userApi: _NoopUserApi(),
         onAuthTokenIssued: (_) {},
         onAuthTokenCleared: () {},
       );

  final Future<bool> Function(String phoneNumber)? onSendSmsVerification;
  final Future<bool> Function(String phoneNumber, String code)? onVerifySmsCode;
  final Future<User?> Function({String? nickName, String? phoneNum})? onLogin;
  final Future<User> Function()? onGetCurrentUser;
  final Future<User> Function({
    required String name,
    required String nickName,
    required String phoneNum,
    required String birthDate,
    String? profileImageKey,
    String? profileCoverImageKey,
    bool serviceAgreed,
    bool privacyPolicyAgreed,
    bool marketingAgreed,
  })?
  onCreateUser;
  final Future<User> Function({
    required int userId,
    required String profileImageKey,
  })?
  onUpdateProfileImage;
  final Future<User> Function({
    required int userId,
    required String coverImageKey,
  })?
  onUpdateCoverImage;
  final Future<User> Function(int id)? onDeleteUser;

  @override
  Future<User?> login({String? nickName, String? phoneNum}) async {
    final handler = onLogin;
    if (handler == null) {
      throw UnimplementedError('onLogin is not configured');
    }
    return handler(nickName: nickName, phoneNum: phoneNum);
  }

  @override
  Future<bool> sendSmsVerification(String phoneNum) async {
    final handler = onSendSmsVerification;
    if (handler == null) {
      throw UnimplementedError('onSendSmsVerification is not configured');
    }
    return handler(phoneNum);
  }

  @override
  Future<bool> verifySmsCode(String phoneNum, String code) async {
    final handler = onVerifySmsCode;
    if (handler == null) {
      throw UnimplementedError('onVerifySmsCode is not configured');
    }
    return handler(phoneNum, code);
  }

  @override
  Future<User> getCurrentUser() async {
    final handler = onGetCurrentUser;
    if (handler == null) {
      throw UnimplementedError('onGetCurrentUser is not configured');
    }
    return handler();
  }

  /// 회원가입 인자를 그대로 노출해 컨트롤러 정규화와 전달 값을 검증합니다.
  @override
  Future<User> createUser({
    required String name,
    required String nickName,
    required String phoneNum,
    required String birthDate,
    String? profileImageKey,
    String? profileCoverImageKey,
    bool serviceAgreed = true,
    bool privacyPolicyAgreed = true,
    bool marketingAgreed = false,
  }) async {
    final handler = onCreateUser;
    if (handler == null) {
      throw UnimplementedError('onCreateUser is not configured');
    }
    return handler(
      name: name,
      nickName: nickName,
      phoneNum: phoneNum,
      birthDate: birthDate,
      profileImageKey: profileImageKey,
      profileCoverImageKey: profileCoverImageKey,
      serviceAgreed: serviceAgreed,
      privacyPolicyAgreed: privacyPolicyAgreed,
      marketingAgreed: marketingAgreed,
    );
  }

  @override
  Future<User> updateProfileImage({
    required int userId,
    required String profileImageKey,
  }) async {
    final handler = onUpdateProfileImage;
    if (handler == null) {
      throw UnimplementedError('onUpdateProfileImage is not configured');
    }
    return handler(userId: userId, profileImageKey: profileImageKey);
  }

  @override
  Future<User> updateCoverImage({
    required int userId,
    required String coverImageKey,
  }) async {
    final handler = onUpdateCoverImage;
    if (handler == null) {
      throw UnimplementedError('onUpdateCoverImage is not configured');
    }
    return handler(userId: userId, coverImageKey: coverImageKey);
  }

  @override
  Future<User> deleteUser(int id) async {
    final handler = onDeleteUser;
    if (handler == null) {
      throw UnimplementedError('onDeleteUser is not configured');
    }
    return handler(id);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SoiApiClient.instance.initialize();
    SoiApiClient.instance.clearAuthToken();
  });

  group('UserController login error handling', () {
    test('trims whitespace before requesting SMS verification', () async {
      final controller = UserController(
        userService: _FakeUserService(
          onSendSmsVerification: (phoneNumber) async {
            expect(phoneNumber, '+821066784110');
            return true;
          },
        ),
      );

      final result = await controller.requestSmsVerification(
        '  +821066784110  ',
      );

      expect(result, isTrue);
    });

    test('trims whitespace before verifying SMS code', () async {
      final controller = UserController(
        userService: _FakeUserService(
          onVerifySmsCode: (phoneNumber, code) async {
            expect(phoneNumber, '+821066784110');
            expect(code, '12345');
            return true;
          },
        ),
      );

      final result = await controller.verifySmsCode(
        '  +821066784110  ',
        ' 12345 ',
      );

      expect(result, isTrue);
    });

    test('rethrows SMS verification errors so UI can show the exact reason', () async {
      final controller = UserController(
        userService: _FakeUserService(
          onSendSmsVerification: (_) async => throw const SoiApiException(
            message: '앱 검증에 실패했습니다.',
          ),
        ),
      );

      expect(
        controller.requestSmsVerification('+821066784110'),
        throwsA(isA<SoiApiException>()),
      );
    });

    test('returns null when combined login throws NotFoundException', () async {
      final controller = UserController(
        userService: _FakeUserService(
          onLogin: ({String? nickName, String? phoneNum}) async =>
              throw const NotFoundException(message: 'not found'),
        ),
      );

      final result = await controller.login(
        nickName: 'unknown',
        phoneNumber: '01000000000',
      );
      expect(result, isNull);
      expect(controller.currentUser, isNull);
    });

    test('trims nickname and phone before delegating login', () async {
      final controller = UserController(
        userService: _FakeUserService(
          onLogin: ({String? nickName, String? phoneNum}) async {
            expect(nickName, 'minchan');
            expect(phoneNum, '01011112222');
            return const User(
              id: 1,
              userId: 'minchan',
              name: '민찬',
              phoneNumber: '01011112222',
            );
          },
        ),
      );

      final result = await controller.login(
        nickName: '  minchan  ',
        phoneNumber: ' 01011112222 ',
      );

      expect(result?.id, 1);
      expect(controller.currentUser?.id, 1);
    });

    test(
      'rethrows NetworkException when combined login fails by network',
      () async {
        final controller = UserController(
          userService: _FakeUserService(
            onLogin: ({String? nickName, String? phoneNum}) async =>
                throw const NetworkException(message: 'network down'),
          ),
        );

        try {
          await controller.login(
            nickName: 'minchan',
            phoneNumber: '01011112222',
          );
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
            profileCoverImageKey: 'server-cover-key',
          ),
        ),
      );

      final result = await controller.tryAutoLogin();
      final prefs = await SharedPreferences.getInstance();

      expect(result, isTrue);
      expect(SoiApiClient.instance.authToken, 'jwt-token');
      expect(controller.currentUser?.id, 1);
      expect(controller.coverImageUrlKey, 'server-cover-key');
      expect(prefs.getString('api_cover_image_key'), 'server-cover-key');
    });

    test('blocks signup completion when JWT login is not issued', () async {
      final controller = UserController(
        userService: _FakeUserService(
          onCreateUser:
              ({
                required String name,
                required String nickName,
                required String phoneNum,
                required String birthDate,
                String? profileImageKey,
                String? profileCoverImageKey,
                bool serviceAgreed = true,
                bool privacyPolicyAgreed = true,
                bool marketingAgreed = false,
              }) async {
                expect(profileImageKey, '');
                expect(profileCoverImageKey, '');
                return const User(
                  id: 2,
                  userId: 'new-user',
                  name: '새 사용자',
                  phoneNumber: '01099998888',
                );
              },
          onLogin: ({String? nickName, String? phoneNum}) async {
            expect(nickName, 'new-user');
            expect(phoneNum, '01099998888');
            return null;
          },
        ),
      );

      final result = await controller.createUser(
        name: '새 사용자',
        nickName: 'new-user',
        phoneNum: '01099998888',
        birthDate: '2000-01-01',
      );

      expect(result, isNull);
      expect(controller.currentUser, isNull);
      expect(controller.coverImageUrlKey, isNull);
      expect(controller.errorMessage, contains('사용자 생성 실패'));
    });

    test('stores cover image key after updateCoverImageUrl succeeds', () async {
      final controller = UserController(
        userService: _FakeUserService(
          onUpdateCoverImage:
              ({required int userId, required String coverImageKey}) async {
                expect(userId, 1);
                expect(coverImageKey, 'cover-key');
                return const User(
                  id: 1,
                  userId: 'minchan',
                  name: '민찬',
                  phoneNumber: '01012345678',
                );
              },
        ),
      );

      final result = await controller.updateCoverImageUrl(
        userId: 1,
        coverImageKey: 'cover-key',
      );
      final prefs = await SharedPreferences.getInstance();

      expect(result, isTrue);
      expect(controller.coverImageUrlKey, 'cover-key');
      expect(prefs.getString('api_cover_image_key'), 'cover-key');
    });

    test(
      'updateprofileImageUrl syncs current user immediately without losing cover data',
      () async {
        final controller = UserController(
          userService: _FakeUserService(
            onUpdateProfileImage:
                ({required int userId, required String profileImageKey}) async {
                  expect(userId, 1);
                  expect(profileImageKey, 'profiles/new-profile.webp');
                  return const User(
                    id: 1,
                    userId: 'minchan',
                    name: '민찬',
                    profileImageKey: 'profiles/new-profile.webp',
                    profileImageUrl: 'https://example.com/new-profile.webp',
                    phoneNumber: '01012345678',
                  );
                },
          ),
        );
        controller.setCurrentUser(
          const User(
            id: 1,
            userId: 'minchan',
            name: '민찬',
            profileImageKey: 'profiles/old-profile.webp',
            profileImageUrl: 'https://example.com/old-profile.webp',
            profileCoverImageKey: 'covers/keep-cover.webp',
            profileCoverImageUrl: 'https://example.com/keep-cover.webp',
            phoneNumber: '01012345678',
          ),
        );

        final result = await controller.updateprofileImageUrl(
          userId: 1,
          profileImageKey: 'profiles/new-profile.webp',
        );

        expect(result?.profileImageKey, 'profiles/new-profile.webp');
        expect(
          controller.currentUser?.profileImageUrl,
          'https://example.com/new-profile.webp',
        );
        expect(
          controller.currentUser?.profileCoverImageKey,
          'covers/keep-cover.webp',
        );
        expect(controller.coverImageUrlKey, 'covers/keep-cover.webp');
      },
    );

    test(
      'normalizes signup fields and persists the authenticated cover image key',
      () async {
        final controller = UserController(
          userService: _FakeUserService(
            onCreateUser:
                ({
                  required String name,
                  required String nickName,
                  required String phoneNum,
                  required String birthDate,
                  String? profileImageKey,
                  String? profileCoverImageKey,
                  bool serviceAgreed = true,
                  bool privacyPolicyAgreed = true,
                  bool marketingAgreed = false,
                }) async {
                  expect(name, '새 사용자');
                  expect(nickName, 'new-user');
                  expect(phoneNum, '01099998888');
                  expect(birthDate, '2000-01-01');
                  expect(profileImageKey, '');
                  expect(profileCoverImageKey, '');
                  return const User(
                    id: 2,
                    userId: 'new-user',
                    name: '새 사용자',
                    phoneNumber: '01099998888',
                  );
                },
            onLogin: ({String? nickName, String? phoneNum}) async {
              expect(nickName, 'new-user');
              expect(phoneNum, '01099998888');
              return const User(
                id: 2,
                userId: 'new-user',
                name: '새 사용자',
                phoneNumber: '01099998888',
                profileCoverImageKey: 'covers/new-user.webp',
              );
            },
          ),
        );

        final result = await controller.createUser(
          name: ' 새 사용자 ',
          nickName: ' new-user ',
          phoneNum: ' 01099998888 ',
          birthDate: ' 2000-01-01 ',
          profileImageKey: '   ',
        );
        final prefs = await SharedPreferences.getInstance();

        expect(result?.id, 2);
        expect(controller.currentUser?.id, 2);
        expect(controller.coverImageUrlKey, 'covers/new-user.webp');
        expect(prefs.getString('api_cover_image_key'), 'covers/new-user.webp');
      },
    );

    test('clears local session after account deletion succeeds', () async {
      SharedPreferences.setMockInitialValues({
        'api_is_logged_in': true,
        'api_user_id': 1,
        'api_phone_number': '01012345678',
        'api_access_token': 'jwt-token',
        'api_cover_image_key': 'cover-key',
      });
      SoiApiClient.instance.setAuthToken('jwt-token');

      final controller = UserController(
        userService: _FakeUserService(
          onDeleteUser: (id) async {
            expect(id, 1);
            return const User(
              id: 1,
              userId: 'minchan',
              name: '민찬',
              phoneNumber: '01012345678',
            );
          },
        ),
      );
      controller.setCurrentUser(
        const User(
          id: 1,
          userId: 'minchan',
          name: '민찬',
          phoneNumber: '01012345678',
        ),
      );

      final deletedUser = await controller.deleteUser(1);
      final prefs = await SharedPreferences.getInstance();

      expect(deletedUser?.id, 1);
      expect(controller.currentUser, isNull);
      expect(SoiApiClient.instance.authToken, isNull);
      expect(prefs.getString('api_access_token'), isNull);
      expect(prefs.getInt('api_user_id'), isNull);
      expect(prefs.getString('api_cover_image_key'), isNull);
    });

    test('notifies listeners when the same user updates profile visuals', () {
      final controller = UserController(
        userService: _FakeUserService(
          onLogin: ({String? nickName, String? phoneNum}) async => null,
        ),
      );
      var notificationCount = 0;
      controller.addListener(() {
        notificationCount += 1;
      });

      controller.setCurrentUser(
        const User(
          id: 1,
          userId: 'minchan',
          name: '민찬',
          phoneNumber: '01012345678',
          profileImageKey: 'profiles/original.png',
        ),
      );
      notificationCount = 0;

      controller.setCurrentUser(
        const User(
          id: 1,
          userId: 'minchan',
          name: '민찬',
          phoneNumber: '01012345678',
          profileImageKey: 'profiles/updated.png',
          profileImageUrl: 'https://example.com/profiles/updated.png',
        ),
      );

      expect(notificationCount, 1);
    });

    test(
      'drops stale fallback image URL when current user image key changes',
      () {
        final controller = UserController(
          userService: _FakeUserService(
            onLogin: ({String? nickName, String? phoneNum}) async => null,
          ),
        );
        controller.setCurrentUser(
          const User(
            id: 7,
            userId: 'me',
            name: '나',
            phoneNumber: '01000000000',
            profileImageKey: 'profiles/current.png',
          ),
        );

        final selection = controller.selectProfileImage(
          userId: 7,
          fallbackImageUrl: 'https://example.com/profiles/old.png',
          fallbackImageKey: 'profiles/old.png',
        );

        expect(selection.imageUrl, isNull);
        expect(selection.imageKey, 'profiles/current.png');
      },
    );
  });
}
