import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../api/controller/friend_controller.dart';
import '../../api/controller/media_controller.dart';
import '../../api/controller/user_controller.dart';
import '../../api/models/user.dart';
import '../../utils/snackbar_utils.dart';
import '../about_feed/manager/feed_data_manager.dart';
import 'services/profile_data_service.dart';
import 'services/profile_session_service.dart';
import 'widgets/profile_action_confirmation_sheet.dart';
import 'widgets/profile_main_header.dart';
import 'widgets/profile_screen_sections.dart';

/// 사용자 프로필 화면을 구성하는 위젯입니다.
/// 사용자 정보 표시, 프로필 이미지 업데이트, 로그아웃 및 계정 삭제 기능을 포함하고 있습니다.
class ProfileSettingScreen extends StatefulWidget {
  const ProfileSettingScreen({super.key});

  @override
  State<ProfileSettingScreen> createState() => _ProfileSettingScreenState();
}

class _ProfileSettingScreenState extends State<ProfileSettingScreen> {
  final ProfileDataService _profileDataService = ProfileDataService();
  final ProfileSessionService _profileSessionService =
      const ProfileSessionService();

  User? _userInfo;
  String? _profileImageUrl;
  int _friendCount = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _primeInitialHeaderState();
    _loadUserData();
  }

  void _primeInitialHeaderState() {
    final currentUser = context.read<UserController>().currentUser;
    final friendController = context.read<FriendController>();
    final mediaController = context.read<MediaController>();
    if (currentUser == null) return;

    _userInfo = currentUser;
    _profileImageUrl = _peekProfileImageUrl(
      user: currentUser,
      mediaController: mediaController,
    );
    unawaited(
      _prefetchProfileImageUrl(
        user: currentUser,
        mediaController: mediaController,
      ),
    );
    if (friendController.cachedFriendsUserId == currentUser.id) {
      _friendCount = friendController.cachedFriends.length;
    }
  }

  String? _peekProfileImageUrl({
    required User? user,
    required MediaController mediaController,
  }) {
    final profileImageKey = user?.profileImageUrlKey?.trim() ?? '';
    if (profileImageKey.isEmpty) return null;

    final cachedUrl = mediaController.peekPresignedUrl(profileImageKey)?.trim();
    if (cachedUrl == null || cachedUrl.isEmpty) {
      return null;
    }
    return cachedUrl;
  }

  Future<void> _prefetchProfileImageUrl({
    required User? user,
    required MediaController mediaController,
  }) async {
    if (!mounted) return;

    final profileImageKey = user?.profileImageUrlKey?.trim() ?? '';
    if (profileImageKey.isEmpty ||
        (_profileImageUrl?.trim().isNotEmpty ?? false)) {
      return;
    }

    final resolvedUrl = await mediaController.getPresignedUrl(profileImageKey);
    if (!mounted) return;

    final trimmedUrl = resolvedUrl?.trim() ?? '';
    if (trimmedUrl.isEmpty) return;

    final activeProfileImageKey =
        (_userInfo ?? user)?.profileImageUrlKey?.trim() ?? '';
    if (activeProfileImageKey != profileImageKey) return;

    setState(() {
      _profileImageUrl = trimmedUrl;
    });
  }

  String? _resolveLoadedProfileImageUrl({
    required User? previousUser,
    required String? previousUrl,
    required User? nextUser,
    required String? nextUrl,
    required MediaController mediaController,
  }) {
    final nextProfileImageKey = nextUser?.profileImageUrlKey?.trim() ?? '';
    if (nextProfileImageKey.isEmpty) return null;

    final resolvedNextUrl = nextUrl?.trim() ?? '';
    if (resolvedNextUrl.isNotEmpty) {
      return resolvedNextUrl;
    }

    final cachedUrl = mediaController
        .peekPresignedUrl(nextProfileImageKey)
        ?.trim();
    if (cachedUrl != null && cachedUrl.isNotEmpty) {
      return cachedUrl;
    }

    final previousProfileImageKey =
        previousUser?.profileImageUrlKey?.trim() ?? '';
    final resolvedPreviousUrl = previousUrl?.trim() ?? '';
    if (previousProfileImageKey == nextProfileImageKey &&
        resolvedPreviousUrl.isNotEmpty) {
      return resolvedPreviousUrl;
    }

    return null;
  }

  /// 사용자 데이터를 로드하는 함수입니다.
  Future<void> _loadUserData() async {
    if (!mounted) return;

    final userController = context.read<UserController>();
    final mediaController = context.read<MediaController>();
    final friendController = context.read<FriendController>();
    final currentUser = userController.currentUser;

    if (currentUser == null) {
      debugPrint('currentUser가 null입니다.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    ProfileScreenData? profileData;
    final previousUser = _userInfo ?? currentUser;
    var resolvedProfileImageUrl = _resolveLoadedProfileImageUrl(
      previousUser: previousUser,
      previousUrl: _profileImageUrl,
      nextUser: previousUser,
      nextUrl: null,
      mediaController: mediaController,
    );
    var resolvedFriendCount = _friendCount;

    try {
      profileData = await _profileDataService.loadUserData(
        userId: currentUser.id,
        userController: userController,
        mediaController: mediaController,
      );
      resolvedProfileImageUrl = _resolveLoadedProfileImageUrl(
        previousUser: previousUser,
        previousUrl: _profileImageUrl,
        nextUser: profileData.userInfo ?? previousUser,
        nextUrl: profileData.profileImageUrl,
        mediaController: mediaController,
      );
    } catch (error) {
      debugPrint('사용자 데이터 로드 오류: $error');
    }

    try {
      final friends = await friendController.getAllFriends(
        userId: currentUser.id,
      );
      resolvedFriendCount = friends.length;
    } catch (error) {
      debugPrint('친구 수 로드 오류: $error');
    }

    if (!mounted) return;

    if (profileData != null) {
      _applyLoadedProfileData(
        profileData,
        friendCount: resolvedFriendCount,
        profileImageUrl: resolvedProfileImageUrl,
      );
      return;
    }

    setState(() {
      _profileImageUrl = resolvedProfileImageUrl;
      _friendCount = resolvedFriendCount;
      _isLoading = false;
    });
  }

  void _closeSettings() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  void _showLogoutDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ProfileActionConfirmationSheet(
        title: tr('profile.logout.title', context: context),
        confirmLabel: tr('profile.logout.confirm', context: context),
        onConfirm: _performLogout,
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      final userController = context.read<UserController>();
      final feedDataManager = context.read<FeedDataManager>();

      await _profileSessionService.logout(
        userController: userController,
        feedDataManager: feedDataManager,
      );

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/start', (route) => false);
    } catch (error) {
      if (!mounted) return;
      SnackBarUtils.showSnackBar(
        context,
        tr('profile.snackbar.logout_failed', context: context),
      );
    }
  }

  void _showDeleteAccountDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ProfileActionConfirmationSheet(
        title: tr('profile.delete_account.title', context: context),
        description: tr('profile.delete_account.description', context: context),
        confirmLabel: tr('profile.delete_account.confirm', context: context),
        onConfirm: _performDeleteAccount,
      ),
    );
  }

  Future<void> _performDeleteAccount() async {
    var isLoadingDialogShown = false;

    try {
      if (mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
        isLoadingDialogShown = true;
      }

      final userController = context.read<UserController>();
      final feedDataManager = context.read<FeedDataManager>();

      await _profileSessionService.beginDeleteAccount(
        userController: userController,
        feedDataManager: feedDataManager,
      );

      if (!mounted) return;
      if (isLoadingDialogShown) {
        Navigator.of(context).pop();
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/start', (route) => false);
    } catch (error) {
      if (!mounted) return;
      if (isLoadingDialogShown) {
        Navigator.of(context).pop();
      }
      SnackBarUtils.showSnackBar(
        context,
        tr(
          'profile.snackbar.delete_account_failed',
          context: context,
          namedArgs: {'error': error.toString()},
        ),
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// 로드된 사용자 정보와 프로필 사진 URL을 화면 상태에 적용하는 함수입니다.
  /// 로드된 데이터를 화면에 반영하고, 로딩 상태를 해제합니다.
  ///
  /// Parameters:
  /// - [profileData]: 사용자 정보와 프로필 사진 URL이 담긴 객체입니다. 이 데이터를 화면 상태에 적용합니다.
  void _applyLoadedProfileData(
    ProfileScreenData profileData, {
    required int friendCount,
    required String? profileImageUrl,
  }) {
    setState(() {
      _userInfo = profileData.userInfo ?? _userInfo;
      _profileImageUrl = profileImageUrl;
      _friendCount = friendCount;
      _isLoading = false;
    });
  }

  /// 앱 설정 섹션을 빌드하는 함수입니다.
  Widget _buildAppSettingsSection() {
    return ProfileMenuSection(
      // title: '앱 설정'
      title: tr('profile.section.app_settings', context: context),
      child: ProfileSectionCard(
        child: Column(
          children: [
            ProfileMenuItem(
              // title: '언어'로 앱 설정 메뉴 항목을 표시합니다.
              title: tr('profile.settings.language', context: context),

              // value: '한국어'로 설정하여 현재 언어를 표시합니다.
              // 언어 설정이 생기면 추후에 변경될 수 있습니다.
              value: tr('profile.settings.language_ko', context: context),
            ),
            const ProfileSectionDivider(),

            //'개인정보 보호' 메뉴 항목을 표시합니다.
            ProfileMenuItem(
              title: tr('profile.settings.privacy', context: context),
              value: '',
              onTap: () {
                Navigator.pushNamed(context, '/privacy_protect');
              },
            ),
            const ProfileSectionDivider(),

            // '게시물 관리' 메뉴 항목을 표시합니다.
            // 탭하면 '/post_management' 경로로 이동합니다.
            ProfileMenuItem(
              title: tr('profile.settings.post_management', context: context),
              value: '',
              onTap: () {
                Navigator.pushNamed(context, '/post_management');
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 앱 이용 안내 가이드 섹션을 빌드하는 함수입니다.
  Widget _buildUsageGuideSection() {
    return ProfileMenuSection(
      // title: '이용안내' 타이틀을 빌드합니다.
      title: tr('profile.section.usage_guide', context: context),
      child: ProfileSectionCard(
        child: Column(
          children: [
            // '개인 정보 처리 방침' 메뉴 섹션을 빌드하는 위젯
            ProfileMenuItem(
              title: tr('profile.usage.privacy_policy', context: context),
              onTap: () {
                Navigator.pushNamed(context, '/privacy_policy');
              },
            ),
            const ProfileSectionDivider(),

            // '서비스 이용 약관' 메뉴를 빌드하는 위젯
            ProfileMenuItem(
              title: tr('profile.usage.terms_of_service', context: context),
              onTap: () {
                Navigator.pushNamed(context, '/terms_of_service');
              },
            ),
            const ProfileSectionDivider(),

            // '앱 버전' 메뉴 항목을 빌드하는 위젯
            ProfileMenuItem(
              // title: '앱 버전'으로 앱 버전 정보를 표시하는 메뉴 항목을 빌드합니다.
              title: tr('profile.usage.app_version', context: context),

              // value: '1.0.0'으로 현재 하드코딩 되어있습니다.
              value: tr('profile.usage.app_version_value', context: context),
            ),
          ],
        ),
      ),
    );
  }

  /// '기타' 섹션을 빌드하는 함수입니다.
  Widget _buildOtherSection() {
    return ProfileMenuSection(
      // '기타' 타이틀을 빌드합니다.
      title: tr('profile.section.other', context: context),
      child: ProfileSectionCard(
        child: Column(
          children: [
            // '앱 정보 제공 동의' 메뉴 항목을 빌드하는 위젯
            ProfileMenuItem(
              title: tr('profile.other.app_info_consent', context: context),
            ),
            const ProfileSectionDivider(),

            // '계정 삭제' 메뉴 항목을 빌드하는 위젯
            ProfileMenuItem(
              title: tr('profile.other.delete_account', context: context),
              isRed: true,
              onTap: _showDeleteAccountDialog,
            ),
            const ProfileSectionDivider(),

            // '로그아웃' 메뉴 항목을 빌드하는 위젯
            ProfileMenuItem(
              title: tr('profile.other.logout', context: context),
              isRed: true,
              onTap: _showLogoutDialog,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserController>().currentUser;
    final mediaController = context.read<MediaController>();
    final displayUser = _userInfo ?? currentUser;
    final displayProfileImageUrl =
        _resolveLoadedProfileImageUrl(
          previousUser: _userInfo,
          previousUrl: _profileImageUrl,
          nextUser: displayUser,
          nextUrl: _profileImageUrl,
          mediaController: mediaController,
        ) ??
        _peekProfileImageUrl(
          user: displayUser,
          mediaController: mediaController,
        );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          ProfileMainHeader(
            nickname: displayUser?.userId,
            profileImageUrl: displayProfileImageUrl,
            profileImageKey: displayUser?.profileImageUrlKey,
            friendCount: _friendCount,
            onMenuTap: _closeSettings,
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD9D9D9)),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(17.w, 28.h, 17.w, 49.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileAccountSection(userInfo: _userInfo),
                        SizedBox(height: 36.h),
                        _buildAppSettingsSection(),
                        SizedBox(height: 36.h),
                        _buildUsageGuideSection(),
                        SizedBox(height: 36.h),
                        _buildOtherSection(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
