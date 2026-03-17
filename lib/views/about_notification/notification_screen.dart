import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../../api/controller/notification_controller.dart' as api;
import '../../api/controller/user_controller.dart';
import '../../api/models/notification.dart';
import 'services/notification_navigation_handler.dart';
import 'widgets/api_notification_item_widget.dart';

/// 알림 메인 화면 (API 버전)
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const double _paginationThreshold =
      200; // 스크롤이 바닥에서 200픽셀 이내로 접근하면 다음 페이지 로드

  late api.NotificationController _notificationController;
  late ScrollController _scrollController;

  bool _isLoading = false;
  bool _isFriendRequestLoading = false;
  bool _isLoadingMore = false; // 추가 페이지 로딩 중 여부
  bool _hasMoreNotifications = true; // 추가 페이지 존재 여부
  String? _error;
  NotificationGetAllResult? _notificationResult;
  int? _friendRequestCount; // 친구추가 요청 개수
  int _currentPage = 0; // 현재 페이지 번호 (0부터 시작)

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFriendRequestCountFromGetFriendApi(); // 친구 요청 개수 로드(get-friend)
      _loadNotifications(); // 알림 로드
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 스크롤 이벤트 핸들러: 페이지네이션 트리거
  /// 스크롤이 바닥에서 일정 픽셀 이내로 접근하면 다음 페이지를 로드합니다.
  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _isLoading ||
        _isLoadingMore ||
        !_hasMoreNotifications ||
        _notificationResult == null) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - _paginationThreshold) {
      return;
    }

    unawaited(_loadNotifications(loadMore: true));
  }

  /// 알림 로드
  Future<void> _loadNotifications({bool loadMore = false}) async {
    final userController = context.read<UserController>();
    final user = userController.currentUser;

    if (user == null) {
      setState(() {
        _error = tr('notification.login_required', context: context);
      });
      return;
    }

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _error = null;
        _currentPage = 0;
        _hasMoreNotifications = true;
      }
    });

    try {
      _notificationController = context.read<api.NotificationController>();
      final nextPage = loadMore ? _currentPage + 1 : 0;
      final result = await _notificationController.getAllNotifications(
        userId: user.id,
        page: nextPage,
      );

      // 페이지네이션 결과 처리
      if (mounted) {
        final mergedNotifications = loadMore
            ?
              // 기존 알림과 새로 로드된 알림을 ID 기반으로 병합하여 중복 제거
              _mergeNotifications(
                _notificationResult?.notifications ?? const [],
                result.notifications,
              )
            :
              // 새로 로드된 알림으로 전체 결과를 대체 (페이지네이션이 아닌 경우)
              result.notifications;

        // 친구 요청 개수는 페이지네이션과 상관없이 항상 최신 값으로 업데이트
        final baseResult = loadMore
            ? (_notificationResult ??
                  NotificationGetAllResult(
                    friendRequestCount: result.friendRequestCount,
                  ))
            : result;

        setState(() {
          _notificationResult = baseResult.copyWith(
            friendRequestCount: result.friendRequestCount,
            notifications: mergedNotifications,
          );
          _currentPage = nextPage;
          _hasMoreNotifications = result.notifications.isNotEmpty;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!loadMore) {
            _error = tr(
              'notification.load_failed_with_reason',
              context: context,
              namedArgs: {'error': e.toString()},
            );
          }
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  /// 알림 목록과 새로 로드된 알림을 ID 기반으로 병합하여 중복 제거
  List<AppNotification> _mergeNotifications(
    List<AppNotification> current,
    List<AppNotification> incoming,
  ) {
    final merged = List<AppNotification>.from(current);
    final seenKeys = current.map(_notificationKey).toSet();

    for (final notification in incoming) {
      final key = _notificationKey(notification);
      if (seenKeys.add(key)) {
        merged.add(notification);
      }
    }

    return merged;
  }

  /// 알림 객체에서 고유 키를 생성하는 헬퍼 메서드
  String _notificationKey(AppNotification notification) {
    return notification.id?.toString() ??
        '${notification.type?.value}:'
            '${notification.relatedId}:'
            '${notification.categoryIdForPost}:'
            '${notification.replyCommentId}:'
            '${notification.parentCommentId}:'
            '${notification.text ?? ''}:'
            '${notification.nickname ?? ''}';
  }

  /// 친구 요청 개수 로드 (알림 리스트와 독립)
  Future<void> _loadFriendRequestCountFromGetFriendApi() async {
    final userController = context.read<UserController>();
    final user = userController.currentUser;

    if (user == null) {
      return;
    }

    setState(() {
      _isFriendRequestLoading = true;
    });

    try {
      final notificationController = context.read<api.NotificationController>();
      final friendNotifications = await notificationController
          .getAllFriendNotifications(userId: user.id);
      final uniqueKeys = <String>{};
      for (final n in friendNotifications) {
        final key = n.relatedId ?? n.id;
        if (key != null) {
          uniqueKeys.add(key.toString());
        }
      }
      final count = uniqueKeys.isNotEmpty
          ? uniqueKeys.length
          : friendNotifications.length;
      if (!mounted) return;
      setState(() {
        _friendRequestCount = count;
        _isFriendRequestLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isFriendRequestLoading = false;
      });
    }
  }

  /// 새로고침 처리
  Future<void> _onRefresh() async {
    final userController = context.read<UserController>();
    final user = userController.currentUser;

    if (user != null) {
      context.read<api.NotificationController>().invalidateCache(); // 캐시 무효화
      await _loadFriendRequestCountFromGetFriendApi(); // 친구 요청 개수 갱신
      await _loadNotifications(); // 알림 갱신
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(), // AppBar
      // Body
      body: Column(
        children: [
          SizedBox(height: 20.h),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// AppBar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: Color(0xffd9d9d9)),
      title: Text(
        tr('notification.title', context: context),
        style: Theme.of(context).textTheme.displayLarge?.copyWith(
          color: const Color(0xFFF8F8F8),
          fontSize: 20.sp,
          fontFamily: 'Pretendard Variable',
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Body
  Widget _buildBody() {
    // 친구 요청 섹션은 알림 데이터 로딩/에러/빈 상태와 상관없이 항상 노출
    final showNotificationList =
        _notificationResult != null && _notificationResult!.hasNotifications;

    Widget body;
    if (_isLoading && _notificationResult == null) {
      body = _buildLoadingState();
    } else if (_error != null) {
      body = _buildErrorState();
    } else if (!showNotificationList) {
      body = _buildEmptyState();
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 19.w),
            child: Text(
              tr('notification.recent_7_days', context: context),
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.02.sp,
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: _buildNotificationList()),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFriendRequestSection(),
        SizedBox(height: 24.h),
        Expanded(child: body),
      ],
    );
  }

  /// 친구 요청 섹션
  Widget _buildFriendRequestSection() {
    final requestCount =
        _friendRequestCount ?? _notificationResult?.friendRequestCount ?? 0;
    final subtitle = _isFriendRequestLoading || _isLoading
        ? tr('notification.loading_short', context: context)
        : (requestCount > 0
              ? tr(
                  'notification.pending_requests',
                  context: context,
                  namedArgs: {'count': requestCount.toString()},
                )
              : tr('notification.no_requests', context: context));

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed('/friend_request');
      },
      child: Padding(
        padding: EdgeInsets.only(left: 19.w),
        child: Container(
          width: 354.w,
          height: 66.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xff1c1c1c),
          ),
          child: Row(
            children: [
              SizedBox(width: 18.w),
              Image.asset(
                'assets/friend_request_icon.png',
                width: 43,
                height: 43,
              ),
              SizedBox(width: 8.w),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('notification.friend_requests', context: context),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.08,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color(0xFFCBCBCB),
                      fontSize: 13.sp,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (requestCount > 0) ...[
                Container(
                  width: 20.w,
                  height: 20.h,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      requestCount > 99 ? '99+' : '$requestCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
              ],
              Icon(Icons.arrow_forward_ios, color: Colors.white, size: 23.sp),
              SizedBox(width: 12.w),
            ],
          ),
        ),
      ),
    );
  }

  /// 로딩 상태
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xff634D45)),
          SizedBox(height: 16.h),
          Text(
            tr('notification.loading', context: context),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xff535252),
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }

  /// 에러 상태
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
          SizedBox(height: 16.h),
          Text(
            tr('notification.load_failed', context: context),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: Colors.white,
              fontSize: 20.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            _error ?? tr('notification.unknown_error', context: context),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xff535252),
              fontSize: 16.sp,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: _onRefresh,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff634D45),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
            ),
            child: Text(tr('common.retry', context: context)),
          ),
        ],
      ),
    );
  }

  /// 빈 상태
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64.sp,
            color: const Color(0xff535252).withValues(alpha: 0.5),
          ),
          SizedBox(height: 16.h),
          Text(
            tr('notification.empty', context: context),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: const Color(0xff535252),
              fontSize: 20.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            tr('notification.empty_subtitle', context: context),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xff535252).withValues(alpha: 0.7),
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }

  /// 알림 목록
  Widget _buildNotificationList() {
    final notifications = _notificationResult?.notifications ?? [];

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xff634D45),
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xff1c1c1c),
            ),
            child: Column(
              children: [
                SizedBox(height: 22.h),
                for (int i = 0; i < notifications.length; i++)
                  ApiNotificationItemWidget(
                    notification: notifications[i],
                    profileUrl: notifications[i].userProfile,
                    imageUrl: notifications[i].imageUrl,
                    onTap: () => _onNotificationTap(notifications[i]),
                    onConfirm:
                        notifications[i].type ==
                            AppNotificationType.categoryInvite
                        ? () => _onNotificationTap(notifications[i])
                        : null,
                    isLast: i == notifications.length - 1,
                  ),
                if (_isLoadingMore) ...[
                  SizedBox(height: 8.h),
                  const CircularProgressIndicator(color: Color(0xff634D45)),
                  SizedBox(height: 16.h),
                ],
                SizedBox(height: 7.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 알림 탭 처리
  ///
  /// Parameters:
  ///   - [notification]: 탭된 알림 객체
  Future<void> _onNotificationTap(AppNotification notification) async {
    await NotificationNavigationHandler.handleInAppNotificationTap(
      context: context,
      notification: notification,
      onRefresh: _onRefresh,
    );
  }
}
