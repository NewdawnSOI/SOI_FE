//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class UserAPIApi {
  UserAPIApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// 전화번호 인증
  ///
  /// 사용자가 입력한 전화번호로 인증을 발송합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] phone (required):
  Future<Response> authSMSWithHttpInfo(String phone,) async {
    // ignore: prefer_const_declarations
    final path = r'/user/auth';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'phone', phone));

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

  /// 전화번호 인증
  ///
  /// 사용자가 입력한 전화번호로 인증을 발송합니다.
  ///
  /// Parameters:
  ///
  /// * [String] phone (required):
  Future<bool?> authSMS(String phone,) async {
    final response = await authSMSWithHttpInfo(phone,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'bool',) as bool;
    
    }
    return null;
  }

  /// 사용자 생성
  ///
  /// 새로운 사용자를 등록합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [UserCreateReqDto] userCreateReqDto (required):
  Future<Response> createUserWithHttpInfo(UserCreateReqDto userCreateReqDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/user/create';

    // ignore: prefer_final_locals
    Object? postBody = userCreateReqDto;

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

  /// 사용자 생성
  ///
  /// 새로운 사용자를 등록합니다.
  ///
  /// Parameters:
  ///
  /// * [UserCreateReqDto] userCreateReqDto (required):
  Future<ApiResponseDtoUserRespDto?> createUser(UserCreateReqDto userCreateReqDto,) async {
    final response = await createUserWithHttpInfo(userCreateReqDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoUserRespDto',) as ApiResponseDtoUserRespDto;
    
    }
    return null;
  }

  /// Id로 사용자 삭제
  ///
  /// Id 로 사용자를 삭제합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Response> deleteUserWithHttpInfo(int id,) async {
    // ignore: prefer_const_declarations
    final path = r'/user/delete';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'id', id));

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'DELETE',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Id로 사용자 삭제
  ///
  /// Id 로 사용자를 삭제합니다.
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<ApiResponseDtoUserRespDto?> deleteUser(int id,) async {
    final response = await deleteUserWithHttpInfo(id,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoUserRespDto',) as ApiResponseDtoUserRespDto;
    
    }
    return null;
  }

  /// 키워드로 사용자 검색
  ///
  /// 키워드가 포함된 userId를 갖고있는 사용자를 전부 검색합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  Future<Response> findUserWithHttpInfo(String userId,) async {
    // ignore: prefer_const_declarations
    final path = r'/user/find-by-keyword';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'userId', userId));

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 키워드로 사용자 검색
  ///
  /// 키워드가 포함된 userId를 갖고있는 사용자를 전부 검색합니다.
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  Future<ApiResponseDtoListUserRespDto?> findUser(String userId,) async {
    final response = await findUserWithHttpInfo(userId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoListUserRespDto',) as ApiResponseDtoListUserRespDto;
    
    }
    return null;
  }

  /// 모든유저 조회
  ///
  /// 모든유저를 조회합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getAllUsersWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/user/get-all';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 모든유저 조회
  ///
  /// 모든유저를 조회합니다.
  Future<ApiResponseDtoListUserFindRespDto?> getAllUsers() async {
    final response = await getAllUsersWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoListUserFindRespDto',) as ApiResponseDtoListUserFindRespDto;
    
    }
    return null;
  }

  /// 사용자 id 중복 체크
  ///
  /// 사용자 id 중복 체크합니다. 사용가능 : true, 사용불가(중복) : false
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  Future<Response> idCheckWithHttpInfo(String userId,) async {
    // ignore: prefer_const_declarations
    final path = r'/user/id-check';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'userId', userId));

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 사용자 id 중복 체크
  ///
  /// 사용자 id 중복 체크합니다. 사용가능 : true, 사용불가(중복) : false
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  Future<ApiResponseDtoBoolean?> idCheck(String userId,) async {
    final response = await idCheckWithHttpInfo(userId,);
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

  /// 사용자 로그인(전화번호로)
  ///
  /// 인증이 완료된 전화번호로 로그인을 합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] phone (required):
  Future<Response> loginWithHttpInfo(String phone,) async {
    // ignore: prefer_const_declarations
    final path = r'/user/login';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'phone', phone));

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

  /// 사용자 로그인(전화번호로)
  ///
  /// 인증이 완료된 전화번호로 로그인을 합니다.
  ///
  /// Parameters:
  ///
  /// * [String] phone (required):
  Future<ApiResponseDtoUserRespDto?> login(String phone,) async {
    final response = await loginWithHttpInfo(phone,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoUserRespDto',) as ApiResponseDtoUserRespDto;
    
    }
    return null;
  }
}
