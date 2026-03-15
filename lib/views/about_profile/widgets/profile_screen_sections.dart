import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../../api/models/user.dart';

/// 이 위젯은 맨 위 프로필 사진 부분만 보여줘요.
/// 사진, 연필 버튼, 로딩 표시를 한곳에 모아놨어요.
class ProfileAvatarHeader extends StatelessWidget {
  const ProfileAvatarHeader({
    super.key,
    required this.profileImageUrl,
    required this.isUploadingProfile,
    required this.profileImageLoadFailed,
    required this.profileImageRetryCount,
    required this.onEditTap,
    required this.onImageRetryRequested,
    required this.onImageLoadFailed,
  });

  final String? profileImageUrl;
  final bool isUploadingProfile;
  final bool profileImageLoadFailed;
  final int profileImageRetryCount;
  final VoidCallback onEditTap;
  final VoidCallback onImageRetryRequested;
  final VoidCallback onImageLoadFailed;

  @override
  /// 이 메서드는 프로필 사진 머리글을 화면에 그려줘요.
  /// 탭하면 사진을 바꾸는 버튼도 같이 보여줘요.
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: onEditTap,
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFD9D9D9),
                ),
                child: Stack(
                  children: [
                    _buildProfileImage(),
                    if (isUploadingProfile)
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0.w,
              bottom: 4.h,
              child: GestureDetector(
                onTap: onEditTap,
                child: Image.asset(
                  'assets/pencil.png',
                  width: 25.41.w,
                  height: 25.41.h,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 이 메서드는 사진을 보여줄지 기본 아이콘을 보여줄지 정해요.
  /// 사진이 안 보이면 다시 시도하거나 대신 사람 그림을 보여줘요.
  Widget _buildProfileImage() {
    final hasProfileImage =
        profileImageUrl != null &&
        profileImageUrl!.isNotEmpty &&
        !profileImageLoadFailed;

    if (!hasProfileImage) {
      return const Center(child: _ProfileDefaultIcon());
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: profileImageUrl!,
        memCacheWidth: (96 * 4).round(),
        memCacheHeight: (96 * 4).round(),
        maxWidthDiskCache: (96 * 4).round(),
        fit: BoxFit.cover,
        width: 96,
        height: 96,
        placeholder: (context, url) => const _ProfileImagePlaceholder(),
        errorWidget: (context, url, error) {
          if (profileImageRetryCount < 2) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              CachedNetworkImage.evictFromCache(profileImageUrl!);
              onImageRetryRequested();
            });
            return const _ProfileImagePlaceholder();
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            onImageLoadFailed();
          });
          return const _ProfileDefaultIcon();
        },
      ),
    );
  }
}

/// 이 위젯은 아이디와 이름 같은 계정 정보를 보여줘요.
/// 여러 칸을 한 묶음으로 만들어 보기 쉽게 정리해줘요.
class ProfileAccountSection extends StatelessWidget {
  const ProfileAccountSection({super.key, required this.userInfo});

  final User? userInfo;

  @override
  /// 이 메서드는 계정 정보 칸들을 차례로 그려줘요.
  /// 사용자 정보가 있으면 각 칸에 맞는 글자를 넣어줘요.
  Widget build(BuildContext context) {
    return ProfileMenuSection(
      title: tr('profile.section.account', context: context),
      child: Column(
        children: [
          _ProfileAccountCard(
            label: tr('profile.account.id_label', context: context),
            value: userInfo?.userId ?? '',
          ),
          SizedBox(height: 7.h),
          _ProfileAccountCard(
            label: tr('profile.account.name_label', context: context),
            value: userInfo?.name ?? '',
          ),
          SizedBox(height: 7.h),
          _ProfileAccountCard(
            label: tr('profile.account.birth_label', context: context),
            value: userInfo?.birthDate ?? '',
          ),
        ],
      ),
    );
  }
}

/// 이 위젯은 섹션 제목과 내용물을 한 묶음으로 감싸줘요.
/// 같은 모양의 구역을 여러 곳에서 쉽게 쓰게 해줘요.
class ProfileMenuSection extends StatelessWidget {
  const ProfileMenuSection({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  /// 이 메서드는 제목과 본문을 위아래로 배치해 보여줘요.
  /// 그래서 긴 설정 화면도 구역별로 알아보기 쉬워져요.
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 16.w),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w700,
                fontSize: 20.sp,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        child,
      ],
    );
  }
}

