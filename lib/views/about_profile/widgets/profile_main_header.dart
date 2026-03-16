import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProfileMainHeader extends StatelessWidget {
  /// 프로필 페이지의 메인 헤더를 구성하는 위젯입니다.
  /// 사용자의 닉네임, 프로필 이미지, 친구 수 등을 표시하며, 메뉴 버튼을 포함합니다.
  ///
  /// Parameters:
  /// - [nickname]: 사용자의 닉네임입니다. 닉네임이 없는 경우 '@알 수 없음'으로 표시됩니다.
  /// - [profileImageUrl]: 사용자의 프로필 이미지 URL입니다. 이미지가 없는 경우 기본 아바타 아이콘이 표시됩니다.
  /// - [profileImageKey]: 프로필 이미지의 캐시 키입니다. 이미지가 없는 경우 기본 아바타 아이콘이 표시됩니다.
  /// - [friendCount]: 사용자의 친구 수입니다. '친구 {count}명' 형식으로 표시됩니다.
  /// - [onMenuTap]: 메뉴 버튼이 탭될 때 호출되는 콜백 함수입니다.
  const ProfileMainHeader({
    super.key,
    required this.nickname,
    required this.profileImageUrl,
    required this.profileImageKey,
    required this.friendCount,
    required this.onMenuTap,
  });

  // 사용자의 닉네임입니다. 닉네임이 없는 경우 '@알 수 없음'으로 표시됩니다.
  final String? nickname;

  // 사용자의 프로필 이미지 URL입니다. 이미지가 없는 경우 기본 아바타 아이콘이 표시됩니다.
  final String? profileImageUrl;

  // 프로필 이미지의 캐시 키입니다. 이미지가 없는 경우 기본 아바타 아이콘이 표시됩니다.
  final String? profileImageKey;

  // 사용자의 친구 수입니다. '친구 {count}명' 형식으로 표시됩니다.
  final int friendCount;

  // 메뉴 버튼이 탭될 때 호출되는 콜백 함수입니다.
  final VoidCallback onMenuTap;

  /// 닉네임 레이블을 생성하는 메서드입니다. 닉네임이 없는 경우 '@알 수 없음'으로 표시됩니다.
  String _nicknameLabel(BuildContext context) {
    final resolvedNickname = nickname?.trim() ?? '';
    if (resolvedNickname.isEmpty) {
      return '@${tr('common.unknown', context: context)}';
    }
    return '@$resolvedNickname';
  }

  /// 친구 수 레이블을 생성하는 메서드입니다. '친구 {count}명' 형식으로 표시됩니다.
  String _friendCountLabel(BuildContext context) {
    return tr(
      'profile.main.friends_count',
      context: context,
      namedArgs: {'count': friendCount.toString()},
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: 253.h,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(4.r),
          bottomRight: Radius.circular(4.r),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.34),
                    Colors.black.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
            Positioned(
              top: topPadding + 10.h,
              right: 16.w,
              child: IconButton(
                onPressed: onMenuTap,
                splashRadius: 22.r,
                icon: Icon(
                  Icons.menu_rounded,
                  color: const Color(0xFFF9F9F9),
                  size: 24.sp,
                ),
              ),
            ),
            Positioned(
              left: 24.w,
              right: 24.w,
              bottom: 24.h,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ProfileHeaderAvatar(
                    profileImageUrl: profileImageUrl,
                    profileImageKey: profileImageKey,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      _nicknameLabel(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17.sp,
                        fontFamily: 'Pretendard Variable',
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.40,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    _friendCountLabel(context),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.40,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderAvatar extends StatelessWidget {
  const _ProfileHeaderAvatar({
    required this.profileImageUrl,
    required this.profileImageKey,
  });

  final String? profileImageUrl;
  final String? profileImageKey;

  @override
  Widget build(BuildContext context) {
    final resolvedProfileImageUrl = profileImageUrl?.trim() ?? '';
    final resolvedProfileImageKey = profileImageKey?.trim() ?? '';
    final hasResolvedProfileImage = resolvedProfileImageUrl.isNotEmpty;
    final hasProfileImage = resolvedProfileImageKey.isNotEmpty;

    return ClipOval(
      child: Container(
        width: 45.9.sp,
        height: 45.9.sp,
        color: const Color(0xFF1C1C1C),
        child: hasResolvedProfileImage
            ? CachedNetworkImage(
                imageUrl: resolvedProfileImageUrl,
                cacheKey: hasProfileImage ? resolvedProfileImageKey : null,
                useOldImageOnUrlChange: hasProfileImage,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                fit: BoxFit.cover,
                memCacheWidth: (45.9.sp * 4).round(),
                memCacheHeight: (45.9.sp * 4).round(),
                maxWidthDiskCache: (45.9.sp * 4).round(),
                placeholder: (_, __) =>
                    const ColoredBox(color: Color(0xFF1C1C1C)),
                errorWidget: (_, __, ___) =>
                    const _ProfileHeaderAvatarFallback(),
              )
            : hasProfileImage
            ? const ColoredBox(color: Color(0xFF1C1C1C))
            : const _ProfileHeaderAvatarFallback(),
      ),
    );
  }
}

class _ProfileHeaderAvatarFallback extends StatelessWidget {
  const _ProfileHeaderAvatarFallback();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.person_rounded,
      color: const Color(0xFFCCCCCC),
      size: 24.sp,
    );
  }
}
