import 'package:flutter/material.dart';

import '../models/category.dart';
import '../services/category_search_service.dart';

/// 카테고리 검색 상태 관리 컨트롤러
/// 카테고리 검색 화면에서 사용되는 검색어, 필터, 검색 결과 등을 관리하는 ChangeNotifier 기반 컨트롤러입니다.
/// API 호출은 CategorySearchService를 통해 수행됩니다.
class CategorySearchController extends ChangeNotifier {
  final CategorySearchService _searchService;

  String _searchQuery = ''; // 현재 검색어
  CategoryFilter _activeFilter = CategoryFilter.all; // 현재 활성화된 필터
  bool _isSearchLoading = false; // 검색 API 호출 중인지 여부
  int? _lastSearchUserId;
  int _searchGeneration = 0;
  int _nextRequestToken = 0;
  final Map<CategoryFilter, int> _latestRequestTokenByFilter = {};

  /// 필터별 검색 결과 캐시
  final Map<CategoryFilter, List<Category>> _resultsByFilter = {};

  CategorySearchController({CategorySearchService? searchService})
    : _searchService = searchService ?? CategorySearchService();

  String get searchQuery => _searchQuery;
  CategoryFilter get activeFilter => _activeFilter;
  bool get isSearchLoading => _isSearchLoading;

  /// 특정 필터의 검색 결과를 반환한다.
  ///
  /// 해당 필터로 아직 검색한 적 없으면 빈 리스트를 반환한다.
  List<Category> filteredCategoriesFor(CategoryFilter filter) =>
      _resultsByFilter[filter] ?? const [];

  bool _isLatestRequest({
    required int userId,
    required String query,
    required CategoryFilter filter,
    required int generation,
    required int requestToken,
  }) {
    return _searchGeneration == generation &&
        _lastSearchUserId == userId &&
        _searchQuery == query &&
        _latestRequestTokenByFilter[filter] == requestToken;
  }

  /// 캐시된 검색 결과를 재사용할 수 있는지 여부를 판단한다.
  /// - 동일한 사용자 ID, 검색어, 필터에 대해서는 API를 재호출하지 않고 캐시된 결과를 재사용할 수 있다.
  /// - 검색어가 빈 문자열인 경우는 검색 결과가 없으므로 캐시 재사용이 불가능하다.
  bool _canReuseCachedResults({
    required int userId,
    required String query,
    required CategoryFilter filter,
  }) {
    return _lastSearchUserId == userId &&
        _searchQuery == query &&
        _resultsByFilter.containsKey(filter);
  }

  // ============================================
  // API 기반 검색
  // ============================================

  /// 서버 사이드 키워드 검색
  ///
  /// `/category/find-by-keyword` API를 호출하여 해당 [filter]의 결과를 업데이트합니다.
  /// 다른 필터의 기존 결과는 유지되므로 탭 전환 중에도 화면이 깜빡이지 않습니다.
  ///
  /// Parameters:
  ///   - [userId]: 현재 사용자 ID
  ///   - [query]: 검색어 (빈 문자열이면 clearSearch 처리)
  ///   - [filter]: 검색할 카테고리 필터 (기본값: CategoryFilter.all)
  Future<void> searchCategoriesFromApi({
    required int userId,
    required String query,
    CategoryFilter filter = CategoryFilter.all,
  }) async {
    final trimmedQuery = query.trim();
    final didUserChange =
        _lastSearchUserId != null && _lastSearchUserId != userId;
    var shouldNotify = false;

    if (didUserChange) {
      _searchGeneration++;
      if (_resultsByFilter.isNotEmpty) {
        _resultsByFilter.clear();
        shouldNotify = true;
      }
      if (_isSearchLoading) {
        _isSearchLoading = false;
        shouldNotify = true;
      }
    }

    _lastSearchUserId = userId;

    if (_searchQuery != trimmedQuery) {
      _searchQuery = trimmedQuery;
      shouldNotify = true;
    }
    if (_activeFilter != filter) {
      _activeFilter = filter;
      shouldNotify = true;
    }

    if (trimmedQuery.isEmpty) {
      _searchGeneration++;
      _latestRequestTokenByFilter.clear();
      if (_resultsByFilter.isNotEmpty) {
        _resultsByFilter.clear();
        shouldNotify = true;
      }
      if (_isSearchLoading) {
        _isSearchLoading = false;
        shouldNotify = true;
      }
      if (shouldNotify) {
        notifyListeners();
      }
      return;
    }

    // 캐시된 결과를 재사용할 수 있으면 API 호출 없이 캐시된 결과를 사용한다.
    if (_canReuseCachedResults(
      userId: userId,
      query: trimmedQuery,
      filter: filter,
    )) {
      if (_isSearchLoading) {
        // API 호출이 진행 중이었지만, 캐시된 결과를 재사용할 수 있으므로 로딩 상태를 해제한다.
        _isSearchLoading = false;
        shouldNotify = true;
      }
      if (shouldNotify) {
        // 캐시된 결과로 화면을 업데이트한다.
        notifyListeners();
      }
      return;
    }

    final requestGeneration = _searchGeneration;
    final requestToken = ++_nextRequestToken;
    _latestRequestTokenByFilter[filter] = requestToken;

    if (!_isSearchLoading) {
      _isSearchLoading = true;
      shouldNotify = true;
    }
    if (shouldNotify) {
      notifyListeners();
    }

    try {
      // Service 레이어에서 API 호출 및 결과 매핑을 담당한다.
      final results = await _searchService.searchCategories(
        userId: userId,
        filter: filter,
        keyword: trimmedQuery,
      );

      if (!_isLatestRequest(
        userId: userId,
        query: trimmedQuery,
        filter: filter,
        generation: requestGeneration,
        requestToken: requestToken,
      )) {
        return;
      }

      _resultsByFilter[filter] = List<Category>.unmodifiable(results);
    } catch (_) {
      if (!_isLatestRequest(
        userId: userId,
        query: trimmedQuery,
        filter: filter,
        generation: requestGeneration,
        requestToken: requestToken,
      )) {
        return;
      }

      _resultsByFilter[filter] = const []; // 실패 시 해당 필터 결과는 빈 리스트로 설정
    } finally {
      if (_isLatestRequest(
        userId: userId,
        query: trimmedQuery,
        filter: filter,
        generation: requestGeneration,
        requestToken: requestToken,
      )) {
        _isSearchLoading = false; // 로딩 상태 해제
        notifyListeners();
      }
    }
  }

  /// 검색 상태를 초기화한다.
  void clearSearch({bool notify = true}) {
    final hadState =
        _searchQuery.isNotEmpty ||
        _activeFilter != CategoryFilter.all ||
        _isSearchLoading ||
        _resultsByFilter.isNotEmpty;
    _searchGeneration++;
    _searchQuery = '';
    _activeFilter = CategoryFilter.all;
    _isSearchLoading = false;
    _lastSearchUserId = null;
    _latestRequestTokenByFilter.clear();
    _resultsByFilter.clear();
    if (notify && hadState) {
      notifyListeners();
    }
  }
}
