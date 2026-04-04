import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 댓글 Row를 길게 눌렀을 때 나타나는 팝업을 담당하는 위젯입니다.
/// - 댓글을 길게 눌렀을 때, 해당 댓글의 위치와 소유권 여부에 따라 삭제, 신고, 차단 등의 액션이 포함된 팝업이 표시됩니다.
///
/// fields:
/// - [anchorRect]: 팝업이 나타날 위치를 결정하는 Rect입니다. 댓글이 길게 눌린 위치의 좌표와 크기를 포함해야 합니다.
/// - [isOwnedByCurrentUser]: 현재 댓글이 사용자가 작성한 댓글인지 여부입니다.
///   - true면 삭제 액션이 포함된 팝업이 표시되고,
///   - false면 신고 및 차단 액션이 포함된 팝업이 표시됩니다.
/// - [onDelete]: 삭제 액션이 선택되었을 때 호출되는 콜백입니다.
/// - [onReport]: 신고 액션이 선택되었을 때 호출되는 콜백입니다.
/// - [onBlock]: 차단 액션이 선택되었을 때 호출되는 콜백입니다.
class ApiCommentSheetActionPopup extends StatelessWidget {
  const ApiCommentSheetActionPopup({
    super.key,
    required this.anchorRect,
    required this.isOwnedByCurrentUser,
    required this.onDelete,
    required this.onReport,
    required this.onBlock,
  });

  final Rect anchorRect;
  final bool isOwnedByCurrentUser;
  final VoidCallback onDelete;
  final VoidCallback onReport;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    /// 팝업이 화면 가장자리에서 떨어져야 하는 최소 간격입니다.
    const horizontalMargin = 16.0;

    /// 팝업의 너비는 댓글 소유권 여부에 따라 달라집니다.
    /// - 사용자가 작성한 댓글이면 삭제 액션만 포함된 팝업이므로 너비가 좁아집니다.
    /// - 다른 사용자의 댓글이면 신고 및 차단 액션이 포함된 팝업이므로 너비가 넓어집니다.
    final menuWidth = isOwnedByCurrentUser ? 140.w : 188.w;

    /// 팝업이 화면 밖으로 나가지 않도록,
    /// 댓글의 오른쪽 끝에서 팝업의 너비를 뺀 위치와 화면 너비에서 팝업의 너비와 최소 간격을 뺀 위치 중 더 큰 값을 선택합니다.
    final popupLeft = (anchorRect.right - menuWidth).clamp(
      horizontalMargin,
      MediaQuery.of(context).size.width - menuWidth - horizontalMargin,
    );

    /// 팝업이 댓글 바로 아래에 나타나도록, 댓글의 하단 좌표에서 약간 위로 올라오도록 설정합니다.
    final popupTop = anchorRect.bottom - 4.sp;

    return Positioned(
      left: popupLeft, // 팝업의 왼쪽 위치를 계산된 popupLeft로 설정합니다.
      top: popupTop, // 팝업의 위쪽 위치를 계산된 popupTop로 설정합니다.
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * -12.sp),
              child: Transform.scale(
                scale: 0.96 + (0.04 * value),
                alignment: Alignment.topRight,
                child: child,
              ),
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: isOwnedByCurrentUser
              ?
                // 사용자가 작성한 댓글이면 삭제 액션만 포함된 팝업을 표시합니다.
                _ApiCommentPopupActionButton(
                  label: tr('comments.delete'),
                  onTap: onDelete,
                  isDestructive: true,
                )
              :
                // 다른 사용자의 댓글이면 "신고 및 차단 액션이 포함된 팝업"을 표시합니다.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ApiCommentPopupActionButton(
                      label: tr('common.report'),
                      onTap: onReport,
                    ),
                    SizedBox(width: 10.sp),
                    _ApiCommentPopupActionButton(
                      label: tr('common.block'),
                      onTap: onBlock,
                      isDestructive: true,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// 댓글 액션 팝업에서 각 액션을 나타내는 버튼 위젯입니다.
/// - 삭제, 신고, 차단 등의 액션을 나타내며, 액션의 종류에 따라 스타일이 달라집니다.
/// - 삭제 액션은 붉은색 텍스트와 아이콘으로 강조되고, 신고 및 차단 액션은 기본 스타일로 표시됩니다.
/// - 버튼에 상관없이 공통으로 사용하기 위한 위젯입니다.
///
/// fields:
/// - [label]: 버튼에 표시될 텍스트입니다.
/// - [onTap]: 버튼이 눌렸을 때 호출되는 콜백입니다.
/// - [isDestructive]: 이 버튼이 파괴적인 액션(예: 삭제, 차단)을 나타내는지 여부입니다. true면 붉은색 스타일이 적용됩니다.
class _ApiCommentPopupActionButton extends StatelessWidget {
  const _ApiCommentPopupActionButton({
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final isDeleteAction = isDestructive && label == tr('comments.delete');
    return SizedBox(
      height: 45.sp,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFF323232),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.sp),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (isDeleteAction) ...[
              Image.asset(
                'assets/trash_red.png',
                width: 16.w,
                height: 16.h,
                fit: BoxFit.contain,
              ),
              SizedBox(width: 12.sp),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: isDeleteAction ? 15.sp : 13.sp,
                fontWeight: isDeleteAction ? FontWeight.w500 : FontWeight.w600,
                color: isDeleteAction ? const Color(0xFFFF0000) : null,
                fontFamily: 'Pretendard',
                letterSpacing: isDeleteAction ? 0 : -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
