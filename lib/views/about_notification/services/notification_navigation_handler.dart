import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/category_controller.dart';
import 'package:soi/api/controller/post_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/notification.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi/app/app_constants.dart';
import 'package:soi/app/push/app_push_payload.dart';
import 'package:soi/utils/snackbar_utils.dart';
import 'package:soi/views/about_archiving/screens/archive_detail/api_category_photos_screen.dart';
import 'package:soi/views/about_archiving/screens/archive_detail/api_photo_detail_screen.dart';
import 'package:soi/views/about_notification/widgets/category_invite_confirm_sheet.dart';

class NotificationNavigationHandler {
  const NotificationNavigationHandler._();

  static Future<void> handleInAppNotificationTap({
    required BuildContext context,
    required AppNotification notification,
    required Future<void> Function() onRefresh,
  }) async {
    final currentUser = context.read<UserController>().currentUser;
    if (currentUser == null) {
      _showSnackBar(
        context,
        tr('notification.login_required', context: context),
      );
      return;
    }

    final type = notification.type;
    if (type == null) {
      _showSnackBar(
        context,
        tr('notification.invalid_notification', context: context),
      );
      return;
    }

    if (type == AppNotificationType.friendRequest ||
        type == AppNotificationType.friendRespond) {
      Navigator.of(context).pushNamed(AppRoute.friendRequest);
      return;
    }

    if (type == AppNotificationType.categoryInvite) {
      final categoryId =
          notification.relatedId ?? notification.categoryIdForPost;
      if (categoryId == null) {
        _showSnackBar(
          context,
          tr('notification.category_not_found', context: context),
        );
        return;
      }

      final categoryController = context.read<CategoryController>();
      final acceptedMessage = tr(
        'notification.invite_accepted',
        context: context,
      );
      final acceptFailedMessage = tr(
        'notification.invite_accept_failed',
        context: context,
      );
      final declinedMessage = tr(
        'notification.invite_declined',
        context: context,
      );
      final declineFailedMessage = tr(
        'notification.invite_decline_failed',
        context: context,
      );
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return CategoryInviteConfirmSheet(
            categoryName:
                extractCategoryNameFromNotificationText(notification.text) ??
                tr('notification.category_default', context: context),
            categoryImageUrl: notification.imageUrl ?? '',
            invitees: const [],
            onAccept: () async {
              Navigator.of(sheetContext).pop();
              await _runWithBlockingLoading(context, () async {
                final ok = await categoryController.acceptInvite(
                  categoryId: categoryId,
                  responserId: currentUser.id,
                );
                if (!context.mounted) {
                  return;
                }
                if (ok) {
                  await onRefresh();
                  if (!context.mounted) {
                    return;
                  }
                  _showSnackBar(context, acceptedMessage);
                } else {
                  _showSnackBar(
                    context,
                    categoryController.errorMessage ?? acceptFailedMessage,
                  );
                }
              });
            },
            onDecline: () async {
              Navigator.of(sheetContext).pop();
              await _runWithBlockingLoading(context, () async {
                final ok = await categoryController.declineInvite(
                  categoryId: categoryId,
                  responserId: currentUser.id,
                );
                if (!context.mounted) {
                  return;
                }
                if (ok) {
                  await onRefresh();
                  if (!context.mounted) {
                    return;
                  }
                  _showSnackBar(context, declinedMessage);
                } else {
                  _showSnackBar(
                    context,
                    categoryController.errorMessage ?? declineFailedMessage,
                  );
                }
              });
            },
          );
        },
      );
      return;
    }

    if (type == AppNotificationType.categoryAdded) {
      final categoryId =
          notification.relatedId ?? notification.categoryIdForPost;
      if (categoryId == null) {
        _showSnackBar(
          context,
          tr('notification.category_not_found', context: context),
        );
        return;
      }

      await _openCategory(
        context,
        categoryId: categoryId,
        userId: currentUser.id,
      );
      return;
    }

    if (_isPostRelated(type)) {
      final postId = notification.relatedId;
      final categoryId = notification.categoryIdForPost;
      if (postId == null || categoryId == null) {
        _showSnackBar(
          context,
          tr('notification.post_not_found', context: context),
        );
        return;
      }

      await _openPostDetail(
        context,
        categoryId: categoryId,
        postId: postId,
        userId: currentUser.id,
        notificationId: notification.id,
      );
      return;
    }

    _showSnackBar(context, tr('notification.unsupported', context: context));
  }

  static Future<void> handlePushTap({
    required BuildContext context,
    required AppPushPayload payload,
  }) async {
    final currentUser = context.read<UserController>().currentUser;
    if (currentUser == null) {
      Navigator.of(context).pushNamed(AppRoute.root);
      return;
    }

    final type = payload.type;
    if (type == AppNotificationType.categoryAdded &&
        payload.categoryId != null) {
      await _openCategory(
        context,
        categoryId: payload.categoryId!,
        userId: currentUser.id,
      );
      return;
    }

    if (type != null && _isPostRelated(type) && payload.hasPostRoute) {
      await _openPostDetail(
        context,
        categoryId: payload.categoryId!,
        postId: payload.postId!,
        userId: currentUser.id,
        notificationId: payload.notificationId,
      );
      return;
    }

    Navigator.of(context).pushNamed(AppRoute.notifications);
  }

  static String? extractCategoryNameFromNotificationText(String? text) {
    if (text == null || text.isEmpty) {
      return null;
    }
    final quoted = RegExp(r'"([^"]+)"').firstMatch(text)?.group(1);
    if (quoted != null && quoted.isNotEmpty) {
      return quoted;
    }
    final curlyQuoted = RegExp(r'“([^”]+)”').firstMatch(text)?.group(1);
    if (curlyQuoted != null && curlyQuoted.isNotEmpty) {
      return curlyQuoted;
    }
    return null;
  }

  static bool _isPostRelated(AppNotificationType type) {
    return type == AppNotificationType.photoAdded ||
        type == AppNotificationType.commentAdded ||
        type == AppNotificationType.commentAudioAdded ||
        type == AppNotificationType.commentVideoAdded ||
        type == AppNotificationType.commentPhotoAdded ||
        type == AppNotificationType.commentReplyAdded;
  }

  static Future<void> _openCategory(
    BuildContext context, {
    required int categoryId,
    required int userId,
  }) async {
    final categoryController = context.read<CategoryController>();

    await _runWithBlockingLoading(context, () async {
      await categoryController.loadCategories(userId);
    });
    if (!context.mounted) {
      return;
    }

    final category = categoryController.getCategoryById(categoryId);
    if (category == null) {
      Navigator.of(context).pushNamed(AppRoute.archiving);
      _showSnackBar(
        context,
        tr('notification.category_not_found', context: context),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ApiCategoryPhotosScreen(category: category),
      ),
    );
  }

  static Future<void> _openPostDetail(
    BuildContext context, {
    required int categoryId,
    required int postId,
    required int userId,
    int? notificationId,
  }) async {
    final categoryController = context.read<CategoryController>();
    final postController = context.read<PostController>();

    late final List<Post> posts;
    await _runWithBlockingLoading(context, () async {
      await categoryController.loadCategories(userId);
      posts = await postController.getPostsByCategory(
        categoryId: categoryId,
        userId: userId,
        notificationId: notificationId,
      );
    });
    if (!context.mounted) {
      return;
    }

    final category = categoryController.getCategoryById(categoryId);
    if (category == null) {
      Navigator.of(context).pushNamed(AppRoute.archiving);
      _showSnackBar(
        context,
        tr('notification.category_not_found', context: context),
      );
      return;
    }

    final imagePosts = posts.where((post) => post.hasImage).toList();
    final initialIndex = imagePosts.indexWhere((post) => post.id == postId);

    if (initialIndex < 0) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ApiCategoryPhotosScreen(category: category),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ApiPhotoDetailScreen(
          allPosts: imagePosts,
          initialIndex: initialIndex,
          categoryName: category.name,
          categoryId: category.id,
        ),
      ),
    );
  }

  static Future<T> _runWithBlockingLoading<T>(
    BuildContext context,
    Future<T> Function() action,
  ) async {
    if (!context.mounted) {
      return action();
    }

    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xff634D45)),
      ),
    );

    try {
      return await action();
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  static void _showSnackBar(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    SnackBarUtils.showSnackBar(context, message);
  }
}
