import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/api_exception.dart';
import 'package:soi/api/controller/user_controller.dart' as api;
import 'package:solar_icons/solar_icons.dart';

import '../../app/push/app_push_coordinator.dart';
import '../../theme/theme.dart';
import '../../utils/snackbar_utils.dart';
import '../home_navigator_screen.dart';
import 'widgets/common/continue_button.dart';
import 'widgets/common/custom_text_field.dart';
import 'widgets/common/page_title.dart';

/// 닉네임과 전화번호 로그인을 처리하고, 성공 시 홈 진입 라우팅까지 이어주는 화면입니다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.homeRouteBuilder});

  final Route<void> Function(BuildContext context)? homeRouteBuilder;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  late final Listenable _inputFieldsListenable = Listenable.merge([
    _nicknameController,
    _phoneController,
  ]);

  bool _isSubmitting = false;
  bool _isIssuingTestPushToken = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _hasRequiredInputs {
    return _nicknameController.text.trim().isNotEmpty &&
        _normalizedPhoneNumber.isNotEmpty;
  }

  String get _normalizedPhoneNumber {
    return _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              children: [
                SizedBox(height: 12.h),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PageTitle(title: tr('login.title', context: context)),
                      SizedBox(height: 28.h),
                      _buildNicknameField(),
                      SizedBox(height: 16.h),
                      _buildPhoneField(),
                    ],
                  ),
                ),
                AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(
                    bottom: keyboardHeight > 0 ? keyboardHeight + 20.h : 40.h,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListenableBuilder(
                        listenable: _inputFieldsListenable,
                        builder: (context, _) {
                          return ContinueButton(
                            isEnabled: _hasRequiredInputs && !_isSubmitting,
                            text: _isSubmitting
                                ? tr('login.loading', context: context)
                                : tr('common.login', context: context),
                            onPressed: () => _submitLogin(),
                          );
                        },
                      ),
                      if (kDebugMode && supportsFirebaseMessaging) ...[
                        SizedBox(height: 12.h),
                        TextButton(
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
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNicknameField() {
    return CustomTextField(
      controller: _nicknameController,
      hintText: tr('login.nickname_hint', context: context),
      keyboardType: TextInputType.text,
      textAlign: TextAlign.start,
      prefixIcon: Icon(
        Icons.person_outline,
        color: const Color(0xffC0C0C0),
        size: 24.sp,
      ),
      onSubmitted: (_) => _handleSubmitted(),
    );
  }

  Widget _buildPhoneField() {
    return CustomTextField(
      controller: _phoneController,
      hintText: tr('login.phone_hint', context: context),
      keyboardType: TextInputType.phone,
      textAlign: TextAlign.start,
      prefixIcon: Icon(
        SolarIconsOutline.phone,
        color: const Color(0xffC0C0C0),
        size: 24.sp,
      ),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))],
      onSubmitted: (_) => _handleSubmitted(),
    );
  }

  void _handleSubmitted() {
    if (_hasRequiredInputs && !_isSubmitting) {
      _submitLogin();
    }
  }

  Future<void> _issueTestPushToken() async {
    if (_isIssuingTestPushToken) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isIssuingTestPushToken = true;
    });

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
      if (mounted) {
        setState(() {
          _isIssuingTestPushToken = false;
        });
      }
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

  /// 로그인 성공 후 홈으로 이동하고 홈 첫 진입에서 푸시 권한 요청을 이어받게 합니다.
  Future<void> _submitLogin() async {
    if (_isSubmitting) return;

    final nickname = _nicknameController.text.trim();
    final phoneNumber = _normalizedPhoneNumber;
    final userController = context.read<api.UserController>();

    if (nickname.isEmpty) {
      _showErrorSnackBar(tr('login.nickname_required', context: context));
      return;
    }

    if (phoneNumber.isEmpty) {
      _showErrorSnackBar(tr('login.phone_required', context: context));
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = await userController.login(
        nickName: nickname,
        phoneNumber: phoneNumber,
      );

      if (!mounted) return;

      if (user != null) {
        _goHomePage();
        return;
      }

      debugPrint('[LoginScreen] 로그인 실패 code=404');
      _showErrorSnackBar(tr('login.not_found', context: context));
    } on SoiApiException catch (e) {
      if (!mounted) return;
      _handleLoginException(
        e,
        logPrefix: '로그인',
        defaultMessage: tr('login.failed', context: context),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('로그인 알 수 없는 오류: $e');
      _showErrorSnackBar(tr('login.failed', context: context));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _handleLoginException(
    SoiApiException error, {
    required String logPrefix,
    required String defaultMessage,
  }) {
    if (error is NetworkException) {
      debugPrint(
        '[LoginScreen] $logPrefix 실패 code=network, message=${error.message}',
      );
      _showErrorSnackBar(tr('login.network_error', context: context));
      return;
    }
    if (error is BadRequestException) {
      debugPrint(
        '[LoginScreen] $logPrefix 실패 code=${error.statusCode ?? 400}, message=${error.message}',
      );
      _showErrorSnackBar(tr('login.invalid_input', context: context));
      return;
    }
    debugPrint(
      '[LoginScreen] $logPrefix 실패 code=${error.statusCode ?? 'unknown'}, message=${error.message}',
    );
    _showErrorSnackBar(defaultMessage);
  }

  /// 로그인 성공 직후 홈 라우트를 다시 만들고 첫 진입용 푸시 권한 플래그를 전달합니다.
  void _goHomePage() {
    Navigator.pushAndRemoveUntil(
      context,
      _buildHomeRoute(),
      (route) => false,
    );
  }

  /// 로그인 이후 도착 화면 생성을 한 곳에 모아 두어 테스트가 실제 홈 전체를 띄우지 않고도 흐름을 검증하게 합니다.
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

  void _showErrorSnackBar(String message) {
    if (mounted) {
      SnackBarUtils.showSnackBar(context, message);
    }
  }
}
