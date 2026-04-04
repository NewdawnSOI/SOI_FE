import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

/// Firebase Messaging 사용 가능 여부.
bool get supportsFirebaseMessaging =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// 기본 알림 제목.
const String _fallbackNotificationTitle = 'SOI';

/// 백그라운드 채널 이름 기본값.
const String _backgroundChannelNameFallback = 'SOI 알림';

/// 백그라운드 채널 설명 기본값.
const String _backgroundChannelDescriptionFallback = '새로운 소식과 활동 알림';

/// 알림 이미지 다운로드 제한시간.
const Duration _notificationImageDownloadTimeout = Duration(seconds: 4);

/// 같은 푸시 데이터 중복 처리 방지 시간.
const Duration _payloadDeduplicationWindow = Duration(seconds: 5);

/// 로컬 알림 시작 설정값.
const InitializationSettings _localNotificationInitializationSettings =
    InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

/// 백그라운드용 로컬 알림 플러그인.
final FlutterLocalNotificationsPlugin _backgroundLocalNotifications =
    FlutterLocalNotificationsPlugin();

/// 백그라운드 푸시 처리 시작점.
///
/// 파라미터:
/// - [message]: 백그라운드에서 받은 메시지.
///
/// 반환값:
/// - 처리 작업 Future.
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

/// 로컬 알림 준비 함수.
///
/// 파라미터:
/// - [plugin]: 준비할 알림 플러그인.
/// - [onDidReceiveNotificationResponse]: 알림 탭 응답 함수.
///
/// 반환값:
/// - 준비 작업 Future.
Future<void> _initializeLocalNotifications(
  FlutterLocalNotificationsPlugin plugin, {
  DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
}) async {
  await plugin.initialize(
    _localNotificationInitializationSettings,
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
  );
}

/// Android 알림 채널 준비 함수.
///
/// 파라미터:
/// - [plugin]: 채널을 만들 플러그인.
/// - [channelName]: 사용자에게 보일 채널 이름.
/// - [channelDescription]: 채널 설명.
///
/// 반환값:
/// - 채널 준비 작업 Future.
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

/// 플랫폼별 알림 옵션 생성기.
///
/// 파라미터:
/// - [payload]: 화면에 보여줄 푸시 데이터.
/// - [channelName]: Android 채널 이름.
/// - [channelDescription]: Android 채널 설명.
/// - [androidLargeIcon]: Android 큰 아이콘 이미지.
/// - [androidStyleInformation]: Android 스타일 정보.
/// - [iOSAttachment]: iOS 첨부 이미지 파일.
///
/// 반환값:
/// - 플랫폼별 알림 설정값.
NotificationDetails _buildNotificationDetails({
  required AppPushPayload payload,
  required String channelName,
  required String channelDescription,
  AndroidBitmap<Object>? androidLargeIcon,
  StyleInformation? androidStyleInformation,
  DarwinNotificationAttachment? iOSAttachment,
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
    iOS: DarwinNotificationDetails(
      attachments: iOSAttachment == null ? null : [iOSAttachment],
    ),
  );
}

/// 로컬 알림 표시 함수.
///
/// 파라미터:
/// - [plugin]: 알림을 띄울 플러그인.
/// - [payload]: 화면에 보여줄 푸시 데이터.
/// - [channelName]: Android 채널 이름.
/// - [channelDescription]: Android 채널 설명.
///
/// 반환값:
/// - 표시 작업 Future.
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
  final notificationAttachment = await _loadDarwinNotificationAttachment(
    payload,
  );

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
      iOSAttachment: notificationAttachment,
    ),
    payload: jsonEncode(payload.toJson()),
  );
}

