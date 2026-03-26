import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/api_exception.dart';
import 'package:soi/api/models/comment.dart';
import 'package:soi/api/services/comment_service.dart';
import 'package:soi_api_client/api.dart';

class _FakeCommentApi extends CommentAPIApi {
  _FakeCommentApi({
    required this.onGetParentComment,
    required this.onGetChildComment,
    this.onGetAllCommentByUserId,
  });

  final Future<ApiResponseDtoSliceCommentRespDto?> Function(
    int postId,
    int page,
  )
  onGetParentComment;
  final Future<ApiResponseDtoSliceCommentRespDto?> Function(
    int parentCommentId,
    int page,
  )
  onGetChildComment;
  final Future<ApiResponseDtoSliceCommentRespDto?> Function(int page)?
  onGetAllCommentByUserId;

  @override
  Future<ApiResponseDtoSliceCommentRespDto?> getParentComment(
    int postId,
    int page,
  ) {
    return onGetParentComment(postId, page);
  }

  @override
  Future<ApiResponseDtoSliceCommentRespDto?> getChildComment(
    int parentCommentId,
    int page,
  ) {
    return onGetChildComment(parentCommentId, page);
  }

  @override
  Future<ApiResponseDtoSliceCommentRespDto?> getAllCommentByUserId(int page) {
    final handler = onGetAllCommentByUserId;
    if (handler == null) {
      throw UnimplementedError('onGetAllCommentByUserId is not configured');
    }
    return handler(page);
  }
}

class _CreateCommentApi extends CommentAPIApi {
  _CreateCommentApi({required this.onCreate});

  final Future<ApiResponseDtoObject?> Function(CommentReqDto dto) onCreate;

  @override
  Future<ApiResponseDtoObject?> create3(CommentReqDto commentReqDto) {
    return onCreate(commentReqDto);
  }
}

ApiResponseDtoSliceCommentRespDto _sliceResponse({
  required List<CommentRespDto> content,
  required bool last,
  required bool empty,
  bool success = true,
  String? message,
}) {
  return ApiResponseDtoSliceCommentRespDto(
    success: success,
    message: message,
    data: SliceCommentRespDto(content: content, last: last, empty: empty),
  );
}

CommentRespDto _commentDto(int id, {DateTime? createdAt}) {
  return CommentRespDto(
    id: id,
    nickname: 'user$id',
    commentType: CommentRespDtoCommentTypeEnum.TEXT,
    createdAt: createdAt,
  );
}

