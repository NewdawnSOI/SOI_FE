import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProfileActionConfirmationSheet extends StatelessWidget {
  /// 프로필 페이지에서 사용되는 액션 확인 시트를 구성하는 위젯입니다.
  /// 사용자가 프로필에서 특정 액션을 수행하기 전에 확인을 요청하는 모달 시트입니다.
  ///
  /// Parameters:
  /// - [title]: 확인 시트의 제목입니다. 사용자에게 수행하려는 액션에 대한 명확한 설명을 제공합니다.
  /// - [description]: 확인 시트의 추가 설명입니다. 액션의 결과나 중요성을 강조하는 데 사용됩니다. 이 필드는 선택적입니다.
  /// - [confirmLabel]: 확인 버튼에 표시될 텍스트입니다. 사용자가 액션을 수행하기 전에 명확한 행동 지침을 제공합니다.
  /// - [onConfirm]: 사용자가 확인 버튼을 탭했을 때 호출되는 콜백 함수입니다. 이 함수는 액션을 수행하는 로직을 포함해야 하며, 비동기 작업을 지원합니다.
  const ProfileActionConfirmationSheet({
    super.key,
    required this.title,
    required this.confirmLabel,
    required this.onConfirm,
    this.description,
  });

  /// 확인 시트 상단 제목입니다.
  final String title;

  /// 확인 시트의 보조 설명(선택)입니다.
  final String? description;

  /// 확인 버튼에 표시되는 텍스트입니다.
  final String confirmLabel;

  /// 확인 버튼 탭 시 실행되는 비동기 콜백입니다.
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF323232),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: description == null ? 34.h : 26.h),

          // 확인 시트의 제목을 표시하는 텍스트 위젯입니다.
          // 사용자에게 수행하려는 액션에 대한 명확한 설명을 제공합니다.
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Pretendard Variable',
              fontWeight: FontWeight.w700,
              fontSize: 19.8.sp,
              color: const Color(0xFFF9F9F9),
            ),
            textAlign: TextAlign.center,
          ),
          if (description != null) ...[
            SizedBox(height: 12.h),

            // 확인 시트의 추가 설명을 표시하는 텍스트 위젯입니다.
            // 액션의 결과나 중요성을 강조하는 데 사용됩니다. 이 필드는 선택적입니다.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Text(
                description!,
                style: TextStyle(
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w500,
                  fontSize: 15.8.sp,
                  height: 1.6,
                  color: const Color(0xFFF9F9F9),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          SizedBox(height: 28.h),

          // 확인 버튼입니다.
          // 사용자가 액션을 수행하기 전에 명확한 행동 지침을 제공합니다.
          SizedBox(
            width: 344.w,
            height: 38.h,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF9F9F9),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(19),
                ),
              ),
              child: Text(
                confirmLabel,
                style: TextStyle(
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w600,
                  fontSize: 17.8.sp,
                ),
              ),
            ),
          ),
          SizedBox(height: 14.h),

          // 취소 버튼입니다.
          // 사용자가 액션을 취소할 수 있도록 명확한 옵션을 제공합니다.
          SizedBox(
            width: 344.w,
            height: 38.h,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF323232),
                elevation: 0,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(19),
                ),
              ),
              child: Text(
                tr('common.cancel', context: context),
                style: TextStyle(
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w500,
                  fontSize: 17.8.sp,
                  color: const Color(0xFFCCCCCC),
                ),
              ),
            ),
          ),
          SizedBox(height: 16.5.h),
        ],
      ),
    );
  }
}
