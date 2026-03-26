import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/media_controller.dart';
import 'package:soi/api/services/media_service.dart';
import 'package:soi/views/common_widget/about_comment/comment_profile_tag_widget.dart';
import 'package:soi/views/common_widget/about_comment/comment_save_payload.dart';
import 'package:soi/views/common_widget/about_comment/pending_api_voice_comment.dart';
import 'package:soi/views/common_widget/api_photo/tag_pointer.dart';
import 'package:soi_api_client/api.dart';

class _NoopMediaApi extends APIApi {}

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
  String? profileImageUrl,
  String? profileImageKey,
}) {
  return ChangeNotifierProvider<MediaController>.value(
    value: mediaController,
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

  testWidgets(
    'renders a network avatar only after resolving the profile key',
    (tester) async {
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
    },
  );
}
