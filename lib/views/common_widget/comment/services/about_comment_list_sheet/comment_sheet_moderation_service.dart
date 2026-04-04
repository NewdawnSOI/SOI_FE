import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../../api/controller/comment_controller.dart';
import '../../../../../api/controller/friend_controller.dart';
import '../../../../../api/controller/post_controller.dart';
import '../../../../../api/controller/user_controller.dart';
import '../../../../../api/models/comment.dart';
import '../../../../../utils/snackbar_utils.dart';
import '../../../../about_feed/manager/feed_data_manager.dart';
import '../../../report/report_bottom_sheet.dart';
import '../../widgets/about_comment_list_sheet/comment_sheet_block_confirmation_sheet.dart';

/// 댓글 작성자 신고, 차단, 삭제 같은 moderation 흐름을 담당합니다.
/// 시트는 로컬 상태 반영만 남기고 외부 부수효과는 이 서비스가 처리합니다.
class CommentSheetModerationService {
  const CommentSheetModerationService._();

  /// 신고 시트 노출과 성공 토스트 메시지를 일관된 흐름으로 묶습니다.
  static Future<void> reportCommentAuthor({
    required BuildContext context,
    required VoidCallback collapseExpandedActionComment,
    required void Function(String message) showSnackBar,
  }) async {
    collapseExpandedActionComment();
    final result = await ReportBottomSheet.show(context);
    if (result == null || !context.mounted) {
      return;
    }
    showSnackBar(tr('common.report_submit_success'));
  }

  /// 작성자 차단 후 피드와 포스트 캐시를 함께 갱신해 잔존 콘텐츠를 정리합니다.
  static Future<void> blockCommentAuthor({
    required BuildContext context,
    required Comment comment,
    required UserController userController,
    required FriendController friendController,
    required FeedDataManager feedDataManager,
    required PostController postController,
    required VoidCallback collapseExpandedActionComment,
  }) async {
    collapseExpandedActionComment();

    final messenger = ScaffoldMessenger.of(context);
    final currentUser = userController.currentUser;
    if (currentUser == null) {
      SnackBarUtils.showWithMessenger(messenger, tr('common.login_required'));
      return;
    }

    final shouldBlock = await CommentSheetBlockConfirmationSheet.show(context);
    if (shouldBlock != true || !context.mounted) {
      return;
    }

    final nickname = (comment.nickname ?? '').trim();
    if (nickname.isEmpty) {
      SnackBarUtils.showWithMessenger(
        messenger,
        tr('common.user_info_unavailable'),
      );
      return;
    }

    final targetUser = await userController.getUserByNickname(nickname);
    if (targetUser == null) {
      SnackBarUtils.showWithMessenger(
        messenger,
        tr('common.user_info_unavailable'),
      );
      return;
    }

    final ok = await friendController.blockFriend(
      requesterId: currentUser.id,
      receiverId: targetUser.id,
    );
    if (!context.mounted) {
      return;
    }

    if (ok) {
      feedDataManager.removePostsByNickname(nickname);
      postController.notifyPostsChanged();
      SnackBarUtils.showWithMessenger(messenger, tr('common.block_success'));
      return;
    }

    SnackBarUtils.showWithMessenger(messenger, tr('common.block_failed'));
  }

  /// 서버 삭제가 성공하면 호출자 로컬 상태와 캐시 동기화 콜백을 실행합니다.
  static Future<void> deleteComment({
    required Comment comment,
    required CommentController commentController,
    required VoidCallback? onDeleted,
    required void Function(String message) showSnackBar,
  }) async {
    final targetId = comment.id;
    if (targetId == null) {
      showSnackBar(tr('comments.delete_unavailable'));
      return;
    }

    try {
      final success = await commentController.deleteComment(targetId);
      if (!success) {
        showSnackBar(tr('comments.delete_failed'));
        return;
      }

      onDeleted?.call();
      showSnackBar(tr('comments.delete_success'));
    } catch (_) {
      showSnackBar(tr('comments.delete_error'));
    }
  }
}
