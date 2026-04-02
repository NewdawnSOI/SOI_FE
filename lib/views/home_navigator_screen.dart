import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/app/push/app_push_coordinator.dart';
import 'package:soi/views/about_feed/feed_home.dart';
import '../theme/theme.dart';
import 'about_archiving/screens/api_archive_main_screen.dart';
import 'about_camera/camera_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'about_friends/friend_management_screen.dart';
import 'about_profile/profile_page.dart';
import '../api/services/camera_service.dart';
import '../utils/tab_reselect_registry.dart';

/// 홈 탭 페이지뷰와 첫 진입 후속 액션을 조립해 인증 이후 메인 앱 진입점을 제공합니다.
class HomePageNavigationBar extends StatefulWidget {
  final int currentPageIndex;
  final bool requestPushPermissionOnEnter;

  /// 전역에서 홈 탭(Feed/Archive/Camera/Friend/Profile)을 바꾸기 위한 키입니다.
  ///
  /// (배포버전 프리즈 방지) `pushAndRemoveUntil`로 홈을 "새로" 만드는 대신,
  /// 기존 홈을 유지한 채 탭만 바꾸도록 유도합니다.
  static final GlobalKey<_HomePageNavigationBarState> _globalKey =
      GlobalKey<_HomePageNavigationBarState>();

  /// `MaterialApp.routes` 등에서 주입할 루트 키 (외부에는 `Key`로만 노출).
  static Key get rootKey => _globalKey;

  /// 현재 살아있는 홈이 있으면 탭만 변경합니다. (없으면 아무 것도 하지 않음)
  static void requestTab(int index) {
    _globalKey.currentState?._setCurrentPageIndex(index);
  }

  const HomePageNavigationBar({
    super.key,
    required this.currentPageIndex,
    this.requestPushPermissionOnEnter = false,
  });

  @override
  State<HomePageNavigationBar> createState() => _HomePageNavigationBarState();
}

class _HomePageNavigationBarState extends State<HomePageNavigationBar> {
  late int _currentPageIndex;
  late final PageController _pageController; // 페이지 뷰 컨트롤러
  static const _inactiveColor = Color(0xff535252);
  static const _activeColor = Color(0xffffffff);
  bool _didRequestPushPermissionOnEnter = false;

