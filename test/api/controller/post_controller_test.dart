import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/controller/post_controller.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi/api/services/post_service.dart';
import 'package:soi_api_client/api.dart';

class _NoopPostApi extends PostAPIApi {}

typedef _CreatePostHandler =
    Future<bool> Function({
      int? userId,
      required String nickName,
      String? content,
      List<String> postFileKey,
      List<String> audioFileKey,
      List<String> thumbnailFileKey,
      List<int> categoryIds,
      String? waveformData,
      int? duration,
      double? savedAspectRatio,
      bool? isFromGallery,
      PostType? postType,
    });

typedef _GetPostsByCategoryHandler =
    Future<List<Post>> Function({
      required int categoryId,
      required int userId,
      int? notificationId,
      int page,
    });

class _FakePostService extends PostService {
  _FakePostService({this.onCreate, this.onGetPostsByCategory})
    : super(postApi: _NoopPostApi());

  final _CreatePostHandler? onCreate;
  final _GetPostsByCategoryHandler? onGetPostsByCategory;

  @override
  Future<List<Post>> getPostsByCategory({
    required int categoryId,
    required int userId,
    int? notificationId,
    int page = 0,
  }) async {
    final handler = onGetPostsByCategory;
    if (handler == null) {
      throw UnimplementedError('onGetPostsByCategory is not configured');
    }
    return handler(
      categoryId: categoryId,
      userId: userId,
      notificationId: notificationId,
      page: page,
    );
  }

  @override
  Future<bool> createPost({
    int? userId,
    required String nickName,
    String? content,
    List<String> postFileKey = const [],
    List<String> audioFileKey = const [],
    List<String> thumbnailFileKey = const [],
    List<int> categoryIds = const [],
    String? waveformData,
    int? duration,
    double? savedAspectRatio,
    bool? isFromGallery,
    PostType? postType,
  }) async {
    final handler = onCreate;
    if (handler == null) {
      throw UnimplementedError('onCreate is not configured');
    }
    return handler(
      userId: userId,
      nickName: nickName,
      content: content,
      postFileKey: postFileKey,
      audioFileKey: audioFileKey,
      thumbnailFileKey: thumbnailFileKey,
      categoryIds: categoryIds,
      waveformData: waveformData,
      duration: duration,
      savedAspectRatio: savedAspectRatio,
      isFromGallery: isFromGallery,
      postType: postType,
    );
  }
}

