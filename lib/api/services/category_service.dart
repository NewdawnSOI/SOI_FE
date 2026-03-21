import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
import 'package:soi_api_client/api.dart';

import '../api_client.dart';
import '../api_exception.dart';
import '../models/models.dart';

/// 카테고리 초대 상태
///
/// 카테고리 초대에 대한 응답 상태입니다.
enum CategoryInviteStatus {
  /// 대기 중
  pending('PENDING'),

  /// 수락됨
  accepted('ACCEPTED'),

  /// 거절됨
  declined('DECLINED'),

  /// 만료됨
  expired('EXPIRED');

  final String value;
  const CategoryInviteStatus(this.value);
}

/// 카테고리 관련 API 래퍼 서비스
///
/// 카테고리 생성, 조회, 초대 관리 등 카테고리 관련 기능을 제공합니다.
/// Provider를 통해 주입받아 사용합니다.
///
/// 사용 예시:
/// ```dart
/// final categoryService = Provider.of<CategoryService>(context, listen: false);
///
/// // 카테고리 생성
/// final categoryId = await categoryService.createCategory(
///   requesterId: 1,
///   name: '우리 그룹',
///   receiverIds: [2, 3, 4],
///   isPublic: true,
/// );
///
/// // 카테고리 목록 조회
/// final categories = await categoryService.getCategories(
///   userId: 1,
///   filter: CategoryFilter.all,
/// );
/// ```
class CategoryService {
  final CategoryAPIApi _categoryApi;
  final Map<String, Future<List<Category>>> _inFlightCategoryQueries =
      {}; // 중복 API 호출 방지용 캐시

  CategoryService({CategoryAPIApi? categoryApi})
    : _categoryApi = categoryApi ?? SoiApiClient.instance.categoryApi;

  ///
  /// 카테고리 목록 조회 시 요청 파라미터를 조합하여 고유 키를 생성하는 헬퍼 메서드입니다.
  /// 중복 API 호출 방지 로직에서 사용됩니다.
  ///
  /// Parameters:
  /// - [filter]: 카테고리 필터 (ALL, PUBLIC, PRIVATE)
  /// - [page]: 페이지 번호
  /// - [fetchAllPages]: 모든 페이지를 조회할지 여부
  /// - [maxPages]: 최대 조회 페이지 수
  ///
  /// Returns
  /// - [String]: 요청 파라미터를 조합한 고유 키 문자열
  String _buildCategoryRequestKey({
    required CategoryFilter filter,
    required int page,
    required bool fetchAllPages,
    required int maxPages,
  }) {
    return '${filter.value}:$page:$fetchAllPages:$maxPages';
  }

  /// 카테고리 DTO 리스트를 도메인 모델 리스트로 변환하는 헬퍼 메서드입니다.
  /// Parameters:
  /// - [dtos]: 카테고리 DTO 리스트
  ///
  /// Returns:
  /// - [List<Category>]: 도메인 모델 리스트
  List<Category> _mapCategories(Iterable<CategoryRespDto> dtos) {
    return List<Category>.unmodifiable(dtos.map(Category.fromDto));
  }

  /// 중복 ID를 체크하여 고유한 카테고리만 리스트에 추가하는 헬퍼 메서드입니다.
  /// API에서 페이지네이션된 데이터를 가져올 때, 중복된 카테고리가 포함될 수 있으므로 이를 방지하기 위해 사용됩니다.
  /// Parameters:
  /// - [categories]: 고유한 카테고리를 추가할 리스트 (변경 가능)
  /// - [dtos]: API에서 가져온 카테고리 DTO 리스트
  /// - [seenIds]: 이미 추가된 카테고리 ID를 저장하는 집합
  ///
  /// Returns:
  /// - [int]: 새로 추가된 고유 카테고리의 수
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

  // ============================================
  // 카테고리 생성
  // ============================================

