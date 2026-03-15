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
      List.unmodifiable(_resultsByFilter[filter] ?? const []);

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
    _searchQuery = trimmedQuery;
    _activeFilter = filter;

    if (trimmedQuery.isEmpty) {
      _resultsByFilter.clear();
      notifyListeners();
      return;
    }

    _isSearchLoading = true;
    notifyListeners();

    try {
      // Service 레이어에서 API 호출 및 결과 매핑을 담당한다.
      final results = await _searchService.searchCategories(
        filter: filter,
        keyword: trimmedQuery,
      );

      _resultsByFilter[filter] = results; // 필터별 결과 업데이트
    } catch (_) {
      _resultsByFilter[filter] = const []; // 실패 시 해당 필터 결과는 빈 리스트로 설정
    } finally {
      _isSearchLoading = false; // 로딩 상태 해제
      notifyListeners();
    }
  }

  /// 검색 상태를 초기화한다.
  void clearSearch({bool notify = true}) {
    _searchQuery = '';
    _activeFilter = CategoryFilter.all;
    _isSearchLoading = false;
    _resultsByFilter.clear();
    if (notify) {
      notifyListeners();
    }
  }
}
