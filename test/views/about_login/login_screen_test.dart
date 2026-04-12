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
import 'package:soi/views/about_login_&_register/widgets/common/custom_text_field.dart';
import 'package:soi/views/about_login_&_register/widgets/pages/phone_input_page.dart';
import 'package:soi/views/about_login_&_register/widgets/pages/sms_code_page.dart';
import 'package:soi_api_client/api.dart';

/// 로그인 화면 테스트에 필요한 최소 번역 키만 메모리 로더로 제공합니다.
class _InMemoryAssetLoader extends AssetLoader {
  const _InMemoryAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    return {
      'common': {'confirm': '확인'},
      'login': {
        'phone_title': '전화번호를 입력해 주세요.',
        'sms_title': '인증번호를 입력해 주세요.',
        'phone_hint': '전화번호',
        'send_code': '인증번호 받기',
        'sending_code': '전송 중...',
        'verify_and_login': '로그인',
        'verifying': '인증 중...',
        'resend_code': '인증번호 재전송',
        'phone_required': '전화번호를 입력해주세요.',
        'not_found': '가입되지 않은 전화번호입니다.',
        'failed': '로그인에 실패했습니다.',
        'send_failed': '인증번호 전송에 실패했습니다. 다시 시도해주세요.',
        'verification_failed': '인증에 실패했습니다. 인증번호를 확인해주세요.',
        'network_error': '네트워크 연결이 불안정합니다. 다시 시도해주세요.',
        'invalid_input': '입력한 정보를 확인한 뒤 다시 시도해주세요.',
        'test_push_token_action': '테스트용 FCM 토큰 발급',
        'test_push_token_loading': '테스트용 FCM 토큰 발급 중...',
        'test_push_token_copied': 'FCM 토큰을 클립보드에 복사했습니다.',
        'test_push_token_unavailable': 'FCM 토큰을 발급하지 못했습니다.',
        'test_push_token_failed_with_reason': 'FCM 토큰 발급 실패: {error}',
        'test_push_token_dialog_title': '테스트용 FCM 토큰',
        'test_push_token_dialog_hint': '토큰 안내',
      },
      'register': {
        'country_kr': '대한민국',
        'country_us': '미국',
        'country_mx': '멕시코',
        'sms_hint': '인증번호',
      },
    };
  }
}

class _NoopAuthApi extends AuthControllerApi {}

class _NoopUserApi extends UserAPIApi {}

/// 로그인 화면이 호출하는 SMS/인증/전화번호 로그인 흐름과 자동 인증 상태를 테스트 더블로 대체합니다.
class _FakeUserController extends api.UserController {
  _FakeUserController({
    required this.onRequestSmsVerification,
    required this.onVerifySmsCode,
    required this.onLoginByPhone,
  }) : super(
         userService: UserService(
           authApi: _NoopAuthApi(),
           userApi: _NoopUserApi(),
           onAuthTokenIssued: (_) {},
           onAuthTokenCleared: () {},
         ),
       );

  final Future<bool> Function(String phoneNumber, {required bool useFirebase})
  onRequestSmsVerification;
  final Future<bool> Function(
    String phoneNumber,
    String code, {
    required bool useFirebase,
  })
  onVerifySmsCode;
  final Future<User?> Function(String phoneNumber) onLoginByPhone;
  bool phoneVerificationCompleted = false;
  String? lastRequestedPhoneNumber;
  bool? lastRequestedUseFirebase;
  String? lastVerifiedPhoneNumber;
  String? lastVerifiedCode;
  bool? lastVerifiedUseFirebase;
  String? lastLoginPhoneNumber;

  /// Firebase 즉시 인증 완료 여부를 로그인 화면이 실시간으로 읽을 수 있게 노출합니다.
  @override
  bool get isPhoneVerificationCompleted => phoneVerificationCompleted;

  @override
  /// 인증 요청 분기에서 전달한 번호와 채널이 기대값인지 테스트 더블로 검증합니다.
  Future<bool> requestSmsVerification(
    String phoneNumber, {
    bool useFirebase = true,
  }) {
    lastRequestedPhoneNumber = phoneNumber;
    lastRequestedUseFirebase = useFirebase;
    return onRequestSmsVerification(phoneNumber, useFirebase: useFirebase);
  }

