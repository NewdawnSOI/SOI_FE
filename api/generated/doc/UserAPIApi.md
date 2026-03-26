# soi_api_client.api.UserAPIApi

## Load the API package
```dart
import 'package:soi_api_client/api.dart';
```

All URIs are relative to *https://newdawnsoi.site*

Method | HTTP request | Description
------------- | ------------- | -------------
[**deleteUser**](UserAPIApi.md#deleteuser) | **DELETE** /user/delete | Id로 사용자 삭제
[**findUser**](UserAPIApi.md#finduser) | **GET** /user/find-by-keyword | 키워드로 사용자 검색
[**getAllUsers**](UserAPIApi.md#getallusers) | **GET** /user/get-all | 모든유저 조회
[**getUser**](UserAPIApi.md#getuser) | **GET** /user/get | 특정유저 조회
[**loginByNickname**](UserAPIApi.md#loginbynickname) | **POST** /user/login/by-nickname | 사용자 로그인(전화번호로)
[**loginByPhone**](UserAPIApi.md#loginbyphone) | **POST** /user/login/by-phone | 사용자 로그인(전화번호로)
[**update1**](UserAPIApi.md#update1) | **PATCH** /user/update | 유저정보 업데이트
[**updateCoverImage**](UserAPIApi.md#updatecoverimage) | **PATCH** /user/update-cover-image | 유저 배경사진 업데이트
[**updateProfile**](UserAPIApi.md#updateprofile) | **PATCH** /user/update-profile | 유저 프로필 업데이트


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
> ApiResponseDtoListUserRespDto findUser(nickname)

키워드로 사용자 검색

키워드가 포함된 userId를 갖고있는 사용자를 전부 검색합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final nickname = nickname_example; // String | 

try {
    final result = api_instance.findUser(nickname);
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->findUser: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **nickname** | **String**|  | 

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

# **getUser**
> ApiResponseDtoUserRespDto getUser()

특정유저 조회

유저의 id값(Long)으로 유저를 조회합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();

try {
    final result = api_instance.getUser();
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->getUser: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**ApiResponseDtoUserRespDto**](ApiResponseDtoUserRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **loginByNickname**
> ApiResponseDtoUserRespDto loginByNickname(nickName)

사용자 로그인(전화번호로)

인증이 완료된 전화번호로 로그인을 합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final nickName = nickName_example; // String | 

try {
    final result = api_instance.loginByNickname(nickName);
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->loginByNickname: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **nickName** | **String**|  | 

### Return type

[**ApiResponseDtoUserRespDto**](ApiResponseDtoUserRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **loginByPhone**
> ApiResponseDtoUserRespDto loginByPhone(phoneNum)

사용자 로그인(전화번호로)

인증이 완료된 전화번호로 로그인을 합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final phoneNum = phoneNum_example; // String | 

try {
    final result = api_instance.loginByPhone(phoneNum);
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->loginByPhone: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **phoneNum** | **String**|  | 

### Return type

[**ApiResponseDtoUserRespDto**](ApiResponseDtoUserRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **update1**
> ApiResponseDtoUserRespDto update1(userUpdateReqDto)

유저정보 업데이트

새로운 데이터로 유저정보를 업데이트합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final userUpdateReqDto = UserUpdateReqDto(); // UserUpdateReqDto | 

try {
    final result = api_instance.update1(userUpdateReqDto);
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->update1: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userUpdateReqDto** | [**UserUpdateReqDto**](UserUpdateReqDto.md)|  | 

### Return type

[**ApiResponseDtoUserRespDto**](ApiResponseDtoUserRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateCoverImage**
> ApiResponseDtoUserRespDto updateCoverImage(coverImageKey)

유저 배경사진 업데이트

유저의 배경사진을 업데이트 합니다. 기본 배경화면으로 변경하고싶으면 profileImageKey에 \"\" 을 넣으면 됩니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final coverImageKey = coverImageKey_example; // String | 

try {
    final result = api_instance.updateCoverImage(coverImageKey);
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->updateCoverImage: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **coverImageKey** | **String**|  | [optional] 

### Return type

[**ApiResponseDtoUserRespDto**](ApiResponseDtoUserRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateProfile**
> ApiResponseDtoUserRespDto updateProfile(profileImageKey)

유저 프로필 업데이트

유저의 프로필을 업데이트 합니다. 기본 프로필로 변경하고싶으면 profileImageKey에 \"\" 을 넣으면 됩니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final profileImageKey = profileImageKey_example; // String | 

try {
    final result = api_instance.updateProfile(profileImageKey);
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->updateProfile: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profileImageKey** | **String**|  | [optional] 

### Return type

[**ApiResponseDtoUserRespDto**](ApiResponseDtoUserRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

