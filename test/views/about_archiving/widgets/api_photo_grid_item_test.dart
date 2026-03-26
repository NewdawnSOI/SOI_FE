import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/media_controller.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi/api/services/media_service.dart';
import 'package:soi/views/about_archiving/widgets/api_photo_grid_item.dart';
import 'package:soi_api_client/api.dart';

class _NoopMediaApi extends APIApi {}

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
}) {
  return ChangeNotifierProvider<MediaController>.value(
    value: mediaController,
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
}