  @override
  /// 수동 코드 인증 호출이 필요한 경우에만 더블이 검증 로직을 대신 수행합니다.
  Future<bool> verifySmsCode(
    String phoneNumber,
    String code, {
    bool useFirebase = true,
  }) {
    lastVerifiedPhoneNumber = phoneNumber;
    lastVerifiedCode = code;
    lastVerifiedUseFirebase = useFirebase;
    return onVerifySmsCode(phoneNumber, code, useFirebase: useFirebase);
  }

  @override
  /// 인증된 전화번호 로그인이 홈 이동으로 이어지는지만 검증할 수 있게 결과를 주입합니다.
  Future<User?> loginByPhone(String phoneNumber) {
    lastLoginPhoneNumber = phoneNumber;
    return onLoginByPhone(phoneNumber);
  }

  @override
  /// 새 번호 입력이나 국가 변경 시 이전 인증 대기 상태가 비워지는지 테스트 더블에서도 유지합니다.
  void resetPhoneVerificationState() {
    phoneVerificationCompleted = false;
  }
}

/// 하단 계속하기 버튼이 레이아웃 위치에 영향을 받지 않도록 콜백을 직접 실행합니다.
Future<void> _pressPrimaryButton(WidgetTester tester) async {
  final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
  expect(button.onPressed, isNotNull);
  final callback = button.onPressed!;
  final result = Function.apply(callback, const []);
  if (result is Future<void>) {
    await result;
  }
  await tester.pumpAndSettle();
}

/// 입력창의 자동 검증처럼 unawaited async 작업이 끝날 때까지 한 번 더 이벤트 루프를 비웁니다.
Future<void> _flushAsyncWork(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pumpAndSettle();
}

