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

  /// 카테고리 추가
  ///
  /// 카테고리를 추가합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [CategoryCreateReqDto] categoryCreateReqDto (required):
  Future<Response> create1WithHttpInfo(CategoryCreateReqDto categoryCreateReqDto,) async {
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
  Future<ApiResponseDtoLong?> create1(CategoryCreateReqDto categoryCreateReqDto,) async {
    final response = await create1WithHttpInfo(categoryCreateReqDto,);
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

  /// 카테고리에 초대된 유저가 초대 승낙여부를 결정하는 API
  ///
  /// status에 넣을 수 있는 상태 : PENDING, ACCEPTED, DECLINED, EXPIRED
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [CategoryInviteResponseReqDto] categoryInviteResponseReqDto (required):
  Future<Response> inviteReponseWithHttpInfo(CategoryInviteResponseReqDto categoryInviteResponseReqDto,) async {
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
  Future<ApiResponseDtoBoolean?> inviteReponse(CategoryInviteResponseReqDto categoryInviteResponseReqDto,) async {
    final response = await inviteReponseWithHttpInfo(categoryInviteResponseReqDto,);
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

  ///  카테고리에 유저 추가
  ///
  /// 이미 생성된 카테고리에 유저를 초대할 때 사용합니다.
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

  ///  카테고리에 유저 추가
  ///
  /// 이미 생성된 카테고리에 유저를 초대할 때 사용합니다.
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
