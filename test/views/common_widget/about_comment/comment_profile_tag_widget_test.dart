import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/api_client.dart';
import 'package:soi/api/controller/media_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/user.dart';
import 'package:soi/api/services/media_service.dart';
import 'package:soi/views/common_widget/about_comment/comment_profile_tag_widget.dart';
import 'package:soi/views/common_widget/about_comment/comment_save_payload.dart';
import 'package:soi/views/common_widget/about_comment/comment_for_pending.dart';
import 'package:soi/views/common_widget/photo/tag_pointer.dart';
import 'package:soi_api_client/api.dart';

class _NoopMediaApi extends APIApi {}

/// 댓글 태그 테스트에서 현재 사용자 이미지 변경을 직접 주입하는 컨트롤러입니다.
class _FakeUserController extends UserController {
  _FakeUserController({User? currentUser}) {
    setCurrentUser(currentUser);
  }
}

/// 댓글 태그 테스트에서 presigned URL 응답과 캐시 hit를 제어하는 미디어 컨트롤러입니다.
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

/// 테스트 케이스마다 같은 pending 댓글 payload를 간단히 재사용하도록 만듭니다.
CommentSavePayload _buildPayload({
  String? profileImageUrl,
  String? profileImageKey,
}) {
  return CommentSavePayload(
    postId: 1,
    userId: 7,
    kind: CommentDraftKind.text,
    text: 'pending comment',
    profileImageUrl: profileImageUrl,
    profileImageKey: profileImageKey,
  );
}

/// CommentProfileTagWidget을 MediaController provider와 함께 최소 환경으로 감싸 렌더링합니다.
Widget _buildHarness({
  required MediaController mediaController,
  UserController? userController,
  String? profileImageUrl,
  String? profileImageKey,
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
          child: CommentProfileTagWidget(
            payload: _buildPayload(
              profileImageUrl: profileImageUrl,
              profileImageKey: profileImageKey,
            ),
            avatarSize: kPendingCommentAvatarSize,
            resolveDropRelativePosition: () => const Offset(0.5, 0.5),
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

  testWidgets('placing tag keeps a 33 by 33 visible bubble', (tester) async {
    await tester.pumpWidget(
      _buildHarness(mediaController: _FakeMediaController()),
    );

    final tagSize = tester.getSize(find.byType(TagBubble));
    expect(tagSize.width, moreOrLessEquals(kPendingCommentTagSize));
  });

  testWidgets(
    'uses profileImageUrl immediately and keeps profileImageKey as cache key',
    (tester) async {
      const profileUrl = 'https://example.com/profiles/immediate.png';
      const profileKey = 'profiles/immediate.png';

      await tester.pumpWidget(
        _buildHarness(
          mediaController: _FakeMediaController(),
          profileImageUrl: profileUrl,
          profileImageKey: profileKey,
        ),
      );

      final networkImage = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(networkImage.imageUrl, profileUrl);
      expect(networkImage.cacheKey, profileKey);
    },
  );

  testWidgets('renders a network avatar only after resolving the profile key', (
    tester,
  ) async {
    const profileKey = 'profiles/me.png';
    const resolvedUrl = 'https://example.com/profiles/me.png';

    await tester.pumpWidget(
      _buildHarness(
        mediaController: _FakeMediaController(
          urls: const <String, String?>{profileKey: resolvedUrl},
          delay: const Duration(milliseconds: 20),
        ),
        profileImageKey: profileKey,
      ),
    );

    expect(find.byType(CachedNetworkImage), findsNothing);

    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    expect(find.byType(CachedNetworkImage), findsOneWidget);
    final networkImage = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(networkImage.imageUrl, resolvedUrl);
  });

  testWidgets(
    'uses current user selector image when pending payload is stale',
    (tester) async {
      final userController = _FakeUserController(
        currentUser: const User(
          id: 7,
          userId: 'me',
          name: '나',
          phoneNumber: '01000000000',
          profileImageUrl: 'https://example.com/profiles/current.png',
          profileImageKey: 'profiles/current.png',
        ),
      );

      await tester.pumpWidget(
        _buildHarness(
          mediaController: _FakeMediaController(),
          userController: userController,
          profileImageUrl: 'https://example.com/profiles/stale.png',
          profileImageKey: 'profiles/stale.png',
        ),
      );

      final networkImage = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(networkImage.imageUrl, 'https://example.com/profiles/current.png');
      expect(networkImage.cacheKey, 'profiles/current.png');
    },
  );
}
