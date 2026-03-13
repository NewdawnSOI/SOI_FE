import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../api/controller/category_controller.dart';
import '../../api/controller/media_controller.dart';
import '../../api/controller/user_controller.dart';
import '../../api/models/user.dart';
import '../../utils/snackbar_utils.dart';
import '../about_feed/manager/feed_data_manager.dart';
import 'services/profile_data_service.dart';
import 'services/profile_session_service.dart';
import 'widgets/profile_action_confirmation_sheet.dart';
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

  bool _isLoading = true;
  bool _isUploadingProfile = false;
  int _profileImageRetryCount = 0;
  bool _profileImageLoadFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  /// 사용자 데이터를 로드하는 함수입니다.
  Future<void> _loadUserData() async {
    if (!mounted) return;

    final userController = context.read<UserController>();
    final mediaController = context.read<MediaController>();
    final currentUser = userController.currentUser;

    if (currentUser == null) {
      debugPrint('currentUser가 null입니다.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // 사용자 정보와 프로필 사진 URL을 가져와서 profileData에 저장합니다.
      final profileData = await _profileDataService.loadUserData(
        userId: currentUser.id,
        userController: userController,
        mediaController: mediaController,
      );

      if (!mounted) return;
      _applyLoadedProfileData(profileData); // 로드된 데이터를 화면에 적용합니다.
    } catch (error) {
      debugPrint('사용자 데이터 로드 오류: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfileImage() async {
    final userController = context.read<UserController>();
    final mediaController = context.read<MediaController>();
    final categoryController = context.read<CategoryController>();
    final currentUser = userController.currentUser;

    if (currentUser == null) {
      _showProfileSnackBar(
        tr('profile.snackbar.login_required', context: context),
      );
      return;
    }

    try {
      final pickedFile = await _profileDataService.pickProfileImage();
      if (!mounted || pickedFile == null) return;

      final fileExists = await pickedFile.exists();
      if (!fileExists) {
        if (!mounted) return;
        _showProfileSnackBar(
          tr('profile.snackbar.image_not_found', context: context),
        );
        return;
      }

      final compressedFile = await _profileDataService.compressProfileImage(
        pickedFile,
      );

      if (!mounted) return;
      setState(() {
        _isUploadingProfile = true;
      });

      final uploadResult = await _profileDataService.uploadProfileImage(
        file: compressedFile,
        userId: currentUser.id,
        userController: userController,
        mediaController: mediaController,
        categoryController: categoryController,
      );

      if (!mounted) return;

      switch (uploadResult.status) {
        case ProfileImageUploadStatus.success:
          setState(() {
            _profileImageUrl = uploadResult.profileImageUrl;
            _profileImageRetryCount = 0;
            _profileImageLoadFailed = false;
            _userInfo = uploadResult.userInfo ?? _userInfo;
          });
          _showProfileSnackBar(
            tr('profile.snackbar.profile_updated', context: context),
          );
          break;
        case ProfileImageUploadStatus.uploadFailed:
          _showProfileSnackBar(
            tr('profile.snackbar.upload_failed', context: context),
          );
          break;
        case ProfileImageUploadStatus.failed:
          _showProfileSnackBar(
            tr('profile.snackbar.profile_update_failed', context: context),
          );
          break;
      }
    } catch (error) {
      debugPrint('프로필 이미지 업데이트 오류: $error');
      if (!mounted) return;
      _showProfileSnackBar(
        tr('profile.snackbar.profile_update_failed', context: context),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingProfile = false;
        });
      }
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
  void _applyLoadedProfileData(ProfileScreenData profileData) {
    setState(() {
      _userInfo = profileData.userInfo;
      _profileImageUrl = profileData.profileImageUrl;
      _profileImageRetryCount = 0;
      _profileImageLoadFailed = false;
      _isLoading = false;
    });
  }

  /// 프로필 이미지 로드 실패 시 재시도 횟수를 증가시키는 함수입니다.
  void _incrementProfileImageRetry() {
    if (!mounted) return;
    setState(() {
      _profileImageRetryCount++; // 프로필 이미지 재시도 횟수를 증가시킵니다.
    });
  }

  /// 프로필 이미지 로드 실패 상태를 표시하는 함수입니다.
  void _markProfileImageLoadFailed() {
    // 이미 실패 상태인 경우 중복으로 설정하지 않도록 합니다.
    if (!mounted || _profileImageLoadFailed) return;
    setState(() {
      // 프로필 이미지 로드 실패 상태를 true로 설정합니다.
      _profileImageLoadFailed = true;
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

  /// 프로필 관련 작업의 결과를 사용자에게 알려주는 스낵바를 표시하는 함수입니다.
  void _showProfileSnackBar(String message) {
    if (!mounted) return;
    SnackBarUtils.showSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xFFD9D9D9)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // '프로필' 타이틀을 빌드하는 Text 위젯입니다.
            Text(
              tr('profile.title', context: context),
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 20.sp,
                color: const Color(0xFFD9D9D9),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFD9D9D9)),
              )
            : SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 17.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 프로필 아바타 헤더를 빌드하는 위젯입니다.
                      ProfileAvatarHeader(
                        profileImageUrl: _profileImageUrl,
                        isUploadingProfile: _isUploadingProfile,
                        profileImageLoadFailed: _profileImageLoadFailed,
                        profileImageRetryCount: _profileImageRetryCount,
                        onEditTap: _updateProfileImage,
                        onImageRetryRequested: _incrementProfileImageRetry,
                        onImageLoadFailed: _markProfileImageLoadFailed,
                      ),
                      ProfileAccountSection(userInfo: _userInfo),
                      SizedBox(height: 36.h),
                      _buildAppSettingsSection(), // 앱 설정 섹션을 빌드하는 위젯입니다.
                      SizedBox(height: 36.h),
                      _buildUsageGuideSection(), // 이용 안내 섹션을 빌드하는 위젯입니다.
                      SizedBox(height: 36.h),
                      _buildOtherSection(), // 기타 섹션을 빌드하는 위젯입니다.
                      SizedBox(height: 49.h),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
