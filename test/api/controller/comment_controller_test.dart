import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/controller/comment_controller.dart';
import 'package:soi/api/models/comment.dart';
import 'package:soi/api/models/comment_creation_result.dart';
import 'package:soi/api/services/comment_service.dart';
import 'package:soi_api_client/api.dart';

class _NoopCommentApi extends CommentAPIApi {}

typedef _CreateCommentHandler =
    Future<CommentCreationResult> Function({
      required int postId,
      required int userId,
      int? emojiId,
      int? parentId,
      int? replyUserId,
      String? text,
      String? audioFileKey,
      String? fileKey,
      String? waveformData,
      int? duration,
      double? locationX,
      double? locationY,
      CommentType? type,
    });

typedef _GetCommentsHandler =
    Future<List<Comment>> Function({required int postId});

class _FakeCommentService extends CommentService {
  _FakeCommentService({
    required this.onCreate,
    this.onGetByUserId,
    this.onGetComments,
  }) : super(commentApi: _NoopCommentApi());

  final _CreateCommentHandler onCreate;
  final _GetCommentsHandler? onGetComments;
  final Future<({List<Comment> comments, bool hasMore})> Function({
    required int userId,
    required int page,
  })?
  onGetByUserId;

  @override
  Future<CommentCreationResult> createComment({
    required int postId,
    required int userId,
    int? emojiId,
    int? parentId,
    int? replyUserId,
    String? text,
    String? audioFileKey,
    String? fileKey,
    String? waveformData,
    int? duration,
    double? locationX,
    double? locationY,
    CommentType? type,
  }) {
    return onCreate(
      postId: postId,
      userId: userId,
      emojiId: emojiId,
      parentId: parentId,
      replyUserId: replyUserId,
      text: text,
      audioFileKey: audioFileKey,
      fileKey: fileKey,
      waveformData: waveformData,
      duration: duration,
      locationX: locationX,
      locationY: locationY,
      type: type,
    );
  }

  @override
  Future<List<Comment>> getComments({required int postId}) {
    final handler = onGetComments;
    if (handler == null) {
      throw UnsupportedError('Should not call getComments');
    }
    return handler(postId: postId);
  }

  @override
  Future<CommentCreationResult> createTextComment({
    required int postId,
    required int userId,
    required String text,
    required double locationX,
    required double locationY,
  }) async {
    throw UnsupportedError('Should route through createComment');
  }

  @override
  Future<CommentCreationResult> createAudioComment({
    required int postId,
    required int userId,
    required String audioFileKey,
    required String waveformData,
    required int duration,
    required double locationX,
    required double locationY,
  }) async {
    throw UnsupportedError('Should route through createComment');
  }

  @override
  Future<({List<Comment> comments, bool hasMore})> getCommentsByUserId({
    required int userId,
    int page = 0,
  }) {
    final handler = onGetByUserId;
    if (handler == null) {
      throw UnsupportedError('Should not call getCommentsByUserId');
    }
    return handler(userId: userId, page: page);
  }
}

