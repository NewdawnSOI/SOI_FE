import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import '../common/page_title.dart';
import '../common/custom_text_field.dart';

/// 전화번호 입력 페이지 위젯
///
/// 회원가입과 로그인 화면이 같은 전화번호 입력 레이아웃을 공유할 수 있게
/// 문구와 뒤로 가기 동작만 외부에서 주입받습니다.
class PhoneInputPage extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final String selectedCountryCode;
  final ValueChanged<String> onCountryChanged;
  final int? maxLength;
  final String? errorText;
  final String? titleText;
  final String? hintText;
  final VoidCallback? onBackPressed;
  final PageController? pageController;

  const PhoneInputPage({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.selectedCountryCode,
    required this.onCountryChanged,
    this.maxLength,
    this.errorText,
    this.titleText,
    this.hintText,
    this.onBackPressed,
    required this.pageController,
  });

  /// 전화번호 입력 영역을 작은 화면과 키보드 상태에서도 스크롤 가능하게 배치한다.
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final safeBottom = mediaQuery.padding.bottom;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = 84.h;
          final bottomPadding = keyboardHeight > 0
              ? keyboardHeight + 32.h
              : 120.h + safeBottom;
          final minContentHeight = math
              .max(0.0, constraints.maxHeight - topPadding - bottomPadding)
              .toDouble();

          return Stack(
            children: [
              // 뒤로 가기 버튼을 화면 상단 왼쪽에 고정한다.
              Positioned(
                top: 8.h,
                left: 8.w,
                child: IconButton(
                  onPressed: () {
                    final handleBack = onBackPressed;
                    if (handleBack != null) {
                      handleBack();
                      return;
                    }

                    pageController?.previousPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  key: const ValueKey('auth_phone_back_button'),
                  icon: Icon(Icons.arrow_back_ios, color: Colors.white),
                ),
              ),
              //
              SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  20.w,
                  topPadding,
                  20.w,
                  bottomPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minContentHeight),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // "SOI 접속을 위해 전화번호를 입력해주세요." 제목 위젯
                        PageTitle(
                          title:
                              titleText ??
                              tr('register.phone_title', context: context),
                        ),
                        SizedBox(height: 16.h),
                        // 국가 코드 선택 드롭다운 위젯
                        _CountrySelector(
                          selectedCountryCode: selectedCountryCode,
                          onChanged: onCountryChanged,
                        ),
                        SizedBox(height: 16.h),
                        // 전화번호 입력 필드 위젯
                        SizedBox(
                          key: const ValueKey('auth_phone_input_wrapper'),
                          width: 239.w,
                          child: CustomTextField(
                            controller: controller,
                            hintText:
                                hintText ??
                                tr('register.phone_hint', context: context),
                            keyboardType: TextInputType.phone,
                            textAlign: TextAlign.start,
                            maxLength: maxLength,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            prefixIcon: Icon(
                              SolarIconsOutline.phone,
                              color: const Color(0xffC0C0C0),
                              size: 24.sp,
                            ),
                            onChanged: onChanged,
                          ),
                        ),
                        if (errorText != null) ...[
                          SizedBox(height: 8.h),
                          SizedBox(
                            width: 239.w,
                            child: Text(
                              errorText!,
                              style: TextStyle(
                                color: const Color(0xFFFF8D8D),
                                fontSize: 12.sp,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CountryOption {
  final String code;
  final String label;
  final String dialCode;

  const _CountryOption({
    required this.code,
    required this.label,
    required this.dialCode,
  });
}

/// 전화번호 입력 전에 국가 코드 선택을 현재 화면 폭에 맞춰 제공한다.
class _CountrySelector extends StatelessWidget {
  final String selectedCountryCode;
  final ValueChanged<String> onChanged;

  const _CountrySelector({
    required this.selectedCountryCode,
    required this.onChanged,
  });

  /// 국가 코드 드롭다운을 현재 화면 폭에 맞춰 안정적으로 노출한다.
  @override
  Widget build(BuildContext context) {
    final options = [
      _CountryOption(
        code: 'KR',
        label: tr('register.country_kr', context: context),
        dialCode: '+82',
      ),
      _CountryOption(
        code: 'US',
        label: tr('register.country_us', context: context),
        dialCode: '+1',
      ),
      _CountryOption(
        code: 'MX',
        label: tr('register.country_mx', context: context),
        dialCode: '+52',
      ),
    ];

    return Container(
      key: const ValueKey('auth_phone_country_selector'),
      width: 239.w,
      height: 44,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: const Color(0xff323232),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.centerLeft,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCountryCode,
          isExpanded: true,
          dropdownColor: const Color(0xff323232),
          iconEnabledColor: const Color(0xFFF8F8F8),
          style: TextStyle(
            color: const Color(0xFFF8F8F8),
            fontSize: 14.sp,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w500,
          ),
          items: options
              .map((option) {
                return DropdownMenuItem<String>(
                  value: option.code,
                  child: Text('${option.label} (${option.dialCode})'),
                );
              })
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}
