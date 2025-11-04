# soi_api_client.api.UserAPIApi

## Load the API package
```dart
import 'package:soi_api_client/api.dart';
```

All URIs are relative to *https://newdawnsoi.site*

Method | HTTP request | Description
------------- | ------------- | -------------
[**authSMS**](UserAPIApi.md#authsms) | **POST** /user/auth | 전화번호 인증
[**createUser**](UserAPIApi.md#createuser) | **POST** /user/create | 사용자 생성
[**deleteUser**](UserAPIApi.md#deleteuser) | **DELETE** /user/delete | Id로 사용자 삭제
[**findUser**](UserAPIApi.md#finduser) | **GET** /user/find-by-keyword | 키워드로 사용자 검색
[**getAllUsers**](UserAPIApi.md#getallusers) | **GET** /user/get-all | 모든유저 조회
[**idCheck**](UserAPIApi.md#idcheck) | **GET** /user/id-check | 사용자 id 중복 체크
[**login**](UserAPIApi.md#login) | **POST** /user/login | 사용자 로그인(전화번호로)


# **authSMS**
> bool authSMS(phone)

전화번호 인증

사용자가 입력한 전화번호로 인증을 발송합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final phone = phone_example; // String | 

try {
    final result = api_instance.authSMS(phone);
    print(result);
} catch (e) {
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
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final userCreateReqDto = UserCreateReqDto(); // UserCreateReqDto | 

try {
    final result = api_instance.createUser(userCreateReqDto);
    print(result);
} catch (e) {
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
> ApiResponseDtoUserRespDto deleteUser(id)

Id로 사용자 삭제

Id 로 사용자를 삭제합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final id = 789; // int | 

try {
    final result = api_instance.deleteUser(id);
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->deleteUser: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **int**|  | 

### Return type

[**ApiResponseDtoUserRespDto**](ApiResponseDtoUserRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **findUser**
> ApiResponseDtoListUserRespDto findUser(userId)

키워드로 사용자 검색

키워드가 포함된 userId를 갖고있는 사용자를 전부 검색합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final userId = userId_example; // String | 

try {
    final result = api_instance.findUser(userId);
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->findUser: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**|  | 

### Return type

[**ApiResponseDtoListUserRespDto**](ApiResponseDtoListUserRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAllUsers**
> ApiResponseDtoListUserFindRespDto getAllUsers()

모든유저 조회

모든유저를 조회합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();

try {
    final result = api_instance.getAllUsers();
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->getAllUsers: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**ApiResponseDtoListUserFindRespDto**](ApiResponseDtoListUserFindRespDto.md)

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
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final userId = userId_example; // String | 

try {
    final result = api_instance.idCheck(userId);
    print(result);
} catch (e) {
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
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final phone = phone_example; // String | 

try {
    final result = api_instance.login(phone);
    print(result);
} catch (e) {
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

