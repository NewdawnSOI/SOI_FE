import 'package:flutter/material.dart';

/// 인라인 텍스트 입력과 제출을 패키지 기본 UI로 제공해, 호스트가 SOI와 같은 3단계 흐름을 바로 조립할 수 있게 합니다.
class MediaTagTextInputBar extends StatefulWidget {
  const MediaTagTextInputBar({
    super.key,
    required this.onSubmitText,
    this.onFocusChanged,
    this.onEditingCancelled,
    this.hintText = 'Add tag',
    this.initialText = '',
    this.autoFocus = true,
    this.height = 46,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
    this.decoration,
    this.submitIcon,
  });

  final Future<void> Function(String text) onSubmitText;
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback? onEditingCancelled;
  final String hintText;
  final String initialText;
  final bool autoFocus;
  final double height;
  final EdgeInsetsGeometry padding;
  final Decoration? decoration;
  final Widget? submitIcon;

  @override
  State<MediaTagTextInputBar> createState() => _MediaTagTextInputBarState();
}

/// 텍스트 입력 포커스와 제출 상태를 한 곳에서 관리해 typing 모드 전환을 단순화합니다.
class _MediaTagTextInputBarState extends State<MediaTagTextInputBar> {
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
      height: widget.height,
      decoration:
          widget.decoration ??
          BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(widget.height / 2),
            border: Border.all(
              color: const Color(0x66D9D9D9),
              width: 1.2,
            ),
          ),
      padding: widget.padding,
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
                fontWeight: FontWeight.w300,
              ),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: const TextStyle(
                  color: Color(0xFFF8F8F8),
                  fontSize: 16,
                  fontWeight: FontWeight.w200,
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
                : widget.submitIcon ??
                      const Icon(
                        Icons.send_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
          ),
        ],
      ),
    );
  }
}
