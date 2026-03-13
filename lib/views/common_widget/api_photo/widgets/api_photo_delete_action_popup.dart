import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ApiPhotoDeleteActionPopup extends StatelessWidget {
  const ApiPhotoDeleteActionPopup({
    super.key,
    required this.position,
    required this.imageWidth,
    required this.onDeleteTap,
  });

  final Offset position;
  final double imageWidth;
  final VoidCallback onDeleteTap;

  @override
  Widget build(BuildContext context) {
    const popupWidth = 180.0;
    var left = position.dx;
    final top = position.dy + 20;

    if (left + popupWidth > imageWidth) {
      left = imageWidth - popupWidth - 8;
    }

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 173.w,
          height: 45.h,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onDeleteTap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(width: 14.w),
                Padding(
                  padding: EdgeInsets.only(bottom: 1.h),
                  child: Image.asset(
                    'assets/trash_red.png',
                    width: 12.2.w,
                    height: 13.6.w,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  'comments.delete',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFFF0000),
                    fontFamily: 'Pretendard',
                  ),
                ).tr(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
