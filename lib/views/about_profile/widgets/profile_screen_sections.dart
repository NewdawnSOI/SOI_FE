import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../api/models/user.dart';

class ProfileAccountSection extends StatelessWidget {
  /// 프로필 페이지의 계정 정보 섹션을 구성하는 위젯입니다.
  /// 사용자의 계정 정보(아이디, 이름, 생년월일 등)를 표시하는 카드 형태의 섹션입니다.
  /// 이 섹션은 `ProfileMenuSection` 위젯을 사용하여 제목과 함께 계정 정보를 그룹화합니다.
  /// `User` 모델에서 필요한 정보를 받아와서 각 항목을 `_ProfileAccountCard` 위젯으로 표시합니다.
  ///
  /// Parameters:
  /// - [userInfo]: 사용자 계정 정보를 담고 있는 `User` 모델 객체입니다. 이 객체에서 아이디, 이름, 생년월일 등의 정보를 추출하여 화면에 표시합니다.
  const ProfileAccountSection({super.key, required this.userInfo});

  final User? userInfo;

  @override
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

class ProfileMenuSection extends StatelessWidget {
  const ProfileMenuSection({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
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

class ProfileSectionCard extends StatelessWidget {
  const ProfileSectionCard({super.key, required this.child});

  final Widget child;

  @override
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

class ProfileSectionDivider extends StatelessWidget {
  const ProfileSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: Color(0xFF323232));
  }
}

class _ProfileAccountCard extends StatelessWidget {
  const _ProfileAccountCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
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
