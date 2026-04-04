import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../api/controller/friend_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../api/models/user.dart';

class FriendListCard extends StatefulWidget {
  final double scale;

  const FriendListCard({super.key, required this.scale});

  @override
  State<FriendListCard> createState() => _FriendListCardState();
}

class _FriendListCardState extends State<FriendListCard> {
  bool _initialized = false;
  int? _refreshingUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshFriends());
  }

  /// API를 통해 친구 목록 로드 + Provider 캐시 갱신
  Future<void> _refreshFriends() async {
    try {
      // 현재 사용자 ID 가져오기
      final userController = Provider.of<UserController>(
        context,
        listen: false,
      );
      final currentUserId = userController.currentUser?.id;

      if (currentUserId == null) {
        debugPrint('로그인된 사용자가 없습니다.');
        return;
      }

      if (_refreshingUserId == currentUserId) {
        return;
      }
      _refreshingUserId = currentUserId;

      final friendController = Provider.of<FriendController>(
        context,
        listen: false,
      );

      await friendController.getAllFriends(userId: currentUserId);
      if (mounted) {
        _refreshingUserId = null;
      }
    } catch (e) {
      debugPrint('친구 목록 로드 실패: $e');
      if (mounted) {
        _refreshingUserId = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector2<
      UserController,
      FriendController,
      _FriendListCardViewState
    >(
      selector: (_, userController, friendController) {
        final currentUserId = userController.currentUser?.id;
        final hasCurrentUserCache =
            currentUserId != null &&
            friendController.cachedFriendsUserId == currentUserId;
        final friends = hasCurrentUserCache
            ? friendController.cachedFriends
            : const <User>[];
        final showLoading = friendController.isLoading && friends.isEmpty;

        return _FriendListCardViewState(
          currentUserId: currentUserId,
          hasCurrentUserCache: hasCurrentUserCache,
          friends: friends,
          showLoading: showLoading,
          acceptedFriendsRevision: friendController.acceptedFriendsRevision,
        );
      },
      builder: (context, state, _) {
        final currentUserId = state.currentUserId;
        if (!_initialized) {
          _initialized = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _refreshFriends(),
          );
        }

        if (currentUserId != null && !state.hasCurrentUserCache) {
          if (_refreshingUserId != currentUserId) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _refreshFriends(),
            );
          }
        }

        final friends = state.friends;

        return SizedBox(
          width: 354.w,
          child: Card(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            color: const Color(0xff1c1c1c),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: state.showLoading
                ? SizedBox(
                    height: 132.h,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xfff9f9f9),
                      ),
                    ),
                  )
                : friends.isEmpty
                ? SizedBox(
                    height: 132.h,
                    child: Center(
                      child: Text(
                        'friends.empty',
                        style: TextStyle(
                          color: const Color(0xff666666),
                          fontSize: 14.sp,
                        ),
                      ).tr(),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 18.w,
                              vertical: 8.h,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: (44).w,
                                  height: (44).w,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xff323232),
                                  ),
                                  child: ClipOval(
                                    child:
                                        friend.displayProfileImageUrl == null ||
                                            friend
                                                .displayProfileImageUrl!
                                                .isEmpty
                                        ? _buildInitialOrIcon(friend)
                                        : CachedNetworkImage(
                                            imageUrl:
                                                friend.displayProfileImageUrl!,
                                            cacheKey:
                                                friend.profileImageCacheKey,
                                            memCacheWidth: (44 * 3).round(),
                                            maxWidthDiskCache: (44 * 3).round(),
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) =>
                                                _buildInitialOrIcon(friend),
                                            errorWidget: (_, __, ___) =>
                                                _buildInitialOrIcon(friend),
                                          ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        friend.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: const Color(0xFFD9D9D9),
                                          fontSize: 16,
                                          fontFamily: 'Pretendard',
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      Text(
                                        friend.userId,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: const Color(0xFFD9D9D9),
                                          fontSize: 10,
                                          fontFamily: 'Pretendard',
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pushNamed(context, '/friend_list');
                          },
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, size: (18).sp),
                                  SizedBox(width: (8).w),
                                  Text(
                                    'common.more',
                                    style: TextStyle(
                                      color: const Color(0xffd9d9d9),
                                      fontSize: (16).sp,
                                    ),
                                  ).tr(),
                                ],
                              ),
                              SizedBox(height: (12).h),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

Widget _buildInitialOrIcon(User friend) {
  if (friend.name.isNotEmpty) {
    return Center(
      child: Text(
        friend.name[0],
        style: TextStyle(
          color: const Color(0xfff9f9f9),
          fontSize: 15.sp,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
  return Center(
    child: Icon(Icons.person, size: (30).sp, color: const Color(0xff777777)),
  );
}

class _FriendListCardViewState {
  const _FriendListCardViewState({
    required this.currentUserId,
    required this.hasCurrentUserCache,
    required this.friends,
    required this.showLoading,
    required this.acceptedFriendsRevision,
  });

  final int? currentUserId;
  final bool hasCurrentUserCache;
  final List<User> friends;
  final bool showLoading;
  final int acceptedFriendsRevision;

  @override
  bool operator ==(Object other) {
    return other is _FriendListCardViewState &&
        other.currentUserId == currentUserId &&
        other.hasCurrentUserCache == hasCurrentUserCache &&
        identical(other.friends, friends) &&
        other.showLoading == showLoading &&
        other.acceptedFriendsRevision == acceptedFriendsRevision;
  }

  @override
  int get hashCode => Object.hash(
    currentUserId,
    hasCurrentUserCache,
    friends,
    showLoading,
    acceptedFriendsRevision,
  );
}
