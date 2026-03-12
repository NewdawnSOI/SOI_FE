import 'dart:async';
import 'dart:ui';

import 'package:app_links/app_links.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soi/api/controller/friend_controller.dart' as api_friend;
import 'package:soi/api/controller/user_controller.dart';

import 'api/api.dart' as api;
import 'app/app_constants.dart';
import 'app/app_container_builder.dart';
import 'app/app_providers.dart';
import 'app/app_routes.dart';
import 'utils/analytics_service.dart';
import 'utils/app_route_observer.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await _lockPortraitOrientation();

  final prefs = await SharedPreferences.getInstance();
  final hasSeenLaunchVideo =
      prefs.getBool(AppConstant.hasSeenLaunchVideoKey) ?? false;

  if (hasSeenLaunchVideo) {
    FlutterNativeSplash.preserve(widgetsBinding: binding);
  } else {
    FlutterNativeSplash.remove();
  }

  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('ko_KR', null);
  _configureImageCache();
  api.SoiApiClient.instance.initialize();
  KakaoSdk.init(nativeAppKey: dotenv.env[AppConstant.kakaoNativeAppKey]!);
  _configureErrorHandling();

  // AnalyticsService 인스턴스를 생성합니다.
  // 이 과정에서 Mixpanel SDK가 초기화되고, 앱의 플랫폼과 빌드 모드에 대한 슈퍼 프로퍼티가 등록됩니다.
  final analyticsService = await _createAnalyticsService();

  final userController = UserController();
  final didAutoLogin = await userController.tryAutoLogin();
  if (didAutoLogin) {
    await userController.refreshCurrentUser();
  }

  if (hasSeenLaunchVideo) {
    FlutterNativeSplash.remove();
  }

  runApp(
    EasyLocalization(
      supportedLocales: supportedLocales,
      path: 'assets/translations',
      fallbackLocale: koreanLocale,
      startLocale:
          PlatformDispatcher.instance.locale.languageCode ==
              AppConstant.spanishLanguageCode
          ? spanishLocale
          : koreanLocale,
      child: MyApp(
        hasSeenLaunchVideo: hasSeenLaunchVideo,
        preloadedUserController: userController,
        analyticsService: analyticsService,
      ),
    ),
  );
}

/// AnalyticsService 인스턴스를 생성합니다.
Future<AnalyticsService> _createAnalyticsService() async {
  final token = dotenv.env[AppConstant.mixpanelProjectToken]?.trim();
  if (token == null || token.isEmpty) {
    throw StateError('MIXPANEL_PROJECT_TOKEN is not configured.');
  }
  return AnalyticsService.create(token: token);
}

/// 앱 전체에서 사용되는 이미지 캐시 설정을 구성하는 함수입니다.
void _configureImageCache() {
  final cache = PaintingBinding.instance.imageCache;
  const maxItems = kDebugMode
      ? AppConstant.imageCacheMaxItemsDebug
      : AppConstant.imageCacheMaxItemsRelease;
  const maxBytes = maxItems * AppConstant.bytesPerMb;

  cache.maximumSize = maxItems;
  cache.maximumSizeBytes = maxBytes;
}

/// 앱의 에러 핸들링을 구성하는 함수입니다.
void _configureErrorHandling() {
  FlutterError.onError = FlutterError.presentError;
  PlatformDispatcher.instance.onError = (error, stack) => true;
}

Future<void> _lockPortraitOrientation() {
  return SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
}

class MyApp extends StatefulWidget {
  final bool hasSeenLaunchVideo;
  final UserController preloadedUserController;
  final AnalyticsService
  analyticsService; // AnalyticsService 인스턴스를 MyApp의 생성자로 전달받아서 멤버 변수로 저장합니다.

