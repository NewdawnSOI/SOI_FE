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

class ProfilePage extends StatefulWidget {
  ///
  /// 프로필 페이지의 메인 위젯입니다.
  /// 사용자 정보, 프로필 이미지, 친구 수 등의 데이터를 로드하고, 프로필 헤더와 탭 바를 구성합니다.
  /// 각 탭에 해당하는 콘텐츠를 표시하는 탭 뷰도 포함되어 있습니다.
  ///
  /// fields:
  /// - [_userInfo]: 현재 표시할 사용자 정보를 담는 User 객체입니다. 초기값은 null이며, 데이터 로드 후 업데이트됩니다.
  /// - [_profileImageUrl]: 현재 표시할 프로필 이미지 URL입니다. 초기값은 null이며, 데이터 로드 후 업데이트됩니다.
  /// - [_friendCount]: 현재 표시할 친구 수입니다. 초기값은 0이며, 데이터 로드 후 업데이트됩니다.
  /// - [_selectedTab]: 현재 선택된 탭을 나타내는 _ProfileTab 열거형 값입니다. 초기값은 _ProfileTab.media입니다.
  /// - [_profileDataService]
  ///   - 프로필 페이지에서 필요한 데이터와 기능을 담당하는 ProfileDataService 객체입니다.
  ///   - 데이터 로드와 프로필 이미지 선택 등의 작업을 수행합니다.
  ///
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileDataService _profileDataService = ProfileDataService();

  User? _userInfo;
  String? _profileImageUrl;
  String? _coverImageUrl;
  int _friendCount = 0;
  _ProfileTab _selectedTab = _ProfileTab.media;

  @override
  void initState() {
    super.initState();
    _primeInitialHeaderState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadProfilePageData());
    });
  }

  void _primeInitialHeaderState() {
    final userController = context.read<UserController>();
    final currentUser = userController.currentUser;
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

    // 커버 이미지 초기 로드
    final coverImageKey = userController.coverImageUrlKey?.trim() ?? '';
    if (coverImageKey.isNotEmpty) {
      _coverImageUrl = mediaController.peekPresignedUrl(coverImageKey)?.trim();
      if (_coverImageUrl == null || _coverImageUrl!.isEmpty) {
        _coverImageUrl = null;
        unawaited(
          _prefetchCoverImageUrl(
            coverImageKey: coverImageKey,
            mediaController: mediaController,
          ),
        );
      }
    }

    final cachedFriendCount = friendController.peekCachedFriendCount(
      userId: currentUser.id,
    );
    if (cachedFriendCount != null) {
      _friendCount = cachedFriendCount;
    }
  }

  Future<void> _prefetchCoverImageUrl({
    required String coverImageKey,
    required MediaController mediaController,
  }) async {
    if (!mounted) return;
    final resolvedUrl = await mediaController.getPresignedUrl(coverImageKey);
    if (!mounted) return;
    final trimmed = resolvedUrl?.trim() ?? '';
    if (trimmed.isEmpty) return;
    setState(() {
      _coverImageUrl = trimmed;
    });
  }

  String? _peekProfileImageUrl({
    required User? user,
    required MediaController mediaController,
  }) {
    final directUrl = user?.displayProfileImageUrl;
    if (directUrl != null && directUrl.isNotEmpty) {
      return directUrl;
    }

    final profileImageKey = user?.profileImageCacheKey ?? '';
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

    final directUrl = user?.displayProfileImageUrl;
    if (directUrl != null && directUrl.isNotEmpty) {
      if (_profileImageUrl?.trim() == directUrl) {
        return;
      }
      setState(() {
        _profileImageUrl = directUrl;
      });
      return;
    }

    final profileImageKey = user?.profileImageCacheKey ?? '';
    if (profileImageKey.isEmpty ||
        (_profileImageUrl?.trim().isNotEmpty ?? false)) {
      return;
    }

    final resolvedUrl = await mediaController.getPresignedUrl(profileImageKey);
    if (!mounted) return;

    final trimmedUrl = resolvedUrl?.trim() ?? '';
    if (trimmedUrl.isEmpty) return;

    final activeProfileImageKey =
        (_userInfo ?? user)?.profileImageCacheKey ?? '';
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
    final resolvedNextUrl = nextUrl?.trim() ?? '';
    if (resolvedNextUrl.isNotEmpty) {
      return resolvedNextUrl;
    }

    final directUrl = nextUser?.displayProfileImageUrl;
    if (directUrl != null && directUrl.isNotEmpty) {
      return directUrl;
    }

    final nextProfileImageKey = nextUser?.profileImageCacheKey ?? '';
    if (nextProfileImageKey.isEmpty) return null;

    final cachedUrl = mediaController
        .peekPresignedUrl(nextProfileImageKey)
        ?.trim();
    if (cachedUrl != null && cachedUrl.isNotEmpty) {
      return cachedUrl;
    }

    final previousProfileImageKey = previousUser?.profileImageCacheKey ?? '';
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

    final profileFuture = _profileDataService
        .loadUserData(
          userId: currentUser.id,
          userController: userController,
          mediaController: mediaController,
        )
        .then<ProfileScreenData?>((value) => value)
        .catchError((_) => null);
    final friendsFuture = friendController
        .getAllFriends(userId: currentUser.id)
        .then<List<User>?>((value) => value)
        .catchError((_) => null);

    final results = await Future.wait<Object?>([profileFuture, friendsFuture]);
    final profileData = results[0] as ProfileScreenData?;
    final friends = results[1] as List<User>?;

    if (profileData != null) {
      resolvedUser = profileData.userInfo ?? previousUser;
      resolvedProfileImageUrl = _resolveLoadedProfileImageUrl(
        previousUser: previousUser,
        previousUrl: _profileImageUrl,
        nextUser: resolvedUser,
        nextUrl: profileData.profileImageUrl,
        mediaController: mediaController,
      );
    } else {
      resolvedUser = previousUser;
    }

    if (friends != null) {
      resolvedFriendCount = friends.length;
    } else {
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
            profileImageKey: displayUser?.profileImageCacheKey,
            friendCount: _friendCount,
            onMenuTap: _openProfileSettings,
            coverImageUrl: _coverImageUrl,
            coverImageKey: context.read<UserController>().coverImageUrlKey,
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

/// 프로필 페이지의 탭바의 타입을 정의하는 열거형입니다.
enum _ProfileTab { media, text, comments }
