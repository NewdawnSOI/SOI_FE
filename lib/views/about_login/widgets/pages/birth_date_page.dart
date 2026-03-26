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

/// 생년월일 입력 3개 필드의 자동 포커스 이동과 키보드 표시 상태를 관리한다.
class _BirthDatePageState extends State<BirthDatePage> {
  late final FocusNode _monthFocusNode = FocusNode(); // 월 입력 필드에 대한 포커스 노드
  late final FocusNode _dayFocusNode = FocusNode(); // 일 입력 필드에 대한 포커스 노드
  late final FocusNode _yearFocusNode = FocusNode(); // 년 입력 필드에 대한 포커스 노드

  /// 날짜 세그먼트가 가득 찼을 때 다음 입력 칸으로 포커스를 넘기고 키보드를 유지한다.
  /// - [WidgetsBinding.instance.addPostFrameCallback]를 사용하여 프레임이 렌더링된 후에 포커스 이동을 요청한다.
  ///   - 이렇게 하면, 포커스 이동이 UI 업데이트와 충돌하지 않고 자연스럽게 이루어진다.
  ///
  /// parameters:
  /// - [nextFocusNode]: 포커스를 이동할 다음 입력 필드의 FocusNode
  ///   - 포커스 이동 후에도 키보드가 유지되도록 SystemChannels.textInput.invokeMethod('TextInput.show')를 호출한다.
  void _moveFocusTo(FocusNode nextFocusNode) {
    // 프레임이 렌더링된 후에 포커스 이동을 요청하여 UI 업데이트와 충돌하지 않도록 한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !nextFocusNode.canRequestFocus) {
        return;
      }

      // 다음 입력 필드로 포커스 이동
      FocusScope.of(context).requestFocus(nextFocusNode);

      // 포커스 이동 후에도 키보드가 유지되도록 명시적으로 키보드 표시를 요청한다.
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  /// 각 날짜 입력값을 부모에 알리고, 자릿수가 채워지면 다음 필드로 이동시킨다.
  void _handleDateInputChanged({
    required String value,
    required int maxLength,
    FocusNode? nextFocusNode,
  }) {
    if (value.length > maxLength) {
      return;
    }

    widget.onChanged();

    if (value.length == maxLength && nextFocusNode != null) {
      _moveFocusTo(nextFocusNode);
    }
  }

  @override
  void dispose() {
    _monthFocusNode.dispose();
    _dayFocusNode.dispose();
    _yearFocusNode.dispose();
    super.dispose();
  }

  /// 생년월일 입력창을 키보드 높이에 맞춰 배치하고 현재 포커스 상태를 반영한다.
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
                          onChanged: (value) => _handleDateInputChanged(
                            value: value,
                            maxLength: 2,
                            nextFocusNode: _dayFocusNode,
                          ),
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
                          onChanged: (value) => _handleDateInputChanged(
                            value: value,
                            maxLength: 2,
                            nextFocusNode: _yearFocusNode,
                          ),
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
                          onChanged: (value) => _handleDateInputChanged(
                            value: value,
                            maxLength: 4,
                          ),
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
