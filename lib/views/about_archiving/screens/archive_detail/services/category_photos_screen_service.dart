import '../../../../../../api/models/post.dart';

/// 아카이브 상세 화면의 카테고리 포스트 캐시 키를 일관된 형식으로 생성합니다.
String buildCategoryPostsCacheKey({
  required int userId,
  required int categoryId,
}) {
  return '$userId:$categoryId';
}

/// 아카이브 상세 화면에서 카테고리별 포스트 목록을 캐싱하는 역할을 하는 클래스입니다.
///
/// 캐시된 데이터의 유효 기간(TTL)을 관리하고, mutation revision을 활용하여 데이터 일치 여부를 판단합니다.
///
/// mutation revision은 카테고리 포스트의 변경 이력을 나타내는 정수로,
/// 캐시된 데이터가 현재 카테고리 상태와 일치하는지 판단하는 데 사용됩니다.
///
/// fields:
/// - [ttl]: 캐시된 데이터의 **유효 기간**을 설정하는 TTL(Time To Live)입니다.
/// - [now]: **현재 시간**을 반환하는 함수입니다.
/// - [entries]: 캐시 엔트리를 키-값 형태로 보관하는 내부 저장소 Map입니다.
///   - key: 캐시 키 (예: 'userId:categoryId')
///   - value: 해당 카테고리 화면에 보이는 포스트 목록과 캐시([CategoryPostsScreenCacheEntry])
///     - [CategoryPostsScreenCacheEntry]는 다음 필드를 포함합니다:
///       - [posts]: 화면에 보이는 포스트 목록 (immutable)
///       - [cachedAt]: 캐시된 시점 (TTL 계산용)
///       - [mutationRevision]: 카테고리 포스트의 mutation revision (변경 감지용)
class CategoryPostsScreenCacheStore {
  /// 캐시된 데이터의 유효 기간을 설정하는 TTL(Time To Live)입니다.
  final Duration _ttl;

  /// 현재 시간을 반환하는 함수입니다.
  ///
  /// 테스트 시점 조작을 위해 주입 가능하도록 설계되었습니다.
  final DateTime Function() _now;

  /// 캐시 엔트리를 키-값 형태로 보관하는 내부 저장소 Map입니다.
  /// - key: 캐시 키 (예: 'userId:categoryId')
  /// - value: 해당 카테고리 화면에 보이는 포스트 목록과 캐시([CategoryPostsScreenCacheEntry])
  ///   - [CategoryPostsScreenCacheEntry]는 다음 필드를 포함합니다:
  ///     - [posts]: 화면에 보이는 포스트 목록 (immutable)
  ///     - [cachedAt]: 캐시된 시점 (TTL 계산용)
  ///     - [mutationRevision]: 카테고리 포스트의 변경 이력을 나타내는 상수값 (변경 감지용)
  final Map<String, CategoryPostsScreenCacheEntry> _entries =
      <String, CategoryPostsScreenCacheEntry>{};

  CategoryPostsScreenCacheStore({
    Duration ttl = const Duration(minutes: 30),
    DateTime Function()? now,
  }) : _ttl = ttl,
       _now = now ?? DateTime.now;

  /// 현재 revision과 TTL 기준으로 화면 캐시가 아직 재사용 가능한지 판단합니다.
  ///
  /// Parameters:
  /// - [key]: 캐시 키 (예: 'userId:categoryId')
  /// - [currentMutationRevision]: 현재 카테고리 포스트의 변경 이력을 나타내는 상수값 (변경 감지용)
  /// - [allowExpired]: TTL이 지난 캐시라도 변경 이력 상수(mutationRevision)가 일치하면 허용할지 여부 (기본값: false)
  ///
  /// Returns:
  /// - [CategoryPostsScreenCacheEntry]
  ///   - 유효한 캐시 엔트리 (posts, cachedAt, mutationRevision)
  ///   - null (캐시 없음, revision 불일치, 또는 TTL 만료)
  CategoryPostsScreenCacheEntry? read(
    String key, {
    required int currentMutationRevision,
    bool allowExpired = false,
  }) {
    final cached = _entries[key];
    if (cached == null) {
      return null;
    }

    if (cached.mutationRevision != currentMutationRevision) {
      _entries.remove(key);
      return null;
    }

    final isExpired = _now().difference(cached.cachedAt) >= _ttl;
    if (isExpired && !allowExpired) {
      return null;
    }

    return cached;
  }

