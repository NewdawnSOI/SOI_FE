import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 댓글 입력을 위한 기본 바
/// 카메라 버튼, 텍스트 입력 영역, 마이크 버튼으로 구성되어 있습니다.
/// 텍스트 입력 영역을 탭하면 onCenterTap 콜백이 호출되어 댓글 입력 UI로 전환할 수 있습니다.
///
/// Parameters:
/// - [onCenterTap]: 텍스트 입력 영역을 탭했을 때 호출되는 콜백
/// - [onCameraPressed]: 카메라 버튼이 눌렸을 때 호출되는 콜백 (선택적)
/// - [onMicPressed]: 마이크 버튼이 눌렸을 때 호출되는 콜백 (선택적)
class CommentBaseBarWidget extends StatelessWidget {
  final VoidCallback onCenterTap;
  final VoidCallback? onCameraPressed;
  final VoidCallback? onMicPressed;

  const CommentBaseBarWidget({
    super.key,
    required this.onCenterTap,
    this.onCameraPressed,
    this.onMicPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 353.sp,
      height: 46.sp,
      decoration: BoxDecoration(
        color: const Color(0xff1c1c1c),
        borderRadius: BorderRadius.circular(52.sp),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onCameraPressed,
            icon: Image.asset(
              'assets/camera_button_baseBar.png',
              width: 32.sp,
              height: 32.sp,
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCenterTap,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '댓글 추가...',
                  style: TextStyle(
                    color: const Color(0xFFF8F8F8),
                    fontSize: 16.sp,
                    fontFamily: 'Pretendard Variable',
                    fontWeight: FontWeight.w200,
                    letterSpacing: -1.14,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onMicPressed,
            icon: Image.asset('assets/mic_icon.png'),
          ),
        ],
      ),
    );
  }
}