/// 디자인 기준 크기로 고정해 레이아웃 수치를 직접 검증할 수 있게 로그인 화면을 띄웁니다.
Future<void> _pumpSizedTestApp(
  WidgetTester tester,
  api.UserController userController,
) async {
  await tester.binding.setSurfaceSize(const Size(393, 852));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(_buildTestApp(userController));
  await tester.pumpAndSettle();
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
                  settings: const RouteSettings(
                    name: '/home_navigation_screen',
                  ),
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
    testWidgets('requests Firebase SMS for Korean numbers then logs in', (
      tester,
    ) async {
      final userController = _FakeUserController(
        onRequestSmsVerification: (_, {required useFirebase}) async => true,
        onVerifySmsCode: (_, __, {required useFirebase}) async => true,
        onLoginByPhone: (_) async => const User(
          id: 1,
          userId: 'phone-user',
          name: '전화 로그인',
          phoneNumber: '01012345678',
        ),
      );

      await tester.pumpWidget(_buildTestApp(userController));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '010-1234-5678');
      await tester.pumpAndSettle();

      await _pressPrimaryButton(tester);

      expect(userController.lastRequestedPhoneNumber, '+821012345678');
      expect(userController.lastRequestedUseFirebase, isTrue);
      expect(find.text('인증번호를 입력해 주세요.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '123456');
      await _flushAsyncWork(tester);

      expect(userController.lastVerifiedPhoneNumber, '+821012345678');
      expect(userController.lastVerifiedCode, '123456');
      expect(userController.lastVerifiedUseFirebase, isTrue);
      expect(userController.lastLoginPhoneNumber, '01012345678');
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets(
      'shows translated not found message when phone login returns null',
      (tester) async {
        final userController = _FakeUserController(
          onRequestSmsVerification: (_, {required useFirebase}) async => true,
          onVerifySmsCode: (_, __, {required useFirebase}) async => true,
          onLoginByPhone: (_) async => null,
        );

        await tester.pumpWidget(_buildTestApp(userController));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, '01012345678');
        await tester.pumpAndSettle();

        await _pressPrimaryButton(tester);

        await tester.enterText(find.byType(TextField).first, '123456');
        await _flushAsyncWork(tester);

        expect(find.text('가입되지 않은 전화번호입니다.'), findsOneWidget);
      },
    );

    testWidgets(
      'starts Firebase phone verification for US numbers and auto logs in when verification completes',
      (tester) async {
        var verifyCalled = false;

        final userController = _FakeUserController(
          onRequestSmsVerification: (_, {required useFirebase}) async => true,
          onVerifySmsCode: (_, __, {required useFirebase}) async {
            verifyCalled = true;
            return true;
          },
          onLoginByPhone: (_) async => const User(
            id: 2,
            userId: 'firebase-user',
            name: '자동 로그인',
            phoneNumber: '4155551234',
          ),
        );

        await tester.pumpWidget(_buildTestApp(userController));
        await tester.pumpAndSettle();

        await tester.tap(find.text('대한민국 (+82)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('미국 (+1)').last);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, '4155551234');
        await tester.pumpAndSettle();

        await _pressPrimaryButton(tester);

        expect(userController.lastRequestedPhoneNumber, '+14155551234');
        expect(userController.lastRequestedUseFirebase, isTrue);
        expect(find.text('인증번호를 입력해 주세요.'), findsOneWidget);

        userController.phoneVerificationCompleted = true;

        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(verifyCalled, isFalse);
        expect(userController.lastLoginPhoneNumber, '4155551234');
        expect(find.text('HOME'), findsOneWidget);
      },
    );

    testWidgets('matches register phone layout geometry', (tester) async {
      final userController = _FakeUserController(
        onRequestSmsVerification: (_, {required useFirebase}) async => true,
        onVerifySmsCode: (_, __, {required useFirebase}) async => true,
        onLoginByPhone: (_) async => null,
      );

      await _pumpSizedTestApp(tester, userController);

      expect(find.byType(PhoneInputPage), findsOneWidget);

      final scaffoldRect = tester.getRect(find.byType(Scaffold));
      final backRect = tester.getRect(
        find.byKey(const ValueKey('auth_phone_back_button')),
      );
      final titleRect = tester.getRect(find.text('전화번호를 입력해 주세요.'));
      final countryRect = tester.getRect(
        find.byKey(const ValueKey('auth_phone_country_selector')),
      );
      final inputRect = tester.getRect(
        find.byKey(const ValueKey('auth_phone_input_wrapper')),
      );
      final buttonRect = tester.getRect(find.byType(ElevatedButton));

      expect(backRect.top, lessThan(titleRect.top));
      expect(backRect.center.dx, lessThan(countryRect.center.dx));
      expect(countryRect.width, closeTo(inputRect.width, 0.5));
      expect(countryRect.center.dx, closeTo(inputRect.center.dx, 1.0));
      expect(countryRect.top, greaterThan(titleRect.bottom));
      expect(inputRect.top, greaterThan(countryRect.bottom));
      expect(
        scaffoldRect.bottom - buttonRect.bottom,
        allOf(greaterThan(16), lessThan(40)),
      );
    });

    testWidgets('matches register sms layout geometry and styling', (
      tester,
    ) async {
      final userController = _FakeUserController(
        onRequestSmsVerification: (_, {required useFirebase}) async => true,
        onVerifySmsCode: (_, __, {required useFirebase}) async => true,
        onLoginByPhone: (_) async => null,
      );

      await _pumpSizedTestApp(tester, userController);

      await tester.enterText(find.byType(TextField).first, '01012345678');
      await tester.pumpAndSettle();
      await _pressPrimaryButton(tester);

      expect(find.byType(SmsCodePage), findsOneWidget);

      final scaffoldRect = tester.getRect(find.byType(Scaffold));
      final backRect = tester.getRect(
        find.byKey(const ValueKey('auth_sms_back_button')),
      );
      final titleRect = tester.getRect(find.text('인증번호를 입력해 주세요.'));
      final inputRect = tester.getRect(
        find.byKey(const ValueKey('auth_sms_input_wrapper')),
      );
      final resendRect = tester.getRect(
        find.byKey(const ValueKey('auth_sms_resend_button')),
      );
      final buttonRect = tester.getRect(find.byType(ElevatedButton));
      final smsField = tester.widget<CustomTextField>(
        find.byType(CustomTextField),
      );

      expect(backRect.top, lessThan(titleRect.top));
      expect(backRect.center.dx, lessThan(inputRect.center.dx));
      expect(inputRect.width, greaterThan(200));
      expect(inputRect.top, greaterThan(titleRect.bottom));
      expect(resendRect.top, greaterThanOrEqualTo(inputRect.bottom));
      expect(resendRect.center.dx, closeTo(inputRect.center.dx, 1.0));
      expect(smsField.borderRadius, 16.5);
      expect(smsField.contentPadding, EdgeInsets.only(bottom: 7.h));
      expect(
        scaffoldRect.bottom - buttonRect.bottom,
        allOf(greaterThan(16), lessThan(40)),
      );
    });
  });
}
