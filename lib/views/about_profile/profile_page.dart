import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../api/controller/friend_controller.dart';
import '../../api/controller/media_controller.dart';
import '../../api/controller/user_controller.dart';
import '../../api/models/post.dart';
import '../../api/models/user.dart';
import '../../app/app_constants.dart';
import 'services/profile_data_service.dart';
import 'widgets/profile_main_header.dart';
import 'widgets/profile_main_tab_views.dart';

/// 프로필 페이지의 탭바의 타입을 정의하는 열거형입니다.
enum _ProfileTab { media, text, comments }

/// 프로필 페이지의 메인 위젯입니다.
/// 사용자 정보, 프로필 이미지, 친구 수 등의 데이터를 로드하고, 프로필 헤더와 탭 바를 구성합니다.

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileDataService _profileDataService = ProfileDataService();

  User? _userInfo;
  String? _profileImageUrl;
  int _friendCount = 0;
  _ProfileTab _selectedTab = _ProfileTab.media;

  @override
  void initState() {
    super.initState();
    _primeInitialHeaderState();
    _loadProfilePageData();
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

  Future<void> _loadProfilePageData() async {
    if (!mounted) return;

    final userController = context.read<UserController>();
    final mediaController = context.read<MediaController>();
    final friendController = context.read<FriendController>();
    final currentUser = userController.currentUser;

    if (currentUser == null) {
      return;
    }

    final previousUser = _userInfo ?? currentUser;
    User? resolvedUser = previousUser;
    var resolvedProfileImageUrl = _resolveLoadedProfileImageUrl(
      previousUser: previousUser,
      previousUrl: _profileImageUrl,
      nextUser: previousUser,
      nextUrl: null,
      mediaController: mediaController,
    );
    var resolvedFriendCount = _friendCount;

    try {
      final profileData = await _profileDataService.loadUserData(
        userId: currentUser.id,
        userController: userController,
        mediaController: mediaController,
      );
      resolvedUser = profileData.userInfo ?? previousUser;
      resolvedProfileImageUrl = _resolveLoadedProfileImageUrl(
        previousUser: previousUser,
        previousUrl: _profileImageUrl,
        nextUser: resolvedUser,
        nextUrl: profileData.profileImageUrl,
        mediaController: mediaController,
      );
    } catch (_) {
      resolvedUser = previousUser;
    }

    try {
      final friends = await friendController.getAllFriends(
        userId: currentUser.id,
      );
      resolvedFriendCount = friends.length;
    } catch (_) {
      resolvedFriendCount = _friendCount;
    }

    if (!mounted) return;

    setState(() {
      _userInfo = resolvedUser;
      _profileImageUrl = resolvedProfileImageUrl;
      _friendCount = resolvedFriendCount;
    });
  }

  void _openProfileSettings() {
    Navigator.of(context).pushNamed(AppRoute.profileScreen);
  }

  void _selectTab(_ProfileTab tab) {
    if (_selectedTab == tab) return;
    setState(() {
      _selectedTab = tab;
    });
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
          // 프로필 페이지의 헤더를 구성하는 ProfileMainHeader 위젯입니다.
          ProfileMainHeader(
            nickname: displayUser?.userId,
            profileImageUrl: displayProfileImageUrl,
            profileImageKey: displayUser?.profileImageUrlKey,
            friendCount: _friendCount,
            onMenuTap: _openProfileSettings,
          ),
          // 프로필 페이지의 탭 바를 구성하는 _ProfileTabBar 위젯입니다.
          // 탭 바는 미디어, 텍스트, 댓글 탭을 표시하고, 선택된 탭을 강조합니다.
          _ProfileTabBar(selectedTab: _selectedTab, onTabSelected: _selectTab),
          Expanded(
            child: displayUser?.id == null
                ? Center(
                    child: Text(
                      tr('common.login_required', context: context),
                      style: TextStyle(
                        color: const Color(0xFFB5B5B5),
                        fontSize: 15.sp,
                        fontFamily: 'Pretendard Variable',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : IndexedStack(
                    index: _selectedTab.index,
                    children: [
                      // 프로필 페이지의 각 탭에 해당하는 콘텐츠를 구성하는 위젯입니다.

                      // '미디어' 탭 콘텐츠를 구성하는 ProfilePostTabView 위젯입니다.
                      // 사용자의 미디어 게시물을 표시합니다.
                      ProfilePostTabView(
                        key: ValueKey('profile_media_tab_${displayUser!.id}'),
                        userId: displayUser.id,
                        postType: PostType.multiMedia,
                        isActive: _selectedTab == _ProfileTab.media,
                        detailTitle: tr(
                          'profile.main.tabs.media',
                          context: context,
                        ),
                        emptyMessageKey: 'profile.main.empty_media',
                      ),

                      // '텍스트' 탭 콘텐츠를 구성하는 ProfilePostTabView 위젯입니다.
                      // 사용자의 텍스트 게시물을 표시합니다.
                      ProfilePostTabView(
                        key: ValueKey('profile_text_tab_${displayUser.id}'),
                        userId: displayUser.id,
                        postType: PostType.textOnly,
                        isActive: _selectedTab == _ProfileTab.text,
                        detailTitle: tr(
                          'profile.main.tabs.text',
                          context: context,
                        ),
                        emptyMessageKey: 'profile.main.empty_text',
                      ),

                      // '댓글' 탭 콘텐츠를 구성하는 ProfileCommentTabView 위젯입니다.
                      // 사용자의 댓글을 표시합니다.
                      ProfileCommentTabView(
                        key: ValueKey('profile_comment_tab_${displayUser.id}'),
                        userId: displayUser.id,
                        isActive: _selectedTab == _ProfileTab.comments,
                        emptyMessageKey: 'profile.main.empty_comments',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// 프로필 페이지의 탭 바를 구성하는 위젯입니다.
/// 미디어, 텍스트, 댓글 탭을 표시하고, 선택된 탭을 강조합니다.
class _ProfileTabBar extends StatelessWidget {
  const _ProfileTabBar({
    required this.selectedTab,
    required this.onTabSelected,
  });

  final _ProfileTab selectedTab;
  final ValueChanged<_ProfileTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF323232))),
      ),
      child: SizedBox(
        height: 51.h,
        child: Row(
          children: [
            // 각 탭 아이템을 구성하는 _ProfileTabItem 위젯입니다.

            // '미디어' 탭 아이템입니다.
            _ProfileTabItem(
              title: tr('profile.main.tabs.media', context: context),
              isSelected: selectedTab == _ProfileTab.media,
              onTap: () => onTabSelected(_ProfileTab.media),
            ),

            // '텍스트' 탭 아이템입니다.
            _ProfileTabItem(
              title: tr('profile.main.tabs.text', context: context),
              isSelected: selectedTab == _ProfileTab.text,
              onTap: () => onTabSelected(_ProfileTab.text),
            ),

            // '댓글' 탭 아이템입니다.
            _ProfileTabItem(
              title: tr('profile.main.tabs.comments', context: context),
              isSelected: selectedTab == _ProfileTab.comments,
              onTap: () => onTabSelected(_ProfileTab.comments),
            ),
          ],
        ),
      ),
    );
  }
}

/// 프로필 페이지의 탭 아이템을 구성하는 위젯입니다.
/// 탭 제목과 선택 상태에 따라 스타일이 달라지며, 탭을 선택하면 onTap 콜백이 호출됩니다.
class _ProfileTabItem extends StatelessWidget {
  const _ProfileTabItem({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 탭 제목을 표시하는 Text 위젯입니다. 선택된 탭은 흰색으로 강조됩니다.
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12.h),

            // 선택된 탭을 강조하는 애니메이션 컨테이너입니다. 선택된 탭은 하단에 흰색 바가 표시됩니다.
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 81.sp,
              height: 4.h,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(999.r),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
