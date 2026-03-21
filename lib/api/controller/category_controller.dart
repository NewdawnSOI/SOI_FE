import 'package:flutter/foundation.dart';
import 'package:soi/api/models/category.dart' as model;
import 'package:soi/api/services/category_service.dart';

/// 카테고리 컨트롤러
///
/// 카테고리 관련 UI 상태 관리 및 비즈니스 로직을 담당합니다.
/// CategoryService를 내부적으로 사용하며, API 변경 시 Service만 수정하면 됩니다.
class CategoryController extends ChangeNotifier {
  final CategoryService _categoryService;

  // 카테고리 캐시 (filter별로 관리)
  final Map<model.CategoryFilter, List<model.Category>> _categoriesCache = {};
  final Map<String, _CachedCategoryRequest> _requestCache = {};
  final Map<int, model.Category> _categoryByIdCache = {};
  int? _cachedUserId;
  static const Duration _cacheTimeout = Duration(seconds: 30);

  // 현재 표시 중인 카테고리 (마지막으로 로드한 filter의 데이터)
  List<model.Category> _currentCategories = const [];

  // 로딩 상태
  bool _isLoading = false;

  // 에러 메시지
  String? _errorMessage;

  /// 생성자
  ///
  /// [categoryService]를 주입받아 사용합니다. 테스트 시 MockCategoryService를 주입할 수 있습니다.
  CategoryController({CategoryService? categoryService})
    : _categoryService = categoryService ?? CategoryService();

  String _buildRequestCacheKey({
    required int userId,
    required model.CategoryFilter filter,
    required int page,
    required bool fetchAllPages,
    required int maxPages,
  }) {
    return '$userId:${filter.value}:$page:$fetchAllPages:$maxPages';
  }

  _CachedCategoryRequest? _getValidRequestCache(String requestKey) {
    final cached = _requestCache[requestKey];
    if (cached == null) return null;

    if (DateTime.now().difference(cached.cachedAt) >= _cacheTimeout) {
      _requestCache.remove(requestKey);
      return null;
    }

    return cached;
  }

  void _storeRequestCache(String requestKey, List<model.Category> categories) {
    _requestCache[requestKey] = _CachedCategoryRequest(
      categories: List<model.Category>.unmodifiable(categories),
      cachedAt: DateTime.now(),
    );
  }

  void _storeFilterCache(
    model.CategoryFilter filter,
    List<model.Category> categories,
  ) {
    _categoriesCache[filter] = List<model.Category>.unmodifiable(categories);
  }

  void _resetCaches({bool notify = false}) {
    _categoriesCache.clear();
    _requestCache.clear();
    _categoryByIdCache.clear();
    _currentCategories = const [];
    _cachedUserId = null;
    if (notify) {
      notifyListeners();
    }
  }

  void _rebuildCategoryIndex() {
    _categoryByIdCache.clear();

    for (final category in _currentCategories) {
      _categoryByIdCache[category.id] = category;
    }

    for (final categories in _categoriesCache.values) {
      for (final category in categories) {
        _categoryByIdCache.putIfAbsent(category.id, () => category);
      }
    }
  }