  /// 현재 화면에 보이는 포스트 스냅샷을 immutable 리스트로 저장합니다.
  ///
  /// Parameters:
  /// - [key]: 캐시 키 (예: 'userId:categoryId')
  /// - [posts]: 화면에 보이는 포스트 목록 (immutable로 감싸서 저장)
  /// - [mutationRevision]: 현재 카테고리 포스트의 mutation revision (변경 감지용)
  void write(
    String key, {
    required List<Post> posts,
    required int mutationRevision,
  }) {
    // 기존 캐시가 있더라도 새로 쓰는 데이터가 최신이므로 덮어씁니다.
    _entries[key] = CategoryPostsScreenCacheEntry(
      posts: List<Post>.unmodifiable(posts),
      cachedAt: _now(),
      mutationRevision: mutationRevision,
    );
  }

  /// 특정 카테고리 화면 캐시만 선택적으로 무효화합니다.
  void remove(String key) {
    _entries.remove(key);
  }
}

/// 화면 캐시 한 건의 포스트 목록과 저장 시점을 함께 보관하는 데이터 클래스입니다.
/// mutationRevision은 캐시된 데이터가 현재 카테고리 상태와 일치하는지 판단하는 데 사용됩니다.
///
/// fields:
/// - [posts]: 화면에 보이는 포스트 목록 (immutable)
/// - [cachedAt]: 캐시된 시점 (TTL 계산용)
/// - [mutationRevision]: 카테고리 포스트의 mutation revision (변경 감지용)
class CategoryPostsScreenCacheEntry {
  final List<Post> posts;
  final DateTime cachedAt;
  final int mutationRevision;

  const CategoryPostsScreenCacheEntry({
    required this.posts,
    required this.cachedAt,
    required this.mutationRevision,
  });
}

/// 차단 유저와 중복 포스트를 제외한 화면용 페이지 결과를 누적합니다.
class CategoryPostsVisibleAccumulator {
  Set<int> _seenPostIds = <int>{};
  Set<String> _blockedUserIds = <String>{};

  /// 최신 차단 유저 집합으로 필터 기준을 교체합니다.
  void replaceBlockedUserIds(Iterable<String> blockedUserIds) {
    _blockedUserIds = blockedUserIds.toSet();
  }

  /// 새 로드 세션 시작 시 이미 화면에 있는 포스트를 기준으로 중복 체크를 초기화합니다.
  void reset({Iterable<Post> seedPosts = const <Post>[]}) {
    _seenPostIds = seedPosts.map((post) => post.id).toSet();
  }

  /// 한 페이지 분량의 포스트를 화면에 보일 항목만 남기도록 정제합니다.
  CategoryPostsAppendResult appendPage(Iterable<Post> pagePosts) {
    final visiblePosts = <Post>[];
    var blockedRemoved = 0;
    var duplicateRemoved = 0;

    for (final post in pagePosts) {
      if (_blockedUserIds.contains(post.nickName)) {
        blockedRemoved++;
        continue;
      }
      if (!_seenPostIds.add(post.id)) {
        duplicateRemoved++;
        continue;
      }
      visiblePosts.add(post);
    }

    return CategoryPostsAppendResult(
      posts: List<Post>.unmodifiable(visiblePosts),
      blockedRemoved: blockedRemoved,
      duplicateRemoved: duplicateRemoved,
    );
  }
}

/// 페이지 append 과정에서 실제로 화면에 남은 포스트와 제거 통계를 함께 전달합니다.
class CategoryPostsAppendResult {
  final List<Post> posts;
  final int blockedRemoved;
  final int duplicateRemoved;

  const CategoryPostsAppendResult({
    required this.posts,
    required this.blockedRemoved,
    required this.duplicateRemoved,
  });
}

/// 상세 화면에서 삭제된 포스트 ID를 현재 화면 목록에 반영합니다.
List<Post> removePostsByIds(Iterable<Post> posts, Set<int> deletedPostIds) {
  if (deletedPostIds.isEmpty) {
    return List<Post>.unmodifiable(posts);
  }

  return List<Post>.unmodifiable(
    posts.where((post) => !deletedPostIds.contains(post.id)),
  );
}