/// FCM 메세지에서 앱에서 쓰기 편한 데이터로 변환하는 함수.
/// - FCM에서 받은 RemoteMessage 객체를 앱에서 쓰기 편한 AppPushPayload 객체로 변환.
/// - AppPushPayLoad의 fromData에서 실제로 수행됨.
///
/// 파라미터:
/// - [message]: FCM로부터 받는 원격 메시지.
///
/// 반환값:
/// - [AppPushPayload]: 앱에서 쓰기 쉽게 바꾼 푸시 데이터.
AppPushPayload _payloadFromRemoteMessage(RemoteMessage message) {
  debugPrint('[Push] raw data: ${message.data}');
  return AppPushPayload.fromData(
    // 원본 data 맵을 그대로 넘겨서 필요한 값들을 AppPushPayload에서 추출하도록 함.
    message.data,

    // 알림 제목과 본문은 data 맵이 아닌 notification 객체에 들어올 수 있어서 따로 전달.
    title: message.notification?.title,

    // 알림 본문은 notification 객체에 들어올 수 있어서 따로 전달.
    body: message.notification?.body,
  );
}

/// 화면 표시 가능 여부 검사기.
///
/// 파라미터:
/// - [payload]: 검사할 푸시 데이터.
///
/// 반환값:
/// - 알림 표시 가능 여부.
bool _payloadHasVisibleContent(AppPushPayload payload) {
  return (payload.notificationTitle?.isNotEmpty ?? false) ||
      (payload.notificationBody?.isNotEmpty ?? false);
}

/// Android 알림 이미지 불러오기.
/// - Android 알림에서 보여줄 **이미지**를 payload에서 찾아서 가져오는 함수.
///
/// 파라미터:
/// - [payload]: 안드로이드 알림에서 보여줄 이미지가 들어 있을 수 있는 푸시 데이터.
///
/// 반환값:
/// - [Future<AndroidBitmap<Object>?>]: Android에서 쓸 비트맵 이미지를 Future로 반환.
///   - await으로 기다리다가 이미지를 받아오고 나서 AndroidBitmap 형태로 변환해서 반환.
///   - 실패하면 null 반환.
Future<AndroidBitmap<Object>?> _loadAndroidNotificationImage(
  AppPushPayload payload,
) async {
  if (defaultTargetPlatform != TargetPlatform.android) {
    return null;
  }

  // 이미지 URL을 Uri 형태로 변환해서 가져옴.
  final uri = _resolveNotificationImageUri(payload);
  if (uri == null) {
    return null;
  }

  try {
    // 이미지 주소로 HTTP GET 요청을 보내서 이미지 데이터를 받아옴.
    final response = await http
        .get(uri)
        .timeout(_notificationImageDownloadTimeout);
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      return null;
    }

    // 받은 이미지 데이터를 AndroidBitmap 형태로 변환해서 반환.
    return ByteArrayAndroidBitmap(response.bodyBytes);
  } catch (error) {
    debugPrint('[Push] 알림 이미지 로드 실패: $error');
    return null;
  }
}

/// iOS 알림 이미지 불러오기.
/// - iOS 알림에서 보여줄 **이미지**를 payload에서 찾아서 가져오는 함수.
/// - iOS는 알림에 이미지를 붙이는 방식이어서 Android와는 다르게 처리.
///
/// 파라미터:
/// - [payload]: 이미지가 들어 있을 수 있는 푸시 데이터.
///
/// 반환값:
/// - [Future<DarwinNotificationAttachment?>]: iOS에서 붙일 이미지 파일.
///   - await으로 기다리다가 이미지를 받아오고 나서 임시 파일로 저장한 후 DarwinNotificationAttachment 형태로 반환.
Future<DarwinNotificationAttachment?> _loadDarwinNotificationAttachment(
  AppPushPayload payload,
) async {
  if (defaultTargetPlatform != TargetPlatform.iOS) {
    return null;
  }

  // 이미지 URL을 Uri 형태로 변환해서 가져옴.
  final uri = _resolveNotificationImageUri(payload);
  if (uri == null) {
    return null;
  }

  try {
    // 이미지 주소로 HTTP GET 요청을 보내서 이미지 데이터를 받아옴.
    final response = await http
        .get(uri)
        .timeout(_notificationImageDownloadTimeout);
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      return null;
    }

    // iOS에서 붙일 수 있는 확장자 찾기
    // - URL 경로에서 확장자 추출 시도
    // - 확장자 없거나 인식 불가하면 content-type 헤더에서 확장자 추출 시도
    final fileExtension = _resolveDarwinAttachmentExtension(
      uri,
      contentType: response.headers['content-type'],
    );
    if (fileExtension == null) {
      debugPrint('[Push] iOS 알림 첨부 확장자를 확인할 수 없습니다: $uri');
      return null;
    }

    // 파일 이름에 notificationId를 포함해서 같은 이미지라도 다른 푸시마다 별도의 파일로 저장되도록 함.
    // 그래야 iOS에서 알림마다 이미지를 제대로 붙여서 보여줄 수 있음.
    final fileName =
        'soi_push_${payload.notificationId ?? DateTime.now().millisecondsSinceEpoch}$fileExtension';

    // 임시 파일 생성.
    final file = File('${Directory.systemTemp.path}/$fileName');

    // 파일에 이미지 데이터를 기록.
    // flush: true로 해서 데이터가 완전히 기록된 후에 파일이 닫히도록 함.
    await file.writeAsBytes(response.bodyBytes, flush: true);

    // 임시 파일을 DarwinNotificationAttachment 형태로 변환해서 반환.
    return DarwinNotificationAttachment(file.path);
  } catch (error) {
    debugPrint('[Push] iOS 알림 이미지 로드 실패: $error');
    return null;
  }
}

