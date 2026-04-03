import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/api_client.dart';
import 'package:soi/api/controller/media_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/user.dart';
import 'package:soi/api/services/media_service.dart';
import 'package:soi/views/about_archiving/widgets/archive_card_widget/api_archive_profile_row_widget.dart';
import 'package:soi_api_client/api.dart';

class _NoopMediaApi extends APIApi {}

/// 아카이브 프로필 행 테스트에서 현재 사용자 이미지를 직접 갱신하는 컨트롤러입니다.
class _FakeUserController extends UserController {
  _FakeUserController({User? currentUser}) {
    setCurrentUser(currentUser);
  }
}

/// 아카이브 프로필 행 테스트에서 presigned URL 응답을 제어하는 미디어 컨트롤러입니다.
class _FakeMediaController extends MediaController {
  _FakeMediaController({
    this.cachedUrls = const <String, String?>{},
    this.urls = const <String, String?>{},
    this.delay = Duration.zero,
  }) : super(mediaService: MediaService(mediaApi: _NoopMediaApi()));

  final Map<String, String?> cachedUrls;
  final Map<String, String?> urls;
  final Duration delay;

  @override
  String? peekPresignedUrl(String key) => cachedUrls[key];

  @override
  Future<String?> getPresignedUrl(String key) async {
    return urls[key];
  }

  @override
  Future<List<String>> getPresignedUrls(List<String> keys) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return [
      for (final key in keys)
        if ((urls[key] ?? '').isNotEmpty) urls[key]!,
    ];
  }
}

/// 공용 아카이브 프로필 행을 MediaController provider와 함께 최소 환경에서 렌더링합니다.
Widget _buildHarness({
  required MediaController mediaController,
  UserController? userController,
  List<String> profileImageUrls = const <String>[],
  List<String> profileImageKeys = const <String>[],
  List<String> memberNicknames = const <String>['member'],
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<MediaController>.value(value: mediaController),
      ChangeNotifierProvider<UserController>.value(
        value: userController ?? _FakeUserController(),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: ApiArchiveProfileRowWidget(
            profileImageUrls: profileImageUrls,
            profileImageKeys: profileImageKeys,
            memberNicknames: memberNicknames,
            totalUserCount: 1,
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SoiApiClient.instance.initialize();
    SoiApiClient.instance.clearAuthToken();
  });

  testWidgets(
    'uses profileImageUrl immediately and keeps profileImageKey as cache key',
    (tester) async {
      const profileUrl = 'https://example.com/category/member.png';
      const profileKey = 'category/member.png';

      await tester.pumpWidget(
        _buildHarness(
          mediaController: _FakeMediaController(),
          profileImageUrls: const <String>[profileUrl],
          profileImageKeys: const <String>[profileKey],
        ),
      );

      final networkImage = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(networkImage.imageUrl, profileUrl);
      expect(networkImage.cacheKey, profileKey);
    },
  );

  testWidgets('loads a fresh URL from profileImageKey when URL is missing', (
    tester,
  ) async {
    const profileKey = 'category/member.png';
    const resolvedUrl = 'https://example.com/category/member.png';

    await tester.pumpWidget(
      _buildHarness(
        mediaController: _FakeMediaController(
          urls: const <String, String?>{profileKey: resolvedUrl},
          delay: const Duration(milliseconds: 20),
        ),
        profileImageKeys: const <String>[profileKey],
      ),
    );

    expect(find.byType(CachedNetworkImage), findsNothing);

    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    final networkImage = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(networkImage.imageUrl, resolvedUrl);
    expect(networkImage.cacheKey, profileKey);
  });

  testWidgets(
    'uses current user image selection when the row entry is my nickname',
    (tester) async {
      final userController = _FakeUserController(
        currentUser: const User(
          id: 7,
          userId: 'me',
          name: '나',
          phoneNumber: '01000000000',
          profileImageUrl: 'https://example.com/profiles/me-current.png',
          profileImageKey: 'profiles/me-current.png',
        ),
      );

      await tester.pumpWidget(
        _buildHarness(
          mediaController: _FakeMediaController(),
          userController: userController,
          profileImageUrls: const <String>[
            'https://example.com/profiles/stale.png',
          ],
          profileImageKeys: const <String>['profiles/stale.png'],
          memberNicknames: const <String>['me'],
        ),
      );

      final networkImage = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(
        networkImage.imageUrl,
        'https://example.com/profiles/me-current.png',
      );
      expect(networkImage.cacheKey, 'profiles/me-current.png');
    },
  );
}
