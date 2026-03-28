import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi/views/about_archiving/screens/archive_detail/services/api_category_photos_screen_service.dart';

/// 화면 지원 로직 테스트에서 사용할 최소 Post 모델을 생성합니다.
Post _post({required int id, String nickName = 'user', DateTime? createdAt}) {
  return Post(id: id, nickName: nickName, createdAt: createdAt);
}

void main() {
  group('CategoryPostsScreenCacheStore', () {
    late DateTime now;
    late CategoryPostsScreenCacheStore cacheStore;

    setUp(() {
      now = DateTime(2024, 1, 1, 12);
      cacheStore = CategoryPostsScreenCacheStore(
        ttl: const Duration(minutes: 30),
        now: () => now,
      );
    });

    test('returns a fresh cached entry before ttl expires', () {
      cacheStore.write(
        '1:10',
        posts: <Post>[_post(id: 1)],
        mutationRevision: 2,
      );

      final cached = cacheStore.read('1:10', currentMutationRevision: 2);

      expect(cached, isNotNull);
      expect(cached!.posts.map((post) => post.id), <int>[1]);
    });

    test('allows expired entries only when allowExpired is true', () {
      cacheStore.write(
        '1:10',
        posts: <Post>[_post(id: 1)],
        mutationRevision: 2,
      );
      now = now.add(const Duration(minutes: 31));

      expect(cacheStore.read('1:10', currentMutationRevision: 2), isNull);

      final stale = cacheStore.read(
        '1:10',
        currentMutationRevision: 2,
        allowExpired: true,
      );

      expect(stale, isNotNull);
      expect(stale!.posts.single.id, 1);
    });

    test('invalidates entries whose mutation revision changed', () {
      cacheStore.write(
        '1:10',
        posts: <Post>[_post(id: 1)],
        mutationRevision: 2,
      );

      final cached = cacheStore.read(
        '1:10',
        currentMutationRevision: 3,
        allowExpired: true,
      );

      expect(cached, isNull);
      expect(
        cacheStore.read('1:10', currentMutationRevision: 2, allowExpired: true),
        isNull,
      );
    });
  });

  group('CategoryPostsVisibleAccumulator', () {
    test('filters blocked users and duplicates across pages', () {
      final accumulator = CategoryPostsVisibleAccumulator()
        ..replaceBlockedUserIds(const <String>['blocked'])
        ..reset();

      final firstPage = accumulator.appendPage(<Post>[
        _post(id: 1, nickName: 'visible-a'),
        _post(id: 2, nickName: 'blocked'),
        _post(id: 1, nickName: 'visible-a'),
      ]);

      final secondPage = accumulator.appendPage(<Post>[
        _post(id: 1, nickName: 'visible-a'),
        _post(id: 3, nickName: 'visible-b'),
      ]);

      expect(firstPage.posts.map((post) => post.id), <int>[1]);
      expect(firstPage.blockedRemoved, 1);
      expect(firstPage.duplicateRemoved, 1);
      expect(secondPage.posts.map((post) => post.id), <int>[3]);
      expect(secondPage.blockedRemoved, 0);
      expect(secondPage.duplicateRemoved, 1);
    });

    test(
      'seed posts are treated as already rendered when restarting session',
      () {
        final accumulator = CategoryPostsVisibleAccumulator()
          ..replaceBlockedUserIds(const <String>[])
          ..reset(seedPosts: <Post>[_post(id: 7)]);

        final result = accumulator.appendPage(<Post>[
          _post(id: 7),
          _post(id: 8),
        ]);

        expect(result.posts.map((post) => post.id), <int>[8]);
        expect(result.duplicateRemoved, 1);
      },
    );
  });

  group('removePostsByIds', () {
    test('drops only deleted post ids and keeps order of survivors', () {
      final remaining = removePostsByIds(
        <Post>[_post(id: 1), _post(id: 2), _post(id: 3)],
        <int>{2},
      );

      expect(remaining.map((post) => post.id), <int>[1, 3]);
    });
  });
}