/// 알림 이미지 주소 찾기.
/// - payload에서 알림에 보여줄 이미지 주소를 찾아서 Uri 형태로 반환하는 함수.
/// - 안드로이드와 iOS 모두에서 알림에 이미지를 보여주려면 이미지 주소가 필요해서 이 함수에서 공통으로 처리후 넘겨줌.
///
/// 파라미터:
/// - [payload]: 이미지가 들어 있을 수 있는 푸시 데이터.
///
/// 반환값:
/// - [Uri?]: 사용할 수 있는 이미지 주소.
///   - [Uri]: 이미지 주소가 유효하면 Uri 형태로 반환.
///   - [null]: 이미지 주소가 없거나 유효하지 않으면 null 반환.
Uri? _resolveNotificationImageUri(AppPushPayload payload) {
  final imageUrl = payload.imageUrl?.trim(); // payload에서 이미지 URL을 가져와서 공백 제거.

  // 이미지 URL을 Uri 형태로 변환 시도.
  final uri = imageUrl == null ? null : Uri.tryParse(imageUrl);

  // Uri가 null이거나 유효한 http/https URL이 아니면 null 반환.
  if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
    return null;
  }

  // 유효한 이미지 URL이 담긴 Uri 반환.
  return uri;
}

/// iOS 첨부 파일 확장자 찾기.
///
/// 파라미터:
/// - [uri]: 이미지 주소.
/// - [contentType]: 응답의 파일 형식 정보.
///
/// 반환값:
/// - iOS에서 붙일 수 있는 확장자.
String? _resolveDarwinAttachmentExtension(Uri uri, {String? contentType}) {
  final path = uri.path;
  final lastDotIndex = path.lastIndexOf('.');
  if (lastDotIndex >= 0 && lastDotIndex < path.length - 1) {
    final extension = _normalizeDarwinAttachmentExtension(
      path.substring(lastDotIndex),
    );
    if (extension != null) {
      return extension;
    }
  }

  switch (contentType?.split(';').first.trim().toLowerCase()) {
    case 'image/jpeg':
      return '.jpg';
    case 'image/png':
      return '.png';
    case 'image/gif':
      return '.gif';
    case 'image/heic':
      return '.heic';
    case 'image/heif':
      return '.heif';
    default:
      return null;
  }
}

/// iOS 첨부 확장자 정리기.
///
/// 파라미터:
/// - [rawExtension]: 원본 확장자.
///
/// 반환값:
/// - 사용할 수 있게 정리한 확장자.
String? _normalizeDarwinAttachmentExtension(String rawExtension) {
  final normalized = rawExtension.trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }

  final extension = normalized.startsWith('.') ? normalized : '.$normalized';
  switch (extension) {
    case '.jpg':
    case '.jpeg':
    case '.png':
    case '.gif':
    case '.heic':
    case '.heif':
      return extension;
    default:
      return null;
  }
}

