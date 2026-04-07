import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/media_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi/api/models/user.dart';
import 'package:soi/api/services/media_service.dart';
import 'package:soi/api/services/user_service.dart';
import 'package:soi/views/about_archiving/widgets/api_photo_grid_item.dart';
import 'package:soi_api_client/api.dart';

class _NoopMediaApi extends APIApi {}

class _NoopAuthApi extends AuthControllerApi {}

class _NoopUserApi extends UserAPIApi {}

/// 그리드 아이템 테스트에서 presigned URL 응답을 제어하는 미디어 컨트롤러입니다.
class _FakeMediaController extends MediaController {
  _FakeMediaController({
    this.urls = const <String, String?>{},
    this.delay = Duration.zero,
  }) : super(mediaService: MediaService(mediaApi: _NoopMediaApi()));

  final Map<String, String?> urls;
  final Duration delay;

  @override
  String? peekPresignedUrl(String key) => null;

  @override
  Future<String?> getPresignedUrl(String key) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return urls[key];
  }
}

/// 그리드 아바타가 현재 사용자 selector를 탈 수 있도록 테스트용 로그인 상태를 제공합니다.
class _FakeUserController extends UserController {
  _FakeUserController({User? user})
    : super(
        userService: UserService(
          authApi: _NoopAuthApi(),
          userApi: _NoopUserApi(),
          onAuthTokenIssued: (_) {},
          onAuthTokenCleared: () {},
        ),
      ) {
    setCurrentUser(
      user ??
          User(id: 1, userId: 'viewer', name: '뷰어', phoneNumber: '01000000000'),
    );
  }
}

/// 미디어와 작성자 아바타가 함께 보이는 이미지 post를 테스트용으로 생성합니다.
Post _buildPost({
  String? postFileUrl,
  String? postFileKey,
  String? profileImageUrl,
  String? profileImageKey,
}) {
  return Post(
    id: 10,
    nickName: 'grid-user',
    content: 'caption',
    postFileKey: postFileKey,
    postFileUrl: postFileUrl,
    userProfileImageKey: profileImageKey,
    userProfileImageUrl: profileImageUrl,
    createdAt: DateTime(2024, 1, 1),
    postType: PostType.multiMedia,
  );
}

/// ApiPhotoGridItem을 MediaController provider와 ScreenUtil 초기화가 포함된 최소 환경으로 감쌉니다.
Widget _buildHarness({
  required MediaController mediaController,
  required Post post,
  UserController? userController,
}) {
  final effectiveUserController = userController ?? _FakeUserController();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<MediaController>.value(value: mediaController),
      ChangeNotifierProvider<UserController>.value(
        value: effectiveUserController,
      ),
    ],
    child: ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 170,
              child: ApiPhotoGridItem(
                post: post,
                postUrl: post.postFileUrl ?? '',
                allPosts: <Post>[post],
                currentIndex: 0,
                categoryName: 'category',
                categoryId: 1,
                initialCommentCount: 0,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

CachedNetworkImage _findNetworkImage(
  WidgetTester tester, {
  required String cacheKey,
}) {
  return tester
      .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
      .singleWhere((image) => image.cacheKey == cacheKey);
}

void main() {
  testWidgets(
    'uses post and profile URLs immediately while keeping keys as cache keys',
    (tester) async {
      const postKey = 'posts/grid.jpg';
      const postUrl = 'https://example.com/posts/grid.jpg';
      const profileKey = 'profiles/grid.jpg';
      const profileUrl = 'https://example.com/profiles/grid.jpg';

      await tester.pumpWidget(
        _buildHarness(
          mediaController: _FakeMediaController(),
          post: _buildPost(
            postFileUrl: postUrl,
            postFileKey: postKey,
            profileImageUrl: profileUrl,
            profileImageKey: profileKey,
          ),
        ),
      );
      await tester.pump();

      expect(_findNetworkImage(tester, cacheKey: postKey).imageUrl, postUrl);
      expect(
        _findNetworkImage(tester, cacheKey: profileKey).imageUrl,
        profileUrl,
      );
    },
  );

  testWidgets(
    'resolves post and profile URLs from keys when immediate URLs are missing',
    (tester) async {
      const postKey = 'posts/grid.jpg';
      const postUrl = 'https://example.com/posts/grid.jpg';
      const profileKey = 'profiles/grid.jpg';
      const profileUrl = 'https://example.com/profiles/grid.jpg';

      await tester.pumpWidget(
        _buildHarness(
          mediaController: _FakeMediaController(
            urls: const <String, String?>{
              postKey: postUrl,
              profileKey: profileUrl,
            },
            delay: const Duration(milliseconds: 20),
          ),
          post: _buildPost(postFileKey: postKey, profileImageKey: profileKey),
        ),
      );
      await tester.pump();

      final initialImages = tester.widgetList<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(
        initialImages.where((image) => image.cacheKey == postKey),
        isEmpty,
      );
      expect(
        initialImages.where((image) => image.cacheKey == profileKey),
        isEmpty,
      );

      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump();

      expect(_findNetworkImage(tester, cacheKey: postKey).imageUrl, postUrl);
      expect(
        _findNetworkImage(tester, cacheKey: profileKey).imageUrl,
        profileUrl,
      );
    },
  );

  testWidgets(
    'renders media card when postType is media and only postFileUrl is present',
    (tester) async {
      const postUrl = 'https://example.com/posts/url-only.jpg';

      await tester.pumpWidget(
        _buildHarness(
          mediaController: _FakeMediaController(),
          post: _buildPost(postFileUrl: postUrl, postFileKey: null),
        ),
      );
      await tester.pump();

      final networkImages = tester.widgetList<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(networkImages.any((image) => image.imageUrl == postUrl), isTrue);
      expect(find.text('caption'), findsNothing);
    },
  );

  testWidgets(
    'overrides the grid avatar with the current user image without rebuilding the whole card',
    (tester) async {
      const fallbackProfileKey = 'profiles/fallback.jpg';
      const fallbackProfileUrl = 'https://example.com/profiles/fallback.jpg';
      const currentProfileKey = 'profiles/current.jpg';
      const currentProfileUrl = 'https://example.com/profiles/current.jpg';

      await tester.pumpWidget(
        _buildHarness(
          mediaController: _FakeMediaController(),
          userController: _FakeUserController(
            user: const User(
              id: 55,
              userId: 'grid-user',
              name: '그리드 사용자',
              profileImageKey: currentProfileKey,
              profileImageUrl: currentProfileUrl,
              phoneNumber: '01000000000',
            ),
          ),
          post: _buildPost(
            postFileUrl: 'https://example.com/posts/grid.jpg',
            postFileKey: 'posts/grid.jpg',
            profileImageUrl: fallbackProfileUrl,
            profileImageKey: fallbackProfileKey,
          ),
        ),
      );
      await tester.pump();

      expect(
        _findNetworkImage(tester, cacheKey: currentProfileKey).imageUrl,
        currentProfileUrl,
      );
    },
  );
}
