import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProfileMainHeader extends StatelessWidget {
  const ProfileMainHeader({
    super.key,
    required this.nickname,
    required this.profileImageUrl,
    required this.friendCount,
    required this.onMenuTap,
  });

  final String? nickname;
  final String? profileImageUrl;
  final int friendCount;
  final VoidCallback onMenuTap;

  String _nicknameLabel(BuildContext context) {
    final resolvedNickname = nickname?.trim() ?? '';
    if (resolvedNickname.isEmpty) {
      return '@${tr('common.unknown', context: context)}';
    }
    return '@$resolvedNickname';
  }

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
                  _ProfileHeaderAvatar(profileImageUrl: profileImageUrl),
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
  const _ProfileHeaderAvatar({required this.profileImageUrl});

  final String? profileImageUrl;

  @override
  Widget build(BuildContext context) {
    final hasProfileImage =
        profileImageUrl != null && profileImageUrl!.trim().isNotEmpty;

    return ClipOval(
      child: Container(
        width: 45.9.sp,
        height: 45.9.sp,
        color: const Color(0xFF1C1C1C),
        child: hasProfileImage
            ? CachedNetworkImage(
                imageUrl: profileImageUrl!,
                fit: BoxFit.cover,
                memCacheWidth: (45.9.sp * 4).round(),
                maxWidthDiskCache: (45.9.sp * 4).round(),
                placeholder: (_, __) =>
                    const ColoredBox(color: Color(0xFF1C1C1C)),
                errorWidget: (_, __, ___) =>
                    const _ProfileHeaderAvatarFallback(),
              )
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
