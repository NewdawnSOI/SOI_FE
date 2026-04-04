import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../comment_text_input_widget.dart';

/// 댓글 시트 입력바의 액션 버튼과 텍스트 입력 필드를 담당하는 위젯입니다.
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
    required this.replyDraftController,
    required this.replyDraftFocusNode,
    required this.onReplyDraftChanged,
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
  final TextEditingController replyDraftController;
  final FocusNode replyDraftFocusNode;
  final ValueChanged<String> onReplyDraftChanged;
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
                // 액션 버튼 모드일 때는 카메라 버튼, 텍스트 입력 필드, 마이크 버튼이 포함된 액션 바를 표시합니다.
                KeyedSubtree(
                  key: const ValueKey('comment_action_bar'),
                  child: Container(
                    width: 353.sp,
                    height: 46.sp,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0B0B),
                      borderRadius: BorderRadius.circular(52.r),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 10.sp),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: onCameraPressed,
                          padding: EdgeInsets.zero,
                          icon: Container(
                            width: 32.sp,
                            height: 32.sp,
                            decoration: const ShapeDecoration(
                              color: Color(0xFF323232),
                              shape: CircleBorder(),
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/camera_mode.png',
                                width: 17.78.sp,
                                height: 16.sp,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.sp),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: IgnorePointer(
                              ignoring: !isReplyDraftArmed,
                              child: TextField(
                                controller: replyDraftController,
                                focusNode: replyDraftFocusNode,
                                autofocus: false,
                                minLines: 1,
                                maxLines: 1,
                                onChanged: onReplyDraftChanged,
                                onTapOutside: (_) =>
                                    FocusScope.of(context).unfocus(),
                                style: TextStyle(
                                  color: const Color(0xFFF8F8F8),
                                  fontSize: 16.sp,
                                  fontFamily: 'Pretendard Variable',
                                  fontWeight: FontWeight.w200,
                                  letterSpacing: -1.14,
                                ),
                                cursorColor: Colors.white,
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                  hintText: tr('comments.add_comment'),
                                  hintStyle: TextStyle(
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
                        ),
                        IconButton(
                          onPressed: onMicPressed,
                          padding: EdgeInsets.zero,
                          icon: Image.asset(
                            'assets/record_icon.png',
                            width: 36.sp,
                            height: 36.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