/// 이 위젯은 어두운 배경 카드 상자 하나를 만들어줘요.
/// 안쪽에 넣은 내용을 같은 모양으로 감싸 보여줘요.
class ProfileSectionCard extends StatelessWidget {
  const ProfileSectionCard({super.key, required this.child});

  final Widget child;

  @override
  /// 이 메서드는 카드 모양 상자를 화면에 그려줘요.
  /// 안에 들어온 내용을 예쁘게 담는 역할만 해요.
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

/// 이 위젯은 설정 목록의 한 줄을 보여줘요.
/// 제목과 값, 그리고 눌렀을 때 할 일을 함께 담아요.
///
/// Parameters:
/// - [title]: 설정 항목의 제목을 나타내는 문자열입니다.
/// - [value]: 설정 항목의 현재 값을 나타내는 문자열입니다. null일 수 있으며, 이 경우 값이 표시되지 않습니다.
/// - [isRed]: 설정 항목의 텍스트 색상을 빨간색으로 표시할지 여부를 나타내는 불리언 값입니다. 기본값은 false입니다.
/// - [onTap]: 설정 항목이 탭될 때 실행되는 콜백 함수입니다. null일 수 있으며, 이 경우 탭 이벤트가 처리되지 않습니다.
class ProfileMenuItem extends StatelessWidget {
  const ProfileMenuItem({
    super.key,
    required this.title,
    this.value,
    this.isRed = false,
    this.onTap,
  });

  final String title;
  final String? value;
  final bool isRed;
  final VoidCallback? onTap;

  @override
  /// 이 메서드는 설정 한 줄을 화면에 그려줘요.
  /// 값이 있으면 오른쪽에 보여주고, 누르면 약속된 일을 해요.
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w400,
                  fontSize: 16.sp,
                  color: isRed
                      ? const Color(0xFFFF0000)
                      : const Color(0xFFF9F9F9),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (value != null)
              Flexible(
                child: Text(
                  value!,
                  style: TextStyle(
                    fontFamily: 'Pretendard Variable',
                    fontWeight: FontWeight.w400,
                    fontSize: 16.sp,
                    color: const Color(0xFFF9F9F9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 이 위젯은 줄과 줄 사이에 얇은 선을 그어줘요.
/// 항목들이 서로 붙어 보이지 않게 나눠줘요.
class ProfileSectionDivider extends StatelessWidget {
  const ProfileSectionDivider({super.key});

  @override
  /// 이 메서드는 아주 얇은 구분선을 화면에 그려줘요.
  /// 목록이 한눈에 더 잘 보이도록 도와줘요.
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: Color(0xFF323232));
  }
}

/// 이 위젯은 계정 정보를 보여주는 작은 카드 하나예요.
/// 이름표와 내용을 함께 넣어 한 줄씩 읽기 쉽게 해줘요.
class _ProfileAccountCard extends StatelessWidget {
  const _ProfileAccountCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  /// 이 메서드는 작은 정보 카드 한 칸을 그려줘요.
  /// 왼쪽 위엔 이름표를, 아래엔 실제 내용을 보여줘요.
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.symmetric(horizontal: 19.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard Variable',
              fontWeight: FontWeight.w400,
              fontSize: 13.sp,
              color: const Color(0xFFCCCCCC),
            ),
          ),
          SizedBox(height: 7.h),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w400,
                  fontSize: 16.sp,
                  color: const Color(0xFFF9F9F9),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 이 위젯은 사진이 없을 때 대신 보여주는 사람 그림이에요.
/// 빈 자리를 어색하지 않게 채워주는 기본 표시예요.
class _ProfileDefaultIcon extends StatelessWidget {
  const _ProfileDefaultIcon();

  @override
  /// 이 메서드는 기본 사람 아이콘 하나를 그려줘요.
  /// 사진이 준비되지 않았을 때 대신 화면에 보여줘요.
  Widget build(BuildContext context) {
    return Icon(Icons.person, size: 76.sp, color: Colors.white);
  }
}

/// 이 위젯은 사진이 로딩 중일 때 반짝이며 기다리게 해줘요.
/// 아직 사진이 안 왔다는 것을 부드럽게 알려줘요.
class _ProfileImagePlaceholder extends StatelessWidget {
  const _ProfileImagePlaceholder();

  @override
  /// 이 메서드는 반짝이는 동그란 빈칸을 그려줘요.
  /// 사진이 오는 동안 잠깐 대신 보여주는 자리표시자예요.
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2A2A2A),
      highlightColor: const Color(0xFF3A3A3A),
      child: Container(
        width: 96,
        height: 96,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF2A2A2A),
        ),
      ),
    );
  }
}
