import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
import 'package:soi_api_client/api.dart';

import '../api_client.dart';
import '../api_exception.dart';
import '../models/category.dart';

/// 카테고리 검색 API 래퍼 서비스
///
/// `/category/find-by-keyword` 엔드포인트를 통해 서버 사이드 카테고리 검색을 제공합니다.
/// keyword가 null이거나 빈 문자열이면 전체 카테고리를 반환합니다.
class CategorySearchService {
  final CategoryAPIApi _categoryApi;
  final Map<String, Future<List<Category>>> _inFlightSearchQueries = {};
  final Map<String, _CachedCategorySearchResult> _searchCache = {};
  static const Duration _searchCacheTtl = Duration(seconds: 30);

  CategorySearchService({CategoryAPIApi? categoryApi})
    : _categoryApi = categoryApi ?? SoiApiClient.instance.categoryApi;

  String _buildSearchRequestKey({
    int? userId,
    required CategoryFilter filter,
    String? keyword,
    required int page,
    required bool fetchAllPages,
    required int maxPages,
  }) {
    return '${userId ?? 'anonymous'}:${filter.value}:${keyword ?? ''}:$page:$fetchAllPages:$maxPages';
  }

  _CachedCategorySearchResult? _getValidCachedResult(String requestKey) {
    final cached = _searchCache[requestKey];
    if (cached == null) return null;

    if (DateTime.now().difference(cached.cachedAt) >= _searchCacheTtl) {
      _searchCache.remove(requestKey);
      return null;
    }

    return cached;
  }

  void _purgeExpiredCacheEntries() {
    final now = DateTime.now();
    _searchCache.removeWhere(
      (_, entry) => now.difference(entry.cachedAt) >= _searchCacheTtl,
    );
  }

  List<Category> _mapCategories(Iterable<CategoryRespDto> dtos) {
    return List<Category>.unmodifiable(dtos.map(Category.fromDto));
  }

  int _appendUniqueCategories({
    required List<Category> categories,
    required Iterable<CategoryRespDto> dtos,
    required Set<int> seenIds,
  }) {
    var addedCount = 0;
    for (final dto in dtos) {
      final dtoId = dto.id;
      if (dtoId != null && seenIds.add(dtoId)) {
        categories.add(Category.fromDto(dto));
        addedCount++;
      }
    }
    return addedCount;
  }

  /// 키워드로 카테고리 검색
  ///
  /// Parameters:
  /// - [filter]: 카테고리 필터 (ALL, PUBLIC, PRIVATE)
  /// - [keyword]: 검색어 (null이거나 빈 문자열이면 전체 카테고리 반환)
  /// - [page]: 시작 페이지 (기본값: 0)
  /// - [fetchAllPages]: 모든 페이지 조회 여부 (기본값: true)
  /// - [maxPages]: 최대 조회 페이지 수 (기본값: 50)
  ///
  /// Returns: 검색 결과 카테고리 목록
  Future<List<Category>> searchCategories({
    int? userId,
    CategoryFilter filter = CategoryFilter.all,
    String? keyword,
    int page = 0,
    bool fetchAllPages = true,
    int maxPages = 50,
  }) async {
    final normalizedPage = page < 0 ? 0 : page;
    final normalizedMaxPages = maxPages < 1 ? 1 : maxPages;
    final trimmedKeyword = keyword?.trim().isEmpty == true
        ? null
        : keyword?.trim();
    final requestKey = _buildSearchRequestKey(
      userId: userId,
      filter: filter,
      keyword: trimmedKeyword,
      page: normalizedPage,
      fetchAllPages: fetchAllPages,
      maxPages: normalizedMaxPages,
    );

    _purgeExpiredCacheEntries();
    final cached = _getValidCachedResult(requestKey);
    if (cached != null) {
      return cached.categories;
    }

    final task = _inFlightSearchQueries.putIfAbsent(requestKey, () {
      return _searchCategoriesInternal(
        filter: filter,
        keyword: trimmedKeyword,
        page: normalizedPage,
        fetchAllPages: fetchAllPages,
        maxPages: normalizedMaxPages,
      );
    });

    try {
      final results = await task;
      _searchCache[requestKey] = _CachedCategorySearchResult(
        categories: results,
        cachedAt: DateTime.now(),
      );
      return results;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '카테고리 검색 실패: $e', originalException: e);
    } finally {
      final registeredTask = _inFlightSearchQueries[requestKey];
      if (identical(registeredTask, task)) {
        _inFlightSearchQueries.remove(requestKey);
      }
    }
  }

  Future<List<Category>> _searchCategoriesInternal({
    required CategoryFilter filter,
    String? keyword,
    required int page,
    required bool fetchAllPages,
    required int maxPages,
  }) async {
    if (!fetchAllPages) {
      final dtos = await _fetchSearchPage(
        filterValue: filter.value,
        keyword: keyword,
        page: page,
      );
      return _mapCategories(dtos);
    }

    final allCategories = <Category>[];
    final seenIds = <int>{};
    var currentPage = page;
    int? firstPageSize;

    for (var i = 0; i < maxPages; i++) {
      final dtos = await _fetchSearchPage(
        filterValue: filter.value,
        keyword: keyword,
        page: currentPage,
      );

      if (dtos.isEmpty) break;

      firstPageSize ??= dtos.length;

      final addedCount = _appendUniqueCategories(
        categories: allCategories,
        dtos: dtos,
        seenIds: seenIds,
      );

      if (addedCount == 0) break;
      if (dtos.length < firstPageSize) break;

      currentPage++;
    }

    return List<Category>.unmodifiable(allCategories);
  }

  /// 단일 페이지 검색 API 호출 (내부 헬퍼)
  Future<List<CategoryRespDto>> _fetchSearchPage({
    required String filterValue,
    String? keyword,
    required int page,
  }) async {
    final response = await _categoryApi.getCategories1(
      filterValue,
      keyword: keyword,
      page: page,
    );

    if (response == null) return const [];

    if (response.success != true) {
      throw SoiApiException(message: response.message ?? '카테고리 검색 실패');
    }

    return response.data;
  }

  SoiApiException _handleApiException(ApiException e) {
    debugPrint('CategorySearchService API Error [${e.code}]: ${e.message}');

    switch (e.code) {
      case 400:
        return BadRequestException(
          message: e.message ?? '잘못된 요청입니다.',
          originalException: e,
        );
      case 401:
        return AuthException(
          message: e.message ?? '인증이 필요합니다.',
          originalException: e,
        );
      case 403:
        return ForbiddenException(
          message: e.message ?? '접근 권한이 없습니다.',
          originalException: e,
        );
      case 404:
        return NotFoundException(
          message: e.message ?? '카테고리를 찾을 수 없습니다.',
          originalException: e,
        );
      case >= 500:
        return ServerException(
          statusCode: e.code,
          message: e.message ?? '서버 오류가 발생했습니다.',
          originalException: e,
        );
      default:
        return SoiApiException(
          statusCode: e.code,
          message: e.message ?? '알 수 없는 오류가 발생했습니다.',
          originalException: e,
        );
    }
  }
}

class _CachedCategorySearchResult {
  const _CachedCategorySearchResult({
    required this.categories,
    required this.cachedAt,
  });

  final List<Category> categories;
  final DateTime cachedAt;
}
