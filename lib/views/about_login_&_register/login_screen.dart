import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/api_exception.dart';
import 'package:soi/api/controller/user_controller.dart' as api;

import '../../app/push/app_push_coordinator.dart';
import '../../theme/theme.dart';
import '../../utils/snackbar_utils.dart';
import '../home_navigator_screen.dart';
import 'services/register_phone_number_service.dart';
import 'widgets/common/continue_button.dart';
import 'widgets/pages/phone_input_page.dart';
import 'widgets/pages/sms_code_page.dart';

enum _LoginStep { phone, sms }

/// 전화번호 입력 → SMS 인증 → 로그인을 처리하는 화면입니다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.homeRouteBuilder});

  final Route<void> Function(BuildContext context)? homeRouteBuilder;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsController = TextEditingController();

  _LoginStep _step = _LoginStep.phone;
  String _selectedCountryCode = 'KR';
  String? _phoneErrorKey;
  Timer? _autoVerifyTimer;

  bool _isSendingCode = false;
  bool _isVerifying = false;
  bool _isIssuingTestPushToken = false;

  /// 현재 선택 국가 기준으로 한국은 서버 SMS, 그 외는 Firebase 인증을 사용합니다.
  bool get _usesApiPhoneVerification =>
      RegisterPhoneNumberService.usesApiSmsVerification(
        countryCode: _selectedCountryCode,
      );

  int get _expectedSmsCodeLength => _usesApiPhoneVerification ? 5 : 6;

  /// 현재 입력값을 국가별 규칙으로 검사해 화면에 보여줄 에러 키를 계산합니다.
  String? get _currentPhoneErrorKey {
    if (_phoneController.text.trim().isEmpty) {
      return null;
    }

    return RegisterPhoneNumberService.validatePhone(
      rawValue: _phoneController.text,
      countryCode: _selectedCountryCode,
    )?.translationKey;
  }

  /// Firebase 즉시 인증 상태를 로그인 화면에서도 재사용할 수 있게 현재 값을 읽습니다.
  bool get _isCurrentPhoneVerificationCompleted =>
      context.read<api.UserController>().isPhoneVerificationCompleted;

  @override
  /// 전화번호 입력과 자동 인증 감시 상태를 함께 정리해 화면 종료 후 잔여 작업을 막습니다.
  void dispose() {
    _autoVerifyTimer?.cancel();
    _phoneController.dispose();
    _smsController.dispose();
    super.dispose();
  }

  String get _localPhone => RegisterPhoneNumberService.formatLocalPhone(
    rawValue: _phoneController.text,
    countryCode: _selectedCountryCode,
  );

  String get _e164Phone => RegisterPhoneNumberService.formatE164Phone(
    rawValue: _phoneController.text,
    countryCode: _selectedCountryCode,
  );

  bool get _isPhoneReady =>
      RegisterPhoneNumberService.validatePhone(
            rawValue: _phoneController.text,
            countryCode: _selectedCountryCode,
          ) ==
          null &&
      _localPhone.isNotEmpty;

  bool get _isSmsReady => _smsController.text.length == _expectedSmsCodeLength;

  @override
  /// 회원가입 화면과 같은 단계 레이아웃 위에 로그인 CTA만 덧입혀 인증 플로우를 렌더링합니다.
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final actionBottomInset = keyboardHeight > 0 ? keyboardHeight + 20.h : 30.h;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            _buildCurrentStep(),
            if (kDebugMode && supportsFirebaseMessaging)
              Positioned(
                bottom: actionBottomInset + 59.h + 12.h,
                left: 0,
                right: 0,
                child: Center(
                  child: TextButton(
                    onPressed: _isIssuingTestPushToken
                        ? null
                        : () => _issueTestPushToken(),
                    child: Text(
                      _isIssuingTestPushToken
                          ? tr(
                              'login.test_push_token_loading',
                              context: context,
                            )
                          : tr(
                              'login.test_push_token_action',
                              context: context,
                            ),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: actionBottomInset,
              left: 0,
              right: 0,
              child: _buildPrimaryAction(),
            ),
          ],
        ),
      ),
    );
  }

  /// 현재 단계에 맞는 회원가입 공용 페이지 위젯을 로그인 문구와 콜백으로 재사용합니다.
  Widget _buildCurrentStep() {
    if (_step == _LoginStep.phone) {
      return PhoneInputPage(
        controller: _phoneController,
        onChanged: _handlePhoneChanged,
        selectedCountryCode: _selectedCountryCode,
        onCountryChanged: _handleCountryChanged,
        maxLength: RegisterPhoneNumberService.maxInputLength(
          countryCode: _selectedCountryCode,
        ),
        errorText: _phoneErrorKey == null
            ? null
            : tr(_phoneErrorKey!, context: context),
        titleText: tr('login.phone_title', context: context),
        hintText: tr('login.phone_hint', context: context),
        onBackPressed: _handleBackNavigation,
        pageController: null,
      );
    }

    return SmsCodePage(
      controller: _smsController,
      onChanged: (_) {
        if (_isSmsReady && !_isVerifying) {
          _verifyAndLogin();
        }
      },
      onResendPressed: _sendVerificationCode,
      isBusy: _isSendingCode || _isVerifying,
      maxCodeLength: _expectedSmsCodeLength,
      titleText: tr('login.sms_title', context: context),
      hintText: tr('register.sms_hint', context: context),
      resendText: tr('login.resend_code', context: context),
      onBackPressed: _handleBackNavigation,
      pageController: null,
    );
  }

  /// 현재 단계와 로딩 상태에 맞춰 회원가입 화면과 같은 위치에 CTA를 고정합니다.
  Widget _buildPrimaryAction() {
    return Center(
      child: _step == _LoginStep.phone
          ? ListenableBuilder(
              listenable: _phoneController,
              builder: (context, _) {
                return ContinueButton(
                  isEnabled: _isPhoneReady && !_isSendingCode,
                  text: _isSendingCode
                      ? tr('login.sending_code', context: context)
                      : tr('login.send_code', context: context),
                  onPressed: _sendVerificationCode,
                );
              },
            )
          : ListenableBuilder(
              listenable: _smsController,
              builder: (context, _) {
                return ContinueButton(
                  isEnabled:
                      (_isSmsReady || _isCurrentPhoneVerificationCompleted) &&
                      !_isVerifying,
                  text: _isVerifying
                      ? tr('login.verifying', context: context)
                      : tr('login.verify_and_login', context: context),
                  onPressed: _verifyAndLogin,
                );
              },
            ),
    );
  }

  /// 현재 단계에 맞춰 뒤로 가기 동작을 분기하고 이전 인증 대기 상태를 정리합니다.
  void _handleBackNavigation() {
    if (_step == _LoginStep.sms) {
      _resetPendingPhoneVerification();
      setState(() {
        _step = _LoginStep.phone;
      });
      return;
    }

    Navigator.of(context).pop();
  }

  /// 국가 변경 시 번호 형식과 인증 상태를 함께 초기화해 새 국가 규칙으로 다시 시작합니다.
  void _handleCountryChanged(String countryCode) {
    _resetPendingPhoneVerification();
    setState(() {
      _selectedCountryCode = countryCode;
      _phoneController.clear();
      _step = _LoginStep.phone;
      _phoneErrorKey = null;
    });
  }

  /// 전화번호 입력이 바뀌면 표시 에러와 이전 인증 대기 상태를 최신 입력 기준으로 동기화합니다.
  void _handlePhoneChanged(String _) {
    final nextErrorKey = _currentPhoneErrorKey;
    _resetPendingPhoneVerification();
    if (_phoneErrorKey == nextErrorKey) {
      return;
    }

    setState(() {
      _phoneErrorKey = nextErrorKey;
    });
  }

  /// 인증 채널에 맞는 번호 형식을 선택해 SMS를 발송하고, 필요하면 자동 인증 감시까지 시작합니다.
  Future<void> _sendVerificationCode() async {
    if (_isSendingCode) return;

    _resetPendingPhoneVerification();

    final validationError = RegisterPhoneNumberService.validatePhone(
      rawValue: _phoneController.text,
      countryCode: _selectedCountryCode,
    );
    if (validationError != null) {
      final errorKey = validationError.translationKey;
      setState(() {
        _phoneErrorKey = errorKey;
      });
      _showErrorSnackBar(tr(errorKey, context: context));
      return;
    }

    final verificationPhoneNumber = _usesApiPhoneVerification
        ? _localPhone
        : _e164Phone;
    if (verificationPhoneNumber.isEmpty) {
      _showErrorSnackBar(tr('login.phone_required', context: context));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSendingCode = true);

    final userController = context.read<api.UserController>();
    try {
      final sent = await userController.requestSmsVerification(
        verificationPhoneNumber,
        useFirebase: !_usesApiPhoneVerification,
      );

      if (!mounted) return;

      if (sent) {
        setState(() {
          _step = _LoginStep.sms;
          _smsController.clear();
          _phoneErrorKey = null;
        });

        if (_isCurrentPhoneVerificationCompleted) {
          await _continueWithVerifiedPhone();
          return;
        }

        if (!_usesApiPhoneVerification) {
          _startAutoVerificationWatcher();
        }
      } else {
        _showErrorSnackBar(tr('login.send_failed', context: context));
      }
    } on SoiApiException catch (e) {
      if (!mounted) return;
      _handleException(
        e,
        defaultMessage: tr('login.send_failed', context: context),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(tr('login.send_failed', context: context));
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  /// Firebase 즉시 인증이 늦게 완료되는 경우를 감시해 사용자가 코드를 직접 입력하지 않아도 로그인으로 이어갑니다.
  void _startAutoVerificationWatcher() {
    if (_usesApiPhoneVerification) {
      return;
    }

    _autoVerifyTimer?.cancel();
    _autoVerifyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _step != _LoginStep.sms) {
        timer.cancel();
        return;
      }

      if (!_isCurrentPhoneVerificationCompleted) {
        return;
      }

      timer.cancel();
      unawaited(_continueWithVerifiedPhone());
    });
  }

  /// 입력이 바뀌거나 단계가 돌아갈 때 이전 인증 대기 상태를 정리해 다음 요청과 섞이지 않게 합니다.
  void _resetPendingPhoneVerification() {
    _autoVerifyTimer?.cancel();
    _smsController.clear();
    context.read<api.UserController>().resetPhoneVerificationState();
  }

  /// 인증이 끝난 전화번호로 실제 로그인 API를 호출하고 홈 화면 이동 여부를 결정합니다.
  Future<void> _continueWithVerifiedPhone({
    bool manageLoadingState = true,
  }) async {
    if (manageLoadingState && _isVerifying) return;

    final phoneForLogin = _localPhone;
    if (phoneForLogin.isEmpty) {
      _showErrorSnackBar(tr('login.phone_required', context: context));
      return;
    }

    FocusScope.of(context).unfocus();
    if (manageLoadingState) {
      setState(() => _isVerifying = true);
    }

    final userController = context.read<api.UserController>();
    try {
      final user = await userController.loginByPhone(phoneForLogin);

      if (!mounted) return;

      if (user != null) {
        _goHomePage();
      } else {
        _showErrorSnackBar(tr('login.not_found', context: context));
      }
    } on SoiApiException catch (e) {
      if (!mounted) return;
      _handleException(e, defaultMessage: tr('login.failed', context: context));
    } catch (_) {
      if (!mounted) return;
      _showErrorSnackBar(tr('login.failed', context: context));
    } finally {
      if (manageLoadingState && mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  /// 사용자가 입력한 코드를 현재 인증 채널에 전달하고 성공 시 전화번호 로그인으로 이어집니다.
  Future<void> _verifyAndLogin() async {
    if (_isVerifying) return;

    if (_isCurrentPhoneVerificationCompleted) {
      await _continueWithVerifiedPhone(manageLoadingState: false);
      return;
    }

    final code = _smsController.text.trim();
    final phoneForVerify = _usesApiPhoneVerification ? _localPhone : _e164Phone;

    FocusScope.of(context).unfocus();
    setState(() => _isVerifying = true);

    final userController = context.read<api.UserController>();
    try {
      final verified = await userController.verifySmsCode(
        phoneForVerify,
        code,
        useFirebase: !_usesApiPhoneVerification,
      );

      if (!mounted) return;

      if (!verified) {
        _showErrorSnackBar(tr('login.verification_failed', context: context));
        return;
      }

      await _continueWithVerifiedPhone(manageLoadingState: false);
    } on SoiApiException catch (e) {
      if (!mounted) return;
      _handleException(e, defaultMessage: tr('login.failed', context: context));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(tr('login.failed', context: context));
    } finally {
      if (mounted && _isVerifying) setState(() => _isVerifying = false);
    }
  }

  /// 인증 예외 타입에 맞는 로그인 메시지를 선택해 화면에 전달합니다.
  void _handleException(
    SoiApiException error, {
    required String defaultMessage,
  }) {
    if (error is NetworkException) {
      _showErrorSnackBar(tr('login.network_error', context: context));
      return;
    }
    if (error is BadRequestException) {
      _showErrorSnackBar(tr('login.invalid_input', context: context));
      return;
    }
    _showErrorSnackBar(defaultMessage);
  }

  void _goHomePage() {
    Navigator.pushAndRemoveUntil(context, _buildHomeRoute(), (route) => false);
  }

  Route<void> _buildHomeRoute() {
    final routeBuilder = widget.homeRouteBuilder;
    if (routeBuilder != null) {
      return routeBuilder(context);
    }

    return MaterialPageRoute<void>(
      builder: (context) => HomePageNavigationBar(
        key: HomePageNavigationBar.rootKey,
        currentPageIndex: 0,
        requestPushPermissionOnEnter: true,
      ),
      settings: const RouteSettings(name: '/home_navigation_screen'),
    );
  }

  Future<void> _issueTestPushToken() async {
    if (_isIssuingTestPushToken) return;

    FocusScope.of(context).unfocus();
    setState(() => _isIssuingTestPushToken = true);

    try {
      final token = await AppPushCoordinator.instance.issueTestDeviceToken();
      if (!mounted) return;

      if (token == null) {
        _showErrorSnackBar(
          tr('login.test_push_token_unavailable', context: context),
        );
        return;
      }

      await Clipboard.setData(ClipboardData(text: token));
      debugPrint('[LoginScreen] test FCM token issued: $token');

      if (!mounted) return;
      SnackBarUtils.showSnackBar(
        context,
        tr('login.test_push_token_copied', context: context),
        duration: const Duration(seconds: 2),
      );
      await _showIssuedTokenDialog(token);
    } catch (e) {
      if (!mounted) return;
      debugPrint('[LoginScreen] test FCM token issue failed: $e');
      _showErrorSnackBar(
        tr(
          'login.test_push_token_failed_with_reason',
          context: context,
          namedArgs: {'error': '$e'},
        ),
      );
    } finally {
      if (mounted) setState(() => _isIssuingTestPushToken = false);
    }
  }

  Future<void> _showIssuedTokenDialog(String token) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            tr('login.test_push_token_dialog_title', context: dialogContext),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    'login.test_push_token_dialog_hint',
                    context: dialogContext,
                  ),
                ),
                SizedBox(height: 12.h),
                SelectableText(token),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr('common.confirm', context: dialogContext)),
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      SnackBarUtils.showSnackBar(context, message);
    }
  }
}