  const MyApp({
    super.key,
    required this.hasSeenLaunchVideo,
    required this.preloadedUserController,
    required this.analyticsService,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  Uri? _lastHandledUri;
  DateTime? _lastHandledTime;

  // 마지막으로 AnalyticsService에 identify로 전달한 사용자 ID를 저장하는 변수입니다.
  // 사용자가 로그인하거나 로그아웃할 때 이 값을 업데이트해서 중복된 identify 호출을 방지하는 데 사용됩니다.
  int? _lastAnalyticsUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // UserController의 상태가 변경될 때마다
    // _syncAnalyticsIdentity를 호출해서 AnalyticsService의 사용자 식별 정보를 최신 상태로 유지합니다.
    widget.preloadedUserController.addListener(_syncAnalyticsIdentity);

    // 앱이 시작될 때 사진 라이브러리 권한을 미리 요청해서, 사용자가 사진 관련 기능을 사용할 때 원활하게 권한이 처리되도록 합니다.
    _primePhotoLibraryPermission();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingUri,
      onError: (error) => debugPrint('딥링크 수신 실패: $error'),
    );
    _handleInitialLink();
    _syncAnalyticsIdentity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.preloadedUserController.removeListener(_syncAnalyticsIdentity);
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lockPortraitOrientation();
    }
  }

  void _primePhotoLibraryPermission() {
    Future.microtask(() async {
      try {
        await PhotoManager.requestPermissionExtend();
      } catch (e) {
        debugPrint('Photo permission prefetch failed: $e');
      }
    });
  }

  Future<void> _handleInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) _handleIncomingUri(uri);
    } catch (e) {
      debugPrint('초기 딥링크 확인 실패: $e');
    }
  }

  /// AnalyticsService의 사용자 식별 정보를 UserController의 상태에 맞게 동기화하는 함수입니다.
  void _syncAnalyticsIdentity() {
    final currentUserId = widget.preloadedUserController.currentUserId;
    if (currentUserId == _lastAnalyticsUserId) {
      return;
    }

    // 이전에 identify로 전달했던 사용자 ID를 저장해둡니다.
    final previousUserId = _lastAnalyticsUserId;

    // 현재 사용자 ID로 업데이트합니다.
    _lastAnalyticsUserId = currentUserId;

    if (currentUserId == null) {
      if (previousUserId != null) {
        // 사용자가 로그아웃한 경우에는 AnalyticsService의 사용자 식별 정보를 초기화합니다.
        unawaited(widget.analyticsService.reset());
      }
      return;
    }

    // 사용자가 로그인한 경우에는 AnalyticsService에
    // identify로 사용자 ID를 전달해서 사용자를 식별합니다.
    unawaited(widget.analyticsService.identify(userId: currentUserId));
  }

  void _handleIncomingUri(Uri uri) {
    final now = DateTime.now();
    final timeDiff = _lastHandledTime == null
        ? AppConstant.deepLinkInitTimeDiffSeconds
        : now.difference(_lastHandledTime!).inSeconds;

    if (_lastHandledUri == uri &&
        timeDiff < AppConstant.deepLinkDuplicationWindowSeconds) {
      return;
    }

    _lastHandledUri = uri;
    _lastHandledTime = now;

    final userId =
        uri.queryParameters[AppConstant.userIdQueryKey] ??
        uri.queryParameters[AppConstant.refUserIdQueryKey] ??
        uri.queryParameters[AppConstant.inviterIdQueryKey] ??
        '';
    final nickName =
        uri.queryParameters[AppConstant.nickNameQueryKey] ??
        uri.queryParameters[AppConstant.refNicknameQueryKey] ??
        uri.queryParameters[AppConstant.inviterQueryKey] ??
        '';

    if (userId.isEmpty && nickName.isEmpty) return;

    unawaited(_processInviteLink(userId: userId, nickName: nickName));
  }

  Future<void> _processInviteLink({
    required String userId,
    required String nickName,
  }) async {
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    final userController = Provider.of<UserController>(context, listen: false);
    final friendController = Provider.of<api_friend.FriendController>(
      context,
      listen: false,
    );
    final currentUser = userController.currentUser;
    if (currentUser == null || currentUser.phoneNumber.isEmpty) return;

    var requesterId = int.tryParse(userId);
    if (requesterId == null &&
        nickName.isNotEmpty &&
        nickName != AppConstant.inviteFriendFallbackName) {
      final inviterUser = await userController.getUserByNickname(nickName);
      requesterId = inviterUser?.id;
    }

    if (requesterId == null || requesterId == currentUser.id) return;

    await friendController.addFriend(
      requesterId: requesterId,
      receiverPhoneNum: currentUser.phoneNumber,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: buildAppProviders(
        widget.preloadedUserController,
        widget.analyticsService,
      ),
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          navigatorKey: _navigatorKey,
          initialRoute: widget.hasSeenLaunchVideo
              ? AppRoute.root
              : AppRoute.launchVideo,
          navigatorObservers: [appRouteObserver],
          debugShowCheckedModeBanner: false,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          builder: (context, child) => buildAppContainer(context, child!),
          routes: buildAppRoutes(),
          theme: ThemeData(iconTheme: const IconThemeData(color: Colors.white)),
        ),
      ),
    );
  }
}
