import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 텍스트 댓글을 입력하는 위젯입니다.
/// 음성 댓글 입력 모드와 전환할 수 있습니다.
/// 텍스트 댓글을 댓글 바텀 sheet에 표시하는 위젯이 아닙니다.
class VoiceCommentTextWidget extends StatefulWidget {
  final String photoId;
  final Function(String) onToggleVoiceComment;
  final Function(bool)? onFocusChanged; // 포커스 변경 콜백 추가
  final Function(String)? onTextCommentCreated; // 텍스트 댓글 생성 콜백

  const VoiceCommentTextWidget({
    super.key,
    required this.photoId,
    required this.onToggleVoiceComment,
    this.onFocusChanged,
    this.onTextCommentCreated, // 텍스트 댓글 생성 콜백 추가
  });

  @override
  State<VoiceCommentTextWidget> createState() => _VoiceCommentTextWidgetState();
}

class _VoiceCommentTextWidgetState extends State<VoiceCommentTextWidget> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    widget.onFocusChanged?.call(_focusNode.hasFocus);
  }

  /// 텍스트 댓글 전송
  Future<void> _sendTextComment() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      // 텍스트를 임시로 저장하고 콜백 호출
      // 실제 Firestore 저장은 프로필 위치 지정 후 수행
      _textController.clear();
      FocusScope.of(context).unfocus();

      // 콜백을 통해 pending 상태로 전환
      widget.onTextCommentCreated?.call(text);

      debugPrint('✅ 텍스트 댓글 임시 저장 완료');
    } catch (e) {
      debugPrint('❌ 텍스트 댓글 처리 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 353,
      // 높이 자동 증가 (옵션 B)
      decoration: BoxDecoration(
        color: const Color(0xff161616),
        borderRadius: BorderRadius.circular(21.5),
        border: Border.all(color: const Color(0x66D9D9D9), width: 1),
      ),
      padding: EdgeInsets.only(left: 11.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 5),
            child: InkWell(
              onTap: () => widget.onToggleVoiceComment(widget.photoId),
              child: Image.asset('assets/mic_icon.png', width: 36, height: 36),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 11),
              child: TextField(
                controller: _textController, // TextEditingController 연결
                focusNode: _focusNode, // FocusNode 연결
                onTapOutside: (event) {
                  FocusScope.of(context).unfocus();
                },
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: '댓글 추가 ....',
                  hintStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w200,
                    letterSpacing: -1.14,
                  ),
                ),
                cursorColor: Colors.white,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w200,
                  letterSpacing: -1.14,
                ),
                textAlignVertical: TextAlignVertical.center,
              ),
            ),
          ),
          IconButton(
            onPressed: _isSending ? null : _sendTextComment, // 전송 버튼에 핸들러 연결
            icon:
                _isSending
                    ? SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : Image.asset(
                      'assets/send_icon.png',
                      width: 17,
                      height: 17,
                    ),
          ),
        ],
      ),
    );
  }
}