void main() {
  group('CommentController convenience methods', () {
    test(
      'createTextComment routes through createComment payload path',
      () async {
        int? capturedPostId;
        int? capturedUserId;
        int? capturedEmojiId;
        int? capturedParentId;
        int? capturedReplyUserId;
        String? capturedText;
        String? capturedAudioKey;
        String? capturedFileKey;
        String? capturedWaveform;
        int? capturedDuration;
        double? capturedLocationX;
        double? capturedLocationY;
        CommentType? capturedType;

        final controller = CommentController(
          commentService: _FakeCommentService(
            onCreate:
                ({
                  required int postId,
                  required int userId,
                  int? emojiId,
                  int? parentId,
                  int? replyUserId,
                  String? text,
                  String? audioFileKey,
                  String? fileKey,
                  String? waveformData,
                  int? duration,
                  double? locationX,
                  double? locationY,
                  CommentType? type,
                }) async {
                  capturedPostId = postId;
                  capturedUserId = userId;
                  capturedEmojiId = emojiId;
                  capturedParentId = parentId;
                  capturedReplyUserId = replyUserId;
                  capturedText = text;
                  capturedAudioKey = audioFileKey;
                  capturedFileKey = fileKey;
                  capturedWaveform = waveformData;
                  capturedDuration = duration;
                  capturedLocationX = locationX;
                  capturedLocationY = locationY;
                  capturedType = type;
                  return const CommentCreationResult(success: true);
                },
          ),
        );

        final result = await controller.createTextComment(
          postId: 10,
          userId: 20,
          text: 'hello',
          locationX: 0.4,
          locationY: 0.6,
        );

        expect(result.success, isTrue);
        expect(capturedPostId, 10);
        expect(capturedUserId, 20);
        expect(capturedEmojiId, 0);
        expect(capturedParentId, 0);
        expect(capturedReplyUserId, 0);
        expect(capturedText, 'hello');
        expect(capturedAudioKey, '');
        expect(capturedFileKey, '');
        expect(capturedWaveform, '');
        expect(capturedDuration, 0);
        expect(capturedLocationX, 0.4);
        expect(capturedLocationY, 0.6);
        expect(capturedType, CommentType.text);
      },
    );

    test(
      'createAudioComment routes through createComment payload path',
      () async {
        int? capturedPostId;
        int? capturedUserId;
        int? capturedEmojiId;
        int? capturedParentId;
        int? capturedReplyUserId;
        String? capturedText;
        String? capturedAudioKey;
        String? capturedFileKey;
        String? capturedWaveform;
        int? capturedDuration;
        double? capturedLocationX;
        double? capturedLocationY;
        CommentType? capturedType;

        final controller = CommentController(
          commentService: _FakeCommentService(
            onCreate:
                ({
                  required int postId,
                  required int userId,
                  int? emojiId,
                  int? parentId,
                  int? replyUserId,
                  String? text,
                  String? audioFileKey,
                  String? fileKey,
                  String? waveformData,
                  int? duration,
                  double? locationX,
                  double? locationY,
                  CommentType? type,
                }) async {
                  capturedPostId = postId;
                  capturedUserId = userId;
                  capturedEmojiId = emojiId;
                  capturedParentId = parentId;
                  capturedReplyUserId = replyUserId;
                  capturedText = text;
                  capturedAudioKey = audioFileKey;
                  capturedFileKey = fileKey;
                  capturedWaveform = waveformData;
                  capturedDuration = duration;
                  capturedLocationX = locationX;
                  capturedLocationY = locationY;
                  capturedType = type;
                  return const CommentCreationResult(success: true);
                },
          ),
        );

        final result = await controller.createAudioComment(
          postId: 11,
          userId: 22,
          audioFileKey: 'audio/key.m4a',
          waveformData: '1,2,3',
          duration: 9,
          locationX: 0.2,
          locationY: 0.8,
        );

        expect(result.success, isTrue);
        expect(capturedPostId, 11);
        expect(capturedUserId, 22);
        expect(capturedEmojiId, 0);
        expect(capturedParentId, 0);
        expect(capturedReplyUserId, 0);
        expect(capturedText, '');
        expect(capturedAudioKey, 'audio/key.m4a');
        expect(capturedFileKey, '');
        expect(capturedWaveform, '1,2,3');
        expect(capturedDuration, 9);
        expect(capturedLocationX, 0.2);
        expect(capturedLocationY, 0.8);
        expect(capturedType, CommentType.audio);
      },
    );

    test('createComment treats parentId/replyUserId 0 as non-reply', () async {
      int? capturedParentId;
      int? capturedReplyUserId;
      String? capturedText;
      String? capturedAudioKey;
      String? capturedFileKey;
      String? capturedWaveform;
      int? capturedDuration;
      double? capturedLocationX;
      double? capturedLocationY;
      CommentType? capturedType;

      final controller = CommentController(
        commentService: _FakeCommentService(
          onCreate:
              ({
                required int postId,
                required int userId,
                int? emojiId,
                int? parentId,
                int? replyUserId,
                String? text,
                String? audioFileKey,
                String? fileKey,
                String? waveformData,
                int? duration,
                double? locationX,
                double? locationY,
                CommentType? type,
              }) async {
                capturedParentId = parentId;
                capturedReplyUserId = replyUserId;
                capturedText = text;
                capturedAudioKey = audioFileKey;
                capturedFileKey = fileKey;
                capturedWaveform = waveformData;
                capturedDuration = duration;
                capturedLocationX = locationX;
                capturedLocationY = locationY;
                capturedType = type;
                return const CommentCreationResult(success: true);
              },
        ),
      );

      final result = await controller.createComment(
        postId: 77,
        userId: 88,
        parentId: 0,
        replyUserId: 0,
        text: 'reply-check',
      );

      expect(result.success, isTrue);
      expect(capturedParentId, 0);
      expect(capturedReplyUserId, 0);
      expect(capturedText, 'reply-check');
      expect(capturedAudioKey, '');
      expect(capturedFileKey, '');
      expect(capturedWaveform, '');
      expect(capturedDuration, 0);
      expect(capturedLocationX, 0.0);
      expect(capturedLocationY, 0.0);
      expect(capturedType, CommentType.text);
    });

    test('createComment keeps audio payload for reply comment', () async {
      int? capturedParentId;
      int? capturedReplyUserId;
      String? capturedText;
      String? capturedAudioKey;
      String? capturedWaveform;
      int? capturedDuration;
      CommentType? capturedType;

      final controller = CommentController(
        commentService: _FakeCommentService(
          onCreate:
              ({
                required int postId,
                required int userId,
                int? emojiId,
                int? parentId,
                int? replyUserId,
                String? text,
                String? audioFileKey,
                String? fileKey,
                String? waveformData,
                int? duration,
                double? locationX,
                double? locationY,
                CommentType? type,
              }) async {
                capturedParentId = parentId;
                capturedReplyUserId = replyUserId;
                capturedText = text;
                capturedAudioKey = audioFileKey;
                capturedWaveform = waveformData;
                capturedDuration = duration;
                capturedType = type;
                return const CommentCreationResult(success: true);
              },
        ),
      );

      final result = await controller.createComment(
        postId: 77,
        userId: 88,
        parentId: 12,
        replyUserId: 34,
        audioKey: 'reply/audio.m4a',
        waveformData: '[0.1,0.2]',
        duration: 5,
        type: CommentType.reply,
      );

      expect(result.success, isTrue);
      expect(capturedParentId, 12);
      expect(capturedReplyUserId, 34);
      expect(capturedText, '');
      expect(capturedAudioKey, 'reply/audio.m4a');
      expect(capturedWaveform, '[0.1,0.2]');
      expect(capturedDuration, 5);
      expect(capturedType, CommentType.reply);
    });

    test('getCommentsByUserId forwards paging params to service', () async {
      int? capturedUserId;
      int? capturedPage;

      final controller = CommentController(
        commentService: _FakeCommentService(
          onCreate:
              ({
                required int postId,
                required int userId,
                int? emojiId,
                int? parentId,
                int? replyUserId,
                String? text,
                String? audioFileKey,
                String? fileKey,
                String? waveformData,
                int? duration,
                double? locationX,
                double? locationY,
                CommentType? type,
              }) async => const CommentCreationResult(success: true),
          onGetByUserId: ({required int userId, required int page}) async {
            capturedUserId = userId;
            capturedPage = page;
            return (
              comments: const [
                Comment(id: 1, nickname: 'a', type: CommentType.text),
              ],
              hasMore: true,
            );
          },
        ),
      );

      final result = await controller.getCommentsByUserId(userId: 7, page: 2);

      expect(capturedUserId, 7);
      expect(capturedPage, 2);
      expect(result.comments, hasLength(1));
      expect(result.hasMore, isTrue);
    });

    test(
      'dedupes in-flight getComments requests and keeps loading stable',
      () async {
        final commentsCompleter = Completer<List<Comment>>();
        var callCount = 0;

        final controller = CommentController(
          commentService: _FakeCommentService(
            onCreate:
                ({
                  required int postId,
                  required int userId,
                  int? emojiId,
                  int? parentId,
                  int? replyUserId,
                  String? text,
                  String? audioFileKey,
                  String? fileKey,
                  String? waveformData,
                  int? duration,
                  double? locationX,
                  double? locationY,
                  CommentType? type,
                }) async => const CommentCreationResult(success: true),
            onGetComments: ({required int postId}) {
              callCount++;
              return commentsCompleter.future;
            },
          ),
        );

        final first = controller.getComments(postId: 5);
        final second = controller.getComments(postId: 5);

        expect(controller.isLoading, isTrue);

        commentsCompleter.complete([
          const Comment(id: 1, nickname: 'n', type: CommentType.text),
        ]);

        final results = await Future.wait([first, second]);

        expect(callCount, 1);
        expect(results[0], hasLength(1));
        expect(results[1].single.id, 1);
        expect(controller.isLoading, isFalse);
      },
    );
  });
}
