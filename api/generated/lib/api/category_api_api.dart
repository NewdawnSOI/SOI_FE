//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class CategoryAPIApi {
  CategoryAPIApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// 카테고리 알림설정
  ///
  /// 유저아이디와 카테고리 아이디로 알림을 설정합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] categoryId (required):
  Future<Response> categoryAlertWithHttpInfo(int categoryId,) async {
    // ignore: prefer_const_declarations
    final path = r'/category/set/alert';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'categoryId', categoryId));

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 카테고리 알림설정
  ///
  /// 유저아이디와 카테고리 아이디로 알림을 설정합니다.
  ///
  /// Parameters:
  ///
  /// * [int] categoryId (required):
  Future<ApiResponseDtoBoolean?> categoryAlert(int categoryId,) async {
    final response = await categoryAlertWithHttpInfo(categoryId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoBoolean',) as ApiResponseDtoBoolean;
    
    }
    return null;
  }

  /// 카테고리 고정
  ///
  /// 카테고리 아이디, 유저 아이디로 카테고리를 고정 혹은 고정해제 시킵니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] categoryId (required):
  Future<Response> categoryPinnedWithHttpInfo(int categoryId,) async {
    // ignore: prefer_const_declarations
    final path = r'/category/set/pinned';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'categoryId', categoryId));

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 카테고리 고정
  ///
  /// 카테고리 아이디, 유저 아이디로 카테고리를 고정 혹은 고정해제 시킵니다.
  ///
  /// Parameters:
  ///
  /// * [int] categoryId (required):
  Future<ApiResponseDtoBoolean?> categoryPinned(int categoryId,) async {
    final response = await categoryPinnedWithHttpInfo(categoryId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoBoolean',) as ApiResponseDtoBoolean;
    
    }
    return null;
  }

  /// 카테고리 추가
  ///
  /// 카테고리를 추가합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [CategoryCreateReqDto] categoryCreateReqDto (required):
  Future<Response> create4WithHttpInfo(CategoryCreateReqDto categoryCreateReqDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/category/create';

    // ignore: prefer_final_locals
    Object? postBody = categoryCreateReqDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 카테고리 추가
  ///
  /// 카테고리를 추가합니다.
  ///
  /// Parameters:
  ///
  /// * [CategoryCreateReqDto] categoryCreateReqDto (required):
  Future<ApiResponseDtoLong?> create4(CategoryCreateReqDto categoryCreateReqDto,) async {
    final response = await create4WithHttpInfo(categoryCreateReqDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoLong',) as ApiResponseDtoLong;
    
    }
    return null;
  }

  /// 카테고리 이름수정
  ///
  /// 카테고리 아이디, 유저 아이디, 수정할 이름을 받아 카테고리 이름을 수정합니다. 커스텀한 이름을 삭제하길 원하면 name에 그냥 빈값 \"\" 을 넣으면 커스텀 이름이 삭제됩니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] categoryId (required):
  ///
  /// * [String] name:
  Future<Response> customNameWithHttpInfo(int categoryId, { String? name, }) async {
    // ignore: prefer_const_declarations
    final path = r'/category/set/name';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'categoryId', categoryId));
    if (name != null) {
      queryParams.addAll(_queryParams('', 'name', name));
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 카테고리 이름수정
  ///
  /// 카테고리 아이디, 유저 아이디, 수정할 이름을 받아 카테고리 이름을 수정합니다. 커스텀한 이름을 삭제하길 원하면 name에 그냥 빈값 \"\" 을 넣으면 커스텀 이름이 삭제됩니다.
  ///
  /// Parameters:
  ///
  /// * [int] categoryId (required):
  ///
  /// * [String] name:
  Future<ApiResponseDtoBoolean?> customName(int categoryId, { String? name, }) async {
    final response = await customNameWithHttpInfo(categoryId,  name: name, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoBoolean',) as ApiResponseDtoBoolean;
    
    }
    return null;
  }

  /// 카테고리 프로필 수정
  ///
  /// 카테고리 아이디, 유저 아이디, 수정할 프로필 사진을 받아 프로필을 수정합니다. 기본 프로필로 변경하고싶으면 profileImageKey에 \"\" 을 넣으면 됩니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] categoryId (required):
  ///
  /// * [String] profileImageKey:
  Future<Response> customProfileWithHttpInfo(int categoryId, { String? profileImageKey, }) async {
    // ignore: prefer_const_declarations
    final path = r'/category/set/profile';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'categoryId', categoryId));
    if (profileImageKey != null) {
      queryParams.addAll(_queryParams('', 'profileImageKey', profileImageKey));
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 카테고리 프로필 수정
  ///
  /// 카테고리 아이디, 유저 아이디, 수정할 프로필 사진을 받아 프로필을 수정합니다. 기본 프로필로 변경하고싶으면 profileImageKey에 \"\" 을 넣으면 됩니다.
  ///
  /// Parameters:
  ///
  /// * [int] categoryId (required):
  ///
  /// * [String] profileImageKey:
  Future<ApiResponseDtoBoolean?> customProfile(int categoryId, { String? profileImageKey, }) async {
    final response = await customProfileWithHttpInfo(categoryId,  profileImageKey: profileImageKey, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoBoolean',) as ApiResponseDtoBoolean;
    
    }
    return null;
  }

  /// 카테고리 나가기 (삭제)
  ///
  /// 카테고리를 나갑니다. (만약 카테고리에 속한 유저가 본인밖에 없으면 관련 데이터 다 삭제)
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] categoryId (required):
  Future<Response> delete1WithHttpInfo(int categoryId,) async {
    // ignore: prefer_const_declarations
    final path = r'/category/delete';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'categoryId', categoryId));

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 카테고리 나가기 (삭제)
  ///
  /// 카테고리를 나갑니다. (만약 카테고리에 속한 유저가 본인밖에 없으면 관련 데이터 다 삭제)
  ///
  /// Parameters:
  ///
  /// * [int] categoryId (required):
  Future<ApiResponseDtoObject?> delete1(int categoryId,) async {
    final response = await delete1WithHttpInfo(categoryId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoObject',) as ApiResponseDtoObject;
    
    }
    return null;
  }

  /// 유저가 속한 카테고리 리스트를 가져오는 API
  ///
  /// CategoryFilter : ALL, PUBLIC, PRIVATE -> 옵션에 따라서 전체, 그룹, 개인으로 가져올 수 있음
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] categoryFilter (required):
  ///
  /// * [int] page:
  Future<Response> getCategoriesWithHttpInfo(String categoryFilter, { int? page, }) async {
    // ignore: prefer_const_declarations
    final path = r'/category/find';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'categoryFilter', categoryFilter));
    if (page != null) {
      queryParams.addAll(_queryParams('', 'page', page));
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 유저가 속한 카테고리 리스트를 가져오는 API
  ///
  /// CategoryFilter : ALL, PUBLIC, PRIVATE -> 옵션에 따라서 전체, 그룹, 개인으로 가져올 수 있음
  ///
  /// Parameters:
  ///
  /// * [String] categoryFilter (required):
  ///
  /// * [int] page:
  Future<ApiResponseDtoListCategoryRespDto?> getCategories(String categoryFilter, { int? page, }) async {
    final response = await getCategoriesWithHttpInfo(categoryFilter,  page: page, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoListCategoryRespDto',) as ApiResponseDtoListCategoryRespDto;
    
    }
    return null;
  }

  /// 유저가 속한 카테고를 검색하는 API
  ///
  /// CategoryFilter : ALL, PUBLIC, PRIVATE -> 옵션에 따라서 전체, 그룹, 개인으로 가져올 수 있음, keyword에 검색어 입력, 만약 검색어가 null이거나 빈문자열일경우 그냥 전체 카테고리를 가져옴
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] categoryFilter (required):
  ///
  /// * [String] keyword:
  ///
  /// * [int] page:
  Future<Response> getCategories1WithHttpInfo(String categoryFilter, { String? keyword, int? page, }) async {
    // ignore: prefer_const_declarations
    final path = r'/category/find-by-keyword';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'categoryFilter', categoryFilter));
    if (keyword != null) {
      queryParams.addAll(_queryParams('', 'keyword', keyword));
    }
    if (page != null) {
      queryParams.addAll(_queryParams('', 'page', page));
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 유저가 속한 카테고를 검색하는 API
  ///
  /// CategoryFilter : ALL, PUBLIC, PRIVATE -> 옵션에 따라서 전체, 그룹, 개인으로 가져올 수 있음, keyword에 검색어 입력, 만약 검색어가 null이거나 빈문자열일경우 그냥 전체 카테고리를 가져옴
  ///
  /// Parameters:
  ///
  /// * [String] categoryFilter (required):
  ///
  /// * [String] keyword:
  ///
  /// * [int] page:
  Future<ApiResponseDtoListCategoryRespDto?> getCategories1(String categoryFilter, { String? keyword, int? page, }) async {
    final response = await getCategories1WithHttpInfo(categoryFilter,  keyword: keyword, page: page, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoListCategoryRespDto',) as ApiResponseDtoListCategoryRespDto;
    
    }
    return null;
  }

  /// 카테고리에 초대된 유저가 초대 승낙여부를 결정하는 API
  ///
  /// status에 넣을 수 있는 상태 : PENDING, ACCEPTED, DECLINED, EXPIRED
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [CategoryInviteResponseReqDto] categoryInviteResponseReqDto (required):
  Future<Response> inviteResponseWithHttpInfo(CategoryInviteResponseReqDto categoryInviteResponseReqDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/category/invite/response';

    // ignore: prefer_final_locals
    Object? postBody = categoryInviteResponseReqDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 카테고리에 초대된 유저가 초대 승낙여부를 결정하는 API
  ///
  /// status에 넣을 수 있는 상태 : PENDING, ACCEPTED, DECLINED, EXPIRED
  ///
  /// Parameters:
  ///
  /// * [CategoryInviteResponseReqDto] categoryInviteResponseReqDto (required):
  Future<ApiResponseDtoBoolean?> inviteResponse(CategoryInviteResponseReqDto categoryInviteResponseReqDto,) async {
    final response = await inviteResponseWithHttpInfo(categoryInviteResponseReqDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoBoolean',) as ApiResponseDtoBoolean;
    
    }
    return null;
  }

  ///  카테고리에 유저 추가(초대)
  ///
  /// 이미 생성된 카테고리에 유저를 추가(초대)할 때 사용합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [CategoryInviteReqDto] categoryInviteReqDto (required):
  Future<Response> inviteUserWithHttpInfo(CategoryInviteReqDto categoryInviteReqDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/category/invite';

    // ignore: prefer_final_locals
    Object? postBody = categoryInviteReqDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  ///  카테고리에 유저 추가(초대)
  ///
  /// 이미 생성된 카테고리에 유저를 추가(초대)할 때 사용합니다.
  ///
  /// Parameters:
  ///
  /// * [CategoryInviteReqDto] categoryInviteReqDto (required):
  Future<ApiResponseDtoBoolean?> inviteUser(CategoryInviteReqDto categoryInviteReqDto,) async {
    final response = await inviteUserWithHttpInfo(categoryInviteReqDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoBoolean',) as ApiResponseDtoBoolean;
    
    }
    return null;
  }
}
