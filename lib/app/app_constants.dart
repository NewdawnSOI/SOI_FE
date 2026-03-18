import 'package:flutter/material.dart';

/// 앱 내에서 사용되는 상수와 라우트 경로를 정의하는 파일
class AppRoute {
  static const launchVideo = '/launch_video';
  static const root = '/';
  static const homeNavigation = '/home_navigation_screen';
  static const camera = '/camera';
  static const archiving = '/archiving';
  static const start = '/start';
  static const auth = '/auth';
  static const login = '/login';
  static const onboarding = '/onboarding';
  static const shareRecord = '/share_record';
  static const myRecord = '/my_record';
  static const allCategory = '/all_category';
  static const privacyPolicy = '/privacy_policy';
  static const contactManager = '/contact_manager';
  static const friendListAdd = '/friend_list_add';
  static const friendList = '/friend_list';
  static const friendRequest = '/friend_request';
  static const feedHome = '/feed_home';
  static const profileScreen = '/profile_screen';
  static const privacyProtect = '/privacy_protect';
  static const termsOfService = '/terms_of_service';
  static const blockedFriends = '/blocked_friends';
  static const postManagement = '/post_management';
  static const deletePhoto = '/delete_photo';
  static const notifications = '/notifications';
}

/// 앱 내에서 사용되는 상수들을 정의하는 클래스
class AppConstant {
  static const hasSeenLaunchVideoKey = 'hasSeenLaunchVideo';
  static const kakaoNativeAppKey = 'KAKAO_NATIVE_APP_KEY';
  static const mixpanelProjectToken = 'MIXPANEL_PROJECT_TOKEN';
  static const koreanLanguageCode = 'ko';
  static const japaneseLanguageCode = 'ja';
  static const chineseLanguageCode = 'zh';
  static const englishLanguageCode = 'en';
  static const spanishLanguageCode = 'es';
  static const inviteFriendFallbackName = '친구';

  static const userIdQueryKey = 'userId';
  static const refUserIdQueryKey = 'refUserId';
  static const inviterIdQueryKey = 'inviterId';
  static const nickNameQueryKey = 'nickName';
  static const refNicknameQueryKey = 'refNickname';
  static const inviterQueryKey = 'inviter';

  static const imageCacheMaxItemsDebug = 50;
  static const imageCacheMaxItemsRelease = 30;
  static const bytesPerMb = 1024 * 1024;

  static const deepLinkDuplicationWindowSeconds = 3;
  static const deepLinkInitTimeDiffSeconds = 999;

  static const textScaleMin = 1.0;
  static const textScaleMax = 1.1;
  static const wideLayoutBreakpoint = 600.0;
  static const wideLayoutMaxWidth = 480.0;
}

const koreanLocale = Locale(AppConstant.koreanLanguageCode);
const japaneseLocale = Locale(AppConstant.japaneseLanguageCode);
const chineseLocale = Locale(AppConstant.chineseLanguageCode);
const spanishLocale = Locale(AppConstant.spanishLanguageCode);
const englishLocale = Locale(AppConstant.englishLanguageCode);

const supportedLocales = <Locale>[
  koreanLocale,
  japaneseLocale,
  chineseLocale,
  spanishLocale,
  englishLocale,
];

const supportedDateFormattingLocales = <String>[
  'ko_KR',
  'ja_JP',
  'zh_CN',
  'es_ES',
  'en_US',
];

Locale resolveSupportedLocale(Locale systemLocale) {
  switch (systemLocale.languageCode.toLowerCase()) {
    case AppConstant.koreanLanguageCode:
      return koreanLocale;
    case AppConstant.japaneseLanguageCode:
      return japaneseLocale;
    case AppConstant.chineseLanguageCode:
      return chineseLocale;
    case AppConstant.spanishLanguageCode:
      return spanishLocale;
    default:
      return englishLocale;
  }
}
