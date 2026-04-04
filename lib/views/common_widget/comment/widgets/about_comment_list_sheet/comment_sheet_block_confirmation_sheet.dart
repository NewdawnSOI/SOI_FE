import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 댓글 시트에서 특정 댓글을 차단하기 전에 사용자에게 확인을 요청하는 시트를 담당하는 위젯입니다.
/// - 사용자가 댓글을 차단하기로 결정했는지 여부를 반환하는 bottom sheet로 표시됩니다.
/// - "예" 버튼을 누르면 true, "아니오" 버튼을 누르면 false가 반환되고, 시트 외부를 탭하거나 뒤로 가기 버튼을 누르면 null이 반환됩니다.
///
/// fields:
/// - 없음 (이 위젯은 단순히 UI를 표시하는 역할만 하며, 필요한 데이터는 show 메서드의 인자로 전달받거나 콜백을 통해 처리됩니다.)
class CommentSheetBlockConfirmationSheet extends StatelessWidget {
  const CommentSheetBlockConfirmationSheet({super.key});

  /// 차단 확인 시트를 bottom sheet로 띄우고 사용자의 선택을 반환합니다.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const CommentSheetBlockConfirmationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xff323232),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 17.sp),
          Text(
            tr('common.block_confirm'),
            style: TextStyle(
              color: const Color(0xFFF8F8F8),
              fontSize: 19.78.sp,
              fontFamily: 'Pretendard Variable',
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12.sp),
          SizedBox(
            height: 38.sp,
            width: 344.sp,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xfff5f5f5),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.2.r),
                ),
              ),
              child: Text(
                tr('common.yes'),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 17.8.sp,
                ),
              ),
            ),
          ),
          SizedBox(height: 13.sp),
          SizedBox(
            height: 38.sp,
            width: 344.sp,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF323232),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.2.r),
                ),
              ),
              child: Text(
                tr('common.no'),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                  fontSize: 17.8.sp,
                ),
              ),
            ),
          ),
          SizedBox(height: 30.sp),
        ],
      ),
    );
  }
}
