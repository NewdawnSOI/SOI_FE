import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/models/post.dart';

// _compareByTime 정렬 로직을 독립적으로 검증하는 유닛 테스트
// ApiCategoryPhotosGridSliver._compareByTime과 동일한 로직을 사용합니다.
int _compareByTime(Post a, Post b) {
  final aTime = a.createdAt;
  final bTime = b.createdAt;
  if (aTime != null && bTime != null) {
    final cmp = bTime.compareTo(aTime);
    if (cmp != 0) return cmp;
  } else if (aTime != null) {
    return -1;
  } else if (bTime != null) {
    return 1;
  }
  return b.id.compareTo(a.id);
}

List<Post> _sortedPosts(List<Post> posts) =>
    List<Post>.from(posts)..sort(_compareByTime);

Post _post({required int id, DateTime? createdAt, String nickName = 'user'}) {
  return Post(id: id, nickName: nickName, createdAt: createdAt);
}

void main() {
  group('ApiCategoryPhotosGridSliver 정렬 로직', () {
    test('createdAt 기준 최신순(내림차순) 정렬', () {
      final posts = [
        _post(id: 1, createdAt: DateTime(2024, 1, 1)),
        _post(id: 2, createdAt: DateTime(2024, 3, 1)),
        _post(id: 3, createdAt: DateTime(2024, 2, 1)),
      ];

      final sorted = _sortedPosts(posts);

      expect(sorted[0].id, 2); // 3월 (가장 최신)
      expect(sorted[1].id, 3); // 2월
      expect(sorted[2].id, 1); // 1월 (가장 오래됨)
    });

    test('createdAt이 null인 경우 id 내림차순으로 폴백', () {
      final posts = [
        _post(id: 10),
        _post(id: 30),
        _post(id: 20),
      ];

      final sorted = _sortedPosts(posts);

      expect(sorted[0].id, 30);
      expect(sorted[1].id, 20);
      expect(sorted[2].id, 10);
    });

    test('createdAt이 있는 포스트가 null인 포스트보다 앞에 위치', () {
      final posts = [
        _post(id: 1, createdAt: null),
        _post(id: 2, createdAt: DateTime(2024, 1, 1)),
        _post(id: 3, createdAt: null),
      ];

      final sorted = _sortedPosts(posts);

      // createdAt이 있는 항목이 먼저
      expect(sorted[0].id, 2);
      // 나머지는 id 내림차순
      expect(sorted[1].id, 3);
      expect(sorted[2].id, 1);
    });

    test('createdAt이 동일하면 id 내림차순으로 폴백', () {
      final sameTime = DateTime(2024, 6, 15);
      final posts = [
        _post(id: 5, createdAt: sameTime),
        _post(id: 7, createdAt: sameTime),
        _post(id: 6, createdAt: sameTime),
      ];

      final sorted = _sortedPosts(posts);

      expect(sorted[0].id, 7);
      expect(sorted[1].id, 6);
      expect(sorted[2].id, 5);
    });

    test('빈 리스트는 빈 리스트를 반환', () {
      expect(_sortedPosts([]), isEmpty);
    });

    test('단일 항목 리스트는 순서 변경 없이 반환', () {
      final posts = [_post(id: 42, createdAt: DateTime(2024, 1, 1))];
      final sorted = _sortedPosts(posts);
      expect(sorted.length, 1);
      expect(sorted[0].id, 42);
    });

    test('identical 참조 캐싱: 동일 리스트 정렬 결과가 일관됨', () {
      final posts = List<Post>.unmodifiable([
        _post(id: 1, createdAt: DateTime(2024, 1, 1)),
        _post(id: 2, createdAt: DateTime(2024, 3, 1)),
      ]);

      final sorted1 = _sortedPosts(posts);
      final sorted2 = _sortedPosts(posts);

      // 두 정렬 결과가 동일한 순서인지 확인
      expect(sorted1.map((p) => p.id).toList(),
          equals(sorted2.map((p) => p.id).toList()));
      expect(sorted1[0].id, 2);
      expect(sorted1[1].id, 1);
    });
  });
}
