import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../api/controller/friend_controller.dart';
import '../../api/controller/media_controller.dart';
import '../../api/controller/user_controller.dart';
import '../../api/models/user.dart';
import '../../app/app_constants.dart';
import 'services/profile_data_service.dart';
import 'widgets/profile_main_header.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfilePageData();
    });
  }

  void _primeInitialHeaderState() {
    final currentUser = context.read<UserController>().currentUser;
    final friendController = context.read<FriendController>();
    if (currentUser == null) return;

    _userInfo = currentUser;
    if (friendController.cachedFriendsUserId == currentUser.id) {
      _friendCount = friendController.cachedFriends.length;
    }
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

    User? resolvedUser = currentUser;
    String? resolvedProfileImageUrl;
    var resolvedFriendCount = 0;

    try {
      final profileData = await _profileDataService.loadUserData(
        userId: currentUser.id,
        userController: userController,
        mediaController: mediaController,
      );
      resolvedUser = profileData.userInfo ?? currentUser;
      resolvedProfileImageUrl = profileData.profileImageUrl;
    } catch (_) {
      resolvedUser = currentUser;
    }

    try {
      final friends = await friendController.getAllFriends(
        userId: currentUser.id,
      );
      resolvedFriendCount = friends.length;
    } catch (_) {
      resolvedFriendCount = 0;
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // 프로필 페이지의 헤더를 구성하는 ProfileMainHeader 위젯입니다.
          ProfileMainHeader(
            nickname: _userInfo?.userId,
            profileImageUrl: _profileImageUrl,
            friendCount: _friendCount,
            onMenuTap: _openProfileSettings,
          ),
          // 프로필 페이지의 탭 바를 구성하는 _ProfileTabBar 위젯입니다.
          // 탭 바는 미디어, 텍스트, 댓글 탭을 표시하고, 선택된 탭을 강조합니다.
          _ProfileTabBar(selectedTab: _selectedTab, onTabSelected: _selectTab),
          Expanded(
            child: IndexedStack(
              index: _selectedTab.index,
              children: const [
                ColoredBox(color: Colors.black),
                ColoredBox(color: Colors.black),
                ColoredBox(color: Colors.black),
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
