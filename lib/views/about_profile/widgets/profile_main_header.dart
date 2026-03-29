import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../common_widget/user/current_user_image_builder.dart';

/// 프로필 페이지 최상단 헤더 위젯입니다.
///
/// 커버 이미지, 프로필 이미지, 닉네임, 친구 수, 뒤로가기 버튼, 메뉴 버튼을 포함합니다.
///
/// fields:
/// - [observedUserId]: 헤더가 표현하는 사용자의 ID입니다. UserController에서 이미지 선택 시 범위를 좁히는 데 사용됩니다.
/// - [nickname]: 사용자의 닉네임입니다. 닉네임이 없는 경우 '@알 수 없음'으로 표시됩니다.
/// - [profileImageUrl]: 사용자의 프로필 이미지 URL입니다. 이미지가 없는 경우 기본 아바타 아이콘이 표시됩니다.
/// - [profileImageKey]: 프로필 이미지의 캐시 키입니다. 이미지가 없는 경우 기본 아바타 아이콘이 표시됩니다.
/// - [friendCount]: 사용자의 친구 수입니다. '친구 {count}명' 형식으로 표시됩니다.
/// - [onBackTap]: 좌측 뒤로가기 버튼이 탭될 때 호출되는 콜백 함수입니다.
/// - [onMenuTap]: 우측 메뉴 버튼이 탭될 때 호출되는 콜백 함수입니다.
/// - [onProfileImageTap]: 프로필 이미지가 탭될 때 호출되는 콜백 함수입니다.
/// - [coverImageUrl]: 커버 이미지 URL입니다. 헤더 배경으로 표시됩니다.
/// - [coverImageKey]: 커버 이미지의 캐시 키입니다.
/// - [onCoverImageTap]
///   - 커버 이미지 영역이 탭될 때 호출되는 콜백 함수입니다.
///   - null이면 탭 불가 (profile_page에서는 null, profile_setting_screen에서는 핸들러 전달).
class ProfileMainHeader extends StatelessWidget {
  const ProfileMainHeader({
    super.key,
    required this.observedUserId,
    required this.nickname,
    required this.profileImageUrl,
    required this.profileImageKey,
    required this.friendCount,
    this.onBackTap,
    this.onMenuTap,
    this.onProfileImageTap,
    this.coverImageUrl,
    this.coverImageKey,
    this.onCoverImageTap,
  });

  /// 헤더가 표현하는 사용자를 식별해 현재 사용자 selector 범위를 좁힙니다.
  final int? observedUserId;

  /// 사용자의 닉네임입니다. 닉네임이 없는 경우 '@알 수 없음'으로 표시됩니다.
  final String? nickname;

  /// 사용자의 프로필 이미지 URL입니다. 이미지가 없는 경우 기본 아바타 아이콘이 표시됩니다.
  final String? profileImageUrl;

  /// 프로필 이미지의 캐시 키입니다. 이미지가 없는 경우 기본 아바타 아이콘이 표시됩니다.
  final String? profileImageKey;

  /// 사용자의 친구 수입니다. '친구 {count}명' 형식으로 표시됩니다.
  final int friendCount;

  /// 좌측 뒤로가기 버튼이 탭될 때 호출되는 콜백 함수입니다.
  final VoidCallback? onBackTap;

  /// 우측 메뉴 버튼이 탭될 때 호출되는 콜백 함수입니다.
  final VoidCallback? onMenuTap;

  /// 프로필 이미지가 탭될 때 호출되는 콜백 함수입니다.
  final VoidCallback? onProfileImageTap;

  /// 커버 이미지 URL입니다. 헤더 배경으로 표시됩니다.
  final String? coverImageUrl;

  /// 커버 이미지의 캐시 키입니다.
  final String? coverImageKey;

  /// 커버 이미지 영역이 탭될 때 호출되는 콜백 함수입니다.
  /// null이면 탭 불가 (profile_page에서는 null, profile_setting_screen에서는 핸들러 전달).
  final VoidCallback? onCoverImageTap;

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

