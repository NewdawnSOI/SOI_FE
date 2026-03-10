import 'package:flutter/material.dart';

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
      width: 353,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xff161616),
        borderRadius: BorderRadius.circular(21.5),
        border: Border.all(color: const Color(0x66D9D9D9), width: 1.2),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onCameraPressed,
            icon: Image.asset('assets/camera.png', width: 22, height: 22),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCenterTap,
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '댓글 추가...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onMicPressed,
            icon: Image.asset('assets/mic_icon.png', width: 30, height: 30),
          ),
        ],
      ),
    );
  }
}
