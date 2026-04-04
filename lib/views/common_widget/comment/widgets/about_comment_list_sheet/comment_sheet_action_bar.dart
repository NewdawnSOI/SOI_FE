import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../comment_text_input_widget.dart';

/// 댓글 시트 입력바의 액션 버튼과 텍스트 입력 필드를 담당하는 위젯입니다.
/// - 댓글 시트의 하단에 고정되어, 사용자가 댓글을 작성하거나 미디어 첨부 등의 액션을 수행할 수 있도록 합니다.
///
/// fields:
/// - [isTextInputMode]: 현재 텍스트 입력 모드인지 여부입니다.
///   - true면 텍스트 입력 필드가 표시되고,
///   - false면 액션 버튼이 표시됩니다.
/// - [textInputSession]: 텍스트 입력 세션을 구분하는 정수입니다. 댓글마다 고유한 세션이 할당되어야 합니다.
/// - [replyTargetId]: 현재 입력 중인 댓글의 대상 댓글 ID입니다. 새 댓글 작성 시 null, 대댓글 작성 시 부모 댓글 ID가 할당됩니다.
/// - [pendingInitialReplyText]: 현재 입력 중인 텍스트 입력 필드에 초기값으로 설정할 문자열입니다. 대댓글 작성 시 부모 댓글의 @멘션이 할당됩니다.
/// - [isReplyDraftArmed]: 현재 대댓글 작성이 활성화되어 있는지 여부입니다. true면 텍스트 입력 필드가 활성화되고, false면 비활성화됩니다.
/// - [replyDraftController]: 대댓글 작성 텍스트 입력 필드의 TextEditingController입니다.
/// - [replyDraftFocusNode]: 대댓글 작성 텍스트 입력 필드의 FocusNode입니다.
/// - [onReplyDraftChanged]: 대댓글 작성 텍스트 입력 필드의 내용이 변경될 때 호출되는 콜백입니다. 변경된 텍스트가 인자로 전달됩니다.
/// - [onCameraPressed]: 카메라 버튼이 눌렸을 때 호출되는 콜백입니다.
/// - [onMicPressed]: 마이크 버튼이 눌렸을 때 호출되는 콜백입니다.
/// - [onSubmitText]: 텍스트 입력이 제출되었을 때 호출되는 콜백입니다. 제출된 텍스트가 인자로 전달됩니다.
/// - [onEditingCancelled]: 텍스트 입력이 취소되었을 때 호출되는 콜백입니다.
class ApiCommentSheetActionBar extends StatelessWidget {
  const ApiCommentSheetActionBar({
    super.key,
    required this.isTextInputMode,
    required this.textInputSession,
    required this.replyTargetId,
    required this.pendingInitialReplyText,
    required this.isReplyDraftArmed,
    required this.onCenterTap,
    required this.onCameraPressed,
    required this.onMicPressed,
    required this.onSubmitText,
    required this.onEditingCancelled,
  });

  final bool isTextInputMode;
  final int textInputSession;
  final int? replyTargetId;
  final String pendingInitialReplyText;
  final bool isReplyDraftArmed;
  final VoidCallback onCenterTap;
  final VoidCallback onCameraPressed;
  final VoidCallback onMicPressed;
  final Future<void> Function(String text) onSubmitText;
  final VoidCallback onEditingCancelled;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 52.sp,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: isTextInputMode
              ?
                // 텍스트 입력 모드일 때는 CommentTextInputWidget을 표시합니다.
                KeyedSubtree(
                  key: ValueKey(
                    'reply_input_${replyTargetId ?? 0}_$textInputSession',
                  ),
                  child: CommentTextInputWidget(
                    initialText: pendingInitialReplyText,
                    onSubmitText: onSubmitText,
                    onEditingCancelled: onEditingCancelled,
                    hintText: tr('comments.add_comment'),
                  ),
                )
              :
                // 액션 버튼 모드일 때는 기존 댓글 바 모양을 유지하되, 중앙 탭으로 텍스트 입력 모드에 진입합니다.
                KeyedSubtree(
                  key: const ValueKey('comment_action_bar'),
                  child: Opacity(
                    opacity: isReplyDraftArmed ? 1 : 0.45,
                    child: Container(
                      width: 353,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF000000).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(52),
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 5),
                          IconButton(
                            onPressed: isReplyDraftArmed ? onCameraPressed : null,
                            padding: EdgeInsets.zero,
                            icon: Container(
                              width: 32,
                              height: 32,
                              decoration: const ShapeDecoration(
                                color: Color(0xFF323232),
                                shape: CircleBorder(),
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/camera_mode.png',
                                  width: (17.78).sp,
                                  height: 16.sp,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: isReplyDraftArmed ? onCenterTap : null,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  tr('comments.add_comment'),
                                  style: const TextStyle(
                                    color: Color(0xFFF8F8F8),
                                    fontSize: 16,
                                    fontFamily: 'Pretendard Variable',
                                    fontWeight: FontWeight.w200,
                                    letterSpacing: -1.14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: isReplyDraftArmed ? onMicPressed : null,
                            padding: EdgeInsets.zero,
                            icon: Image.asset(
                              'assets/record_icon.png',
                              width: 36,
                              height: 36,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
