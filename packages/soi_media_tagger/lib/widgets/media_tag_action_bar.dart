import 'package:flutter/material.dart';

/// 태깅 입력 진입점을 공통 액션 바로 렌더링해, 호스트 앱이 기본 UI를 바로 붙일 수 있게 합니다.
enum MediaTagComposerAction {
  text,
  camera,
  mic,
}

/// 태깅 입력 액션을 하단 바 형태로 노출하는 기본 위젯입니다.
class MediaTagActionBar extends StatelessWidget {
  const MediaTagActionBar({
    super.key,
    required this.onAction,
    this.placeholderText = 'Add tag',
    this.placeholderStyle,
    this.decoration,
    this.cameraIcon,
    this.micIcon,
    this.height = 52,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final Future<void> Function(MediaTagComposerAction action) onAction;
  final String placeholderText;
  final TextStyle? placeholderStyle;
  final Decoration? decoration;
  final Widget? cameraIcon;
  final Widget? micIcon;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      height: height,
      decoration:
          decoration ??
          BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(height / 2),
          ),
      child: Row(
        children: [
          IconButton(
            icon: cameraIcon ?? const Icon(Icons.camera_alt, color: Colors.white),
            onPressed: () => onAction(MediaTagComposerAction.camera),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onAction(MediaTagComposerAction.text),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  placeholderText,
                  style:
                      placeholderStyle ??
                      const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
          IconButton(
            icon: micIcon ?? const Icon(Icons.mic, color: Colors.white),
            onPressed: () => onAction(MediaTagComposerAction.mic),
          ),
        ],
      ),
    );
  }
}
