# soi_api_client.api.CategoryAPIApi

## Load the API package
```dart
import 'package:soi_api_client/api.dart';
```

All URIs are relative to *https://newdawnsoi.site*

Method | HTTP request | Description
------------- | ------------- | -------------
[**create1**](CategoryAPIApi.md#create1) | **POST** /category/create | 카테고리 추가
[**inviteReponse**](CategoryAPIApi.md#invitereponse) | **POST** /category/invite/response | 카테고리에 초대된 유저가 초대 승낙여부를 결정하는 API
[**inviteUser**](CategoryAPIApi.md#inviteuser) | **POST** /category/invite |  카테고리에 유저 추가


# **create1**
> ApiResponseDtoLong create1(categoryCreateReqDto)

카테고리 추가

카테고리를 추가합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CategoryAPIApi();
final categoryCreateReqDto = CategoryCreateReqDto(); // CategoryCreateReqDto | 

try {
    final result = api_instance.create1(categoryCreateReqDto);
    print(result);
} catch (e) {
    print('Exception when calling CategoryAPIApi->create1: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **categoryCreateReqDto** | [**CategoryCreateReqDto**](CategoryCreateReqDto.md)|  | 

### Return type

[**ApiResponseDtoLong**](ApiResponseDtoLong.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **inviteReponse**
> ApiResponseDtoBoolean inviteReponse(categoryInviteResponseReqDto)

카테고리에 초대된 유저가 초대 승낙여부를 결정하는 API

status에 넣을 수 있는 상태 : PENDING, ACCEPTED, DECLINED, EXPIRED

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CategoryAPIApi();
final categoryInviteResponseReqDto = CategoryInviteResponseReqDto(); // CategoryInviteResponseReqDto | 

try {
    final result = api_instance.inviteReponse(categoryInviteResponseReqDto);
    print(result);
} catch (e) {
    print('Exception when calling CategoryAPIApi->inviteReponse: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **categoryInviteResponseReqDto** | [**CategoryInviteResponseReqDto**](CategoryInviteResponseReqDto.md)|  | 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **inviteUser**
> ApiResponseDtoBoolean inviteUser(categoryInviteReqDto)

 카테고리에 유저 추가

이미 생성된 카테고리에 유저를 초대할 때 사용합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CategoryAPIApi();
final categoryInviteReqDto = CategoryInviteReqDto(); // CategoryInviteReqDto | 

try {
    final result = api_instance.inviteUser(categoryInviteReqDto);
    print(result);
} catch (e) {
    print('Exception when calling CategoryAPIApi->inviteUser: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **categoryInviteReqDto** | [**CategoryInviteReqDto**](CategoryInviteReqDto.md)|  | 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

