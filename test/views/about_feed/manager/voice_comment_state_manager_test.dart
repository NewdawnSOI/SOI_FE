import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/comment_controller.dart';
import 'package:soi/api/controller/media_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/comment.dart';
import 'package:soi/api/models/user.dart';
import 'package:soi/api/services/comment_service.dart';
import 'package:soi/api/services/media_service.dart';
import 'package:soi/api/services/user_service.dart';
import 'package:soi/views/about_feed/manager/voice_comment_state_manager.dart';
import 'package:soi_api_client/api.dart';

class _NoopAuthApi extends AuthControllerApi {}

class _NoopCommentApi extends CommentAPIApi {}

class _NoopMediaApi extends APIApi {}

class _NoopUserApi extends UserAPIApi {}

/// 태그 댓글 로드가 post 단위로 분리되는지 검증하기 위한 테스트용 댓글 컨트롤러입니다.
class _FakeCommentController extends CommentController {
  _FakeCommentController({this.onGetTagComments})
    : super(commentService: CommentService(commentApi: _NoopCommentApi()));

  final Future<List<Comment>> Function(int postId)? onGetTagComments;

  @override
  Future<List<Comment>> getTagComments({
    required int postId,
    bool forceReload = false,
  }) {
    final handler = onGetTagComments;
    if (handler == null) {
      throw UnsupportedError('Should not call getTagComments');
    }
    return handler(postId);
  }
}

class _FakeMediaController extends MediaController {
  _FakeMediaController()
    : super(mediaService: MediaService(mediaApi: _NoopMediaApi()));

  @override
  Future<List<String>> getPresignedUrls(List<String> keys) async {
    return List<String>.filled(keys.length, '');
  }
}

/// 저장 성공 후 임시 댓글 상태 정리를 검증하기 위한 테스트용 사용자 컨트롤러입니다.
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
      const User(
        id: 7,
        userId: 'tester',
        name: '테스터',
        phoneNumber: '01000000000',
      ),
    );
  }
}

void main() {
  testWidgets(
    'loadTagCommentsForPosts updates each post as soon as it finishes',
    (tester) async {
      final stateManager = VoiceCommentStateManager();
      final stateChanges = <Set<int>>[];
      late _FakeCommentController commentController;
      BuildContext? capturedContext;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CommentController>(
              create: (_) => commentController = _FakeCommentController(
                onGetTagComments: (postId) async {
                  if (postId == 1) {
                    await Future<void>.delayed(
                      const Duration(milliseconds: 40),
                    );
                    return const [
                      Comment(
                        id: 11,
                        nickname: 'slow',
                        type: CommentType.text,
                        locationX: 0.2,
                        locationY: 0.4,
                      ),
                    ];
                  }

                  await Future<void>.delayed(const Duration(milliseconds: 5));
                  return const [
                    Comment(
                      id: 22,
                      nickname: 'fast',
                      type: CommentType.text,
                      locationX: 0.6,
                      locationY: 0.3,
                    ),
                  ];
                },
              ),
            ),
            ChangeNotifierProvider<MediaController>(
              create: (_) => _FakeMediaController(),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      stateManager.setOnStateChanged(() {
        final loadedPostIds = <int>{};
        for (final postId in const [1, 2]) {
          if (commentController.peekTagCommentsCache(postId: postId) != null) {
            loadedPostIds.add(postId);
          }
        }
        stateChanges.add(loadedPostIds);
      });

      final request = stateManager.loadTagCommentsForPosts([
        1,
        2,
      ], capturedContext!);

      await tester.pump(const Duration(milliseconds: 10));

      expect(commentController.peekTagCommentsCache(postId: 2), isNotNull);
      expect(commentController.peekTagCommentsCache(postId: 1), isNull);
      expect(
        stateChanges.any((keys) => keys.length == 1 && keys.contains(2)),
        isTrue,
      );

      await tester.pump(const Duration(milliseconds: 40));
      await request;

      expect(commentController.peekTagCommentsCache(postId: 1)?.single.id, 11);
      expect(commentController.peekTagCommentsCache(postId: 2)?.single.id, 22);
    },
  );

  test(
    'handleCommentSaveSuccess clears pending draft state and marks the post as saved',
    () async {
      final stateManager = VoiceCommentStateManager();
      final userController = _FakeUserController();

      stateManager.toggleVoiceComment(10);
      await stateManager.onTextCommentCompleted(10, 'hello', userController);

      expect(stateManager.voiceCommentActiveStates[10], isTrue);
      expect(stateManager.pendingTextComments[10], isTrue);
      expect(stateManager.pendingCommentDrafts.containsKey(10), isTrue);

      stateManager.handleCommentSaveSuccess(
        10,
        const Comment(id: 99, nickname: 'tagged', type: CommentType.text),
      );

      expect(stateManager.voiceCommentSavedStates[10], isTrue);
      expect(stateManager.voiceCommentActiveStates[10], isFalse);
      expect(stateManager.pendingTextComments.containsKey(10), isFalse);
      expect(stateManager.pendingCommentDrafts.containsKey(10), isFalse);
      expect(stateManager.pendingVoiceComments.containsKey(10), isFalse);
    },
  );
}
