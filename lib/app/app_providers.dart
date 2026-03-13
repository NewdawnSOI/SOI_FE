import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:soi/api/controller/audio_controller.dart';
import 'package:soi/api/controller/category_controller.dart' as api_category;
import 'package:soi/api/controller/category_search_controller.dart'
    as api_category_search;
import 'package:soi/api/services/category_search_service.dart';
import 'package:soi/api/controller/comment_audio_controller.dart';
import 'package:soi/api/controller/comment_controller.dart';
import 'package:soi/api/controller/contact_controller.dart';
import 'package:soi/api/controller/friend_controller.dart' as api_friend;
import 'package:soi/api/controller/media_controller.dart' as api_media;
import 'package:soi/api/controller/notification_controller.dart'
    as api_notification;
import 'package:soi/api/controller/post_controller.dart';
import 'package:soi/api/controller/report_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/utils/analytics_service.dart';
import 'package:soi/views/about_feed/manager/feed_data_manager.dart';

List<SingleChildWidget> buildAppProviders(
  UserController userController,
  AnalyticsService analyticsService,
) {
  return [
    // AnalyticsService는 앱 전체에서 공유되는 서비스이므로 Provider.value를 사용해서 인스턴스를 전달합니다.
    Provider<AnalyticsService>.value(value: analyticsService),

    // 사용자의 로그인 상태와 사용자 정보를 관리하는 UserController도 앱 전체에서 공유되는 상태이므로 Provider.value를 사용해서 인스턴스를 전달합니다.
    ChangeNotifierProvider<UserController>.value(value: userController),

    // 카테고리 관련 컨트롤러와 서비스들을 Provider로 등록합니다.
    ChangeNotifierProvider<api_category.CategoryController>(
      create: (_) => api_category.CategoryController(),
    ),

    // 카테고리 검색 컨트롤러는 CategorySearchService를 주입받아서 생성됩니다.
    ChangeNotifierProvider<api_category_search.CategorySearchController>(
      create: (_) => api_category_search.CategorySearchController(
        searchService: CategorySearchService(),
      ),
    ),
    ChangeNotifierProvider<PostController>(create: (_) => PostController()),
    ChangeNotifierProvider<FeedDataManager>(create: (_) => FeedDataManager()),
    ChangeNotifierProvider<api_friend.FriendController>(
      create: (_) => api_friend.FriendController(),
    ),
    ChangeNotifierProvider<CommentController>(
      create: (_) => CommentController(),
    ),
    ChangeNotifierProvider<api_media.MediaController>(
      create: (_) => api_media.MediaController(),
    ),
    ChangeNotifierProvider<api_notification.NotificationController>(
      create: (_) => api_notification.NotificationController(),
    ),
    ChangeNotifierProvider<ReportController>(
      create: (_) => ReportController(),
    ),
    ChangeNotifierProvider<ContactController>(
      create: (_) => ContactController(),
    ),
    ChangeNotifierProvider<AudioController>(create: (_) => AudioController()),
    ChangeNotifierProvider<CommentAudioController>(
      create: (_) => CommentAudioController(),
    ),
  ];
}
