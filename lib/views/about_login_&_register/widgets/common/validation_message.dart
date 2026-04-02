import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 검증 결과 메시지를 표시하는 위젯 (성공/에러)
class ValidationMessage extends StatelessWidget {
  final String message;
  final bool isSuccess;
  final double? fontSize;
  final double? iconSize;
  final String? successIconPath;
  final String? errorIconPath;

  const ValidationMessage({
    super.key,
    required this.message,
    required this.isSuccess,
    this.fontSize = 12,
    this.iconSize = 15,
    this.successIconPath = 'assets/check.png',
    this.errorIconPath = 'assets/error.png',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            isSuccess ? successIconPath! : errorIconPath!,
            width: iconSize!.w,
            height: iconSize!.h,
          ),
          SizedBox(width: 7.w),
          Text(
            message,
            style: TextStyle(
              color: const Color(0xFFf8f8f8),
              fontSize: fontSize,
              fontFamily: 'Pretendard Variable',
              fontWeight: FontWeight.w500,
              letterSpacing: -0.40,
            ),
          ),
        ],
      ),
    );
  }
}
