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
      ),
    ),
  );
}

void _configureImageCache() {
  final cache = PaintingBinding.instance.imageCache;
  const maxItems = kDebugMode
      ? AppConstant.imageCacheMaxItemsDebug
      : AppConstant.imageCacheMaxItemsRelease;
  const maxBytes = maxItems * AppConstant.bytesPerMb;

  cache.maximumSize = maxItems;
  cache.maximumSizeBytes = maxBytes;
}

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

  const MyApp({
    super.key,
    required this.hasSeenLaunchVideo,
    required this.preloadedUserController,
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _primePhotoLibraryPermission();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingUri,
      onError: (error) => debugPrint('딥링크 수신 실패: $error'),
    );
    _handleInitialLink();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      providers: buildAppProviders(widget.preloadedUserController),
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
