import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import '../common/page_title.dart';

/// 생년월일 입력 페이지 위젯
class BirthDatePage extends StatefulWidget {
  final TextEditingController monthController;
  final TextEditingController dayController;
  final TextEditingController yearController;
  final PageController? pageController;
  final VoidCallback onChanged;
  final VoidCallback onSkip;

  const BirthDatePage({
    super.key,
    required this.monthController,
    required this.dayController,
    required this.yearController,
    required this.pageController,
    required this.onChanged,
    required this.onSkip,
  });

  @override
  State<BirthDatePage> createState() => _BirthDatePageState();
}

class _BirthDatePageState extends State<BirthDatePage> {
  late final FocusNode _monthFocusNode = FocusNode(); // 월 입력 필드에 대한 포커스 노드
  late final FocusNode _dayFocusNode = FocusNode(); // 일 입력 필드에 대한 포커스 노드
  late final FocusNode _yearFocusNode = FocusNode(); // 년 입력 필드에 대한 포커스 노드

  @override
  void dispose() {
    _monthFocusNode.dispose();
    _dayFocusNode.dispose();
    _yearFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 키보드 높이 계산
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final verticalOffset = keyboardHeight > 0 ? -30.0 : 0.0; // 키보드가 올라올 때 위로 이동

    return Stack(
      children: [
        Positioned(
          top: 60.h,
          left: 20.w,
          child: IconButton(
            onPressed: () {
              widget.pageController?.previousPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
        ),
        Positioned(
          top: 60.h,
          right: 20.w,
          child: TextButton(
            onPressed: widget.onSkip,
            child: Text(
              tr('register.skip', context: context),
              style: TextStyle(
                color: const Color(0xFFF8F8F8),
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                fontFamily: 'Pretendard',
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Transform.translate(
            offset: Offset(0, verticalOffset),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PageTitle(title: tr('register.birth_title', context: context)),
                SizedBox(height: 24.h),
                Container(
                  width: 320.w,
                  height: 51,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Color(0xff323232),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.monthController,
                          focusNode: _monthFocusNode, // 월 입력 필드에 포커스 노드 연결
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          textAlign: TextAlign.center,
                          maxLength: 2,
                          cursorColor: Color(0xFFF8F8F8),
                          style: TextStyle(
                            color: Color(0xFFF8F8F8),
                            fontSize: 16.sp,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            counterText: '',
                            hintText: 'MM',
                            hintStyle: TextStyle(
                              color: const Color(0xFFCBCBCB),
                              fontSize: 16,
                              fontFamily: 'Pretendard Variable',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          onChanged: (v) {
                            if (v.length == 2) {
                              _dayFocusNode.requestFocus();
                            }
                            if (v.length <= 2) widget.onChanged();
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                      Text(
                        '/',
                        style: TextStyle(
                          color: Color(0xFFC0C0C0),
                          fontSize: 18,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: widget.dayController,
                          focusNode: _dayFocusNode,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          textAlign: TextAlign.center,
                          maxLength: 2,
                          cursorColor: Color(0xFFF8F8F8),
                          style: TextStyle(
                            color: Color(0xFFF8F8F8),
                            fontSize: 16.sp,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            counterText: '',
                            hintText: 'DD',
                            hintStyle: TextStyle(
                              color: const Color(0xFFCBCBCB),
                              fontSize: 16,
                              fontFamily: 'Pretendard Variable',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          onChanged: (v) {
                            if (v.length == 2) {
                              _yearFocusNode.requestFocus();
                            }
                            if (v.length <= 2) widget.onChanged();
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                      Text(
                        '/',
                        style: TextStyle(
                          color: Color(0xFFC0C0C0),
                          fontSize: 18,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: widget.yearController,
                          focusNode: _yearFocusNode,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          textAlign: TextAlign.center,
                          maxLength: 4,
                          cursorColor: Color(0xFFF8F8F8),
                          style: TextStyle(
                            color: Color(0xFFF8F8F8),
                            fontSize: 16.sp,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            counterText: '',
                            hintText: 'YYYY',
                            hintStyle: TextStyle(
                              color: const Color(0xFFCBCBCB),
                              fontSize: 16,
                              fontFamily: 'Pretendard Variable',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          onChanged: (v) {
                            if (v.length <= 4) widget.onChanged();
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