  model.Category _copyCategory(
    model.Category category, {
    String? name,
    String? photoUrl,
    bool clearPhotoUrl = false,
    bool? isNew,
    bool? isPinned,
    DateTime? pinnedAt,
    bool clearPinnedAt = false,
  }) {
    return model.Category(
      id: category.id,
      name: name ?? category.name,
      nickNames: category.nickNames,
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? category.photoUrl),
      isNew: isNew ?? category.isNew,
      totalUserCount: category.totalUserCount,
      isPinned: isPinned ?? category.isPinned,
      usersProfileKey: category.usersProfileKey,
      pinnedAt: clearPinnedAt ? null : (pinnedAt ?? category.pinnedAt),
      lastPhotoUploadedAt: category.lastPhotoUploadedAt,
    );
  }

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get errorMessage => _errorMessage;

  /// 캐시된 카테고리 목록 (현재 filter 기준)
  ///
  /// 캐시에 불변 리스트로 저장되므로 별도 래핑 없이 바로 반환합니다.
  List<model.Category> get categories => _currentCategories;

  /// filter별 캐시된 카테고리 목록 조회
  ///
  /// 캐시에 불변 리스트로 저장되므로 별도 래핑 없이 바로 반환합니다.
  List<model.Category> getCategoriesByFilter(model.CategoryFilter filter) {
    return _categoriesCache[filter] ?? const [];
  }

  /// 요청 형태에 맞는 카테고리 캐시가 아직 유효한지 확인합니다.
  bool hasFreshRequest({
    required int userId,
    model.CategoryFilter filter = model.CategoryFilter.all,
    int page = 0,
    bool fetchAllPages = true,
    int maxPages = 50,
  }) {
    if (_cachedUserId != null && _cachedUserId != userId) {
      return false;
    }

    final normalizedPage = page < 0 ? 0 : page;
    final normalizedMaxPages = maxPages < 1 ? 1 : maxPages;
    final requestKey = _buildRequestCacheKey(
      userId: userId,
      filter: filter,
      page: normalizedPage,
      fetchAllPages: fetchAllPages,
      maxPages: normalizedMaxPages,
    );

    return _getValidRequestCache(requestKey) != null;
  }

  /// 전체 카테고리 (ALL filter)
  List<model.Category> get allCategories =>
      getCategoriesByFilter(model.CategoryFilter.all);

  /// 공개 카테고리 (PUBLIC filter)
  List<model.Category> get publicCategories =>
      getCategoriesByFilter(model.CategoryFilter.public_);

  /// 비공개 카테고리 (PRIVATE filter)
  List<model.Category> get privateCategories =>
      getCategoriesByFilter(model.CategoryFilter.private_);

  /// 카테고리 목록 로드 및 캐시
  ///
  /// [forceReload]가 true이면 캐시를 무시하고 새로 로드합니다.
  ///
  /// **로드 전략:**
  /// - ALL: PUBLIC, PRIVATE, ALL 모두 로드 (병렬 처리)
  /// - PUBLIC: PUBLIC만 로드
  /// - PRIVATE: PRIVATE만 로드
  Future<List<model.Category>> loadCategories(
    int userId, {
    model.CategoryFilter filter = model.CategoryFilter.all,
    bool forceReload = true,
    int page = 0,
    bool fetchAllPages = true, // 페이지네이션이 필요한 경우 true로 설정 (기본값: true)
    int maxPages = 50,
  }) async {
    final normalizedPage = page < 0 ? 0 : page;
    final normalizedMaxPages = maxPages < 1 ? 1 : maxPages;

    if (_cachedUserId != null && _cachedUserId != userId) {
      _resetCaches();
    }

    final requestKey = _buildRequestCacheKey(
      userId: userId,
      filter: filter,
      page: normalizedPage,
      fetchAllPages: fetchAllPages,
      maxPages: normalizedMaxPages,
    );

    if (!forceReload) {
      final cachedRequest = _getValidRequestCache(requestKey);
      if (cachedRequest != null) {
        if (!identical(_currentCategories, cachedRequest.categories)) {
          _currentCategories = cachedRequest.categories;
          _rebuildCategoryIndex();
          notifyListeners();
        } else if (_categoryByIdCache.isEmpty) {
          _rebuildCategoryIndex();
        }
        return cachedRequest.categories;
      }
    }

    _setLoading(true);
    _clearError();

    try {
      if (filter == model.CategoryFilter.all) {
        // ALL 필터: PUBLIC, PRIVATE, ALL 모두 병렬로 로드
        final results = await Future.wait([
          // 전체 카테고리를 먼저 로드
          _categoryService.getCategories(
            filter: model.CategoryFilter.all,
            page: normalizedPage,
            fetchAllPages: fetchAllPages,
            maxPages: normalizedMaxPages,
          ),
          // PUBLIC 카테고리를 병렬로 로드
          _categoryService.getCategories(
            filter: model.CategoryFilter.public_,
            page: normalizedPage,
            fetchAllPages: fetchAllPages,
            maxPages: normalizedMaxPages,
          ),
          // PRIVATE 카테고리를 병렬로 로드
          _categoryService.getCategories(
            filter: model.CategoryFilter.private_,
            page: normalizedPage,
            fetchAllPages: fetchAllPages,
            maxPages: normalizedMaxPages,
          ),
        ]);

        // 각 filter별 캐시 저장 (불변 리스트로 저장하여 getter에서 래핑 비용 제거)
        _storeFilterCache(model.CategoryFilter.all, results[0]);
        _storeFilterCache(model.CategoryFilter.public_, results[1]);
        _storeFilterCache(model.CategoryFilter.private_, results[2]);
        _storeRequestCache(
          _buildRequestCacheKey(
            userId: userId,
            filter: model.CategoryFilter.all,
            page: normalizedPage,
            fetchAllPages: fetchAllPages,
            maxPages: normalizedMaxPages,
          ),
          results[0],
        );
        _storeRequestCache(
          _buildRequestCacheKey(
            userId: userId,
            filter: model.CategoryFilter.public_,
            page: normalizedPage,
            fetchAllPages: fetchAllPages,
            maxPages: normalizedMaxPages,
          ),
          results[1],
        );
        _storeRequestCache(
          _buildRequestCacheKey(
            userId: userId,
            filter: model.CategoryFilter.private_,
            page: normalizedPage,
            fetchAllPages: fetchAllPages,
            maxPages: normalizedMaxPages,
          ),
          results[2],
        );
        _currentCategories = _categoriesCache[model.CategoryFilter.all]!;
      } else {
        // PUBLIC 또는 PRIVATE 필터: 해당 필터만 로드
        final categories = await _categoryService.getCategories(
          filter: filter,
          page: normalizedPage,
          fetchAllPages: fetchAllPages,
          maxPages: normalizedMaxPages,
        );

        _storeFilterCache(filter, categories);
        _storeRequestCache(requestKey, categories);
        _currentCategories = _categoriesCache[filter]!;
      }

      _cachedUserId = userId;
      _rebuildCategoryIndex();

      _setLoading(false);
      return _currentCategories;
    } catch (e) {
      _setError('카테고리 조회 실패: $e');
      debugPrint('[CategoryController] 카테고리 로드 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  /// 캐시 무효화
  void invalidateCache() {
    _resetCaches(notify: true);
  }

  /// 특정 카테고리를 읽음 상태로 표시
  ///
  /// 서버에서 isNew 값이 false로 내려오더라도 캐시가 남아 있으면
  /// UI에 즉시 반영되지 않을 수 있으므로, 사용자가 카테고리를 열었을 때
  /// 로컬 캐시의 isNew를 false로 갱신한다.
  void markCategoryAsViewed(int categoryId) {
    _updateCachedCategory(categoryId, (category) {
      if (!category.isNew) return category;
      return _copyCategory(category, isNew: false);
    });
  }

  /// 특정 카테고리 캐시 갱신 헬퍼
  /// 카테고리 이름을 수정하고 나서 UI에 바로 반영되지 않는 문제를 해결하기 위해서 사용
  ///
  /// Parameters:
  ///   - [categoryId]: 카테고리 ID
  ///   - [update]: 카테고리 객체를 받아 수정된 객체를 반환하는 함수
  ///   - [notify]: 캐시를 갱신한 후에 notifyListeners를 호출할지 여부 (기본값: true)
  void _updateCachedCategory(
    int categoryId,
    model.Category Function(model.Category category) update, {
    bool notify = true, // 캐시를 갱신한 후에 notifyListeners를 호출할지 여부 (기본값: true)
  }) {
    bool updated = false;

    // 특정 카테고리만 갱신하는 내부 함수 (불변 리스트 유지)
    List<model.Category> updateList(List<model.Category> categories) {
      final index = categories.indexWhere((c) => c.id == categoryId);
      if (index == -1) return categories;

      final currentCategory = categories[index];
      final nextCategory = update(currentCategory);
      if (identical(nextCategory, currentCategory)) {
        return categories;
      }

      final newList = List<model.Category>.from(categories);
      newList[index] = nextCategory;
      updated = true;
      return List<model.Category>.unmodifiable(newList);
    }

    // 현재 목록 갱신
    _currentCategories = updateList(_currentCategories);

    // 필터별 캐시 갱신
    _categoriesCache.updateAll((key, value) => updateList(value));

    _requestCache.updateAll((key, value) {
      final updatedCategories = updateList(value.categories);
      if (identical(updatedCategories, value.categories)) {
        return value;
      }
      return value.copyWith(categories: updatedCategories);
    });

    if (updated && notify) {
      _rebuildCategoryIndex();
      notifyListeners();
    } else if (updated) {
      _rebuildCategoryIndex();
    }
  }

  String? _normalizeProfileImageKey(String? profileImageKey) {
    final normalized = profileImageKey?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  void _updateCategoryNameInCache(int categoryId, String? newName) {
    if (newName == null) return;
    _updateCachedCategory(
      categoryId,
      (category) => category.copyWith(name: newName),
    );
  }

  /// ID로 캐시된 카테고리 조회
  model.Category? getCategoryById(int categoryId) =>
      _categoryByIdCache[categoryId];

  /// 카테고리 생성
  /// Parameters:
  ///   - [requesterId]: 요청자 사용자 ID
  ///   - [name]: 카테고리 이름
  ///   - [receiverIds]: 초대할 사용자 ID 목록
  ///   - [isPublic]: 공개 여부
  ///
  /// Returns:
  ///   - [int]: 생성된 카테고리 ID (실패 시 null)
  Future<int?> createCategory({
    required int requesterId,
    required String name,
    List<int> receiverIds = const [],
    bool isPublic = true,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final id = await _categoryService.createCategory(
        requesterId: requesterId,
        name: name,
        receiverIds: receiverIds,
        isPublic: isPublic,
      );
      _setLoading(false);
      return id;
    } catch (e) {
      _setError('카테고리 생성 실패: $e');
      _setLoading(false);
      return null;
    }
  }

  /// 카테고리 조회
  /// Parameters:
  /// - [filter]: 카테고리 필터 (기본값: all)
  Future<List<model.Category>> getCategories({
    model.CategoryFilter filter = model.CategoryFilter.all,
    int page = 0,
    bool fetchAllPages = false,
    int maxPages = 50,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final categories = await _categoryService.getCategories(
        filter: filter,
        page: page,
        fetchAllPages: fetchAllPages,
        maxPages: maxPages,
      );
      _setLoading(false);
      return categories;
    } catch (e) {
      _setError('카테고리 조회 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  /// 모든 카테고리 조회
  /// Parameters:
  /// - [userId]: 사용자 ID
  ///
  /// Returns:
  /// - [List<model.Category>]: 모든 카테고리 목록
  Future<List<model.Category>> getAllCategories(int userId) =>
      getCategories(filter: model.CategoryFilter.all);

  // 공개 카테고리 조회
  Future<List<model.Category>> getPublicCategories(int userId) =>
      getCategories(filter: model.CategoryFilter.public_);

  // 비공개 카테고리 조회
  Future<List<model.Category>> getPrivateCategories(int userId) =>
      getCategories(filter: model.CategoryFilter.private_);

  /// 카테고리 고정
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  ///
  /// Returns:
  /// - [bool]: 고정 성공 여부
  ///   - true: 고정됨
  ///   - false: 고정 해제됨
  Future<bool> toggleCategoryPin({required int categoryId}) async {
    _setLoading(true);
    _clearError();
    try {
      final result = await _categoryService.toggleCategoryPin(
        categoryId: categoryId,
      );
      final cachedCategory = getCategoryById(categoryId);
      if (cachedCategory != null && cachedCategory.isPinned != result) {
        _updateCachedCategory(
          categoryId,
          (category) => _copyCategory(
            category,
            isPinned: result,
            pinnedAt: result ? (category.pinnedAt ?? DateTime.now()) : null,
            clearPinnedAt: !result,
          ),
          notify: false,
        );
      }
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('카테고리 고정 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 카테고리 알림 설정
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  ///
  /// Returns:
  /// - [bool]: 알림 설정 여부
  Future<bool> setCategoryAlert({required int categoryId}) async {
    _setLoading(true);
    _clearError();
    try {
      final result = await _categoryService.setCategoryAlert(
        categoryId: categoryId,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('카테고리 알림 설정 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 카테고리 초대
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  /// - [requesterId]: 요청자 사용자 ID
  /// - [receiverIds]: 초대할 사용자 ID 목록
  ///
  /// Returns:
  /// - [bool]: 초대 성공 여부
  ///   - true: 초대 성공
  ///   - false: 초대 실패
  Future<bool> inviteUsersToCategory({
    required int categoryId,
    required int requesterId,
    required List<int> receiverIds,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final result = await _categoryService.inviteUsersToCategory(
        categoryId: categoryId,
        requesterId: requesterId,
        receiverIds: receiverIds,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('사용자 초대 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 카테고리 초대 수락
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  ///
  /// Returns:
  /// - [bool]: 수락 성공 여부
  ///   - true: 수락 성공
  ///   - false: 수락 실패
  Future<bool> acceptInvite({
    required int categoryId,
    required int responserId,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final result = await _categoryService.acceptInvite(
        categoryId: categoryId,
        responserId: responserId,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('초대 수락 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 카테고리 초대 거절
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  ///
  /// Returns:
  /// - [bool]: 거절 성공 여부
  ///   - true: 거절 성공
  ///   - false: 거절 실패
  Future<bool> declineInvite({
    required int categoryId,
    required int responserId,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final result = await _categoryService.declineInvite(
        categoryId: categoryId,
        responserId: responserId,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('초대 거절 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  // ============================================
  // 카테고리 설정 (이름, 프로필)
  // ============================================

  /// 카테고리 커스텀 이름 수정
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  /// - [name]: 새 이름
  ///
  /// Returns:
  /// - [bool]: 수정 성공 여부
  ///   - true: 수정 성공
  ///   - false: 수정 실패
  Future<bool> updateCustomName({required int categoryId, String? name}) async {
    _setLoading(true);
    _clearError();
    try {
      // 카테고리 이름을 수정
      final result = await _categoryService.updateCustomName(
        categoryId: categoryId,
        name: name,
      );
      // 수정이 성공하면 캐시를 갱신하고 변경사항을 바로 UI에 반영
      if (result) {
        _updateCategoryNameInCache(categoryId, name);
      }

      _setLoading(false);
      return result;
    } catch (e) {
      _setError('카테고리 이름 수정 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 카테고리 커스텀 프로필 이미지 수정
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  /// - [profileImageKey]: 새 프로필 이미지 키 (null이면 기본 이미지로 설정)
  ///
  /// Returns:
  /// - [bool]: 수정 성공 여부
  ///   - true: 수정 성공
  ///   - false: 수정 실패
  Future<bool> updateCustomProfile({
    required int categoryId,
    String? profileImageKey,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final result = await _categoryService.updateCustomProfile(
        categoryId: categoryId,
        profileImageKey: profileImageKey,
      );

      // 서버에는 반영되지만 UI가 바로 갱신되지 않는 경우가 있어,
      // 성공 시 로컬 캐시도 즉시 갱신하여 화면에 바로 반영한다.
      if (result) {
        final normalized = _normalizeProfileImageKey(profileImageKey);

        // 카테고리 캐시 갱신
        _updateCachedCategory(
          categoryId,
          (category) => _copyCategory(
            category,
            photoUrl: normalized,
            clearPhotoUrl: normalized == null,
          ),
        );
      }

      _setLoading(false);
      return result;
    } catch (e) {
      _setError('카테고리 프로필 수정 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 카테고리 커스텀 프로필 이미지 일괄 수정
  ///
  /// fields:
  /// - [profileImageKeysByCategoryId]: 카테고리 ID별 새 프로필 이미지 키 맵 (null이면 기본 이미지로 설정)
  ///
  /// Returns:
  /// - [bool]: 일괄 수정 성공 여부
  ///   - true: 모든 수정 성공
  ///   - false: 하나라도 수정 실패
  Future<bool> updateCustomProfilesBatch({
    required Map<int, String?> profileImageKeysByCategoryId,
  }) async {
    if (profileImageKeysByCategoryId.isEmpty) return true;

    _setLoading(true);
    _clearError();
    try {
      final entries = profileImageKeysByCategoryId.entries.toList(
        growable: false,
      );
      final results = await Future.wait([
        for (final entry in entries)
          _categoryService.updateCustomProfile(
            categoryId: entry.key,
            profileImageKey: entry.value,
          ),
      ]);

      var hasLocalCacheUpdate = false;
      for (var i = 0; i < entries.length; i++) {
        if (!results[i]) continue;

        final entry = entries[i];
        final normalized = _normalizeProfileImageKey(entry.value);
        _updateCachedCategory(
          entry.key,
          (category) => _copyCategory(
            category,
            photoUrl: normalized,
            clearPhotoUrl: normalized == null,
          ),
          notify: false,
        );
        hasLocalCacheUpdate = true;
      }

      if (hasLocalCacheUpdate) {
        notifyListeners();
      }

      _setLoading(false);
      return results.every((value) => value == true);
    } catch (e) {
      _setError('카테고리 프로필 일괄 수정 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  // ============================================
  // 카테고리 삭제 (나가기)
  // ============================================

  /// 카테고리 나가기 (삭제)
  ///
  /// Parameters:
  ///   - [categoryId]: 카테고리 ID
  ///
  /// Returns:
  ///   - [bool]: 나가기 성공 여부
  ///     - true: 나가기 성공
  ///     - false: 나가기 실패
  Future<bool> leaveCategory({required int categoryId}) async {
    _setLoading(true);
    _clearError();
    try {
      // API 호출 - 카테고리 나가기
      final result = await _categoryService.leaveCategory(
        categoryId: categoryId,
      );

      // 성공 시 캐시 무효화
      if (result) {
        invalidateCache();
      }

      _setLoading(false);
      return result;
    } catch (e) {
      _setError('카테고리 나가기 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 카테고리 삭제 (leaveCategory의 별칭)
  ///
  /// Parameters:
  ///   - [categoryId]: 카테고리 ID
  ///
  /// Returns:
  ///   - [bool]: 삭제 성공 여부
  ///     - true: 삭제 성공
  ///     - false: 삭제 실패
  Future<bool> deleteCategory({required int categoryId}) async {
    return leaveCategory(categoryId: categoryId);
  }

  void clearError() {
    if (_errorMessage == null) return;
    _clearError();
    notifyListeners();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    if (_errorMessage == message) return;
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}

class _CachedCategoryRequest {
  const _CachedCategoryRequest({
    required this.categories,
    required this.cachedAt,
  });

  final List<model.Category> categories;
  final DateTime cachedAt;

  _CachedCategoryRequest copyWith({
    List<model.Category>? categories,
    DateTime? cachedAt,
  }) {
    return _CachedCategoryRequest(
      categories: categories ?? this.categories,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }
}
