# soi_api_client.api.AuthControllerApi

## Load the API package
```dart
import 'package:soi_api_client/api.dart';
```

All URIs are relative to *https://newdawnsoi.site*

Method | HTTP request | Description
------------- | ------------- | -------------
[**authSMS**](AuthControllerApi.md#authsms) | **POST** /auth/sms | 전화번호 인증
[**checkAuthSMS**](AuthControllerApi.md#checkauthsms) | **POST** /auth/sms/check | 전화번호 인증확인
[**createUser**](AuthControllerApi.md#createuser) | **POST** /auth/signup | 사용자 생성
[**idCheck**](AuthControllerApi.md#idcheck) | **GET** /auth/id-check | 사용자 id 중복 체크
[**login**](AuthControllerApi.md#login) | **POST** /auth/login | 
[**logout**](AuthControllerApi.md#logout) | **POST** /auth/logout | 
[**refresh**](AuthControllerApi.md#refresh) | **POST** /auth/refresh | 


# **authSMS**
> bool authSMS(phoneNum)

전화번호 인증

사용자가 입력한 전화번호로 인증을 발송합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = AuthControllerApi();
final phoneNum = phoneNum_example; // String | 

try {
    final result = api_instance.authSMS(phoneNum);
    print(result);
} catch (e) {
    print('Exception when calling AuthControllerApi->authSMS: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **phoneNum** | **String**|  | 

### Return type

**bool**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **checkAuthSMS**
> bool checkAuthSMS(authCheckReqDto)

전화번호 인증확인

사용자 전화번호와 사용자가 입력한 인증코드를 보내서 인증확인을 진행합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = AuthControllerApi();
final authCheckReqDto = AuthCheckReqDto(); // AuthCheckReqDto | 

try {
    final result = api_instance.checkAuthSMS(authCheckReqDto);
    print(result);
} catch (e) {
    print('Exception when calling AuthControllerApi->checkAuthSMS: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **authCheckReqDto** | [**AuthCheckReqDto**](AuthCheckReqDto.md)|  | 

### Return type

**bool**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createUser**
> ApiResponseDtoUserRespDto createUser(userCreateReqDto)

사용자 생성

새로운 사용자를 등록합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = AuthControllerApi();
final userCreateReqDto = UserCreateReqDto(); // UserCreateReqDto | 

try {
    final result = api_instance.createUser(userCreateReqDto);
    print(result);
} catch (e) {
    print('Exception when calling AuthControllerApi->createUser: $e\n');
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

# **idCheck**
> ApiResponseDtoBoolean idCheck(userId)

사용자 id 중복 체크

사용자 id 중복 체크합니다. 사용가능 : true, 사용불가(중복) : false

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = AuthControllerApi();
final userId = userId_example; // String | 

try {
    final result = api_instance.idCheck(userId);
    print(result);
} catch (e) {
    print('Exception when calling AuthControllerApi->idCheck: $e\n');
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
> LoginRespDto login(loginReqDto)



### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = AuthControllerApi();
final loginReqDto = LoginReqDto(); // LoginReqDto | 

try {
    final result = api_instance.login(loginReqDto);
    print(result);
} catch (e) {
    print('Exception when calling AuthControllerApi->login: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **loginReqDto** | [**LoginReqDto**](LoginReqDto.md)|  | 

### Return type

[**LoginRespDto**](LoginRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **logout**
> ApiResponseDtoBoolean logout(refreshTokenReqDto)



### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = AuthControllerApi();
final refreshTokenReqDto = RefreshTokenReqDto(); // RefreshTokenReqDto | 

try {
    final result = api_instance.logout(refreshTokenReqDto);
    print(result);
} catch (e) {
    print('Exception when calling AuthControllerApi->logout: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **refreshTokenReqDto** | [**RefreshTokenReqDto**](RefreshTokenReqDto.md)|  | 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **refresh**
> LoginRespDto refresh(refreshTokenReqDto)



### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = AuthControllerApi();
final refreshTokenReqDto = RefreshTokenReqDto(); // RefreshTokenReqDto | 

try {
    final result = api_instance.refresh(refreshTokenReqDto);
    print(result);
} catch (e) {
    print('Exception when calling AuthControllerApi->refresh: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **refreshTokenReqDto** | [**RefreshTokenReqDto**](RefreshTokenReqDto.md)|  | 

### Return type

[**LoginRespDto**](LoginRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

