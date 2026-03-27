import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/comment_controller.dart';
import 'package:soi/api/controller/media_controller.dart';
import 'package:soi/api/models/comment.dart';
import 'package:soi/api/services/comment_service.dart';
import 'package:soi/api/services/media_service.dart';
import 'package:soi/views/about_feed/manager/voice_comment_state_manager.dart';
import 'package:soi_api_client/api.dart';

class _NoopCommentApi extends CommentAPIApi {}

class _NoopMediaApi extends APIApi {}

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

void main() {
  testWidgets(
    'loadTagCommentsForPosts updates each post as soon as it finishes',
    (tester) async {
      final stateManager = VoiceCommentStateManager();
      final stateChanges = <Set<int>>[];
      BuildContext? capturedContext;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CommentController>(
              create: (_) => _FakeCommentController(
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
        stateChanges.add(stateManager.postTagComments.keys.toSet());
      });

      final request = stateManager.loadTagCommentsForPosts([
        1,
        2,
      ], capturedContext!);

      await tester.pump(const Duration(milliseconds: 10));

      expect(stateManager.postTagComments.containsKey(2), isTrue);
      expect(stateManager.postTagComments.containsKey(1), isFalse);
      expect(
        stateChanges.any((keys) => keys.length == 1 && keys.contains(2)),
        isTrue,
      );

      await tester.pump(const Duration(milliseconds: 40));
      await request;

      expect(stateManager.postTagComments[1]?.single.id, 11);
      expect(stateManager.postTagComments[2]?.single.id, 22);
    },
  );

  test(
    'handleCommentSaveSuccess updates tag cache without creating full cache',
    () {
      final stateManager = VoiceCommentStateManager();

      stateManager.handleCommentSaveSuccess(
        10,
        const Comment(
          id: 99,
          nickname: 'tagged',
          type: CommentType.text,
          locationX: 0.3,
          locationY: 0.8,
        ),
      );

      expect(stateManager.postComments.containsKey(10), isFalse);
      expect(stateManager.postTagComments[10]?.single.id, 99);
    },
  );
}