/// Android 알림 스타일 생성기.
///
/// 파라미터:
/// - [payload]: 화면에 보여줄 푸시 데이터.
/// - [image]: 함께 보여줄 이미지.
///
/// 반환값:
/// - Android 알림 스타일 정보.
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

/// 앱 푸시 코디네이터 클래스.
/// - 앱에서 푸시 알림과 관련된 모든 로직을 담당하는 클래스입니다.
/// - 푸시 권한 요청, 토큰 관리, 포그라운드 알림 표시, 알림 탭 처리, 백그라운드 푸시 처리 등 푸시와 관련된 모든 기능을 한 곳에서 관리합니다.
/// - 페이지 네비게이션은 [NotificationNavigationHandler]에 위임해서 푸시 데이터에 따라 적절한 화면으로 이동하는 로직을 담당하게 합니다.
///
/// 필드:
/// - [instance]: 앱 전체에서 함께 쓰는 객체.
///   - 싱글턴 패턴으로 구현되어 있어서 앱 어디서든 AppPushCoordinator.instance으로 접근해서 같은 객체를 공유할 수 있습니다.
///   - 푸시 알림과 관련된 상태와 로직을 **한 곳에서 관리하기 위해** 싱글턴 패턴을 사용합니다.
/// - [channelId]: 공용 알림 채널 ID.
/// - [_messaging]: Firebase 메시징 객체.
/// - [_localNotifications]: 앱 안 로컬 알림 객체.
/// - [_notificationDeviceService]: 디바이스 토큰 서버 연동 서비스.
/// - [_navigatorKey]: 화면 이동용 네비게이터 키.
/// - [_foregroundMessageSubscription]: 포그라운드 메시지 구독.
/// - [_messageOpenedSubscription]: 알림 탭 메시지 구독.
/// - [_tokenRefreshSubscription]: 토큰 변경 구독.
/// - [_syncQueue]: 사용자 동기화 순서 보장 큐.
/// - [_isInitialized]: 초기 설정 완료 여부.
/// - [_isRoutingPayload]: 화면 이동 처리 중 여부.
/// - [_currentUserId]: 현재 로그인 사용자 ID.
/// - [_lastKnownToken]: 마지막으로 확인한 디바이스 토큰.
/// - [_lastRegisteredBindingKey]: 마지막으로 서버에 등록한 사용자와 토큰 묶음.
/// - [_pendingPayload]: 아직 처리하지 않은 푸시 데이터.
/// - [_lastHandledPayloadKey]: 마지막으로 처리한 푸시 데이터 키.
/// - [_lastHandledPayloadAt]: 마지막으로 처리한 시각.
class AppPushCoordinator {
  /// 싱글턴 생성자.
  /// - 외부에서 생성자 호출을 막고 [instance]를 통해서만 접근하도록 함.
  /// - 싱글턴 패턴이란, 앱 전체에서 하나의 인스턴스만 만들어서 공유하는 디자인 패턴입니다.
  /// - 푸시 알림과 관련된 상태와 로직을 "한 곳에서 관리하기 위해" 싱글턴 패턴을 사용합니다.
  AppPushCoordinator._();

  /// 앱 전체 공용 인스턴스.
  static final AppPushCoordinator instance = AppPushCoordinator._();

  /// 공용 알림 채널 ID.
  static const String channelId = 'soi_general_notifications';

  /// Firebase 메시징 객체.
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// 앱 안 로컬 알림 객체.
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// 디바이스 토큰 서버 연동 서비스.
  final NotificationDeviceService _notificationDeviceService =
      NotificationDeviceService();

  /// 화면 이동용 네비게이터 키.
  GlobalKey<NavigatorState>? _navigatorKey;

  /// 포그라운드 메시지 구독.
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  /// 알림 탭 메시지 구독.
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;

  /// 토큰 변경 구독.
  StreamSubscription<String>? _tokenRefreshSubscription;

  /// 사용자 동기화 순서 보장 큐.
  Future<void> _syncQueue = Future<void>.value();

