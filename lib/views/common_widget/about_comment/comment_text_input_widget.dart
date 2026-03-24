import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CommentTextInputWidget extends StatefulWidget {
  final Future<void> Function(String text) onSubmitText;
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback? onEditingCancelled;
  final String hintText;
  final String initialText;
  final bool autoFocus;

  /// 댓글 입력창 위젯입니다.
  /// - 텍스트 입력과 제출 기능을 제공합니다.
  /// - 제출 중에는 입력과 제출 버튼이 비활성화됩니다.
  ///
  /// fields:
  /// - [onSubmitText]: 텍스트 제출 시 호출되는 콜백 함수입니다. 비동기 함수로, 텍스트를 인자로 받아 처리합니다.
  /// - [onFocusChanged]: 입력창의 포커스 상태가 변경될 때 호출되는 콜백 함수입니다. 포커스 상태를 bool 값으로 전달합니다.
  /// - [onEditingCancelled]: 입력창이 포커스를 잃고 텍스트가 비어 있을 때 호출되는 콜백 함수입니다. 편집이 취소되었음을 알립니다.
  /// - [hintText]: 입력창에 표시되는 힌트 텍스트입니다. 기본값은 '댓글 추가...'입니다.
  /// - [initialText]: 입력창이 처음 렌더링될 때 설정되는 초기 텍스트입니다. 기본값은 빈 문자열입니다.
  /// - [autoFocus]: 위젯이 렌더링될 때 자동으로 포커스를 받을지 여부를 결정하는 플래그입니다. 기본값은 true입니다.

  const CommentTextInputWidget({
    super.key,
    required this.onSubmitText,
    this.onFocusChanged,
    this.onEditingCancelled,
    this.hintText = '댓글 추가...',
    this.initialText = '',
    this.autoFocus = true,
  });

  @override
  State<CommentTextInputWidget> createState() => _CommentTextInputWidgetState();
}

class _CommentTextInputWidgetState extends State<CommentTextInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialText;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    widget.onFocusChanged?.call(_focusNode.hasFocus);
    if (!_focusNode.hasFocus && _controller.text.trim().isEmpty) {
      widget.onEditingCancelled?.call();
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    var submissionSucceeded = false;
    try {
      await widget.onSubmitText(text);
      submissionSucceeded = true;
    } catch (_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    } finally {
      if (mounted && submissionSucceeded) {
        _controller.clear();
        FocusScope.of(context).unfocus();
      }
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

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
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: widget.autoFocus,
              minLines: 1,
              maxLines: 4,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              onSubmitted: (_) => _submit(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w300,
                letterSpacing: -0.6,
              ),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: Color(0xFFF8F8F8),
                  fontSize: 16.sp,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w200,
                  letterSpacing: -1.14,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Image.asset('assets/send_icon.png', width: 17, height: 17),
          ),
        ],
      ),
    );
  }
}
