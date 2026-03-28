import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soi/api/controller/comment_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/comment.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi/api/models/user.dart';
import 'package:soi/api/services/comment_service.dart';
import 'package:soi/api/services/user_service.dart';
import 'package:soi/views/common_widget/about_comment/comment_media_tag_preview_widget.dart';
import 'package:soi/views/common_widget/about_comment/api_voice_comment_list_sheet.dart';
import 'package:soi/views/common_widget/about_comment/pending_api_voice_comment.dart';
import 'package:soi/views/common_widget/api_photo/api_photo_card_widget.dart';
import 'package:soi/views/common_widget/api_photo/api_photo_display_widget.dart';
import 'package:soi/views/common_widget/api_photo/tag_pointer.dart';
import 'package:soi_api_client/api.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _InMemoryAssetLoader extends AssetLoader {
  const _InMemoryAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    return {
      'common': {
        'login_required': '로그인이 필요합니다.',
        'user_info_unavailable': '사용자 정보를 불러올 수 없습니다.',
      },
      'comments': {
        'title': '댓글',
        'add_comment': '댓글을 입력하세요',
        'empty': '댓글이 없습니다.',
        'reply_action': '답장 달기',
      },
    };
  }
}

class _NoopAuthApi extends AuthControllerApi {}

class _NoopCommentApi extends CommentAPIApi {}

class _NoopUserApi extends UserAPIApi {}

class _FakeUserController extends UserController {
  _FakeUserController()
    : super(
        userService: UserService(
          authApi: _NoopAuthApi(),
          userApi: _NoopUserApi(),
          onAuthTokenIssued: (_) {},
          onAuthTokenCleared: () {},
        ),
      ) {
    setCurrentUser(
      User(id: 1, userId: 'tester', name: '테스터', phoneNumber: '01000000000'),
    );
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDownAll(() {
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
  });

  Widget buildHarness({required List<Comment> comments}) {
    final post = Post(
      id: 100,
      nickName: 'tester',
      postFileKey: 'post.jpg',
      postFileUrl: 'https://example.com/post.jpg',
      createdAt: DateTime(2024, 1, 1),
    );

    return ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, child) => EasyLocalization(
        supportedLocales: const [Locale('ko')],
        path: 'assets/translations',
        fallbackLocale: const Locale('ko'),
        assetLoader: const _InMemoryAssetLoader(),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<UserController>(
              create: (_) => _FakeUserController(),
            ),
            ChangeNotifierProvider<CommentController>(
              create: (_) {
                final controller = CommentController(
                  commentService: CommentService(commentApi: _NoopCommentApi()),
                );
                controller.replaceCommentsCache(
                  postId: post.id,
                  comments: comments,
                );
                return controller;
              },
            ),
          ],
          child: Builder(
            builder: (easyCtx) => MaterialApp(
              localizationsDelegates: easyCtx.localizationDelegates,
              supportedLocales: easyCtx.supportedLocales,
              locale: easyCtx.locale,
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.only(top: 120),
                  child: child!,
                ),
              ),
            ),
          ),
        ),
      ),
      child: ApiPhotoCardWidget(
        post: post,
        categoryName: 'test',
        categoryId: 1,
        index: 0,
        isOwner: true,
        displayOnly: true,
        pendingCommentDrafts: <int, PendingApiCommentDraft>{},
        pendingVoiceComments: const <int, PendingApiCommentMarker>{},
        onToggleAudio: (_) {},
        onTextCommentCompleted: (_, __) {},
        onAudioCommentCompleted: (_, __, ___, ____) async {},
        onMediaCommentCompleted: (_, __, ___) async {},
        onProfileImageDragged: (_, __) {},
        onCommentSaveProgress: (_, __) {},
        onCommentSaveSuccess: (_, __) {},
        onCommentSaveFailure: (_, __) {},
        onDeletePressed: () {},
      ),
    );
  }

  Comment mediaComment({required double y}) {
    return Comment(
      id: 200,
      userId: 10,
      nickname: 'commenter',
      userProfileUrl: 'https://example.com/profile.jpg',
      fileUrl: 'https://example.com/comment.jpg',
      locationX: 0.5,
      locationY: y,
      type: CommentType.photo,
    );
  }

  testWidgets(
    'creates root overlay immediately and expands beyond media bounds',
    (tester) async {
      await tester.pumpWidget(buildHarness(comments: [mediaComment(y: 0.02)]));
      await tester.pump();

      expect(find.byType(TagBubble), findsOneWidget);
      expect(find.byType(CommentMediaTagPreviewWidget), findsNothing);

      await tester.tap(find.byType(TagBubble));
      await tester.pump();

      expect(find.byType(CommentMediaTagPreviewWidget), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ApiPhotoDisplayWidget),
          matching: find.byType(CommentMediaTagPreviewWidget),
        ),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('tapping expanded overlay collapses it', (tester) async {
    await tester.pumpWidget(buildHarness(comments: [mediaComment(y: 0.3)]));
    await tester.pump();

    await tester.tap(find.byType(TagBubble));
    await tester.pump();

    expect(find.byType(CommentMediaTagPreviewWidget), findsOneWidget);

    await tester.tap(find.byType(CommentMediaTagPreviewWidget));
    await tester.pump();

    expect(find.byType(CommentMediaTagPreviewWidget), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('outside tap dismisses expanded overlay', (tester) async {
    await tester.pumpWidget(buildHarness(comments: [mediaComment(y: 0.25)]));
    await tester.pump();

    await tester.tap(find.byType(TagBubble));
    await tester.pump();

    expect(find.byType(CommentMediaTagPreviewWidget), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pump();

    expect(find.byType(CommentMediaTagPreviewWidget), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'media-preview-unavailable tag opens comment sheet instead of overlay',
    (tester) async {
      final unavailableComment = Comment(
        id: 201,
        userId: 11,
        nickname: 'commenter',
        userProfileUrl: 'https://example.com/profile.jpg',
        locationX: 0.5,
        locationY: 0.3,
        type: CommentType.photo,
      );

      await tester.pumpWidget(buildHarness(comments: [unavailableComment]));
      await tester.pump();

      await tester.tap(find.byType(TagBubble));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(CommentMediaTagPreviewWidget), findsNothing);
      expect(find.byType(ApiVoiceCommentListSheet), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
