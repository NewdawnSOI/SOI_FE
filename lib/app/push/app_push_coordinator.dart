import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/services/notification_device_service.dart';
import 'package:soi/app/push/app_push_payload.dart';
import 'package:soi/firebase_options.dart';
import 'package:soi/views/about_notification/services/notification_navigation_handler.dart';

bool get supportsFirebaseMessaging =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!supportsFirebaseMessaging) {
    return;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class AppPushCoordinator {
  AppPushCoordinator._();

  static final AppPushCoordinator instance = AppPushCoordinator._();

  static const String channelId = 'soi_general_notifications';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final NotificationDeviceService _notificationDeviceService =
      NotificationDeviceService();

  GlobalKey<NavigatorState>? _navigatorKey;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  Future<void> _syncQueue = Future<void>.value();

  bool _isInitialized = false;
  bool _isRoutingPayload = false;
  int? _currentUserId;
  String? _lastKnownToken;
  String? _lastRegisteredBindingKey;
  AppPushPayload? _pendingPayload;

  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;
    if (!supportsFirebaseMessaging || _isInitialized) {
      await processPendingNavigation();
      return;
    }

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
    );

    final androidNotifications = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidNotifications?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        tr('push.channel_name'),
        description: tr('push.channel_description'),
        importance: Importance.max,
      ),
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: true,
    );

    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      (message) => unawaited(_showForegroundNotification(message)),
    );
    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => unawaited(_queueRemoteMessage(message)),
    );
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      (token) => unawaited(_registerTokenForCurrentUser(token)),
    );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _pendingPayload = _payloadFromRemoteMessage(initialMessage);
    }

    _isInitialized = true;
  }

  Future<void> syncAuthenticatedUser(int? userId) {
    _syncQueue = _syncQueue.then((_) => _syncAuthenticatedUserInternal(userId));
    return _syncQueue;
  }

  Future<void> _syncAuthenticatedUserInternal(int? userId) async {
    if (!supportsFirebaseMessaging || !_isInitialized) {
      _currentUserId = userId;
      return;
    }

    final previousUserId = _currentUserId;
    _currentUserId = userId;

    if (userId == null) {
      if (previousUserId != null) {
        clearLocalState();
      }
      return;
    }

    if (previousUserId != null && previousUserId != userId) {
      _lastRegisteredBindingKey = null;
    }

    await _requestPermission();
    final token = await _messaging.getToken();
    if (token != null && token.trim().isNotEmpty) {
      await _registerTokenForCurrentUser(token);
    }
    await processPendingNavigation();
  }

  Future<void> deleteCurrentDeviceToken() async {
    if (!supportsFirebaseMessaging || !_isInitialized) {
      return;
    }

    final token = _lastKnownToken ?? await _messaging.getToken();
    if (token == null || token.trim().isEmpty) {
      return;
    }

    try {
      await _notificationDeviceService.deleteToken(token);
    } catch (error) {
      debugPrint('[Push] 디바이스 토큰 삭제 실패: $error');
    }
  }

  Future<String?> issueTestDeviceToken() async {
    if (!supportsFirebaseMessaging) {
      return null;
    }

    if (_isInitialized) {
      await _requestPermission();
    } else {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    }

    final token = await _messaging.getToken();
    final normalizedToken = token?.trim();
    if (normalizedToken == null || normalizedToken.isEmpty) {
      return null;
    }

    _lastKnownToken = normalizedToken;
    return normalizedToken;
  }

  void clearLocalState() {
    _currentUserId = null;
    _lastKnownToken = null;
    _lastRegisteredBindingKey = null;
    _pendingPayload = null;
  }

  Future<void> processPendingNavigation() async {
    final payload = _pendingPayload;
    final context = _navigatorKey?.currentContext;
    if (payload == null || context == null || _isRoutingPayload) {
      return;
    }

    final currentUser = context.read<UserController>().currentUser;
    if (currentUser == null) {
      return;
    }

    _isRoutingPayload = true;
    _pendingPayload = null;
    try {
      await NotificationNavigationHandler.handlePushTap(
        context: context,
        payload: payload,
      );
    } catch (error) {
      debugPrint('[Push] 알림 라우팅 실패: $error');
      _pendingPayload = payload;
    } finally {
      _isRoutingPayload = false;
    }
  }

  Future<void> dispose() async {
    await _foregroundMessageSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription = null;
    _messageOpenedSubscription = null;
    _tokenRefreshSubscription = null;
    _isInitialized = false;
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final androidNotifications = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidNotifications?.requestNotificationsPermission();
  }

  Future<void> _registerTokenForCurrentUser(String token) async {
    final userId = _currentUserId;
    if (userId == null) {
      return;
    }

    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return;
    }

    _lastKnownToken = normalizedToken;
    final bindingKey = '$userId:$normalizedToken';
    if (_lastRegisteredBindingKey == bindingKey) {
      return;
    }

    try {
      final registered = await _notificationDeviceService.registerToken(
        token: normalizedToken,
        platform: _currentPlatform(),
      );
      if (registered) {
        _lastRegisteredBindingKey = bindingKey;
      }
    } catch (error) {
      debugPrint('[Push] 디바이스 토큰 등록 실패: $error');
    }
  }

  Future<void> _queueRemoteMessage(RemoteMessage message) async {
    _pendingPayload = _payloadFromRemoteMessage(message);
    await processPendingNavigation();
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final payload = _payloadFromRemoteMessage(message);
    if ((payload.title?.isEmpty ?? true) && (payload.body?.isEmpty ?? true)) {
      return;
    }

    await _localNotifications.show(
      payload.notificationId ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      payload.title ?? 'SOI',
      payload.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          tr('push.channel_name'),
          channelDescription: tr('push.channel_description'),
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(payload.toJson()),
    );
  }

  void _handleLocalNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        _pendingPayload = AppPushPayload.fromJson(decoded);
        unawaited(processPendingNavigation());
      }
    } catch (error) {
      debugPrint('[Push] 로컬 알림 payload 파싱 실패: $error');
    }
  }

  AppPushPayload _payloadFromRemoteMessage(RemoteMessage message) {
    return AppPushPayload.fromData(
      message.data,
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }

  NotificationDevicePlatform _currentPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return NotificationDevicePlatform.android;
      case TargetPlatform.iOS:
        return NotificationDevicePlatform.ios;
      default:
        return NotificationDevicePlatform.web;
    }
  }
}