void main() {
  group('PostController createPost forwarding', () {
    test(
      'forwards text-only payload fields to service without mutation',
      () async {
        int? capturedUserId;
        String? capturedNickName;
        String? capturedContent;
        List<String>? capturedPostFileKey;
        List<String>? capturedAudioFileKey;
        List<int>? capturedCategoryIds;
        PostType? capturedPostType;

        final controller = PostController(
          postService: _FakePostService(
            onCreate:
                ({
                  int? userId,
                  required String nickName,
                  String? content,
                  List<String> postFileKey = const [],
                  List<String> audioFileKey = const [],
                  List<String> thumbnailFileKey = const [],
                  List<int> categoryIds = const [],
                  String? waveformData,
                  int? duration,
                  double? savedAspectRatio,
                  bool? isFromGallery,
                  PostType? postType,
                }) async {
                  capturedUserId = userId;
                  capturedNickName = nickName;
                  capturedContent = content;
                  capturedPostFileKey = postFileKey;
                  capturedAudioFileKey = audioFileKey;
                  capturedCategoryIds = categoryIds;
                  capturedPostType = postType;
                  return true;
                },
          ),
        );

        final result = await controller.createPost(
          userId: 100,
          nickName: 'tester',
          content: 'hello text only',
          postFileKey: const [],
          audioFileKey: const [],
          categoryIds: const [1, 2],
          postType: PostType.textOnly,
        );

        expect(result, isTrue);
        expect(capturedUserId, 100);
        expect(capturedNickName, 'tester');
        expect(capturedContent, 'hello text only');
        expect(capturedPostFileKey, isEmpty);
        expect(capturedAudioFileKey, isEmpty);
        expect(capturedCategoryIds, const [1, 2]);
        expect(capturedPostType, PostType.textOnly);
      },
    );

    test('bumps category mutation revisions for created categories', () async {
      final controller = PostController(
        postService: _FakePostService(
          onCreate:
              ({
                int? userId,
                required String nickName,
                String? content,
                List<String> postFileKey = const [],
                List<String> audioFileKey = const [],
                List<String> thumbnailFileKey = const [],
                List<int> categoryIds = const [],
                String? waveformData,
                int? duration,
                double? savedAspectRatio,
                bool? isFromGallery,
                PostType? postType,
              }) async => true,
        ),
      );

      expect(
        controller.getCategoryMutationRevision(userId: 100, categoryId: 1),
        0,
      );

      final result = await controller.createPost(
        userId: 100,
        nickName: 'tester',
        categoryIds: const [1, 2, 2],
        postType: PostType.textOnly,
      );

      expect(result, isTrue);
      expect(
        controller.getCategoryMutationRevision(userId: 100, categoryId: 1),
        1,
      );
      expect(
        controller.getCategoryMutationRevision(userId: 100, categoryId: 2),
        1,
      );
      expect(
        controller.getCategoryMutationRevision(userId: 100, categoryId: 3),
        0,
      );
    });

    test('forwards isFromGallery to service without mutation', () async {
      bool? capturedIsFromGallery;

      final controller = PostController(
        postService: _FakePostService(
          onCreate:
              ({
                int? userId,
                required String nickName,
                String? content,
                List<String> postFileKey = const [],
                List<String> audioFileKey = const [],
                List<String> thumbnailFileKey = const [],
                List<int> categoryIds = const [],
                String? waveformData,
                int? duration,
                double? savedAspectRatio,
                bool? isFromGallery,
                PostType? postType,
              }) async {
                capturedIsFromGallery = isFromGallery;
                return true;
              },
        ),
      );

      final result = await controller.createPost(
        userId: 100,
        nickName: 'tester',
        postFileKey: const ['posts/example.jpg'],
        isFromGallery: false,
        postType: PostType.multiMedia,
      );

      expect(result, isTrue);
      expect(capturedIsFromGallery, isFalse);
    });
  });

  group('PostController getPostsByCategory cache', () {
    test('캐시 히트 시 API를 호출하지 않음', () async {
      int callCount = 0;
      final controller = PostController(
        postService: _FakePostService(
          onGetPostsByCategory:
              ({
                required int categoryId,
                required int userId,
                int? notificationId,
                int page = 0,
              }) async {
                callCount++;
                return [];
              },
        ),
      );

      await controller.getPostsByCategory(categoryId: 1, userId: 10);
      await controller.getPostsByCategory(categoryId: 1, userId: 10);

      expect(callCount, 1, reason: '두 번째 호출은 캐시에서 반환되어야 함');
    });

    test('forceRefresh=true 시 캐시를 무시하고 API 호출', () async {
      int callCount = 0;
      final controller = PostController(
        postService: _FakePostService(
          onGetPostsByCategory:
              ({
                required int categoryId,
                required int userId,
                int? notificationId,
                int page = 0,
              }) async {
                callCount++;
                return [];
              },
        ),
      );

      await controller.getPostsByCategory(categoryId: 1, userId: 10);
      await controller.getPostsByCategory(
        categoryId: 1,
        userId: 10,
        forceRefresh: true,
      );

      expect(callCount, 2, reason: 'forceRefresh면 캐시를 무시하고 재호출');
    });

    test('in-flight dedupe: 동시 요청은 API를 1번만 호출', () async {
      int callCount = 0;
      final controller = PostController(
        postService: _FakePostService(
          onGetPostsByCategory:
              ({
                required int categoryId,
                required int userId,
                int? notificationId,
                int page = 0,
              }) async {
                callCount++;
                // 약간의 비동기 지연으로 동시 요청 시뮬레이션
                await Future<void>.delayed(Duration.zero);
                return [];
              },
        ),
      );

      await Future.wait([
        controller.getPostsByCategory(categoryId: 2, userId: 10),
        controller.getPostsByCategory(categoryId: 2, userId: 10),
        controller.getPostsByCategory(categoryId: 2, userId: 10),
      ]);

      expect(callCount, 1, reason: '동시 동일 키 요청은 in-flight dedupe로 1번만 호출');
    });

    test('에러 발생 시 만료된 캐시 stale fallback', () async {
      int callCount = 0;
      bool shouldFail = false;
      final controller = PostController(
        postService: _FakePostService(
          onGetPostsByCategory:
              ({
                required int categoryId,
                required int userId,
                int? notificationId,
                int page = 0,
              }) async {
                callCount++;
                if (shouldFail) throw Exception('network error');
                return [];
              },
        ),
      );

      // 첫 호출 성공 → 캐시 저장
      final first = await controller.getPostsByCategory(
        categoryId: 3,
        userId: 10,
      );
      expect(first, isEmpty);

      // 두 번째 호출 강제 실패 (stale fallback 확인)
      shouldFail = true;
      final second = await controller.getPostsByCategory(
        categoryId: 3,
        userId: 10,
        forceRefresh: true,
      );

      expect(second, isEmpty, reason: '에러 시 만료된 캐시(stale)를 반환');
      expect(callCount, 2);
    });
  });

  group('PostController _notifyPostsChanged 선택적 캐시 무효화', () {
    test('createPost 성공 시 해당 카테고리 캐시만 무효화', () async {
      int catACallCount = 0;
      int catBCallCount = 0;

      final controller = PostController(
        postService: _FakePostService(
          onCreate:
              ({
                int? userId,
                required String nickName,
                String? content,
                List<String> postFileKey = const [],
                List<String> audioFileKey = const [],
                List<String> thumbnailFileKey = const [],
                List<int> categoryIds = const [],
                String? waveformData,
                int? duration,
                double? savedAspectRatio,
                bool? isFromGallery,
                PostType? postType,
              }) async => true,
          onGetPostsByCategory:
              ({
                required int categoryId,
                required int userId,
                int? notificationId,
                int page = 0,
              }) async {
                if (categoryId == 10) catACallCount++;
                if (categoryId == 20) catBCallCount++;
                return [];
              },
        ),
      );

      // 두 카테고리 캐시 워밍
      await controller.getPostsByCategory(categoryId: 10, userId: 1);
      await controller.getPostsByCategory(categoryId: 20, userId: 1);
      expect(catACallCount, 1);
      expect(catBCallCount, 1);

      // categoryId=10에만 포스트 생성
      await controller.createPost(
        userId: 1,
        nickName: 'tester',
        categoryIds: const [10],
        postType: PostType.textOnly,
      );

      // categoryId=10 캐시는 무효화 → 재조회 시 API 호출
      await controller.getPostsByCategory(categoryId: 10, userId: 1);
      expect(catACallCount, 2, reason: 'createPost 후 해당 카테고리 캐시 무효화됨');

      // categoryId=20 캐시는 유지 → API 호출 없음
      await controller.getPostsByCategory(categoryId: 20, userId: 1);
      expect(catBCallCount, 1, reason: '다른 카테고리 캐시는 유지됨');
    });

    test('리스너 순회 중 remove 호출해도 ConcurrentModificationError 없음', () {
      final controller = PostController(
        postService: _FakePostService(
          onCreate:
              ({
                int? userId,
                required String nickName,
                String? content,
                List<String> postFileKey = const [],
                List<String> audioFileKey = const [],
                List<String> thumbnailFileKey = const [],
                List<int> categoryIds = const [],
                String? waveformData,
                int? duration,
                double? savedAspectRatio,
                bool? isFromGallery,
                PostType? postType,
              }) async => true,
        ),
      );

      late VoidCallback selfRemovingListener;
      selfRemovingListener = () {
        controller.removePostsChangedListener(selfRemovingListener);
      };

      controller.addPostsChangedListener(selfRemovingListener);

      // notifyPostsChanged 호출 중 리스너가 자신을 제거해도 에러 없어야 함
      expect(() => controller.notifyPostsChanged(), returnsNormally);
    });
  });
}
