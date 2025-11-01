# soi_api.api.UserAPIApi

## Load the API package
```dart
import 'package:soi_api/api.dart';
```

All URIs are relative to *http://localhost:8080*

Method | HTTP request | Description
------------- | ------------- | -------------
[**authSMS**](UserAPIApi.md#authsms) | **POST** /user/auth | 전화번호 인증
[**createUser**](UserAPIApi.md#createuser) | **POST** /user/create | 사용자 생성
[**deleteUser**](UserAPIApi.md#deleteuser) | **DELETE** /user/delete | 유저 Id로 사용자 삭제
[**idCheck**](UserAPIApi.md#idcheck) | **GET** /user/id-check | 사용자 id 중복 체크
[**login**](UserAPIApi.md#login) | **POST** /user/login | 사용자 로그인(전화번호로)


# **authSMS**
> bool authSMS(phone)

전화번호 인증

사용자가 입력한 전화번호로 인증을 발송합니다.

### Example
```dart
import 'package:soi_api/api.dart';

final api = SoiApi().getUserAPIApi();
final String phone = phone_example; // String | 

try {
    final response = api.authSMS(phone);
    print(response);
} catch on DioException (e) {
    print('Exception when calling UserAPIApi->authSMS: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **phone** | **String**|  | 

### Return type

**bool**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createUser**
> ApiResponseDtoUserRespDto createUser(userCreateReqDto)

사용자 생성

새로운 사용자를 등록합니다.

### Example
```dart
import 'package:soi_api/api.dart';

final api = SoiApi().getUserAPIApi();
final UserCreateReqDto userCreateReqDto = ; // UserCreateReqDto | 

try {
    final response = api.createUser(userCreateReqDto);
    print(response);
} catch on DioException (e) {
    print('Exception when calling UserAPIApi->createUser: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userCreateReqDto** | [**UserCreateReqDto**](UserCreateReqDto.md)|  | 

### Return type

[**ApiResponseDtoUserRespDto**](ApiResponseDtoUserRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteUser**
> ApiResponseDtoUserRespDto deleteUser(userId)

유저 Id로 사용자 삭제

id 로 사용자를 삭제합니다.

### Example
```dart
import 'package:soi_api/api.dart';

final api = SoiApi().getUserAPIApi();
final String userId = userId_example; // String | 

try {
    final response = api.deleteUser(userId);
    print(response);
} catch on DioException (e) {
    print('Exception when calling UserAPIApi->deleteUser: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**|  | 

### Return type

[**ApiResponseDtoUserRespDto**](ApiResponseDtoUserRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **idCheck**
> ApiResponseDtoBoolean idCheck(userId)

사용자 id 중복 체크

사용자 id 중복 체크합니다. 사용가능 : true, 사용불가(중복) : false

### Example
```dart
import 'package:soi_api/api.dart';

final api = SoiApi().getUserAPIApi();
final String userId = userId_example; // String | 

try {
    final response = api.idCheck(userId);
    print(response);
} catch on DioException (e) {
    print('Exception when calling UserAPIApi->idCheck: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**|  | 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **login**
> ApiResponseDtoUserRespDto login(phone)

사용자 로그인(전화번호로)

인증이 완료된 전화번호로 로그인을 합니다.

### Example
```dart
import 'package:soi_api/api.dart';

final api = SoiApi().getUserAPIApi();
final String phone = phone_example; // String | 

try {
    final response = api.login(phone);
    print(response);
} catch on DioException (e) {
    print('Exception when calling UserAPIApi->login: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **phone** | **String**|  | 

### Return type

[**ApiResponseDtoUserRespDto**](ApiResponseDtoUserRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