  /// 초기 설정 완료 여부.
  bool _isInitialized = false;

  /// 화면 이동 처리 중 여부.
  bool _isRoutingPayload = false;

  /// 현재 로그인 사용자 ID.
  int? _currentUserId;

  /// 마지막으로 확인한 디바이스 토큰.
  String? _lastKnownToken;

  /// 마지막으로 서버에 등록한 사용자와 토큰 묶음.
  String? _lastRegisteredBindingKey;

  /// 아직 처리하지 않은 푸시 데이터.
  AppPushPayload? _pendingPayload;

  /// 마지막으로 처리한 푸시 데이터 키.
  String? _lastHandledPayloadKey;

  /// 마지막으로 처리한 시각.
  DateTime? _lastHandledPayloadAt;

  /// 푸시 기능 시작 함수.
  ///
  /// 파라미터:
  /// - [navigatorKey]: 알림 탭 후 화면 이동에 쓸 키.
  ///
  /// 반환값:
  /// - 시작 작업 Future.
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

  /// 로그인 사용자 맞춤 함수.
  ///
  /// 파라미터:
  /// - [userId]: 현재 로그인 사용자 ID.
  ///
  /// 반환값:
  /// - 맞춤 작업 Future.
  Future<void> syncAuthenticatedUser(int? userId) {
    _syncQueue = _syncQueue.then((_) => _syncAuthenticatedUserInternal(userId));
    return _syncQueue;
  }

  /// 로그인 사용자 내부 맞춤 함수.
  ///
  /// 파라미터:
  /// - [userId]: 현재 로그인 사용자 ID.
  ///
  /// 반환값:
  /// - 내부 맞춤 작업 Future.
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