void main() {
  group('CommentService createComment payload normalization', () {
    test('fills null values with 0/empty defaults for text comment', () async {
      CommentReqDto? capturedDto;

      final service = CommentService(
        commentApi: _CreateCommentApi(
          onCreate: (dto) async {
            capturedDto = dto;
            return ApiResponseDtoObject(success: true, data: null);
          },
        ),
      );

      final result = await service.createComment(
        postId: 182,
        userId: 46,
        text: '  댓글 작성 테스트 46  ',
        locationX: 0.7,
        locationY: 0.7,
        type: CommentType.text,
      );

      expect(result.success, isTrue);
      expect(capturedDto, isNotNull);
      expect(capturedDto!.userId, 46);
      expect(capturedDto!.postId, 182);
      expect(capturedDto!.emojiId, 0);
      expect(capturedDto!.parentId, 0);
      expect(capturedDto!.replyUserId, 0);
      expect(capturedDto!.text, '댓글 작성 테스트 46');
      expect(capturedDto!.audioKey, '');
      expect(capturedDto!.fileKey, '');
      expect(capturedDto!.waveformData, '');
      expect(capturedDto!.duration, 0);
      expect(capturedDto!.locationX, 0.7);
      expect(capturedDto!.locationY, 0.7);
      expect(capturedDto!.commentType, CommentReqDtoCommentTypeEnum.TEXT);
    });

    test(
      'keeps audio payload and converts waveform for audio comment',
      () async {
        CommentReqDto? capturedDto;

        final service = CommentService(
          commentApi: _CreateCommentApi(
            onCreate: (dto) async {
              capturedDto = dto;
              return ApiResponseDtoObject(success: true, data: null);
            },
          ),
        );

        final result = await service.createComment(
          postId: 50,
          userId: 60,
          audioFileKey: 'audio/key.m4a',
          waveformData: '[0.1,0.2,0.3]',
          duration: 9,
          type: CommentType.audio,
        );

        expect(result.success, isTrue);
        expect(capturedDto, isNotNull);
        expect(capturedDto!.emojiId, 0);
        expect(capturedDto!.parentId, 0);
        expect(capturedDto!.replyUserId, 0);
        expect(capturedDto!.text, '');
        expect(capturedDto!.audioKey, 'audio/key.m4a');
        expect(capturedDto!.fileKey, '');
        expect(capturedDto!.waveformData, '0.1,0.2,0.3');
        expect(capturedDto!.duration, 9);
        expect(capturedDto!.locationX, 0.0);
        expect(capturedDto!.locationY, 0.0);
        expect(capturedDto!.commentType, CommentReqDtoCommentTypeEnum.AUDIO);
      },
    );
  });

  group('CommentService getComments pagination', () {
    test('dedupes in-flight getComments requests by postId', () async {
      final parentCompleter = Completer<ApiResponseDtoSliceCommentRespDto?>();
      var parentCallCount = 0;

      final service = CommentService(
        commentApi: _FakeCommentApi(
          onGetParentComment: (postId, page) {
            parentCallCount++;
            return parentCompleter.future;
          },
          onGetChildComment: (parentCommentId, page) async => null,
        ),
      );

      final first = service.getComments(postId: 77);
      final second = service.getComments(postId: 77);

      parentCompleter.complete(
        _sliceResponse(content: const [], last: true, empty: true),
      );

      final results = await Future.wait([first, second]);

      expect(parentCallCount, 1);
      expect(results[0], isEmpty);
      expect(results[1], isEmpty);
    });

    test('merges parent and child comment pages', () async {
      final parentCalls = <String>[];
      final childCalls = <String>[];

      final service = CommentService(
        commentApi: _FakeCommentApi(
          onGetParentComment: (postId, page) async {
            parentCalls.add('$postId:$page');
            if (page == 0) {
              return _sliceResponse(
                content: [
                  _commentDto(
                    1,
                    createdAt: DateTime.parse('2026-03-08T10:00:00Z'),
                  ),
                  _commentDto(2),
                ],
                last: false,
                empty: false,
              );
            }
            if (page == 1) {
              return _sliceResponse(
                content: [_commentDto(3)],
                last: true,
                empty: false,
              );
            }
            return null;
          },
          onGetChildComment: (parentCommentId, page) async {
            childCalls.add('$parentCommentId:$page');
            if (page != 0) {
              return null;
            }
            switch (parentCommentId) {
              case 1:
                return _sliceResponse(
                  content: [_commentDto(11)],
                  last: true,
                  empty: false,
                );
              case 2:
                return _sliceResponse(content: [], last: true, empty: true);
              case 3:
                return _sliceResponse(
                  content: [_commentDto(31), _commentDto(32)],
                  last: true,
                  empty: false,
                );
              default:
                return null;
            }
          },
        ),
      );

      final comments = await service.getComments(postId: 99);

      expect(parentCalls, ['99:0', '99:1']);
      expect(childCalls, ['1:0', '2:0', '3:0']);
      expect(comments.map((e) => e.id), [1, 11, 2, 3, 31, 32]);
      expect(comments.first.createdAt, DateTime.parse('2026-03-08T10:00:00Z'));
    });

    test(
      'fetches child comment groups in parallel while preserving order',
      () async {
        final firstChildCompleter =
            Completer<ApiResponseDtoSliceCommentRespDto?>();
        final secondChildCompleter =
            Completer<ApiResponseDtoSliceCommentRespDto?>();
        final childCalls = <String>[];

        final service = CommentService(
          commentApi: _FakeCommentApi(
            onGetParentComment: (postId, page) async {
              if (page > 0) return null;
              return _sliceResponse(
                content: [_commentDto(1), _commentDto(2)],
                last: true,
                empty: false,
              );
            },
            onGetChildComment: (parentCommentId, page) {
              childCalls.add('$parentCommentId:$page');
              if (parentCommentId == 1) {
                return firstChildCompleter.future;
              }
              return secondChildCompleter.future;
            },
          ),
        );

        final request = service.getComments(postId: 55);
        await Future<void>.delayed(Duration.zero);

        expect(childCalls, ['1:0', '2:0']);

        secondChildCompleter.complete(
          _sliceResponse(content: [_commentDto(21)], last: true, empty: false),
        );
        firstChildCompleter.complete(
          _sliceResponse(content: [_commentDto(11)], last: true, empty: false),
        );

        final comments = await request;
        expect(comments.map((comment) => comment.id), [1, 11, 2, 21]);
      },
    );

    test(
      'throws SoiApiException when slice response reports failure',
      () async {
        final service = CommentService(
          commentApi: _FakeCommentApi(
            onGetParentComment: (postId, page) async {
              return _sliceResponse(
                content: [],
                last: true,
                empty: true,
                success: false,
                message: '조회 실패',
              );
            },
            onGetChildComment: (parentCommentId, page) async => null,
          ),
        );

        await expectLater(
          service.getComments(postId: 99),
          throwsA(
            isA<SoiApiException>().having(
              (e) => e.message,
              'message',
              contains('조회 실패'),
            ),
          ),
        );
      },
    );
  });

  group('CommentService parent/child slice queries', () {
    test('getParentComments maps slice response and exposes hasMore', () async {
      final service = CommentService(
        commentApi: _FakeCommentApi(
          onGetParentComment: (postId, page) async {
            expect(postId, 55);
            expect(page, 3);
            return _sliceResponse(
              content: [_commentDto(201), _commentDto(202)],
              last: false,
              empty: false,
            );
          },
          onGetChildComment: (parentCommentId, page) async => null,
        ),
      );

      final result = await service.getParentComments(postId: 55, page: 3);

      expect(result.comments.map((comment) => comment.id), [201, 202]);
      expect(result.hasMore, isTrue);
    });

    test('dedupes in-flight getChildComments requests', () async {
      final sliceCompleter = Completer<ApiResponseDtoSliceCommentRespDto?>();
      var callCount = 0;

      final service = CommentService(
        commentApi: _FakeCommentApi(
          onGetParentComment: (postId, page) async => null,
          onGetChildComment: (parentCommentId, page) {
            callCount++;
            expect(parentCommentId, 12);
            expect(page, 1);
            return sliceCompleter.future;
          },
        ),
      );

      final first = service.getChildComments(parentCommentId: 12, page: 1);
      final second = service.getChildComments(parentCommentId: 12, page: 1);

      sliceCompleter.complete(
        _sliceResponse(content: [_commentDto(301)], last: true, empty: false),
      );

      final results = await Future.wait([first, second]);

      expect(callCount, 1);
      expect(results[0].comments.single.id, 301);
      expect(results[1].hasMore, isFalse);
    });
  });

  group('CommentService getCommentsByUserId', () {
    test('maps slice response and exposes hasMore', () async {
      final service = CommentService(
        commentApi: _FakeCommentApi(
          onGetParentComment: (postId, page) async => null,
          onGetChildComment: (parentCommentId, page) async => null,
          onGetAllCommentByUserId: (page) async {
            expect(page, 1);
            return _sliceResponse(
              content: [_commentDto(100), _commentDto(101)],
              last: false,
              empty: false,
            );
          },
        ),
      );

      final result = await service.getCommentsByUserId(userId: 42, page: 1);

      expect(result.comments.map((comment) => comment.id), [100, 101]);
      expect(result.hasMore, isTrue);
    });

    test('dedupes in-flight getCommentsByUserId requests', () async {
      final sliceCompleter = Completer<ApiResponseDtoSliceCommentRespDto?>();
      var callCount = 0;

      final service = CommentService(
        commentApi: _FakeCommentApi(
          onGetParentComment: (postId, page) async => null,
          onGetChildComment: (parentCommentId, page) async => null,
          onGetAllCommentByUserId: (page) {
            callCount++;
            return sliceCompleter.future;
          },
        ),
      );

      final first = service.getCommentsByUserId(userId: 1, page: 2);
      final second = service.getCommentsByUserId(userId: 1, page: 2);

      sliceCompleter.complete(
        _sliceResponse(content: [_commentDto(9)], last: true, empty: false),
      );

      final results = await Future.wait([first, second]);

      expect(callCount, 1);
      expect(results[0].comments.single.id, 9);
      expect(results[1].hasMore, isFalse);
    });
  });
}