  /// 카테고리 생성
  ///
  /// 새로운 카테고리(앨범)를 생성합니다.
  ///
  /// Parameters:
  /// - [requesterId]: 생성 요청자 ID
  /// - [name]: 카테고리 이름
  /// - [receiverIds]: 초대할 사용자 ID 목록
  /// - [isPublic]: 공개 여부 (true: 그룹, false: 개인)
  ///
  /// Returns: 생성된 카테고리 ID (int)
  Future<int> createCategory({
    required int requesterId,
    required String name,
    List<int> receiverIds = const [],
    bool isPublic = true,
  }) async {
    try {
      final dto = CategoryCreateReqDto(
        requesterId: requesterId,
        name: name,
        receiverIds: receiverIds,
        isPublic: isPublic,
      );

      final response = await _categoryApi.create4(
        dto,
      ); // API 명세에 따라 create4로 호출

      if (response == null) {
        throw const DataValidationException(message: '카테고리 생성 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '카테고리 생성 실패');
      }

      if (response.data == null) {
        throw const DataValidationException(message: '생성된 카테고리 ID가 없습니다.');
      }

      return response.data!;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '카테고리 생성 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 카테고리 조회
  // ============================================

  /// 단일 페이지 카테고리 DTO 조회 (내부 헬퍼)
  ///
  /// API 호출 + null/에러 체크를 한 곳에서 처리합니다.
  /// 매핑 전 원시 DTO를 반환하여 호출측에서 필요한 항목만 변환할 수 있습니다.
  ///
  /// Returns: DTO 리스트 (빈 리스트 = 데이터 없음 또는 마지막 페이지)
  Future<List<CategoryRespDto>> _fetchCategoryPage({
    required String filterValue,
    required int page,
  }) async {
    final response = await _categoryApi.getCategories(filterValue, page: page);

    if (response == null) return const [];

    if (response.success != true) {
      throw SoiApiException(message: response.message ?? '카테고리 목록 조회 실패');
    }

    return response.data;
  }

  /// 사용자의 카테고리 목록 조회
  ///
  /// Parameters:
  /// - [filter]: 카테고리 필터 (ALL, PUBLIC, PRIVATE)
  /// - [page]: 시작 페이지 (기본값: 0)
  /// - [fetchAllPages]: 모든 페이지를 조회할지 여부 (기본값: true)
  /// - [maxPages]: 최대 조회 페이지 수 (기본값: 50)
  ///
  /// Returns: 카테고리 목록 (`List<Category>`)
  Future<List<Category>> getCategories({
    CategoryFilter filter = CategoryFilter.all,
    int page = 0,
    bool fetchAllPages = true, // 페이지네이션이 필요한 경우 true로 설정 (기본값: true)
    int maxPages = 50,
  }) async {
    final normalizedPage = page < 0 ? 0 : page;
    final normalizedMaxPages = maxPages < 1 ? 1 : maxPages;

    // 요청 파라미터를 조합하여 고유 키 생성 (중복 API 호출 방지용)
    final requestKey = _buildCategoryRequestKey(
      filter: filter,
      page: normalizedPage,
      fetchAllPages: fetchAllPages,
      maxPages: normalizedMaxPages,
    );

    // 중복 API 호출 방지: 동일한 요청이 이미 진행 중이면 기존 작업 반환
    final task = _inFlightCategoryQueries.putIfAbsent(requestKey, () {
      return _getCategoriesInternal(
        filter: filter,
        page: normalizedPage,
        fetchAllPages: fetchAllPages,
        maxPages: normalizedMaxPages,
      );
    });

    try {
      return await task;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '카테고리 목록 조회 실패: $e', originalException: e);
    } finally {
      // API 호출이 완료된 후에도 동일한 요청이 들어올 수 있으므로,
      // 등록된 작업이 현재 작업과 동일한 경우에만 제거하여 중복 API 호출 방지 로직 유지
      final registeredTask = _inFlightCategoryQueries[requestKey];
      if (identical(registeredTask, task)) {
        // 현재 작업이 등록된 작업과 동일한 경우에만 제거
        _inFlightCategoryQueries.remove(requestKey);
      }
    }
  }

  /// 카테고리 목록 조회 내부 구현
  /// API 호출과 페이지네이션 로직을 처리합니다.
  /// 중복 API 호출 방지 로직은 getCategories()에서 처리하므로 이 메서드는 단일 요청에 집중할 수 있습니다.
  Future<List<Category>> _getCategoriesInternal({
    required CategoryFilter filter,
    required int page,
    required bool fetchAllPages,
    required int maxPages,
  }) async {
    // 단일 페이지 조회
    if (!fetchAllPages) {
      // 단일 페이지 조회: API 호출 후 바로 매핑하여 반환
      final dtos = await _fetchCategoryPage(
        filterValue: filter.value,
        page: page,
      );
      return _mapCategories(dtos); // 단일 페이지 결과 매핑 후 반환
    }

    // 전체 페이지 조회
    final allCategories = <Category>[];
    final seenIds = <int>{};
    var currentPage = page;
    int? firstPageSize;

    // API가 페이지네이션된 데이터를 반환할 때,
    // 중복된 카테고리가 포함될 수 있으므로 이를 방지하기 위해 seenIds 집합을 사용하여 고유한 카테고리만 추가합니다.
    for (var i = 0; i < maxPages; i++) {
      final dtos = await _fetchCategoryPage(
        filterValue: filter.value,

        page: currentPage,
      );

      if (dtos.isEmpty) break;

      // 첫 페이지 크기를 기록하여 마지막 페이지 감지에 활용
      firstPageSize ??= dtos.length;

      // DTO id로 중복 체크 후 Category 객체 생성 (불필요한 객체 생성 방지)
      final addedCount = _appendUniqueCategories(
        categories: allCategories,
        dtos: dtos,
        seenIds: seenIds,
      );

      // 서버가 같은 페이지를 반복 반환할 경우 무한 루프 방지
      if (addedCount == 0) break;

      // 마지막 페이지 감지: 반환 항목이 첫 페이지보다 적으면 종료
      if (dtos.length < firstPageSize) break;

      currentPage++;
    }

    return List<Category>.unmodifiable(allCategories);
  }

  // ============================================
  // 카테고리 고정
  // ============================================

  /// 카테고리 고정/고정해제 토글
  /// [categoryId]를 고정하거나 고정 해제합니다.
  ///
  /// Parameters:
  /// - [categoryId]: 고정/고정 해제할 카테고리 ID
  ///
  /// Returns:
  /// - true: 고정됨
  /// - false: 고정 해제됨
  Future<bool> toggleCategoryPin({required int categoryId}) async {
    try {
      final response = await _categoryApi.categoryPinned(categoryId);

      if (response == null) {
        throw const DataValidationException(message: '카테고리 고정 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '카테고리 고정 변경 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '카테고리 고정 변경 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 카테고리 알림 설정
  // ============================================

  /// 카테고리 알림 설정
  /// - [categoryId]에 대한 알림 상태를 설정합니다.
  ///
  /// Parameters:
  /// - [categoryId]: 알림 설정을 변경할 카테고리 ID
  ///
  /// Returns:
  /// - true: 알림 설정됨
  /// - false: 알림 해제됨
  Future<bool> setCategoryAlert({required int categoryId}) async {
    try {
      final response = await _categoryApi.categoryAlert(categoryId);

      if (response == null) {
        throw const DataValidationException(message: '카테고리 알림 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '카테고리 알림 설정 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '카테고리 알림 설정 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 카테고리 초대
  // ============================================

  /// 카테고리에 사용자 초대
  ///
  /// 기존 카테고리에 새로운 사용자를 초대합니다.
  /// 초대받은 사용자는 카테고리에 참여하게 되며, 초대 요청자와 초대받는 사용자 모두에게 알림이 전송됩니다.
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  /// - [requesterId]: 초대 요청자 ID
  /// - [receiverIds]: 초대받을 사용자 ID 목록
  ///
  /// Returns
  /// - [true]: 초대 성공 여부
  /// - [false]: 초대 실패 (예: 이미 초대된 사용자 포함)
  Future<bool> inviteUsersToCategory({
    required int categoryId,
    required int requesterId,
    required List<int> receiverIds,
  }) async {
    try {
      // DTO 생성 - API 명세에 맞게 요청 데이터 구성
      final dto = CategoryInviteReqDto(
        categoryId: categoryId,
        requesterId: requesterId,
        receiverId: receiverIds,
      );

      // API 호출 - 사용자 초대
      final response = await _categoryApi.inviteUser(dto);

      if (response == null) {
        throw const DataValidationException(message: '초대 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '사용자 초대 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '사용자 초대 실패: $e', originalException: e);
    }
  }

  /// 카테고리 초대 응답
  ///
  /// 받은 초대에 대해 수락/거절 응답을 합니다.
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  /// - [responserId]: 응답자 ID (초대받은 사용자)
  /// - [status]: 응답 상태 (ACCEPTED, DECLINED 등)
  ///
  /// Returns
  /// - [true]: 응답 처리 성공 여부
  /// - [false]: 응답 처리 실패 (예: 이미 응답한 초대에 대한 중복 응답)
  Future<bool> respondToInvite({
    required int categoryId,
    required int responserId,
    required CategoryInviteStatus status,
  }) async {
    try {
      final dto = CategoryInviteResponseReqDto(
        categoryId: categoryId,
        responserId: responserId,
        status: _toCategoryInviteStatusEnum(status),
      );

      final response = await _categoryApi.inviteResponse(dto);

      if (response == null) {
        throw const DataValidationException(message: '초대 응답 처리 결과가 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '초대 응답 처리 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '초대 응답 처리 실패: $e', originalException: e);
    }
  }

  /// 카테고리 초대 수락 (편의 메서드)
  Future<bool> acceptInvite({
    required int categoryId,
    required int responserId,
  }) async {
    return respondToInvite(
      categoryId: categoryId,
      responserId: responserId,
      status: CategoryInviteStatus.accepted,
    );
  }

  /// 카테고리 초대 거절 (편의 메서드)
  Future<bool> declineInvite({
    required int categoryId,
    required int responserId,
  }) async {
    return respondToInvite(
      categoryId: categoryId,
      responserId: responserId,
      status: CategoryInviteStatus.declined,
    );
  }

  // ============================================
  // 카테고리 설정 (이름, 프로필)
  // ============================================

  /// 카테고리 커스텀 이름 수정
  ///
  /// 카테고리의 사용자별 커스텀 이름을 수정합니다.
  /// 빈 문자열("")을 전달하면 커스텀 이름이 삭제되고 원래 이름으로 돌아갑니다.
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  /// - [name]: 새로운 커스텀 이름 (빈 문자열이면 커스텀 이름 삭제)
  ///
  /// Returns: 수정 성공 여부
  Future<bool> updateCustomName({required int categoryId, String? name}) async {
    try {
      final response = await _categoryApi.customName(categoryId, name: name);

      if (response == null) {
        throw const DataValidationException(message: '카테고리 이름 수정 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '카테고리 이름 수정 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '카테고리 이름 수정 실패: $e', originalException: e);
    }
  }

  /// 카테고리 커스텀 프로필 이미지 수정
  ///
  /// 카테고리의 사용자별 커스텀 프로필 이미지를 수정합니다.
  /// 빈 문자열("")을 전달하면 기본 프로필로 변경됩니다.
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID

  /// - [profileImageKey]: 새로운 프로필 이미지 키 (빈 문자열이면 기본 프로필)
  ///
  /// Returns: 수정 성공 여부
  Future<bool> updateCustomProfile({
    required int categoryId,
    String? profileImageKey,
  }) async {
    try {
      final response = await _categoryApi.customProfile(
        categoryId,
        profileImageKey: profileImageKey,
      );

      if (response == null) {
        throw const DataValidationException(message: '카테고리 프로필 수정 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '카테고리 프로필 수정 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(
        message: '카테고리 프로필 수정 실패: $e',
        originalException: e,
      );
    }
  }

  // ============================================
  // 카테고리 삭제 (나가기)
  // ============================================

  /// 카테고리 나가기 (삭제)
  ///
  /// 카테고리에서 나갑니다.
  /// 만약 카테고리에 속한 유저가 본인밖에 없으면 관련 데이터가 모두 삭제됩니다.
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  ///
  /// Returns: 삭제/나가기 성공 여부
  Future<bool> leaveCategory({required int categoryId}) async {
    try {
      // API 호출 - 카테고리 나가기
      final response = await _categoryApi.delete1(categoryId);

      if (response == null) {
        throw const DataValidationException(message: '카테고리 나가기 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '카테고리 나가기 실패');
      }

      return true;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '카테고리 나가기 실패: $e', originalException: e);
    }
  }

  /// 카테고리 삭제 (leaveCategory의 별칭)
  Future<bool> deleteCategory({required int categoryId}) async {
    return leaveCategory(categoryId: categoryId);
  }

  // ============================================
  // 에러 핸들링 헬퍼
  // ============================================

  SoiApiException _handleApiException(ApiException e) {
    debugPrint('API Error [${e.code}]: ${e.message}');

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

  /// CategoryInviteStatus를 API enum으로 변환
  CategoryInviteResponseReqDtoStatusEnum? _toCategoryInviteStatusEnum(
    CategoryInviteStatus status,
  ) {
    switch (status) {
      case CategoryInviteStatus.pending:
        return CategoryInviteResponseReqDtoStatusEnum.PENDING;
      case CategoryInviteStatus.accepted:
        return CategoryInviteResponseReqDtoStatusEnum.ACCEPTED;
      case CategoryInviteStatus.declined:
        return CategoryInviteResponseReqDtoStatusEnum.DECLINED;
      case CategoryInviteStatus.expired:
        return CategoryInviteResponseReqDtoStatusEnum.EXPIRED;
    }
  }
}
