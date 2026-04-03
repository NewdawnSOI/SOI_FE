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

enum PushNavigationAction {
  notifications,
  friendRequest,
  category,
  categoryPost,
}

/// 알림과 푸시에서 전달된 정보에 따라 적절한 화면으로 진입하는 로직을 담당하는 유틸리티 클래스입니다.
/// - 알림 탭에서 알림을 탭했을 때, 해당 알림의 유형과 관련된 정보에 따라 적절한 화면으로 진입하는 로직을 담당합니다.
/// - 푸시 알림을 탭했을 때, 전달된 페이로드의 유형과 관련된 정보에 따라 적절한 화면으로 진입하는 로직을 담당합니다.
///
/// methods:
/// - [handleInAppNotificationTap]: 알림 탭에서 알림을 탭했을 때, 해당 알림의 유형과 관련된 정보에 따라 적절한 화면으로 진입하는 함수입니다.
/// - [handlePushTap]: 푸시 알림을 탭했을 때, 전달된 페이로드의 유형과 관련된 정보에 따라 적절한 화면으로 진입하는 함수입니다.
/// - [extractCategoryNameFromNotificationText]
///   - 알림 텍스트에서 카테고리 이름을 추출하는 함수입니다.
///   - 알림 텍스트에서 큰따옴표(") 또는 꺾쇠따옴표(“)로 감싸진 부분을 카테고리 이름으로 간주하여 추출합니다.
/// - [resolvePushNavigation]
///   - 푸시 페이로드의 유형과 관련된 정보에 따라 적절한 네비게이션 액션과 관련된 데이터를 반환하는 함수입니다.
///   - 푸시 페이로드의 유형에 따라, 친구 요청 관련 액션, 카테고리 관련 액션, 카테고리 내 포스트 관련 액션, 알림 탭으로 이동하는 액션 중 하나를 반환합니다.
/// - [resolvePostDetailLaunch]
///   - 알림에서 전달된 postId와 categoryId를 기반으로, 해당 포스트의 상세 페이지로 진입하기 위한 데이터를 반환하는 함수입니다.
///   - 카테고리 내 포스트 목록에서 알림에서 전달된 postId와 일치하는 포스트를 찾고, 해당 포스트가 존재하는 경우 포스트 목록과 초기 인덱스, 단건 포스트 모드 여부를 반환합니다.
///   - 알림에서 전달된 postId와 일치하는 포스트를 목록에서 찾지 못한 경우, 상세 API를 통해 정확한 정보를 가져오기 위한 데이터를 반환합니다.
///   - 알림에서 전달된 postId와 일치하는 포스트가 존재하지 않는 경우에는 null을 반환합니다.
/// - [_runWithBlockingLoading]
///   - 로딩 중에는 다른 작업이 불가능하도록 모달 형태의 로딩 인디케이터를 표시하는 유틸리티 함수입니다.
///   - 이 함수는 로딩이 필요한 작업을 수행하는 Future를 인자로 받아, 로딩 인디케이터가 표시된 상태에서 해당 작업을 실행하고, 작업이 완료되면 로딩 인디케이터를 제거합니다.
///   - 로딩이 필요한 작업을 수행하는 동안에는 사용자가 다른 작업을 시도하지 못하도록 막아, 작업이 완료될 때까지 기다리도록 합니다.
/// - [_showSnackBar]: 스낵바를 표시하는 유틸리티 함수입니다. 주어진 메시지를 스낵바로 표시합니다.
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

    final navigation = resolvePushNavigation(payload);
    switch (navigation.action) {
      case PushNavigationAction.friendRequest:
        Navigator.of(context).pushNamed(AppRoute.friendRequest);
        return;
      case PushNavigationAction.category:
        await _openCategory(
          context,
          categoryId: navigation.categoryId!,
          userId: currentUser.id,
        );
        return;
      case PushNavigationAction.categoryPost:
        await _openCategory(
          context,
          categoryId: navigation.categoryId!,
          userId: currentUser.id,
          initialPostId: navigation.postId,
        );
        return;
      case PushNavigationAction.notifications:
        Navigator.of(context).pushNamed(AppRoute.notifications);
        return;
    }
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

  static bool _isFriendRequestRelated(AppNotificationType type) {
    return type == AppNotificationType.friendRequest ||
        type == AppNotificationType.friendRespond;
  }

  @visibleForTesting
  static ({PushNavigationAction action, int? categoryId, int? postId})
  resolvePushNavigation(AppPushPayload payload) {
    final type = payload.type;
    if (type != null && _isFriendRequestRelated(type)) {
      return (
        action: PushNavigationAction.friendRequest,
        categoryId: null,
        postId: null,
      );
    }

    if (type == AppNotificationType.categoryAdded &&
        payload.categoryId != null) {
      return (
        action: PushNavigationAction.category,
        categoryId: payload.categoryId,
        postId: null,
      );
    }

    if (type != null && _isPostRelated(type) && payload.hasPostRoute) {
      return (
        action: PushNavigationAction.categoryPost,
        categoryId: payload.categoryId,
        postId: payload.postId,
      );
    }

    return (
      action: PushNavigationAction.notifications,
      categoryId: null,
      postId: null,
    );
  }

  static Future<void> _openCategory(
    BuildContext context, {
    required int categoryId,
    required int userId,
    int? initialPostId,
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
        builder: (_) => ApiCategoryPhotosScreen(
          category: category,
          initialPostId: initialPostId,
        ),
      ),
    );
  }

  /// 알림에서 전달된 postId와 categoryId를 기반으로 해당 포스트의 상세 페이지로 진입하는 함수입니다.
  /// 알림 유형에 따라, 초기 진입 시점에 해당 포스트만 불러오는 단건 포스트 모드로 진입을 시도할 수 있습니다.
  ///  이 경우, 초기 메모리 버스트를 줄이는 효과가 있습니다.
  ///
  /// parameters:
  /// - [context]: 현재 BuildContext
  /// - [categoryId]: 진입하려는 포스트가 속한 카테고리의 ID입니다.
  /// - [postId]: 진입하려는 포스트의 ID입니다.
  /// - [userId]: 현재 사용자의 ID입니다.
  /// - [notificationId]
  ///   - 알림에서 전달된 postId와 categoryId를 기반으로 포스트 목록을 불러올 때, 해당 알림을 제외하여 목록을 불러오기 위한 ID입니다.
  ///   - 이 값을 전달하면, 알림에서 전달된 포스트가 목록에 포함되지 않은 상태로 진입할 수 있습니다.
  ///   - 이 값을 전달하지 않으면, 알림에서 전달된 포스트가 목록에 포함된 상태로 진입합니다.
  /// - [preferSinglePostMode]
  ///   - 알림 유형에 따라, 초기 진입 시점에 해당 포스트만 불러오는 단건 포스트 모드로 진입을 시도할지 여부입니다.
  ///   - 이 값을 true로 전달하면, 초기 진입 시점에 해당 포스트만 불러오는 단건 포스트 모드로 진입을 시도합니다.
  ///   - 이 경우, 초기 메모리 버스트를 줄이는 효과가 있습니다.
  ///   - 단, 이 모드로 진입을 시도하더라도, 알림에서 전달된 postId에 해당하는 포스트가 존재하지 않거나, 단건 포스트 모드로 진입하는 과정에서 오류가 발생하는 경우에는, 기존처럼 포스트 목록 기반 진입으로 대체됩니다.
  static Future<void> _openPostDetail(
    BuildContext context, {
    required int categoryId,
    required int postId,
    required int userId,
    int? notificationId,
    bool preferSinglePostMode = false,
  }) async {
    final categoryController = context.read<CategoryController>();
    final postController = context.read<PostController>();

    // 푸시 진입은 단건 post를 우선 열어 초기 메모리 버스트를 줄이고,
    // 일반 알림 탭에서는 기존처럼 category 목록 기반 진입을 유지합니다.
    List<Post> posts = const <Post>[];
    Post? exactPost;
    await _runWithBlockingLoading(context, () async {
      await categoryController.loadCategories(userId);
      if (preferSinglePostMode) {
        exactPost = await postController.getPostDetail(postId);
        return;
      }

      posts = await postController.getPostsByCategory(
        categoryId: categoryId,
        userId: userId,
        notificationId: notificationId,
        forceRefresh: true,
      );

      if (posts.every((post) => post.id != postId)) {
        exactPost = await postController.getPostDetail(postId);
      }
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

    if (preferSinglePostMode && exactPost?.id == postId) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ApiPhotoDetailScreen(
            allPosts: List<Post>.unmodifiable(<Post>[exactPost!]),
            initialIndex: 0,
            categoryName: category.name,
            categoryId: category.id,
            singlePostMode: true,
          ),
        ),
      );
      return;
    }

    final detailLaunch = resolvePostDetailLaunch(
      categoryPosts: posts,
      postId: postId,
      exactPost: exactPost,
    );

    if (detailLaunch == null) {
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
          allPosts: detailLaunch.posts,
          initialIndex: detailLaunch.initialIndex,
          categoryName: category.name,
          categoryId: category.id,
          singlePostMode: detailLaunch.singlePostMode,
        ),
      ),
    );
  }

  /// 알림에서 전달된 postId와 일치하는 포스트를 목록에서 찾지 못한 경우,
  /// 상세 API를 통해 정확한 정보를 가져오기 위한 반환 타입입니다.
  @visibleForTesting
  static ({List<Post> posts, int initialIndex, bool singlePostMode})?
  resolvePostDetailLaunch({
    required List<Post> categoryPosts,
    required int postId,
    Post? exactPost,
  }) {
    final initialIndex = categoryPosts.indexWhere((post) => post.id == postId);
    if (initialIndex >= 0) {
      return (
        posts: List<Post>.unmodifiable(categoryPosts),
        initialIndex: initialIndex,
        singlePostMode: false,
      );
    }

    if (exactPost?.id == postId) {
      return (
        posts: List<Post>.unmodifiable(<Post>[exactPost!]),
        initialIndex: 0,
        singlePostMode: true,
      );
    }

    return null;
  }

  /// 로딩 중에는 다른 작업이 불가능하도록 모달 형태의 로딩 인디케이터를 표시하는 유틸리티 함수입니다.
  ///
  /// parameters:
  /// - [context]: 현재 BuildContext
  /// - [action]: 로딩 인디케이터가 표시된 상태에서 실행할 비동기 작업을 나타내는 함수입니다. 이 함수는 로딩이 필요한 작업을 수행하고 결과를 반환하는 Future를 리턴해야 합니다.
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
