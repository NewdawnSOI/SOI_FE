import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:soi/api/controller/audio_controller.dart';
import 'package:soi/api/controller/category_controller.dart' as api_category;
import 'package:soi/api/controller/category_search_controller.dart'
    as api_category_search;
import 'package:soi/api/controller/comment_audio_controller.dart';
import 'package:soi/api/controller/comment_controller.dart';
import 'package:soi/api/controller/contact_controller.dart';
import 'package:soi/api/controller/friend_controller.dart' as api_friend;
import 'package:soi/api/controller/media_controller.dart' as api_media;
import 'package:soi/api/controller/notification_controller.dart'
    as api_notification;
import 'package:soi/api/controller/post_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/views/about_feed/manager/feed_data_manager.dart';

List<SingleChildWidget> buildAppProviders(UserController userController) {
  return [
    ChangeNotifierProvider<UserController>.value(value: userController),
    ChangeNotifierProvider<api_category.CategoryController>(
      create: (_) => api_category.CategoryController(),
    ),
    ChangeNotifierProvider<api_category_search.CategorySearchController>(
      create: (_) => api_category_search.CategorySearchController(),
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
    ChangeNotifierProvider<ContactController>(
      create: (_) => ContactController(),
    ),
    ChangeNotifierProvider<AudioController>(create: (_) => AudioController()),
    ChangeNotifierProvider<CommentAudioController>(
      create: (_) => CommentAudioController(),
    ),
  ];
}
