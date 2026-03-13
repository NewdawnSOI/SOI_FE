import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 이 바닥 창은 정말 할 건지 한 번 더 물어봐요.
/// 실수로 큰 버튼을 눌렀을 때 다시 생각하게 도와줘요.
class ProfileActionConfirmationSheet extends StatelessWidget {
  const ProfileActionConfirmationSheet({
    super.key,
    required this.title,
    required this.confirmLabel,
    required this.onConfirm,
    this.description,
  });

  final String title;
  final String? description;
  final String confirmLabel;
  final Future<void> Function() onConfirm;

  @override
  /// 이 메서드는 확인 창 모양을 화면에 그려줘요.
  /// 제목, 설명, 확인 버튼, 취소 버튼을 차례로 보여줘요.
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
