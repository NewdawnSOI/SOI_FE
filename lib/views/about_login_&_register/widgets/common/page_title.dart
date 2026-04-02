import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PageTitle extends StatelessWidget {
  final String title;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextAlign? textAlign;

  ///
  /// 각 페이지에서 사용되는 공통 제목 위젯
  ///
  /// fields:
  /// - [title]: 제목 텍스트
  /// - [fontSize]: 글자 크기 (기본값: 18)
  /// - [fontWeight]: 글자 두께 (기본값: FontWeight.w600)
  /// - [color]: 글자 색상 (기본값: Color(0xFFF8F8F8))
  /// - [textAlign]: 텍스트 정렬 (기본값: TextAlign.center)
  ///

  const PageTitle({
    super.key,
    required this.title,
    this.fontSize = 18,
    this.fontWeight = FontWeight.w600,
    this.color = const Color(0xFFF8F8F8),
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: fontSize!.sp,
        fontFamily: GoogleFonts.inter().fontFamily,
        fontWeight: fontWeight,
      ),
      textAlign: textAlign,
    );
  }
}