  /// 헤더의 배경 탭과 전경 액션이 서로 가로막지 않도록 레이어를 조립합니다.
  /// 화면별로 필요한 상단 액션만 띄우고, 나머지 레이아웃은 동일하게 유지합니다.
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: 252.h,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(4.r),
          bottomRight: Radius.circular(4.r),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 커버 이미지 배경 (탭 가능)
            GestureDetector(
              onTap: onCoverImageTap,
              behavior: HitTestBehavior.opaque,
              // 커버 이미지 자체는 UserController에 부분 구독해 변경만 반영하도록 별도 위젯으로 분리합니다.
              child: _ProfileHeaderCoverImage(
                observedUserId: observedUserId,
                fallbackImageUrl: coverImageUrl,
                fallbackImageKey: coverImageKey,
              ),
            ),
            IgnorePointer(
              child: DecoratedBox(
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
            ),
            if (onBackTap != null)
              Positioned(
                top: topPadding + 10.h,
                left: 8.w,
                child: IconButton(
                  onPressed: onBackTap,
                  splashRadius: 22.r,
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: const Color(0xFFF9F9F9),
                    size: 20.sp,
                  ),
                ),
              ),
            if (onMenuTap != null)
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
                  // 프로필 이미지 아바타 (탭 가능)
                  _ProfileHeaderAvatar(
                    observedUserId: observedUserId,
                    profileImageUrl: profileImageUrl,
                    profileImageKey: profileImageKey,
                    onTap: onProfileImageTap,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: IgnorePointer(
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
                  ),
                  SizedBox(width: 12.w),
                  IgnorePointer(
                    child: Text(
                      _friendCountLabel(context),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontFamily: 'Pretendard Variable',
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.40,
                      ),
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

/// 헤더 배경 커버 이미지만 UserController에 부분 구독해 나머지 레이아웃 재빌드를 막습니다.
class _ProfileHeaderCoverImage extends StatelessWidget {
  const _ProfileHeaderCoverImage({
    required this.observedUserId,
    required this.fallbackImageUrl,
    required this.fallbackImageKey,
  });

  final int? observedUserId;
  final String? fallbackImageUrl;
  final String? fallbackImageKey;

  @override
  Widget build(BuildContext context) {
    return CurrentUserImageBuilder(
      imageKind: CurrentUserImageKind.cover,
      targetUserId: observedUserId,
      fallbackImageUrl: fallbackImageUrl,
      fallbackImageKey: fallbackImageKey,
      builder: (context, imageUrl, cacheKey) {
        final resolvedCoverImageUrl = imageUrl?.trim() ?? '';
        if (resolvedCoverImageUrl.isEmpty) {
          return const ColoredBox(color: Colors.black);
        }

        return CachedNetworkImage(
          imageUrl: resolvedCoverImageUrl,
          cacheKey: cacheKey,
          fit: BoxFit.cover,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: (_, __) => const ColoredBox(color: Colors.black),
          errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
        );
      },
    );
  }
}

/// 헤더 아바타만 UserController에 부분 구독해 프로필 이미지 변경만 따로 반영합니다.
class _ProfileHeaderAvatar extends StatelessWidget {
  ///
  /// 프로필 이미지를 표시하는 위젯입니다.
  ///
  /// 이미지가 없는 경우 기본 아바타 아이콘이 표시됩니다.
  ///
  /// fields:
  /// - [profileImageUrl]: 프로필 이미지의 URL입니다. 이미지가 없는 경우 기본 아바타 아이콘이 표시됩니다.
  /// - [profileImageKey]: 프로필 이미지의 캐시 키입니다. 이미지가 없는 경우 기본 아바타 아이콘이 표시됩니다.
  /// - [onTap]: 프로필 이미지가 탭될 때 호출되는 콜백 함수입니다.
  ///

  const _ProfileHeaderAvatar({
    required this.observedUserId,
    required this.profileImageUrl,
    required this.profileImageKey,
    this.onTap,
  });

  final int? observedUserId;
  final String? profileImageUrl;
  final String? profileImageKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatarSize = 45.9.sp;

    // CurrentUserImageBuilder를 사용해 프로필 이미지 URL과 캐시 키를 UserController에서 선택적으로 구독합니다.
    return CurrentUserImageBuilder(
      imageKind: CurrentUserImageKind.profile,
      targetUserId: observedUserId,
      fallbackImageUrl: profileImageUrl,
      fallbackImageKey: profileImageKey,
      builder: (context, imageUrl, cacheKey) {
        final resolvedProfileImageUrl = imageUrl?.trim() ?? '';
        final hasResolvedProfileImage = resolvedProfileImageUrl.isNotEmpty;
        final hasProfileImage = cacheKey?.trim().isNotEmpty ?? false;

        return GestureDetector(
          onTap: onTap,
          child: ClipOval(
            child: Container(
              width: avatarSize,
              height: avatarSize,
              color: const Color(0xFF1C1C1C),
              child: hasResolvedProfileImage
                  ? CachedNetworkImage(
                      imageUrl: resolvedProfileImageUrl,
                      cacheKey: hasProfileImage ? cacheKey : null,
                      useOldImageOnUrlChange: hasProfileImage,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      fit: BoxFit.cover,
                      memCacheWidth: (avatarSize * 2).round(),
                      maxWidthDiskCache: (avatarSize * 2).round(),
                      placeholder: (_, __) =>
                          const ColoredBox(color: Color(0xFF1C1C1C)),
                      errorWidget: (_, __, ___) =>
                          const _ProfileHeaderAvatarFallback(),
                    )
                  : hasProfileImage
                  ? const ColoredBox(color: Color(0xFF1C1C1C))
                  : const _ProfileHeaderAvatarFallback(),
            ),
          ),
        );
      },
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
