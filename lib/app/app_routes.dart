import 'package:flutter/material.dart';
import 'package:soi/views/about_archiving/screens/api_archive_main_screen.dart';
import 'package:soi/views/about_archiving/screens/archive_detail/all_archives_screen.dart';
import 'package:soi/views/about_archiving/screens/archive_detail/my_archives_screen.dart';
import 'package:soi/views/about_archiving/screens/archive_detail/shared_archives_screen.dart';
import 'package:soi/views/about_camera/camera_screen.dart';
import 'package:soi/views/about_feed/feed_home.dart';
import 'package:soi/views/about_friends/friend_list_add_screen.dart';
import 'package:soi/views/about_friends/friend_list_screen.dart';
import 'package:soi/views/about_friends/friend_management_screen.dart';
import 'package:soi/views/about_friends/friend_request_screen.dart';
import 'package:soi/views/about_login_&_register/login_screen.dart';
import 'package:soi/views/about_login_&_register/register_screen.dart';
import 'package:soi/views/about_login_&_register/start_screen.dart';
import 'package:soi/views/about_notification/notification_screen.dart';
import 'package:soi/views/about_onboarding/onboarding_main_screen.dart';
import 'package:soi/views/about_profile/blocked_friend_list_screen.dart';
import 'package:soi/views/about_profile/deleted_post_list_screen.dart';
import 'package:soi/views/about_profile/post_management_screen.dart';
import 'package:soi/views/about_profile/privacy_protect_screen.dart';
import 'package:soi/views/about_profile/profile_setting_screen.dart';
import 'package:soi/views/about_setting/privacy.dart';
import 'package:soi/views/about_setting/terms_of_service.dart';
import 'package:soi/views/home_navigator_screen.dart';
import 'package:soi/views/launch_video_screen.dart';

import 'app_constants.dart';

Map<String, WidgetBuilder> buildAppRoutes() {
  return {
    AppRoute.launchVideo: (context) => const LaunchVideoScreen(),
    AppRoute.root: (context) => const StartScreen(),
    AppRoute.homeNavigation: (context) => HomePageNavigationBar(
      key: HomePageNavigationBar.rootKey,
      currentPageIndex: 0,
    ),
    AppRoute.camera: (context) => const CameraScreen(),
    AppRoute.archiving: (context) => const APIArchiveMainScreen(),
    AppRoute.start: (context) => const StartScreen(),
    AppRoute.auth: (context) => const AuthScreen(),
    AppRoute.login: (context) => const LoginScreen(),
    AppRoute.onboarding: (context) => const OnboardingMainScreen(),
    AppRoute.shareRecord: (context) => const SharedArchivesScreen(),
    AppRoute.myRecord: (context) => const MyArchivesScreen(),
    AppRoute.allCategory: (context) => const AllArchivesScreen(),
    AppRoute.privacyPolicy: (context) => const PrivacyPolicyScreen(),
    AppRoute.contactManager: (context) => const FriendManagementScreen(),
    AppRoute.friendListAdd: (context) => const FriendListAddScreen(),
    AppRoute.friendList: (context) => const FriendListScreen(),
    AppRoute.friendRequest: (context) => const FriendRequestScreen(),
    AppRoute.feedHome: (context) => const FeedHomeScreen(),
    AppRoute.profileScreen: (context) => const ProfileSettingScreen(),
    AppRoute.privacyProtect: (context) => const PrivacyProtectScreen(),
    AppRoute.termsOfService: (context) => const TermsOfService(),
    AppRoute.blockedFriends: (context) => const BlockedFriendListScreen(),
    AppRoute.postManagement: (context) => const PostManagementScreen(),
    AppRoute.deletePhoto: (context) => const DeletedPostListScreen(),
    AppRoute.notifications: (context) => const NotificationScreen(),
  };
}
