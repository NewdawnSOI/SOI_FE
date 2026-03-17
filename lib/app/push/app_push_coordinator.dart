import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
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

const String _fallbackNotificationTitle = 'SOI';
const String _backgroundChannelNameFallback = 'SOI 알림';
const String _backgroundChannelDescriptionFallback = '새로운 소식과 활동 알림';
const Duration _notificationImageDownloadTimeout = Duration(seconds: 4);

const InitializationSettings _localNotificationInitializationSettings =
    InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

final FlutterLocalNotificationsPlugin _backgroundLocalNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!supportsFirebaseMessaging) {
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!AppPushCoordinator.shouldDisplayBackgroundDataOnlyMessage(message)) {
    return;
  }

  final payload = _payloadFromRemoteMessage(message);
  await _initializeLocalNotifications(_backgroundLocalNotifications);
  await _showLocalNotification(
    _backgroundLocalNotifications,
    payload,
    channelName: _backgroundChannelNameFallback,
    channelDescription: _backgroundChannelDescriptionFallback,
  );
}

Future<void> _initializeLocalNotifications(
  FlutterLocalNotificationsPlugin plugin, {
  DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
}) async {
  await plugin.initialize(
    _localNotificationInitializationSettings,
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
  );
}

Future<void> _ensureNotificationChannel(
  FlutterLocalNotificationsPlugin plugin, {
  required String channelName,
  required String channelDescription,
}) async {
  final androidNotifications = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidNotifications?.createNotificationChannel(
    AndroidNotificationChannel(
      AppPushCoordinator.channelId,
      channelName,
      description: channelDescription,
      importance: Importance.max,
    ),
  );
}

NotificationDetails _buildNotificationDetails({
  required AppPushPayload payload,
  required String channelName,
  required String channelDescription,
  AndroidBitmap<Object>? androidLargeIcon,
  StyleInformation? androidStyleInformation,
}) {
  final title = AppPushCoordinator.resolveDisplayTitle(payload);
  final body = AppPushCoordinator.resolveDisplayBody(payload);
  return NotificationDetails(
    android: AndroidNotificationDetails(
      AppPushCoordinator.channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: androidLargeIcon,
      styleInformation:
          androidStyleInformation ??
          BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: _fallbackNotificationTitle,
          ),
    ),
    iOS: const DarwinNotificationDetails(),
  );
}

Future<void> _showLocalNotification(
  FlutterLocalNotificationsPlugin plugin,
  AppPushPayload payload, {
  required String channelName,
  required String channelDescription,
}) async {
  if (!_payloadHasVisibleContent(payload)) {
    return;
  }

  final title = AppPushCoordinator.resolveDisplayTitle(payload);
  final body = AppPushCoordinator.resolveDisplayBody(payload);
  final notificationImage = await _loadAndroidNotificationImage(payload);

  await _ensureNotificationChannel(
    plugin,
    channelName: channelName,
    channelDescription: channelDescription,
  );
  await plugin.show(
    payload.notificationId ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    _buildNotificationDetails(
      payload: payload,
      channelName: channelName,
      channelDescription: channelDescription,
      androidLargeIcon: notificationImage,
      androidStyleInformation: _buildAndroidStyleInformation(
        payload,
        image: notificationImage,
      ),
    ),
    payload: jsonEncode(payload.toJson()),
  );
}

AppPushPayload _payloadFromRemoteMessage(RemoteMessage message) {
  return AppPushPayload.fromData(
    message.data,
    title: message.notification?.title,
    body: message.notification?.body,
  );
}

bool _payloadHasVisibleContent(AppPushPayload payload) {
  return (payload.notificationTitle?.isNotEmpty ?? false) ||
      (payload.notificationBody?.isNotEmpty ?? false);
}

Future<AndroidBitmap<Object>?> _loadAndroidNotificationImage(
  AppPushPayload payload,
) async {
  if (defaultTargetPlatform != TargetPlatform.android) {
    return null;
  }

  final imageUrl = payload.imageUrl?.trim();
  final uri = imageUrl == null ? null : Uri.tryParse(imageUrl);
  if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
    return null;
  }

  try {
    final response = await http
        .get(uri)
        .timeout(_notificationImageDownloadTimeout);
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      return null;
    }
    return ByteArrayAndroidBitmap(response.bodyBytes);
  } catch (error) {
    debugPrint('[Push] 알림 이미지 로드 실패: $error');
    return null;
  }
}

StyleInformation _buildAndroidStyleInformation(
  AppPushPayload payload, {
  AndroidBitmap<Object>? image,
}) {
  final title = AppPushCoordinator.resolveDisplayTitle(payload);
  final body = AppPushCoordinator.resolveDisplayBody(payload);

  if (image != null) {
    return BigPictureStyleInformation(
      image,
      largeIcon: image,
      contentTitle: title,
      summaryText: body,
      hideExpandedLargeIcon: false,
    );
  }

  return BigTextStyleInformation(
    body,
    contentTitle: title,
    summaryText: _fallbackNotificationTitle,
  );
}

