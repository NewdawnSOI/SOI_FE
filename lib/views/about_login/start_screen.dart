import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_constants.dart';
import '../../api/controller/user_controller.dart';
import '../../theme/theme.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with TickerProviderStateMixin {
  /// 서버 초기화 공지 표시 여부 확인에 사용되는 키와 기존 설치 흔적 키 목록
  /// 서버 초기화 공지 표시 여부는 SharedPreferences에 저장된 플래그와 기존 설치 흔적 키 존재 여부를 기반으로 결정됩니다.
  static const String _serverResetNoticeShownKey =
      'start_server_reset_notice_shown_20260319';

  /// 기존 설치 흔적 키 목록 (하나라도 존재하면 서버 초기화 공지를 보여줌)
  static const List<String> _existingInstallTraceKeys = [
    AppConstant.hasSeenLaunchVideoKey,
    'api_is_logged_in',
    'api_user_id',
    'api_phone_number',
    'api_access_token',
    'api_onboarding_completed',
  ];

  bool _isCheckingAutoLogin = true;
  bool _homeNavigationScheduled = false;

  /// 서버 초기화 공지 표시 여부 확인 완료 여부
  /// 이 값이 true가 되면 이후로는 서버 초기화 공지 표시 여부를 다시 확인하지 않습니다.
  bool _serverResetNoticeChecked = false;

  // 애니메이션 컨트롤러들
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _buttonController;

  // 애니메이션들
  late Animation<double> _logoOpacity;
  late Animation<Offset> _logoSlide;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _buttonOpacity;
  late Animation<Offset> _buttonSlide;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkInitialAuthState();
  }

  /// 애니메이션 초기화
  void _initializeAnimations() {
    // 애니메이션 컨트롤러 생성
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _textController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // 애니메이션 정의
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );
    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
        );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );

    _buttonOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );
    _buttonSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _buttonController,
            curve: Curves.easeOutCubic,
          ),
        );
  }

  /// 순차적 애니메이션 시작
  void _startAnimations() async {
    // 500ms 대기 후 로고 애니메이션
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) _logoController.forward();

    // 로고 애니메이션 완료 후 텍스트 애니메이션
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) _textController.forward();

    // 텍스트 애니메이션 완료 후 버튼 애니메이션
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) _buttonController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  /// 앱 루트에서 이미 복원한 인증 상태만 보고 시작 화면을 결정합니다.
  void _checkInitialAuthState() {
    final userController = Provider.of<UserController>(context, listen: false);
    if (userController.isLoggedIn) {
      unawaited(_navigateToHome());
      return;
    }

    _isCheckingAutoLogin = false;
    _startAnimations();
    unawaited(_showServerResetNoticeIfNeeded());
  }

  Future<void> _showServerResetNoticeIfNeeded() async {
    if (_serverResetNoticeChecked) {
      return;
    }
    _serverResetNoticeChecked = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyShown = prefs.getBool(_serverResetNoticeShownKey) ?? false;
      final hasExistingInstallTrace = _existingInstallTraceKeys.any(
        prefs.containsKey,
      );
      if (alreadyShown || !hasExistingInstallTrace || !mounted) {
        return;
      }

      await prefs.setBool(_serverResetNoticeShownKey, true);
      if (!mounted) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        unawaited(
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Container(
                  padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 24.h),
                  decoration: BoxDecoration(
                    color: AppTheme.lightTheme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(28.r),
                    border: Border.all(
                      color: const Color(0xff2b2b2b),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr(
                          'start.server_reset_notice_title',
                          context: dialogContext,
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFF8F8F8),
                          fontSize: 20.sp,
                          fontFamily: 'Pretendard Variable',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 14.h),
                      Text(
                        tr(
                          'start.server_reset_notice_message',
                          context: dialogContext,
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFD9D9D9),
                          fontSize: 15.sp,
                          fontFamily: 'Pretendard Variable',
                          fontWeight: FontWeight.w500,
                          height: 1.55,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            minimumSize: Size(double.infinity, 52.h),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            tr('common.confirm', context: dialogContext),
                            style: TextStyle(
                              fontSize: 17.sp,
                              fontFamily: 'Pretendard Variable',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      });
    } catch (error) {
      debugPrint('서버 초기화 공지 표시 여부 확인 실패: $error');
    }
  }

  /// 로그인 버튼 처리
  Future<void> _handleLoginTap() async {
    if (!mounted) {
      return;
    }
    Navigator.pushNamed(context, '/login');
  }

  Future<void> _navigateToHome() async {
    if (!mounted || _homeNavigationScheduled) {
      return;
    }

    _homeNavigationScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.pushReplacementNamed(context, '/home_navigation_screen');
    });
  }

  @override
  Widget build(BuildContext context) {
    // 자동 로그인 체크 중일 때 로딩 화면 표시
    if (_isCheckingAutoLogin) {
      return Scaffold(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        body: Center(
          child: AnimatedBuilder(
            animation: _logoController,
            builder: (context, child) {
              return SlideTransition(
                position: _logoSlide,
                child: FadeTransition(
                  opacity: _logoOpacity,
                  child: Image.asset(
                    'assets/SOI_logo.png',
                    width: 126.w,
                    height: 88.h,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(height: 170.h),
              // 로고 애니메이션
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return SlideTransition(
                    position: _logoSlide,
                    child: FadeTransition(
                      opacity: _logoOpacity,
                      child: Image.asset(
                        'assets/SOI_logo.png',
                        width: 126.w,
                        height: 88.h,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 38.h),
              // 텍스트 애니메이션
              AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textOpacity,
                      child: _buildSubText(),
                    ),
                  );
                },
              ),
              SizedBox(height: 257.h),
              // 버튼 애니메이션
              AnimatedBuilder(
                animation: _buttonController,
                builder: (context, child) {
                  return SlideTransition(
                    position: _buttonSlide,
                    child: FadeTransition(
                      opacity: _buttonOpacity,
                      child: _buildButtons(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubText() {
    return Text(
      tr('start.welcome', context: context),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: const Color(0xFFF8F8F8),
        fontSize: 20,
        fontFamily: 'Pretendard Variable',
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildButtons() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(context, '/auth');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xffffffff),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17.8),
            ),
          ),
          child: Container(
            width: 239.w,
            height: 59.h,
            alignment: Alignment.center,
            child: Text(
              tr('common.signup', context: context),
              style: TextStyle(
                color: Colors.black,
                fontSize: 22.sp,
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        SizedBox(height: 19.w),
        ElevatedButton(
          onPressed: () async {
            // 로그인 기록 체크 후 분기 처리
            await _handleLoginTap();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xff171717),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17.8),
            ),
          ),
          child: Container(
            width: 239.w,
            height: 59.h,
            alignment: Alignment.center,
            child: Text(
              tr('common.login', context: context),
              style: TextStyle(
                color: Colors.white,
                fontSize: 22.sp,
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