  void _setCurrentPageIndex(int index) {
    if (!mounted) return;
    if (_currentPageIndex == index) return;
    _moveToPage(index, animate: false);
  }

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.currentPageIndex; // 초기 페이지 인덱스 설정
    _pageController = PageController(
      initialPage: _currentPageIndex,
    ); // 페이지 컨트롤러 초기화
    _schedulePushPermissionRequestOnEntry();
    unawaited(CameraService.instance.prepareSessionIfPermitted());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 로그인/회원가입 직후 홈에 들어온 경우 첫 프레임에서만 OS 푸시 권한 요청을 시작합니다.
  void _schedulePushPermissionRequestOnEntry() {
    if (!widget.requestPushPermissionOnEnter ||
        _didRequestPushPermissionOnEnter) {
      return;
    }
    _didRequestPushPermissionOnEnter = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final userId = context.read<UserController>().currentUserId;
      if (userId == null) {
        return;
      }

      unawaited(_requestPushPermissionForUser(userId));
    });
  }

  /// 홈 진입 직후 현재 로그인 사용자 토큰 동기화까지 한 번에 이어서 처리합니다.
  Future<void> _requestPushPermissionForUser(int userId) async {
    try {
      await AppPushCoordinator.instance.requestSystemPermissionAndSyncUser(
        userId,
      );
    } catch (error) {
      debugPrint(
        '[HomePageNavigationBar] push permission request skipped: $error',
      );
    }
  }

  /// 페이지 이동 함수
  void _moveToPage(int index, {bool animate = true}) {
    if (!mounted) return;

    // 이미 선택된 탭을 다시 선택한 경우, 페이지 이동 없이 리셀이벤트만 발생하도록 처리
    // 이렇게 하면 사용자가 현재 탭을 다시 눌렀을 때, 페이지가 리셋되거나 스크롤이 최상단으로 이동하는 등의 행동을 구현할 수 있습니다.
    if (_currentPageIndex == index) {
      TabReselectRegistry.notifyReselect(index);
      return;
    }
    if (_currentPageIndex != index) {
      setState(() {
        _currentPageIndex = index;
      });
    }

    if (index == 2) {
      unawaited(CameraService.instance.activateSession());
    }

    if (!_pageController.hasClients) return;

    if (animate) {
      // 페이지 이동 애니메이션
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    _pageController.jumpToPage(index); // 즉시 페이지 이동 (애니메이션 없이)
  }

  /// 홈 탭 컨테이너는 각 탭이 자체적으로 키보드/레이아웃을 제어할 수 있게
  /// 루트 Scaffold의 body 높이를 키보드에 의해 다시 줄이지 않습니다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false, // 키보드에 의해 body 높이가 줄어드는 것을 방지
      bottomNavigationBar: Container(
        margin: EdgeInsets.only(top: 10.h),
        height: 70.h,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(backgroundColor: Colors.black),
          child: NavigationBar(
            indicatorColor: Colors.transparent,
            backgroundColor: AppTheme.lightTheme.colorScheme.surface,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            onDestinationSelected: (int index) {
              _moveToPage(index); // 페이지 이동 함수 호출
            },
            selectedIndex: _currentPageIndex,
            destinations: <Widget>[
              NavigationDestination(
                icon: _buildNavSvgIcon(
                  'assets/home_navi.svg',
                  _inactiveColor,
                  width: 26.sp,
                  height: 23.sp,
                ),
                selectedIcon: _buildNavSvgIcon(
                  'assets/home_navi.svg',
                  _activeColor,
                  width: 26.sp,
                  height: 23.sp,
                ),
                label: '',
              ),
              NavigationDestination(
                icon: _buildNavSvgIcon(
                  'assets/update_navi.svg',
                  _inactiveColor,
                ),
                selectedIcon: _buildNavSvgIcon(
                  'assets/update_navi.svg',
                  _activeColor,
                ),
                label: '',
              ),
              NavigationDestination(
                icon: _buildNavSvgIcon('assets/add_navi.svg', _inactiveColor),
                selectedIcon: _buildNavSvgIcon(
                  'assets/add_navi.svg',
                  _activeColor,
                ),
                label: '',
              ),
              NavigationDestination(
                icon: _buildNavSvgIcon(
                  'assets/friend_navi.svg',
                  _inactiveColor,
                  width: 29.sp,
                  height: 22.sp,
                ),
                selectedIcon: _buildNavSvgIcon(
                  'assets/friend_navi.svg',
                  _activeColor,
                  width: 29.sp,
                  height: 22.sp,
                ),
                label: '',
              ),
              NavigationDestination(
                icon: _buildNavSvgIcon(
                  'assets/profile_navi.svg',
                  _inactiveColor,
                  width: 28.sp,
                  height: 28.sp,
                ),
                selectedIcon: _buildNavSvgIcon(
                  'assets/profile_navi.svg',
                  _activeColor,
                  width: 28.sp,
                  height: 28.sp,
                ),
                label: '',
              ),
            ],
          ),
        ),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: CameraScreen.isVideoRecordingNotifier,
        builder: (context, isVideoRecording, child) {
          return PageView(
            controller: _pageController,
            physics: isVideoRecording
                ? const NeverScrollableScrollPhysics()
                : null,
            onPageChanged: (index) {
              if (!mounted || _currentPageIndex == index) return;
              setState(() {
                _currentPageIndex = index;
              });
              if (index == 2) {
                unawaited(CameraService.instance.activateSession());
              }
            },
            children: [
              _buildPage(0, const FeedHomeScreen()),
              _buildPage(1, const APIArchiveMainScreen()),
              _buildPage(2, CameraScreen(isActive: _currentPageIndex == 2)),
              _buildPage(3, const FriendManagementScreen()),
              _buildPage(4, const ProfilePage()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavSvgIcon(
    String assetPath,
    Color color, {
    double? width,
    double? height,
  }) {
    return SvgPicture.asset(
      assetPath,
      width: width ?? 25.sp,
      height: height ?? 25.sp,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  Widget _buildPage(int index, Widget child) {
    return TickerMode(enabled: _currentPageIndex == index, child: child);
  }
}
