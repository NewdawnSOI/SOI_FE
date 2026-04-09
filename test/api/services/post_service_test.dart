import 'package:flutter_test/flutter_test.dart';
import 'package:soi_api_client/api.dart';
import 'package:soi/api/api_exception.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi/api/services/post_service.dart';

class _FakePostApi extends PostAPIApi {
  _FakePostApi({this.onCreate, this.onUpdate});

  final Future<ApiResponseDtoBoolean?> Function(PostCreateReqDto)? onCreate;
  final Future<ApiResponseDtoObject?> Function(PostUpdateReqDto)? onUpdate;

  @override
  Future<ApiResponseDtoBoolean?> create1(
    PostCreateReqDto postCreateReqDto,
  ) async {
    final handler = onCreate;
    if (handler == null) {
      throw UnimplementedError('onCreate is not configured');
    }
    return handler(postCreateReqDto);
  }

  @override
  Future<ApiResponseDtoObject?> update3(
    PostUpdateReqDto postUpdateReqDto,
  ) async {
    final handler = onUpdate;
    if (handler == null) {
      throw UnimplementedError('onUpdate is not configured');
    }
    return handler(postUpdateReqDto);
  }
}

void main() {
  group('PostService postType mapping', () {
    test(
      'uses explicit TEXT postType for create and keeps categoryIds/content',
      () async {
        PostCreateReqDto? capturedDto;
        final service = PostService(
          postApi: _FakePostApi(
            onCreate: (dto) async {
              capturedDto = dto;
              return ApiResponseDtoBoolean(success: true, data: true);
            },
          ),
        );

        final result = await service.createPost(
          nickName: 'tester',
          content: 'text-only content',
          postFileKey: const [],
          audioFileKey: const [],
          categoryIds: const [10, 20],
          postType: PostType.textOnly,
        );

        expect(result, isTrue);
        expect(capturedDto?.postType, PostCreateReqDtoPostTypeEnum.TEXT);
        expect(capturedDto?.categoryId, const [10, 20]);
        expect(capturedDto?.content, 'text-only content');
      },
    );

    test('infers TEXT for create when media key list is empty', () async {
      PostCreateReqDto? capturedDto;
      final service = PostService(
        postApi: _FakePostApi(
          onCreate: (dto) async {
            capturedDto = dto;
            return ApiResponseDtoBoolean(success: true, data: true);
          },
        ),
      );

      final result = await service.createPost(
        nickName: 'tester',
        postFileKey: const [],
      );

      expect(result, isTrue);
      expect(capturedDto?.postType, PostCreateReqDtoPostTypeEnum.TEXT);
    });

    test(
      'infers IMAGE for create when image media key list is present',
      () async {
        PostCreateReqDto? capturedDto;
        final service = PostService(
          postApi: _FakePostApi(
            onCreate: (dto) async {
              capturedDto = dto;
              return ApiResponseDtoBoolean(success: true, data: true);
            },
          ),
        );

        final result = await service.createPost(
          nickName: 'tester',
          postFileKey: const ['posts/example.jpg'],
        );

        expect(result, isTrue);
        expect(capturedDto?.postType, PostCreateReqDtoPostTypeEnum.IMAGE);
      },
    );

    test(
      'maps update postType to VIDEO when video postFileKey is provided',
      () async {
        PostUpdateReqDto? capturedDto;
        final service = PostService(
          postApi: _FakePostApi(
            onUpdate: (dto) async {
              capturedDto = dto;
              return ApiResponseDtoObject(success: true, data: true);
            },
          ),
        );

        final result = await service.updatePost(
          postId: 1,
          postFileKey: 'posts/example.mp4',
        );

        expect(result, isTrue);
        expect(capturedDto?.postType, PostUpdateReqDtoPostTypeEnum.VIDEO);
      },
    );

    test('allows explicit postType override for create', () async {
      PostCreateReqDto? capturedDto;
      final service = PostService(
        postApi: _FakePostApi(
          onCreate: (dto) async {
            capturedDto = dto;
            return ApiResponseDtoBoolean(success: true, data: true);
          },
        ),
      );

      final result = await service.createPost(
        nickName: 'tester',
        postFileKey: const ['posts/example.jpg'],
        postType: PostType.textOnly,
      );

      expect(result, isTrue);
      expect(capturedDto?.postType, PostCreateReqDtoPostTypeEnum.TEXT);
    });

    test('forwards isFromGallery to create payload', () async {
      PostCreateReqDto? capturedDto;
      final service = PostService(
        postApi: _FakePostApi(
          onCreate: (dto) async {
            capturedDto = dto;
            return ApiResponseDtoBoolean(success: true, data: true);
          },
        ),
      );

      final result = await service.createPost(
        nickName: 'tester',
        postFileKey: const ['posts/example.jpg'],
        isFromGallery: true,
      );

      expect(result, isTrue);
      expect(capturedDto?.isFromGallery, isTrue);
    });

    test(
      'pads missing audio slots to match category count for create payload',
      () async {
        PostCreateReqDto? capturedDto;
        final service = PostService(
          postApi: _FakePostApi(
            onCreate: (dto) async {
              capturedDto = dto;
              return ApiResponseDtoBoolean(success: true, data: true);
            },
          ),
        );

        final result = await service.createPost(
          nickName: 'tester',
          postFileKey: const ['posts/example.jpg'],
          audioFileKey: const [],
          categoryIds: const [16],
          postType: PostType.image,
        );

        expect(result, isTrue);
        expect(capturedDto?.postFileKey, const ['posts/example.jpg']);
        expect(capturedDto?.audioFileKey, const ['']);
      },
    );
  });

  group('PostService exception handling', () {
    test('SoiApiException은 래핑 없이 그대로 rethrow됨', () async {
      final original = SoiApiException(message: '원본 예외', statusCode: 422);
      final service = PostService(
        postApi: _FakePostApi(onCreate: (_) async => throw original),
      );

      SoiApiException? caught;
      try {
        await service.createPost(nickName: 'tester');
      } on SoiApiException catch (e) {
        caught = e;
      }

      expect(
        caught,
        same(original),
        reason: 'SoiApiException은 wrap 없이 동일 인스턴스로 rethrow',
      );
    });

    test('예상치 못한 예외는 SoiApiException으로 래핑됨', () async {
      final service = PostService(
        postApi: _FakePostApi(
          onCreate: (_) async => throw StateError('unexpected'),
        ),
      );

      expect(
        () => service.createPost(nickName: 'tester'),
        throwsA(isA<SoiApiException>()),
      );
    });
  });

  group('PostService _resolveCreatePostType', () {
    test('빈 키 리스트는 TEXT로 추론', () async {
      PostCreateReqDto? capturedDto;
      final service = PostService(
        postApi: _FakePostApi(
          onCreate: (dto) async {
            capturedDto = dto;
            return ApiResponseDtoBoolean(success: true, data: true);
          },
        ),
      );

      await service.createPost(nickName: 'tester', postFileKey: const []);
      expect(capturedDto?.postType, PostCreateReqDtoPostTypeEnum.TEXT);
    });

    test('이미지 키는 IMAGE로 추론된다', () async {
      PostCreateReqDto? capturedDto;
      final service = PostService(
        postApi: _FakePostApi(
          onCreate: (dto) async {
            capturedDto = dto;
            return ApiResponseDtoBoolean(success: true, data: true);
          },
        ),
      );

      await service.createPost(
        nickName: 'tester',
        postFileKey: const ['posts/real.jpg'],
      );
      expect(capturedDto?.postType, PostCreateReqDtoPostTypeEnum.IMAGE);
    });
  });
}