    final hasPermission = await _ensureNotificationPermission(
      promptIfNeeded: false,
    );
    if (!hasPermission) {
      await processPendingNavigation();
      return;
    }
    final token = await _messaging.getToken();
    if (token != null && token.trim().isNotEmpty) {
      await _registerTokenForCurrentUser(token);
    }
    await processPendingNavigation();
  }

  /// 로그인이나 회원가입 같은 사용자 액션 직후에 시스템 알림 권한을 요청하고 토큰 동기화까지 이어갑니다.
  Future<void> requestSystemPermissionAndSyncUser(int? userId) {
    _syncQueue = _syncQueue.then(
      (_) => _requestSystemPermissionAndSyncUserInternal(userId),
    );
    return _syncQueue;
  }

  /// 사용자 액션에서만 시스템 알림 권한 프롬프트를 띄우고 허용된 경우 현재 사용자 토큰을 등록합니다.
  Future<void> _requestSystemPermissionAndSyncUserInternal(int? userId) async {
    if (!supportsFirebaseMessaging) {
      return;
    }

    _currentUserId = userId;
    if (userId == null) {
      return;
    }

    final hasPermission = await _ensureNotificationPermission(
      promptIfNeeded: true,
    );
    if (!hasPermission) {
      return;
    }

    final token = await _messaging.getToken();
    if (token != null && token.trim().isNotEmpty) {
      await _registerTokenForCurrentUser(token);
    }

    if (_isInitialized) {
      await processPendingNavigation();
    }
  }

  /// 현재 디바이스 토큰 삭제 함수.
  ///
  /// 반환값:
  /// - 삭제 작업 Future.
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

  /// 테스트용 디바이스 토큰 받기.
  ///
  /// 반환값:
  /// - 발급된 디바이스 토큰 값.
  Future<String?> issueTestDeviceToken() async {
    if (!supportsFirebaseMessaging) {
      return null;
    }

    final hasPermission = await _ensureNotificationPermission(
      promptIfNeeded: true,
    );
    if (!hasPermission) {
      return null;
    }

    final token = await _messaging.getToken();
    final normalizedToken = token?.trim();
    if (normalizedToken == null || normalizedToken.isEmpty) {
      return null;
    }

    _lastKnownToken = normalizedToken;
    return normalizedToken;
  }

  /// 로컬 상태 비우기.
  ///
  /// 반환값:
  /// - 없음.
  void clearLocalState() {
    _currentUserId = null;
    _lastKnownToken = null;
    _lastRegisteredBindingKey = null;
    _pendingPayload = null;
    _lastHandledPayloadKey = null;
    _lastHandledPayloadAt = null;
  }

  /// 대기 중 푸시 이동 처리 함수.
  ///
  /// 반환값:
  /// - 화면 이동 처리 Future.
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
    if (_isDuplicatePayload(payload)) {
      _pendingPayload = null;
      return;
    }

    _isRoutingPayload = true;
    _pendingPayload = null;
    try {
      await NotificationNavigationHandler.handlePushTap(
        context: context,
        payload: payload,
      );
      _markPayloadHandled(payload);
    } catch (error) {
      debugPrint('[Push] 알림 라우팅 실패: $error');
      _pendingPayload = payload;
    } finally {
      _isRoutingPayload = false;
    }
  }

  /// 구독과 상태 정리 함수.
  ///
  /// 반환값:
  /// - 정리 작업 Future.
  Future<void> dispose() async {
    await _foregroundMessageSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription = null;
    _messageOpenedSubscription = null;
    _tokenRefreshSubscription = null;
    _isInitialized = false;
  }

  /// 푸시 권한 요청 함수.
  ///
  /// 반환값:
  /// - 요청 작업 Future.
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

  /// 현재 권한 상태를 조회하고 필요할 때만 시스템 권한 프롬프트를 표시합니다.
  Future<bool> _ensureNotificationPermission({
    required bool promptIfNeeded,
  }) async {
    final currentSettings = await _messaging.getNotificationSettings();
    if (_isPermissionGranted(currentSettings)) {
      return true;
    }
    if (!promptIfNeeded) {
      return false;
    }

    await _requestPermission();
    final requestedSettings = await _messaging.getNotificationSettings();
    return _isPermissionGranted(requestedSettings);
  }

  /// 승인된 알림 권한만 토큰 등록 경로로 이어져 불필요한 시스템 프롬프트를 막습니다.
  bool _isPermissionGranted(NotificationSettings settings) {
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// 현재 사용자 토큰 등록 함수.
  ///
  /// 파라미터:
  /// - [token]: 서버에 등록할 디바이스 토큰.
  ///
  /// 반환값:
  /// - 등록 작업 Future.
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

  /// 원격 메시지 대기열 저장 함수.
  ///
  /// 파라미터:
  /// - [message]: 나중에 처리할 원격 메시지.
  ///
  /// 반환값:
  /// - 저장 작업 Future.
  Future<void> _queueRemoteMessage(RemoteMessage message) async {
    _pendingPayload = _payloadFromRemoteMessage(message);
    await processPendingNavigation();
  }

  /// 포그라운드 알림 표시 함수.
  ///
  /// 파라미터:
  /// - [message]: 바로 보여줄 원격 메시지.
  ///
  /// 반환값:
  /// - 표시 작업 Future.
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final payload = _payloadFromRemoteMessage(message);
    await _showLocalNotification(
      _localNotifications,
      payload,
      channelName: _localizedChannelName,
      channelDescription: _localizedChannelDescription,
    );
  }

  /// 로컬 알림 탭 응답 처리 함수.
  ///
  /// 파라미터:
  /// - [response]: 사용자가 탭한 알림 정보.
  ///
  /// 반환값:
  /// - 없음.
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

  /// 현재 기기 플랫폼 찾기.
  ///
  /// 반환값:
  /// - 현재 기기 플랫폼 값.
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

  /// 번역된 채널 이름.
  String get _localizedChannelName => tr('push.channel_name');

  /// 번역된 채널 설명.
  String get _localizedChannelDescription => tr('push.channel_description');

  /// 같은 푸시 데이터인지 확인하기.
  ///
  /// 파라미터:
  /// - [payload]: 비교할 푸시 데이터.
  ///
  /// 반환값:
  /// - 최근 것과 같은지 여부.
  bool _isDuplicatePayload(AppPushPayload payload) {
    final handledAt = _lastHandledPayloadAt;
    final handledKey = _lastHandledPayloadKey;
    final nextKey = _buildPayloadKey(payload);
    if (handledAt == null || handledKey == null || handledKey != nextKey) {
      return false;
    }
    return DateTime.now().difference(handledAt) < _payloadDeduplicationWindow;
  }

  /// 처리 끝난 푸시 기록 함수.
  ///
  /// 파라미터:
  /// - [payload]: 처리 완료로 남길 푸시 데이터.
  ///
  /// 반환값:
  /// - 없음.
  void _markPayloadHandled(AppPushPayload payload) {
    _lastHandledPayloadKey = _buildPayloadKey(payload);
    _lastHandledPayloadAt = DateTime.now();
  }

  /// 푸시 비교용 키 만들기.
  ///
  /// 파라미터:
  /// - [payload]: 키를 만들 푸시 데이터.
  ///
  /// 반환값:
  /// - 문자열 형태 비교 키.
  String _buildPayloadKey(AppPushPayload payload) {
    return [
      payload.notificationId?.toString() ?? 'null',
      payload.type?.value ?? 'null',
      payload.categoryId?.toString() ?? 'null',
      payload.categoryInviteId?.toString() ?? 'null',
      payload.postId?.toString() ?? 'null',
      payload.commentId?.toString() ?? 'null',
      payload.friendId?.toString() ?? 'null',
    ].join(':');
  }

  /// 알림 payload를 앱에서 쓰기 편한 형태로 변환하는 함수.
  /// - 로컬 알림에서 받은 payload 문자열을 앱에서 쓰기 편한 AppPushPayload 객체로 변환.
  /// - AppPushPayload의 fromJson에서 실제로 수행됨.
  ///
  /// 파라미터:
  /// - [payload]: 문자열 형태 푸시 데이터.
  ///
  /// 반환값:
  /// - 앱에서 쓸 푸시 데이터.
  @visibleForTesting
  static AppPushPayload? decodeNotificationPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return null;
    }

    try {
      // String을 JSON 객체로 변환.
      final decoded = jsonDecode(payload);

      // JSON 객체가 Map 형태면 AppPushPayload로 변환해서 반환.
      if (decoded is Map) {
        return AppPushPayload.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (error) {
      debugPrint('[Push] 로컬 알림 payload 파싱 실패: $error');
    }
    return null;
  }

  /// 앱 시작 시 푸시 데이터 고르기.
  ///
  /// 파라미터:
  /// - [initialMessage]: Firebase가 준 첫 메시지.
  /// - [localNotificationLaunchDetails]: 로컬 알림으로 열린 정보.
  ///
  /// 반환값:
  /// - 우선순위를 반영한 푸시 데이터.
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

  /// 백그라운드 data-only 알림 표시 여부 확인.
  ///
  /// 파라미터:
  /// - [message]: 확인할 원격 메시지.
  ///
  /// 반환값:
  /// - 로컬 알림을 띄울지 여부.
  @visibleForTesting
  static bool shouldDisplayBackgroundDataOnlyMessage(RemoteMessage message) {
    if (message.notification != null) {
      return false;
    }

    return _payloadHasVisibleContent(_payloadFromRemoteMessage(message));
  }

  /// 화면 표시용 제목 고르기.
  ///
  /// 파라미터:
  /// - [payload]: 표시할 푸시 데이터.
  ///
  /// 반환값:
  /// - 최종 제목 문자열.
  @visibleForTesting
  static String resolveDisplayTitle(AppPushPayload payload) {
    return payload.notificationTitle?.trim().isNotEmpty == true
        ? payload.notificationTitle!.trim()
        : _fallbackNotificationTitle;
  }

  /// 화면 표시용 본문 고르기.
  ///
  /// 파라미터:
  /// - [payload]: 표시할 푸시 데이터.
  ///
  /// 반환값:
  /// - 최종 본문 문자열.
  @visibleForTesting
  static String resolveDisplayBody(AppPushPayload payload) {
    return payload.notificationBody?.trim() ?? '';
  }
}
