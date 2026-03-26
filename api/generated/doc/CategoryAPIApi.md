# soi_api_client.api.CategoryAPIApi

## Load the API package
```dart
import 'package:soi_api_client/api.dart';
```

All URIs are relative to *https://newdawnsoi.site*

Method | HTTP request | Description
------------- | ------------- | -------------
[**categoryAlert**](CategoryAPIApi.md#categoryalert) | **POST** /category/set/alert | 카테고리 알림설정
[**categoryPinned**](CategoryAPIApi.md#categorypinned) | **POST** /category/set/pinned | 카테고리 고정
[**create4**](CategoryAPIApi.md#create4) | **POST** /category/create | 카테고리 추가
[**customName**](CategoryAPIApi.md#customname) | **POST** /category/set/name | 카테고리 이름수정
[**customProfile**](CategoryAPIApi.md#customprofile) | **POST** /category/set/profile | 카테고리 프로필 수정
[**delete1**](CategoryAPIApi.md#delete1) | **POST** /category/delete | 카테고리 나가기 (삭제)
[**getCategories**](CategoryAPIApi.md#getcategories) | **POST** /category/find | 유저가 속한 카테고리 리스트를 가져오는 API
[**getCategories1**](CategoryAPIApi.md#getcategories1) | **POST** /category/find-by-keyword | 유저가 속한 카테고를 검색하는 API
[**inviteResponse**](CategoryAPIApi.md#inviteresponse) | **POST** /category/invite/response | 카테고리에 초대된 유저가 초대 승낙여부를 결정하는 API
[**inviteUser**](CategoryAPIApi.md#inviteuser) | **POST** /category/invite |  카테고리에 유저 추가(초대)


# **categoryAlert**
> ApiResponseDtoBoolean categoryAlert(categoryId)

카테고리 알림설정

유저아이디와 카테고리 아이디로 알림을 설정합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CategoryAPIApi();
final categoryId = 789; // int | 

try {
    final result = api_instance.categoryAlert(categoryId);
    print(result);
} catch (e) {
    print('Exception when calling CategoryAPIApi->categoryAlert: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **categoryId** | **int**|  | 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **categoryPinned**
> ApiResponseDtoBoolean categoryPinned(categoryId)

카테고리 고정

카테고리 아이디, 유저 아이디로 카테고리를 고정 혹은 고정해제 시킵니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CategoryAPIApi();
final categoryId = 789; // int | 

try {
    final result = api_instance.categoryPinned(categoryId);
    print(result);
} catch (e) {
    print('Exception when calling CategoryAPIApi->categoryPinned: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **categoryId** | **int**|  | 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **create4**
> ApiResponseDtoLong create4(categoryCreateReqDto)

카테고리 추가

카테고리를 추가합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CategoryAPIApi();
final categoryCreateReqDto = CategoryCreateReqDto(); // CategoryCreateReqDto | 

try {
    final result = api_instance.create4(categoryCreateReqDto);
    print(result);
} catch (e) {
    print('Exception when calling CategoryAPIApi->create4: $e\n');
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

# **customName**
> ApiResponseDtoBoolean customName(categoryId, name)

카테고리 이름수정

카테고리 아이디, 유저 아이디, 수정할 이름을 받아 카테고리 이름을 수정합니다. 커스텀한 이름을 삭제하길 원하면 name에 그냥 빈값 \"\" 을 넣으면 커스텀 이름이 삭제됩니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CategoryAPIApi();
final categoryId = 789; // int | 
final name = name_example; // String | 

try {
    final result = api_instance.customName(categoryId, name);
    print(result);
} catch (e) {
    print('Exception when calling CategoryAPIApi->customName: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **categoryId** | **int**|  | 
 **name** | **String**|  | [optional] 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **customProfile**
> ApiResponseDtoBoolean customProfile(categoryId, profileImageKey)

카테고리 프로필 수정

카테고리 아이디, 유저 아이디, 수정할 프로필 사진을 받아 프로필을 수정합니다. 기본 프로필로 변경하고싶으면 profileImageKey에 \"\" 을 넣으면 됩니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CategoryAPIApi();
final categoryId = 789; // int | 
final profileImageKey = profileImageKey_example; // String | 

try {
    final result = api_instance.customProfile(categoryId, profileImageKey);
    print(result);
} catch (e) {
    print('Exception when calling CategoryAPIApi->customProfile: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **categoryId** | **int**|  | 
 **profileImageKey** | **String**|  | [optional] 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **delete1**
> ApiResponseDtoObject delete1(categoryId)

카테고리 나가기 (삭제)

카테고리를 나갑니다. (만약 카테고리에 속한 유저가 본인밖에 없으면 관련 데이터 다 삭제)

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CategoryAPIApi();
final categoryId = 789; // int | 

try {
    final result = api_instance.delete1(categoryId);
    print(result);
} catch (e) {
    print('Exception when calling CategoryAPIApi->delete1: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **categoryId** | **int**|  | 

### Return type

[**ApiResponseDtoObject**](ApiResponseDtoObject.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getCategories**
> ApiResponseDtoListCategoryRespDto getCategories(categoryFilter, page)

유저가 속한 카테고리 리스트를 가져오는 API

CategoryFilter : ALL, PUBLIC, PRIVATE -> 옵션에 따라서 전체, 그룹, 개인으로 가져올 수 있음

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CategoryAPIApi();
final categoryFilter = categoryFilter_example; // String | 
final page = 56; // int | 

try {
    final result = api_instance.getCategories(categoryFilter, page);
    print(result);
} catch (e) {
    print('Exception when calling CategoryAPIApi->getCategories: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **categoryFilter** | **String**|  | 
 **page** | **int**|  | [optional] [default to 0]

### Return type

[**ApiResponseDtoListCategoryRespDto**](ApiResponseDtoListCategoryRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getCategories1**
> ApiResponseDtoListCategoryRespDto getCategories1(categoryFilter, keyword, page)

유저가 속한 카테고를 검색하는 API

CategoryFilter : ALL, PUBLIC, PRIVATE -> 옵션에 따라서 전체, 그룹, 개인으로 가져올 수 있음, keyword에 검색어 입력, 만약 검색어가 null이거나 빈문자열일경우 그냥 전체 카테고리를 가져옴

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CategoryAPIApi();
final categoryFilter = categoryFilter_example; // String | 
final keyword = keyword_example; // String | 
final page = 56; // int | 

try {
    final result = api_instance.getCategories1(categoryFilter, keyword, page);
    print(result);
} catch (e) {
    print('Exception when calling CategoryAPIApi->getCategories1: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **categoryFilter** | **String**|  | 
 **keyword** | **String**|  | [optional] 
 **page** | **int**|  | [optional] [default to 0]

### Return type

[**ApiResponseDtoListCategoryRespDto**](ApiResponseDtoListCategoryRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **inviteResponse**
> ApiResponseDtoBoolean inviteResponse(categoryInviteResponseReqDto)

카테고리에 초대된 유저가 초대 승낙여부를 결정하는 API

status에 넣을 수 있는 상태 : PENDING, ACCEPTED, DECLINED, EXPIRED

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CategoryAPIApi();
final categoryInviteResponseReqDto = CategoryInviteResponseReqDto(); // CategoryInviteResponseReqDto | 

try {
    final result = api_instance.inviteResponse(categoryInviteResponseReqDto);
    print(result);
} catch (e) {
    print('Exception when calling CategoryAPIApi->inviteResponse: $e\n');
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

 카테고리에 유저 추가(초대)

이미 생성된 카테고리에 유저를 추가(초대)할 때 사용합니다.

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