/// 앱의 푸시 알림 관련 기능을 중앙에서 관리하는 AppPushCoordinator 클래스입니다.
/// 푸시 알림의 초기화, 사용자 인증 상태와의 동기화, 알림 수신 및 처리, 디바이스 토큰 관리 등의 역할을 수행합니다.
/// 앱 전체에서 사용할 수 있는 싱글톤 인스턴스를 제공하여, 앱의 어디에서나 푸시 알림 관련 기능에 접근할 수 있도록 합니다.
///
/// fields:
/// - [instance]: AppPushCoordinator의 싱글톤 인스턴스입니다.
/// - [channelId]: 푸시 알림 채널의 고유 식별자입니다.
/// - [_messaging]: FirebaseMessaging 인스턴스로, 푸시 알림과 관련된 Firebase 기능을 제공합니다.
/// - [_localNotifications]: FlutterLocalNotificationsPlugin 인스턴스로, 로컬 알림을 관리합니다.
/// - [_notificationDeviceService]: NotificationDeviceService 인스턴스로, 디바이스 토큰 등록 및 삭제와 관련된 API 호출을 처리합니다.
/// - [_navigatorKey]: 앱의 네비게이터 키로, 알림을 탭했을 때 적절한 화면으로 라우팅하는 데 사용됩니다.
/// - [_foregroundMessageSubscription]: 앱이 포그라운드에 있을 때 수신되는 푸시 메시지를 처리하는 스트림 구독입니다.
/// - [_messageOpenedSubscription]: 사용자가 푸시 알림을 탭했을 때 발생하는 이벤트를 처리하는 스트림 구독입니다.
/// - [_tokenRefreshSubscription]: 디바이스 토큰이 갱신될 때 발생하는 이벤트를 처리하는 스트림 구독입니다.
/// - [_syncQueue]: 사용자 인증 상태와의 동기화를 순차적으로 처리하기 위한 큐입니다.
/// - [_isInitialized]: 푸시 알림 시스템이 초기화되었는지 여부를 나타내는 플래그입니다.
/// - [_isRoutingPayload]: 현재 푸시 알림 페이로드를 라우팅 중인지 여부를 나타내는 플래그입니다.
/// - [_currentUserId]: 현재 인증된 사용자의 ID입니다.
/// - [_lastKnownToken]: 마지막으로 알려진 디바이스 토큰입니다.
/// - [_lastRegisteredBindingKey]: 마지막으로 등록된 사용자 ID와 토큰의 조합을 나타내는 문자열입니다.
/// - [_pendingPayload]: 처리 대기 중인 푸시 알림 페이로드입니다.
class AppPushCoordinator {
  AppPushCoordinator._(); // 프라이빗 생성자입니다. 외부에서 직접 인스턴스를 생성할 수 없도록 합니다.

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

    await _initializeLocalNotifications(
      _localNotifications,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
    );
    await _ensureNotificationChannel(
      _localNotifications,
      channelName: _localizedChannelName,
      channelDescription: _localizedChannelDescription,
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

    final localLaunchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();
    final initialMessage = await _messaging.getInitialMessage();
    _pendingPayload = AppPushCoordinator.resolvePendingLaunchPayload(
      initialMessage: initialMessage,
      localNotificationLaunchDetails: localLaunchDetails,
    );

    _isInitialized = true;
  }

  /// 이 메서드는 현재 인증된 사용자의 ID와 푸시 알림 시스템을 동기화합니다.
  /// 사용자 ID가 변경되면 디바이스 토큰을 새 사용자에 맞게 등록하거나 삭제합니다.
  Future<void> syncAuthenticatedUser(int? userId) {
    _syncQueue = _syncQueue.then((_) => _syncAuthenticatedUserInternal(userId));
    return _syncQueue;
  }

  /// 이 메서드는 현재 인증된 사용자의 ID와 푸시 알림 시스템을 동기화합니다.
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

  ///
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
      // 이 메서드는 현재 인증된 사용자의 ID와 푸시 알림 시스템을 동기화합니다.
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
    await _showLocalNotification(
      _localNotifications,
      payload,
      channelName: _localizedChannelName,
      channelDescription: _localizedChannelDescription,
    );
  }

  void _handleLocalNotificationResponse(NotificationResponse response) {
    final payload = AppPushCoordinator.decodeNotificationPayload(
      response.payload,
    );
    if (payload == null) {
      return;
    }
    _pendingPayload = payload;
    unawaited(processPendingNavigation());
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

  String get _localizedChannelName => tr('push.channel_name');

  String get _localizedChannelDescription => tr('push.channel_description');

  @visibleForTesting
  static AppPushPayload? decodeNotificationPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        return AppPushPayload.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (error) {
      debugPrint('[Push] 로컬 알림 payload 파싱 실패: $error');
    }
    return null;
  }

  @visibleForTesting
  static AppPushPayload? resolvePendingLaunchPayload({
    RemoteMessage? initialMessage,
    NotificationAppLaunchDetails? localNotificationLaunchDetails,
  }) {
    if (initialMessage != null) {
      return _payloadFromRemoteMessage(initialMessage);
    }

    if (localNotificationLaunchDetails?.didNotificationLaunchApp != true) {
      return null;
    }

    return decodeNotificationPayload(
      localNotificationLaunchDetails?.notificationResponse?.payload,
    );
  }

  @visibleForTesting
  static bool shouldDisplayBackgroundDataOnlyMessage(RemoteMessage message) {
    if (message.notification != null) {
      return false;
    }

    return _payloadHasVisibleContent(_payloadFromRemoteMessage(message));
  }

  @visibleForTesting
  static String resolveDisplayTitle(AppPushPayload payload) {
    return payload.notificationTitle?.trim().isNotEmpty == true
        ? payload.notificationTitle!.trim()
        : _fallbackNotificationTitle;
  }

  @visibleForTesting
  static String resolveDisplayBody(AppPushPayload payload) {
    return payload.notificationBody?.trim() ?? '';
  }
}
