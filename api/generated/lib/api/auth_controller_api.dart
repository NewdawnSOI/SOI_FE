//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AuthControllerApi {
  AuthControllerApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// 전화번호 인증
  ///
  /// 사용자가 입력한 전화번호로 인증을 발송합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] phoneNum (required):
  Future<Response> authSMSWithHttpInfo(String phoneNum,) async {
    // ignore: prefer_const_declarations
    final path = r'/auth/sms';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'phoneNum', phoneNum));

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
  /// * [String] phoneNum (required):
  Future<bool?> authSMS(String phoneNum,) async {
    final response = await authSMSWithHttpInfo(phoneNum,);
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

  /// 전화번호 인증확인
  ///
  /// 사용자 전화번호와 사용자가 입력한 인증코드를 보내서 인증확인을 진행합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [AuthCheckReqDto] authCheckReqDto (required):
  Future<Response> checkAuthSMSWithHttpInfo(AuthCheckReqDto authCheckReqDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/auth/sms/check';

    // ignore: prefer_final_locals
    Object? postBody = authCheckReqDto;

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

  /// 전화번호 인증확인
  ///
  /// 사용자 전화번호와 사용자가 입력한 인증코드를 보내서 인증확인을 진행합니다.
  ///
  /// Parameters:
  ///
  /// * [AuthCheckReqDto] authCheckReqDto (required):
  Future<bool?> checkAuthSMS(AuthCheckReqDto authCheckReqDto,) async {
    final response = await checkAuthSMSWithHttpInfo(authCheckReqDto,);
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
    final path = r'/auth/signup';

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
    final path = r'/auth/id-check';

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

  /// Performs an HTTP 'POST /auth/login' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [LoginReqDto] loginReqDto (required):
  Future<Response> loginWithHttpInfo(LoginReqDto loginReqDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/auth/login';

    // ignore: prefer_final_locals
    Object? postBody = loginReqDto;

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

  /// Parameters:
  ///
  /// * [LoginReqDto] loginReqDto (required):
  Future<LoginRespDto?> login(LoginReqDto loginReqDto,) async {
    final response = await loginWithHttpInfo(loginReqDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'LoginRespDto',) as LoginRespDto;
    
    }
    return null;
  }
}
