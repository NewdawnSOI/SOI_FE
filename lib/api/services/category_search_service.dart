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

  CategorySearchService({CategoryAPIApi? categoryApi})
    : _categoryApi = categoryApi ?? SoiApiClient.instance.categoryApi;

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

    try {
      if (!fetchAllPages) {
        final dtos = await _fetchSearchPage(
          filterValue: filter.value,

          keyword: trimmedKeyword,
          page: normalizedPage,
        );
        return dtos.map((dto) => Category.fromDto(dto)).toList();
      }

      // 전체 페이지 조회
      final allCategories = <Category>[];
      final seenIds = <int>{};
      var currentPage = normalizedPage;
      int? firstPageSize;

      for (var i = 0; i < normalizedMaxPages; i++) {
        final dtos = await _fetchSearchPage(
          filterValue: filter.value,

          keyword: trimmedKeyword,
          page: currentPage,
        );

        if (dtos.isEmpty) break;

        firstPageSize ??= dtos.length;

        var addedCount = 0;
        for (final dto in dtos) {
          final dtoId = dto.id;
          if (dtoId != null && seenIds.add(dtoId)) {
            allCategories.add(Category.fromDto(dto));
            addedCount++;
          }
        }

        if (addedCount == 0) break;
        if (dtos.length < firstPageSize) break;

        currentPage++;
      }

      return allCategories;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '카테고리 검색 실패: $e', originalException: e);
    }
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
