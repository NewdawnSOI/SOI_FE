import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soi/api/controller/user_controller.dart' as api;
import 'package:soi/api/models/user.dart';
import 'package:soi/api/services/user_service.dart';
import 'package:soi/views/about_login_&_register/login_screen.dart';
import 'package:soi_api_client/api.dart';

class _InMemoryAssetLoader extends AssetLoader {
  const _InMemoryAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    return {
      'common': {'login': '로그인', 'confirm': '확인'},
      'login': {
        'title': '로그인',
        'nickname_hint': '닉네임',
        'phone_hint': '전화번호',
        'nickname_required': '닉네임을 입력해주세요.',
        'phone_required': '전화번호를 입력해주세요.',
        'not_found': '입력한 닉네임 또는 전화번호를 확인해주세요.',
        'failed': '로그인에 실패했습니다.',
        'network_error': '네트워크 연결이 불안정합니다. 다시 시도해주세요.',
        'invalid_input': '입력한 정보를 확인한 뒤 다시 시도해주세요.',
        'loading': '로그인 중...',
        'test_push_token_action': '테스트용 FCM 토큰 발급',
        'test_push_token_loading': '테스트용 FCM 토큰 발급 중...',
        'test_push_token_copied': 'FCM 토큰을 클립보드에 복사했습니다.',
        'test_push_token_unavailable': 'FCM 토큰을 발급하지 못했습니다.',
        'test_push_token_failed_with_reason': 'FCM 토큰 발급 실패: {error}',
        'test_push_token_dialog_title': '테스트용 FCM 토큰',
        'test_push_token_dialog_hint': '토큰 안내',
      },
    };
  }
}

class _NoopAuthApi extends AuthControllerApi {}

class _NoopUserApi extends UserAPIApi {}

class _FakeUserController extends api.UserController {
  _FakeUserController({required this.onLogin})
    : super(
        userService: UserService(
          authApi: _NoopAuthApi(),
          userApi: _NoopUserApi(),
          onAuthTokenIssued: (_) {},
          onAuthTokenCleared: () {},
        ),
      );

  final Future<User?> Function({String? nickName, String? phoneNumber}) onLogin;

  @override
  Future<User?> login({String? nickName, String? phoneNumber}) {
    return onLogin(nickName: nickName, phoneNumber: phoneNumber);
  }
}

Widget _buildTestApp(api.UserController userController) {
  return EasyLocalization(
    supportedLocales: const [Locale('ko')],
    path: 'unused',
    fallbackLocale: const Locale('ko'),
    assetLoader: const _InMemoryAssetLoader(),
    child: Builder(
      builder: (easyContext) {
        return ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (_, __) => ChangeNotifierProvider<api.UserController>.value(
            value: userController,
            child: MaterialApp(
              locale: easyContext.locale,
              supportedLocales: easyContext.supportedLocales,
              localizationsDelegates: easyContext.localizationDelegates,
              home: LoginScreen(
                homeRouteBuilder: (_) => MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('HOME')),
                  settings: const RouteSettings(name: '/home_navigation_screen'),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('LoginScreen', () {
    testWidgets('normalizes credentials and navigates on successful login', (
      tester,
    ) async {
      String? capturedNickname;
      String? capturedPhoneNumber;
      final userController = _FakeUserController(
        onLogin: ({String? nickName, String? phoneNumber}) async {
          capturedNickname = nickName;
          capturedPhoneNumber = phoneNumber;
          return const User(
            id: 1,
            userId: 'minchan',
            name: '민찬',
            phoneNumber: '01012345678',
          );
        },
      );

      await tester.pumpWidget(_buildTestApp(userController));
      await tester.pumpAndSettle();

      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );

      await tester.enterText(find.byType(TextField).first, '  minchan  ');
      await tester.enterText(find.byType(TextField).at(1), '010-1234-5678');
      await tester.pump();

      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(capturedNickname, 'minchan');
      expect(capturedPhoneNumber, '01012345678');
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('shows translated not found message when login returns null', (
      tester,
    ) async {
      final userController = _FakeUserController(
        onLogin: ({String? nickName, String? phoneNumber}) async => null,
      );

      await tester.pumpWidget(_buildTestApp(userController));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'minchan');
      await tester.enterText(find.byType(TextField).at(1), '01012345678');
      await tester.pump();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('입력한 닉네임 또는 전화번호를 확인해주세요.'), findsOneWidget);
    });
  });
}
